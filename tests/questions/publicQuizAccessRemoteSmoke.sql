-- Run against the linked project; no real question or battle is modified.
BEGIN;
SET LOCAL ROLE anon;
DO $$
DECLARE q record;field text;denied boolean;
BEGIN
 SELECT id,question,image_url,option_a,option_b,option_c,option_d,explanation,category,difficulty,level,is_active,
 question_type,block_config,duration_seconds,blocks,code_snippet,hint_1,hint_2,learning_topic,learning_url
 INTO q FROM public.coding_questions WHERE is_active LIMIT 1;
 IF q.id IS NULL THEN RAISE EXCEPTION 'An active question is required for the anonymous read check';END IF;
 FOREACH field IN ARRAY ARRAY['correct_answer','correct_sequence','bug_line'] LOOP
  denied:=false;
  BEGIN EXECUTE format('SELECT %I FROM public.coding_questions LIMIT 1',field);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'Answer field exposed: %',field;END IF;
 END LOOP;
 IF has_table_privilege('anon','public.coding_question_block_keys','SELECT') THEN RAISE EXCEPTION 'Workspace answers exposed';END IF;
 PERFORM id,question_id,created_at,timer_started_at,timer_paused_at,status FROM public.battle_question_rounds LIMIT 1;
END $$;
RESET ROLE;
SELECT 'PASS anonymous player/spectator question and timer fields; answer keys remain inaccessible' AS checks;
ROLLBACK;
