import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db=new PGlite();
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
 CREATE TABLE game_cards(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),metadata jsonb NOT NULL DEFAULT '{}');
 CREATE TABLE special_skills(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text UNIQUE NOT NULL,name text,description text,icon text,category text,skill_type text,activation_timing text,source_zones text[],target_spec jsonb,cost_spec jsonb,limits jsonb,effects jsonb,consumes_turn boolean,priority integer,is_active boolean,catalog_status text,metadata jsonb DEFAULT '{}',trigger_spec jsonb DEFAULT '{"type":"main_phase"}',skill_version integer DEFAULT 1,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now());
 CREATE TABLE game_card_special_skills(game_card_id uuid REFERENCES game_cards,special_skill_id uuid REFERENCES special_skills,sort_order integer,enabled boolean,overrides jsonb,UNIQUE(game_card_id,special_skill_id));`);
 const lifecycle=await readFile('supabase/migrations/012_skill_catalog_workflow.sql','utf8');
 await db.exec(lifecycle.slice(lifecycle.indexOf('CREATE OR REPLACE FUNCTION public.tcg_prepare_special_skill_catalog_write()'),lifecycle.indexOf('CREATE OR REPLACE FUNCTION public.tcg_record_special_skill_revision()')));
 await db.exec('CREATE TRIGGER tcg_prepare_special_skill_catalog_write_trigger BEFORE INSERT OR UPDATE ON special_skills FOR EACH ROW EXECUTE FUNCTION tcg_prepare_special_skill_catalog_write()');
 const original=await readFile('supabase/migrations/036_studio_executable_card_skills.sql','utf8');
 await db.exec(original.split('-- BEGIN GENERATED STUDIO REGISTRY (build-studio-skill-migration.mjs)')[1].split('-- END GENERATED STUDIO REGISTRY')[0]);
 await db.exec(original.slice(original.indexOf('CREATE OR REPLACE FUNCTION public.sync_studio_battle_skills('),original.indexOf('CREATE OR REPLACE FUNCTION public.sync_card_studio_battle_skills(')));
 const source='10000000-0000-4000-8000-000000000001',copy='10000000-0000-4000-8000-000000000002';
 const metadata={studio_card:{skills:[{name:'Guard',description:'Beri Shield 8 pada 1 ally. CD 2.'},{name:'Heal',description:'Pulihkan 7 HP pada 1 ally. CD 2.'}]},studio_artwork:{skill_icons:[{url:'https://example.test/guard.webp'},null]}};
 await db.query('INSERT INTO game_cards(id,metadata) VALUES($1,$2)',[source,metadata]);
 const skills=async id=>(await db.query('SELECT s.*,l.enabled FROM special_skills s JOIN game_card_special_skills l ON l.special_skill_id=s.id WHERE l.game_card_id=$1 ORDER BY l.sort_order',[id])).rows;
 const sync=async id=>db.query("SELECT sync_studio_battle_skills(id,metadata#>'{studio_card,skills}',metadata->'studio_artwork') FROM game_cards WHERE id=$1",[id]);
 let [one,two]=await skills(source);assert.ok(one.is_active && two.is_active);
 // A real custom rule saved before migration 037 must be retained as well.
 const customEffects=[{type:'heal_card',target:'target_card',owner:'self',allowed_zones:['active'],amount:{mode:'fixed',value:19}}];
 await db.query("UPDATE special_skills SET name='Custom Guard',description='Pulihkan 19 HP pada 1 ally.',icon='https://example.test/custom.webp',effects=$2,limits='{\"action_points\":2,\"cooldown_turns\":4}',target_spec='{\"type\":\"ally_active\",\"required\":true,\"max_targets\":1}' WHERE id=$1",[one.id,customEffects]);
 const migration=await readFile('supabase/migrations/037_preserve_studio_skill_overrides.sql','utf8');await db.exec(migration);
 [one,two]=await skills(source);assert.equal(one.metadata.studio_customized,true);assert.notEqual(two.metadata.studio_customized,true);
 const snapshot=structuredClone(one);
 metadata.studio_card.skills[0]={name:'Stale template',description:'Serangan normal dan efek tidak didukung.',battle:{enabled:false,behavior:'auto'}};
 metadata.studio_artwork.skill_icons[0]={url:'https://example.test/stale.webp'};
 metadata.studio_card.skills[1]={name:'Healing 11',description:'Pulihkan 11 HP pada 1 ally. CD 3.'};
 await db.query('UPDATE game_cards SET metadata=$2 WHERE id=$1',[source,metadata]);
 [one,two]=await skills(source);
 for(const key of ['id','name','description','icon','effects','limits','target_spec','catalog_status','skill_version']) assert.deepEqual(one[key],snapshot[key],`custom ${key} survived save`);
 assert.equal(one.enabled,true,'unsupported print text cannot disable valid custom effects');
 assert.equal(two.name,'Healing 11');assert.equal(two.metadata.studio_customized,undefined);assert.equal(two.limits.cooldown_turns,3);
 await sync(source);await sync(source);assert.equal((await skills(source))[1].metadata.studio_customized,undefined);
 assert.equal((await skills(source)).length,2);
 // Catalog edit/rename locks the slot, independent of its internal code.
 await db.query("UPDATE special_skills SET code='renamed_heal',effects=$2,limits='{\"action_points\":1,\"cooldown_turns\":5}',metadata=metadata||'{\"studio_customized\":true}' WHERE id=$1",[two.id,customEffects]);
 await sync(source);assert.equal((await skills(source))[1].code,'renamed_heal');assert.equal((await skills(source)).length,2);
 // No-marker clients are detected at the database boundary too.
 await db.query("UPDATE special_skills SET description='Pulihkan 19 HP.',icon='https://example.test/new.webp' WHERE id=$1",[two.id]);
 await sync(source);assert.equal((await skills(source))[1].description,'Pulihkan 19 HP.');
 // Explicit source inheritance for a new RFID instance, even with stale print text.
 await db.query('INSERT INTO game_cards(id,metadata) VALUES($1,$2)',[copy,{...metadata,catalog_source_id:source}]);
 const clones=await skills(copy);assert.equal(clones.length,2);
 for(let i=0;i<2;i++){
  const master=(await skills(source))[i];assert.notEqual(clones[i].id,master.id);
  for(const key of ['name','description','icon','effects','limits','target_spec','cost_spec']) assert.deepEqual(clones[i][key],master[key],`copy ${key}`);
  assert.equal(clones[i].metadata.studio_source_skill_id,master.id);
 }
 await sync(copy);assert.equal((await skills(copy)).length,2);
 // Explicit registration choices are distinct from compiler readiness.
 const copyMeta={...metadata,catalog_source_id:source};
 copyMeta.studio_card=structuredClone(metadata.studio_card);
 copyMeta.studio_card.skills[0].battle={enabled:false,selection_enabled:false};
 await db.query('UPDATE game_cards SET metadata=$2 WHERE id=$1',[copy,copyMeta]);
 assert.equal((await skills(copy))[0].enabled,false);assert.equal((await skills(copy))[0].is_active,true);
 copyMeta.studio_card.skills[0].battle.selection_enabled=true;
 await db.query('UPDATE game_cards SET metadata=$2 WHERE id=$1',[copy,copyMeta]);
 assert.equal((await skills(copy))[0].enabled,true);
 // Disabled/draft rules cannot be resurrected by an old Studio payload.
 await db.query("UPDATE special_skills SET catalog_status='draft' WHERE id=$1",[one.id]);
 await sync(source);assert.equal((await skills(source))[0].enabled,false);assert.equal((await skills(source))[0].is_active,false);
 const disabledCopy='10000000-0000-4000-8000-000000000003';
 await db.query('INSERT INTO game_cards(id,metadata) VALUES($1,$2)',[disabledCopy,{...metadata,catalog_source_id:source}]);
 assert.equal((await skills(disabledCopy))[0].is_active,false);
 // Source edits do not rewrite already instantiated copies.
 assert.equal((await skills(copy))[0].is_active,true);
 await db.query("UPDATE special_skills SET name='Safe manual name' WHERE id=$1",[clones[1].id]);
 assert.equal((await skills(copy))[1].metadata.studio_customized,true);
 await assert.rejects(db.query("UPDATE special_skills SET effects='[]',catalog_status='active' WHERE id=$1",[two.id]),/Efek skill/);
 const before=await skills(source);
 await assert.rejects(db.query("UPDATE game_cards SET metadata=jsonb_set(metadata,'{studio_card,skills}','[]') WHERE id=$1",[source]),/dua slot/);
 assert.deepEqual(await skills(source),before);
 await db.exec(migration);assert.equal((await skills(source)).length,2);
 // Anonymous/authenticated clients cannot invoke privileged sync helpers.
 const allowed=(await db.query("SELECT has_function_privilege('authenticated','sync_studio_battle_skills(uuid,jsonb,jsonb)','execute') value")).rows[0].value;
 assert.equal(allowed,false);
 await db.exec('GRANT USAGE ON SCHEMA public TO authenticated; GRANT SELECT,UPDATE ON special_skills TO authenticated; SET ROLE authenticated');
 await db.query("UPDATE special_skills SET name='Authenticated edit' WHERE id=$1",[two.id]);
 await db.exec('RESET ROLE');await sync(source);assert.equal((await skills(source))[1].name,'Authenticated edit');
 // Importing a previously registered non-Studio card keeps its original rules.
 await db.exec(`CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT '00000000-0000-4000-8000-000000000001'::uuid $$;CREATE FUNCTION is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
 CREATE TABLE card_studio_entries(owner_id uuid,dataset_id text,card_key text,game_card_id uuid);
 ALTER TABLE game_cards ADD COLUMN uid text UNIQUE,ADD COLUMN card_code text,ADD COLUMN name text,ADD COLUMN element text,ADD COLUMN hp int,ADD COLUMN attack int,ADD COLUMN defense int,ADD COLUMN rarity text,ADD COLUMN level int,ADD COLUMN lore text,ADD COLUMN image_url text,ADD COLUMN physical_card_image_url text,ADD COLUMN avatar_url text,ADD COLUMN card_kind text,ADD COLUMN fusion_only boolean DEFAULT false,ADD COLUMN physical_scan_enabled boolean DEFAULT false,ADD COLUMN tags text[];`);
 await db.exec(await readFile('supabase/migrations/038_link_studio_card_rfid.sql','utf8'));
 const importMigration=await readFile('supabase/migrations/039_preserve_imported_card_skills.sql','utf8');await db.exec(importMigration);await db.exec(importMigration);
 const legacy='10000000-0000-4000-8000-000000000009';
 await db.query("INSERT INTO game_cards(id,name,card_code,metadata) VALUES($1,'Legacy','LEGACY','{}')",[legacy]);
 const legacySkill=(await db.query("INSERT INTO special_skills(code,name,description,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,is_active,catalog_status) VALUES('legacy_rule','Legacy rule','Heal 19','active','main_phase',ARRAY['active'],'{\"type\":\"ally_active\"}','{\"type\":\"none\"}','{\"action_points\":2,\"cooldown_turns\":4}',$1,false,true,'active') RETURNING id",[customEffects])).rows[0].id;
 await db.query("INSERT INTO game_card_special_skills VALUES($1,$2,1,true,'{\"action_points\":1}')",[legacy,legacySkill]);
 await db.query('UPDATE game_cards SET metadata=$2 WHERE id=$1',[legacy,metadata]);
 assert.equal((await db.query('SELECT metadata FROM game_cards WHERE id=$1',[legacy])).rows[0].metadata.studio_legacy_bindings,true);
 await db.query("INSERT INTO card_studio_entries VALUES(auth.uid(),'legacy-test','DRAFT-LEGACY',$1)",[legacy]);
 await db.query("SELECT sync_card_studio_battle_skills('legacy-test')");
 assert.equal((await skills(legacy)).length,1);assert.equal((await skills(legacy))[0].id,legacySkill);
 const instance=(await db.query("SELECT link_studio_card_rfid($1,'LEGACY-UID') result",[legacy])).rows[0].result.id;
 assert.equal((await skills(instance)).length,1);assert.equal((await skills(instance))[0].id,legacySkill);
 const unified=structuredClone(metadata);unified.studio_card.sync_skill_presentation=true;unified.studio_card.skills[0].name='Unified name';unified.studio_card.skills[0].description='Custom heal 19';unified.studio_artwork.skill_icons[0]={url:'https://example.test/unified.webp'};
 const originalRules=(await skills(legacy))[0].effects;
 await db.query('UPDATE game_cards SET metadata=metadata||$2 WHERE id=$1',[legacy,unified]);
 assert.equal((await skills(legacy))[0].name,'Unified name');assert.equal((await skills(legacy))[0].icon,'https://example.test/unified.webp');assert.deepEqual((await skills(legacy))[0].effects,originalRules);
 console.log('PASS: legacy edits, automatic templates, repeated saves, renamed codes, image/rule/AP/CD preservation, RFID inheritance, draft safety, existing copy isolation, active validation, atomic rollback, migration idempotency and authenticated helper isolation.');
} finally {await db.close();}
