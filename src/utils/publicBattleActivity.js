import { spotlightTurn } from './battleSpotlight.js';

export const battleCardId = card => card?.battleId ?? card?.battle_id ?? card?.id ?? null;

// UI presence is transient. Only the player whose turn it is may direct the TV.
// A turn stamp prevents a previously opened pile from resurfacing next round.
export function publicBattleActivity(battle, states, fields) {
  if (!battle || battle.status !== 'battle' || battle.winner || battle.question_active || battle.teacher_paused) return null;
  const side = { player1: 'p1', player_1: 'p1', player2: 'p2', player_2: 'p2' }[battle.current_turn] ?? battle.current_turn;
  if (!['p1', 'p2'].includes(side)) return null;
  const state = states?.[side];
  if (!state) return null;
  const turn = spotlightTurn(battle);
  const playerName = battle[side === 'p1' ? 'player1_name' : 'player2_name'] || (side === 'p1' ? 'Player 1' : 'Player 2');
  const base = { side, playerName, turn };
  if (['bench', 'graveyard'].includes(state.viewerZone) && state.viewerTurn === turn) {
    const cards = fields?.[side]?.[state.viewerZone] ?? [];
    const found = state.viewerCardId == null ? -1 : cards.findIndex(card => String(battleCardId(card)) === String(state.viewerCardId));
    const index = found >= 0 ? found : Math.max(0, Math.min(Math.trunc(Number(state.viewerIndex)) || 0, cards.length - 1));
    const zoneLabel = state.viewerZone === 'bench' ? 'Bench' : 'Graveyard';
    return { ...base, kind: 'viewer', zone: state.viewerZone, zoneLabel, cards, index, card: cards[index] ?? null, message: `Membuka ${zoneLabel}`, cardSide: side };
  }
  const selected = state.focus?.selected;
  const target = state.focus?.target;
  const latest = [selected && { ...selected, kind: 'selected' }, target && { ...target, kind: 'target' }]
    .filter(record => record && record.turn === turn).sort((a, b) => b.at - a.at || (b.kind === 'target' ? 1 : -1))[0];
  if (!latest) return null;
  const cardSide = latest.kind === 'target' ? (side === 'p1' ? 'p2' : 'p1') : side;
  const card = (fields?.[cardSide]?.active ?? []).find(card => String(battleCardId(card)) === String(latest.cardId));
  if (!card) return null;
  return { ...base, kind: latest.kind, card, cardSide, message: latest.kind === 'target' ? 'Memilih target serangan' : 'Memilih kartu Active' };
}
