-- Synthetic fixtures only. Run in a transaction ending in ROLLBACK.
CREATE TEMP TABLE pilot_checks(label text);
CREATE FUNCTION pg_temp.pilot_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; INSERT INTO pilot_checks VALUES(label); END $$;
CREATE FUNCTION pg_temp.pilot_fixture() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE b uuid:=gen_random_uuid(); src uuid:=gen_random_uuid(); ally uuid:=gen_random_uuid(); bench uuid:=gen_random_uuid(); enemy uuid:=gen_random_uuid(); q text:='PILOT-QA-'||b;
BEGIN
 PERFORM set_config('tcg.intra_turn_action','off',true);
 INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,
 player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,
 fusion_enabled,combo_enabled,generic_combo_enabled,action_points_enabled,action_points_per_turn,player1_action_points,
 player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,
 turn_deadline_at,max_active,max_bench,max_attacks_per_card,player1_skill,status_effects_enabled)
 VALUES(b,q,'tcg_v1','battle','p1',1,50,'pilot-qa-1-'||b,'pilot-qa-2-'||b,200,200,200,200,false,false,true,true,true,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1,100,false);
 INSERT INTO public.battle_cards(id,battle_id,player,uid,name,card_code,zone,slot,hp,base_hp,current_hp,attack,defense,element,exhausted)
 VALUES(src,b,'p1',src::text,'QA Source','QA_A','active',1,100,100,60,30,10,'Fire',false),
 (ally,b,'p1',ally::text,'QA Ally','QA_B','active',2,100,100,80,30,10,'Fire',false),
 (bench,b,'p1',bench::text,'QA Bench','QA_C','bench',NULL,100,100,80,30,10,'Forest',false),
 (enemy,b,'p2',enemy::text,'QA Enemy','QA_E','active',1,500,500,500,30,10,'Water',false);
 RETURN jsonb_build_object('b',b,'code',q,'src',src,'ally',ally,'bench',bench,'enemy',enemy);
END $$;
CREATE FUNCTION pg_temp.pilot_action(f jsonb,a text,c text DEFAULT 'src',payload jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN RETURN public.submit_battle_action(f->>'code',coalesce(f->>'player','p1'),'pilot-qa-'||CASE WHEN f->>'player'='p2' THEN '2-' ELSE '1-' END||(f->>'b'),a,(f->>c)::uuid,jsonb_build_object('action_id',gen_random_uuid())||payload); END $$;
CREATE FUNCTION pg_temp.pilot_state(f jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('cards',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM battle_cards c WHERE battle_id=(f->>'b')::uuid),
 'skills',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM battle_card_skills c WHERE battle_id=(f->>'b')::uuid),
 'uses',(SELECT count(*) FROM battle_special_skill_uses WHERE battle_id=(f->>'b')::uuid),
 'statuses',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM battle_status_effects c WHERE battle_id=(f->>'b')::uuid),
 'resources',(SELECT jsonb_build_array(player1_hp,player2_hp,player1_skill,player2_skill,player1_action_points,player2_action_points,current_turn) FROM battle_sessions WHERE id=(f->>'b')::uuid));
