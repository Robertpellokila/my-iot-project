import {test} from 'node:test';
import assert from 'node:assert/strict';
import {comboCode, comboMembersMatch, findComboRule, comboCooldown, comboPower} from '../../src/lib/battle/comboRules.js';
const card=(id,element='fire',tags=[])=>({id,card_code:id,element,tags,attack:35});
const pair={id:1,rule_kind:'same',type_keys:['fire','fire'],members:[],enabled:true};
test('members match independent of order and never reuse the same card',()=>{
 const rules=[{type:'fire'},{type:'fire',card_code:'A',tag:'TEAM'}];
 assert.equal(comboMembersMatch(rules,[card('A','fire',['team']),card('B')]),true);
 assert.equal(comboMembersMatch(rules,[card('A'),card('B','fire',['TEAM'])]),false);
 assert.equal(comboMembersMatch([{card_code:'A'},{card_code:'A'}],[card('A'),card('B')]),false);
});
test('printed code normalization removes storage suffix but not arbitrary prefixes',()=>{
 assert.equal(comboCode('cob-008'),comboCode('COB_008_STUDIO_'+ 'A'.repeat(32)));
 assert.notEqual(comboCode('COB-008'),comboCode('COB-008-other'));
});
test('recipe priority is deterministic and shared tags exclude Fusion metadata',()=>{
 const strict={...pair,id:2,priority:10,shared_tag:true};
 assert.equal(findComboRule([pair,strict],[card('A','fire',['fusion:F1']),card('B','fire',['fusion:F1'])]).id,1);
 assert.equal(findComboRule([pair,strict],[card('A','fire',['Team']),card('B','fire',['team'])]).id,2);
 assert.equal(findComboRule([pair,{...strict,priority:0}],[card('A','fire',['Team']),card('B','fire',['team'])]).id,2);
 assert.equal(findComboRule([{...pair,enabled:false}],[card('A'),card('B')]),null);
 assert.equal(findComboRule([pair],[card('A'),card('B','water')]),null);
});
test('triple and formation require a full type multiset',()=>{
 const triple={...pair,rule_kind:'triple',type_keys:['dark','fire','thunder']};
 assert.equal(findComboRule([triple],[card('A'),card('B','electric'),card('C','dark')]),triple);
 assert.equal(findComboRule([triple],[card('A'),card('B'),card('C','dark')]),null);
 const formation={...pair,rule_kind:'formation',type_keys:['fire','fire','fire','fire']};
 assert.equal(findComboRule([formation],[card('A'),card('B'),card('C'),card('D')]),formation);
});
test('shared cooldown skips precisely one owner turn and survives other side turns',()=>{
 const b={combo_policy:{version:1},player1_owner_turn:3,player1_combo_last_owner_turn:3};
 assert.equal(comboCooldown(b,'p1').remaining,2);
 assert.equal(comboCooldown({...b,current_turn:'p2',player2_owner_turn:9},'p1').remaining,2);
 assert.equal(comboCooldown({...b,player1_owner_turn:4},'p1').remaining,1);
 assert.equal(comboCooldown({...b,player1_owner_turn:5},'p1').reason,'');
 assert.equal(comboCooldown(b,'p2').reason,'');
 assert.equal(comboCooldown({...b,combo_policy:null},'p1').reason,'');
});
test('power preview floors assists separately and follows primary selection',()=>{
 const cards=[card('A'),{...card('B'),attack:40},card('C')];
 assert.equal(comboPower(cards.slice(0,2),'A',null),55);
 assert.equal(comboPower(cards,'B',{primary_multiplier:1,assist_multipliers:[.6,.5],bonus_damage:12,damage_multiplier:1}),90);
});
