-- Execute inside BEGIN / ROLLBACK. Uses synthetic RFID copies only.
DO $qa$
DECLARE source_id uuid; target_id uuid; previous_id uuid; linked_id uuid;
 scan_uid text:='QA-TRANSFER-'||gen_random_uuid(); result jsonb; before_card jsonb; before_skills jsonb; after_skills jsonb; admin_id uuid;
BEGIN
 SELECT id INTO admin_id FROM profiles WHERE role='admin' LIMIT 1;
 IF admin_id IS NULL THEN RAISE EXCEPTION 'Admin fixture unavailable'; END IF;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 SELECT id INTO source_id FROM game_cards WHERE uid IS NULL AND archived_at IS NULL AND NOT fusion_only AND metadata ? 'studio_card' ORDER BY id LIMIT 1;
 SELECT id INTO target_id FROM game_cards WHERE uid IS NULL AND archived_at IS NULL AND NOT fusion_only AND metadata ? 'studio_card' AND id<>source_id ORDER BY id LIMIT 1;
 IF source_id IS NULL OR target_id IS NULL THEN RAISE EXCEPTION 'Need two saved Base cards';END IF;
 result:=link_studio_card_rfid(source_id,scan_uid); previous_id:=(result->>'id')::uuid;
 SELECT to_jsonb(c) INTO before_card FROM game_cards c WHERE id=previous_id;
 SELECT coalesce(jsonb_agg(to_jsonb(l) ORDER BY special_skill_id),'[]') INTO before_skills FROM game_card_special_skills l WHERE game_card_id=previous_id;
 result:=link_studio_card_rfid(target_id,lower(scan_uid));
 IF result#>>'{previous_card,id}'<>previous_id::text OR NOT (result->>'conflict')::boolean THEN RAISE EXCEPTION 'Conflict preview missing'; END IF;
 BEGIN PERFORM reassign_studio_card_rfid(target_id,scan_uid,source_id);RAISE EXCEPTION 'Stale preview accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 result:=reassign_studio_card_rfid(target_id,scan_uid,previous_id);linked_id:=(result->>'id')::uuid;
 IF NOT (result->>'transferred')::boolean OR linked_id=previous_id THEN RAISE EXCEPTION 'Transfer failed';END IF;
 IF (SELECT to_jsonb(c)-'updated_at' FROM game_cards c WHERE id=previous_id) IS DISTINCT FROM ((before_card-'updated_at')||'{"uid":null,"physical_scan_enabled":false}'::jsonb) THEN RAISE EXCEPTION 'Old card changed beyond UID and scanning';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(l) ORDER BY special_skill_id),'[]') INTO after_skills FROM game_card_special_skills l WHERE game_card_id=previous_id;
 IF before_skills IS DISTINCT FROM after_skills THEN RAISE EXCEPTION 'Old skill bindings changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM game_cards WHERE id=linked_id AND uid=scan_uid AND metadata->>'catalog_source_id'=target_id::text) THEN RAISE EXCEPTION 'Destination copy incorrect';END IF;
 IF (SELECT count(*) FROM game_cards WHERE upper(uid)=upper(scan_uid))<>1 THEN RAISE EXCEPTION 'UID is not unique';END IF;
 result:=reassign_studio_card_rfid(target_id,scan_uid,previous_id);
 IF NOT (result->>'already_linked')::boolean THEN RAISE EXCEPTION 'Retry not idempotent'; END IF;
 IF has_function_privilege('anon','reassign_studio_card_rfid(uuid,text,uuid)','execute') THEN RAISE EXCEPTION 'Anon transfer permission';END IF;
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 BEGIN PERFORM reassign_studio_card_rfid(source_id,scan_uid,linked_id);RAISE EXCEPTION 'Non-admin transfer accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $qa$;
