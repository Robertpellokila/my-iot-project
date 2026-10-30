-- Synthetic data only. Caller wraps this file in BEGIN/ROLLBACK.
CREATE TEMP TABLE combo_checks(label text);
CREATE FUNCTION pg_temp.combo_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label;END IF;INSERT INTO combo_checks VALUES(label);END $$;
-- Limit this transaction's catalog to two known seeded group recipes.
UPDATE tcg_combo_rule_catalog SET enabled=rule_kind IN ('triple','formation');
CREATE FUNCTION pg_temp.combo_fixture(types text[],ap integer DEFAULT 3) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE b uuid:=gen_random_uuid();c uuid;enemy uuid:=gen_random_uuid();ids uuid[]:='{}';i integer;q text:='COMBO-QA-'||b;
BEGIN
 PERFORM set_config('tcg.intra_turn_action','off',true);
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,
 question_enabled,question_active,combo_enabled,generic_combo_enabled,triple_combo_enabled,formation_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,
 player1_deck_remaining,player2_deck_remaining,turn_index,player1_owner_turn,player2_owner_turn,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card,status_effects_enabled)
 VALUES(b,q,'tcg_v1','battle','p1',1,50,'combo-qa-1-'||b,'combo-qa-2-'||b,200,200,200,200,false,false,true,true,true,true,true,ap,ap,0,20,20,1,1,1,60,now(),now()+interval '1 minute',4,4,1,false);
 FOR i IN 1..cardinality(types) LOOP
  c:=gen_random_uuid();ids:=array_append(ids,c);
  INSERT INTO battle_cards(id,battle_id,player,uid,name,card_code,zone,slot,hp,base_hp,current_hp,attack,defense,element,exhausted,tags)
  VALUES(c,b,'p1',c::text,'Combo QA '||i,'QA_'||i,'active',i,100,100,60,40,10,types[i],false,ARRAY['combo-team']);
 END LOOP;
 INSERT INTO battle_cards(id,battle_id,player,uid,name,card_code,zone,slot,hp,base_hp,current_hp,attack,defense,element,exhausted)
 VALUES(enemy,b,'p2',enemy::text,'Combo QA enemy','QA_E','active',1,1000,1000,1000,30,10,'water',false);
 RETURN jsonb_build_object('b',b,'code',q,'ids',to_jsonb(ids),'enemy',enemy);
