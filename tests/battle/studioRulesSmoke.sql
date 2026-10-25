DO $rules$
DECLARE b uuid:=gen_random_uuid(); src uuid:=gen_random_uuid(); enemy uuid:=gen_random_uuid(); bench uuid:=gen_random_uuid(); ally uuid:=gen_random_uuid();
 r jsonb; test_key text; hp_now integer; native_damage integer; stat_now integer; sid uuid; code text:='RULE-QA-'||gen_random_uuid()::text; request_id uuid; first_card uuid; cd integer; necro uuid:=gen_random_uuid(); recall_card uuid; target_runtime uuid; chain uuid:=gen_random_uuid(); chain_card uuid; fusion_id uuid:=gen_random_uuid();
BEGIN
 PERFORM set_config('tcg.intra_turn_action','off',true);
 SELECT id INTO first_card FROM game_cards WHERE metadata#>>'{studio_card,display_code}'='COB-006' AND uid IS NULL LIMIT 1;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card,status_effects_enabled)
 VALUES(b,code,'tcg_v1','battle','p1',1,50,'rules1','rules2',200,200,200,200,false,false,true,true,10,10,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1,true);
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element)
 VALUES(src,b,'p1',first_card,gen_random_uuid()::text,'Source','active',1,200,200,100,30,10,'Knight'),
 (enemy,b,'p2',NULL,gen_random_uuid()::text,'Enemy','active',1,200,200,200,30,10,'Knight'),
 (ally,b,'p1',NULL,gen_random_uuid()::text,'Ally','active',2,100,100,30,30,10,'Knight'),
 (bench,b,'p1',NULL,gen_random_uuid()::text,'Bench','bench',NULL,100,100,100,30,10,'Knight');
 -- Shield, flat guard, temporary DEF, marks and outgoing debuffs must affect
 -- the native attack RPC as well as Studio attacks.
 FOREACH test_key IN ARRAY ARRAY['studio_shield','studio_reduction','studio_defense','studio_mark','studio_attack_reduction'] LOOP
  UPDATE battle_status_effects SET active=false WHERE battle_id=b;
  UPDATE battle_cards SET current_hp=200,attack_turn_index=NULL,last_attacked_turn=NULL,attacks_this_turn=0 WHERE battle_id=b;
  PERFORM public.tcg_studio_status(b,src,CASE WHEN test_key='studio_attack_reduction' THEN src ELSE enemy END,test_key,CASE WHEN test_key='studio_shield' THEN 16 ELSE 8 END,CASE WHEN test_key IN ('studio_reduction','studio_defense') THEN 'hit' ELSE NULL END);
  request_id:=gen_random_uuid();
  r:=public.submit_battle_action(code,'p1','rules1','attack',src,jsonb_build_object('target_card_id',enemy,'action_id',request_id));
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Native attack rejected for %: %',test_key,r; END IF;
  SELECT 200-current_hp INTO native_damage FROM battle_cards WHERE id=enemy;
  IF native_damage<>(CASE test_key WHEN 'studio_shield' THEN 4 WHEN 'studio_mark' THEN 28 ELSE 12 END) THEN RAISE EXCEPTION 'Native % damage wrong: %',test_key,native_damage; END IF;
  IF test_key='studio_defense' AND (SELECT defense FROM battle_cards WHERE id=enemy)<>10 THEN RAISE EXCEPTION 'DEF hit bonus not removed'; END IF;
  r:=public.submit_battle_action(code,'p1','rules1','attack',src,jsonb_build_object('target_card_id',enemy,'action_id',request_id));
  IF NOT coalesce((r->>'replayed')::boolean,false) OR (SELECT 200-current_hp FROM battle_cards WHERE id=enemy)<>native_damage THEN RAISE EXCEPTION 'Native replay applied twice'; END IF;
 END LOOP;
 -- Conditional +damage is omitted when the condition is false.
 UPDATE battle_status_effects SET active=false WHERE battle_id=b;
 UPDATE battle_cards SET current_hp=200,attack_turn_index=NULL,last_attacked_turn=NULL,attacks_this_turn=0 WHERE battle_id=b;
 SELECT id INTO sid FROM battle_card_skills WHERE battle_card_id=src AND metadata#>>'{master_metadata,slot}'='1';
 UPDATE battle_cards SET battle_metadata=battle_metadata-'studio_summoned_turn' WHERE id=ally;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',src,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',enemy));
 IF NOT coalesce((r->>'ok')::boolean,false) OR (SELECT current_hp FROM battle_cards WHERE id=enemy)<>180 THEN RAISE EXCEPTION 'False condition still added damage: %',r; END IF;
 -- Choice, wrong owner and missing choice must reject without usage/AP.
 SELECT id INTO sid FROM battle_card_skills WHERE battle_card_id=src AND metadata#>>'{master_metadata,slot}'='2';
 UPDATE battle_sessions SET player1_action_points=10 WHERE id=b;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',src,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',ally));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>10 THEN RAISE EXCEPTION 'Missing choice consumed AP'; END IF;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',src,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',enemy,'skill_option','heal'));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>10 THEN RAISE EXCEPTION 'Wrong-owner target accepted'; END IF;
 PERFORM public.tcg_studio_status(b,enemy,src,'studio_silence_slot2',1,'next_end');
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',src,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',ally,'skill_option','heal'));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Silenced slot 2 accepted'; END IF;
 UPDATE battle_status_effects SET active=false WHERE battle_id=b AND status_key='studio_silence_slot2';
 PERFORM public.tcg_studio_status(b,enemy,src,'root',1,'next_end');
 r:=public.submit_battle_action(code,'p1','rules1','move_to_bench',src,jsonb_build_object('action_id',gen_random_uuid()));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT zone FROM battle_cards WHERE id=src)<>'active' THEN RAISE EXCEPTION 'Root did not block moving'; END IF;
 UPDATE battle_status_effects SET active=false WHERE battle_id=b;
 -- End-turn ATK and next-start team DEF restore the exact base stats.
 PERFORM public.tcg_studio_status(b,src,ally,'studio_attack_buff',6,'end');
 PERFORM public.tcg_studio_status(b,src,ally,'studio_team_defense',3,'next_start');
 UPDATE battle_cards SET current_hp=40 WHERE id=ally;
 PERFORM public.tcg_studio_status(b,src,ally,'studio_delayed_heal',10,'next_end');
 PERFORM set_config('tcg.intra_turn_action','off',true);
 UPDATE battle_sessions SET current_turn='p2' WHERE id=b;
 IF (SELECT attack FROM battle_cards WHERE id=ally)<>30 OR (SELECT defense FROM battle_cards WHERE id=ally)<>13 OR (SELECT current_hp FROM battle_cards WHERE id=ally)<>40 THEN RAISE EXCEPTION 'First end-turn expiry incorrect: card %, statuses %, clocks %',(SELECT jsonb_build_object('atk',attack,'def',defense,'hp',current_hp) FROM battle_cards WHERE id=ally),(SELECT jsonb_agg(jsonb_build_object('key',status_key,'active',active,'meta',metadata)) FROM battle_status_effects WHERE target_card_id=ally AND metadata->>'studio_version'='2'),(SELECT jsonb_build_object('p1',player1_owner_turn,'p2',player2_owner_turn,'turn',current_turn) FROM battle_sessions WHERE id=b); END IF;
 UPDATE battle_sessions SET current_turn='p1' WHERE id=b;
 IF (SELECT defense FROM battle_cards WHERE id=ally)<>10 OR (SELECT current_hp FROM battle_cards WHERE id=ally)<>40 THEN RAISE EXCEPTION 'Next-start expiry incorrect'; END IF;
 UPDATE battle_sessions SET current_turn='p2' WHERE id=b;
 IF (SELECT current_hp FROM battle_cards WHERE id=ally)<>50 THEN RAISE EXCEPTION 'Delayed heal timing incorrect'; END IF;
 -- Multi-target attack validates both targets before writing any damage/AP.
 SELECT id INTO chain_card FROM game_cards WHERE metadata#>>'{studio_card,display_code}'='PAN-007' AND uid IS NULL LIMIT 1;
 PERFORM set_config('tcg.intra_turn_action','off',true); UPDATE battle_sessions SET current_turn='p1',player1_action_points=10 WHERE id=b;
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element) VALUES(chain,b,'p1',chain_card,gen_random_uuid()::text,'Panda','active',3,120,120,120,40,10,'Thunder');
 SELECT id INTO sid FROM battle_card_skills WHERE battle_card_id=chain AND metadata#>>'{master_metadata,slot}'='2';
 UPDATE battle_cards SET current_hp=200 WHERE id=enemy;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',chain,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',enemy,'target_card_ids',jsonb_build_array(enemy,enemy)));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT current_hp FROM battle_cards WHERE id=enemy)<>200 OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>10 THEN RAISE EXCEPTION 'Duplicate targets accepted or wrote damage'; END IF;
 INSERT INTO battle_cards(battle_id,player,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element) VALUES(b,'p2',gen_random_uuid()::text,'Second target','active',2,200,200,200,30,10,'Water') RETURNING id INTO request_id;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',chain,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',enemy,'target_card_ids',jsonb_build_array(enemy,request_id)));
 IF NOT coalesce((r->>'ok')::boolean,false) OR (SELECT current_hp FROM battle_cards WHERE id=enemy)<>184 OR (SELECT current_hp FROM battle_cards WHERE id=request_id)<>184 THEN RAISE EXCEPTION 'Two-target 0.65x ATK damage incorrect: %',r; END IF;
 UPDATE battle_sessions SET player1_action_points=10 WHERE id=b;
 -- Actual revive keeps every existing cooldown/usage row and rejects Fusion
 -- bodies, consumed materials, and a full Bench before charging AP.
 SELECT id INTO recall_card FROM game_cards WHERE metadata#>>'{studio_card,display_code}'='NUL-006' AND uid IS NULL LIMIT 1;
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element) VALUES(necro,b,'p1',recall_card,gen_random_uuid()::text,'Necro','active',4,120,120,120,30,10,'Dark');
 SELECT id INTO sid FROM battle_card_skills WHERE battle_card_id=necro AND metadata#>>'{master_metadata,slot}'='2';
 UPDATE battle_cards SET game_card_id=first_card,zone='graveyard',slot=NULL,current_hp=0,is_fusion_result=true,origin_type='fusion',card_kind='fusion' WHERE id=ally;
 INSERT INTO battle_card_skills(battle_id,battle_card_id,player,special_skill_id,skill_code,name,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,priority,cooldown_until_owner_turn,uses_count)
 SELECT b,ally,'p1',special_skill_id,'QA_PERSIST','Used ability','active','main_phase',source_zones,target_spec,cost_spec,limits,effects,false,1,99,1 FROM battle_card_skills WHERE battle_card_id=src LIMIT 1 RETURNING id INTO target_runtime;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',necro,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',ally));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Revived Fusion body'; END IF;
 INSERT INTO battle_fusions(id,battle_id,player,recipe_id,result_game_card_id) SELECT fusion_id,b,'p1',id,result_game_card_id FROM fusion_recipes LIMIT 1;
 UPDATE battle_cards SET is_fusion_result=false,origin_type='rfid',card_kind='normal' WHERE id=ally;
 INSERT INTO battle_cards(battle_id,player,uid,name,zone,hp,base_hp,current_hp,attack,defense,origin_type,card_kind,fusion_consumed,necro_consumed,consumed_by_fusion_id) VALUES(b,'p1',gen_random_uuid()::text,'Consumed fixture','graveyard',100,100,0,30,10,'rfid','normal',true,true,fusion_id) RETURNING id INTO request_id;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',necro,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',request_id));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Revived consumed material'; END IF;
 UPDATE battle_sessions SET max_bench=1 WHERE id=b;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',necro,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',ally));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>10 THEN RAISE EXCEPTION 'Revive Bench capacity guard failed'; END IF;
 UPDATE battle_sessions SET max_bench=4 WHERE id=b;
 r:=public.submit_battle_action(code,'p1','rules1','special_skill',necro,jsonb_build_object('skill_id',sid,'action_id',gen_random_uuid(),'target_card_id',ally));
 IF NOT coalesce((r->>'ok')::boolean,false) OR (SELECT current_hp FROM battle_cards WHERE id=ally)<>40 OR (SELECT zone FROM battle_cards WHERE id=ally)<>'bench' OR (SELECT zone FROM battle_cards WHERE id=necro)<>'active' THEN RAISE EXCEPTION 'Recall did not restore 40%% to Bench without sacrificing source: %',r; END IF;
 IF (SELECT cooldown_until_owner_turn FROM battle_card_skills WHERE id=target_runtime)<>99 OR (SELECT uses_count FROM battle_card_skills WHERE id=target_runtime)<>1 THEN RAISE EXCEPTION 'Recall reset usage or cooldown'; END IF;
 IF public.tcg_card_action_block_reason(b,ally,'attack') IS NULL OR public.tcg_card_action_block_reason(b,ally,'special_skill') IS NULL THEN RAISE EXCEPTION 'Revive lock absent'; END IF;
 PERFORM set_config('tcg.intra_turn_action','off',true); UPDATE battle_sessions SET current_turn='p2' WHERE id=b; UPDATE battle_sessions SET current_turn='p1' WHERE id=b;
 IF public.tcg_card_action_block_reason(b,ally,'attack') IS NOT NULL THEN RAISE EXCEPTION 'Revive lock did not expire at next own turn'; END IF;
 -- Internal effects and compiler are never callable with anonymous rights.
 IF has_function_privilege('anon','public.tcg_execute_studio_skill(uuid,text,uuid,jsonb,jsonb)','execute') OR has_function_privilege('authenticated','public.sync_studio_battle_skills(uuid,jsonb,jsonb)','execute') THEN RAISE EXCEPTION 'Private effect helper exposed'; END IF;
 RAISE NOTICE 'PASS: native Shield/DEF/guard/mark/debuff, conditional damage, replay, choices, target/slot/root guards, timed restoration and private helper privileges';
END $rules$;
