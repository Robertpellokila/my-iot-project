/**
 * Phase 3D.23 — client-side VISUAL registry only.
 * Damage, duration, stacking and server events still belong to Supabase.
 * Register a new dedicated component here; PlayerBattle and PublicActiveField
 * never need to import another elemental animation.
 */
import BurnFlames from "./BurnFlames.vue";
import ClassicEffect from "./ClassicEffect.vue";

// `code` is a visual family, not the server status_key. Multiple server keys
// may share ONE animation (e.g. Scorch Mark burn + Fire elemental burn).
export const EFFECT_REGISTRY = Object.freeze({
  fusion:  { component: ClassicEffect, kind: "fusion",  layer: 1, aliases: ["fusion_identity", "fusion"] },
  necro:   { component: ClassicEffect, kind: "necro",   layer: 2, aliases: ["necro_identity", "necro"] },
  burn:    { component: BurnFlames,   kind: "burn",    layer: 4, visualOnly: true, aliases: ["burn", "elemental_burn"] },
  poison:  { component: ClassicEffect, kind: "poison",  layer: 3, aliases: ["poison"] },
  freeze:  { component: ClassicEffect, kind: "freeze",  layer: 5, aliases: ["freeze", "frozen", "water_freeze", "ice_freeze"] },
  stun:    { component: ClassicEffect, kind: "stun",    layer: 6, aliases: ["stun", "electric_stun", "paralysis"] },
  curse:   { component: ClassicEffect, kind: "curse",   layer: 6, aliases: ["curse", "dark_curse"] },
  grass:   { component: ClassicEffect, kind: "poison",  layer: 3, aliases: ["grass_poison"] },
  defense: { component: ClassicEffect, kind: "defense", layer: 7, aliases: ["defense"] },
  shield:  { component: ClassicEffect, kind: "shield",  layer: 8, aliases: ["shield", "water_shield", "synergy_shield"] },
});

const ALIAS_TO_EFFECT = Object.fromEntries(
  Object.entries(EFFECT_REGISTRY).flatMap(([name, config]) =>
    config.aliases.map((alias) => [alias, name]),
  ),
);

const validStatusKey = (status) => String(
  status?.status_key ?? status?.key ?? status?.type ?? "",
).trim().toLowerCase();

/** A single registry flag controls badge visibility across both screens. */
export function isVisualOnlyStatus(status) {
  const family = ALIAS_TO_EFFECT[validStatusKey(status)];
  return Boolean(family && EFFECT_REGISTRY[family].visualOnly);
}

/**
 * Accepts normalized or raw RPC status objects. Doesn't create statuses on
 * the basis of element alone. Ignores server-inactive rows. One animation
 * per visual family; a target with both burn types doesn't render twice.
 */
export function resolveCardEffectLayers(statuses = []) {
  if (!Array.isArray(statuses)) return [];
  const byFamily = new Map();
  for (const status of statuses) {
    if (!status || status.active === false) continue;
    const family = ALIAS_TO_EFFECT[validStatusKey(status)];
    if (!family) continue; // Other statuses can keep their badge until a visual is registered.
    const config = EFFECT_REGISTRY[family];
    const stacks = Math.max(1, Number(status.stacks) || 1);
    const current = byFamily.get(family);
    if (!current || stacks > current.stacks) {
      byFamily.set(family, {
        id: family,
        component: config.component,
        kind: config.kind,
        layer: config.layer,
        stacks,
        status,
        // Avoid forwarding unknown attributes to BurnFlames' DOM root.
        props: config.component === ClassicEffect ? { kind: config.kind } : {},
      });
    }
  }
  return [...byFamily.values()].sort((a, b) => a.layer - b.layer);
}
