import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;
 CREATE FUNCTION is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.admin',true),'no')='yes' $$;
 CREATE TABLE battle_sessions(id int PRIMARY KEY,status text,is_active boolean,active_until timestamptz);
 INSERT INTO battle_sessions VALUES(1,'question',true,now()+interval '1 hour'),(2,'question',false,NULL),(3,'question',true,now()-interval '1 hour'),(4,'finished',false,now()-interval '1 hour');
 ALTER TABLE battle_sessions ENABLE ROW LEVEL SECURITY;
 CREATE POLICY public_battle ON battle_sessions FOR SELECT USING(true);
 GRANT SELECT ON battle_sessions TO anon,authenticated;
 CREATE TABLE battle_question_rounds(id int PRIMARY KEY,battle_id int REFERENCES battle_sessions,created_at timestamptz DEFAULT now(),timer_started_at timestamptz,timer_paused_at timestamptz,winner_player text);
 INSERT INTO battle_question_rounds(id,battle_id) SELECT id,id FROM battle_sessions;
 ALTER TABLE battle_question_rounds ENABLE ROW LEVEL SECURITY;
 GRANT ALL ON battle_question_rounds TO anon,authenticated;
 SET ROLE anon;`);
 assert.equal((await db.query('SELECT * FROM battle_question_rounds WHERE id=1')).rows.length,0,'reproduce RLS null round without a query error');
 await db.exec('RESET ROLE');
 const migration=await readFile('supabase/migrations/057_public_quiz_round_clock.sql','utf8');
 await db.exec(migration);await db.exec(migration);
 for(const role of ['anon','authenticated']) {
  await db.exec(`SET ROLE ${role}`);
  const rows=(await db.query('SELECT * FROM battle_question_rounds ORDER BY id')).rows;
  assert.deepEqual(rows.map(r=>r.id),[1,4]);assert.ok(Date.parse(rows[0].created_at));
  for(const sql of ["UPDATE battle_question_rounds SET created_at=now() WHERE id=1","DELETE FROM battle_question_rounds WHERE id=1","TRUNCATE battle_question_rounds","INSERT INTO battle_question_rounds(id,battle_id) VALUES(9,1)"])
   await assert.rejects(db.exec(sql),/permission denied/);
  await db.exec('RESET ROLE');
 }
 await db.exec("SET test.admin='yes'; SET ROLE authenticated;");assert.equal((await db.query('SELECT * FROM battle_question_rounds')).rows.length,4);
 await db.exec("RESET ROLE; SET test.admin='no'; UPDATE battle_question_rounds SET timer_started_at=now()-interval '10 seconds',timer_paused_at=now() WHERE id=1; SET ROLE anon;");
 const round=(await db.query('SELECT * FROM battle_question_rounds WHERE id=1')).rows[0];assert.equal(Date.parse(round.timer_paused_at)-Date.parse(round.timer_started_at),10000);
 console.log('PASS real RLS reproduction and repair, anon/authenticated clocks, expired/disabled isolation, completed history, admin history, pause anchors and all client writes denied.');
}finally{await db.close();}
