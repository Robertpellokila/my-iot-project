-- Linked-project smoke. New fixture records and battle actions always roll back.
BEGIN;
DO $smoke$
DECLARE account_id uuid; response jsonb; entry jsonb; workspace jsonb; master uuid; physical uuid;
 first_skill uuid; second_skill uuid; definition jsonb; b uuid:=gen_random_uuid(); source_card uuid:=gen_random_uuid(); ally uuid:=gen_random_uuid(); runtime uuid; result jsonb;
BEGIN
 SELECT id INTO account_id FROM public.profiles WHERE role='admin' LIMIT 1;
 IF account_id IS NULL THEN RAISE EXCEPTION 'Admin profile required for smoke test'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 workspace:='{"dataset_id":"studio-override-smoke","custom_cards":[],"artworks":{}}';
 entry:='[{"key":"DRAFT-OVERRIDE-QA","card":{"card_code":"DRAFT-OVERRIDE-QA","display_code":"QA_OVERRIDE","name":"Override rollback test","type":"Knight","rarity":"Common","kind":"base","stats":{"hp":120,"attack":30,"defense":14},"skills":[{"name":"Guard","description":"Beri Shield 8 pada 1 ally. CD 2."},{"name":"Heal","description":"Pulihkan 7 HP pada 1 ally. CD 2."}],"tags":[]},"artwork":{}}]';
 response:=public.save_card_studio('studio-override-smoke',workspace,entry);
 master:=(response#>>'{entries,0,game_card_id}')::uuid;
 SELECT s.id INTO first_skill FROM special_skills s JOIN game_card_special_skills l ON l.special_skill_id=s.id WHERE l.game_card_id=master AND l.sort_order=1;
 SELECT s.id INTO second_skill FROM special_skills s JOIN game_card_special_skills l ON l.special_skill_id=s.id WHERE l.game_card_id=master AND l.sort_order=2;
 UPDATE special_skills SET code='override_qa_'||replace(master::text,'-',''),name='Custom Recovery',description='Pulihkan 19 HP pada satu ally. Biaya 2 AP. CD 4.',icon='https://example.invalid/override.webp',
   target_spec='{"type":"ally_active","required":true}',cost_spec='{"type":"none"}',limits='{"action_points":2,"cooldown_turns":4}',
   effects='[{"type":"heal_card","target":"target_card","owner":"self","allowed_zones":["active"],"amount":{"mode":"fixed","value":19}}]',consumes_turn=false
 WHERE id=first_skill;
 SELECT to_jsonb(s)-'updated_at' INTO definition FROM special_skills s WHERE id=first_skill;
 IF NOT (definition#>>'{metadata,studio_customized}')::boolean THEN RAISE EXCEPTION 'Direct skill edit was not marked customized'; END IF;
 entry:=jsonb_set(entry,'{0,card,stats,hp}','143');
 entry:=jsonb_set(entry,'{0,card,skills,0}','{"name":"Stale template","description":"Unsupported printable prose.","battle":{"enabled":false,"behavior":"auto"}}');
 entry:=jsonb_set(entry,'{0,card,skills,1}','{"name":"Heal 11","description":"Pulihkan 11 HP pada 1 ally. CD 3."}');
 PERFORM public.save_card_studio('studio-override-smoke',workspace,entry);
 PERFORM public.save_card_studio('studio-override-smoke',workspace,entry);
 IF (SELECT to_jsonb(s)-'updated_at' FROM special_skills s WHERE id=first_skill) IS DISTINCT FROM definition THEN RAISE EXCEPTION 'Custom master changed on Studio save'; END IF;
 IF NOT EXISTS(SELECT 1 FROM game_card_special_skills WHERE game_card_id=master AND special_skill_id=first_skill AND enabled) THEN RAISE EXCEPTION 'Unsupported print prose disabled valid custom skill'; END IF;
 IF NOT EXISTS(SELECT 1 FROM special_skills WHERE id=second_skill AND name='Heal 11' AND limits->>'cooldown_turns'='3' AND metadata->>'studio_customized' IS DISTINCT FROM 'true') THEN RAISE EXCEPTION 'Untouched template no longer recompiles'; END IF;
 IF (SELECT count(*) FROM game_card_special_skills WHERE game_card_id=master)<>2 THEN RAISE EXCEPTION 'Skill renamed code duplicated binding'; END IF;
 physical:=gen_random_uuid();
 INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled,metadata)
 SELECT physical,'OVERRIDE-QA-'||physical,name,card_code,element,hp,attack,defense,rarity,'normal',false,true,metadata||jsonb_build_object('catalog_source_id',master) FROM game_cards WHERE id=master;
 IF NOT EXISTS(SELECT 1 FROM special_skills s JOIN game_card_special_skills l ON l.special_skill_id=s.id WHERE l.game_card_id=physical AND l.sort_order=1 AND s.name='Custom Recovery' AND s.effects=definition->'effects' AND s.limits=definition->'limits' AND s.icon=definition->>'icon') THEN RAISE EXCEPTION 'New RFID copy lost custom rule'; END IF;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card)
 VALUES(b,'OVERRIDE-QA-'||b,'tcg_v1','battle','p1',1,50,'qa1','qa2',200,200,200,200,false,false,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1);
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element,origin_type,card_kind)
 VALUES(source_card,b,'p1',physical,'OVERRIDE-SOURCE-'||physical,'RFID source','active',1,143,143,143,30,14,'Knight','rfid','normal'),
 (ally,b,'p1',NULL,gen_random_uuid()::text,'Ally','active',2,100,100,20,20,10,'Water','rfid','normal');
 SELECT id INTO runtime FROM battle_card_skills WHERE battle_card_id=source_card AND name='Custom Recovery';
 IF runtime IS NULL THEN RAISE EXCEPTION 'RFID runtime did not snapshot custom rule'; END IF;
 result:=public.submit_battle_action('OVERRIDE-QA-'||b,'p1','qa1','special_skill',source_card,jsonb_build_object('skill_id',runtime,'target_card_id',ally,'action_id',gen_random_uuid()));
 IF NOT coalesce((result->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Custom runtime action rejected: %',result; END IF;
 IF (SELECT current_hp FROM battle_cards WHERE id=ally)<>39 THEN RAISE EXCEPTION 'Custom heal did not apply 19 HP'; END IF;
 IF (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>1 THEN RAISE EXCEPTION 'Custom AP2 not respected'; END IF;
 IF (SELECT cooldown_until_owner_turn FROM battle_card_skills WHERE id=runtime) IS NULL THEN RAISE EXCEPTION 'Custom cooldown not recorded'; END IF;
 -- Editing a source never rewrites an ongoing battle snapshot or its counters.
 UPDATE special_skills SET effects=jsonb_set(effects,'{0,amount,value}','23') WHERE id=first_skill;
 PERFORM public.save_card_studio('studio-override-smoke',workspace,entry);
 IF (SELECT effects#>>'{0,amount,value}' FROM battle_card_skills WHERE id=runtime)<>'19' THEN RAISE EXCEPTION 'Existing battle snapshot was rewritten'; END IF;
 IF has_function_privilege('authenticated','sync_studio_battle_skills(uuid,jsonb,jsonb)','execute') OR has_function_privilege('anon','tcg_studio_skill_is_custom(special_skills)','execute') THEN RAISE EXCEPTION 'Internal sync helpers exposed'; END IF;
END $smoke$;
ROLLBACK;
SELECT 'PASS rollback-only: real Studio save, custom rule preservation, automatic untouched slot, renamed-code identity, RFID inheritance, real heal/AP/CD action and immutable battle snapshot' result;
