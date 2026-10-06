-- Let each authenticated battle player choose a small, safe set of avatars.
-- The per-player access token is required because battle pages are opened by
-- public links rather than Supabase Auth sessions.

ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS player1_avatar_url text,
  ADD COLUMN IF NOT EXISTS player2_avatar_url text;

CREATE OR REPLACE FUNCTION public.set_battle_player_avatar(
  p_code text,
  p_player text,
  p_token text,
  p_avatar text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_player text := lower(btrim(coalesce(p_player, '')));
  v_expected_token text;
  v_avatar text := btrim(coalesce(p_avatar, ''));
  v_avatars text[] := ARRAY[
    '🐻', '🐼', '🐸', '🐱', '🐶', '🐰', '🦊', '🐵',
    '🐨', '🐯', '🐧', '🐙', '🦄', '🐲', '🐤', '🐢'
  ];
BEGIN
  IF v_player NOT IN ('p1', 'p2') THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Pemain tidak valid.');
  END IF;

  SELECT * INTO v_battle
    FROM public.battle_sessions
   WHERE upper(code) = upper(btrim(coalesce(p_code, '')))
   LIMIT 1
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1'
    THEN v_battle.player1_token
    ELSE v_battle.player2_token
  END;

  IF v_expected_token IS NULL OR p_token IS DISTINCT FROM v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Tautan pemain tidak valid.');
  END IF;

  IF NOT (v_avatar = ANY(v_avatars)) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Pilihan avatar tidak tersedia.');
  END IF;

  IF v_player = 'p1' THEN
    UPDATE public.battle_sessions
       SET player1_avatar_url = v_avatar
     WHERE id = v_battle.id;
  ELSE
    UPDATE public.battle_sessions
       SET player2_avatar_url = v_avatar
     WHERE id = v_battle.id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'avatar', v_avatar);
END;
$function$;

REVOKE ALL ON FUNCTION public.set_battle_player_avatar(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_battle_player_avatar(text, text, text, text)
  TO anon, authenticated, service_role;
