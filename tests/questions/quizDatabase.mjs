// Run with PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite/dist/index.js node tests/questions/quizDatabase.mjs
// This harness uses an isolated in-memory database and the actual grading functions.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const migration = name => readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8');
let passed=0;
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
const b='10000000-0000-0000-0000-000000000001',q='20000000-0000-0000-0000-000000000001',r='30000000-0000-0000-0000-000000000001';
async function fixture(type='block_order',options={}){
 await db.exec('DELETE FROM battle_question_bonus_choices; DELETE FROM battle_question_answers; DELETE FROM battle_events; DELETE FROM battle_question_rounds; DELETE FROM battle_sessions; DELETE FROM coding_questions;');
 await db.query(`INSERT INTO coding_questions(id,question,question_type,blocks,correct_sequence,code_snippet,bug_line,option_a,option_b,option_c,option_d,correct_answer) VALUES($1,'Quiz',$2,'["Gerak 10","Bendera","Katakan selesai"]','[1,0,2]','start\nmove -10\nend',1,'Satu','Dua','Tiga','Empat','B')`,[q,type]);
 await db.query(`INSERT INTO battle_sessions(id,code,player1_token,player2_token,question_active,current_question_id,current_question_round_id,question_bonus_enabled) VALUES($1,'TEST','token1','token2',true,$2,$3,$4)`,[b,q,r,!!options.bonus]);
 await db.query('INSERT INTO battle_question_rounds(id,battle_id,question_id) VALUES($1,$2,$3)',[r,b,q]);
}
async function submit(answer,{player='p1',token='token1',round=r,interactive=true}={}) {
 const name=interactive?'submit_battle_interactive_question_answer':'submit_battle_question_answer';
 const result=await db.query(`SELECT public.${name}($1,$2,$3,$4,$5) AS result`,['TEST',player,token,round,interactive?JSON.stringify(answer):answer]);return result.rows[0].result;
}
async function check(name,fn){await fn();passed++;console.log(`PASS ${name}`);}
await check('migration repeat-safe and internal grader inaccessible',async()=>{const result=await db.query(`SELECT has_function_privilege('anon','public.tcg_grade_battle_question_answer(text,text,text,uuid,integer)','EXECUTE') AS allowed`);assert.equal(result.rows[0].allowed,false);});
await check('reject bypass through choice endpoint',async()=>{await fixture();assert.equal((await submit(0,{interactive:false})).ok,false);});
await check('reject invalid token and stale round',async()=>{await fixture();assert.equal((await submit({order:[1,0,2]},{token:'wrong'})).ok,false);assert.equal((await submit({order:[1,0,2]},{round:'30000000-0000-0000-0000-000000000002'})).ok,false);});
await check('reject duplicates, omissions, non-integers, out-of-range and null',async()=>{await fixture();for(const order of [[1,1,2],[1,0],['1',0,2],[1,0,9],[1.5,0,2],null])assert.equal((await submit({order})).ok,false);assert.equal((await submit({})).ok,false);assert.equal((await submit({order:[1,0,2]})).correct,true);});
await check('wrong then correct by opponent; first player cannot retry',async()=>{await fixture();assert.equal((await submit({order:[0,1,2]})).correct,false);assert.equal((await submit({order:[1,0,2]})).ok,false);assert.equal((await submit({order:[1,0,2]},{player:'p2',token:'token2'})).correct,true);const winner=await db.query('SELECT winner_player FROM battle_question_rounds');assert.equal(winner.rows[0].winner_player,'p2');});
await check('both wrong closes quiz and resumes battle',async()=>{await fixture();await submit({order:[0,1,2]});await submit({order:[0,1,2]},{player:'p2',token:'token2'});const battle=await db.query('SELECT question_active,status FROM battle_sessions');assert.equal(battle.rows[0].question_active,false);assert.equal(battle.rows[0].status,'battle');});
await check('server deadline rejects late answer',async()=>{await fixture();await db.exec("UPDATE battle_question_rounds SET created_at=now()-interval '60 seconds'");const result=await submit({order:[1,0,2]});assert.equal(result.timed_out,true);assert.equal((await db.query('SELECT count(*)::int AS n FROM battle_question_answers')).rows[0].n,0);});
await check('choice grading',async()=>{await fixture('choice');assert.equal((await submit(1,{interactive:false})).correct,true);});
await check('find bug: invalid line rejected and correct line accepted',async()=>{await fixture('find_bug');assert.equal((await submit({line_index:3})).ok,false);assert.equal((await submit({line_index:1})).correct,true);});
await check('winner and bonus recorded exactly once',async()=>{await fixture('block_order',{bonus:true});assert.equal((await submit({order:[1,0,2]})).correct,true);const second=await submit({order:[1,0,2]},{player:'p2',token:'token2'});assert.equal(second.already_finished,true);assert.equal((await db.query('SELECT count(*)::int AS n FROM battle_question_bonus_choices')).rows[0].n,1);});
await check('malformed authoring payload rejected',async()=>{await fixture();await assert.rejects(db.exec("UPDATE coding_questions SET correct_sequence='[1,1,2]'"));await assert.rejects(db.exec("UPDATE coding_questions SET blocks='[\"x\",\"x\",\"y\"]'"));});
const {gradeWorkspace}=await import('../../src/lib/questions/blockGrading.js');
const {DEFAULT_BLOCK_CONFIG}=await import('../../src/lib/questions/scratchBlocks.js');
const program=n=>{
 const move={type:'tbc_move',inputs:{STEPS:{shadow:{type:'tbc_number',fields:{NUM:10}}}}};
 const repeat={type:'tbc_repeat',inputs:{TIMES:{shadow:{type:'tbc_number',fields:{NUM:n}}},DO:{block:move}}};
 return {blocks:{languageVersion:0,blocks:[{type:'tbc_flag',id:'flag',x:10,y:20,next:{block:repeat}}]}};
};
await check('structured key is admin-only; save validates and grades nested program',async()=>{
 await fixture('choice');
 const question={question:'Repeat quiz',block_config:DEFAULT_BLOCK_CONFIG,duration_seconds:90};
 await assert.rejects(db.query('SELECT save_block_question($1,$2,$3,$4)',[q,question,[program(3)],{}]));
 await db.exec("SELECT set_config('test.admin','true',false)");
 await db.query('SELECT save_block_question($1,$2,$3,$4)',[q,question,[program(3)],{}]);
 await db.exec("SELECT set_config('test.admin','false',false)");
 assert.equal((await submit({workspace:program(3)})).correct,true);
 assert.equal((await db.query('SELECT count(*)::int n FROM battle_block_answers')).rows[0].n,1);
 assert.equal((await db.query("SELECT has_table_privilege('anon','coding_question_block_keys','SELECT') allowed")).rows[0].allowed,false);
});
await check('SQL structural grader agrees with local preview for variants and policies',async()=>{
 for(const rules of [{},{check_values:false},{numeric_tolerance:.2},{partial_credit:true,weight:10}]){
  for(const n of [3,3.1,4]){
   const a=program(n),b=program(3);a.blocks.blocks[0].id='ignored';a.blocks.blocks[0].x=900;
   const local=gradeWorkspace(a,[b],DEFAULT_BLOCK_CONFIG,rules);
   const {rows}=await db.query('SELECT tcg_block_match(tcg_normalize_workspace($1,$3),tcg_normalize_workspace($2,$3),$4,true)::float8 score',[a,b,DEFAULT_BLOCK_CONFIG,rules]);
   const fraction=rows[0].score;assert.equal(fraction===1,local.correct);assert.ok(Math.abs((rules.partial_credit?fraction*(rules.weight??1):fraction===1?rules.weight??1:0)-local.score)<.00001);
  }
 }
});
await check('structured payload rejects unknown block types and private key has no public policy',async()=>{
 await assert.rejects(db.query('SELECT tcg_normalize_workspace($1,$2)',[{blocks:{blocks:[{type:'evil'}]}},DEFAULT_BLOCK_CONFIG]));
 const policies=await db.query("SELECT roles FROM pg_policies WHERE tablename='coding_question_block_keys'");assert.deepEqual(policies.rows[0].roles,['authenticated']);
});
console.log(`${passed} database checks passed.`);
} catch(error) {console.error(error.message,error.where??"",error.position);process.exitCode=1;} finally { await db.close(); }
