import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = new PGlite();
const read = file => readFile(`supabase/migrations/${file}`, 'utf8');
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.r;
const access = code => value('SELECT admin_battle_access($1) r', [code]);
const redeem = (code, battle = null, side = null) => value('SELECT redeem_battle_player_code($1,$2,$3) r', [code, battle, side]);
const create = code => db.query("INSERT INTO battle_sessions(code,status,is_active,active_until) VALUES($1,'battle',true,now()+interval '1 day')", [code]);
const randomStub = `CREATE OR REPLACE FUNCTION extensions.gen_random_bytes(n integer) RETURNS bytea LANGUAGE sql VOLATILE AS $$ SELECT decode(substr(string_agg(replace(gen_random_uuid()::text,'-',''),''),1,n*2),'hex') FROM generate_series(1,(n+15)/16) $$;`;
try {
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA extensions;
 CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('test.admin',true)='yes' $$;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT CASE WHEN public.is_admin() THEN '01000000-0000-4000-8000-000000000001'::uuid END $$;
 CREATE TABLE battle_sessions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text UNIQUE,status text,is_active boolean,active_until timestamptz,created_by uuid,player1_token text,player2_token text,player1_access_code text,player2_access_code text);
 CREATE TABLE battle_events(battle_id uuid,type text,target_player text,payload jsonb);
 CREATE FUNCTION start_battle_question(uuid,integer) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
 CREATE FUNCTION tcg_tick_statuses_for_player(uuid,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
 CREATE FUNCTION tcg_finish_action_point_turn(uuid,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
 CREATE FUNCTION tcg_emit_fusion_battle_event(uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
 SET test.admin='yes';${randomStub}`);
 // PGlite has no pgcrypto: UUID bytes stand in only for the entropy source.
 // Production uses the existing pgcrypto extensions.gen_random_bytes implementation.
 await db.exec(await read('045_private_battle_player_access.sql'));
 await create('LEGACY');
 const legacy = await access('LEGACY');
 assert.equal(legacy.player1_access_code.length, 12);
 const legacyLogin = await redeem(legacy.player1_access_code);
 const migration = await read('054_short_player_access_codes.sql');
 await db.exec(migration);
 await db.exec(migration);
 assert.deepEqual(await access('LEGACY'), legacy);
 assert.deepEqual(await redeem(legacy.player1_access_code), legacyLogin);
 await create('SHORT');
 const codes = await access('SHORT');
 for (const side of ['player1','player2']) assert.match(codes[`${side}_access_code`], /^[2-9A-HJ-NP-Z]{6}$/);
 assert.notEqual(codes.player1_access_code,codes.player2_access_code);
 const login = await redeem(codes.player1_access_code.toLowerCase().replace(/(.{3})/, '$1-'), 'SHORT', 'p1');
 assert.equal(login.ok,true);assert.equal(login.player,'p1');assert.equal(login.token.length,48);
 assert.equal((await redeem(codes.player1_access_code,'SHORT','p2')).ok,false);
 assert.equal((await redeem(codes.player1_access_code,'LEGACY','p1')).ok,false);
 assert.equal((await redeem('12345')).ok,false);
 const publicState = (await value("SELECT get_public_battle_state('SHORT') r")).battle;
 for(const field of ['player1_token','player2_token','player1_access_code','player2_access_code'])assert.equal(field in publicState,false);
 assert.equal(await value("SELECT bool_and(player1_token IS NULL AND player2_token IS NULL AND player1_access_code IS NULL AND player2_access_code IS NULL) r FROM battle_sessions"),true);
 const rotated = await value("SELECT teacher_reset_battle_access('SHORT','p1') r");
 assert.match(rotated.player1_access_code,/^[2-9A-HJ-NP-Z]{6}$/);
 assert.notEqual(rotated.player1_access_code,codes.player1_access_code);
 assert.equal(rotated.player2_access_code,codes.player2_access_code);
 assert.equal((await redeem(codes.player1_access_code)).ok,false);
 assert.equal((await value("SELECT get_battle_player_state('SHORT','p1',$1) r",[login.token])).ok,false);
 assert.equal((await redeem(rotated.player1_access_code)).ok,true);
 const legacyRotated = await value("SELECT teacher_reset_battle_access('LEGACY','p1') r");
 assert.equal(legacyRotated.player1_access_code.length,6);
 assert.equal(legacyRotated.player2_access_code,legacy.player2_access_code);
 await db.exec("SET test.admin='no'");
 await assert.rejects(access('SHORT'),/Login guru/);
 await assert.rejects(value("SELECT teacher_reset_battle_access('SHORT','p1') r"),/Login guru/);
 for(const role of ['anon','authenticated'])assert.equal(await value("SELECT has_function_privilege($1,'tbc_private.issue_battle_player_access(uuid,text,text)','EXECUTE') r",[role]),false);
 assert.equal(await value("SELECT has_function_privilege('anon','public.teacher_reset_battle_access(text,text)','EXECUTE') r"),false);
 await db.exec("SET test.admin='yes'");
 for(let i=0;i<15;i++)assert.equal((await redeem('ZZZZZZ')).ok,false);
 assert.equal((await redeem(rotated.player1_access_code)).code,'RATE_LIMIT');
 await db.exec("UPDATE tbc_private.battle_access_attempts SET started_at=now()-interval '61 seconds'");
 assert.equal((await redeem(rotated.player1_access_code)).ok,true);
 for(const update of ["status='finished'","is_active=false","active_until=now()-interval '1 second'"]){
  await db.exec(`UPDATE battle_sessions SET ${update} WHERE code='SHORT'`);
  assert.equal((await redeem(rotated.player1_access_code)).ok,false);
  await db.exec("UPDATE battle_sessions SET status='battle',is_active=true,active_until=now()+interval '1 day' WHERE code='SHORT'");
 }
 for(let i=0;i<40;i++)await create(`MANY${i}`);
 assert.equal(await value("SELECT count(DISTINCT access_code)=count(*) r FROM tbc_private.battle_player_access"),true);
 // Force repeated collisions: the whole battle creation must roll back, not leave one player's access behind.
 await db.exec("CREATE OR REPLACE FUNCTION extensions.gen_random_bytes(n integer) RETURNS bytea LANGUAGE sql VOLATILE AS $$ SELECT decode(repeat('00',n),'hex') $$;");
 await assert.rejects(create('COLLISION'),/Belum dapat membuat kode/);
 assert.equal(await value("SELECT count(*) r FROM battle_sessions WHERE code='COLLISION'"),0);
 assert.equal(await value("SELECT count(*) r FROM tbc_private.battle_player_access WHERE access_code='222222'"),0);
 await db.exec(randomStub);
 // Simulate the unique violation raised if another transaction wins the insert race.
 await db.exec(`CREATE SEQUENCE retry_probe;
 CREATE FUNCTION simulate_access_race() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF nextval('retry_probe')=1 THEN RAISE unique_violation;END IF;RETURN NEW;END $$;
 CREATE TRIGGER simulate_access_race BEFORE INSERT ON tbc_private.battle_player_access FOR EACH ROW EXECUTE FUNCTION simulate_access_race();`);
 await create('RETRY');
 assert.equal(await value("SELECT count(*) r FROM tbc_private.battle_player_access a JOIN battle_sessions b ON b.id=a.battle_id WHERE b.code='RETRY'"),2);
 assert.equal(await value('SELECT last_value r FROM retry_probe'),3);
 console.log('PASS: six-character issuance, 84+ unique codes, collision rollback/retry, normalized login, side/battle guards, legacy compatibility, reset/token revocation, private permissions, 15-attempt limit, unavailable battles and idempotent migration.');
} finally { await db.close(); }
