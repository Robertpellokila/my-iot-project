BEGIN;

-- TCG v1 tactical turn system: 1 Active + 2 Bench, 2 AP per turn,
-- once-per-turn attacks, assisted combo attacks, and explicit turn passing.

ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS action_points_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS player1_action_points integer NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS player2_action_points integer NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS turn_index bigint NOT NULL DEFAULT 1;

ALTER TABLE public.battle_cards
  ADD COLUMN IF NOT EXISTS last_attacked_turn bigint,
  ADD COLUMN IF NOT EXISTS combo_assist_turn bigint;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.battle_sessions'::regclass
      AND conname = 'battle_sessions_action_points_check'
  ) THEN
    ALTER TABLE public.battle_sessions
      ADD CONSTRAINT battle_sessions_action_points_check
      CHECK (player1_action_points BETWEEN 0 AND 2
         AND player2_action_points BETWEEN 0 AND 2);
  END IF;
END;
$migration$;

COMMENT ON COLUMN public.battle_sessions.action_points_enabled IS
  'Enables the AP tactical ruleset for newly configured TCG battles.';
COMMENT ON COLUMN public.battle_sessions.turn_index IS
  'Monotonic player-turn number used for once-per-turn attack and combo tracking.';

-- Type pair effects are intentionally immediate; no status is left behind by a combo.
CREATE TABLE IF NOT EXISTS public.tcg_type_combo_rules (
  element_a text NOT NULL,
  element_b text NOT NULL,
  combo_name text NOT NULL,
  bonus_damage integer NOT NULL DEFAULT 0,
  defense_ignore_pct numeric(4,3) NOT NULL DEFAULT 0,
  heal_after integer NOT NULL DEFAULT 0,
  PRIMARY KEY (element_a, element_b),
  CHECK (element_a < element_b),
  CHECK (bonus_damage >= 0),
  CHECK (defense_ignore_pct >= 0 AND defense_ignore_pct <= 1),
  CHECK (heal_after >= 0)
);

INSERT INTO public.tcg_type_combo_rules
  (element_a, element_b, combo_name, bonus_damage, defense_ignore_pct, heal_after)
VALUES
  ('dark', 'electric', 'Shadow Blitz', 0, 0.50, 0),
  ('dark', 'fire', 'Inferno Curse', 12, 0, 0),
  ('dark', 'water', 'Abyss Tide', 8, 0, 0),
  ('dark', 'wind', 'Void Gale', 10, 0, 0),
  ('electric', 'fire', 'Overcharge Flame', 10, 0, 0),
  ('electric', 'grass', 'Root Circuit', 8, 0, 0),
  ('electric', 'water', 'Electro Surge', 8, 0, 0),
  ('electric', 'wind', 'Thunder Gale', 10, 0, 0),
  ('fire', 'grass', 'Wildfire Canopy', 8, 0, 0),
  ('fire', 'water', 'Steam Break', 10, 0, 0),
  ('fire', 'wind', 'Wildfire Gale', 10, 0, 0),
  ('grass', 'water', 'Nature Recovery', 0, 0, 15),
  ('dark', 'fusion', 'Assist Attack', 0, 0, 0),
  ('dark', 'grass', 'Assist Attack', 0, 0, 0),
  ('electric', 'fusion', 'Assist Attack', 0, 0, 0),
  ('fire', 'fusion', 'Assist Attack', 0, 0, 0),
  ('fusion', 'grass', 'Assist Attack', 0, 0, 0),
  ('fusion', 'water', 'Assist Attack', 0, 0, 0),
  ('fusion', 'wind', 'Assist Attack', 0, 0, 0),
  ('grass', 'wind', 'Assist Attack', 0, 0, 0),
  ('water', 'wind', 'Assist Attack', 0, 0, 0)
ON CONFLICT (element_a, element_b) DO UPDATE
SET combo_name = EXCLUDED.combo_name,
    bonus_damage = EXCLUDED.bonus_damage,
    defense_ignore_pct = EXCLUDED.defense_ignore_pct,
    heal_after = EXCLUDED.heal_after;

