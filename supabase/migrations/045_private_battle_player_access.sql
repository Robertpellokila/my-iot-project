BEGIN;
DROP POLICY IF EXISTS "Authenticated users can create battle" ON public.battle_sessions;
CREATE SCHEMA IF NOT EXISTS tbc_private;
REVOKE ALL ON SCHEMA tbc_private FROM PUBLIC,anon,authenticated;
CREATE TABLE tbc_private.battle_player_access(
 battle_id uuid NOT NULL REFERENCES public.battle_sessions(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 player text NOT NULL CHECK(player IN ('p1','p2')),token text NOT NULL UNIQUE,access_code text NOT NULL UNIQUE,
 updated_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(battle_id,player)
);
CREATE TABLE tbc_private.battle_access_attempts(client_key text PRIMARY KEY,started_at timestamptz NOT NULL,failures integer NOT NULL);
REVOKE ALL ON ALL TABLES IN SCHEMA tbc_private FROM PUBLIC,anon,authenticated;
-- All credentials formerly readable in public rows are rotated atomically.
INSERT INTO tbc_private.battle_player_access(battle_id,player,token,access_code)
 SELECT b.id,p,encode(extensions.gen_random_bytes(24),'hex'),upper(encode(extensions.gen_random_bytes(6),'hex')) FROM public.battle_sessions b CROSS JOIN unnest(ARRAY['p1','p2']) p;
CREATE FUNCTION public.tcg_battle_player_token(p_battle_id uuid,p_player text) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT a.token FROM tbc_private.battle_player_access a WHERE a.battle_id=p_battle_id AND a.player=p_player
$$;
REVOKE ALL ON FUNCTION public.tcg_battle_player_token(uuid,text) FROM PUBLIC,anon,authenticated;
-- Preserve the existing AP/skill/quiz logic; replace only private credential reads.
DO $patch$ DECLARE f record;s text; BEGIN
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc~'\.player[12]_token' LOOP
  s:=pg_get_functiondef(f.oid);
  s:=regexp_replace(s,'([a-zA-Z_][a-zA-Z_0-9]*)\.player1_token',E'public.tcg_battle_player_token(\\1.id,''p1'')','g');
  s:=regexp_replace(s,'([a-zA-Z_][a-zA-Z_0-9]*)\.player2_token',E'public.tcg_battle_player_token(\\1.id,''p2'')','g');
  EXECUTE s;
 END LOOP;
END $patch$;
ALTER TABLE public.battle_sessions ALTER COLUMN player1_token DROP DEFAULT,ALTER COLUMN player2_token DROP DEFAULT;
UPDATE public.battle_sessions SET player1_token=NULL,player2_token=NULL,player1_access_code=NULL,player2_access_code=NULL;
ALTER TABLE public.battle_sessions ADD CONSTRAINT battle_session_no_public_credentials CHECK(player1_token IS NULL AND player2_token IS NULL AND player1_access_code IS NULL AND player2_access_code IS NULL);
CREATE FUNCTION public.tcg_store_battle_credentials() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO tbc_private.battle_player_access(battle_id,player,token,access_code) VALUES
  (NEW.id,'p1',coalesce(nullif(NEW.player1_token,''),encode(extensions.gen_random_bytes(24),'hex')),upper(encode(extensions.gen_random_bytes(6),'hex'))),
  (NEW.id,'p2',coalesce(nullif(NEW.player2_token,''),encode(extensions.gen_random_bytes(24),'hex')),upper(encode(extensions.gen_random_bytes(6),'hex')));
 END IF;
 -- Compatibility columns stay empty, including WAL/realtime/RETURNING payloads.
 NEW.player1_token:=NULL;NEW.player2_token:=NULL;NEW.player1_access_code:=NULL;NEW.player2_access_code:=NULL;RETURN NEW;
END $$;
CREATE TRIGGER zzz_store_private_battle_credentials BEFORE INSERT OR UPDATE ON public.battle_sessions FOR EACH ROW EXECUTE FUNCTION public.tcg_store_battle_credentials();
REVOKE ALL ON FUNCTION public.tcg_store_battle_credentials() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.get_public_battle_state(p_code text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(btrim(coalesce(p_code,'')));
 IF b.id IS NULL OR ((NOT coalesce(b.is_active,true) OR b.active_until<=now()) AND b.status<>'finished') THEN RETURN jsonb_build_object('ok',false,'code','BATTLE_UNAVAILABLE','message','Battle tidak tersedia.');END IF;
 RETURN jsonb_build_object('ok',true,'battle',to_jsonb(b)-ARRAY['player1_token','player2_token','player1_access_code','player2_access_code','created_by']);
END $$;
CREATE FUNCTION public.get_battle_player_state(p_code text,p_player text,p_token text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(btrim(coalesce(p_code,'')));
 IF b.id IS NULL OR coalesce(p_player,'') NOT IN ('p1','p2') OR p_token IS NULL OR p_token IS DISTINCT FROM public.tcg_battle_player_token(b.id,p_player) THEN RETURN jsonb_build_object('ok',false,'code','PLAYER_ACCESS_REQUIRED','message','Masukkan kode pribadi dari guru untuk membuka pemain ini.');END IF;
 RETURN public.get_public_battle_state(p_code)||jsonb_build_object('player',p_player,'access_valid',true);
END $$;
CREATE FUNCTION public.redeem_battle_player_code(p_access_code text,p_code text DEFAULT NULL,p_player text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE a tbc_private.battle_player_access;b public.battle_sessions;entered text:=upper(regexp_replace(coalesce(p_access_code,''),'[^a-zA-Z0-9]','','g'));client text;attempt tbc_private.battle_access_attempts;
BEGIN
 IF length(entered)<>12 THEN RETURN jsonb_build_object('ok',false,'message','Masukkan 12 karakter kode pribadi dari guru.');END IF;
 client:=md5(coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb->>'x-forwarded-for');client:=coalesce(client,'local');
 SELECT * INTO attempt FROM tbc_private.battle_access_attempts WHERE client_key=client;
 IF attempt.failures>=15 AND attempt.started_at>clock_timestamp()-interval '1 minute' THEN RETURN jsonb_build_object('ok',false,'code','RATE_LIMIT','message','Terlalu banyak percobaan. Tunggu satu menit sebelum mencoba lagi.');END IF;
 SELECT * INTO a FROM tbc_private.battle_player_access WHERE access_code=entered;
 IF a.battle_id IS NOT NULL THEN SELECT * INTO b FROM public.battle_sessions WHERE id=a.battle_id;END IF;
 IF a.battle_id IS NULL OR (nullif(p_code,'') IS NOT NULL AND upper(b.code)<>upper(trim(p_code))) OR (nullif(p_player,'') IS NOT NULL AND a.player<>p_player) THEN
  INSERT INTO tbc_private.battle_access_attempts VALUES(client,clock_timestamp(),1) ON CONFLICT(client_key) DO UPDATE SET failures=CASE WHEN battle_access_attempts.started_at<clock_timestamp()-interval '1 minute' THEN 1 ELSE battle_access_attempts.failures+1 END,started_at=CASE WHEN battle_access_attempts.started_at<clock_timestamp()-interval '1 minute' THEN clock_timestamp() ELSE battle_access_attempts.started_at END RETURNING * INTO attempt;
  RETURN jsonb_build_object('ok',false,'message',CASE WHEN attempt.failures>=15 THEN 'Terlalu banyak percobaan. Periksa kode dengan guru sebelum mencoba lagi.' ELSE 'Kode pribadi tidak valid untuk pemain ini.' END);
 END IF;
 IF b.status='finished' OR NOT coalesce(b.is_active,true) OR b.active_until<=now() THEN RETURN jsonb_build_object('ok',false,'message','Battle ini sudah tidak tersedia untuk bergabung.');END IF;
 DELETE FROM tbc_private.battle_access_attempts WHERE client_key=client OR started_at<now()-interval '1 day';
 RETURN jsonb_build_object('ok',true,'code',b.code,'player',a.player,'token',a.token);
END $$;
CREATE FUNCTION public.admin_battle_access(p_code text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login guru diperlukan.' USING ERRCODE='42501';END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code));IF b.id IS NULL THEN RAISE EXCEPTION 'Battle tidak ditemukan.';END IF;
 SELECT jsonb_object_agg('player'||CASE WHEN player='p1' THEN '1' ELSE '2' END||'_access_code',access_code) INTO result FROM tbc_private.battle_player_access WHERE battle_id=b.id;
 RETURN coalesce(result,'{}')||jsonb_build_object('code',b.code);
END $$;
-- Helpers/triggers may only run inside guarded authoritative RPCs.
REVOKE ALL ON FUNCTION public.start_battle_question(uuid,integer),public.tcg_tick_statuses_for_player(uuid,text),public.tcg_finish_action_point_turn(uuid,text),public.tcg_emit_fusion_battle_event(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_public_battle_state(text),public.get_battle_player_state(text,text,text),public.redeem_battle_player_code(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_battle_state(text),public.get_battle_player_state(text,text,text),public.redeem_battle_player_code(text,text,text) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_battle_access(text) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION public.admin_battle_access(text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
