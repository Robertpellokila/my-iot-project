export const isSkillImage = value => /^(https?:\/\/|\/|data:image\/(png|jpeg|webp);base64,)/i.test(String(value ?? ''));
export function skillCooldown(skill, battle, player) {
  const owner = Object.hasOwn(skill?.limits ?? {}, 'cooldown_turns');
  const duration = Math.max(0, Number(owner ? skill.limits.cooldown_turns : skill?.limits?.cooldown_rounds ?? skill?.limits?.cooldown ?? 0) || 0);
  const until = Number(owner ? skill?.cooldown_until_owner_turn : skill?.cooldown_until_round);
  const clock = Number(owner ? battle?.[player === 'p2' ? 'player2_owner_turn' : 'player1_owner_turn'] : battle?.round) || 1;
  const remaining = until > 0 ? Math.max(0, until - clock + 1) : 0;
  return { duration, remaining, unit: owner ? 'giliranmu' : 'round', ready: !remaining };
}
export function skillApCost(skill, fallback = 1) {
  const raw = skill?.limits?.action_points;
  const value = Number(raw);
  return raw !== null && raw !== undefined && Number.isInteger(value) && value >= 0 && value <= 10 ? value : fallback;
}
