import test from 'node:test';import assert from 'node:assert/strict';
import {gradeWorkspace,normalizeWorkspace} from '../../src/lib/questions/blockGrading.js';
import {DEFAULT_BLOCK_CONFIG} from '../../src/lib/questions/scratchBlocks.js';
import {blankQuestion,questionPayload,questionDraft,validateQuestion} from '../../src/lib/questions/questionModel.js';
export const program=n=>{
 const move={type:'tbc_move',inputs:{STEPS:{shadow:{type:'tbc_number',fields:{NUM:10}}}}};
 const repeat={type:'tbc_repeat',inputs:{TIMES:{shadow:{type:'tbc_number',fields:{NUM:n}}},DO:{block:move}}};
 return {blocks:{languageVersion:0,blocks:[{type:'tbc_flag',id:'flag',x:10,y:20,next:{block:repeat}}]}};
};
test('nested loops match independent IDs and coordinates; input changes rejected',()=>{const a=program(3);a.blocks.blocks[0].id='random';a.blocks.blocks[0].x=999;assert.equal(gradeWorkspace(a,[program(3)]).correct,true);assert.equal(gradeWorkspace(program(4),[program(3)]).correct,false);});
test('checks sockets, missing children and reordered blocks',()=>{const a=program(3);a.blocks.blocks[0].next.block.inputs.ELSE=a.blocks.blocks[0].next.block.inputs.DO;delete a.blocks.blocks[0].next.block.inputs.DO;assert.equal(gradeWorkspace(a,[program(3)]).correct,false);});
test('numeric tolerance, value toggle, variants, partial score',()=>{assert.equal(gradeWorkspace(program(3.05),[program(3)],{}, {numeric_tolerance:.1}).correct,true);assert.equal(gradeWorkspace(program(9),[program(3)],{}, {check_values:false}).correct,true);assert.equal(gradeWorkspace(program(4),[program(3),program(4)]).correct,true);const r=gradeWorkspace(program(4),[program(3)],{},{partial_credit:true,weight:10});assert.ok(!r.correct&&r.score>0&&r.score<10);});
test('unknown blocks, object fields, forbidden blocks and excess size rejected',()=>{const a=program(3);a.blocks.blocks[0].type='eval';assert.throws(()=>normalizeWorkspace(a));assert.throws(()=>normalizeWorkspace(program(3),{allowed_types:['tbc_flag']}));assert.throws(()=>normalizeWorkspace({blocks:{blocks:Array(101).fill({type:'tbc_flag'})}}));});
test('allow extra and unordered policies do not affect default exact matching',()=>{const a=program(3);a.blocks.blocks.push({type:'tbc_flag'});assert.equal(gradeWorkspace(a,[program(3)]).correct,false);assert.equal(gradeWorkspace(a,[program(3)],{},{allow_extra:true}).correct,true);});
test('structured authoring payload excludes solutions and retains initial workspace',()=>{const d=blankQuestion();Object.assign(d,{question:'Susun loop',mode:'scratch_blocks',block_solutions:[program(3)],duration_seconds:90});assert.deepEqual(validateQuestion(d),[]);const p=questionPayload(d);assert.equal(p.question_type,'scratch_blocks');assert.equal(p.block_solutions,undefined);assert.equal(p.duration_seconds,90);assert.deepEqual(questionDraft(p).block_config,DEFAULT_BLOCK_CONFIG);});
