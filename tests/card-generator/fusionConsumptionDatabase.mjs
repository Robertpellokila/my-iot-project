import {PGlite} from '@electric-sql/pglite';import {readFile} from 'node:fs/promises';import assert from 'node:assert/strict';
const db=new PGlite();
try{
 await db.exec(`CREATE TABLE battle_cards(id uuid PRIMARY KEY,zone text,fusion_consumed boolean DEFAULT false,field_fusion_used boolean DEFAULT false,necro_consumed boolean DEFAULT false,consumed_by_fusion_id uuid,graveyard_reason text,graveyard_at timestamptz,CHECK(NOT fusion_consumed OR consumed_by_fusion_id IS NOT NULL));`);
 await db.exec(await readFile('supabase/migrations/041_preserve_fusion_material_consumption.sql','utf8'));
 await db.exec('CREATE TRIGGER consumption BEFORE INSERT OR UPDATE ON battle_cards FOR EACH ROW EXECUTE FUNCTION tcg_sync_fusion_consumption_state()');
 for(const zone of ['active','bench','graveyard']){
  const id=crypto.randomUUID(),fusion=crypto.randomUUID();await db.query('INSERT INTO battle_cards(id,zone) VALUES($1,$2)',[id,zone]);
  await db.query("UPDATE battle_cards SET zone='graveyard',fusion_consumed=true,consumed_by_fusion_id=$2 WHERE id=$1",[id,fusion]);
  let row=(await db.query('SELECT * FROM battle_cards WHERE id=$1',[id])).rows[0];assert.equal(row.fusion_consumed,true);assert.equal(row.graveyard_reason,'fusion_consumed');assert.equal(zone==='graveyard'?row.necro_consumed:row.field_fusion_used,true);
  await db.query("UPDATE battle_cards SET zone='bench' WHERE id=$1",[id]);row=(await db.query('SELECT * FROM battle_cards WHERE id=$1',[id])).rows[0];assert.equal(row.fusion_consumed,true,'zone movement cannot erase consumption');
 }
 const normal=crypto.randomUUID();await db.query("INSERT INTO battle_cards(id,zone,graveyard_reason) VALUES($1,'graveyard','destroyed')",[normal]);assert.equal((await db.query('SELECT fusion_consumed FROM battle_cards WHERE id=$1',[normal])).rows[0].fusion_consumed,false);
 console.log('PASS Fusion consumption: field/bench and graveyard sources stay consumed across zones; ordinary destroyed cards stay eligible.');
}catch(error){console.error(error.message);process.exitCode=1;}finally{await db.close();}
