-- Synthetic history only. Caller must wrap migration + this file in BEGIN/ROLLBACK.
CREATE TEMP TABLE history_qa_results(checks integer);
DO $test$
DECLARE owner_id uuid:=gen_random_uuid();other_id uuid:=gen_random_uuid();normal_id uuid:=gen_random_uuid();
 ids uuid[]:='{}'; live_id uuid:=gen_random_uuid();other_battle uuid:=gen_random_uuid();g uuid:=gen_random_uuid();c uuid:=gen_random_uuid();
 marker text:='HISTORY-QA-'||gen_random_uuid();r jsonb;before_cards text;after_cards text;denied boolean;n integer;checks integer:=0;
BEGIN
 SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'')) INTO before_cards FROM game_cards t;
 INSERT INTO auth.users(id,email) VALUES(owner_id,owner_id||'@history.invalid'),(other_id,other_id||'@history.invalid'),(normal_id,normal_id||'@history.invalid');
 INSERT INTO profiles(id,role) VALUES(owner_id,'admin'),(other_id,'admin'),(normal_id,'user') ON CONFLICT(id) DO UPDATE SET role=excluded.role;
 FOR n IN 1..12 LOOP
  ids:=array_append(ids,gen_random_uuid());
  INSERT INTO battle_sessions(id,code,created_by,status,is_active,created_at,active_until,player1_name,player2_name)
   VALUES(ids[n],marker||'-'||lpad(n::text,2,'0'),owner_id,'waiting',false,now()-interval '40 days',now()-interval '1 day','QA Alya','QA Raka');
 END LOOP;
 INSERT INTO battle_sessions(id,code,created_by,status,is_active,active_until,teacher_paused) VALUES(live_id,marker||'-live',owner_id,'battle',true,now()+interval '1 day',true);
 INSERT INTO battle_sessions(id,code,created_by,status,is_active) VALUES(other_battle,marker||'-other',other_id,'finished',false);
 PERFORM set_config('request.jwt.claim.sub',owner_id::text,true);
 SET LOCAL ROLE authenticated;
 r:=admin_battle_history(marker,'all','all',1,10);
 IF (r->>'total')::int<>13 OR jsonb_array_length(r->'rows')<>10 OR (r#>>'{summary,active}')::int<>1 OR (r#>>'{summary,deletable}')::int<>12 THEN RAISE EXCEPTION 'Pagination/summary failed: %',r;END IF;checks:=checks+1;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'rows') b WHERE b ?| ARRAY['player1_token','player1_access_code','catalog_snapshot','skill_catalog_snapshot','created_by']) THEN RAISE EXCEPTION 'Private/large fields leaked';END IF;checks:=checks+1;
 r:=admin_battle_history(marker,'all','all',2,10);IF jsonb_array_length(r->'rows')<>3 THEN RAISE EXCEPTION 'Second page failed';END IF;checks:=checks+1;
 r:=admin_battle_history(marker,'all','all',999,10);IF (r->>'page')::int<>2 THEN RAISE EXCEPTION 'Out-of-range page not clamped';END IF;checks:=checks+1;
 r:=admin_battle_history(marker,'all','active',1,10);IF (r->>'total')::int<>1 OR (r#>>'{rows,0,can_delete}')::boolean THEN RAISE EXCEPTION 'Paused match not protected';END IF;checks:=checks+1;
 r:=admin_battle_history(marker,'waiting','inactive',1,25);IF (r->>'total')::int<>12 THEN RAISE EXCEPTION 'Combined filters failed';END IF;checks:=checks+1;
 r:=admin_battle_history('%','all','all',1,10);IF (r->>'total')::int<>0 THEN RAISE EXCEPTION 'Search must treat wildcard literally';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM admin_battle_history('', 'all','all',1,100000);EXCEPTION WHEN raise_exception THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Unbounded read allowed';END IF;checks:=checks+1;
 r:=admin_battle_history_cleanup(now()-interval '30 days');IF (r->>'total')::int<>12 OR jsonb_array_length(r->'rows')<>12 THEN RAISE EXCEPTION 'Cleanup preview failed';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM admin_delete_battle_history(ARRAY[ids[1],live_id]);EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Active match deleted';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM admin_delete_battle_history(ARRAY[ids[1],other_battle]);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Other owner deleted';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM battle_sessions WHERE id=ids[1]) THEN RAISE EXCEPTION 'Rejected mixed batch partially deleted';END IF;checks:=checks+1;
 UPDATE battle_sessions SET is_active=true,active_until=now()+interval '1 day' WHERE id=ids[2];
 SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM admin_delete_battle_history(ARRAY[ids[2]]);EXCEPTION WHEN object_not_in_prerequisite_state THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Stale preview deleted reactivated match';END IF;checks:=checks+1;
 RESET ROLE;
 -- A catalog card with a UID is referenced by a battle snapshot. Deleting the
 -- snapshot must never delete or clear that physical card.
 INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity) VALUES(g,marker,'History QA','QA53_'||upper(replace(g::text,'-','')),'Forest',100,30,10,'common');
 INSERT INTO battle_cards(id,battle_id,game_card_id,uid,player,name,zone,slot,hp,current_hp,attack,defense) VALUES(c,ids[1],g,marker,'p1','QA card','active',1,100,100,30,10);
 INSERT INTO battle_events(battle_id,type,payload) VALUES(ids[1],'history_qa','{}');
 INSERT INTO scan_events(battle_id,uid) VALUES(ids[1],marker);
 INSERT INTO battle_reader_bindings(battle_id,device_id,player) VALUES(ids[1],marker,'p1');
 SET LOCAL ROLE authenticated;
 r:=admin_delete_battle_history(ARRAY[ids[1],ids[1],ids[3]]);IF (r->>'deleted')::int<>2 THEN RAISE EXCEPTION 'Wrong deletion count/deduplication';END IF;checks:=checks+1;
 RESET ROLE;
 IF EXISTS(SELECT 1 FROM battle_sessions WHERE id=ids[1]) OR EXISTS(SELECT 1 FROM battle_cards WHERE battle_id=ids[1]) OR EXISTS(SELECT 1 FROM battle_events WHERE battle_id=ids[1]) OR EXISTS(SELECT 1 FROM scan_events WHERE battle_id=ids[1]) OR EXISTS(SELECT 1 FROM battle_reader_bindings WHERE battle_id=ids[1]) OR EXISTS(SELECT 1 FROM tbc_private.battle_player_access WHERE battle_id=ids[1]) THEN RAISE EXCEPTION 'Match children remain';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=g AND uid=marker) THEN RAISE EXCEPTION 'Catalog/UID lost';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',normal_id::text,true);
 SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM admin_battle_history();EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Non-admin read allowed';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM admin_battle_history_cleanup();EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Non-admin cleanup allowed';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM admin_delete_battle_history(ARRAY[live_id]);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Non-admin delete allowed';END IF;checks:=checks+1;
 RESET ROLE;
 IF has_function_privilege('anon','admin_battle_history(text,text,text,integer,integer)','EXECUTE') OR has_function_privilege('anon','admin_battle_history_cleanup(timestamptz)','EXECUTE') OR has_function_privilege('anon','admin_delete_battle_history(uuid[])','EXECUTE') THEN RAISE EXCEPTION 'Anonymous RPC privilege';END IF;checks:=checks+1;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'')) INTO after_cards FROM game_cards t WHERE id<>g;
 IF before_cards<>after_cards THEN RAISE EXCEPTION 'Existing catalog changed';END IF;checks:=checks+1;
 INSERT INTO history_qa_results VALUES(checks);
END $test$;
SELECT checks,'PASS: isolated pagination, filters, preview, owner/admin guards, stale confirmations, atomic deletion, cascades, catalog/UID preservation' AS result FROM history_qa_results;
