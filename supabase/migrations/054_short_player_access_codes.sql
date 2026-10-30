-- Short private entry codes; session/action tokens retain their original strength.
-- Existing codes/tokens are preserved. New battles and teacher resets use six characters.
BEGIN;
CREATE OR REPLACE FUNCTION tbc_private.issue_battle_player_access(p_battle_id uuid,p_player text,p_token text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE alphabet constant text:='23456789ABCDEFGHJKLMNPQRSTUVWXYZ';random_bytes bytea;candidate text;i integer;attempt integer;
BEGIN
 FOR attempt IN 1..64 LOOP
  random_bytes:=extensions.gen_random_bytes(6);candidate:='';
  FOR i IN 0..5 LOOP
   candidate:=candidate||substr(alphabet,(get_byte(random_bytes,i)%32)+1,1);
  END LOOP;
  -- Exclude the current code as well: resetting access must always replace it.
  IF EXISTS(SELECT 1 FROM tbc_private.battle_player_access WHERE access_code=candidate) THEN CONTINUE;END IF;
  BEGIN
   INSERT INTO tbc_private.battle_player_access(battle_id,player,token,access_code)
   VALUES(p_battle_id,p_player,coalesce(nullif(p_token,''),encode(extensions.gen_random_bytes(24),'hex')),candidate)
   ON CONFLICT(battle_id,player) DO UPDATE SET token=EXCLUDED.token,access_code=EXCLUDED.access_code,updated_at=clock_timestamp();
   RETURN;
  EXCEPTION WHEN unique_violation THEN
   -- A concurrent issuer may claim the same code after the check; retry atomically.
   NULL;
  END;
 END LOOP;
 RAISE EXCEPTION 'Belum dapat membuat kode pribadi. Coba lagi.';
END $$;
REVOKE ALL ON FUNCTION tbc_private.issue_battle_player_access(uuid,text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.tcg_store_battle_credentials() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  PERFORM tbc_private.issue_battle_player_access(NEW.id,'p1',NEW.player1_token);
  PERFORM tbc_private.issue_battle_player_access(NEW.id,'p2',NEW.player2_token);
 END IF;
 NEW.player1_token:=NULL;NEW.player2_token:=NULL;NEW.player1_access_code:=NULL;NEW.player2_access_code:=NULL;RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.tcg_store_battle_credentials() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.redeem_battle_player_code(p_access_code text,p_code text DEFAULT NULL,p_player text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE a tbc_private.battle_player_access;b public.battle_sessions;entered text:=upper(regexp_replace(coalesce(p_access_code,''),'[^a-zA-Z0-9]','','g'));client text;attempt tbc_private.battle_access_attempts;
BEGIN
 IF length(entered) NOT IN (6,12) THEN RETURN jsonb_build_object('ok',false,'message','Masukkan 6 karakter kode pribadi dari guru.');END IF;
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

CREATE OR REPLACE FUNCTION public.teacher_reset_battle_access(p_code text,p_player text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login guru diperlukan.' USING ERRCODE='42501';END IF;
 IF coalesce(p_player,'') NOT IN ('p1','p2') THEN RAISE EXCEPTION 'Pemain tidak valid.';END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;IF b.id IS NULL THEN RAISE EXCEPTION 'Battle tidak ditemukan.';END IF;
 PERFORM tbc_private.issue_battle_player_access(b.id,p_player);
 INSERT INTO public.battle_events(battle_id,type,target_player,payload) VALUES(b.id,'teacher_reset_access',p_player,jsonb_build_object('teacher_id',auth.uid(),'message','Guru memperbarui akses pemain. Gunakan kode pribadi terbaru.'));
 RETURN public.admin_battle_access(b.code)||jsonb_build_object('ok',true,'player',p_player);
END $$;

REVOKE ALL ON FUNCTION public.redeem_battle_player_code(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_battle_player_code(text,text,text) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.teacher_reset_battle_access(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.teacher_reset_battle_access(text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
