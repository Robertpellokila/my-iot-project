-- Full linked-project engine smoke. All fixtures and role changes roll back.
BEGIN;
DO $smoke$
DECLARE b uuid:=gen_random_uuid();g uuid:=gen_random_uuid();q uuid:=gen_random_uuid();qr uuid:=gen_random_uuid();
 code text:='QA45-'||gen_random_uuid();device text:='QA45-'||gen_random_uuid();uid text:='QA45-'||gen_random_uuid();
 t1 text:=gen_random_uuid();t2 text:=gen_random_uuid();c1 text;c2 text;newtoken text;admin_id uuid;r jsonb;pub jsonb;
 before_row battle_sessions;after_row battle_sessions;question_created timestamptz;anchor timestamptz;old_deadline timestamptz;req uuid;n integer;had_permission boolean;
BEGIN
 SELECT id INTO admin_id FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1;
 IF admin_id IS NULL THEN RAISE EXCEPTION 'No teacher account available for rolled-back checks';END IF;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,
 player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,action_points_enabled,
 action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,
 turn_index,max_active,max_bench,turn_duration_seconds,turn_started_at,turn_deadline_at,is_active,active_until)
 VALUES(b,code,'tcg_v1','battle','p1',1,100,t1,t2,200,200,200,200,true,false,true,3,3,0,20,20,1,4,4,60,now(),now()+interval '1 minute',true,now()+interval '1 hour');
 INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled)
 VALUES(g,uid,'Rollback access card','QA45_'||upper(replace(g::text,'-','')),'Forest',100,30,10,'common','normal',false,true);
 INSERT INTO battle_reader_bindings(device_id,battle_id,player,active) VALUES(device,b,'p1',true);
 SELECT * INTO after_row FROM battle_sessions WHERE id=b;
 IF after_row.player1_token IS NOT NULL OR after_row.player2_token IS NOT NULL OR after_row.player1_access_code IS NOT NULL OR after_row.player2_access_code IS NOT NULL THEN RAISE EXCEPTION 'Credentials leaked in public row/RETURNING';END IF;
 IF has_schema_privilege('anon','tbc_private','USAGE') OR has_schema_privilege('authenticated','tbc_private','USAGE') OR has_function_privilege('anon','tcg_battle_player_token(uuid,text)','EXECUTE') OR has_function_privilege('anon','tcg_tick_statuses_for_player(uuid,text)','EXECUTE') OR has_function_privilege('anon','start_battle_question(uuid,integer)','EXECUTE') OR has_function_privilege('anon','tcg_sync_legacy_card_visual_status(uuid,text,text,uuid)','EXECUTE') OR has_table_privilege('anon','battle_player_ui_state','INSERT') THEN RAISE EXCEPTION 'Private helper/table exposed';END IF;
 IF EXISTS(SELECT 1 FROM pg_policies WHERE tablename='battle_sessions' AND policyname='Authenticated users can create battle') THEN RAISE EXCEPTION 'Non-admin creation policy remains';END IF;
 pub:=get_public_battle_state(code)->'battle';
 IF pub IS NULL OR pub ?| ARRAY['player1_token','player2_token','player1_access_code','player2_access_code','created_by'] THEN RAISE EXCEPTION 'Public projection leaks credentials';END IF;
 IF (get_battle_player_state(code,'p1',code)->>'ok')::boolean OR (get_battle_player_state(code,'p1',t2)->>'ok')::boolean OR (get_battle_player_state(code,NULL,t1)->>'ok')::boolean THEN RAISE EXCEPTION 'Public link / wrong side authorized player';END IF;
 IF NOT (get_battle_player_state(code,'p1',t1)->>'ok')::boolean THEN RAISE EXCEPTION 'Valid private token failed';END IF;
 -- Anonymous callers can spectate, but cannot read private schema or use teacher controls.
 SET LOCAL ROLE anon;
 pub:=get_public_battle_state(code);
 IF NOT (pub->>'ok')::boolean THEN RAISE EXCEPTION 'Anonymous spectator failed';END IF;
 had_permission:=false;BEGIN PERFORM admin_battle_access(code);had_permission:=true;EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF had_permission THEN RAISE EXCEPTION 'Anonymous teacher code access succeeded';END IF;
 had_permission:=false;BEGIN PERFORM teacher_control_battle(code,'pause');had_permission:=true;EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF had_permission THEN RAISE EXCEPTION 'Anonymous pause succeeded';END IF;
 had_permission:=false;BEGIN PERFORM token FROM tbc_private.battle_player_access LIMIT 1;had_permission:=true;EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF had_permission THEN RAISE EXCEPTION 'Anonymous private table read succeeded';END IF;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 SET LOCAL ROLE authenticated;
 had_permission:=false;BEGIN PERFORM teacher_control_battle(code,'pause');had_permission:=true;EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF had_permission THEN RAISE EXCEPTION 'Non-teacher pause succeeded';END IF;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 r:=admin_battle_access(code);c1:=r->>'player1_access_code';c2:=r->>'player2_access_code';
 IF length(c1)<>6 OR length(c2)<>6 OR c1=c2 OR r ?| ARRAY['token','player1_token','player2_token'] THEN RAISE EXCEPTION 'Teacher codes invalid';END IF;
 IF NOT (redeem_battle_player_code(c1,code,'p1')->>'ok')::boolean OR (redeem_battle_player_code(c1,code,'p2')->>'ok')::boolean OR (redeem_battle_player_code(c1,'another-battle','p1')->>'ok')::boolean THEN RAISE EXCEPTION 'Private code side/battle isolation failed';END IF;
 FOR n IN 1..16 LOOP r:=redeem_battle_player_code('000000000000',code,'p1');END LOOP;
 IF r->>'code' IS DISTINCT FROM 'RATE_LIMIT' THEN RAISE EXCEPTION 'Private code rate limit missing';END IF;
 DELETE FROM tbc_private.battle_access_attempts;
 -- Actual engine: prepare a Summon before pausing; neither scan nor cancel can mutate while paused.
 r:=submit_battle_action(code,'p1',t1,'summon',NULL,'{}');
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Actual Summon failed: %',r;END IF;
 SELECT * INTO before_row FROM battle_sessions WHERE id=b;req:=before_row.pending_summon_request_id;old_deadline:=before_row.turn_deadline_at;
 r:=teacher_control_battle(code,'pause','Reader reconnect');
 IF NOT (r->>'ok')::boolean THEN RAISE EXCEPTION 'Teacher pause failed: %',r;END IF;
 IF submit_battle_action(code,'p1',t1,'end_turn',NULL,'{}')->>'code' IS DISTINCT FROM 'BATTLE_PAUSED'
 OR cancel_battle_summon(code,'p1',t1,req)->>'code' IS DISTINCT FROM 'BATTLE_PAUSED'
 OR process_multiplayer_rfid_scan(uid,device)->>'code' IS DISTINCT FROM 'BATTLE_PAUSED'
 OR finish_battle_question_timeout(code,'p1',t1,qr)->>'code' IS DISTINCT FROM 'BATTLE_PAUSED'
 OR choose_battle_question_bonus(code,'p1',t1,qr,'heal')->>'code' IS DISTINCT FROM 'BATTLE_PAUSED'
 OR use_battle_bonus_skill(code,'p1',t1,gen_random_uuid())->>'code' IS DISTINCT FROM 'BATTLE_PAUSED' THEN RAISE EXCEPTION 'Paused engine action accepted';END IF;
 SELECT * INTO after_row FROM battle_sessions WHERE id=b;
 IF after_row.player1_action_points<>before_row.player1_action_points OR after_row.current_turn<>before_row.current_turn OR after_row.turn_index<>before_row.turn_index OR after_row.pending_summon_request_id IS DISTINCT FROM req OR after_row.turn_deadline_at IS DISTINCT FROM old_deadline THEN RAISE EXCEPTION 'Pause changed turn/AP/Summon/deadline';END IF;
 UPDATE battle_sessions SET teacher_paused_at=teacher_paused_at-interval '10 seconds' WHERE id=b;
 r:=teacher_control_battle(code,'resume');SELECT * INTO after_row FROM battle_sessions WHERE id=b;
 IF after_row.teacher_paused OR after_row.player1_action_points<>before_row.player1_action_points OR after_row.current_turn<>before_row.current_turn OR after_row.turn_index<>before_row.turn_index OR abs(extract(epoch FROM (after_row.turn_deadline_at-old_deadline))-10)>.5 THEN RAISE EXCEPTION 'Resume changed state or lost remaining time';END IF;
 old_deadline:=after_row.turn_deadline_at;r:=teacher_control_battle(code,'resume');
 SELECT * INTO after_row FROM battle_sessions WHERE id=b;
 IF after_row.turn_deadline_at IS DISTINCT FROM old_deadline OR NOT (r->>'already_applied')::boolean THEN RAISE EXCEPTION 'Repeated resume extends time';END IF;
 r:=process_multiplayer_rfid_scan(uid,device);
 IF NOT coalesce((r->>'ok')::boolean,false) OR NOT EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=b AND game_card_id=g AND zone='active') THEN RAISE EXCEPTION 'Scanner failed after resume: %',r;END IF;
 -- Quiz has its own movable anchor; original audit timestamp never changes.
 INSERT INTO coding_questions(id,question,option_a,option_b,option_c,option_d,correct_answer,duration_seconds) VALUES(q,'QA45 rollback quiz','Right','Wrong','Other','None','A',60);
 INSERT INTO battle_question_rounds(id,battle_id,question_id,round_number,status,created_at) VALUES(qr,b,q,1,'active',now()-interval '10 seconds');
 SELECT created_at INTO question_created FROM battle_question_rounds WHERE id=qr;
 UPDATE battle_sessions SET status='question',question_active=true,question_bonus_enabled=false,current_question_id=q,current_question_round_id=qr WHERE id=b;
 r:=teacher_control_battle(code,'pause','Quiz connection');
 IF NOT coalesce((r->>'ok')::boolean,false) OR NOT EXISTS(SELECT 1 FROM battle_question_rounds WHERE id=qr AND timer_paused_at IS NOT NULL) THEN RAISE EXCEPTION 'Quiz pause failed';END IF;
 IF submit_battle_question_answer(code,'p1',t1,qr,0)->>'code' IS DISTINCT FROM 'BATTLE_PAUSED' OR tcg_expire_battle_question(b,qr)->>'code' IS DISTINCT FROM 'BATTLE_PAUSED' THEN RAISE EXCEPTION 'Paused quiz advanced';END IF;
 UPDATE battle_sessions SET teacher_paused_at=teacher_paused_at-interval '10 seconds' WHERE id=b;
 r:=teacher_control_battle(code,'resume');
 SELECT timer_started_at INTO anchor FROM battle_question_rounds WHERE id=qr AND created_at=question_created AND timer_paused_at IS NULL;
 IF anchor IS NULL OR abs(extract(epoch FROM(anchor-question_created))-10)>.5 THEN RAISE EXCEPTION 'Quiz deadline not shifted or audit time rewritten';END IF;
 r:=submit_battle_question_answer(code,'p1',t1,qr,0);
 IF NOT coalesce((r->>'correct')::boolean,false) THEN RAISE EXCEPTION 'Actual quiz grader failed after resume: %',r;END IF;
 -- Verified live UI cannot be spoofed with a spectator code or other side's token.
 r:=publish_battle_player_ui(code,'p1',t1,'{"viewerZone":"bench","evil":"drop"}');
 IF NOT (r->>'ok')::boolean OR EXISTS(SELECT 1 FROM battle_player_ui_state WHERE battle_id=b AND state?'evil') THEN RAISE EXCEPTION 'Live UI validation failed';END IF;
 IF (publish_battle_player_ui(code,'p2',t1,'{}')->>'ok')::boolean THEN RAISE EXCEPTION 'Other side UI spoofed';END IF;
 r:=teacher_reset_battle_access(code,'p1');
 IF NOT (r->>'ok')::boolean OR r->>'player1_access_code'=c1 OR r->>'player2_access_code'<>c2 THEN RAISE EXCEPTION 'Access rotation changed wrong side';END IF;
 IF (get_battle_player_state(code,'p1',t1)->>'ok')::boolean OR (publish_battle_player_ui(code,'p1',t1,'{}')->>'ok')::boolean OR (redeem_battle_player_code(c1,code,'p1')->>'ok')::boolean OR (submit_battle_action(code,'p1',t1,'end_turn',NULL,'{}')->>'ok')::boolean OR EXISTS(SELECT 1 FROM battle_player_ui_state WHERE battle_id=b AND player='p1') THEN RAISE EXCEPTION 'Revoked device remains authorized';END IF;
 r:=redeem_battle_player_code(r->>'player1_access_code',code,'p1');newtoken:=r->>'token';
 IF NOT coalesce((r->>'ok')::boolean,false) OR NOT (get_battle_player_state(code,'p1',newtoken)->>'ok')::boolean THEN RAISE EXCEPTION 'Replacement device cannot reconnect';END IF;
 r:=teacher_control_battle(code,'finish','Teacher ends pilot','draw');SELECT * INTO after_row FROM battle_sessions WHERE id=b;
 IF NOT coalesce((r->>'ok')::boolean,false) OR after_row.status<>'finished' OR after_row.winner<>'draw' OR after_row.question_active OR after_row.teacher_paused OR after_row.pending_summon_request_id IS NOT NULL THEN RAISE EXCEPTION 'Teacher finish failed';END IF;
 IF (submit_battle_action(code,'p1',newtoken,'end_turn',NULL,'{}')->>'ok')::boolean OR (redeem_battle_player_code(c2,code,'p2')->>'ok')::boolean THEN RAISE EXCEPTION 'Finished match still playable';END IF;
 IF get_public_battle_state(code)->'battle'->>'status'<>'finished' OR get_battle_player_state(code,'p1',newtoken)->'battle'->>'winner'<>'draw' THEN RAISE EXCEPTION 'Final result not shared';END IF;
 IF (SELECT count(*) FROM battle_events WHERE battle_id=b AND type IN ('teacher_pause','teacher_resume','teacher_finish','teacher_reset_access'))<>6 THEN RAISE EXCEPTION 'Teacher history missing or idempotency failed';END IF;
END $smoke$;
SELECT 'PASS private credentials, anon/non-admin isolation, private code matching/rate limit, full-engine pause/resume/scan/quiz, unchanged AP/turn, clocks, live UI, revoked access, teacher finish and history' AS checks;
ROLLBACK;
