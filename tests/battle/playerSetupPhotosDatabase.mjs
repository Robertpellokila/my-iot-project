import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
try{
 await db.exec('CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE TABLE battle_sessions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text,player1_token text,player2_token text);');
 await db.exec(await readFile('supabase/migrations/025_player_battle_avatar_selection.sql','utf8'));
 await db.exec("INSERT INTO battle_sessions(code,player1_token,player2_token,player1_avatar_url,player2_avatar_url) VALUES('PHOTO','one','two','https://example.invalid/photo.webp','🐼'),('EMOJI','one','two',NULL,NULL)");
 await db.exec(await readFile('supabase/migrations/044_preserve_player_setup_photos.sql','utf8'));
 const row=async code=>(await db.query('SELECT * FROM battle_sessions WHERE code=$1',[code])).rows[0];
 const avatar=async(code,side,token,value)=>(await db.query('SELECT set_battle_player_avatar($1,$2,$3,$4) r',[code,side,token,value])).rows[0].r;
 assert.equal((await row('PHOTO')).player1_setup_photo_url,'https://example.invalid/photo.webp');
 assert.equal((await avatar('PHOTO','p1','one','🐱')).source,'game_setup');assert.equal((await row('PHOTO')).player1_avatar_url,'https://example.invalid/photo.webp');
 assert.equal((await avatar('PHOTO','p1','bad','🐱')).ok,false);assert.equal((await avatar('PHOTO',null,'two','🐱')).ok,false);
 assert.equal((await avatar('PHOTO','p2','two','🐱')).ok,true);assert.equal((await row('PHOTO')).player2_avatar_url,'🐱');assert.equal((await row('PHOTO')).player1_avatar_url,'https://example.invalid/photo.webp');
 assert.equal((await avatar('EMOJI','p1','one','https://example.invalid/other.webp')).ok,false);
 await db.exec("INSERT INTO battle_sessions(code,player1_token,player2_token,player1_setup_photo_url,player2_avatar_url) VALUES('NEW','a','b','/images/p1.webp','/images/p2.webp')");
 assert.equal((await row('NEW')).player1_avatar_url,'/images/p1.webp');assert.equal((await row('NEW')).player2_setup_photo_url,'/images/p2.webp');
 await db.exec("UPDATE battle_sessions SET player1_avatar_url='🐶' WHERE code='NEW'");assert.equal((await row('NEW')).player1_avatar_url,'/images/p1.webp');
 await db.exec("UPDATE battle_sessions SET player1_setup_photo_url='/images/updated.webp' WHERE code='NEW'");assert.equal((await row('NEW')).player1_avatar_url,'/images/updated.webp');
 await db.exec("UPDATE battle_sessions SET player1_setup_photo_url=NULL WHERE code='NEW'");assert.equal((await row('NEW')).player1_avatar_url,null);
 await assert.rejects(db.exec("UPDATE battle_sessions SET player1_setup_photo_url='javascript:alert(1)' WHERE code='NEW'"),/tidak valid/);
 console.log('PASS photo backfill, two-player setup, legacy photo insert, emoji fallback, token/side validation, photo preservation/update/removal and unsafe URL rejection');
}finally{await db.close();}
