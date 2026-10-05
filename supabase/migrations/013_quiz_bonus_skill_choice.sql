-- A correct quiz answer offers three distinct bonus skills. The player chooses
-- one through a token-validated RPC; the battle remains paused until then.

CREATE TABLE IF NOT EXISTS public.battle_question_bonus_choices (
  question_round_id uuid PRIMARY KEY
    REFERENCES public.battle_question_rounds(id) ON DELETE CASCADE,
  battle_id uuid NOT NULL
    REFERENCES public.battle_sessions(id) ON DELETE CASCADE,
  player text NOT NULL CHECK (player IN ('p1', 'p2')),
  skill_options text[] NOT NULL,
  selected_skill_type text,
  created_at timestamptz NOT NULL DEFAULT now(),
  selected_at timestamptz,
  CONSTRAINT battle_question_bonus_choices_three_options
    CHECK (cardinality(skill_options) = 3),
  CONSTRAINT battle_question_bonus_choices_selected_in_offer
    CHECK (selected_skill_type IS NULL OR selected_skill_type = ANY(skill_options))
);

CREATE INDEX IF NOT EXISTS battle_question_bonus_choices_pending_idx
  ON public.battle_question_bonus_choices (battle_id, player, created_at DESC)
  WHERE selected_skill_type IS NULL;

