// Isolated PostgreSQL: real quiz migration validators, real seed and grading.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { compileQuestions,seedFile } from '../../scripts/questions/build-question-seed.mjs';
const db=new PGlite();
const migration=name=>readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8');
try {
await db.exec(`
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE battle_sessions(id uuid PRIMARY KEY,code text,player1_token text,player2_token text,question_active boolean,current_question_id uuid,current_question_round_id uuid,question_bonus_enabled boolean DEFAULT false,question_time_limit_seconds integer DEFAULT 30,status text DEFAULT 'question',winner text);
CREATE TABLE coding_questions(id uuid PRIMARY KEY,question text,question_type text DEFAULT 'choice',blocks jsonb DEFAULT '[]',correct_sequence jsonb DEFAULT '[]',code_snippet text,bug_line integer,option_a text,option_b text,option_c text,option_d text,correct_answer text);
CREATE TABLE battle_question_rounds(id uuid PRIMARY KEY,battle_id uuid REFERENCES battle_sessions(id),question_id uuid REFERENCES coding_questions(id),status text DEFAULT 'active',created_at timestamptz DEFAULT now(),winner_player text,winner_answer integer,won_at timestamptz);
CREATE TABLE battle_question_answers(battle_question_id uuid REFERENCES battle_question_rounds(id),player text,answer_index integer,is_correct boolean,answered_at timestamptz,UNIQUE(battle_question_id,player));
CREATE TABLE battle_events(id uuid DEFAULT gen_random_uuid(),battle_id uuid,type text,source_player text,payload jsonb);
`);
const old008=await migration('008_learning_interactive_question_settings.sql');
await db.exec(old008.slice(old008.indexOf('CREATE OR REPLACE FUNCTION public.tcg_expire_battle_question'),old008.indexOf('CREATE OR REPLACE FUNCTION public.submit_battle_interactive_question_answer')));
await db.exec(await migration('013_quiz_bonus_skill_choice.sql'));
await db.exec(await migration('023_close_question_after_both_wrong.sql'));
await db.exec(await migration('028_validate_interactive_quiz_answers.sql'));
await db.exec(await migration('028_validate_interactive_quiz_answers.sql')); // repeat-safe
await db.exec(`CREATE FUNCTION is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.admin',true),'false')='true' $$;
ALTER TABLE coding_questions ADD COLUMN image_url text, ADD COLUMN category text, ADD COLUMN difficulty text, ADD COLUMN is_active boolean, ADD COLUMN explanation text, ADD COLUMN hint_1 text, ADD COLUMN hint_2 text, ADD COLUMN learning_topic text, ADD COLUMN learning_url text;`);
await db.exec(await migration('030_structured_block_quiz.sql'));

await db.exec("ALTER TABLE coding_questions ADD COLUMN level text, ADD COLUMN deleted_at timestamptz, ADD COLUMN created_at timestamptz DEFAULT now();");
const sql=await readFile(seedFile,'utf8');
await db.exec(sql);
assert.equal((await db.query('SELECT count(*)::int n FROM coding_questions')).rows[0].n,60);
assert.equal((await db.query('SELECT count(*)::int n FROM coding_question_block_keys')).rows[0].n,12);
const bank=compileQuestions();
// Reproduce the phone's anonymous SELECT failure, then verify only display fields are opened.
await db.exec(await migration('010_protect_coding_question_answers.sql'));
await db.exec('SET ROLE anon');
await assert.rejects(db.exec('SELECT block_config,duration_seconds FROM coding_questions LIMIT 1'),/permission denied/);
await db.exec('RESET ROLE');
await db.exec(await migration('055_public_quiz_block_fields.sql'));
await db.exec('SET ROLE anon');
assert.equal((await db.query('SELECT id,question,block_config,duration_seconds FROM coding_questions')).rows.length,60);
for(const field of ['correct_answer','correct_sequence','bug_line'])await assert.rejects(db.exec(`SELECT ${field} FROM coding_questions LIMIT 1`),/permission denied/);
await assert.rejects(db.exec('SELECT solutions FROM coding_question_block_keys LIMIT 1'),/permission denied/);
await db.exec('RESET ROLE');
for(const q of bank){
 const b='50000000-0000-4000-8000-000000000001',r='60000000-0000-4000-8000-000000000001';
 await db.exec('DELETE FROM battle_block_answers;DELETE FROM battle_question_bonus_choices;DELETE FROM battle_question_answers;DELETE FROM battle_events;DELETE FROM battle_question_rounds;DELETE FROM battle_sessions;');
 await db.query("INSERT INTO battle_sessions(id,code,player1_token,player2_token,question_active,current_question_id,current_question_round_id) VALUES($1,'SEEDQA','one','two',true,$2,$3)",[b,q.payload.id,r]);
 await db.query('INSERT INTO battle_question_rounds(id,battle_id,question_id) VALUES($1,$2,$3)',[r,b,q.payload.id]);
 const interactive=q.payload.question_type!=='choice';
 let correct,wrong;
 if(q.mode==='scratch_blocks'){correct={workspace:q.solutions[0]};wrong={workspace:q.initial};}
 else if(q.mode==='block_order'){correct={order:q.payload.correct_sequence};wrong={order:q.payload.correct_sequence.toReversed()};}
 else {const i=q.payload.correct_answer.charCodeAt(0)-65;const n=q.mode==='find_bug'?q.code.split('\n').length:4;correct=interactive?{line_index:i}:i;wrong=interactive?{line_index:(i+1)%n}:(i+1)%n;}
 const submit=async(player,token,answer)=>(await db.query(`SELECT ${interactive?'submit_battle_interactive_question_answer':'submit_battle_question_answer'}($1,$2,$3,$4,$5) result`,['SEEDQA',player,token,r,interactive?JSON.stringify(answer):answer])).rows[0].result;
 const failed=await submit('p1','one',wrong);assert.equal(failed.ok,true,`${q.key}: valid wrong answer: ${JSON.stringify(failed)}`);assert.equal(failed.correct,false,q.key);
 const passed=await submit('p2','two',correct);assert.equal(passed.correct,true,`${q.key}: ${JSON.stringify(passed)}`);
}
// A rerun must preserve edits, archived rows and private key changes.
const changed=bank.find(q=>q.mode==='scratch_blocks');
await db.query("UPDATE coding_questions SET question='Edited by teacher',is_active=false,deleted_at=now() WHERE id=$1",[changed.payload.id]);
await db.query("UPDATE coding_question_block_keys SET grading=grading||'{\"weight\":3}'::jsonb WHERE question_id=$1",[changed.payload.id]);
const before=(await db.query('SELECT jsonb_agg(to_jsonb(q) ORDER BY id) rows FROM coding_questions q')).rows[0].rows;
const keys=(await db.query('SELECT jsonb_agg(to_jsonb(k) ORDER BY question_id) rows FROM coding_question_block_keys k')).rows[0].rows;
await db.exec(sql);
assert.deepEqual((await db.query('SELECT jsonb_agg(to_jsonb(q) ORDER BY id) rows FROM coding_questions q')).rows[0].rows,before);
assert.deepEqual((await db.query('SELECT jsonb_agg(to_jsonb(k) ORDER BY question_id) rows FROM coding_question_block_keys k')).rows[0].rows,keys);
assert.equal((await db.query("SELECT has_table_privilege('anon','coding_question_block_keys','SELECT') allowed")).rows[0].allowed,false);
// Inject a failure into a fresh atomic seed: neither questions nor keys persist.
await db.exec('DELETE FROM battle_block_answers;DELETE FROM battle_question_bonus_choices;DELETE FROM battle_question_answers;DELETE FROM battle_events;DELETE FROM battle_question_rounds;DELETE FROM battle_sessions;DELETE FROM coding_questions;');
await db.exec("ALTER TABLE coding_question_block_keys ADD CONSTRAINT reject_seed_test CHECK (jsonb_array_length(solutions)=0);");
await assert.rejects(db.exec(sql));await db.exec('ROLLBACK');
assert.equal((await db.query('SELECT count(*)::int n FROM coding_questions')).rows[0].n,0);
assert.equal((await db.query('SELECT count(*)::int n FROM coding_question_block_keys')).rows[0].n,0);
console.log('PASS: 60 inserted questions, 12 private keys, 120 real-engine answer submissions, edit/archive-safe reruns, private-key permissions, atomic rollback.');
} catch(error){console.error(error.message,error.where??'',error.position??'');process.exitCode=1;}finally{await db.close();}
