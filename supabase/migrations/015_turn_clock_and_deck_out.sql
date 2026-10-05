-- Server-authoritative per-turn clock, one reconnect grace per player, and
-- TCG deck-out defeat when no active/bench cards or physical deck remain.

ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS turn_duration_seconds integer NOT NULL DEFAULT 45,
  ADD COLUMN IF NOT EXISTS turn_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS turn_deadline_at timestamptz,
  ADD COLUMN IF NOT EXISTS player1_last_seen_at timestamptz,
  ADD COLUMN IF NOT EXISTS player2_last_seen_at timestamptz,
  ADD COLUMN IF NOT EXISTS player1_reconnect_grace_used boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS player2_reconnect_grace_used boolean NOT NULL DEFAULT false;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.battle_sessions'::regclass
      AND conname = 'battle_sessions_turn_duration_seconds_check'
  ) THEN
    ALTER TABLE public.battle_sessions
      ADD CONSTRAINT battle_sessions_turn_duration_seconds_check
      CHECK (turn_duration_seconds IN (30, 45, 60));
  END IF;
END;
$migration$;

CREATE OR REPLACE FUNCTION public.tcg_set_battle_turn_clock()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_turn boolean := false;
BEGIN
  IF lower(coalesce(NEW.status, '')) = 'finished'
     OR coalesce(NEW.question_active, false)
     OR lower(coalesce(NEW.status, '')) = 'question' THEN
    NEW.turn_started_at := NULL;
    NEW.turn_deadline_at := NULL;
    RETURN NEW;
  END IF;

  IF lower(coalesce(NEW.status, '')) <> 'battle'
     OR lower(coalesce(NEW.current_turn, '')) NOT IN ('p1', 'p2') THEN
    NEW.turn_started_at := NULL;
    NEW.turn_deadline_at := NULL;
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_new_turn := true;
  ELSE
    v_new_turn :=
      lower(coalesce(OLD.status, '')) IN ('waiting', 'ready', 'question')
      OR lower(coalesce(OLD.current_turn, '')) <> lower(coalesce(NEW.current_turn, ''))
      OR coalesce(OLD.question_active, false) <> coalesce(NEW.question_active, false);
  END IF;

  IF v_new_turn OR NEW.turn_deadline_at IS NULL THEN
    NEW.turn_started_at := now();
    NEW.turn_deadline_at := now()
      + make_interval(secs => greatest(30, least(60, coalesce(NEW.turn_duration_seconds, 45))));
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS battle_sessions_turn_clock_before_write ON public.battle_sessions;
CREATE TRIGGER battle_sessions_turn_clock_before_write
BEFORE INSERT OR UPDATE ON public.battle_sessions
FOR EACH ROW EXECUTE FUNCTION public.tcg_set_battle_turn_clock();

-- Give already-running battles a fresh, full turn when this migration lands.
UPDATE public.battle_sessions
SET turn_started_at = now(),
    turn_deadline_at = now() + make_interval(secs => turn_duration_seconds)
WHERE lower(coalesce(status, '')) = 'battle'
  AND NOT coalesce(question_active, false)
  AND winner IS NULL
  AND turn_deadline_at IS NULL
  AND lower(coalesce(current_turn, '')) IN ('p1', 'p2');