$$;
CREATE FUNCTION pg_temp.pilot_reject(f jsonb,a text,c text,payload jsonb,label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE before jsonb:=pg_temp.pilot_state(f); r jsonb;
BEGIN
 r:=pg_temp.pilot_action(f,a,c,payload);
 PERFORM pg_temp.pilot_assert(NOT coalesce((r->>'ok')::boolean,false),label||' rejects: '||coalesce(r->>'message',''));
 PERFORM pg_temp.pilot_assert(pg_temp.pilot_state(f)=before,label||' preserves HP/AP/gauge/status/skill usage');
END $$;
CREATE FUNCTION pg_temp.pilot_skill(f jsonb,ops jsonb,target text DEFAULT 'enemy_active',attacks boolean DEFAULT false,source text DEFAULT 'src',limits jsonb DEFAULT '{"action_points":1,"cooldown_turns":0}') RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE s uuid:=gen_random_uuid();
BEGIN
 INSERT INTO public.battle_card_skills(id,battle_id,battle_card_id,player,special_skill_id,skill_code,name,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,disabled)
 VALUES(s,(f->>'b')::uuid,(f->>source)::uuid,'p1',(SELECT id FROM special_skills LIMIT 1),s::text,'Pilot fixture','active','main_phase',ARRAY['active'],jsonb_build_object('type',target),'{}',limits,
 jsonb_build_array(jsonb_build_object('type','studio_skill','program',jsonb_build_object('version',2,'target',target,'attacks',attacks,'operations',ops))),false,false);
 RETURN s;
END $$;
CREATE FUNCTION pg_temp.pilot_next_turn(f jsonb) RETURNS void LANGUAGE plpgsql AS $$
DECLARE r jsonb;
BEGIN
 IF (SELECT current_turn FROM battle_sessions WHERE id=(f->>'b')::uuid)='p1' THEN r:=pg_temp.pilot_action(f,'end_turn'); PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'End owner turn'); END IF;
 r:=public.submit_battle_action(f->>'code','p2','pilot-qa-2-'||(f->>'b'),'end_turn',NULL,'{}');
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Start next owner turn');
END $$;

