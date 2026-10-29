import test from 'node:test';
import assert from 'node:assert/strict';
import { PILOT } from '../../src/lib/card-generator/cardSchema.js';
import { compileStudioSkill } from '../../src/lib/card-generator/cardSkillBattleRules.js';
import { RULE_TEMPLATES, skillRuleIssues, applyRuleTemplate, auditSkillCatalog } from '../../src/lib/battle/skillEditor.js';

const activeRule = skill => ({ ...skill, ...compileStudioSkill(skill), skill_type: 'active', is_active: true, catalog_status: 'active' });
test('all 84 pilot slots and all editor templates have coherent executable configuration', () => {
  for (const card of PILOT.cards) for (const skill of card.skills) assert.deepEqual(skillRuleIssues(activeRule(skill)), [], `${card.card_code} ${skill.name}`);
  for (const template of RULE_TEMPLATES) assert.deepEqual(skillRuleIssues(activeRule(template)), []);
});
test('Necro template restores complete rules without replacing short printed text or identity', () => {
  const before = { id: 'necro', code: 'studio_necro', name: 'Necro Recall', description: 'Bangkitkan Base ke Bench, 40% HP.', icon: '/images/icon.png', effects: [], catalog_status: 'draft' };
  const result = applyRuleTemplate(before, RULE_TEMPLATES.find(t => t.name === 'Necro Recall'));
  assert.deepEqual(skillRuleIssues(result), []);
  for (const key of Object.keys(before).filter(key => key !== 'effects')) assert.deepEqual(result[key], before[key]);
  assert.equal(result.target_spec.type, 'ally_graveyard');
  assert.deepEqual(result.effects[0].program.operations, [{ type: 'revive', amount: .4 }]);
  assert.equal(result.limits.action_points, 2); assert.equal(result.limits.once_per_battle, true);
  assert.deepEqual(before.effects, []);
});
test('rejects malformed and mismatched nested effects, choices, ranges and revive limits', () => {
  const base = activeRule(PILOT.cards[0].skills[0]);
  for (const change of [
    s => s.effects[0].program.operations[0].type = 'unknown',
    s => s.effects[0].program.operations[0].amount = -1,
    s => s.effects[0].program.operations[0].condition = 'unsupported',
    s => s.effects[0].program.operations = [],
    s => s.effects[0].program.attacks = false,
    s => s.target_spec.type = 'self_card',
    s => s.effects[0].program.max_targets = 3,
    s => s.limits.action_points = 0,
    s => s.effects = [{ type: 'invented_effect' }],
    s => s.effects[0].program.choices = [{ id: 'x', label: 'Broken', operations: [] }],
  ]) { const next = structuredClone(base); change(next); assert.ok(skillRuleIssues(next).length); }
  const necro = activeRule(RULE_TEMPLATES.find(t => t.name === 'Necro Recall'));
  necro.limits.once_per_battle = false; assert.ok(skillRuleIssues(necro).some(s => s.includes('Revive')));
});
test('audit includes disabled links, missing second slots, duplicate card names and excludes archived cards', () => {
  const skill = { ...activeRule(PILOT.cards[0].skills[0]), id: 's' };
  const cards = [{ id: 'a', name: 'Same', metadata: { skills: [{}, {}] } }, { id: 'b', name: 'Same' }, { id: 'c', archived_at: '2026-10-26' }];
  const result = auditSkillCatalog(cards, [skill], [{ game_card_id: 'a', special_skill_id: 's', enabled: false }]);
  assert.equal(result.length, 2); assert.equal(result[0].missing, 1); assert.equal(result[0].ready, false);
  assert.ok(result[0].entries[0].issues.some(s => s.includes('nonaktif'))); assert.equal(result[1].missing, 1);
});
test('legacy card effects cannot activate with a player-only target', () => {
  const skill = { name: 'Test damage', description: 'Damage kartu', skill_type: 'active', activation_timing: 'main_phase', cost_spec: { type: 'none' }, target_spec: { type: 'enemy_player' }, effects: [{ type: 'damage_card', target: 'target_card', amount: { mode: 'fixed', value: 50 } }] };
  assert.ok(skillRuleIssues(skill).some(issue => issue.includes('target skill masih pemain')));
  skill.target_spec.type = 'enemy_active';
  assert.deepEqual(skillRuleIssues(skill), []);
});
