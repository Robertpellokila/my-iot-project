import test from 'node:test';
import assert from 'node:assert/strict';
import {skillCooldown,skillApCost,isSkillImage} from '../../src/lib/battle/skillState.js';
import {splitSkillIcon,skillMediaValue,skillLimitLabel,describeBasicSkill} from '../../src/lib/battle/skillPresentation.js';
test('CD2 blocks two subsequent owner turns, independent of opponent turns',()=>{
 const s={limits:{cooldown_turns:2},cooldown_until_owner_turn:3};
 for(const [turn,remaining] of [[1,3],[2,2],[3,1],[4,0]]) assert.equal(skillCooldown(s,{player1_owner_turn:turn},'p1').remaining,remaining);
 assert.equal(skillCooldown(s,{player1_owner_turn:2,player2_owner_turn:99},'p1').remaining,2);
});
test('independent skill clocks, CD0, long CD and legacy semantics',()=>{
 assert.equal(skillCooldown({limits:{cooldown_turns:0}},{round:8},'p2').ready,true);
 assert.equal(skillCooldown({limits:{cooldown_turns:5},cooldown_until_owner_turn:6},{player2_owner_turn:4},'p2').remaining,3);
 assert.equal(skillCooldown({limits:{cooldown_rounds:2},cooldown_until_round:3},{round:3},'p1').ready,false);
 assert.equal(skillCooldown({limits:{cooldown_rounds:2},cooldown_until_round:3},{round:4},'p1').ready,true);
});
test('AP respects snapshot overrides, free skills and configured fallback',()=>{
 for(const value of [0,1,2,10]) assert.equal(skillApCost({limits:{action_points:value}},3),value);
 for(const value of [undefined,null,11,-1,'bad']) assert.equal(skillApCost({limits:{action_points:value}},3),3);
});
test('icon URLs reject script protocols',()=>{assert.ok(isSkillImage('/images/icon.png'));assert.equal(isSkillImage('javascript:alert(1)'),false);});
test('skill image fields separate URL media from fallback symbols',()=>{
 const url='https://example.test/skill.webp';
 assert.deepEqual(splitSkillIcon(url),{imageUrl:url,symbol:'✦'});
 assert.equal(skillMediaValue(url,'✦'),url);assert.equal(skillMediaValue('','🔥'),'🔥');
 assert.throws(()=>skillMediaValue('javascript:alert(1)','✦'));
 assert.throws(()=>skillMediaValue('',url));
});
test('skill explanations use configured targets, AP and owner-turn cooldown',()=>{
 assert.equal(skillLimitLabel({limits:{cooldown_turns:2,cooldown_rounds:9}}),'2 giliran pemilik');
 assert.equal(skillLimitLabel({limits:{cooldown_rounds:3}}),'3 ronde');
 assert.equal(skillLimitLabel({limits:{cooldown_turns:0}}),'Tanpa cooldown');
 const copy=describeBasicSkill({type:'heal_player',amount:12,target:'enemy_player',actionPoints:2,cooldown:3,once:true});
 assert.match(copy.description,/Pulihkan 12 HP pemain lawan/);
 assert.match(copy.description,/Biaya 2 AP\. Cooldown 3 giliran pemilik\. Hanya sekali per battle\./);
});
