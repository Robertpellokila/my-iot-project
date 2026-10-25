-- Run after migration 040 inside a rollback-only transaction.
BEGIN;
DO $smoke$
DECLARE account_id uuid; result_id uuid:=gen_random_uuid(); catalog_a uuid:=gen_random_uuid(); catalog_b uuid:=gen_random_uuid(); kind text; recipe jsonb; requirements jsonb; saved jsonb; rid uuid; b uuid; a uuid; c uuid; r jsonb; runtime uuid;
BEGIN
 SELECT id INTO account_id FROM profiles WHERE role='admin' LIMIT 1;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 INSERT INTO game_cards(id,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled,tags)
 VALUES(result_id,'Fusion editor rollback','QA_FUSION_040','Forest',177,50,20,'legendary','fusion',true,false,'{}'),
 (catalog_a,'Material A','QA_FUSION_A_040','Knight',100,30,10,'common','normal',false,false,ARRAY['fusion:editor_qa']),
 (catalog_b,'Material B','QA_FUSION_B_040','Forest',120,40,12,'common','normal',false,false,ARRAY['Fusion:EDITOR_QA']);
 FOREACH kind IN ARRAY ARRAY['exact_card','tag','one_of'] LOOP
   rid:=gen_random_uuid();b:=gen_random_uuid();a:=gen_random_uuid();c:=gen_random_uuid();
   recipe:=jsonb_build_object('id',rid,'code','qa_fusion_040_'||kind,'name','QA Fusion '||kind,'is_active',true,'consumes_turn',false,'result_zone','active','material_destination','graveyard','limits','{"once_per_battle":true,"max_uses":1}'::jsonb,'result_stat_spec','{"hp":{"mode":"fixed","value":177},"attack":{"mode":"material_sum_percent","value":0.5},"defense":{"mode":"highest_material_percent","value":1}}'::jsonb);
   requirements:=CASE kind WHEN 'exact_card' THEN '[{"material_type":"exact_card","card_code":"QA_FUSION_A_040","quantity":1,"allowed_zones":["active"]},{"material_type":"exact_card","card_code":"QA_FUSION_B_040","quantity":1,"allowed_zones":["bench"]}]'::jsonb
     WHEN 'tag' THEN '[{"material_type":"tag","tag":"Fusion:EDITOR_QA","quantity":2,"allowed_zones":["active","bench"]}]'::jsonb
     ELSE '[{"material_type":"one_of","card_codes":["qa_fusion_a_040","QA_FUSION_B_040"],"quantity":2,"allowed_zones":["active","bench"]}]'::jsonb END;
   saved:=save_studio_fusion_recipe(result_id,recipe,requirements);
   IF (saved#>>'{recipe,min_materials}')::integer<>2 THEN RAISE EXCEPTION 'Material counts not synchronized'; END IF;
   INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,fusion_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card)
   VALUES(b,'QA-FUSION-040-'||b,'tcg_v1','battle','p1',1,50,'qa1','qa2',200,200,200,200,false,false,true,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1);
   INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,card_code,tags,zone,slot,hp,base_hp,current_hp,attack,defense,element,origin_type,card_kind)
   VALUES(a,b,'p1',catalog_a,gen_random_uuid()::text,'Material A','QA_FUSION_A_040',ARRAY['fusion:editor_qa'],'active',1,100,100,100,30,10,'Knight','rfid','normal'),
   (gen_random_uuid(),b,'p2',catalog_b,gen_random_uuid()::text,'Opponent decoy','QA_FUSION_B_040',ARRAY['fusion:editor_qa'],'active',1,120,120,120,40,12,'Forest','rfid','normal');
   r:=tcg_match_fusion_recipe(b,'p1',rid);
   IF coalesce((r->>'available')::boolean,false) THEN RAISE EXCEPTION '% reused one material or opponent card',kind; END IF;
   INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,card_code,tags,zone,hp,base_hp,current_hp,attack,defense,element,origin_type,card_kind)
   VALUES(c,b,'p1',catalog_b,gen_random_uuid()::text,'Material B','QA_FUSION_B_040',ARRAY['Fusion:EDITOR_QA'],'graveyard',120,120,120,40,12,'Forest','rfid','normal');
   IF (tcg_match_fusion_recipe(b,'p1',rid)->>'available')::boolean THEN RAISE EXCEPTION '% accepted wrong zone',kind; END IF;
   BEGIN
     UPDATE battle_cards SET zone='bench',fusion_consumed=true WHERE id=c;
     RAISE EXCEPTION '% allowed a consumed card back onto Bench',kind;
   EXCEPTION WHEN check_violation THEN NULL;END;
   UPDATE battle_cards SET zone='bench',fusion_consumed=false WHERE id=c;
   IF NOT (tcg_match_fusion_recipe(b,'p1',rid)->>'available')::boolean THEN RAISE EXCEPTION '% legal materials did not match',kind; END IF;
   r:=submit_battle_action('QA-FUSION-040-'||b,'p1','qa1','fusion',NULL,jsonb_build_object('recipe_id',rid,'action_id',gen_random_uuid()));
   IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION '% Fusion action rejected: %',kind,r; END IF;
   SELECT id INTO runtime FROM battle_cards WHERE battle_id=b AND game_card_id=result_id AND zone='active';
   IF runtime IS NULL OR NOT EXISTS(SELECT 1 FROM battle_cards WHERE id=runtime AND base_hp=177 AND attack=35 AND defense=12) THEN RAISE EXCEPTION '% result stats do not match saved recipe',kind; END IF;
   IF (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>1 THEN RAISE EXCEPTION '% must consume 2 AP',kind; END IF;
   IF (SELECT count(*) FROM battle_cards WHERE id IN (a,c) AND zone='graveyard' AND fusion_consumed)<>2 THEN RAISE EXCEPTION '% materials not consumed: %',kind,(SELECT jsonb_agg(jsonb_build_object('name',name,'zone',zone,'consumed',fusion_consumed,'reason',graveyard_reason,'hp',current_hp)) FROM battle_cards WHERE id IN (a,c)); END IF;
   r:=submit_battle_action('QA-FUSION-040-'||b,'p1','qa1','fusion',NULL,jsonb_build_object('recipe_id',rid,'action_id',gen_random_uuid()));
   IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>1 THEN RAISE EXCEPTION '% repeat changed AP',kind; END IF;
 END LOOP;
 IF has_function_privilege('anon','save_studio_fusion_recipe(uuid,jsonb,jsonb)','execute') THEN RAISE EXCEPTION 'Anonymous recipe write allowed'; END IF;
END $smoke$;
ROLLBACK;
SELECT 'PASS: saved EXACT/ONE TAG/ONE OF recipes, case normalization, quantities and distinct materials, owner/zone/consumed guards, real Fusion execution, computed HP/ATK/DEF, 2AP, consumption and repeat protection; all fixtures rolled back' result;
