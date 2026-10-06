-- A question must resolve when both players have used their one attempt and
-- neither answer is correct. Otherwise question_active remains true forever.
CREATE OR REPLACE FUNCTION public.tcg_close_question_after_both_wrong_answers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_battle_id uuid;
  v_wrong_answer_count integer := 0;
BEGIN
  IF coalesce(NEW.is_correct, false) THEN
    RETURN NEW;
  END IF;

  SELECT count(DISTINCT lower(player))::integer
    INTO v_wrong_answer_count
    FROM public.battle_question_answers
   WHERE battle_question_id = NEW.battle_question_id
     AND lower(player) IN ('p1', 'p2')
     AND coalesce(is_correct, false) = false;

  IF v_wrong_answer_count < 2 THEN
    RETURN NEW;
  END IF;

  SELECT battle_id
    INTO v_battle_id
    FROM public.battle_question_rounds
   WHERE id = NEW.battle_question_id;

  IF v_battle_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Use the same resolved status as the existing question-timeout path.
  UPDATE public.battle_question_rounds
     SET status = 'timed_out'
   WHERE id = NEW.battle_question_id
     AND battle_id = v_battle_id
     AND winner_player IS NULL
     AND status = 'active';

  UPDATE public.battle_sessions
     SET question_active = false,
         status = 'battle',
         current_question_id = NULL,
         current_question_round_id = NULL
   WHERE id = v_battle_id
     AND current_question_round_id = NEW.battle_question_id
     AND coalesce(question_active, false)
     AND winner IS NULL
     AND lower(coalesce(status, '')) <> 'finished';

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.tcg_close_question_after_both_wrong_answers() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS close_question_after_both_wrong_answers
  ON public.battle_question_answers;

CREATE TRIGGER close_question_after_both_wrong_answers
AFTER INSERT ON public.battle_question_answers
FOR EACH ROW
EXECUTE FUNCTION public.tcg_close_question_after_both_wrong_answers();