DO $tests$
DECLARE f jsonb; ff jsonb; r jsonb; s uuid; s2 uuid; before jsonb; q uuid; fid uuid; rid uuid; copy_id uuid; old_state jsonb; act text;
BEGIN
 f:=pg_temp.pilot_fixture();
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Normal attack succeeds');
 PERFORM pg_temp.pilot_reject(f,'move_to_bench','src','{}','Attack then Bench');
 PERFORM pg_temp.pilot_reject(f,'switch_active','bench',jsonb_build_object('active_card_id',f->>'src'),'Attack then swap');
 PERFORM pg_temp.pilot_reject(f,'ultimate','src','{}','Attack then Ultimate');
 PERFORM pg_temp.pilot_reject(f,'synergy','src','{}','Attack then damage Synergy');
 s:=pg_temp.pilot_skill(f,'[{"type":"attack","condition":"always","amount":0,"multiplier":1}]','enemy_active',true);
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy'),'Attack then damage skill');
 s:=pg_temp.pilot_skill(f,'[{"type":"switch"}]','ally_active',false,'ally');
 PERFORM pg_temp.pilot_reject(f,'special_skill','ally',jsonb_build_object('skill_id',s,'target_card_id',f->>'src','bench_card_id',f->>'bench'),'Ally Switch cannot rescue attacker');
 s:=pg_temp.pilot_skill(f,'[{"type":"shield","amount":8,"expiry":"next_start"}]','ally_active',false,'ally');
 r:=pg_temp.pilot_action(f,'special_skill','ally',jsonb_build_object('skill_id',s,'target_card_id',f->>'src'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Ally Shield still protects attacker');
 s:=pg_temp.pilot_skill(f,'[{"type":"heal","amount":7}]','self_card',false,'src');
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'src'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Healing after attack allowed');
 PERFORM pg_temp.pilot_assert(public.tcg_pilot_committed((f->>'src')::uuid),'Retreat lock persists during opponent turn');
 PERFORM pg_temp.pilot_next_turn(f);
 PERFORM pg_temp.pilot_assert(NOT public.tcg_pilot_committed((f->>'src')::uuid),'Retreat lock clears at next owner start');
 r:=pg_temp.pilot_action(f,'move_to_bench');PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Retreat next turn succeeds');
 r:=pg_temp.pilot_action(f,'return_from_bench');PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Return before attacking succeeds');
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Return then attack succeeds');

 FOREACH act IN ARRAY ARRAY['ultimate','synergy','combo_attack','special_skill'] LOOP
   f:=pg_temp.pilot_fixture();
   IF act='combo_attack' THEN
     r:=pg_temp.pilot_action(f,act,'src',jsonb_build_object('participant_card_ids',jsonb_build_array(f->>'src',f->>'ally'),'target_card_id',f->>'enemy'));
   ELSIF act='special_skill' THEN
     s:=pg_temp.pilot_skill(f,'[{"type":"attack","condition":"always","amount":0,"multiplier":1}]','enemy_active',true);
     r:=pg_temp.pilot_action(f,act,'src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy'));
   ELSE r:=pg_temp.pilot_action(f,act); END IF;
   PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,act||' succeeds: '||r::text);
   PERFORM pg_temp.pilot_reject(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'),act||' consumes shared attack');
   PERFORM pg_temp.pilot_reject(f,'move_to_bench','src','{}',act||' locks retreat');
   IF act='combo_attack' THEN
     PERFORM pg_temp.pilot_reject(f,'attack','ally',jsonb_build_object('target_card_id',f->>'enemy'),'Combo assist consumes attack');
     PERFORM pg_temp.pilot_reject(f,'move_to_bench','ally','{}','Combo assist locks retreat');
   END IF;
 END LOOP;

 f:=pg_temp.pilot_fixture();
 s:=pg_temp.pilot_skill(f,'[{"type":"root","amount":1}]');
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Debuff succeeds');
 PERFORM pg_temp.pilot_reject(f,'move_to_bench','src','{}','Debuff locks retreat');
 PERFORM pg_temp.pilot_assert(public.tcg_battle_card_can_attack((f->>'src')::uuid,1,1),'Non-damage debuff preserves attack allowance');
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Attack after debuff succeeds');

 -- Failure inside a multi-effect skill must roll back its early commitment.
 f:=pg_temp.pilot_fixture();
 s:=pg_temp.pilot_skill(f,'[{"type":"attack","condition":"always","amount":0,"multiplier":1},{"type":"switch","target":"self"}]','enemy_active',true);
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy','bench_card_id',f->>'bench'),'Compound damage then self-Switch');

 -- Generic (non-Studio) damage uses exactly the same allowance.
 f:=pg_temp.pilot_fixture();s:=pg_temp.pilot_skill(f,'[]');
 UPDATE battle_card_skills SET effects='[{"type":"damage_card","target":"target_card","owner":"enemy","allowed_zones":["active"],"amount":{"mode":"fixed","value":10}}]' WHERE id=s;
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Legacy damage skill succeeds');
 PERFORM pg_temp.pilot_reject(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'),'Legacy damage shares attack quota');

 -- Moves preserve skill cooldown, use count and active status records.
 f:=pg_temp.pilot_fixture();s:=pg_temp.pilot_skill(f,'[{"type":"shield","amount":10,"expiry":"next_start"}]','self_card',false,'src','{"action_points":1,"cooldown_turns":2,"once_per_battle":true}');
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'src'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Once-per-battle utility succeeds');
 SELECT to_jsonb(c) INTO old_state FROM battle_card_skills c WHERE id=s;
 r:=pg_temp.pilot_action(f,'move_to_bench');PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Utility does not lock retreat');
 PERFORM pg_temp.pilot_assert((SELECT to_jsonb(c)=old_state FROM battle_card_skills c WHERE id=s),'Bench keeps cooldown and use ledger');
 PERFORM pg_temp.pilot_assert(EXISTS(SELECT 1 FROM battle_status_effects WHERE target_card_id=(f->>'src')::uuid AND active AND status_key='studio_shield'),'Bench keeps unexpired shield');
 r:=pg_temp.pilot_action(f,'return_from_bench');PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Utility card returns');
 PERFORM pg_temp.pilot_next_turn(f);
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'src'),'Returning does not reset usage/CD');

 -- Use a synthetic recipe referencing an existing Fusion master; the master
 -- and its stats/skills are read only, never altered by the test.
 SELECT id INTO fid FROM game_cards WHERE fusion_only AND public.tcg_card_battle_available(id) LIMIT 1;
 PERFORM pg_temp.pilot_assert(fid IS NOT NULL,'Fusion master exists');rid:=gen_random_uuid();
 INSERT INTO fusion_recipes(id,code,name,result_game_card_id,is_active,result_zone,material_destination,consumes_turn,limits,result_stat_spec)
 VALUES(rid,'pilot_qa_'||rid,'Pilot QA',fid,true,'active','graveyard',false,'{}','{"hp":{"mode":"fixed","value":150},"attack":{"mode":"fixed","value":40},"defense":{"mode":"fixed","value":10}}');
 INSERT INTO fusion_recipe_materials(recipe_id,material_type,card_code,quantity,allowed_zones,optional,sort_order)
 VALUES(rid,'exact_card','QA_A',1,ARRAY['active','bench'],false,1),(rid,'exact_card','QA_B',1,ARRAY['active','bench'],false,2);
 f:=pg_temp.pilot_fixture();
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Material attacks');
 PERFORM pg_temp.pilot_assert(NOT (public.tcg_match_fusion_recipe((f->>'b')::uuid,'p1',rid)->>'available')::boolean,'Matcher excludes offensive material');
 PERFORM pg_temp.pilot_reject(f,'fusion','src',jsonb_build_object('recipe_id',rid),'Attack then Fusion');
 copy_id:=gen_random_uuid();
 INSERT INTO battle_cards(id,battle_id,player,uid,name,card_code,zone,hp,base_hp,current_hp,attack,defense,element,exhausted)
 VALUES(copy_id,(f->>'b')::uuid,'p1',copy_id::text,'Unused copy','QA_A','bench',100,100,100,30,10,'Fire',false);
 r:=public.tcg_match_fusion_recipe((f->>'b')::uuid,'p1',rid);
 PERFORM pg_temp.pilot_assert((r->>'available')::boolean AND EXISTS(SELECT 1 FROM jsonb_array_elements(r->'materials') m WHERE m->>'battle_card_id'=copy_id::text),'Matcher chooses unused duplicate');

 f:=pg_temp.pilot_fixture();r:=pg_temp.pilot_action(f,'fusion','src',jsonb_build_object('recipe_id',rid));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Legal Fusion succeeds');
 SELECT id INTO q FROM battle_cards WHERE battle_id=(f->>'b')::uuid AND fusion_recipe_id=rid;
 f:=jsonb_set(f,'{src}',to_jsonb(q));
 PERFORM pg_temp.pilot_assert((SELECT player1_action_points=1 FROM battle_sessions WHERE id=(f->>'b')::uuid),'Fusion costs 2 AP');
 PERFORM pg_temp.pilot_assert((SELECT count(*)=2 FROM battle_cards WHERE battle_id=(f->>'b')::uuid AND fusion_consumed AND zone='graveyard'),'Fusion consumes both materials');
 PERFORM pg_temp.pilot_reject(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'),'New Fusion cannot attack');
 s:=pg_temp.pilot_skill(f,'[{"type":"root","amount":1}]');
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'enemy'),'New Fusion cannot debuff');
 s:=pg_temp.pilot_skill(f,'[{"type":"shield","amount":8,"expiry":"next_start"}]','self_card');
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',q));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'New Fusion may use utility');
 PERFORM pg_temp.pilot_next_turn(f);
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Fusion can attack next owner turn');
 ff:=f;

 f:=pg_temp.pilot_fixture();
 UPDATE battle_cards SET uid=NULL,card_kind='fusion',origin_type='fusion',is_fusion_result=true WHERE id=(f->>'bench')::uuid;
 copy_id:=gen_random_uuid();
 INSERT INTO battle_cards(id,battle_id,player,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element,card_kind,origin_type,is_fusion_result)
 VALUES(copy_id,(f->>'b')::uuid,'p1',NULL,'Existing Fusion','active',3,100,100,100,30,10,'Water','fusion','fusion',true);
 PERFORM pg_temp.pilot_reject(f,'return_from_bench','bench','{}','Second Fusion cannot enter empty Active slot');
 PERFORM pg_temp.pilot_reject(f,'switch_active','bench',jsonb_build_object('active_card_id',f->>'src'),'Second Fusion cannot swap with Base');
 PERFORM pg_temp.pilot_assert(NOT (public.tcg_match_fusion_recipe((f->>'b')::uuid,'p1',rid)->>'available')::boolean,'Matcher explains Fusion Active cap');
 PERFORM pg_temp.pilot_reject(f,'fusion','src',jsonb_build_object('recipe_id',rid),'Fusion creation respects cap');
 s:=pg_temp.pilot_skill(f,'[{"type":"switch"}]','ally_active');
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'ally','bench_card_id',f->>'bench'),'Ally Switch respects Fusion cap');
 r:=pg_temp.pilot_action(f,'switch_active','bench',jsonb_build_object('active_card_id',copy_id));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Replacing old Fusion with Bench Fusion is legal');

 -- Player 2 uses its own clock, not round or the opponent's turn counter.
 f:=pg_temp.pilot_fixture();r:=pg_temp.pilot_action(f,'end_turn');
 f:=f||jsonb_build_object('player','p2','src',f->>'enemy','enemy',f->>'src');
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Player 2 attacks');
 PERFORM pg_temp.pilot_reject(f,'move_to_bench','src','{}','Player 2 retreat lock');
 r:=pg_temp.pilot_action(f,'end_turn');PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Player 2 ends turn');
 PERFORM pg_temp.pilot_assert(public.tcg_pilot_committed((f->>'src')::uuid),'Player 2 lock stays during player 1 turn');
 r:=public.submit_battle_action(f->>'code','p1','pilot-qa-1-'||(f->>'b'),'end_turn',NULL,'{}');
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean AND NOT public.tcg_pilot_committed((f->>'src')::uuid),'Player 2 lock clears next owner start');

 -- A stale attack flag on a choice program must not turn a heal into damage.
 f:=pg_temp.pilot_fixture();
 r:=pg_temp.pilot_action(f,'attack','src',jsonb_build_object('target_card_id',f->>'enemy'));
 s:=pg_temp.pilot_skill(f,'[]','self_card',true);
 UPDATE battle_card_skills SET effects='[{"type":"studio_skill","program":{"version":2,"target":"self_card","attacks":true,"choices":[{"id":"heal","operations":[{"type":"heal","amount":5}]},{"id":"hit","operations":[{"type":"attack","condition":"always","amount":0,"multiplier":1}]}]}}]' WHERE id=s;
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'skill_option','heal','target_card_id',f->>'src'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Actual heal choice stays legal after attack');
 PERFORM pg_temp.pilot_assert((SELECT attacks_this_turn=1 FROM battle_cards WHERE id=(f->>'src')::uuid),'Heal choice does not spend another attack');

 -- Recall still rejects consumed materials and keeps usage of a revived card.
 f:=ff;
 s:=pg_temp.pilot_skill(f,'[{"type":"revive","amount":0.4}]','ally_graveyard');
 PERFORM pg_temp.pilot_reject(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'ally'),'Recall rejects consumed material');
 f:=pg_temp.pilot_fixture();
 s2:=pg_temp.pilot_skill(f,'[{"type":"heal","amount":7}]','self_card',false,'ally','{"action_points":0,"cooldown_turns":0,"once_per_battle":true}');
 r:=pg_temp.pilot_action(f,'special_skill','ally',jsonb_build_object('skill_id',s2,'target_card_id',f->>'ally'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Base spends its once-per-battle utility');
 UPDATE battle_cards SET zone='graveyard',slot=NULL,current_hp=0 WHERE id=(f->>'ally')::uuid;
 s:=pg_temp.pilot_skill(f,'[{"type":"revive","amount":0.4}]','ally_graveyard');
 r:=pg_temp.pilot_action(f,'special_skill','src',jsonb_build_object('skill_id',s,'target_card_id',f->>'ally'));
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Recall revives ordinary Base');
 r:=pg_temp.pilot_action(f,'return_from_bench','ally');
 PERFORM pg_temp.pilot_assert((r->>'ok')::boolean,'Revived card may enter Active');
 PERFORM pg_temp.pilot_reject(f,'attack','ally',jsonb_build_object('target_card_id',f->>'enemy'),'Revived card cannot attack yet');
 PERFORM pg_temp.pilot_reject(f,'synergy','ally','{}','Revived card cannot activate Synergy yet');
 PERFORM pg_temp.pilot_next_turn(f);
 PERFORM pg_temp.pilot_reject(f,'special_skill','ally',jsonb_build_object('skill_id',s2,'target_card_id',f->>'ally'),'Revival preserves once-per-battle ledger after delay expires');
END $tests$;
SELECT count(*) AS checks_passed FROM pilot_checks;
