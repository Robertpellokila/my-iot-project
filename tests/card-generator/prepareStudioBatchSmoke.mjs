// Prepare a rollback-only SQL smoke check from the audited source, without embedding
// a duplicate copy of the 42-card dataset in the repository. Execute via Supabase CLI.
import {writeFileSync,readFileSync} from 'node:fs';
import {PILOT} from '../../src/lib/card-generator/cardSchema.js';
import {editableStudioCard} from '../../src/lib/card-generator/cardCatalogBridge.js';
const target=process.argv[2];if(!target)throw new Error('Provide the output .sql path');
const candidate=process.argv[3]?readFileSync(process.argv[3],'utf8'):'';
const entries=JSON.stringify(PILOT.cards.map(card=>({key:card.card_code,card:editableStudioCard(card),artwork:{}})));
writeFileSync(target,`BEGIN;
${candidate}
DO $$ DECLARE account_id uuid; response jsonb; entry jsonb:=$entries$${entries}$entries$::jsonb; BEGIN
 SELECT id INTO account_id FROM public.profiles WHERE role='admin' LIMIT 1;
 IF account_id IS NULL THEN RAISE EXCEPTION 'Admin profile required'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 response:=public.save_card_studio('studio-batch-smoke',jsonb_build_object('dataset_id','studio-batch-smoke','artworks','{}'::jsonb),entry);
 IF jsonb_array_length(response->'entries')<>42 THEN RAISE EXCEPTION 'Batch must save 42 cards'; END IF;
 response:=public.save_card_studio('studio-batch-smoke',jsonb_build_object('dataset_id','studio-batch-smoke','artworks','{}'::jsonb),entry);
 IF (SELECT count(*) FROM public.card_studio_entries WHERE owner_id=account_id AND dataset_id='studio-batch-smoke')<>42 THEN RAISE EXCEPTION 'Repeated batch duplicated entries'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS 42-card save and repeat including existing Fusion codes; fixtures rolled back' result;
`);
