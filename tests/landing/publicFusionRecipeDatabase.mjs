import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE TABLE game_cards(id uuid PRIMARY KEY,name text,card_code text,featured_on_landing boolean DEFAULT false,landing_active boolean DEFAULT true,fusion_only boolean DEFAULT false,metadata jsonb DEFAULT '{}');
  CREATE TABLE fusion_recipes(id uuid PRIMARY KEY,name text,code text,result_game_card_id uuid,is_active boolean,priority integer);
  CREATE TABLE fusion_recipe_materials(id uuid PRIMARY KEY,recipe_id uuid,material_type text,quantity integer,card_code text,card_codes text[],element text,tag text,metadata jsonb,sort_order integer);
`);
await db.exec(readFileSync('supabase/migrations/035_public_fusion_recipe_projection.sql','utf8'));
const source = '00000000-0000-4000-8000-000000000001';
const publicClone = '00000000-0000-4000-8000-000000000002';
const hiddenClone = '00000000-0000-4000-8000-000000000003';
const recipe = '00000000-0000-4000-8000-000000000004';
const material = '00000000-0000-4000-8000-000000000005';
await db.query(`INSERT INTO game_cards(id,name,card_code,featured_on_landing,landing_active,fusion_only,metadata) VALUES
  ($1,'Circuit Grove Guardian','F01',false,true,true,'{}'),
  ($2,'Circuit Grove Guardian','F01_STUDIO_PRIVATE',true,true,true,$4),
  ($3,'Hidden Fusion','F02_STUDIO_PRIVATE',false,true,true,$5)`, [source,publicClone,hiddenClone,{studio_card:{display_code:'F01'}},{studio_card:{display_code:'F02'}}]);
await db.query(`INSERT INTO fusion_recipes(id,name,code,result_game_card_id,is_active,priority) VALUES($1,'Circuit Grove Guardian','timedoor_f01',$2,true,3)`,[recipe,source]);
await db.query(`INSERT INTO fusion_recipe_materials(id,recipe_id,material_type,quantity,card_code,card_codes,metadata,sort_order) VALUES($1,$2,'exact_card',2,'COB-006','{}','{}',1)`,[material,recipe]);
const output = (await db.query('SELECT get_landing_fusion_recipes() AS recipes')).rows[0].recipes;
assert.equal(output.length,1);
assert.equal(output[0].result_game_card_id,publicClone);
assert.equal(output[0].materials[0].card_code,'COB-006');
assert.equal(output[0].materials[0].quantity,2);
assert.equal((await db.query("SELECT has_function_privilege('anon','get_landing_fusion_recipes()','EXECUTE') allowed")).rows[0].allowed,true);
console.log('PASS public Fusion projection maps published Studio display codes and only returns its recipe materials');
await db.close();
