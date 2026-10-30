-- Exercise actual anonymous row visibility. Synthetic battle/round roll back.
BEGIN;
DO $test$
DECLARE b uuid:=gen_random_uuid();q uuid;r uuid:=gen_random_uuid();code text:='QA57-'||b;
 seen battle_question_rounds;admin_id uuid;denied boolean;
BEGIN
 SELECT id INTO q FROM coding_questions WHERE is_active LIMIT 1;
 SELECT id INTO admin_id FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1;
 IF q IS NULL OR admin_id IS NULL THEN RAISE EXCEPTION 'Missing question/admin for rollback fixture';END IF;
 INSERT INTO battle_sessions(id,code,status,current_turn,question_enabled,question_active,is_active,active_until,question_time_limit_seconds)
 VALUES(b,code,'question','p1',true,true,true,now()+interval '1 hour',60);
 INSERT INTO battle_question_rounds(id,battle_id,question_id,round_number,status,created_at)
 VALUES(r,b,q,1,'active',now()-interval '10 seconds');
 UPDATE battle_sessions SET current_question_id=q,current_question_round_id=r WHERE id=b;
 SET LOCAL ROLE anon;
 SELECT * INTO seen FROM battle_question_rounds WHERE id=r;
 IF seen.id IS NULL OR seen.created_at IS NULL THEN RAISE EXCEPTION 'Anonymous player still cannot read the actual round clock';END IF;
 IF NOT coalesce((get_public_battle_state(code)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Public state rejected fixture';END IF;
 denied:=false;BEGIN UPDATE battle_question_rounds SET created_at=now() WHERE id=r;EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Client can reset quiz clock';END IF;
 IF has_table_privilege('anon','battle_question_rounds','TRUNCATE') OR has_table_privilege('authenticated','battle_question_rounds','INSERT') OR has_table_privilege('authenticated','battle_question_rounds','DELETE') THEN RAISE EXCEPTION 'Direct round write grant remains';END IF;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM teacher_control_battle(code,'pause');
 SET LOCAL ROLE anon;SELECT * INTO seen FROM battle_question_rounds WHERE id=r;
 IF seen.timer_paused_at IS NULL THEN RAISE EXCEPTION 'Pause anchor not readable';END IF;
 RESET ROLE;PERFORM teacher_control_battle(code,'resume');
 SET LOCAL ROLE authenticated;SELECT * INTO seen FROM battle_question_rounds WHERE id=r;
 IF seen.timer_paused_at IS NOT NULL OR seen.timer_started_at IS NULL THEN RAISE EXCEPTION 'Resume anchor not readable';END IF;
 RESET ROLE;
 UPDATE battle_sessions SET active_until=now()-interval '1 minute' WHERE id=b;
 SET LOCAL ROLE anon;
 IF EXISTS(SELECT 1 FROM battle_question_rounds WHERE id=r) THEN RAISE EXCEPTION 'Expired live round exposed';END IF;
 RESET ROLE;UPDATE battle_sessions SET active_until=now()+interval '1 hour',is_active=false WHERE id=b;
 SET LOCAL ROLE anon;
 IF EXISTS(SELECT 1 FROM battle_question_rounds WHERE id=r) THEN RAISE EXCEPTION 'Disabled live round exposed';END IF;
 RESET ROLE;UPDATE battle_sessions SET status='finished',winner='draw' WHERE id=b;
 SET LOCAL ROLE anon;
 IF NOT EXISTS(SELECT 1 FROM battle_question_rounds WHERE id=r) THEN RAISE EXCEPTION 'Completed spectator round missing';END IF;
 RESET ROLE;
END $test$;
SELECT 'PASS actual anonymous quiz clock row, pause/resume, read-only access, expired/disabled isolation and finished history' AS checks;
ROLLBACK;
