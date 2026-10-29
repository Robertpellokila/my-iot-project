import { spotlightTurn } from './battleSpotlight.js';
import { battleCardId } from './publicBattleActivity.js';

export function publicTurnSide(battle) {
  return { p1: 'p1', player1: 'p1', player_1: 'p1', p2: 'p2', player2: 'p2', player_2: 'p2' }[battle?.current_turn] ?? null;
}

// Read both the source and target from the current player's verified row. A
// shared "latest selection" can otherwise let the off-turn player steer the TV.
export function publicFeaturedCard(battle, states, side, cards, combat = {}) {
  const find = id => id == null ? null : cards.find(card => String(battleCardId(card)) === String(id));
  if (combat.active) {
    const card = find(combat.sourcePlayer === side ? combat.attackerCardId : combat.targetPlayer === side ? combat.targetCardId : null);
    if (card) return card;
  }
  const current = publicTurnSide(battle);
  if (battle?.status === 'battle' && !battle.winner && !battle.question_active && current) {
    const focus = states?.[current]?.focus?.[current === side ? 'selected' : 'target'];
    if (focus?.turn === spotlightTurn(battle)) {
      const card = find(focus.cardId);
      if (card) return card;
    }
  }
  return cards[0] ?? null;
}

export function publicTurnSeconds(battle, now = Date.now()) {
  if (battle?.status !== 'battle' || battle.winner || battle.question_active) return null;
  const deadline = Date.parse(battle.turn_deadline_at ?? '');
  const clock = battle.teacher_paused ? Date.parse(battle.teacher_paused_at ?? '') : now;
  return Number.isFinite(deadline) && Number.isFinite(clock) ? Math.max(0, Math.ceil((deadline - clock) / 1000)) : null;
}
