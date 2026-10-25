import test from 'node:test';
import assert from 'node:assert/strict';
import {compileStudioSkill,withBattleRule} from '../../src/lib/card-generator/cardSkillBattleRules.js';
const rule=description=>compileStudioSkill({name:'Skill',description});
test('attack clauses retain damage, conditions and secondary effects',()=>{
 const burn=rule('Serangan normal +3 saat baru masuk Active dan menerapkan Burn 1.');
 assert.equal(burn.program.operations[0].condition,'entered_active'); assert.equal(burn.program.operations[0].amount,3); assert.equal(burn.program.operations[1].type,'burn');
 const shield=rule('Serangan normal; +3 damage jika diri memiliki Shield.');
 assert.equal(shield.program.operations[0].type,'attack'); assert.equal(shield.program.operations[0].condition,'self_shield');
});
test('choices contain mutually exclusive effects and separate skill limits',()=>{
 const choice=rule('Pilih: heal 12 pada 1 ally ATAU +4 DEF sampai 1 hit. CD 2.');
 assert.equal(choice.program.operations.length,0); assert.deepEqual(choice.target_spec.choices.map(c=>c.id),['heal','defense']); assert.equal(choice.limits.cooldown_turns,2);
});
test('revive uses target max HP, 2AP, once-per-battle and graveyard target',()=>{
 const description='Sekali/battle, saat NUL-006 Active, habiskan 2 AP: pilih 1 Base Card non-Fusion di Graveyard yang bukan fusion_consumed; kembalikan ke Bench dengan 40% Max HP. Kartu yang dibangkitkan tidak boleh Attack/Skill sampai turn berikutnya dan penggunaan once-per-battle tidak di-reset.';
 const revive=rule(description); assert.equal(revive.limits.action_points,2); assert.equal(revive.limits.once_per_battle,true); assert.equal(revive.target_spec.type,'ally_graveyard'); assert.equal(revive.program.operations[0].amount,.4);
});
test('editing text recompiles rather than retaining stale client-provided effects',()=>{
 const changed=compileStudioSkill({name:'Heal',description:'Pulihkan 19 HP pada 1 ally. CD 3.',battle:{effects:[{type:'damage_player',amount:9999}],limits:{cooldown_turns:0}}});
 assert.equal(changed.limits.cooldown_turns,3); assert.equal(changed.program.operations[0].amount,19); assert.equal(changed.effects[0].type,'studio_skill');
});
test('Studio saves preserve explicit registration choices separately from compiler readiness',()=>{
 const unsupported=withBattleRule({name:'Custom',description:'Custom effect configured in Catalog.',battle:{selection_enabled:true,effects:[{type:'damage_player'}]}});
 assert.equal(unsupported.battle.enabled,false);assert.equal(unsupported.battle.selection_enabled,true);assert.deepEqual(unsupported.battle.effects,[]);
 assert.equal(withBattleRule({name:'Heal',description:'Pulihkan 19 HP pada 1 ally. CD 3.',battle:{selection_enabled:false}}).battle.selection_enabled,false);
});
