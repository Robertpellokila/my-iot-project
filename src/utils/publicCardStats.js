const number = (...values) => {
  for (const value of values) {
    if (value == null || value === '') continue;
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.max(0, parsed);
  }
  return null;
};

// Read the live battle row. Damage multipliers are separate effects, not ATK/DEF.
export function publicCardStats(card) {
  return {
    attack: number(card?.current_attack, card?.attack, card?.base_attack),
    defense: number(card?.current_defense, card?.defense, card?.base_defense),
    hp: number(card?.current_hp, card?.currentHp, card?.hp),
    maxHp: number(card?.base_hp, card?.baseHp, card?.max_hp, card?.hp),
  };
}
