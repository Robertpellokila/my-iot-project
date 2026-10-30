import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { spawnSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { compileQuestions,buildSeedSql,generateSeed,imageUrl } from '../../scripts/questions/build-question-seed.mjs';
import { questionBank } from '../../scripts/questions/pilot-question-bank.mjs';
import { QUIZ_MODES,QUESTION_CATEGORIES,questionDraft,questionPayload,validateQuestion,checkPreviewAnswer } from '../../src/lib/questions/questionModel.js';
import { gradeWorkspace } from '../../src/lib/questions/blockGrading.js';
const compiled=compileQuestions();

test('60 distinct questions cover every difficulty/mode with hints, feedback, balanced choice keys and adequate time',()=>{
 assert.equal(compiled.length,60);assert.equal(new Set(compiled.map(q=>q.payload.id)).size,60);assert.equal(new Set(compiled.map(q=>q.question)).size,60);
 for(const level of ['easy','medium','hard'])for(const {id:mode} of QUIZ_MODES){
  const group=compiled.filter(q=>q.level===level&&q.mode===mode);assert.equal(group.length,4,`${level}/${mode}`);
  if(['choice','image_choice'].includes(mode))assert.deepEqual(group.map(q=>q.payload.correct_answer).sort(),['A','B','C','D']);
 }
 for(const q of compiled){
  assert.ok(QUESTION_CATEGORIES.includes(q.category),q.key);assert.ok(q.payload.hint_1&&q.payload.hint_2&&q.payload.explanation&&q.payload.learning_topic,q.key);
  assert.equal(q.payload.level,q.level);assert.ok(q.payload.duration_seconds>=45);assert.equal(q.payload.is_active,true);
  assert.ok(!('block_solutions' in q.payload));assert.ok(!('solutions' in (q.payload.block_config||{})));
 }
});

test('every published choice, bug line and order accepts its key and rejects a meaningful wrong answer',()=>{
 for(const q of compiled.filter(q=>q.mode!=='scratch_blocks')){
  const p=q.payload;
  if(q.mode==='block_order'){
   assert.deepEqual(p.correct_sequence.map(i=>p.blocks[i]),q.blocks);
   assert.notDeepEqual(p.correct_sequence,p.blocks.map((_,i)=>i));
   assert.equal(checkPreviewAnswer(p,{order:p.correct_sequence}),true,q.key);
   assert.equal(checkPreviewAnswer(p,{order:p.correct_sequence.toReversed()}),false,q.key);
  }else{
   const field=q.mode==='find_bug'?'line_index':'answer_index',index=p.correct_answer.charCodeAt(0)-65;
   assert.equal(checkPreviewAnswer(p,{[field]:index}),true,q.key);
   const count=q.mode==='find_bug'?q.code.split('\n').length:4;
   assert.equal(checkPreviewAnswer(p,{[field]:(index+1)%count}),false,q.key);
   if(q.options)assert.equal(p[`option_${p.correct_answer.toLowerCase()}`],q.options[0],q.key);
  }
 }
});

test('all workspaces start unsolved, accept the answer, reject changed inputs, and contain only available blocks',()=>{
 for(const q of compiled.filter(q=>q.mode==='scratch_blocks')){
  assert.equal(gradeWorkspace(q.initial,q.solutions,q.config,q.grading).correct,false,q.key);
  assert.equal(gradeWorkspace(q.solutions[0],q.solutions,q.config,q.grading).correct,true,q.key);
  const changed=structuredClone(q.solutions[0]);let mutated=false;
  function mutate(node){if(!node||typeof node!=='object'||mutated)return;if(node.type==='tbc_number'){node.fields.NUM+=1;mutated=true;return;}for(const value of Object.values(node))mutate(value);}
  mutate(changed);assert.ok(mutated);assert.equal(gradeWorkspace(changed,q.solutions,q.config,q.grading).correct,false,q.key);
 }
});

test('Python and JavaScript output/bug claims execute as authored in isolated test runtimes',()=>{
 for(const q of questionBank.filter(q=>q.execution)){
  const e=q.execution;
  if(e.language==='javascript'){
   const run=code=>{const lines=[];vm.runInNewContext(code,{console:{log:(...values)=>lines.push(values.map(String).join(' '))}},{timeout:500});return lines.join('\n');};
   assert.equal(run(e.code),e.stdout,q.key);
   if(q.brokenError)assert.throws(()=>run(q.code),error=>error.name===q.brokenError,q.key);
   if(q.brokenOutput)assert.equal(run(q.code),q.brokenOutput,q.key);
  }else{
   const run=code=>spawnSync('python3',['-I','-c',code],{encoding:'utf8',timeout:2000});
   const result=run(e.code);assert.equal(result.status,0,`${q.key}: ${result.stderr}`);assert.equal(result.stdout.trimEnd(),e.stdout,q.key);
   if(q.brokenError){const broken=run(q.code);assert.notEqual(broken.status,0,q.key);assert.ok(broken.stderr.includes(q.brokenError),q.key);}
  }
  if(q.options)assert.equal(q.options[0],e.stdout,q.key);
 }
});

test('admin round trips preserve ordered-code indentation and playable mode',()=>{
 for(const q of compiled){
  const draft=questionDraft(q.payload);
  if(q.mode==='scratch_blocks'){draft.block_solutions=q.solutions;draft.block_grading=q.grading;}
  assert.deepEqual(validateQuestion(draft,q.payload.image_url),[],q.key);
  const saved=questionPayload(draft,q.payload.image_url);assert.equal(saved.question_type,q.payload.question_type);
  if(q.mode==='block_order')assert.deepEqual(saved.correct_sequence.map(i=>saved.blocks[i]),q.blocks,q.key);
 }
});

test('SQL generation is deterministic and all 12 illustrations are present without embedded answers',async()=>{
 assert.equal(buildSeedSql(),buildSeedSql());await generateSeed({check:true});
 const images=compiled.filter(q=>q.diagram);assert.equal(images.length,12);
 for(const q of images){const svg=await readFile(`public${imageUrl(q)}`,'utf8');assert.ok(svg.includes('<svg'));assert.ok(!svg.includes('<script'));assert.ok(!svg.includes('correct_answer'));}
});
