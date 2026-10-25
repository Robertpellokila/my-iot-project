// A turn number orders selections across devices without depending on their clocks.
export function normalizeSpotlight(value) {
  if (!value || value.cardId == null) return null;
  const cardId = String(value.cardId).trim();
  const turn = Number(value.turn);
  const at = Number(value.at);
  if (!cardId || cardId.length > 128 || !Number.isSafeInteger(turn) || turn < 0 || !Number.isFinite(at) || at <= 0) return null;
  return { cardId, turn, at };
}

export function newerSpotlight(next, previous) {
  return Boolean(next && (!previous || next.turn > previous.turn || (next.turn === previous.turn && next.at > previous.at)));
}

export function spotlightTurn(battle) {
  if (battle?.turn_index != null && Number.isSafeInteger(Number(battle.turn_index))) return Math.max(0, Number(battle.turn_index));
  const round = Math.max(1, Number(battle?.round ?? 1) || 1);
  return (round - 1) * 2 + (battle?.current_turn === (battle?.starting_player ?? 'p1') ? 1 : 2);
}

export function clonePlayerFocus(value) {
  return { selected: normalizeSpotlight(value?.selected), target: normalizeSpotlight(value?.target) };
}
