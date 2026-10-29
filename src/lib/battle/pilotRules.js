// Mirrors migration 052. Server validates again before spending resources.
export const RETREAT_LOCK = 'Sudah melakukan aksi ofensif. Bisa mundur atau menjadi bahan Fusion pada giliranmu berikutnya.';
export const ATTACK_LOCK = 'Kesempatan serang kartu ini sudah habis. Attack, skill damage, Combo, Ultimate, dan Synergy damage berbagi 1 kesempatan per giliran.';
export const FUSION_LOCK = 'Fusion baru bisa menyerang atau memberi debuff pada giliranmu berikutnya. Skill bantuan tetap boleh digunakan.';
export const FUSION_CAP = 'Maksimal 1 kartu Fusion di Active. Pindahkan Fusion yang lama ke Bench terlebih dahulu jika sudah boleh mundur.';
export const isFusionCard = card => Boolean(card?.is_fusion_result || card?.origin_type === 'fusion' || card?.card_kind === 'fusion' || card?.fusion_recipe_id);
export const revivalCardReason = card => card?.fusion_consumed || card?.consumed_by_fusion_id || card?.field_fusion_used || card?.fieldFusionUsed || card?.necro_consumed || card?.necroConsumed
  ? 'Bahan Fusion • tidak bisa dibangkitkan' : isFusionCard(card) ? 'Kartu Fusion • tidak bisa dibangkitkan' : '';
const applies = battle => battle?.ruleset === 'tcg_v1';
const ownerTurn = (card, battle) => Math.max(1, Number(battle?.[card?.player === 'p2' ? 'player2_owner_turn' : 'player1_owner_turn']) || 1);
const currentMark = (card, battle, key) => card?.battle_metadata?.[key] != null && Number(card.battle_metadata[key]) >= ownerTurn(card, battle);
const currentAttack = (card, battle) => Number(card?.attack_turn_index ?? -1) === Number(battle?.turn_index ?? 1) && Number(card?.attacks_this_turn ?? 0) > 0;
export const pilotAttackUsed = (card, battle) => applies(battle) && (currentMark(card, battle, 'pilot_attack_owner_turn') || currentAttack(card, battle));
export const pilotRetreatReason = (card, battle) => applies(battle) && (currentMark(card, battle, 'pilot_offense_owner_turn') || currentAttack(card, battle)) ? RETREAT_LOCK : '';
export function pilotOffenseReason(card, battle, attack = true) {
  if (!applies(battle) || !card) return '';
  if (currentMark(card, battle, 'pilot_fusion_owner_turn')) return FUSION_LOCK;
  return attack && pilotAttackUsed(card, battle) ? ATTACK_LOCK : '';
}
export const fusionEntryReason = (card, active, leavingId) => isFusionCard(card) && active.some(c => c.id !== leavingId && c.id !== card.id && isFusionCard(c) && Number(c.current_hp ?? c.hp ?? 0) > 0) ? FUSION_CAP : '';
export function skillOffenseFlags(skill, option) {
  let attack = false, offensive = false;
  for (const effect of skill?.effects ?? []) {
    if (effect.type === 'studio_skill') {
      const program = effect.program ?? {};
      const ops = program.choices?.length ? program.choices.find(c => c.id === option)?.operations ?? [] : program.operations ?? [];
      for (const op of ops) {
        attack ||= op.type === 'attack';
        offensive ||= ['attack','burn','root','attack_debuff','defense_debuff','silence_slot2','mark','attack_reduction'].includes(op.type);
      }
    } else {
      attack ||= ['damage_card','damage_player'].includes(effect.type);
      offensive ||= ['damage_card','damage_player'].includes(effect.type) || (['add_status','remove_status','move_zone','set_card_exhausted'].includes(effect.type) && (['enemy','opponent'].includes(effect.owner) || ['enemy_player','enemy_active','all_enemy_active'].includes(effect.target)));
    }
  }
  return { attack, offensive };
}
