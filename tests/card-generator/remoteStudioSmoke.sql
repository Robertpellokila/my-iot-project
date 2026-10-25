-- Run against the linked project after migration 032. Every fixture rolls back.
BEGIN;
DO $$
DECLARE account_id uuid; response jsonb; first_id uuid; data jsonb; entry jsonb;
BEGIN
 SELECT id INTO account_id FROM public.profiles WHERE role='admin' LIMIT 1;
 IF account_id IS NULL THEN RAISE EXCEPTION 'Admin profile required for smoke check'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 data:=jsonb_build_object('dataset_id','studio-smoke-rollback','custom_cards','[]'::jsonb,'artworks','{}'::jsonb);
 entry:='[{"key":"DRAFT-SMOKE","card":{"card_code":"DRAFT-SMOKE","display_code":"TEST_STUDIO","name":"Rollback only","type":"Knight","rarity":"Common","kind":"base","stats":{"hp":120,"attack":30,"defense":14},"skills":[{"name":"First","description":"Smoke"},{"name":"Second","description":"Smoke"}],"tags":[]},"artwork":{}}]'::jsonb;
 response:=public.save_card_studio('studio-smoke-rollback',data,entry);
 first_id:=(response#>>'{entries,0,game_card_id}')::uuid;
 IF NOT EXISTS(SELECT 1 FROM public.game_cards WHERE id=first_id AND uid IS NULL AND NOT physical_scan_enabled AND hp=120) THEN RAISE EXCEPTION 'Reusable catalog projection failed'; END IF;
 response:=public.save_card_studio('studio-smoke-rollback',data,jsonb_set(entry,'{0,card,stats,hp}','143'::jsonb));
 IF (response#>>'{entries,0,game_card_id}')::uuid<>first_id OR NOT EXISTS(SELECT 1 FROM public.game_cards WHERE id=first_id AND hp=143) THEN RAISE EXCEPTION 'Idempotent update failed'; END IF;
 IF has_function_privilege('anon','public.save_card_studio(text,jsonb,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous write grant'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS real schema + admin save: reusable template, repeated save, stats update, anon denial; all smoke data rolled back' result;
