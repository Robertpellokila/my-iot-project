import {test} from 'node:test';
import assert from 'node:assert/strict';
import {EFFECTS,normalizeSynergyType,synergyRuleState,effectSummary} from '../../src/lib/battle/battleRuleCatalog.js';
const rule={kind:'synergy',element:'forest',name:'Nature Restore',min_cards:2,effect_type:'heal_percent',effect_values:{2:30,3:45,4:60}};
const card=(element='Forest',extra={})=>({element,current_hp:100,zone:'active',...extra});
test('Synergy canonical and legacy aliases agree without collapsing legacy Ice',()=>{
 for(const [input,expected] of [['grass','forest'],['Electric','thunder'],['Wind','thunder'],['Knight','knight'],['LIGHT','light'],['Ice','ice']])assert.equal(normalizeSynergyType(input),expected);
});
test('threshold, active/KO/exhausted source and shared alias use ledger match server rules',()=>{
 const c=card(),cards=[c,card('Grass')];assert.equal(synergyRuleState([rule],c,cards).ready,true);
 for(const extra of [{zone:'bench'},{exhausted:true},{current_hp:0}])assert.equal(synergyRuleState([rule],card('Forest',extra),[...cards,card()]).ready,false);
 assert.equal(synergyRuleState([rule],c,[c,card('Forest',{zone:'bench'})]).ready,false);
 assert.equal(synergyRuleState([rule],c,cards,{grass:true}).used,true);
 assert.equal(synergyRuleState([{...rule,min_cards:3}],c,cards).ready,false);
 assert.match(synergyRuleState([rule],c,[...cards,card()]).effect,/45%/);
});
test('effect labels describe executable numeric fields and fixed semantics',()=>{
 for(const [effect,spec] of Object.entries(EFFECTS))assert.equal(typeof effectSummary({...rule,effect_type:effect,effect_values:{2:spec.fixed??20}}),'string');
 assert.match(effectSummary({kind:'quiz_bonus',effect_type:'heal_flat',effect_values:{1:22}}),/22 HP/);
 assert.match(effectSummary({kind:'quiz_bonus',effect_type:'power_strike',effect_values:{1:50}}),/50%/);
});
