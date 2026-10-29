-- No collection data is changed: every fixture and admin edit rolls back.
BEGIN;
DO $smoke$
DECLARE teacher uuid;b uuid:=gen_random_uuid();master uuid:=gen_random_uuid();uid_card uuid;other uuid:=gen_random_uuid();result_id uuid:=gen_random_uuid();rid uuid:=gen_random_uuid();a uuid:=gen_random_uuid();c uuid:=gen_random_uuid();qcode text:='QA49-'||gen_random_uuid();device text:='QA49-'||gen_random_uuid();uid text:='QA49-'||gen_random_uuid();token1 text:=gen_random_uuid();token2 text:=gen_random_uuid();r jsonb;row game_cards;initial_version integer;before_ap integer;before_count integer;blocked boolean;data jsonb;entry jsonb;workspace jsonb;
BEGIN
 SELECT id INTO teacher FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1;
 IF teacher IS NULL THEN RAISE EXCEPTION 'Admin fixture unavailable';END IF;
 PERFORM set_config('request.jwt.claim.sub',teacher::text,true);
 PERFORM set_config('tcg.intra_turn_action','off',true);
 INSERT INTO game_cards(id,name,card_code,element,hp,attack,defense,rarity,physical_scan_enabled,featured_on_landing,landing_active)
 VALUES(master,'QA49 Master',upper(replace(master::text,'-','')),'Forest',100,30,10,'common',false,true,true),
 (other,'QA49 Other',upper(replace(other::text,'-','')),'Knight',120,32,12,'common',false,false,true);
 SET LOCAL ROLE authenticated;UPDATE game_cards SET landing_display_order=7 WHERE id=master;GET DIAGNOSTICS before_count=ROW_COUNT;IF before_count<>1 THEN RAISE EXCEPTION 'Authenticated admin cannot update publication';END IF;RESET ROLE;
 IF NOT tcg_card_battle_available(master) THEN RAISE EXCEPTION 'Existing default changed';END IF;
 r:=link_studio_card_rfid(master,uid);uid_card:=(r->>'id')::uuid;
 IF NOT tcg_card_battle_available(uid_card) OR NOT EXISTS(SELECT 1 FROM game_cards WHERE id=uid_card AND battle_enabled AND physical_scan_enabled) THEN RAISE EXCEPTION 'RFID copy not enabled';END IF;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,fusion_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,max_active,max_bench,turn_duration_seconds,turn_started_at,turn_deadline_at,is_active,active_until)
 VALUES(b,qcode,'tcg_v1','battle','p1',1,100,token1,token2,200,200,200,200,false,false,true,true,5,5,0,20,20,1,4,4,60,now(),now()+interval '1 minute',true,now()+interval '1 hour');
 INSERT INTO battle_reader_bindings(device_id,battle_id,player,active) VALUES(device,b,'p1',true);
 r:=submit_battle_action(qcode,'p1',token1,'summon',NULL,'{}');IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Summon reservation failed: %',r;END IF;
 SELECT player1_action_points INTO before_ap FROM battle_sessions WHERE id=b;
 r:=manage_game_card(master,'disable',1);
 IF (r#>>'{card,battle_enabled}')::boolean OR NOT (r#>>'{card,featured_on_landing}')::boolean OR tcg_card_battle_available(uid_card) THEN RAISE EXCEPTION 'Battle/public/source separation failed';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(get_landing_cards()) v WHERE v->>'id'=master::text) THEN RAISE EXCEPTION 'Disabling battle hid published card';END IF;
 r:=process_multiplayer_rfid_scan(uid,device);
 IF r->>'code' IS DISTINCT FROM 'CARD_BATTLE_DISABLED' OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>before_ap OR EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=b) THEN RAISE EXCEPTION 'Disabled source scan mutated battle';END IF;
 blocked:=false;BEGIN PERFORM manage_game_card(uid_card,'enable',1);EXCEPTION WHEN OTHERS THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Copy bypassed disabled source';END IF;
 blocked:=false;BEGIN
  INSERT INTO battle_cards(battle_id,player,game_card_id,uid,name,element,attack,defense,hp,base_hp,current_hp,zone,slot) VALUES(b,'p1',uid_card,uid,'QA49 snapshot','Forest',30,10,100,100,100,'active',1);
 EXCEPTION WHEN OTHERS THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Direct snapshot bypassed disabled source';END IF;
 blocked:=false;BEGIN PERFORM manage_game_card(master,'enable',1);EXCEPTION WHEN serialization_failure THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Stale toggle accepted';END IF;
 r:=manage_game_card(master,'enable',2);r:=process_multiplayer_rfid_scan(uid,device);
 IF NOT coalesce((r->>'ok')::boolean,false) OR NOT EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=b AND game_card_id=uid_card AND zone='active') THEN RAISE EXCEPTION 'Actual scan after enabling failed: %',r;END IF;
 SELECT count(*) INTO before_count FROM battle_cards WHERE battle_id=b;
 r:=manage_game_card(master,'archive',3);
 IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=master AND archived_at IS NOT NULL AND NOT battle_enabled AND NOT featured_on_landing AND NOT landing_active) OR tcg_card_battle_available(uid_card) THEN RAISE EXCEPTION 'Archive did not hide/disable';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(get_landing_cards()) v WHERE v->>'id'=master::text) THEN RAISE EXCEPTION 'Archived card public';END IF;
 IF (SELECT count(*) FROM battle_cards WHERE battle_id=b)<>before_count OR NOT EXISTS(SELECT 1 FROM game_cards WHERE id=uid_card AND game_cards.uid IS NOT NULL) THEN RAISE EXCEPTION 'Archive removed existing data';END IF;
 -- Existing snapshots can switch zones and keep HP/stats, even while their source is archived.
 UPDATE battle_cards SET zone='bench',slot=NULL WHERE battle_id=b AND game_card_id=uid_card;
 IF NOT EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=b AND game_card_id=uid_card AND current_hp=100 AND zone='bench') THEN RAISE EXCEPTION 'Existing snapshot changed';END IF;
 blocked:=false;BEGIN PERFORM link_studio_card_rfid(master,uid||'-new');EXCEPTION WHEN OTHERS THEN blocked:=true;END;IF NOT blocked THEN RAISE EXCEPTION 'Archived source copied';END IF;
 SELECT availability_version INTO initial_version FROM game_cards WHERE id=master;
 r:=manage_game_card(master,'archive',3);IF NOT (r->>'already_applied')::boolean OR (r#>>'{card,availability_version}')::integer<>initial_version THEN RAISE EXCEPTION 'Retry archive not idempotent';END IF;
 r:=manage_game_card(master,'restore',initial_version);
 IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=master AND archived_at IS NULL AND NOT battle_enabled AND NOT featured_on_landing AND NOT landing_active) OR tcg_card_battle_available(uid_card) THEN RAISE EXCEPTION 'Restore unexpectedly reactivated';END IF;
 SELECT availability_version INTO initial_version FROM game_cards WHERE id=master;r:=manage_game_card(master,'enable',initial_version);
 -- Fresh copies inherit an explicitly disabled source's status without losing their UID.
 SELECT availability_version INTO initial_version FROM game_cards WHERE id=master;r:=manage_game_card(master,'disable',initial_version);
 r:=link_studio_card_rfid(master,uid||'-disabled');IF (SELECT battle_enabled FROM game_cards WHERE id=(r->>'id')::uuid) THEN RAISE EXCEPTION 'New RFID copy ignored source status';END IF;
 -- Actual Fusion availability and manual recipe execution, using snapshot materials.
 INSERT INTO game_cards(id,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled) VALUES(result_id,'QA49 Fusion',upper(replace(result_id::text,'-','')),'Forest',177,50,20,'legendary','fusion',true,false);
 r:=save_studio_fusion_recipe(result_id,jsonb_build_object('id',rid,'code','qa49_'||replace(rid::text,'-',''),'name','QA49 recipe','is_active',true,'limits','{"once_per_battle":false}'::jsonb,'result_stat_spec','{"hp":{"mode":"fixed","value":177},"attack":{"mode":"fixed","value":50},"defense":{"mode":"fixed","value":20}}'::jsonb),jsonb_build_array(jsonb_build_object('material_type','exact_card','card_code',(SELECT card_code FROM game_cards WHERE id=other),'quantity',2,'allowed_zones','["active","bench"]'::jsonb)));
 INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,card_code,zone,slot,hp,base_hp,current_hp,attack,defense,element)
 VALUES(a,b,'p1',other,gen_random_uuid()::text,'Material A',(SELECT card_code FROM game_cards WHERE id=other),'active',1,120,120,120,32,12,'Knight'),
 (c,b,'p1',other,gen_random_uuid()::text,'Material B',(SELECT card_code FROM game_cards WHERE id=other),'bench',NULL,120,120,120,32,12,'Knight');
 IF NOT coalesce((tcg_match_fusion_recipe(b,'p1',rid)->>'available')::boolean,false) THEN RAISE EXCEPTION 'Enabled Fusion did not match';END IF;
 r:=manage_game_card(result_id,'disable',1);
 IF coalesce((tcg_match_fusion_recipe(b,'p1',rid)->>'available')::boolean,false) THEN RAISE EXCEPTION 'Disabled Fusion still matches';END IF;
 data:=get_player_fusions(qcode,'p1',token1);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(data->'recipes') v WHERE v->>'recipe_id'=rid::text) THEN RAISE EXCEPTION 'Disabled Fusion still offered';END IF;
 SELECT player1_action_points INTO before_ap FROM battle_sessions WHERE id=b;
 r:=submit_battle_action(qcode,'p1',token1,'fusion',NULL,jsonb_build_object('recipe_id',rid,'action_id',gen_random_uuid()));
 IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>before_ap OR NOT EXISTS(SELECT 1 FROM battle_cards WHERE id=a AND zone='active') THEN RAISE EXCEPTION 'Manual recipe bypassed disabled result or spent resources';END IF;
 r:=manage_game_card(result_id,'enable',2);
 r:=submit_battle_action(qcode,'p1',token1,'fusion',NULL,jsonb_build_object('recipe_id',rid,'action_id',gen_random_uuid()));
 IF NOT coalesce((r->>'ok')::boolean,false) OR NOT EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=b AND game_card_id=result_id AND zone='active') THEN RAISE EXCEPTION 'Actual Fusion after enabling failed: %',r;END IF;
 -- Archived Studio rows cannot be resurrected by an old workspace save.
 workspace:=jsonb_build_object('dataset_id','qa49-'||b,'custom_cards','[]'::jsonb,'artworks','{}'::jsonb,'back','{}'::jsonb);
 entry:=jsonb_build_array(jsonb_build_object('key','QA49-STUDIO','card',jsonb_build_object('card_code','QA49-STUDIO','display_code','QA49-STUDIO','name','QA49 Studio','type','Knight','rarity','Common','kind','base','stats','{"hp":120,"attack":30,"defense":14}'::jsonb,'skills','[{"name":"First","description":"Smoke"},{"name":"Second","description":"Smoke"}]'::jsonb,'tags','[]'::jsonb),'artwork','{}'::jsonb));
 r:=save_card_studio('qa49-'||b,workspace,entry);SELECT * INTO row FROM game_cards WHERE id=(r#>>'{entries,0,game_card_id}')::uuid;
 r:=manage_game_card(row.id,'archive',row.availability_version);blocked:=false;BEGIN PERFORM save_card_studio('qa49-'||b,workspace,entry);EXCEPTION WHEN OTHERS THEN blocked:=true;END;IF NOT blocked THEN RAISE EXCEPTION 'Studio resurrected archived card';END IF;
 -- Role checks cover the RPC and direct table writes, not just hidden buttons.
 PERFORM set_config('request.jwt.claim.sub','',true);SET LOCAL ROLE anon;IF EXISTS(SELECT 1 FROM game_cards WHERE id=row.id) THEN RAISE EXCEPTION 'Anonymous caller read archived card';END IF;blocked:=false;BEGIN PERFORM manage_game_card(master,'enable',1);EXCEPTION WHEN insufficient_privilege THEN blocked:=true;END;IF NOT blocked THEN RAISE EXCEPTION 'Anonymous management allowed';END IF;RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;BEGIN PERFORM manage_game_card(master,'enable',1);EXCEPTION WHEN insufficient_privilege THEN blocked:=true;END;IF NOT blocked THEN RAISE EXCEPTION 'Non-admin management allowed';END IF;
 UPDATE game_cards SET battle_enabled=true WHERE id=master;GET DIAGNOSTICS before_count=ROW_COUNT;IF before_count<>0 THEN RAISE EXCEPTION 'Non-admin bypassed RPC with table update';END IF;
 blocked:=false;BEGIN INSERT INTO game_cards(name,card_code,element) VALUES('Unauthorized','QA49-UNAUTHORIZED','Forest');EXCEPTION WHEN insufficient_privilege THEN blocked:=true;END;IF NOT blocked THEN RAISE EXCEPTION 'Non-admin table insert allowed';END IF;RESET ROLE;
END $smoke$;
SELECT 'PASS independent battle/public status, source/RFID gates, real scanner and Fusion, untouched snapshots, archive/restore, stale/idempotent writes, Studio save guard and anon/non-admin RLS' AS checks;
ROLLBACK;
