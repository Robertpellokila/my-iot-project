import { pilotRetreatReason, pilotOffenseReason, skillOffenseFlags, fusionEntryReason, revivalCardReason } from './pilotRules.js';
const idOf = card => card?.id ?? card?.battle_card_id;
const alive = card => Number(card.current_hp ?? card.hp ?? 0) > 0;
const programOf = skill => skill?.effects?.find(effect => effect.type === 'studio_skill')?.program;
const operations = skill => {
  const p = programOf(skill);
  return [...(p?.operations ?? []), ...(p?.choices ?? []).flatMap(choice => choice.operations ?? [])];
};
export function cardActionStatusReason(card, statuses, action, battle) {
  if (!card) return '';
  const applicable = statuses.filter(s => s.active !== false && s.target_card_id === idOf(card));
  for (const status of applicable) {
    const key = status.status_key;
    const defaults = key === 'stun' ? ['attack','defense','ultimate','heal','synergy','special_skill']
      : ['freeze','frozen'].includes(key) ? ['attack','ultimate']
      : key === 'studio_revival_lock' ? ['attack','ultimate','special_skill','combo_attack','synergy']
      : key === 'root' ? ['switch_active','move_to_bench','return_from_bench'] : [];
    const blocked = status.metadata?.blocks_actions ?? defaults;
    if (Array.isArray(blocked) && blocked.includes(action)) return key === 'studio_revival_lock' ? 'Kartu yang dibangkitkan baru bisa beraksi pada giliran berikutnya.' : `${status.metadata?.label || key.toUpperCase()}: aksi ini belum dapat digunakan.`;
  }
  if (['move_to_bench','switch_active','fusion_material'].includes(action)) return pilotRetreatReason(card, battle);
  if (['attack','combo_attack','ultimate'].includes(action)) return pilotOffenseReason(card, battle);
  return '';
}
export function availableSkillTargets(skill, field) {
  const type = skill?.target_spec?.type, p = programOf(skill), ops = operations(skill);
  let targets = type === 'enemy_active' ? field.enemyActive ?? []
    : ['ally_active','any_active'].includes(type) ? field.active ?? []
    : type === 'ally_field' ? [...(field.active ?? []), ...(field.bench ?? [])]
    : type === 'ally_graveyard' ? field.graveyard ?? []
    : ['self','self_card','source_card'].includes(type) ? field.source ? [field.source] : [] : [];
  if (type !== 'ally_graveyard') targets = targets.filter(alive);
  if (p && ops.some(op => op.type === 'revive')) targets = targets.filter(card => !revivalCardReason(card));
  if (skill?.target_spec?.needs_bench) targets = targets.filter(card => !cardActionStatusReason(card, field.statuses ?? [], 'move_to_bench', field.battle)
    && (field.bench ?? []).some(bench => alive(bench) && !bench.exhausted && !cardActionStatusReason(bench, field.statuses ?? [], 'return_from_bench', field.battle)
      && (field.battle?.ruleset !== 'tcg_v1' || !fusionEntryReason(bench, field.active ?? [], idOf(card)))));
  return targets;
}
export function skillFieldBlockReason(skill, field) {
  const source = field.source;
  if (!source || source.zone !== 'active' || !alive(source)) return 'Pilih kartu Active yang masih memiliki HP.';
  const blocked = cardActionStatusReason(source, field.statuses ?? [], 'special_skill', field.battle);
  if (blocked) return blocked;
  const p = programOf(skill), spec = skill?.target_spec ?? {};
  const branchReason = option => {
    const flags = skillOffenseFlags(skill, option);
    return flags.offensive ? pilotOffenseReason(source, field.battle, flags.attack)
      || (flags.attack ? cardActionStatusReason(source, field.statuses ?? [], 'attack', field.battle) : '') : '';
  };
  const offenseReason = p?.choices?.length && !field.option
    ? p.choices.every(choice => branchReason(choice.id)) ? branchReason(p.choices[0].id) : ''
    : branchReason(field.option);
  if (offenseReason) return offenseReason;
  if (['self_player','enemy_player'].includes(spec.type) && skill.effects?.some(effect => ['target_card','selected_graveyard_card'].includes(effect.target))) return 'Target skill belum sesuai dengan efeknya. Minta guru memeriksa aturan skill.';
  if ((skillOffenseFlags(skill, field.option).attack || (p?.attacks && !p?.choices?.length)) && field.attackUsed) return 'Kesempatan serang kartu ini sudah habis pada giliran ini.';
  if (field.skills?.some(row => programOf(row)?.exclusive) && field.skills.some(row => row.last_used_round === field.round && row.last_used_turn_player === field.player)) return 'Skill pada kartu ini tidak dapat dipakai bersamaan pada giliran yang sama.';
  if (spec.needs_bench && !(field.bench ?? []).some(card => alive(card) && !card.exhausted && !cardActionStatusReason(card, field.statuses ?? [], 'return_from_bench', field.battle))) return 'Perlu kartu Bench yang siap untuk ditukar.';
  if (p && operations(skill).some(op => op.type === 'revive') && (field.bench ?? []).filter(alive).length >= (field.maxBench ?? 4)) return 'Bench penuh. Kosongkan satu tempat sebelum membangkitkan kartu.';
  if (['enemy_active','ally_active','any_active','ally_field','ally_graveyard','self','self_card','source_card'].includes(spec.type) && !availableSkillTargets(skill, field).length) return spec.type === 'ally_graveyard' ? 'Belum ada kartu yang dapat dibangkitkan di Graveyard.' : 'Belum ada target yang sesuai untuk skill ini.';
  return '';
}