ALTER TABLE public.battle_question_bonus_choices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.battle_question_bonus_choices FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_battle_question_answer(
  p_code text,
  p_player text,
  p_token text,
  p_question_round_id uuid,
  p_answer_index integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_round public.battle_question_rounds%ROWTYPE;
  v_expected_token text;
  v_player text := lower(trim(coalesce(p_player, '')));
  v_correct_answer text;
  v_correct_option text;
  v_answer_letter text;
  v_is_correct boolean := false;
  v_reward_choices text[] := ARRAY[]::text[];
  v_timeout jsonb := '{}'::jsonb;
BEGIN
  IF v_player NOT IN ('p1', 'p2') THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Invalid player.');
  END IF;

  IF p_answer_index IS NULL OR p_answer_index < 0 OR p_answer_index > 3 THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Invalid answer.');
  END IF;

  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE upper(code) = upper(trim(coalesce(p_code, '')))
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  IF NOT coalesce(v_battle.question_active, false) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Coding challenge tidak sedang aktif.');
  END IF;

  SELECT * INTO v_round
  FROM public.battle_question_rounds
  WHERE id = p_question_round_id AND battle_id = v_battle.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Question round tidak ditemukan.');
  END IF;

  v_timeout := public.tcg_expire_battle_question(v_battle.id, p_question_round_id);
  IF coalesce((v_timeout->>'timed_out')::boolean, false) THEN
    RETURN v_timeout;
  END IF;

  IF v_round.winner_player IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'correct', false,
      'already_finished', true,
      'winner', v_round.winner_player,
      'message', 'Challenge sudah memiliki pemenang.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.battle_question_answers
    WHERE battle_question_id = p_question_round_id AND player = v_player
  ) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Kamu sudah menjawab question ini.');
  END IF;

  SELECT upper(trim(correct_answer)) INTO v_correct_answer
  FROM public.coding_questions WHERE id = v_round.question_id;

  SELECT CASE v_correct_answer
    WHEN 'A' THEN option_a WHEN 'B' THEN option_b
    WHEN 'C' THEN option_c WHEN 'D' THEN option_d
    ELSE NULL
  END INTO v_correct_option
  FROM public.coding_questions WHERE id = v_round.question_id;

  IF v_correct_answer IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Correct answer tidak ditemukan.');
  END IF;

  v_answer_letter := chr(65 + p_answer_index);
  v_is_correct := v_answer_letter = v_correct_answer;

  INSERT INTO public.battle_question_answers (
    battle_question_id, player, answer_index, is_correct, answered_at
  ) VALUES (
    p_question_round_id, v_player, p_answer_index, v_is_correct, now()
  );

  IF NOT v_is_correct THEN
    INSERT INTO public.battle_events (battle_id, type, source_player, payload)
    VALUES (v_battle.id, 'question_wrong', v_player, jsonb_build_object('message', 'Wrong answer'));

    RETURN jsonb_build_object(
      'ok', true,
      'correct', false,
      'winner', NULL,
      'correct_answer', v_correct_answer,
      'correct_option', v_correct_option,
      'message', 'Jawaban salah.'
    );
  END IF;

  UPDATE public.battle_question_rounds
  SET winner_player = v_player,
      winner_answer = p_answer_index,
      won_at = now(),
      status = 'won'
  WHERE id = p_question_round_id;

  IF coalesce(v_battle.question_bonus_enabled, true) THEN
    SELECT array_agg(skill_type ORDER BY random()) INTO v_reward_choices
    FROM (
      SELECT skill_type
      FROM unnest(ARRAY[
        'power_strike', 'iron_guard', 'recovery', 'overcharge', 'cleanse'
      ]::text[]) AS offered(skill_type)
      ORDER BY random()
      LIMIT 3
    ) AS shuffled;

    INSERT INTO public.battle_question_bonus_choices (
      question_round_id, battle_id, player, skill_options
    ) VALUES (
      p_question_round_id, v_battle.id, v_player, v_reward_choices
    )
    ON CONFLICT (question_round_id) DO UPDATE
      SET player = EXCLUDED.player,
          skill_options = EXCLUDED.skill_options,
          selected_skill_type = NULL,
          selected_at = NULL,
          created_at = now();
  ELSE
    UPDATE public.battle_sessions
    SET question_active = false,
        status = 'battle',
        current_question_id = NULL,
        current_question_round_id = NULL
    WHERE id = v_battle.id;
  END IF;

  INSERT INTO public.battle_events (battle_id, type, source_player, payload)
  VALUES (
    v_battle.id,
    'question_winner',
    v_player,
    jsonb_build_object(
      'reward_choices', to_jsonb(v_reward_choices),
      'message', upper(v_player) || ' wins coding challenge'
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'correct', true,
    'winner', v_player,
    'correct_answer', v_correct_answer,
    'correct_option', v_correct_option,
    'reward_choices', to_jsonb(v_reward_choices),
    'message', CASE
      WHEN cardinality(v_reward_choices) > 0
        THEN 'Benar! Pilih satu dari tiga bonus skill.'
      ELSE 'Correct! Kamu memenangkan coding challenge.'
    END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_battle_question_answer(text, text, text, uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_battle_question_answer(text, text, text, uuid, integer) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_battle_question_bonus_choice(
  p_code text,
  p_player text,
  p_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_player text := lower(trim(coalesce(p_player, '')));
  v_expected_token text;
  v_choice public.battle_question_bonus_choices%ROWTYPE;
  v_winner_answer integer;
BEGIN
  IF v_player NOT IN ('p1', 'p2') THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player tidak valid.');
  END IF;

  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE upper(code) = upper(trim(coalesce(p_code, '')));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  SELECT * INTO v_choice
  FROM public.battle_question_bonus_choices
  WHERE battle_id = v_battle.id AND player = v_player AND selected_skill_type IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'pending', false);
  END IF;

  SELECT winner_answer INTO v_winner_answer
  FROM public.battle_question_rounds WHERE id = v_choice.question_round_id;

  RETURN jsonb_build_object(
    'ok', true,
    'pending', true,
    'question_round_id', v_choice.question_round_id,
    'choices', to_jsonb(v_choice.skill_options),
    'winner_answer', v_winner_answer
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_battle_question_bonus_choice(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_battle_question_bonus_choice(text, text, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.choose_battle_question_bonus(
  p_code text,
  p_player text,
  p_token text,
  p_question_round_id uuid,
  p_skill_type text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_choice public.battle_question_bonus_choices%ROWTYPE;
  v_player text := lower(trim(coalesce(p_player, '')));
  v_skill_type text := lower(trim(coalesce(p_skill_type, '')));
  v_expected_token text;
BEGIN
  IF v_player NOT IN ('p1', 'p2') THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player tidak valid.');
  END IF;

  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE upper(code) = upper(trim(coalesce(p_code, '')))
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  SELECT * INTO v_choice
  FROM public.battle_question_bonus_choices
  WHERE question_round_id = p_question_round_id
    AND battle_id = v_battle.id
    AND player = v_player
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Pilihan bonus quiz tidak ditemukan.');
  END IF;

  IF v_choice.selected_skill_type IS NOT NULL THEN
    IF v_choice.selected_skill_type = v_skill_type THEN
      RETURN jsonb_build_object('ok', true, 'already_selected', true, 'skill_type', v_skill_type);
    END IF;
    RETURN jsonb_build_object('ok', false, 'message', 'Kamu sudah memilih bonus skill untuk quiz ini.');
  END IF;

  IF NOT coalesce(v_battle.question_active, false)
     OR lower(coalesce(v_battle.status, '')) = 'finished'
     OR v_battle.current_question_round_id IS DISTINCT FROM p_question_round_id THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Quiz ini tidak lagi menunggu pilihan skill.');
  END IF;

  IF NOT (v_skill_type = ANY(v_choice.skill_options)) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Skill tersebut tidak termasuk dalam pilihanmu.');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.battle_question_rounds
    WHERE id = p_question_round_id
      AND battle_id = v_battle.id
      AND winner_player = v_player
      AND status = 'won'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Pemenang quiz tidak valid.');
  END IF;

  INSERT INTO public.battle_bonus_skills (battle_id, player, skill_type, used, source)
  VALUES (v_battle.id, v_player, v_skill_type, false, 'question');

  UPDATE public.battle_question_bonus_choices
  SET selected_skill_type = v_skill_type, selected_at = now()
  WHERE question_round_id = p_question_round_id;

  UPDATE public.battle_sessions
  SET question_active = false,
      status = 'battle',
      current_question_id = NULL,
      current_question_round_id = NULL
  WHERE id = v_battle.id;

  INSERT INTO public.battle_events (battle_id, type, source_player, payload)
  VALUES (
    v_battle.id,
    'question_bonus_selected',
    v_player,
    jsonb_build_object('skill_type', v_skill_type, 'question_round_id', p_question_round_id)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'skill_type', v_skill_type,
    'message', 'Bonus skill dipilih. Battle dilanjutkan.'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.choose_battle_question_bonus(text, text, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.choose_battle_question_bonus(text, text, text, uuid, text) TO anon, authenticated, service_role;