-- The core action executor temporarily changes current_turn while it applies
-- the legacy action. During that internal step, keep the real turn timer intact.
CREATE OR REPLACE FUNCTION public.tcg_set_battle_turn_clock()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_turn boolean := false;
  v_player_turn_changed boolean := false;
  v_ap_turn_start boolean := false;
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

  IF current_setting('tcg.intra_turn_action', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_new_turn := true;
    v_ap_turn_start := lower(coalesce(NEW.status, '')) = 'battle';
  ELSE
    v_player_turn_changed :=
      lower(coalesce(OLD.current_turn, '')) <> lower(coalesce(NEW.current_turn, ''));
    v_ap_turn_start := v_player_turn_changed
      OR (lower(coalesce(OLD.status, '')) IN ('waiting', 'ready', 'question')
        AND lower(coalesce(NEW.status, '')) = 'battle');
    v_new_turn :=
      lower(coalesce(OLD.status, '')) IN ('waiting', 'ready', 'question')
      OR v_player_turn_changed
      OR coalesce(OLD.question_active, false) <> coalesce(NEW.question_active, false);
  END IF;

  -- The AP pool and per-turn card markers follow every real turn transition,
  -- including a timeout. Legacy core transitions are suppressed above.
  IF coalesce(NEW.action_points_enabled, false)
     AND lower(coalesce(NEW.ruleset, '')) = 'tcg_v1'
     AND lower(coalesce(NEW.current_turn, '')) IN ('p1', 'p2')
     AND v_ap_turn_start THEN
    IF TG_OP = 'UPDATE' AND v_player_turn_changed THEN
      NEW.turn_index := greatest(1, coalesce(OLD.turn_index, 1)) + 1;
    ELSE
      NEW.turn_index := greatest(1, coalesce(NEW.turn_index, 1));
    END IF;
    NEW.player1_action_points := CASE WHEN lower(NEW.current_turn) = 'p1' THEN 2 ELSE 0 END;
    NEW.player2_action_points := CASE WHEN lower(NEW.current_turn) = 'p2' THEN 2 ELSE 0 END;
  END IF;

  IF v_new_turn OR NEW.turn_deadline_at IS NULL THEN
    NEW.turn_started_at := now();
    NEW.turn_deadline_at := now()
      + make_interval(secs => greatest(30, least(60, coalesce(NEW.turn_duration_seconds, 45))));
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.tcg_finish_action_point_turn(
  p_battle_id uuid,
  p_player text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_next_player text;
  v_completed_round integer;
  v_next_round integer;
  v_winner text;
  v_question_result jsonb := '{}'::jsonb;
  v_deck_out jsonb := '{}'::jsonb;
  v_topic_question uuid;
BEGIN
  SELECT * INTO v_battle
  FROM public.battle_sessions
  WHERE id = p_battle_id
  FOR UPDATE;

  IF NOT FOUND OR lower(coalesce(v_battle.status, '')) <> 'battle'
     OR lower(coalesce(v_battle.current_turn, '')) <> lower(coalesce(p_player, '')) THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Giliran tidak dapat diakhiri.');
  END IF;

  IF coalesce(v_battle.pending_action, '') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Selesaikan scan RFID yang tertunda terlebih dahulu.');
  END IF;

  PERFORM public.tcg_tick_statuses_for_player(v_battle.id, p_player);
  v_next_player := CASE WHEN p_player = 'p1' THEN 'p2' ELSE 'p1' END;
  v_completed_round := greatest(1, coalesce(v_battle.round, 1));
  v_next_round := v_completed_round;

  IF p_player = 'p2' THEN
    PERFORM public.tcg_settle_fire_round(v_battle.id, v_completed_round);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = p_battle_id FOR UPDATE;

    IF v_completed_round >= coalesce(v_battle.total_rounds, 10) THEN
      v_winner := CASE
        WHEN v_battle.player1_hp > v_battle.player2_hp THEN 'p1'
        WHEN v_battle.player2_hp > v_battle.player1_hp THEN 'p2'
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
             player1_action_points = 0,
             player2_action_points = 0,
             turn_deadline_at = NULL
       WHERE id = p_battle_id;
      UPDATE public.battle_status_effects
         SET active = false, remaining_turns = 0, remaining_rounds = 0
       WHERE battle_id = p_battle_id AND coalesce(active, false);
      INSERT INTO public.battle_events (battle_id, type, source_player, payload)
      VALUES (p_battle_id, 'win', CASE WHEN v_winner IN ('p1','p2') THEN v_winner ELSE NULL END,
        jsonb_build_object('winner', v_winner, 'reason', 'round_limit',
          'message', CASE WHEN v_winner = 'draw' THEN 'BATTLE DRAW' ELSE upper(v_winner) || ' WINS' END));
      RETURN jsonb_build_object('ok', true, 'finished', true, 'winner', v_winner, 'round', v_completed_round);
    END IF;

    v_next_round := v_completed_round + 1;
  END IF;

  PERFORM set_config('tcg.intra_turn_action', 'off', true);
  UPDATE public.battle_sessions
     SET current_turn = v_next_player,
         round = v_next_round,
         status = 'battle',
         player1_action_points = CASE WHEN v_next_player = 'p1' THEN 2 ELSE 0 END,
         player2_action_points = CASE WHEN v_next_player = 'p2' THEN 2 ELSE 0 END
   WHERE id = p_battle_id;

  INSERT INTO public.battle_events (battle_id, type, source_player, payload)
  VALUES (p_battle_id, 'turn_end', p_player,
    jsonb_build_object('player', p_player, 'next_turn', v_next_player,
      'round', v_next_round, 'message', upper(p_player) || ' TURN ENDED'));

  v_deck_out := public.tcg_check_battle_deck_out(p_battle_id);
  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = p_battle_id;
  IF lower(coalesce(v_battle.status, '')) = 'finished' THEN
    RETURN jsonb_build_object('ok', true, 'finished', true,
      'winner', v_battle.winner, 'round', v_battle.round, 'deck_out', v_deck_out);
  END IF;

  IF p_player = 'p2'
     AND coalesce(v_battle.question_enabled, false)
     AND coalesce(v_battle.question_every_rounds, 0) > 0
     AND mod(v_completed_round, v_battle.question_every_rounds) = 0 THEN
    v_question_result := public.start_battle_question(p_battle_id, v_completed_round);

    -- Keep the configured topic filter when the fallback scheduler selects a question.
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = p_battle_id;
    IF coalesce(v_battle.question_active, false)
       AND coalesce(cardinality(v_battle.question_topics), 0) > 0
       AND v_battle.current_question_round_id IS NOT NULL THEN
      SELECT cq.id INTO v_topic_question
        FROM public.coding_questions cq
       WHERE coalesce(cq.is_active, true)
         AND lower(coalesce(cq.category, '')) = ANY(v_battle.question_topics)
         AND (lower(coalesce(v_battle.question_level, 'medium')) = 'mixed'
           OR lower(coalesce(cq.difficulty, 'medium')) = lower(coalesce(v_battle.question_level, 'medium')))
       ORDER BY random()
       LIMIT 1;
    IF v_topic_question IS NOT NULL THEN
        UPDATE public.battle_question_rounds
           SET question_id = v_topic_question
         WHERE id = v_battle.current_question_round_id
           AND battle_id = p_battle_id AND status = 'active';
        UPDATE public.battle_sessions SET current_question_id = v_topic_question WHERE id = p_battle_id;
      END IF;
    END IF;
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = p_battle_id;

  RETURN jsonb_build_object('ok', true, 'turn_completed', true,
    'next_turn', v_next_player, 'round', v_next_round,
    'question_active', coalesce(v_battle.question_active, false),
    'deck_out', v_deck_out);
END;
$function$;

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
  v_action text := lower(trim(coalesce(p_action, '')));
  v_guard jsonb;
  v_battle public.battle_sessions%ROWTYPE;
  v_card public.battle_cards%ROWTYPE;
  v_bench public.battle_cards%ROWTYPE;
  v_target public.battle_cards%ROWTYPE;
  v_response jsonb;
  v_finish jsonb := '{}'::jsonb;
  v_deck_out jsonb := '{}'::jsonb;
  v_cost integer := 1;
  v_ap integer := 0;
  v_ap_after integer := 0;
  v_old_round integer := 1;
  v_old_total_rounds integer := 10;
  v_old_question_enabled boolean := false;
  v_old_question_active boolean := false;
  v_old_question_id uuid;
  v_old_question_round_id uuid;
  v_old_status text;
  v_expected_token text;
  v_target_id uuid;
  v_bench_id uuid;
  v_skill_id uuid;
  v_target_hp_before integer;
  v_target_hp_after integer;
  v_active_attack integer;
  v_bench_attack integer;
  v_target_defense integer;
  v_effective_defense integer;
  v_damage integer;
  v_player_damage integer := 0;
  v_bonus integer := 0;
  v_heal integer := 0;
  v_defense_ignore numeric := 0;
  v_combo_name text := 'Assist Attack';
  v_element_a text;
  v_element_b text;
  v_enemy text;
  v_enemy_active_count integer := 0;
  v_bench_count integer := 0;
  v_destroyed boolean := false;
  v_effective_damage integer := 0;
  v_destruction_pct numeric := 0;
  v_turn_completed boolean := false;
  v_pending_summon boolean := false;
  v_action_block text;
BEGIN
  v_guard := public.tcg_sync_battle_turn(p_code, p_player, p_token);
  IF NOT coalesce((v_guard->>'ok')::boolean, false) THEN
    RETURN v_guard;
  END IF;

  SELECT * INTO v_battle
    FROM public.battle_sessions
   WHERE upper(code) = upper(trim(coalesce(p_code, '')))
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  IF v_battle.winner IS NOT NULL OR lower(coalesce(v_battle.status, '')) = 'finished' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle sudah selesai.');
  END IF;
  IF v_player NOT IN ('p1', 'p2') OR lower(coalesce(v_battle.current_turn, '')) <> v_player THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Belum giliran kamu.');
  END IF;

  IF NOT coalesce(v_battle.action_points_enabled, false)
     OR lower(coalesce(v_battle.ruleset, '')) <> 'tcg_v1' THEN
    v_response := public.submit_battle_action_pre_turn_clock(
      p_code, p_player, p_token, p_action, p_card_id, coalesce(p_payload, '{}'::jsonb)
    );
    IF NOT coalesce((v_response->>'ok')::boolean, false) THEN RETURN v_response; END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN v_response || jsonb_build_object(
      'deck_out', v_deck_out,
      'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
      'finished', lower(coalesce(v_battle.status, '')) = 'finished'
    );
  END IF;

  IF coalesce(v_battle.question_active, false) OR lower(coalesce(v_battle.status, '')) = 'question' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Selesaikan kuis sebelum melanjutkan turn.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  v_ap := CASE WHEN v_player = 'p1' THEN coalesce(v_battle.player1_action_points, 0)
               ELSE coalesce(v_battle.player2_action_points, 0) END;

  IF v_action IN ('end_turn', 'pass_turn') THEN
    v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    RETURN v_finish || jsonb_build_object(
      'action', 'end_turn',
      'action_points', 0,
      'message', CASE WHEN coalesce((v_finish->>'ok')::boolean, false) THEN 'Turn diakhiri.' ELSE v_finish->>'message' END
    );
  END IF;

  IF v_action = 'defense' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'DEFENSE_IS_PASSIVE',
      'message', 'Defense berasal dari stat DEF dan efek Shield pada kartu; tidak memakai AP sebagai aksi biasa.');
  END IF;

  v_cost := CASE
    WHEN v_action IN ('fusion', 'ultimate', 'combo_attack') THEN 2
    WHEN v_action IN ('attack', 'heal', 'synergy', 'summon', 'move_to_bench', 'return_from_bench', 'switch_active') THEN 1
    ELSE 0
  END;
  IF v_action = 'special_skill' THEN
    BEGIN
      v_skill_id := nullif(trim(coalesce(p_payload->>'skill_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      v_skill_id := NULL;
    END;
    v_cost := 1;
    IF v_skill_id IS NOT NULL THEN
      SELECT CASE
          WHEN coalesce(skill.limits->>'action_points', '') ~ '^[12]$'
            THEN (skill.limits->>'action_points')::integer
          ELSE 1
        END
        INTO v_cost
        FROM public.battle_cards bc
        JOIN public.game_card_special_skills card_skill
          ON card_skill.game_card_id = bc.game_card_id
         AND coalesce(card_skill.enabled, true)
        JOIN public.special_skills skill
          ON skill.id = card_skill.special_skill_id
         AND skill.id = v_skill_id
         AND coalesce(skill.is_active, false)
         AND coalesce(skill.catalog_status, 'active') = 'active'
         AND coalesce(skill.activation_timing, 'main_phase') = 'main_phase'
       WHERE bc.id = p_card_id AND bc.battle_id = v_battle.id;
      IF NOT FOUND THEN v_cost := 1; END IF;
    END IF;
  END IF;
  IF v_cost = 0 THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Aksi tidak dikenal.');
  END IF;
  IF v_ap < v_cost THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_ENOUGH_ACTION_POINTS',
      'message', format('Aksi ini membutuhkan %s AP; tersisa %s AP.', v_cost, v_ap), 'action_points', v_ap);
  END IF;

  v_ap_after := v_ap - v_cost;
  v_enemy := CASE WHEN v_player = 'p1' THEN 'p2' ELSE 'p1' END;

  -- Position changes are resolved here so a TCG action consumes AP without
  -- invoking the legacy one-action turn transition.
  IF v_action IN ('move_to_bench', 'return_from_bench', 'switch_active') THEN
    IF p_card_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu yang akan dipindahkan.');
    END IF;

    IF v_action = 'move_to_bench' THEN
      SELECT * INTO v_card FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_card.id IS NULL OR v_card.zone <> 'active'
         OR coalesce(v_card.current_hp, v_card.base_hp, v_card.hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu Active yang masih dapat bertarung.');
      END IF;
      SELECT count(*) INTO v_bench_count FROM public.battle_cards
       WHERE battle_id = v_battle.id AND player = v_player AND zone = 'bench'
         AND coalesce(current_hp, base_hp, hp, 0) > 0;
      IF v_bench_count >= greatest(0, coalesce(v_battle.max_bench, 2)) THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Bench penuh.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_card.id, 'move_to_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'bench', slot = NULL
       WHERE id = v_card.id;
      v_response := jsonb_build_object('action', v_action, 'message', v_card.name || ' dipindahkan ke Bench.');

    ELSIF v_action = 'return_from_bench' THEN
      SELECT * INTO v_bench FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_bench.id IS NULL OR v_bench.zone <> 'bench'
         OR coalesce(v_bench.current_hp, v_bench.base_hp, v_bench.hp, 0) <= 0
         OR coalesce(v_bench.exhausted, false) THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Kartu Bench ini sudah tidak dapat kembali ke Active.');
      END IF;
      IF EXISTS (SELECT 1 FROM public.battle_cards c
          WHERE c.battle_id = v_battle.id AND c.player = v_player AND c.zone = 'active'
            AND coalesce(c.current_hp, c.base_hp, c.hp, 0) > 0) THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Active masih terisi. Pilih Switch Active untuk menukar posisi.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench.id, 'return_from_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'active', slot = 1
       WHERE id = v_bench.id;
      v_response := jsonb_build_object('action', v_action, 'message', v_bench.name || ' kembali ke Active.');

    ELSE
      BEGIN
        v_target_id := nullif(trim(coalesce(p_payload->>'active_card_id', '')), '')::uuid;
      EXCEPTION WHEN invalid_text_representation THEN
        v_target_id := NULL;
      END;
      IF v_target_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu Active dan Bench untuk bertukar posisi.');
      END IF;
      SELECT * INTO v_bench FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      SELECT * INTO v_card FROM public.battle_cards
       WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_bench.id IS NULL OR v_bench.zone <> 'bench'
         OR coalesce(v_bench.current_hp, v_bench.base_hp, v_bench.hp, 0) <= 0
         OR coalesce(v_bench.exhausted, false)
         OR v_card.id IS NULL OR v_card.zone <> 'active'
         OR coalesce(v_card.current_hp, v_card.base_hp, v_card.hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Kartu Active atau Bench sudah berubah atau tidak dapat bertarung.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_card.id, 'move_to_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench.id, 'return_from_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'bench', slot = NULL
       WHERE id = v_card.id;
      UPDATE public.battle_cards
         SET zone = 'active', slot = 1
       WHERE id = v_bench.id;
      v_response := jsonb_build_object('action', v_action,
        'message', v_bench.name || ' bertukar posisi dengan ' || v_card.name);
    END IF;

    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, card_id, payload)
    VALUES (v_battle.id, 'card_move', v_player, p_card_id,
      coalesce(v_response, '{}'::jsonb) || jsonb_build_object('action_points_spent', 1));
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    IF v_ap_after = 0 AND lower(coalesce(v_battle.status, '')) <> 'finished' THEN
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN coalesce(v_response, '{}'::jsonb) || jsonb_build_object(
      'ok', true,
      'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
      'next_turn', v_battle.current_turn, 'round', v_battle.round,
      'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
      'deck_out', v_deck_out, 'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
      'finished', lower(coalesce(v_battle.status, '')) = 'finished');
  END IF;

  -- Summon is completed by the RFID scan pipeline. Charge its AP now and
  -- keep the current turn locked until the physical card is scanned.
  IF v_action = 'summon' THEN
    IF coalesce(v_battle.pending_action, '') <> '' THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Selesaikan aksi RFID yang tertunda terlebih dahulu.');
    END IF;
    IF (CASE WHEN v_player = 'p1' THEN coalesce(v_battle.player1_deck_remaining, 0)
             ELSE coalesce(v_battle.player2_deck_remaining, 0) END) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'message', 'DECK EMPTY');
    END IF;
    IF (SELECT count(*) FROM public.battle_cards c WHERE c.battle_id = v_battle.id
          AND c.player = v_player AND c.zone IN ('active', 'bench') AND coalesce(c.current_hp, c.base_hp, c.hp, 0) > 0)
       >= coalesce(v_battle.max_active, 1) + coalesce(v_battle.max_bench, 2) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'ACTIVE DECK + BENCH FULL');
    END IF;
    UPDATE public.battle_sessions
       SET pending_action = 'summon', pending_action_player = v_player,
           player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, payload)
    VALUES (v_battle.id, 'action_request', v_player,
      jsonb_build_object('action', 'summon', 'action_points_spent', 1,
        'message', 'SCAN RFID TO SUMMON; card goes to Active if open, otherwise Bench'));
    RETURN jsonb_build_object('ok', true, 'action', 'summon', 'waiting_rfid', true,
      'action_points', v_ap_after, 'message', 'Summon siap. Scan RFID untuk mengambil kartu ke arena.');
  END IF;

  IF v_action = 'combo_attack' THEN
    IF NOT coalesce(v_battle.combo_enabled, true) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Combo Attack dinonaktifkan untuk battle ini.');
    END IF;
    BEGIN
      v_bench_id := nullif(trim(coalesce(p_payload->>'bench_card_id', '')), '')::uuid;
      v_target_id := nullif(trim(coalesce(p_payload->>'target_card_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilihan kartu combo tidak valid.');
    END;
    IF p_card_id IS NULL OR v_bench_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilih satu Active Card dan satu Bench Card.');
    END IF;
    SELECT * INTO v_card FROM public.battle_cards WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
    SELECT * INTO v_bench FROM public.battle_cards WHERE id = v_bench_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
    IF v_card.id IS NULL OR v_bench.id IS NULL
       OR v_card.zone <> 'active' OR v_bench.zone <> 'bench'
       OR coalesce(v_card.current_hp, v_card.base_hp, 0) <= 0
       OR coalesce(v_bench.current_hp, v_bench.base_hp, 0) <= 0
       OR coalesce(v_card.exhausted, false) OR coalesce(v_bench.exhausted, false) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Combo membutuhkan Active Card dan Bench Card yang masih dapat bertarung.');
    END IF;
    IF coalesce(v_card.last_attacked_turn, -1) = coalesce(v_battle.turn_index, 1) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Active Card ini sudah menyerang pada turn ini.');
    END IF;
    IF coalesce(v_bench.combo_assist_turn, -1) = coalesce(v_battle.turn_index, 1) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Bench Card ini sudah membantu combo pada turn ini.');
    END IF;
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, p_card_id, 'combo_attack');
    IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench_id, 'combo_attack');
    IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

    SELECT count(*) INTO v_enemy_active_count FROM public.battle_cards c
      WHERE c.battle_id = v_battle.id AND c.player = v_enemy AND c.zone = 'active'
        AND NOT coalesce(c.exhausted, false) AND coalesce(c.current_hp, c.base_hp, 0) > 0;
    IF v_target_id IS NULL AND v_enemy_active_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'requires_target', true, 'message', 'Pilih Active Card lawan sebagai target combo.');
    END IF;
    IF v_target_id IS NULL AND (NOT coalesce(v_battle.direct_attack_enabled, true)) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Direct Attack dinonaktifkan.');
    END IF;
    IF v_target_id IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_enemy FOR UPDATE;
      IF NOT FOUND OR v_target.zone <> 'active' OR coalesce(v_target.exhausted, false)
         OR coalesce(v_target.current_hp, v_target.base_hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Target harus Active Card lawan yang masih bertarung.');
      END IF;
    END IF;

    v_element_a := lower(trim(coalesce(v_card.element, '')));
    v_element_b := lower(trim(coalesce(v_bench.element, '')));
    SELECT r.combo_name, r.bonus_damage, r.defense_ignore_pct, r.heal_after
      INTO v_combo_name, v_bonus, v_defense_ignore, v_heal
      FROM public.tcg_type_combo_rules r
     WHERE r.element_a = least(v_element_a, v_element_b)
       AND r.element_b = greatest(v_element_a, v_element_b);
    v_combo_name := coalesce(v_combo_name, 'Assist Attack');
    v_bonus := coalesce(v_bonus, 0);
    v_defense_ignore := coalesce(v_defense_ignore, 0);
    v_heal := coalesce(v_heal, 0);

    v_active_attack := greatest(0, coalesce(v_card.attack, 0));
    v_bench_attack := greatest(0, coalesce(v_bench.attack, 0));
    IF v_target_id IS NULL THEN
      v_damage := greatest(1, round((v_active_attack + floor(v_bench_attack * 0.5) + v_bonus) * 0.5)::integer);
      IF v_enemy = 'p1' THEN
        UPDATE public.battle_sessions SET player1_hp = greatest(0, player1_hp - v_damage),
          player1_skill = least(100, coalesce(player1_skill, 0) + 5),
          player2_skill = least(100, coalesce(player2_skill, 0) + 10) WHERE id = v_battle.id;
      ELSE
        UPDATE public.battle_sessions SET player2_hp = greatest(0, player2_hp - v_damage),
          player2_skill = least(100, coalesce(player2_skill, 0) + 5),
          player1_skill = least(100, coalesce(player1_skill, 0) + 10) WHERE id = v_battle.id;
      END IF;
      UPDATE public.battle_sessions
         SET winner = CASE
               WHEN player1_hp <= 0 AND player2_hp <= 0 THEN 'draw'
               WHEN player1_hp <= 0 THEN 'p2'
               WHEN player2_hp <= 0 THEN 'p1'
               ELSE winner
             END,
             status = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN 'finished' ELSE status END,
             finished_at = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN now() ELSE finished_at END
       WHERE id = v_battle.id;
    ELSE
      v_target_hp_before := greatest(0, coalesce(v_target.current_hp, v_target.base_hp, v_target.hp, 0));
      v_target_defense := greatest(0, coalesce(v_target.defense, 0));
      v_effective_defense := greatest(0, v_target_defense - round(v_target_defense * v_defense_ignore)::integer);
      v_damage := greatest(1, v_active_attack + floor(v_bench_attack * 0.5)::integer + v_bonus - v_effective_defense);
      v_target_hp_after := greatest(0, v_target_hp_before - v_damage);
      v_destroyed := v_target_hp_after = 0;
      v_effective_damage := least(v_target_hp_before, v_damage);
      IF v_destroyed THEN
        UPDATE public.battle_cards SET current_hp = 0, zone = 'graveyard', exhausted = true,
          destroyed_at = now(), graveyard_at = now(), graveyard_reason = 'combo_destroyed'
         WHERE id = v_target.id;
        IF coalesce(v_battle.destruction_damage_enabled, true) THEN
          v_destruction_pct := greatest(0, least(1, coalesce(v_battle.destruction_damage_percent, 0.30)));
          IF coalesce(v_battle.destruction_damage_mode, 'final_damage_percent') = 'final_damage_percent' THEN
            v_player_damage := round(v_effective_damage * v_destruction_pct)::integer;
          ELSIF coalesce(v_battle.destruction_damage_mode, '') = 'overflow_percent' THEN
            v_player_damage := round(greatest(0, v_damage - v_target_hp_before) * v_destruction_pct)::integer;
          END IF;
        END IF;
        IF v_enemy = 'p1' THEN
          UPDATE public.battle_sessions SET player1_hp = greatest(0, player1_hp - v_player_damage) WHERE id = v_battle.id;
        ELSE
          UPDATE public.battle_sessions SET player2_hp = greatest(0, player2_hp - v_player_damage) WHERE id = v_battle.id;
        END IF;
      ELSE
        UPDATE public.battle_cards SET current_hp = v_target_hp_after WHERE id = v_target.id;
      END IF;
      IF v_enemy = 'p1' THEN
        UPDATE public.battle_sessions SET player1_skill = least(100, coalesce(player1_skill, 0) + 5),
          player2_skill = least(100, coalesce(player2_skill, 0) + 10) WHERE id = v_battle.id;
      ELSE
        UPDATE public.battle_sessions SET player2_skill = least(100, coalesce(player2_skill, 0) + 5),
          player1_skill = least(100, coalesce(player1_skill, 0) + 10) WHERE id = v_battle.id;
      END IF;
    END IF;

    IF v_heal > 0 THEN
      UPDATE public.battle_cards SET current_hp = least(coalesce(base_hp, hp), coalesce(current_hp, 0) + v_heal)
       WHERE id = v_card.id;
    END IF;
    UPDATE public.battle_sessions
       SET winner = CASE
             WHEN player1_hp <= 0 AND player2_hp <= 0 THEN 'draw'
             WHEN player1_hp <= 0 THEN 'p2'
             WHEN player2_hp <= 0 THEN 'p1'
             ELSE winner
           END,
           status = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN 'finished' ELSE status END,
           finished_at = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN now() ELSE finished_at END
     WHERE id = v_battle.id;
    UPDATE public.battle_cards SET last_attacked_turn = coalesce(v_battle.turn_index, 1) WHERE id = v_card.id;
    UPDATE public.battle_cards SET combo_assist_turn = coalesce(v_battle.turn_index, 1) WHERE id = v_bench.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, target_player, card_id, payload)
    VALUES (v_battle.id, 'attack', v_player, v_enemy, v_card.id,
      jsonb_build_object('ruleset', 'tcg_v1', 'attack_mode', 'assist_combo',
        'attacker_card_id', v_card.id, 'bench_card_id', v_bench.id,
        'target_card_id', v_target_id, 'combo_name', v_combo_name,
        'attacker_element', v_card.element, 'bench_element', v_bench.element,
        'active_attack', v_active_attack, 'bench_assist_attack', floor(v_bench_attack * 0.5)::integer,
        'bonus_damage', v_bonus, 'defense_ignore_pct', v_defense_ignore,
        'damage', v_damage, 'target_hp_before', v_target_hp_before,
        'target_hp_after', v_target_hp_after, 'destroyed', v_destroyed,
        'player_damage', v_player_damage, 'healing', v_heal,
        'message', v_combo_name || ' • ' || v_damage || ' damage'));
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    IF v_ap_after = 0 AND lower(coalesce(v_battle.status, '')) <> 'finished' THEN
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN jsonb_build_object('ok', true, 'action', 'combo_attack', 'combo_name', v_combo_name,
      'damage', v_damage, 'destroyed', v_destroyed, 'player_damage', v_player_damage,
      'healing', v_heal, 'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
      'next_turn', v_battle.current_turn, 'round', v_battle.round,
      'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
      'message', v_combo_name || ' berhasil: ' || v_damage || ' damage.');
  END IF;

  v_old_round := greatest(1, coalesce(v_battle.round, 1));
  v_old_total_rounds := coalesce(v_battle.total_rounds, 10);
  v_old_question_enabled := coalesce(v_battle.question_enabled, false);
  v_old_question_active := coalesce(v_battle.question_active, false);
  v_old_question_id := v_battle.current_question_id;
  v_old_question_round_id := v_battle.current_question_round_id;
  v_old_status := coalesce(v_battle.status, 'battle');

  IF p_card_id IS NOT NULL THEN
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, p_card_id, v_action);
    IF v_action_block IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'STATUS_ACTION_BLOCKED', 'status_blocked', true, 'message', v_action_block);
    END IF;
  END IF;
  IF v_action = 'attack' THEN
    SELECT * INTO v_card FROM public.battle_cards WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player;
    IF NOT FOUND OR v_card.zone <> 'active' THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Serangan membutuhkan Active Card.');
    END IF;
    IF coalesce(v_card.last_attacked_turn, -1) = coalesce(v_battle.turn_index, 1) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Active Card ini sudah menyerang pada turn ini.');
    END IF;
    BEGIN
      v_target_id := nullif(trim(coalesce(p_payload->>'target_card_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN v_target_id := NULL;
    END;
    IF v_target_id IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_enemy AND zone = 'active';
      IF FOUND THEN v_target_hp_before := greatest(0, coalesce(v_target.current_hp, v_target.base_hp, v_target.hp, 0)); END IF;
    END IF;
  END IF;

  -- Suppress the legacy one-action turn transition while the validated core
  -- applies exactly one chosen card action. The transaction then restores the
  -- same round/turn and advances only when AP is exhausted.
  PERFORM set_config('tcg.intra_turn_action', 'on', true);
  UPDATE public.battle_sessions
     SET question_enabled = false,
         total_rounds = greatest(coalesce(total_rounds, 10), coalesce(round, 1) + 1)
   WHERE id = v_battle.id;

  v_response := public.submit_battle_action_phase3d19_core(
    p_code, p_player, p_token, p_action, p_card_id, coalesce(p_payload, '{}'::jsonb)
  );

  IF NOT coalesce((v_response->>'ok')::boolean, false) THEN
    UPDATE public.battle_sessions SET current_turn = v_player, round = v_old_round,
      question_active = v_old_question_active, current_question_id = v_old_question_id,
      current_question_round_id = v_old_question_round_id, status = v_old_status
    WHERE id = v_battle.id;
    PERFORM set_config('tcg.intra_turn_action', 'off', true);
    RETURN v_response;
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id FOR UPDATE;
  UPDATE public.battle_sessions
     SET question_enabled = v_old_question_enabled,
         total_rounds = v_old_total_rounds
   WHERE id = v_battle.id;
  IF lower(coalesce(v_battle.status, '')) <> 'finished' AND v_battle.winner IS NULL THEN
    UPDATE public.battle_sessions SET question_enabled = v_old_question_enabled,
      total_rounds = v_old_total_rounds, current_turn = v_player, round = v_old_round,
      question_active = v_old_question_active, current_question_id = v_old_question_id,
      current_question_round_id = v_old_question_round_id, status = v_old_status
    WHERE id = v_battle.id;
  END IF;

  IF p_action = 'attack' THEN
    UPDATE public.battle_cards SET last_attacked_turn = coalesce(v_battle.turn_index, 1) WHERE id = p_card_id;
    IF v_target_id IS NOT NULL AND v_target_hp_before IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id;
      IF FOUND AND v_target.zone = 'active' AND coalesce(v_target.current_hp, 0) > 0
         AND v_target.current_hp < v_target_hp_before THEN
        PERFORM public.tcg_apply_elemental_basic_passive(v_battle.id, p_card_id, v_target_id, v_old_round);
      END IF;
    END IF;
  END IF;

  PERFORM public.tcg_sync_legacy_card_visual_status(v_battle.id, v_player, v_action, p_card_id);
  IF v_action IN ('attack', 'ultimate') THEN
    PERFORM public.tcg_sync_legacy_card_visual_status(v_battle.id, v_enemy, '', NULL);
  END IF;

  IF lower(coalesce(v_battle.status, '')) = 'finished' OR v_battle.winner IS NOT NULL THEN
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
  ELSE
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    IF v_ap_after = 0 THEN
      PERFORM set_config('tcg.intra_turn_action', 'off', true);
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
  END IF;

  v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
  RETURN v_response || jsonb_build_object(
    'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
    'next_turn', v_battle.current_turn,
    'round', v_battle.round,
    'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
    'question_active', coalesce(v_battle.question_active, false),
    'deck_out', v_deck_out,
    'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
    'finished', lower(coalesce(v_battle.status, '')) = 'finished'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_battle_action(text, text, text, text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_battle_action(text, text, text, text, uuid, jsonb) TO anon, authenticated, service_role;

-- The RFID scanner historically ends every turn after a summon. In AP mode,
-- keep that turn open while the player has AP left and use the same resolver
-- after the final summon scan.
CREATE OR REPLACE FUNCTION public.process_multiplayer_rfid_scan(
  p_uid text,
  p_device_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_before public.battle_sessions%ROWTYPE;
  v_response jsonb;
  v_player text;
  v_ap integer;
  v_turn jsonb := '{}'::jsonb;
  v_tcg_summon boolean := false;
BEGIN
  SELECT b.player INTO v_player
    FROM public.battle_reader_bindings b
   WHERE b.device_id = trim(coalesce(p_device_id, '')) AND coalesce(b.active, false)
   LIMIT 1;
  SELECT s.* INTO v_battle
    FROM public.battle_reader_bindings b
    JOIN public.battle_sessions s ON s.id = b.battle_id
   WHERE b.device_id = trim(coalesce(p_device_id, '')) AND coalesce(b.active, false)
   LIMIT 1;
  IF v_battle.id IS NOT NULL THEN
    PERFORM public.tcg_expire_battle_turn_if_due(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
  END IF;
  v_before := v_battle;
  v_tcg_summon := v_before.id IS NOT NULL
    AND coalesce(v_before.action_points_enabled, false)
    AND lower(coalesce(v_before.ruleset, '')) = 'tcg_v1'
    AND lower(coalesce(v_before.pending_action, '')) = 'summon'
    AND lower(coalesce(v_before.pending_action_player, '')) = lower(coalesce(v_player, ''));

  -- Prevent the legacy scanner from advancing the round or opening its own
  -- question before the AP turn resolver has settled the final summon.
  IF v_tcg_summon THEN
    PERFORM set_config('tcg.intra_turn_action', 'on', true);
    UPDATE public.battle_sessions
       SET question_enabled = false,
           total_rounds = greatest(coalesce(total_rounds, 10), coalesce(round, 1) + 1)
     WHERE id = v_before.id;
  END IF;
  PERFORM set_config('tcg.intra_turn_action', 'on', true);
  v_response := public.process_multiplayer_rfid_scan_pre_turn_clock(p_uid, p_device_id);
  PERFORM set_config('tcg.intra_turn_action', 'off', true);

  IF v_tcg_summon THEN
    UPDATE public.battle_sessions
       SET current_turn = v_before.current_turn,
           round = v_before.round,
           status = CASE WHEN v_before.question_active THEN 'question' ELSE v_before.status END,
           question_enabled = v_before.question_enabled,
           total_rounds = v_before.total_rounds,
           question_active = v_before.question_active,
           current_question_id = v_before.current_question_id,
           current_question_round_id = v_before.current_question_round_id
     WHERE id = v_before.id AND lower(coalesce(status, '')) <> 'finished';
    PERFORM set_config('tcg.intra_turn_action', 'off', true);
  END IF;

  IF NOT coalesce((v_response->>'ok')::boolean, false)
     OR v_before.id IS NULL
     OR NOT coalesce(v_before.action_points_enabled, false)
     OR lower(coalesce(v_before.ruleset, '')) <> 'tcg_v1'
     OR lower(coalesce(v_response->>'phase', '')) <> 'summon' THEN
    RETURN v_response;
  END IF;

  v_ap := CASE WHEN v_player = 'p1' THEN coalesce(v_before.player1_action_points, 0)
               ELSE coalesce(v_before.player2_action_points, 0) END;
  -- Undo the legacy scan's automatic turn/round increment; then pass normally
  -- only if the summon used the player's last AP.
  PERFORM set_config('tcg.intra_turn_action', 'on', true);
  UPDATE public.battle_sessions
     SET current_turn = v_player,
         round = v_before.round,
         status = CASE WHEN question_active THEN 'question' ELSE 'battle' END,
         player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap ELSE player1_action_points END,
         player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap ELSE player2_action_points END
   WHERE id = v_before.id AND lower(coalesce(status, '')) <> 'finished';
  PERFORM set_config('tcg.intra_turn_action', 'off', true);
  IF v_ap <= 0 THEN
    v_turn := public.tcg_finish_action_point_turn(v_before.id, v_player);
  END IF;
  RETURN v_response || jsonb_build_object(
    'action_points', v_ap,
    'next_turn', CASE WHEN v_ap > 0 THEN v_player ELSE v_turn->>'next_turn' END,
    'round', coalesce(nullif(v_turn->>'round', '')::integer, v_before.round),
    'turn_completed', v_ap <= 0,
    'turn_result', v_turn
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_multiplayer_rfid_scan(text, text) TO anon, authenticated, service_role;

-- Let the existing RFID insert path put a newly summoned card in Bench when
-- Active is occupied, while preserving its initial-card Active-only rule.
DO $migration$
DECLARE
  v_definition text;
  v_summon_gate_start integer;
  v_active_offset integer;
  v_active_start integer;
  v_deck_offset integer;
  v_deck_start integer;
  v_insert_start integer;
  v_insert_end_offset integer;
  v_insert_end integer;
  v_segment text;
  v_old_block text;
  v_new_block text;
BEGIN
  SELECT pg_get_functiondef('public.process_multiplayer_rfid_scan_pre_turn_clock(text,text)'::regprocedure)
    INTO v_definition;
  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'Required RFID scan core is missing.';
  END IF;

  IF strpos(v_definition, 'v_summon_zone') > 0 THEN
    RETURN;
  END IF;

  v_definition := replace(v_definition,
    '  v_active_count integer := 0;',
    E'  v_active_count integer := 0;\n  v_bench_count integer := 0;\n  v_summon_zone text := ''active'';');
  IF strpos(v_definition, 'v_bench_count integer') = 0 THEN
    RAISE EXCEPTION 'Could not add bench scan variables to RFID scan core.';
  END IF;

  -- The first ACTIVE LIMIT is for a player's initial card and must remain
  -- Active-only. Patch the later limit reached only after an explicit Summon.
  v_summon_gate_start := strpos(v_definition, '-- MUST PRESS SUMMON');
  v_active_offset := strpos(
    substring(v_definition FROM greatest(v_summon_gate_start, 1)),
    '-- ACTIVE LIMIT'
  );
  v_active_start := CASE
    WHEN v_summon_gate_start > 0 AND v_active_offset > 0
      THEN v_summon_gate_start + v_active_offset - 1
    ELSE 0
  END;
  v_deck_offset := strpos(substring(v_definition FROM greatest(v_active_start, 1)), '-- DECK LIMIT');
  IF v_summon_gate_start = 0 OR v_active_start = 0 OR v_deck_offset = 0 THEN
    RAISE EXCEPTION 'Could not locate the battle summon field-limit block.';
  END IF;
  v_deck_start := v_active_start + v_deck_offset - 1;

  v_old_block := substring(v_definition FROM v_active_start FOR v_deck_start - v_active_start);
  v_new_block := $prefix$
    if v_is_tcg then
      -- Active is the lead position. Additional scanned cards enter Bench.
      select count(*) into v_active_count
        from public.battle_cards
       where battle_id = v_battle.id and player = v_player and zone = 'active'
         and coalesce(current_hp, base_hp, 0) > 0;

      if v_active_count < v_max_active then
        v_summon_zone := 'active';
      else
        select count(*) into v_bench_count
          from public.battle_cards
         where battle_id = v_battle.id and player = v_player and zone = 'bench'
           and coalesce(current_hp, base_hp, 0) > 0;
        if v_bench_count >= greatest(0, coalesce(v_battle.max_bench, 2)) then
          insert into public.battle_events (battle_id, type, source_player, payload)
          values (v_battle.id, 'rfid_warning', v_player,
            jsonb_build_object('message', 'ACTIVE DECK + BENCH FULL'));
          return jsonb_build_object('ok', false, 'message', 'ACTIVE DECK + BENCH FULL');
        end if;
        v_summon_zone := 'bench';
      end if;
    else
$prefix$ || v_old_block || $suffix$
    end if;
    -- =====================================================
$suffix$;
  v_definition := left(v_definition, v_active_start - 1) || v_new_block || substring(v_definition FROM v_deck_start);

  v_insert_start := strpos(v_definition, '-- INSERT SUMMONED CARD');
  v_insert_end_offset := strpos(substring(v_definition FROM greatest(v_insert_start, 1)), '-- TCG V1 - CONSUME PHYSICAL DECK');
  IF v_insert_start = 0 OR v_insert_end_offset = 0 THEN
    RAISE EXCEPTION 'Could not locate summoned-card insert block.';
  END IF;
  v_insert_end := v_insert_start + v_insert_end_offset - 1;
  v_segment := substring(v_definition FROM v_insert_start FOR v_insert_end - v_insert_start);
  IF strpos(v_segment, '''active'',') = 0 THEN
    RAISE EXCEPTION 'Could not locate summoned-card zone value.';
  END IF;
  v_segment := replace(v_segment, '''active'',', 'v_summon_zone,');
  v_definition := left(v_definition, v_insert_start - 1) || v_segment || substring(v_definition FROM v_insert_end);
  EXECUTE v_definition;
END;
$migration$;

COMMIT;
