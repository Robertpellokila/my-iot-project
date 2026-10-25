-- Real-schema test of the one-step RFID flow. All fixtures roll back.
BEGIN;
DO $smoke$
DECLARE account_id uuid; template game_cards; master uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid(); first_skill uuid; linked uuid; result jsonb; retried jsonb;
 b uuid:=gen_random_uuid(); runtime_card uuid:=gen_random_uuid(); runtime_skill uuid;
 legacy_skill uuid; legacy_copy uuid; legacy_entry jsonb;
BEGIN
 SELECT id INTO account_id FROM profiles WHERE role='admin' LIMIT 1;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 SELECT * INTO STRICT template FROM game_cards WHERE metadata ? 'studio_card' AND NOT fusion_only AND uid IS NULL ORDER BY id LIMIT 1;
 INSERT INTO game_cards(id,name,card_code,element,hp,attack,defense,rarity,level,card_kind,fusion_only,physical_scan_enabled,metadata,image_url,avatar_url,featured_on_landing)
 VALUES(master,'RFID Link QA','RFID_LINK_QA',template.element,template.hp,template.attack,template.defense,template.rarity,2,'normal',false,false,template.metadata-'timedoor_seed_key',template.image_url,template.avatar_url,true);
 SELECT s.id INTO first_skill FROM special_skills s JOIN game_card_special_skills l ON l.special_skill_id=s.id WHERE l.game_card_id=master AND l.sort_order=1;
 UPDATE special_skills SET name='RFID Custom Recovery',description='Pulihkan 19 HP pada 1 ally. Biaya 2 AP. CD 4.',target_spec='{"type":"ally_active","required":true}',cost_spec='{"type":"none"}',limits='{"action_points":2,"cooldown_turns":4}',effects='[{"type":"heal_card","target":"target_card","owner":"self","allowed_zones":["active"],"amount":{"mode":"fixed","value":19}}]',consumes_turn=false WHERE id=first_skill;
 result:=link_studio_card_rfid(master,'QA-RFID-38-'||master);linked:=(result->>'id')::uuid;
 retried:=link_studio_card_rfid(master,'QA-RFID-38-'||master);
 IF linked<>(retried->>'id')::uuid OR NOT (retried->>'already_linked')::boolean THEN RAISE EXCEPTION 'UID retry created another instance'; END IF;
 IF NOT EXISTS(SELECT 1 FROM game_cards g WHERE g.id=linked AND g.physical_scan_enabled AND NOT g.featured_on_landing AND g.metadata->>'catalog_source_id'=master::text AND g.hp=template.hp AND g.attack=template.attack AND g.defense=template.defense AND g.image_url IS NOT DISTINCT FROM template.image_url AND g.avatar_url IS NOT DISTINCT FROM template.avatar_url) THEN RAISE EXCEPTION 'Copy changed source data or public settings'; END IF;
 IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=master AND uid IS NULL AND NOT physical_scan_enabled AND featured_on_landing) THEN RAISE EXCEPTION 'Reusable design was modified'; END IF;
 INSERT INTO game_cards(id,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled) VALUES(other_id,'Other QA','OTHER_LINK_QA','Knight',100,20,10,'common','normal',false,false);
 BEGIN PERFORM link_studio_card_rfid(other_id,'QA-RFID-38-'||master);RAISE EXCEPTION 'Collision accepted';EXCEPTION WHEN unique_violation THEN NULL;END;
 PERFORM link_studio_card_rfid(master,'QA-RFID-38-SECOND-'||master);
 IF (SELECT count(*) FROM game_cards WHERE metadata->>'catalog_source_id'=master::text)<>2 THEN RAISE EXCEPTION 'Expected two physical copies for one design'; END IF;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card)
 VALUES(b,'QA-RFID-38-'||b,'tcg_v1','battle','p1',1,50,'qa1','qa2',200,200,200,200,false,false,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1);
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element,origin_type,card_kind)
 VALUES(runtime_card,b,'p1',linked,'QA-RFID-38-'||master,'RFID Card','active',1,template.hp,template.hp,20,template.attack,template.defense,template.element,'rfid','normal');
 SELECT id INTO runtime_skill FROM battle_card_skills WHERE battle_card_id=runtime_card AND name='RFID Custom Recovery';
 IF runtime_skill IS NULL OR (SELECT count(*) FROM battle_card_skills WHERE battle_card_id=runtime_card)<>2 THEN RAISE EXCEPTION 'RFID skill snapshots missing'; END IF;
 result:=submit_battle_action('QA-RFID-38-'||b,'p1','qa1','special_skill',runtime_card,jsonb_build_object('skill_id',runtime_skill,'target_card_id',runtime_card,'action_id',gen_random_uuid()));
 IF NOT coalesce((result->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Copied skill rejected: %',result; END IF;
 IF (SELECT current_hp FROM battle_cards WHERE id=runtime_card)<>39 OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>1 OR (SELECT cooldown_until_owner_turn FROM battle_card_skills WHERE id=runtime_skill) IS NULL THEN RAISE EXCEPTION 'Copied rule heal/AP/cooldown mismatch'; END IF;
 IF has_function_privilege('anon','link_studio_card_rfid(uuid,text)','execute') THEN RAISE EXCEPTION 'Anonymous RFID write grant'; END IF;
 -- Run this compatibility block after migration 039 is present.
 IF to_regprocedure('public.tcg_prepare_registered_studio_import()') IS NOT NULL THEN
   INSERT INTO special_skills(code,name,description,icon,category,skill_type,activation_timing,source_zones,trigger_spec,target_spec,cost_spec,limits,effects,consumes_turn,priority,is_active,catalog_status,metadata)
   SELECT 'legacy_qa_'||replace(other_id::text,'-',''),name,description,icon,category,skill_type,activation_timing,source_zones,trigger_spec,target_spec,cost_spec,limits,effects,consumes_turn,priority,is_active,catalog_status,'{}'::jsonb FROM special_skills WHERE id=first_skill RETURNING id INTO legacy_skill;
   INSERT INTO game_card_special_skills(game_card_id,special_skill_id,sort_order,enabled,overrides) VALUES(other_id,legacy_skill,1,true,'{"action_points":1}');
   legacy_entry:=jsonb_build_array(jsonb_build_object('key','DRAFT-LEGACY-RFID-QA','card',jsonb_build_object('card_code','DRAFT-LEGACY-RFID-QA','source_game_card_id',other_id,'display_code','LEGACY_QA','name','Other QA','type','Knight','rarity','Common','kind','base','stats','{"hp":100,"attack":20,"defense":10}'::jsonb,'skills',template.metadata#>'{studio_card,skills}'),'artwork','{}'::jsonb));
   PERFORM save_card_studio('legacy-rfid-rollback','{"dataset_id":"legacy-rfid-rollback","custom_cards":[],"artworks":{}}',legacy_entry);
   PERFORM sync_card_studio_battle_skills('legacy-rfid-rollback');
   IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=other_id AND metadata->>'studio_legacy_bindings'='true') OR (SELECT count(*) FROM game_card_special_skills WHERE game_card_id=other_id)<>1 THEN RAISE EXCEPTION 'Legacy Studio import duplicated skill bindings'; END IF;
   result:=link_studio_card_rfid(other_id,'QA-RFID-38-LEGACY-'||other_id);legacy_copy:=(result->>'id')::uuid;
   IF (SELECT count(*) FROM game_card_special_skills WHERE game_card_id=legacy_copy)<>1 OR NOT EXISTS(SELECT 1 FROM game_card_special_skills WHERE game_card_id=legacy_copy AND special_skill_id=legacy_skill AND overrides='{"action_points":1}') THEN RAISE EXCEPTION 'Legacy physical copy lost original bindings/overrides'; END IF;
 END IF;
END $smoke$;
ROLLBACK;
SELECT 'PASS RFID panel backend: unchanged design, exact stats/images/custom skills, idempotent retry, UID conflict rejection, multiple copies, hidden publication default, real battle heal/AP/cooldown and anon isolation' result;
