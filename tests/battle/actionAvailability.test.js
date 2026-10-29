import { test } from 'node:test';
import assert from 'node:assert/strict';
import { availableSkillTargets, skillFieldBlockReason, cardActionStatusReason } from '../../src/lib/battle/actionAvailability.js';
const source = { id: 's', zone: 'active', current_hp: 100 };
const base = () => ({ source, active: [source], enemyActive: [{ id: 'e', current_hp: 100 }], bench: [], graveyard: [], statuses: [] });
const rule = (type, target) => ({ target_spec: { type: target }, effects: [{ type: 'studio_skill', program: { operations: [{ type }], choices: [] } }] });
test('Necro readiness requires an eligible graveyard target and room on Bench', () => {
  const skill = rule('revive', 'ally_graveyard'), field = base();
  assert.match(skillFieldBlockReason(skill, field), /Graveyard/);
  field.graveyard = [{ id: 'd', zone: 'graveyard', current_hp: 0 }, { id: 'f', is_fusion_result: true }, { id: 'used', fusion_consumed: true }];
  assert.deepEqual(availableSkillTargets(skill, field).map(c => c.id), ['d']);
  assert.equal(skillFieldBlockReason(skill, field), '');field.bench = [{ current_hp: 10 }];field.maxBench = 1;
  assert.match(skillFieldBlockReason(skill, field), /Bench penuh/);
});
test('attack limits, revival lock and mutual exclusion prevent false ready states', () => {
  const skill = rule('attack', 'enemy_active');skill.effects[0].program.attacks = true;
  assert.match(skillFieldBlockReason(skill, { ...base(), attackUsed: true }), /Kesempatan serang/);
  assert.match(skillFieldBlockReason(skill, { ...base(), statuses: [{ target_card_id: 's', status_key: 'studio_revival_lock' }] }), /giliran berikutnya/);
  const exclusive = rule('shield', 'self_card');exclusive.effects[0].program.exclusive = true;exclusive.last_used_round = 2;exclusive.last_used_turn_player = 'p1';
  assert.match(skillFieldBlockReason(skill, { ...base(), skills: [exclusive], round: 2, player: 'p1' }), /bersamaan/);
});
test('Switch needs a living unlocked Bench card and a movable Active target', () => {
  const skill = rule('switch', 'ally_active');skill.target_spec.needs_bench = true;
  assert.match(skillFieldBlockReason(skill, base()), /Bench/);
  const field = { ...base(), bench: [{ id: 'b', current_hp: 10 }], statuses: [{ target_card_id: 'b', status_key: 'root' }] };
  assert.match(skillFieldBlockReason(skill, field), /Bench/);field.statuses = [];assert.equal(skillFieldBlockReason(skill, field), '');
  field.statuses = [{ target_card_id: 's', status_key: 'root' }];assert.equal(availableSkillTargets(skill, field).length, 0);
});
test('status locks apply only to the affected card and blocked action', () => {
  const statuses = [{ target_card_id: 's', status_key: 'freeze' }];
  assert.match(cardActionStatusReason(source, statuses, 'attack'), /FREEZE/);
  assert.equal(cardActionStatusReason(source, statuses, 'summon'), '');
  assert.equal(cardActionStatusReason({ id: 'other' }, statuses, 'attack'), '');
});
test('a legacy card effect with a player target cannot show ready', () => {
  const skill = { target_spec: { type: 'enemy_player' }, effects: [{ type: 'damage_card', target: 'target_card' }] };
  assert.match(skillFieldBlockReason(skill, base()), /Target skill belum sesuai/);
  skill.target_spec.type = 'enemy_active';
  assert.equal(skillFieldBlockReason(skill, base()), '');
});
