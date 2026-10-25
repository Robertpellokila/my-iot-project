const text = value => typeof value === 'string' ? value.trim() : '';
const payloadOf = event => {
  if (event?.payload && typeof event.payload === 'object') return event.payload;
  try { return JSON.parse(event?.payload || '{}'); } catch { return {}; }
};
export const publicActionTypes = new Set([
  'card_move', 'bench', 'swap', 'return_from_bench', 'summon', 'attack', 'defense', 'heal',
  'ultimate', 'synergy', 'special_skill', 'special_effect', 'fusion', 'turn_end', 'turn_ended',
  'turn_changed', 'turn_timeout', 'action_request', 'card_destroyed', 'graveyard', 'win',
  'question_winner', 'bonus_skill_used',
]);

export function publicActionCardIds(event) {
  const p = payloadOf(event) ?? {};
  return [...new Set([event.card_id, p.attacker_card_id, p.target_card_id, p.battle_card_id]
    .filter(id => id != null && id !== '').map(String))];
}

export function describePublicAction(event, battle, cards = []) {
  const p = payloadOf(event) ?? {};
  const type = String(event.type ?? '').toLowerCase();
  if (!publicActionTypes.has(type)) return null;
  const playerName = side => side === 'p1' ? battle?.player1_name || 'Player 1'
    : side === 'p2' ? battle?.player2_name || 'Player 2' : 'Arena';
  const player = event.source_player ?? p.player ?? p.winner_player ?? null;
  const opposite = event.target_player ?? (player === 'p1' ? 'p2' : 'p1');
  const name = id => cards.find(card => String(card.battleId ?? card.battle_id ?? card.id) === String(id))?.name;
  const source = name(p.attacker_card_id ?? event.card_id ?? p.battle_card_id) || text(p.card_name) || text(p.attacker_name) || 'Kartu';
  const target = name(p.target_card_id) || text(p.target_card_name) || 'kartu lawan';
  const message = text(p.message);
  const action = text(p.action).toLowerCase();
  const move = action || type;
  let detail;
  if (type === 'card_move' || ['bench', 'swap', 'return_from_bench'].includes(type)) {
    if (move === 'move_to_bench' || (type === 'bench' && p.to_zone !== 'active')) {
      detail = ['⇣', 'KE BENCH', message || `${source} dipindahkan ke Bench.`];
    } else if (move === 'return_from_bench' || p.to_zone === 'active') {
      detail = ['⇡', 'KEMBALI KE ACTIVE', message || `${source} kembali ke Active.`];
    } else {
      detail = ['⇄', 'TUKAR POSISI', message || `${source} bertukar posisi antara Active dan Bench.`];
    }
  } else if (type === 'attack') {
    const direct = p.attack_mode === 'direct' || (!p.target_card_id && p.attack_mode === 'active_combo');
    const damage = Number(p.effective_damage ?? p.damage);
    const result = Number.isFinite(damage) ? ` · ${Math.max(0, damage)} damage` : '';
    const combo = ['active_combo', 'combo'].includes(p.attack_mode);
    detail = ['⚔', combo ? 'COMBO ATTACK' : 'SERANGAN', `${source} menyerang ${direct ? playerName(opposite) : target}${result}.`];
  } else if (type === 'summon') {
    const zone = p.zone ?? p.to_zone ?? p.result?.zone;
    detail = ['＋', 'SUMMON', `${source} masuk ${zone === 'bench' ? 'Bench' : zone === 'active' ? 'Active' : 'arena'}.`];
  } else if (type === 'action_request') {
    if (action === 'cancel_summon') detail = ['↶','SUMMON DIBATALKAN',message || 'Scan Summon dibatalkan sebelum kartu terbaca.'];
    else if (action === 'summon') detail = ['⌁', 'MENYIAPKAN SUMMON', 'Menunggu scan kartu RFID.'];
    else return null;
  } else if (['turn_end', 'turn_ended', 'turn_timeout'].includes(type)) {
    detail = ['›', type === 'turn_timeout' ? 'WAKTU HABIS' : 'GILIRAN SELESAI', `Giliran berikutnya: ${playerName(p.next_turn ?? opposite)}.`];
  } else if (type === 'turn_changed') {
    detail = ['›', 'GILIRAN BARU', `${playerName(p.next_turn ?? p.current_turn ?? battle?.current_turn)} mulai bermain.`];
  } else if (type === 'fusion') {
    detail = ['✧', 'FUSION', `${text(p.recipe_name) || 'Fusion berhasil'} → ${text(p.result?.name) || 'kartu Fusion'}.`];
  } else if (['card_destroyed', 'graveyard'].includes(type)) {
    detail = ['◇', 'GRAVEYARD', `${name(p.target_card_id ?? event.card_id) || source} masuk Graveyard.`];
  } else if (type === 'special_effect') {
    const effect = p.effect_type ?? p.effect?.type;
    if (effect === 'revive') detail = ['✦', 'REVIVE', `${name(p.target_card_id) || source} kembali ke arena.`];
    else if (effect === 'move_zone') detail = ['⇄', 'PINDAH ZONA', `${name(p.target_card_id) || source} berpindah ke ${p.result?.to_zone ?? p.to_zone ?? 'zona baru'}.`];
    else return null;
  } else if (type === 'win') {
    const winner = p.winner ?? battle?.winner ?? player;
    detail = ['★', 'HASIL BATTLE', winner === 'draw' ? 'Pertandingan berakhir seri.' : `${playerName(winner)} memenangkan pertandingan!`];
  } else {
    const labels = {
      defense: ['♢', 'BERTAHAN', `${source} menggunakan pertahanan.`],
      heal: ['＋', 'HEAL', `${source} menggunakan pemulihan HP.`],
      ultimate: ['ϟ', 'ULTIMATE', `${source} mengaktifkan Ultimate.`],
      synergy: ['✦', 'SYNERGY', `${source} mengaktifkan Synergy.`],
      special_skill: ['✦', 'SPECIAL SKILL', `${source} menggunakan ${text(p.skill_name) || 'Special Skill'}.`],
      bonus_skill_used: ['✦', 'BONUS SKILL', `Menggunakan ${text(p.skill_name) || text(p.skill_type) || 'bonus skill'}.`],
      question_winner: ['✓', 'JAWABAN BENAR', 'Berhasil menjawab pertanyaan.'],
    };
    const fallback = labels[type];
    if (!fallback) return null;
    detail = [fallback[0], fallback[1], message || fallback[2]];
  }
  return { icon: detail[0], title: detail[1], message: detail[2], player, playerName: playerName(player) };
}