CREATE OR REPLACE FUNCTION public.tcg_check_battle_deck_out(p_battle_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_p1_alive integer := 0;
  v_p2_alive integer := 0;
  v_p1_out boolean := false;
  v_p2_out boolean := false;
  v_winner text;
BEGIN
  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE id = p_battle_id
  FOR UPDATE;

  IF NOT FOUND OR lower(coalesce(v_battle.status, '')) = 'finished'
     OR v_battle.winner IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'finished', false);
  END IF;

  IF lower(coalesce(v_battle.ruleset, '')) <> 'tcg_v1' THEN
    RETURN jsonb_build_object('ok', true, 'finished', false);
  END IF;

  SELECT count(*) FILTER (
           WHERE player = 'p1'
             AND (lower(coalesce(zone, '')) = 'active'
               OR (lower(coalesce(zone, '')) = 'bench'
                 AND coalesce(bench_return_count, 0) < 1
                 AND NOT coalesce(exhausted, false)))
         ),
         count(*) FILTER (
           WHERE player = 'p2'
             AND (lower(coalesce(zone, '')) = 'active'
               OR (lower(coalesce(zone, '')) = 'bench'
                 AND coalesce(bench_return_count, 0) < 1
                 AND NOT coalesce(exhausted, false)))
         )
  INTO v_p1_alive, v_p2_alive
  FROM public.battle_cards
  WHERE battle_id = v_battle.id
    AND lower(coalesce(zone, '')) IN ('active', 'bench')
    AND coalesce(current_hp, base_hp, hp, 0) > 0;

  v_p1_out := v_p1_alive = 0 AND coalesce(v_battle.player1_deck_remaining, 0) <= 0;
  v_p2_out := v_p2_alive = 0 AND coalesce(v_battle.player2_deck_remaining, 0) <= 0;

  IF NOT v_p1_out AND NOT v_p2_out THEN
    RETURN jsonb_build_object(
      'ok', true,
      'finished', false,
      'p1_playable_cards', v_p1_alive,
      'p2_playable_cards', v_p2_alive
    );
  END IF;

  v_winner := CASE
    WHEN v_p1_out AND v_p2_out THEN 'draw'
    WHEN v_p1_out THEN 'p2'
    ELSE 'p1'
  END;

  UPDATE public.battle_sessions
  SET winner = v_winner,
      status = 'finished',
      finished_at = now(),
      question_active = false,
      current_question_id = NULL,
      current_question_round_id = NULL,
      pending_action = NULL,
      pending_action_player = NULL,
      turn_deadline_at = NULL
  WHERE id = v_battle.id;

  UPDATE public.battle_status_effects
  SET active = false, remaining_turns = 0, remaining_rounds = 0
  WHERE battle_id = v_battle.id AND coalesce(active, false);

  INSERT INTO public.battle_events (battle_id, type, source_player, payload)
  VALUES (
    v_battle.id,
    'win',
    CASE WHEN v_winner IN ('p1', 'p2') THEN v_winner ELSE NULL END,
    jsonb_build_object(
      'winner', v_winner,
      'reason', 'deck_out',
      'message', CASE WHEN v_winner = 'draw' THEN 'BATTLE DRAW' ELSE upper(v_winner) || ' WINS' END
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'finished', true,
    'winner', v_winner,
    'reason', 'deck_out',
    'p1_playable_cards', v_p1_alive,
    'p2_playable_cards', v_p2_alive
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.tcg_expire_battle_turn_if_due(p_battle_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_timed_player text;
  v_next_player text;
  v_last_seen timestamptz;
  v_grace_used boolean;
  v_tick jsonb := '{}'::jsonb;
  v_round_settlement jsonb := '{}'::jsonb;
  v_deck_out jsonb := '{}'::jsonb;
  v_question_result jsonb := '{}'::jsonb;
  v_question_candidate uuid;
  v_completed_round integer;
  v_next_round integer;
  v_winner text;
  v_grace_seconds constant integer := 10;
BEGIN
  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE id = p_battle_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  IF lower(coalesce(v_battle.status, '')) <> 'battle'
     OR coalesce(v_battle.question_active, false)
     OR v_battle.winner IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'timed_out', false, 'current_turn', v_battle.current_turn,
      'question_active', coalesce(v_battle.question_active, false),
      'turn_deadline_at', v_battle.turn_deadline_at
    );
  END IF;

  IF v_battle.turn_deadline_at IS NULL THEN
    UPDATE public.battle_sessions
    SET turn_started_at = now(),
        turn_deadline_at = now() + make_interval(secs => turn_duration_seconds)
    WHERE id = v_battle.id;
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
  END IF;

  IF v_battle.turn_deadline_at > now() THEN
    RETURN jsonb_build_object(
      'ok', true, 'timed_out', false, 'current_turn', v_battle.current_turn,
      'turn_deadline_at', v_battle.turn_deadline_at
    );
  END IF;

  v_timed_player := lower(coalesce(v_battle.current_turn, ''));
  IF v_timed_player NOT IN ('p1', 'p2') THEN
    RETURN jsonb_build_object('ok', false, 'timed_out', false, 'message', 'Giliran aktif tidak valid.');
  END IF;

  v_last_seen := CASE WHEN v_timed_player = 'p1'
    THEN v_battle.player1_last_seen_at ELSE v_battle.player2_last_seen_at END;
  v_grace_used := CASE WHEN v_timed_player = 'p1'
    THEN coalesce(v_battle.player1_reconnect_grace_used, false)
    ELSE coalesce(v_battle.player2_reconnect_grace_used, false) END;

  -- A disconnected player gets one 10 second reconnection window per battle.
  IF (v_last_seen IS NULL OR v_last_seen < now() - interval '8 seconds') AND NOT v_grace_used THEN
    IF v_timed_player = 'p1' THEN
      UPDATE public.battle_sessions
      SET player1_reconnect_grace_used = true,
          turn_deadline_at = v_battle.turn_deadline_at + make_interval(secs => v_grace_seconds)
      WHERE id = v_battle.id;
    ELSE
      UPDATE public.battle_sessions
      SET player2_reconnect_grace_used = true,
          turn_deadline_at = v_battle.turn_deadline_at + make_interval(secs => v_grace_seconds)
      WHERE id = v_battle.id;
    END IF;

    INSERT INTO public.battle_events (battle_id, type, source_player, payload)
    VALUES (
      v_battle.id, 'turn_reconnect_grace', v_timed_player,
      jsonb_build_object('player', v_timed_player, 'seconds', v_grace_seconds, 'message', 'RECONNECT GRACE')
    );

    RETURN jsonb_build_object(
      'ok', true, 'timed_out', false, 'grace_granted', true,
      'timed_player', v_timed_player, 'grace_seconds', v_grace_seconds,
      'turn_deadline_at', v_battle.turn_deadline_at + make_interval(secs => v_grace_seconds)
    );
  END IF;

  -- Timeout behaves like ending the current player's turn: expire their
  -- one-turn statuses, and settle the round when P2's turn ends.
  v_tick := public.tcg_tick_statuses_for_player(v_battle.id, v_timed_player);
  IF v_timed_player = 'p2' THEN
    v_round_settlement := public.tcg_settle_fire_round(v_battle.id, coalesce(v_battle.round, 1));
  END IF;

  v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
  IF coalesce((v_deck_out->>'finished')::boolean, false) THEN
    RETURN jsonb_build_object(
      'ok', true, 'timed_out', true, 'timed_player', v_timed_player,
      'winner', v_deck_out->>'winner', 'reason', 'deck_out',
      'status_tick', v_tick, 'round_settlement', v_round_settlement
    );
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id FOR UPDATE;
  v_completed_round := greatest(1, coalesce(v_battle.round, 1));

  IF v_timed_player = 'p2'
     AND v_completed_round >= greatest(1, coalesce(v_battle.total_rounds, 10)) THEN
    v_winner := CASE
      WHEN coalesce(v_battle.player1_hp, 0) > coalesce(v_battle.player2_hp, 0) THEN 'p1'
      WHEN coalesce(v_battle.player2_hp, 0) > coalesce(v_battle.player1_hp, 0) THEN 'p2'
      ELSE 'draw'
    END;

    UPDATE public.battle_sessions
    SET winner = v_winner,
        status = 'finished',
        finished_at = now(),
        question_active = false,
        current_question_id = NULL,
        current_question_round_id = NULL,
        pending_action = NULL,
        pending_action_player = NULL,
        turn_deadline_at = NULL
    WHERE id = v_battle.id;

    UPDATE public.battle_status_effects
    SET active = false, remaining_turns = 0, remaining_rounds = 0
    WHERE battle_id = v_battle.id AND coalesce(active, false);

    INSERT INTO public.battle_events (battle_id, type, source_player, payload)
    VALUES (
      v_battle.id, 'win', CASE WHEN v_winner IN ('p1', 'p2') THEN v_winner ELSE NULL END,
      jsonb_build_object('winner', v_winner, 'reason', 'round_limit_timeout', 'message',
        CASE WHEN v_winner = 'draw' THEN 'BATTLE DRAW' ELSE upper(v_winner) || ' WINS' END)
    );

    RETURN jsonb_build_object(
      'ok', true, 'timed_out', true, 'timed_player', v_timed_player,
      'winner', v_winner, 'reason', 'round_limit', 'status_tick', v_tick,
      'round_settlement', v_round_settlement
    );
  END IF;

  v_next_player := CASE WHEN v_timed_player = 'p1' THEN 'p2' ELSE 'p1' END;
  v_next_round := CASE WHEN v_timed_player = 'p2' THEN v_completed_round + 1 ELSE v_completed_round END;

  UPDATE public.battle_sessions
  SET current_turn = v_next_player,
      round = v_next_round,
      pending_action = NULL,
      pending_action_player = NULL,
      question_active = false,
      current_question_id = NULL,
      current_question_round_id = NULL,
      status = 'battle'
  WHERE id = v_battle.id;

  INSERT INTO public.battle_events (battle_id, type, source_player, target_player, payload)
  VALUES (
    v_battle.id, 'turn_timeout', v_timed_player, v_next_player,
    jsonb_build_object(
      'timed_player', v_timed_player, 'next_turn', v_next_player,
      'round', v_next_round, 'message', upper(v_timed_player) || ' TURN TIMEOUT'
    )
  );

  -- A question starts at the same completed-round boundary as a normal P2 action.
  IF v_timed_player = 'p2'
     AND coalesce(v_battle.question_enabled, false)
     AND greatest(0, coalesce(v_battle.question_every_rounds, 0)) > 0
     AND mod(v_completed_round, v_battle.question_every_rounds) = 0 THEN
    v_question_result := public.start_battle_question(v_battle.id, v_completed_round);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;

    IF coalesce(v_battle.question_active, false)
       AND v_battle.current_question_round_id IS NOT NULL
       AND coalesce(cardinality(v_battle.question_topics), 0) > 0 THEN
      SELECT cq.id INTO v_question_candidate
      FROM public.coding_questions cq
      WHERE coalesce(cq.is_active, true)
        AND lower(coalesce(cq.category, '')) = ANY(v_battle.question_topics)
        AND (
          lower(coalesce(v_battle.question_level, 'medium')) = 'mixed'
          OR lower(coalesce(cq.difficulty, 'medium')) = lower(coalesce(v_battle.question_level, 'medium'))
        )
      ORDER BY random()
      LIMIT 1;

      IF v_question_candidate IS NOT NULL THEN
        UPDATE public.battle_question_rounds
        SET question_id = v_question_candidate
        WHERE id = v_battle.current_question_round_id
          AND battle_id = v_battle.id
          AND status = 'active';
        UPDATE public.battle_sessions
        SET current_question_id = v_question_candidate
        WHERE id = v_battle.id;
      END IF;
    END IF;
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = p_battle_id;
  RETURN jsonb_build_object(
    'ok', true, 'timed_out', true, 'timed_player', v_timed_player,
    'current_turn', v_battle.current_turn, 'round', v_battle.round,
    'question_active', coalesce(v_battle.question_active, false),
    'turn_deadline_at', v_battle.turn_deadline_at,
    'status_tick', v_tick, 'round_settlement', v_round_settlement,
    'question', v_question_result
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.tcg_sync_battle_turn(
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
  v_expiry jsonb;
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

  v_expected_token := CASE WHEN v_player = 'p1'
    THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  v_expiry := public.tcg_expire_battle_turn_if_due(v_battle.id);
  IF NOT coalesce((v_expiry->>'ok')::boolean, false) THEN
    RETURN v_expiry;
  END IF;

  IF v_player = 'p1' THEN
    UPDATE public.battle_sessions SET player1_last_seen_at = now() WHERE id = v_battle.id;
  ELSE
    UPDATE public.battle_sessions SET player2_last_seen_at = now() WHERE id = v_battle.id;
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
  RETURN coalesce(v_expiry, '{}'::jsonb) || jsonb_build_object(
    'ok', true,
    'current_turn', v_battle.current_turn,
    'status', v_battle.status,
    'question_active', coalesce(v_battle.question_active, false),
    'turn_duration_seconds', v_battle.turn_duration_seconds,
    'turn_started_at', v_battle.turn_started_at,
    'turn_deadline_at', v_battle.turn_deadline_at,
    'winner', v_battle.winner,
    'server_now', now()
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.tcg_check_battle_deck_out(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tcg_expire_battle_turn_if_due(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tcg_sync_battle_turn(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.tcg_sync_battle_turn(text, text, text) TO anon, authenticated, service_role;

-- Keep the existing combat/question/passive wrapper intact beneath a new
-- token-validated entry point that first enforces the shared turn clock.
DO $migration$
BEGIN
  IF to_regprocedure('public.submit_battle_action_pre_turn_clock(text,text,text,text,uuid,jsonb)') IS NULL
     AND to_regprocedure('public.submit_battle_action(text,text,text,text,uuid,jsonb)') IS NOT NULL THEN
    ALTER FUNCTION public.submit_battle_action(text, text, text, text, uuid, jsonb)
      RENAME TO submit_battle_action_pre_turn_clock;
  END IF;
END;
$migration$;

REVOKE ALL ON FUNCTION public.submit_battle_action_pre_turn_clock(text, text, text, text, uuid, jsonb)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_battle_action(
  p_code text,
  p_player text,
  p_token text,
  p_action text,
  p_card_id uuid DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_player text := lower(trim(coalesce(p_player, '')));
  v_guard jsonb;
  v_battle public.battle_sessions%ROWTYPE;
  v_response jsonb;
  v_deck_out jsonb := '{}'::jsonb;
BEGIN
  v_guard := public.tcg_sync_battle_turn(p_code, p_player, p_token);
  IF NOT coalesce((v_guard->>'ok')::boolean, false) THEN
    RETURN v_guard;
  END IF;

  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE upper(code) = upper(trim(coalesce(p_code, '')));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  IF v_battle.winner IS NOT NULL OR lower(coalesce(v_battle.status, '')) = 'finished' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle sudah selesai.');
  END IF;

  IF coalesce((v_guard->>'timed_out')::boolean, false)
     AND lower(coalesce(v_battle.current_turn, '')) <> v_player THEN
    RETURN jsonb_build_object(
      'ok', false, 'turn_expired', true,
      'message', 'Waktu giliran habis. Giliran sudah berpindah ke lawan.'
    );
  END IF;

  v_response := public.submit_battle_action_pre_turn_clock(
    p_code, p_player, p_token, p_action, p_card_id, coalesce(p_payload, '{}'::jsonb)
  );

  IF NOT coalesce((v_response->>'ok')::boolean, false) THEN
    RETURN v_response;
  END IF;

  v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;

  RETURN v_response || jsonb_build_object(
    'deck_out', v_deck_out,
    'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
    'finished', lower(coalesce(v_battle.status, '')) = 'finished'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_battle_action(text, text, text, text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_battle_action(text, text, text, text, uuid, jsonb)
  TO anon, authenticated, service_role;

-- RFID scans arrive through the hardware event pipeline, so enforce the same
-- timeout before the existing UID/binding checks consume a card from a deck.
DO $migration$
BEGIN
  IF to_regprocedure('public.process_multiplayer_rfid_scan_pre_turn_clock(text,text)') IS NULL
     AND to_regprocedure('public.process_multiplayer_rfid_scan(text,text)') IS NOT NULL THEN
    ALTER FUNCTION public.process_multiplayer_rfid_scan(text, text)
      RENAME TO process_multiplayer_rfid_scan_pre_turn_clock;
  END IF;
END;
$migration$;

REVOKE ALL ON FUNCTION public.process_multiplayer_rfid_scan_pre_turn_clock(text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.process_multiplayer_rfid_scan(
  p_uid text,
  p_device_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle_id uuid;
BEGIN
  SELECT battle_id INTO v_battle_id
  FROM public.battle_reader_bindings
  WHERE device_id = trim(coalesce(p_device_id, ''))
    AND coalesce(active, false)
  LIMIT 1;

  IF v_battle_id IS NOT NULL THEN
    PERFORM public.tcg_expire_battle_turn_if_due(v_battle_id);
  END IF;

  RETURN public.process_multiplayer_rfid_scan_pre_turn_clock(p_uid, p_device_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_multiplayer_rfid_scan(text, text) TO anon, authenticated, service_role;

COMMENT ON COLUMN public.battle_sessions.turn_duration_seconds IS 'Per-turn clock duration in seconds (30, 45, or 60).';
COMMENT ON COLUMN public.battle_sessions.turn_deadline_at IS 'Server-authoritative deadline for the current turn; NULL while waiting, finished, or a quiz is active.';
COMMENT ON COLUMN public.battle_sessions.player1_reconnect_grace_used IS 'Whether player 1 has used their one 10-second reconnect grace for this battle.';
COMMENT ON COLUMN public.battle_sessions.player2_reconnect_grace_used IS 'Whether player 2 has used their one 10-second reconnect grace for this battle.';