END $$;
CREATE FUNCTION pg_temp.combo_action(f jsonb,ids jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.submit_battle_action(f->>'code','p1','combo-qa-1-'||(f->>'b'),'combo_attack',(coalesce(ids,f->'ids')->>0)::uuid,
 jsonb_build_object('participant_card_ids',coalesce(ids,f->'ids'),'target_card_id',f->>'enemy','action_id',gen_random_uuid()));
$$;
CREATE FUNCTION pg_temp.combo_state(f jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('cards',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM battle_cards c WHERE battle_id=(f->>'b')::uuid),
 'resources',(SELECT jsonb_build_array(player1_hp,player2_hp,player1_action_points,player2_action_points,current_turn,player1_combo_last_owner_turn,player2_combo_last_owner_turn) FROM battle_sessions WHERE id=(f->>'b')::uuid));
$$;
CREATE FUNCTION pg_temp.combo_reject(f jsonb,label text,ids jsonb DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
DECLARE before jsonb:=pg_temp.combo_state(f);r jsonb;
BEGIN r:=pg_temp.combo_action(f,ids);PERFORM pg_temp.combo_assert(NOT coalesce((r->>'ok')::boolean,false),label||' rejected: '||coalesce(r->>'message',''));PERFORM pg_temp.combo_assert(before=pg_temp.combo_state(f),label||' preserves cards/AP/cooldown');END $$;
CREATE FUNCTION pg_temp.combo_next(f jsonb) RETURNS void LANGUAGE plpgsql AS $$
DECLARE r jsonb;
BEGIN
 IF (SELECT current_turn FROM battle_sessions WHERE id=(f->>'b')::uuid)='p1' THEN r:=public.submit_battle_action(f->>'code','p1','combo-qa-1-'||(f->>'b'),'end_turn',NULL,'{}');PERFORM pg_temp.combo_assert((r->>'ok')::boolean,'End p1 turn');END IF;
 r:=public.submit_battle_action(f->>'code','p2','combo-qa-2-'||(f->>'b'),'end_turn',NULL,'{}');PERFORM pg_temp.combo_assert((r->>'ok')::boolean,'End p2 turn');
END $$;
DO $tests$
DECLARE f jsonb;r jsonb;s jsonb;ids jsonb;before jsonb;v public.tcg_combo_rule_catalog;denied boolean;rec bigint;old_snapshot jsonb;mode text;request_id uuid;admin_id uuid;ally uuid;
BEGIN
 FOREACH mode IN ARRAY ARRAY['generic','triple','formation'] LOOP
  f:=pg_temp.combo_fixture(CASE mode WHEN 'generic' THEN ARRAY['fire','fire'] WHEN 'triple' THEN ARRAY['dark','fire','thunder'] ELSE ARRAY['forest','knight','light','thunder'] END);
  r:=pg_temp.combo_action(f);
  PERFORM pg_temp.combo_assert((r->>'ok')::boolean,mode||' succeeds: '||r::text);
  PERFORM pg_temp.combo_assert((r->>'damage')::integer=CASE mode WHEN 'generic' THEN 50 WHEN 'triple' THEN 88 ELSE 92 END,mode||' correct damage');
  PERFORM pg_temp.combo_assert((SELECT bool_and(zone='active' AND attacks_this_turn=1 AND (battle_metadata->>'pilot_attack_owner_turn')::int=1) FROM battle_cards WHERE battle_id=(f->>'b')::uuid AND player='p1'),mode||' consumes every attack and retains cards');
  PERFORM pg_temp.combo_assert((SELECT player1_action_points=CASE mode WHEN 'generic' THEN 1 ELSE 0 END AND player1_combo_last_owner_turn=1 FROM battle_sessions WHERE id=(f->>'b')::uuid),mode||' spends AP and records owner cooldown');
  PERFORM pg_temp.combo_next(f);PERFORM pg_temp.combo_reject(f,mode||' next own turn cooldown');
  PERFORM pg_temp.combo_next(f);r:=pg_temp.combo_action(f);PERFORM pg_temp.combo_assert((r->>'ok')::boolean,mode||' ready again after one skipped own turn');
 END LOOP;
 f:=pg_temp.combo_fixture(ARRAY['fire','fire','forest','forest'],10);ids:=jsonb_build_array(f#>>'{ids,0}',f#>>'{ids,1}');r:=pg_temp.combo_action(f,ids);PERFORM pg_temp.combo_assert((r->>'ok')::boolean,'First combo with extra AP');
 PERFORM pg_temp.combo_reject(f,'Different partners cannot bypass same-turn cap',jsonb_build_array(f#>>'{ids,2}',f#>>'{ids,3}'));
 PERFORM pg_temp.combo_next(f);PERFORM pg_temp.combo_reject(f,'Different partners cannot bypass player cooldown',jsonb_build_array(f#>>'{ids,2}',f#>>'{ids,3}'));
 f:=pg_temp.combo_fixture(ARRAY['fire','fire','fire']);PERFORM pg_temp.combo_reject(f,'Generic cannot substitute for missing Triple');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire','fire','fire']);PERFORM pg_temp.combo_reject(f,'Generic cannot substitute for missing Formation');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_sessions SET generic_combo_enabled=false WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Generic disabled');
 f:=pg_temp.combo_fixture(ARRAY['dark','fire','thunder']);UPDATE battle_sessions SET triple_combo_enabled=false WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Triple disabled');
 f:=pg_temp.combo_fixture(ARRAY['forest','knight','light','thunder']);UPDATE battle_sessions SET formation_enabled=false WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Formation disabled');
 f:=pg_temp.combo_fixture(ARRAY['dark','fire','thunder']);UPDATE battle_sessions SET player1_action_points=2 WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Triple insufficient AP');
 f:=pg_temp.combo_fixture(ARRAY['dark','fire','thunder'],4);UPDATE battle_sessions SET player1_action_points=3,action_costs=action_costs||'{"combo_attack":4,"triple_combo":3}' WHERE id=(f->>'b')::uuid;r:=pg_temp.combo_action(f);PERFORM pg_temp.combo_assert((r->>'ok')::boolean,'Affordable Triple not blocked by higher pair cost');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_cards SET card_kind='fusion' WHERE id=(f#>>'{ids,1}')::uuid;PERFORM pg_temp.combo_reject(f,'Fusion participant');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);PERFORM pg_temp.combo_reject(f,'Duplicate participant',jsonb_build_array(f#>>'{ids,0}',f#>>'{ids,0}'));
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_cards SET zone='bench',slot=NULL WHERE id=(f#>>'{ids,1}')::uuid;PERFORM pg_temp.combo_reject(f,'Bench participant');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_cards SET current_hp=0 WHERE id=(f#>>'{ids,1}')::uuid;PERFORM pg_temp.combo_reject(f,'KO participant');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_sessions SET teacher_paused=true WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Teacher pause');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_sessions SET question_active=true,status='question' WHERE id=(f->>'b')::uuid;PERFORM pg_temp.combo_reject(f,'Quiz lock');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_cards SET attack_turn_index=1,attacks_this_turn=1 WHERE id=(f#>>'{ids,1}')::uuid;PERFORM pg_temp.combo_reject(f,'Participant attack already used');
 f:=pg_temp.combo_fixture(ARRAY['forest','knight','light','thunder']);UPDATE battle_sessions SET status_effects_enabled=true WHERE id=(f->>'b')::uuid;r:=pg_temp.combo_action(f);
 PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND (SELECT bool_and(current_hp=65) FROM battle_cards WHERE battle_id=(f->>'b')::uuid AND player='p1'),'Formation heals every participant by 5');
 PERFORM pg_temp.combo_assert(EXISTS(SELECT 1 FROM battle_status_effects WHERE battle_id=(f->>'b')::uuid AND target_card_id=(f#>>'{ids,0}')::uuid AND status_key='shield' AND active),'Formation applies Shield');
 f:=pg_temp.combo_fixture(ARRAY['dark','fire','thunder']);UPDATE battle_sessions SET status_effects_enabled=true WHERE id=(f->>'b')::uuid;r:=pg_temp.combo_action(f);
 PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND EXISTS(SELECT 1 FROM battle_status_effects WHERE battle_id=(f->>'b')::uuid AND target_card_id=(f->>'enemy')::uuid AND status_key='burn'),'Triple applies Burn');
 -- Same request is replayed, never charged or applied twice, including after reconnect.
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);request_id:=gen_random_uuid();s:=jsonb_build_object('participant_card_ids',f->'ids','target_card_id',f->>'enemy','action_id',request_id);
 r:=public.submit_battle_action(f->>'code','p1','combo-qa-1-'||(f->>'b'),'combo_attack',(f#>>'{ids,0}')::uuid,s);before:=pg_temp.combo_state(f);
 r:=public.submit_battle_action(f->>'code','p1','combo-qa-1-'||(f->>'b'),'combo_attack',(f#>>'{ids,0}')::uuid,s);
 PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND (r->>'replayed')::boolean AND pg_temp.combo_state(f)=before,'Replayed Combo is idempotent');
 -- Opponent has its own cooldown ledger.
 ally:=gen_random_uuid();INSERT INTO battle_cards(id,battle_id,player,uid,name,card_code,zone,slot,hp,base_hp,current_hp,attack,defense,element,exhausted)
 VALUES(ally,(f->>'b')::uuid,'p2',ally::text,'Opponent ally','QA_P2','active',2,1000,1000,1000,10,10,'water',false);
 r:=public.submit_battle_action(f->>'code','p1','combo-qa-1-'||(f->>'b'),'end_turn',NULL,'{}');
 r:=public.submit_battle_action(f->>'code','p2','combo-qa-2-'||(f->>'b'),'combo_attack',(f->>'enemy')::uuid,jsonb_build_object('participant_card_ids',jsonb_build_array(f->>'enemy',ally),'target_card_id',f#>>'{ids,0}'));
 PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND (SELECT player1_combo_last_owner_turn=1 AND player2_combo_last_owner_turn=player2_owner_turn FROM battle_sessions WHERE id=(f->>'b')::uuid),'Opponent Combo independent from first player cooldown');
 -- Matching is independent of chosen primary/order and does not reuse a card.
 INSERT INTO tcg_combo_rule_catalog(rule_kind,type_keys,combo_name,assist_multipliers,members,shared_tag,priority)
 VALUES('same',ARRAY['fire','fire'],'QA Exact Pair',ARRAY[.7], '[{"type":"fire"},{"type":"fire","card_code":"QA-1","tag":"combo-team"}]',true,10) RETURNING id INTO rec;
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);r:=pg_temp.combo_action(f,jsonb_build_array(f#>>'{ids,1}',f#>>'{ids,0}'));PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND r->>'combo_name'='QA Exact Pair','Specific card/tag recipe matches reverse order');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);UPDATE battle_cards SET tags=ARRAY['wrong-tag'] WHERE id=(f#>>'{ids,0}')::uuid;r:=pg_temp.combo_action(f);PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND r->>'combo_name'='Combined Strike','Unmatched named recipe falls back to weaker Generic');
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);SELECT combo_rules_snapshot INTO old_snapshot FROM battle_sessions WHERE id=(f->>'b')::uuid;
 UPDATE tcg_combo_rule_catalog SET enabled=false WHERE id=rec;
 UPDATE battle_sessions SET combo_policy='{}',combo_rules_snapshot='[]' WHERE id=(f->>'b')::uuid;
 PERFORM pg_temp.combo_assert((SELECT combo_policy->>'version'='1' AND combo_rules_snapshot=old_snapshot FROM battle_sessions WHERE id=(f->>'b')::uuid),'Battle policy and recipe snapshot immutable');
 r:=pg_temp.combo_action(f);PERFORM pg_temp.combo_assert((r->>'ok')::boolean AND r->>'combo_name'='QA Exact Pair','Existing match keeps its saved recipe after admin edit');
 -- Guard invalid tokens and anonymous recipe writes.
 f:=pg_temp.combo_fixture(ARRAY['fire','fire']);before:=pg_temp.combo_state(f);
 r:=public.submit_battle_action(f->>'code','p1','invalid','combo_attack',(f#>>'{ids,0}')::uuid,jsonb_build_object('participant_card_ids',f->'ids','target_card_id',f->>'enemy'));
 PERFORM pg_temp.combo_assert(NOT (r->>'ok')::boolean AND before=pg_temp.combo_state(f),'Invalid player token leaves battle untouched');
 SET LOCAL ROLE anon;
 r:=public.get_public_battle_state(f->>'code');
 BEGIN UPDATE battle_sessions SET player1_combo_last_owner_turn=999 WHERE id=(f->>'b')::uuid;EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 RESET ROLE;
 PERFORM pg_temp.combo_assert(r#>>'{battle,combo_policy,version}'='1' AND jsonb_typeof(r#>'{battle,combo_rules_snapshot}')='array','Public state exposes saved Combo rules');
 PERFORM pg_temp.combo_assert(pg_temp.combo_state(f)=before,'Anonymous client cannot forge Combo usage');
 denied:=false;BEGIN PERFORM public.save_combo_recipe('{}');EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;PERFORM pg_temp.combo_assert(denied,'Recipe save requires admin');
 PERFORM pg_temp.combo_assert(NOT has_function_privilege('anon','public.save_combo_recipe(jsonb)','EXECUTE') AND NOT has_table_privilege('authenticated','tcg_combo_rule_catalog','UPDATE'),'Clients cannot bypass recipe save guard');
 -- Actual admin RPC with optimistic locking and malformed rule validation.
 SELECT id INTO admin_id FROM profiles WHERE role='admin' LIMIT 1;PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 r:=public.save_combo_recipe(jsonb_build_object('combo_name','QA Admin Rule','rule_kind','same','type_keys',jsonb_build_array('fire','fire'),'assist_multipliers',jsonb_build_array(.5),'members',jsonb_build_array(jsonb_build_object('type','fire','card_code','QA_1'),jsonb_build_object('type','fire','tag','combo-team'))));
 PERFORM pg_temp.combo_assert(r->>'id' IS NOT NULL AND jsonb_array_length(r->'members')=2,'Admin saves exact-card/tag recipe');s:=r;
 r:=public.save_combo_recipe(r||'{"bonus_damage":4}');denied:=false;BEGIN PERFORM public.save_combo_recipe(s);EXCEPTION WHEN OTHERS THEN denied:=position('sudah berubah' in SQLERRM)>0;END;PERFORM pg_temp.combo_assert(denied,'Stale admin update rejected');
 denied:=false;BEGIN PERFORM public.save_combo_recipe(r||'{"assist_multipliers":[3]}');EXCEPTION WHEN OTHERS THEN denied:=true;END;PERFORM pg_temp.combo_assert(denied,'Unsafe multiplier rejected');
 PERFORM set_config('request.jwt.claim.sub','',true);
END $tests$;
SELECT count(*) AS passed,jsonb_agg(label) AS checks FROM combo_checks;
