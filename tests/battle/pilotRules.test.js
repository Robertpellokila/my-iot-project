import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pilotAttackUsed, pilotOffenseReason, pilotRetreatReason, fusionEntryReason, skillOffenseFlags, revivalCardReason } from '../../src/lib/battle/pilotRules.js';
import { skillFieldBlockReason, availableSkillTargets, cardActionStatusReason } from '../../src/lib/battle/actionAvailability.js';
const battle = { ruleset: 'tcg_v1', current_turn: 'p1', player1_owner_turn: 3, player2_owner_turn: 2, turn_index: 5 };
const source = { id: 'src', player: 'p1', zone: 'active', current_hp: 100, battle_metadata: {} };
const skill = (type, target = 'enemy_active') => ({ target_spec: { type: target }, effects: [{ type: 'studio_skill', program: { target, operations: [{ type }] } }] });
const field = (card = source) => ({ source: card, active: [card], enemyActive: [{ id: 'enemy', zone: 'active', current_hp: 100 }], statuses: [], battle });
test('commitment persists through the opponent turn and expires only at the owner next turn', () => {
  for (const player of ['p1','p2']) {
    const clock = battle[player === 'p1' ? 'player1_owner_turn' : 'player2_owner_turn'];
    const card = { ...source, player, battle_metadata: { pilot_offense_owner_turn: clock, pilot_attack_owner_turn: clock } };
    assert.ok(pilotRetreatReason(card, battle));assert.ok(pilotAttackUsed(card, battle));
    assert.ok(pilotRetreatReason(card, { ...battle, current_turn: player === 'p1' ? 'p2' : 'p1', turn_index: 6 }));
    const next = { ...battle, [player === 'p1' ? 'player1_owner_turn' : 'player2_owner_turn']: clock + 1, turn_index: 7 };
    assert.equal(pilotRetreatReason(card, next), '');assert.equal(pilotOffenseReason(card, next), '');
  }
});
test('existing attack counters work during migration and classic behavior stays separate', () => {
  const card = { ...source, attack_turn_index: 5, attacks_this_turn: 1 };
  assert.ok(pilotRetreatReason(card, battle));assert.ok(pilotOffenseReason(card, battle));
  assert.equal(pilotOffenseReason(card, { ...battle, ruleset: 'classic' }), '');
});
test('damage spends attack; non-damage debuff locks retreat while utility remains available', () => {
  const card = { ...source, battle_metadata: { pilot_offense_owner_turn: 3 } };
  assert.equal(pilotOffenseReason(card, battle), '');assert.ok(pilotRetreatReason(card, battle));
  card.battle_metadata.pilot_attack_owner_turn = 3;
  assert.match(skillFieldBlockReason(skill('attack'), field(card)), /Kesempatan serang/);
  assert.equal(skillFieldBlockReason(skill('heal', 'self_card'), field(card)), '');
  assert.equal(skillFieldBlockReason(skill('shield', 'self_card'), field(card)), '');
  assert.equal(skillFieldBlockReason(skill('root'), field(card)), '');
});
test('new Fusion disallows offense but permits utility and heals in a choice skill', () => {
  const card = { ...source, card_kind: 'fusion', battle_metadata: { pilot_fusion_owner_turn: 3 } };
  for (const type of ['attack','root','burn','mark','silence_slot2']) assert.match(skillFieldBlockReason(skill(type), field(card)), /Fusion baru/);
  assert.equal(skillFieldBlockReason(skill('shield', 'self_card'), field(card)), '');
  const choice = { target_spec: { type: 'self_card' }, effects: [{ type: 'studio_skill', program: { choices: [{ id: 'hit', operations: [{ type: 'attack' }] }, { id: 'heal', operations: [{ type: 'heal' }] }] } }] };
  assert.equal(skillFieldBlockReason(choice, field(card)), '');
  assert.equal(skillFieldBlockReason(choice, { ...field(card), option: 'heal' }), '');
  assert.match(skillFieldBlockReason(choice, { ...field(card), option: 'hit' }), /Fusion baru/);
});
test('ally Switch filters committed targets and obeys the Fusion cap', () => {
  const locked = { ...source, battle_metadata: { pilot_offense_owner_turn: 3 } };
  const swap = { ...skill('switch', 'ally_active'), target_spec: { type: 'ally_active', needs_bench: true } };
  const bench = { id: 'bench', zone: 'bench', current_hp: 100 };
  assert.deepEqual(availableSkillTargets(swap, { ...field(locked), bench: [bench] }), []);
  const fusion = { ...source, id: 'fusion', card_kind: 'fusion' };
  const f = { ...field(), active: [source, fusion], bench: [{ ...bench, card_kind: 'fusion' }] };
  assert.deepEqual(availableSkillTargets(swap, f).map(c => c.id), ['fusion']);
  assert.ok(fusionEntryReason(f.bench[0], f.active));assert.equal(fusionEntryReason(f.bench[0], f.active, 'fusion'), '');
});
test('revival cannot reuse Fusion materials and revival lock also covers Synergy', () => {
  for (const card of [{ fusion_consumed: true }, { field_fusion_used: true }, { consumed_by_fusion_id: 'f' }, { card_kind: 'fusion' }]) assert.ok(revivalCardReason(card));
  assert.equal(revivalCardReason(source), '');
  assert.match(cardActionStatusReason(source, [{ target_card_id: 'src', status_key: 'studio_revival_lock' }], 'synergy', battle), /dibangkitkan/);
});
test('legacy damage and debuff effects are classified without changing their definitions', () => {
  assert.deepEqual(skillOffenseFlags({ effects: [{ type: 'damage_player' }] }), { attack: true, offensive: true });
  assert.deepEqual(skillOffenseFlags({ effects: [{ type: 'add_status', owner: 'enemy' }] }), { attack: false, offensive: true });
  assert.deepEqual(skillOffenseFlags({ effects: [{ type: 'heal_player' }] }), { attack: false, offensive: false });
});
