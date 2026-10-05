/** Canonical elemental status names shared by player and public battle screens. */
export const ELEMENTAL_STATUS_RULES = Object.freeze({
  fire: Object.freeze({ statusKey: "elemental_burn", label: "Burn", icon: "🔥", rounds: 1 }),
  water: Object.freeze({ statusKey: "freeze", label: "Freeze", icon: "🧊", rounds: 1 }),
  ice: Object.freeze({ statusKey: "freeze", label: "Freeze", icon: "🧊", rounds: 1 }),
  electric: Object.freeze({ statusKey: "stun", label: "Stun", icon: "⚡", rounds: 1 }),
  grass: Object.freeze({ statusKey: "poison", label: "Poison", icon: "☠", rounds: 1 }),
  dark: Object.freeze({ statusKey: "curse", label: "Curse", icon: "🌑", rounds: 1 }),
});

const STATUS_ALIASES = Object.freeze({
  water_freeze: "freeze",
  ice_freeze: "freeze",
  frozen: "freeze",
  electric_stun: "stun",
  paralysis: "stun",
  grass_poison: "poison",
  dark_curse: "curse",
  fire_burn: "elemental_burn",
});

export const normalizeBattleStatusKey = (effect) => {
  const raw = String(effect?.status_key ?? effect?.key ?? effect?.type ?? "status")
    .trim()
    .toLowerCase();
  return STATUS_ALIASES[raw] ?? raw;
};
