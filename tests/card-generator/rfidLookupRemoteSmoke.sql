BEGIN;
DO $$
DECLARE admin_id uuid;g uuid:=gen_random_uuid();uid text:='QA56-'||g;r jsonb;before_card jsonb;after_card jsonb;denied boolean;
BEGIN
 SELECT id INTO admin_id FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1;
 IF admin_id IS NULL THEN RAISE EXCEPTION 'Admin fixture identity unavailable';END IF;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled)
 VALUES(g,uid,'QA56 read-only card','QA56_'||upper(replace(g::text,'-','')),'Forest',100,30,10,'common','normal',false,true);
 SELECT to_jsonb(c) INTO before_card FROM game_cards c WHERE id=g;
 r:=admin_lookup_card_rfid(' '||lower(uid)||' ');
 IF NOT (r->>'registered')::boolean OR jsonb_array_length(r->'cards')<>1 OR r#>>'{cards,0,id}'<>g::text THEN RAISE EXCEPTION 'Existing card not found';END IF;
 r:=admin_lookup_card_rfid('NEW-'||g);
 IF (r->>'registered')::boolean OR jsonb_array_length(r->'cards')<>0 THEN RAISE EXCEPTION 'New UID misclassified';END IF;
 INSERT INTO rfid_cards(uid,label,card_type,is_active) VALUES('REG-'||g,'QA56 registry','rfid_card',true);
 r:=admin_lookup_card_rfid('REG-'||g);
 IF NOT (r->>'registered')::boolean OR jsonb_array_length(r->'cards')<>0 OR r#>>'{registration,label}'<>'QA56 registry' OR (r->'registration')?'owner_id' THEN RAISE EXCEPTION 'Registry-only lookup failed';END IF;
 SELECT to_jsonb(c) INTO after_card FROM game_cards c WHERE id=g;
 IF before_card IS DISTINCT FROM after_card THEN RAISE EXCEPTION 'Lookup changed card';END IF;
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM admin_lookup_card_rfid(uid);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Non-admin lookup allowed';END IF;
 RESET ROLE;
 IF has_function_privilege('anon','public.admin_lookup_card_rfid(text)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous lookup allowed';END IF;
END $$;
SELECT 'PASS admin-only read-only RFID lookup: existing, new, registry-only, unchanged data' AS checks;
ROLLBACK;
