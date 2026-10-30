import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.admin',true),'no')='yes' $$;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT CASE WHEN public.is_admin() THEN '01000000-0000-4000-8000-000000000001'::uuid END $$;
 CREATE TABLE game_cards(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),uid text,name text,hp integer,attack integer,defense integer,metadata jsonb,archived_at timestamptz);
 CREATE TABLE rfid_cards(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),uid text,label text,card_type text,is_active boolean,owner_id uuid);
 INSERT INTO game_cards(uid,name,hp,attack,defense,metadata) VALUES('RFID-123','Coby',120,32,10,'{"design":"unchanged","skills":["Guard"]}');
 INSERT INTO rfid_cards(uid,label,card_type,is_active,owner_id) VALUES('REG-123','Testing','rfid_card',true,gen_random_uuid());
 SET test.admin='yes';`);
 const sql=await readFile('supabase/migrations/056_admin_rfid_lookup.sql','utf8');await db.exec(sql);await db.exec(sql);
 const inspect=async uid=>(await db.query('SELECT admin_lookup_card_rfid($1) r',[uid])).rows[0].r;
 const before=(await db.query('SELECT jsonb_agg(to_jsonb(c)) r FROM game_cards c')).rows[0].r;
 const found=await inspect(' rfid-123 ');assert.equal(found.cards[0].name,'Coby');assert.equal(found.uid,'RFID-123');assert.equal(found.registered,true);
 assert.deepEqual(found.cards[0].metadata,{design:'unchanged',skills:['Guard']});
 const registry=await inspect('REG-123');assert.equal(registry.registered,true);assert.deepEqual(registry.cards,[]);assert.equal(registry.registration.label,'Testing');assert.equal('owner_id' in registry.registration,false);
 const fresh=await inspect('NEW-123');assert.equal(fresh.registered,false);assert.deepEqual(fresh.cards,[]);assert.equal(fresh.registration,null);
 for(const uid of ['',null,'123','x'.repeat(129),'AB\nCD'])await assert.rejects(inspect(uid),/UID RFID/);
 assert.deepEqual((await db.query('SELECT jsonb_agg(to_jsonb(c)) r FROM game_cards c')).rows[0].r,before);
 await db.exec("UPDATE game_cards SET archived_at=now();INSERT INTO game_cards(uid,name) VALUES('rfid-123','Duplicate');");
 const duplicate=await inspect('RFID-123');assert.equal(duplicate.cards.length,2);assert.ok(duplicate.cards.some(c=>c.archived_at));
 await db.exec("SET test.admin='no';SET ROLE authenticated;");await assert.rejects(inspect('RFID-123'),/Login admin/);
 await db.exec('RESET ROLE;SET ROLE anon;');await assert.rejects(inspect('RFID-123'),/permission denied/);
 console.log('PASS read-only UID lookup: exact normalized match, new/registry-only/archived/ambiguous cards, design/skill preservation, input validation and admin-only permissions.');
}finally{await db.close();}
