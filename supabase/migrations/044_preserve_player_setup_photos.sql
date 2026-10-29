BEGIN;
-- Keep the uploaded identity separate from the optional emoji selected by a player.
ALTER TABLE public.battle_sessions ADD COLUMN player1_setup_photo_url text,ADD COLUMN player2_setup_photo_url text;
UPDATE public.battle_sessions SET
 player1_setup_photo_url=CASE WHEN btrim(player1_avatar_url)~*'^(https?://|/[^/])' THEN btrim(player1_avatar_url) END,
 player2_setup_photo_url=CASE WHEN btrim(player2_avatar_url)~*'^(https?://|/[^/])' THEN btrim(player2_avatar_url) END
WHERE btrim(player1_avatar_url)~*'^(https?://|/[^/])' OR btrim(player2_avatar_url)~*'^(https?://|/[^/])';
CREATE FUNCTION public.tcg_preserve_player_setup_photos() RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.player1_setup_photo_url IS NULL AND btrim(NEW.player1_avatar_url)~*'^(https?://|/[^/])' THEN NEW.player1_setup_photo_url:=btrim(NEW.player1_avatar_url);END IF;
  IF NEW.player2_setup_photo_url IS NULL AND btrim(NEW.player2_avatar_url)~*'^(https?://|/[^/])' THEN NEW.player2_setup_photo_url:=btrim(NEW.player2_avatar_url);END IF;
 ELSE
  -- Clearing the dedicated photo explicitly also clears its matching display value.
  IF NEW.player1_setup_photo_url IS NULL AND OLD.player1_setup_photo_url IS NOT NULL AND NEW.player1_avatar_url IS NOT DISTINCT FROM OLD.player1_setup_photo_url THEN NEW.player1_avatar_url:=NULL;END IF;
  IF NEW.player2_setup_photo_url IS NULL AND OLD.player2_setup_photo_url IS NOT NULL AND NEW.player2_avatar_url IS NOT DISTINCT FROM OLD.player2_setup_photo_url THEN NEW.player2_avatar_url:=NULL;END IF;
 END IF;
 IF NEW.player1_setup_photo_url IS NOT NULL THEN
  IF btrim(NEW.player1_setup_photo_url)!~*'^(https?://|/[^/])' THEN RAISE EXCEPTION 'URL foto Player 1 tidak valid.';END IF;
  NEW.player1_avatar_url:=btrim(NEW.player1_setup_photo_url);
 END IF;
 IF NEW.player2_setup_photo_url IS NOT NULL THEN
  IF btrim(NEW.player2_setup_photo_url)!~*'^(https?://|/[^/])' THEN RAISE EXCEPTION 'URL foto Player 2 tidak valid.';END IF;
  NEW.player2_avatar_url:=btrim(NEW.player2_setup_photo_url);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tbc_preserve_player_setup_photos BEFORE INSERT OR UPDATE ON public.battle_sessions FOR EACH ROW EXECUTE FUNCTION public.tcg_preserve_player_setup_photos();
CREATE OR REPLACE FUNCTION public.set_battle_player_avatar(p_code text,p_player text,p_token text,p_avatar text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;side text:=lower(btrim(coalesce(p_player,'')));expected_token text;photo text;avatar text:=btrim(coalesce(p_avatar,''));
BEGIN
 IF side NOT IN ('p1','p2') THEN RETURN jsonb_build_object('ok',false,'message','Pemain tidak valid.');END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(btrim(coalesce(p_code,''))) LIMIT 1 FOR UPDATE;
 IF b.id IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Battle tidak ditemukan.');END IF;
 expected_token:=CASE WHEN side='p1' THEN b.player1_token ELSE b.player2_token END;
 IF expected_token IS NULL OR p_token IS DISTINCT FROM expected_token THEN RETURN jsonb_build_object('ok',false,'message','Tautan pemain tidak valid.');END IF;
 photo:=CASE WHEN side='p1' THEN b.player1_setup_photo_url ELSE b.player2_setup_photo_url END;
 IF photo IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'avatar',photo,'source','game_setup','message','Foto dari Game Setup digunakan untuk battle ini.');END IF;
 IF NOT (avatar=ANY(ARRAY['🐻','🐼','🐸','🐱','🐶','🐰','🦊','🐵','🐨','🐯','🐧','🐙','🦄','🐲','🐤','🐢'])) THEN RETURN jsonb_build_object('ok',false,'message','Pilihan avatar tidak tersedia.');END IF;
 UPDATE public.battle_sessions SET player1_avatar_url=CASE WHEN side='p1' THEN avatar ELSE player1_avatar_url END,player2_avatar_url=CASE WHEN side='p2' THEN avatar ELSE player2_avatar_url END WHERE id=b.id;
 RETURN jsonb_build_object('ok',true,'avatar',avatar,'source','player_choice');
END $$;
REVOKE ALL ON FUNCTION public.tcg_preserve_player_setup_photos() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.set_battle_player_avatar(text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_battle_player_avatar(text,text,text,text) TO anon,authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
