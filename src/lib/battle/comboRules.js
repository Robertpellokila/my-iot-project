import {getTcgComboTypeKey, normalizeTcgType, formatTcgType} from '../../utils/tcgTypes.js';
export const comboCode = value => String(value ?? '').trim().toUpperCase().replace(/_STUDIO_[A-F0-9]{32}$/, '').replaceAll('-', '_');
const tagKey = value => String(value ?? '').trim().toLowerCase();
const specificity = rule => (rule.members ?? []).reduce((score, member) => score + (member.card_code ? 2 : 0) + (member.tag ? 1 : 0), rule.shared_tag ? 1 : 0);
export function comboMembersMatch(requirements = [], cards = []) {
  if (!requirements.length) return true;
  const [requirement, ...rest] = requirements;
  return cards.some((card, index) => (!requirement.type || normalizeTcgType(card.element) === requirement.type)
    && (!requirement.card_code || comboCode(card.card_code) === comboCode(requirement.card_code))
    && (!requirement.tag || (card.tags ?? []).some(tag => tagKey(tag) === tagKey(requirement.tag)))
    && comboMembersMatch(rest, cards.filter((_, i) => i !== index)));
}
export function findComboRule(rules, cards) {
  const key = getTcgComboTypeKey(cards.map(card => card.element));
  if (!key || cards.length < 2 || cards.length > 4) return null;
  const kind = cards.length === 4 ? ['formation', 'ultimate'] : cards.length === 3 ? ['triple']
    : [normalizeTcgType(cards[0].element) === normalizeTcgType(cards[1].element) ? 'same' : 'pair'];
  return [...rules].sort((a,b) => (b.priority ?? 0) - (a.priority ?? 0) || specificity(b) - specificity(a) || Number(a.id) - Number(b.id)).find(rule => rule.enabled !== false
    && kind.includes(rule.rule_kind) && rule.type_keys.join('+') === key && comboMembersMatch(rule.members, cards)
    && (!rule.shared_tag || (cards[0].tags ?? []).some(tag => tagKey(tag) && !tagKey(tag).startsWith('fusion:') && cards.every(card => (card.tags ?? []).some(t => tagKey(t) === tagKey(tag)))))) ?? null;
}
export function comboCooldown(battle, player) {
  const side = player === 'p2' ? 'player2' : 'player1';
  const last = battle?.[`${side}_combo_last_owner_turn`];
  if (!battle?.combo_policy || last == null) return {reason:'', remaining:0, readyTurn:null};
  const current = Number(battle[`${side}_owner_turn`] ?? 1), readyTurn = Number(last) + 2;
  const remaining = Math.max(0, readyTurn - current);
  return {readyTurn, remaining, reason: !remaining ? '' : current <= Number(last)
    ? 'Jatah Combo giliran ini sudah dipakai. Lewati satu giliranmu; semua jenis Combo berbagi cooldown.'
    : 'Combo cooldown pada giliran ini. Siap pada giliranmu berikutnya.'};
}
export function comboRecipeRequirement(rule) {
  const slots = rule.members?.length ? rule.members.map(member => [formatTcgType(member.type), member.card_code, member.tag && `tag “${member.tag}”`].filter(Boolean).join(' · ')) : rule.type_keys.map(formatTcgType);
  return slots.join(' + ') + (rule.shared_tag ? ' · Semua peserta harus berbagi satu tag (bukan fusion:).' : '');
}
export function comboPower(cards, primaryId, rule) {
  const ordered = [...cards.filter(c => c.id === primaryId), ...cards.filter(c => c.id !== primaryId)];
  return Math.round((ordered.reduce((sum, card, i) => sum + (i === 0 ? Math.max(0, Number(card.attack) || 0) * (rule?.primary_multiplier ?? 1)
    : Math.floor(Math.max(0, Number(card.attack) || 0) * (rule?.assist_multipliers?.[i-1] ?? (rule ? .6 : .5)))), 0) + (rule?.bonus_damage ?? 0)) * (rule?.damage_multiplier ?? 1));
}
