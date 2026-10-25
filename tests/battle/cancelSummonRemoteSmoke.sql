-- Explicitly authorized linked-project smoke; every fixture is rolled back.
BEGIN;
DO $smoke$
DECLARE b uuid:=gen_random_uuid(); g uuid:=gen_random_uuid(); uid text:='QA42-'||gen_random_uuid();
 code text:='QA42-'||gen_random_uuid(); device text:='QA42-'||gen_random_uuid(); t1 text:=gen_random_uuid();t2 text:=gen_random_uuid();
 r jsonb; request uuid; old_request uuid; ap integer; cards integer; remaining integer;
BEGIN
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,
  player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,action_points_enabled,
  action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,
  turn_index,max_active,max_bench,turn_duration_seconds,turn_started_at,turn_deadline_at,action_costs)
 VALUES(b,code,'tcg_v1','battle','p1',1,100,t1,t2,200,200,200,200,false,false,true,3,3,0,20,20,1,4,4,60,now(),now()+interval '1 minute','{"summon":3}');
 INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled)
 VALUES(g,uid,'Rollback cancellation card','QA42_'||upper(replace(g::text,'-','')),'Forest',100,30,10,'common','normal',false,true);
 INSERT INTO battle_reader_bindings(device_id,battle_id,player,active) VALUES(device,b,'p1',true);
 r:=submit_battle_action(code,'p1',t1,'summon',NULL,'{}');
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Summon failed: %',r; END IF;
 SELECT pending_summon_request_id,player1_action_points INTO request,ap FROM battle_sessions WHERE id=b;
 IF request IS NULL OR ap<>0 THEN RAISE EXCEPTION 'Reservation was not recorded'; END IF;
 r:=cancel_battle_summon(code,'p1',t1,request);
 IF NOT coalesce((r->>'ok')::boolean,false) OR (r->>'action_points_refunded')::integer<>3 THEN RAISE EXCEPTION 'Full AP cancellation failed: %',r; END IF;
 IF coalesce((cancel_battle_summon(code,'p1',t1,request)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Duplicate cancellation succeeded'; END IF;
 r:=process_multiplayer_rfid_scan(uid,device);
 SELECT count(*) INTO cards FROM battle_cards WHERE battle_id=b;
 IF coalesce((r->>'ok')::boolean,false) OR cards<>0 THEN RAISE EXCEPTION 'Late scan bypassed cancellation: %',r; END IF;
 old_request:=request;
 UPDATE battle_sessions SET action_costs='{"summon":2}' WHERE id=b;
 r:=submit_battle_action(code,'p1',t1,'summon',NULL,'{}');
 SELECT pending_summon_request_id INTO request FROM battle_sessions WHERE id=b;
 IF coalesce((cancel_battle_summon(code,'p1',t1,old_request)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Old request cancelled new Summon'; END IF;
 IF coalesce((cancel_battle_summon(code,'p1','invalid',request)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Invalid token cancelled'; END IF;
 r:=process_multiplayer_rfid_scan(uid,device);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Real scanner failed: %',r; END IF;
 r:=cancel_battle_summon(code,'p1',t1,request);
 SELECT player1_action_points,player1_deck_remaining INTO ap,remaining FROM battle_sessions WHERE id=b;
 SELECT count(*) INTO cards FROM battle_cards WHERE battle_id=b AND zone='active';
 IF coalesce((r->>'ok')::boolean,false) OR ap<>1 OR remaining<>19 OR cards<>1 THEN RAISE EXCEPTION 'Scan-first state was rewound: %, %, %, %',r,ap,remaining,cards; END IF;
END $smoke$;
SELECT 'summon/cancel, duplicate, stale token/request, actual late-scan rejection and scan-first preservation passed' AS checks;
ROLLBACK;
