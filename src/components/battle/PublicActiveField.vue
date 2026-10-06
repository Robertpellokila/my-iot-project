<script setup>
import {
  computed,
  nextTick,
  onMounted,
  onUnmounted,
  onUpdated,
  ref,
} from "vue";
import BattleCard from "./BattleCard.vue";
import CardStatusVfx from "./CardStatusVfx.vue";
import { normalizeBattleStatusKey } from "../../composables/battle/elementalStatus.js";
const props = defineProps({
  battle: {
    type: Object,
    required: true,
  },
  player1Active: {
    type: Array,
    default: () => [],
  },
  player2Active: {
    type: Array,
    default: () => [],
  },
  player1BenchCount: {
    type: Number,
    default: 0,
  },
  player2BenchCount: {
    type: Number,
    default: 0,
  },
  statusEffects: {

    type: Array,

    default: () => [],

  },



  combatFx: {
    type: Object,
    default: () => ({
      active: false,
      attackMode: null,
      phase: "idle",
      sourcePlayer: null,
      targetPlayer: null,
      attackerCardId: null,
      targetCardId: null,
      destroyed: false,
      powerStrikeApplied: false,
      attackDebuffApplied: false,
      attackDebuffPercent: 0,
      defenseApplied: false,
      waterShieldApplied: false,
      waterShieldPercent: 0,
    }),
  },
});
/* =========================================================
   HELPERS
========================================================= */
const getCardId = (card) =>
  card?.battleId ??
  card?.battle_id ??
  card?.id ??
  null;
const clampRatio = (value) =>
  Math.max(
    0,
    Math.min(
      1,
      Number(value) || 0,
    ),
  );
const ratioPercent = (value) =>
  Math.round(
    clampRatio(value) * 100,
  );
/* =========================================================
   DOM REFERENCES
========================================================= */
const p1HudRef = ref(null);
const p2HudRef = ref(null);
const p1AvatarRef = ref(null);
const p2AvatarRef = ref(null);
const p1FieldRef = ref(null);
const p2FieldRef = ref(null);
const p1StageRef = ref(null);
const p2StageRef = ref(null);
const stageMetrics = ref({ width: 0, height: 0 });
let stageObserver = null;
const measureStage = () => {
  const stages = [p1StageRef.value, p2StageRef.value]
    .filter(Boolean).map((el) => el.getBoundingClientRect());
  if (!stages.length) return;
  const width = Math.floor(Math.min(...stages.map((rect) => rect.width)));
  const height = Math.floor(Math.min(...stages.map((rect) => rect.height)));
  if (width > 0 && height > 0 &&
      (width !== stageMetrics.value.width || height !== stageMetrics.value.height)) {
    stageMetrics.value = { width, height };
  }
};
const cardElements =
  new Map();
const cardRectCache =
  new Map();
const rectToPlainObject = (
  rect,
) => {
  if (!rect) {
    return null;
  }
  return {
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
    width: rect.width,
    height: rect.height,
    x: rect.x,
    y: rect.y,
    centerX:
      rect.left +
      rect.width / 2,
    centerY:
      rect.top +
      rect.height / 2,
  };
};
const cardElementKey = (
  player,
  cardId,
) =>
  `${player}:${String(
    cardId,
  )}`;
const registerCardElement = (
  player,
  card,
  element,
) => {
  const cardId =
    getCardId(card);
  if (!cardId) {
    return;
  }
  const key =
    cardElementKey(
      player,
      cardId,
    );
  if (!element) {
    cardElements.delete(
      key,
    );
    return;
  }
  cardElements.set(
    key,
    element,
  );
  const rect =
    element.getBoundingClientRect();
  if (
    rect.width > 0 &&
    rect.height > 0
  ) {
    cardRectCache.set(
      key,
      rectToPlainObject(
        rect,
      ),
    );
  }
};
const captureCardRects =
  () => {
    for (
      const [
        key,
        element,
      ]
      of cardElements.entries()
    ) {
      if (
        !element ||
        typeof element
          .getBoundingClientRect !==
          "function"
      ) {
        continue;
      }
      const rect =
        element.getBoundingClientRect();
      if (
        rect.width <= 0 ||
        rect.height <= 0
      ) {
        continue;
      }
      cardRectCache.set(
        key,
        rectToPlainObject(
          rect,
        ),
      );
    }
  };
const getCardRect = (
  player,
  cardId,
) => {
  if (
    !player ||
    !cardId
  ) {
    return null;
  }
  const key =
    cardElementKey(
      player,
      cardId,
    );
  const element =
    cardElements.get(
      key,
    );
  if (
    element &&
    typeof element
      .getBoundingClientRect ===
      "function"
  ) {
    const rect =
      element.getBoundingClientRect();
    if (
      rect.width > 0 &&
      rect.height > 0
    ) {
      const plain =
        rectToPlainObject(
          rect,
        );
      cardRectCache.set(
        key,
        plain,
      );
      return plain;
    }
  }
  return (
    cardRectCache.get(
      key,
    ) ??
    null
  );
};
const getPlayerTargetRect =
  (player) => {
    const avatar =
      player === "p1"
        ? p1AvatarRef.value
        : p2AvatarRef.value;
    if (
      avatar &&
      typeof avatar
        .getBoundingClientRect ===
        "function"
    ) {
      return rectToPlainObject(
        avatar.getBoundingClientRect(),
      );
    }
    const hud =
      player === "p1"
        ? p1HudRef.value
        : p2HudRef.value;
    if (
      hud &&
      typeof hud
        .getBoundingClientRect ===
        "function"
    ) {
      return rectToPlainObject(
        hud.getBoundingClientRect(),
      );
    }
    return null;
  };
defineExpose({
  captureCardRects,
  getCardRect,
  getPlayerTargetRect,
});
/* =========================================================
   BATTLE CONFIG
========================================================= */
const maxActive =
  computed(() =>
    Math.max(
      1,
      Number(
        props.battle
          ?.max_active ??
          4,
      ) || 4,
    ),
  );
const maxBench =
  computed(() =>
    Math.max(
      0,
      Number(
        props.battle
          ?.max_bench ??
          4,
      ) || 4,
    ),
  );
/* =========================================================
   ACTIVE SLOTS
========================================================= */
const player1Slots =
  computed(() =>
    Array.from(
      {
        length:
          maxActive.value,
      },
      (_, index) =>
        props.player1Active[
          index
        ] ?? null,
    ),
  );
const player2Slots =
  computed(() =>
    Array.from(
      {
        length:
          maxActive.value,
      },
      (_, index) =>
        props.player2Active[
          index
        ] ?? null,
    ),
  );
/* =========================================================
   FORMATION
========================================================= */
const formationColumns =
  computed(() => {
    const count =
      maxActive.value;
    if (count <= 2) {
      return 1;
    }
    if (count <= 4) {
      return 2;
    }
    if (count <= 6) {
      return 3;
    }
    if (count <= 8) {
      return 4;
    }
    return Math.ceil(
      Math.sqrt(count),
    );
  });
const formationRows =
  computed(() =>
    Math.ceil(
      maxActive.value /
        formationColumns.value,
    ),
  );
const formationClass =
  computed(
    () =>
      `formation-${Math.min(
        maxActive.value,
        8,
      )}`,
  );
const spectatorCardWidth = computed(() => {
  const columns = formationColumns.value;
  const rows = formationRows.value;
  const width = stageMetrics.value.width || 400;
  const height = stageMetrics.value.height || 520;
  const widthCapacity = (width - 26 - (columns - 1) * 10) / columns;
  const heightCapacity = (height - 18 - (rows - 1) * 12) / rows / 1.68;
  return Math.max(68, Math.floor(Math.min(240, widthCapacity, heightCapacity)));
});
const formationStyle = computed(() => ({
  "--formation-columns": formationColumns.value,
  "--formation-rows": formationRows.value,
  "--tv-card-w": `${spectatorCardWidth.value}px`,
  "--tv-card-h": `${Math.floor(spectatorCardWidth.value * 1.68)}px`,
}));
/* =========================================================
   PLAYER INFO
========================================================= */
const p1Name =
  computed(
    () =>
      props.battle
        ?.player1_name ??
      "Player 1",
  );
const p2Name =
  computed(
    () =>
      props.battle
        ?.player2_name ??
      "Player 2",
  );
/* =========================================================
   HP
========================================================= */
const p1Hp =
  computed(() =>
    Number(
      props.battle
        ?.player1_hp ??
        0,
    ) || 0,
  );
const p2Hp =
  computed(() =>
    Number(
      props.battle
        ?.player2_hp ??
        0,
    ) || 0,
  );
const p1MaxHp =
  computed(() =>
    Math.max(
      1,
      Number(
        props.battle
          ?.player1_max_hp ??
          props.battle
            ?.player_starting_hp ??
          200,
      ) || 200,
    ),
  );
const p2MaxHp =
  computed(() =>
    Math.max(
      1,
      Number(
        props.battle
          ?.player2_max_hp ??
          props.battle
            ?.player_starting_hp ??
          200,
      ) || 200,
    ),
  );
const p1HpPercent =
  computed(() =>
    Math.max(
      0,
      Math.min(
        100,
        (
          p1Hp.value /
          p1MaxHp.value
        ) * 100,
      ),
    ),
  );
const p2HpPercent =
  computed(() =>
    Math.max(
      0,
      Math.min(
        100,
        (
          p2Hp.value /
          p2MaxHp.value
        ) * 100,
      ),
    ),
  );
/* =========================================================
   ULTIMATE
========================================================= */
const p1Skill =
  computed(() =>
    Math.max(
      0,
      Math.min(
        100,
        Number(
          props.battle
            ?.player1_skill ??
            0,
        ) || 0,
      ),
    ),
  );
const p2Skill =
  computed(() =>
    Math.max(
      0,
      Math.min(
        100,
        Number(
          props.battle
            ?.player2_skill ??
            0,
        ) || 0,
      ),
    ),
  );
/* =========================================================
   PERSISTENT MODIFIER STATE
========================================================= */
const p1PowerStrikeReady =
  computed(() =>
    Boolean(
      props.battle
        ?.player1_power_strike_ready,
    ),
  );
const p2PowerStrikeReady =
  computed(() =>
    Boolean(
      props.battle
        ?.player2_power_strike_ready,
    ),
  );
const p1Defending =
  computed(() =>
    Boolean(
      props.battle
        ?.player1_defending,
    ),
  );
const p2Defending =
  computed(() =>
    Boolean(
      props.battle
        ?.player2_defending,
    ),
  );
const p1WaterShieldPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player1_synergy_shield,
    ),
  );
const p2WaterShieldPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player2_synergy_shield,
    ),
  );
const p1AttackDebuffPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player1_attack_debuff,
    ),
  );
const p2AttackDebuffPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player2_attack_debuff,
    ),
  );
/* =========================================================
   STATUS ITEMS
========================================================= */
const buildStatusItems = (
  player,
) => {
  const items = [];
  const powerStrike =
    player === "p1"
      ? p1PowerStrikeReady.value
      : p2PowerStrikeReady.value;
  const defending =
    player === "p1"
      ? p1Defending.value
      : p2Defending.value;
  const shieldPercent =
    player === "p1"
      ? p1WaterShieldPercent.value
      : p2WaterShieldPercent.value;
  const debuffPercent =
    player === "p1"
      ? p1AttackDebuffPercent.value
      : p2AttackDebuffPercent.value;
  if (powerStrike) {
    items.push({
      type: "power",
      icon: "⚡",
      title:
        "POWER STRIKE READY",
      detail:
        "NEXT ATTACK ×1.50 DAMAGE (+50%)",
    });
  }
  if (defending) {
    items.push({
      type: "defense",
      icon: "🛡",
      title:
        "DEFENSE ACTIVE",
      detail:
        "NEXT INCOMING DAMAGE ×0.50 (-50%)",
    });
  }
  if (shieldPercent > 0) {
    items.push({
      type: "water",
      icon: "💧",
      title:
        "WATER SHIELD",
      detail:
        `NEXT INCOMING DAMAGE -${shieldPercent}%`,
    });
  }
  if (debuffPercent > 0) {
    items.push({
      type: "debuff",
      icon: "❄",
      title:
        "ATTACK DEBUFF",
      detail:
        `NEXT ATTACK DAMAGE -${debuffPercent}%`,
    });
  }
  return items;
};
const p1StatusItems =
  computed(() =>
    buildStatusItems(
      "p1",
    ),
  );
const p2StatusItems =
  computed(() =>
    buildStatusItems(
      "p2",
    ),
  );
/* =========================================================
   COMBAT HELPERS
========================================================= */
const combatCardMatches = (
  card,
  id,
) => {
  if (
    !card ||
    !id
  ) {
    return false;
  }
  return (
    String(
      getCardId(card),
    ) ===
    String(id)
  );
};
const getCombatSlotClasses = (
  player,
  card,
) => {
  if (
    !props.combatFx
      ?.active ||
    !card
  ) {
    return {};
  }
  const attacker =
    player ===
      props.combatFx
        .sourcePlayer &&
    combatCardMatches(
      card,
      props.combatFx
        .attackerCardId,
    );
  const target =
    player ===
      props.combatFx
        .targetPlayer &&
    combatCardMatches(
      card,
      props.combatFx
        .targetCardId,
    );
  return {
    "combat-attacker-slot":
      attacker,
    "combat-target-slot":
      target,
    "combat-charge":
      attacker &&
      props.combatFx
        .phase ===
        "charge",
    "combat-power-strike":
      attacker &&
      props.combatFx
        .powerStrikeApplied,
    "combat-attack-debuff":
      attacker &&
      props.combatFx
        .attackDebuffApplied,
    "combat-defense-target":
      target &&
      props.combatFx
        .defenseApplied,
    "combat-water-target":
      target &&
      props.combatFx
        .waterShieldApplied,
    "combat-impact":
      target &&
      props.combatFx
        .phase ===
        "impact",
    "combat-damaged":
      target &&
      [
        "result",
        "destroyed",
      ].includes(
        props.combatFx
          .phase,
      ),
    "combat-destroyed":
      target &&
      props.combatFx
        .destroyed &&
      [
        "destroyed",
        "exit",
      ].includes(
        props.combatFx
          .phase,
      ),
  };
};
/* =========================================================

   PHASE 3D.18 • STATUS EFFECT UI

========================================================= */

const STATUS_VISUALS = {
  defense: { icon: "🛡", label: "DEFENSE", tone: "defense" },
  water_shield: { icon: "💧", label: "SHIELD", tone: "water" },
  synergy_shield: { icon: "💧", label: "SHIELD", tone: "water" },
  shield: { icon: "💧", label: "SHIELD", tone: "water" },
  attack_debuff: { icon: "❄", label: "ATK DOWN", tone: "debuff" },
  power_strike: { icon: "⚡", label: "POWER STRIKE", tone: "power" },
  power_strike_ready: { icon: "⚡", label: "POWER STRIKE", tone: "power" },
  burn: { icon: "🔥", label: "BURN", tone: "burn" },
  elemental_burn: { icon: "🔥", label: "FIRE BURN", tone: "burn" },
  freeze: { icon: "🧊", label: "FREEZE", tone: "freeze" },
  frozen: { icon: "🧊", label: "FREEZE", tone: "freeze" },
  regen: { icon: "💚", label: "REGEN", tone: "regen" },
  regeneration: { icon: "💚", label: "REGEN", tone: "regen" },
  silence: { icon: "🔒", label: "SILENCE", tone: "silence" },
  stun: { icon: "💫", label: "STUN", tone: "stun" },
  poison: { icon: "☠", label: "POISON", tone: "poison" },
  curse: { icon: "🌑", label: "CURSE", tone: "curse" },
  bleed: { icon: "🩸", label: "BLEED", tone: "bleed" },
  invincible: { icon: "✨", label: "INVINCIBLE", tone: "buff" },
  invulnerability: { icon: "✨", label: "INVINCIBLE", tone: "buff" },
  cooldown: { icon: "⏳", label: "COOLDOWN", tone: "cooldown" },
  necro_identity: { icon: "☠", label: "NECRO", tone: "necro" },
  fusion_identity: { icon: "🧬", label: "FUSION", tone: "fusion" },
};

const normalizeStatusKey = normalizeBattleStatusKey;

const statusMetadata = (effect) => {
  const value = effect?.metadata;
  if (value && typeof value === "object") return value;
  if (typeof value === "string") {
    try { return JSON.parse(value); } catch { /* malformed metadata */ }
  }
  return {};
};

const statusPercent = (value) => {
  const numeric = Number(value ?? 0) || 0;
  const percent = Math.abs(numeric) <= 1 ? numeric * 100 : numeric;
  return Math.round(Math.abs(percent));
};

const enrichStatus = (effect) => {
  const key = normalizeStatusKey(effect);
  const meta = statusMetadata(effect);
  const visual = STATUS_VISUALS[key] ?? {};
  const rawValue = effect?.value;
  const value = Number(
    rawValue && typeof rawValue === "object"
      ? (rawValue.amount ?? rawValue.value ?? 0)
      : (rawValue ?? 0),
  ) || 0;
  const percentKeys = new Set([
    "defense",
    "water_shield",
    "synergy_shield",
    "shield",
    "attack_debuff",
    "power_strike",
    "power_strike_ready",
  ]);
  const turns = Number(effect?.remaining_turns ?? 0) || 0;
  const rounds = Number(effect?.remaining_rounds ?? 0) || 0;
  const stacks = Math.max(1, Number(effect?.stacks ?? 1) || 1);
  const valueParts = [];

  if (percentKeys.has(key) && value !== 0) {
    valueParts.push(`${statusPercent(value)}%`);
  } else if (value !== 0) {
    valueParts.push(`${Math.abs(value)}`);
  }

  if (stacks > 1) {
    valueParts.push(`×${stacks}`);
  }

  return {
    ...effect,
    key,
    icon: String(meta.icon ?? visual.icon ?? "✦"),
    label: String(meta.label ?? meta.name ?? visual.label ?? key.replaceAll("_", " ").toUpperCase()),
    tone: String(meta.tone ?? visual.tone ?? (value < 0 ? "debuff" : "buff")),
    valueText: valueParts.join(" "),
    durationText: turns > 0 ? `${turns}T` : rounds > 0 ? `${rounds}R` : "",
  };
};

const dedupeStatuses = (items) => {
  const map = new Map();
  for (const raw of items) {
    const item = enrichStatus(raw);
    const key = `${item.key}:${item.target_card_id ?? "player"}`;
    const current = map.get(key);
    if (!current || (!current.valueText && item.valueText)) {
      map.set(key, item);
    }
  }
  return [...map.values()];
};

const legacyPlayerStatuses = (playerKey) => {
  const isP1 = playerKey === "p1";
  const statuses = [];
  const defending = isP1 ? p1Defending.value : p2Defending.value;
  const shield = isP1 ? p1WaterShieldPercent.value : p2WaterShieldPercent.value;
  const debuff = isP1 ? p1AttackDebuffPercent.value : p2AttackDebuffPercent.value;
  const power = isP1 ? p1PowerStrikeReady.value : p2PowerStrikeReady.value;

  if (defending) statuses.push({ status_key: "defense", value: 0.5, target_player: playerKey });
  if (shield > 0) statuses.push({ status_key: "water_shield", value: shield, target_player: playerKey });
  if (debuff > 0) statuses.push({ status_key: "attack_debuff", value: debuff, target_player: playerKey });
  if (power) statuses.push({ status_key: "power_strike_ready", value: 0.5, target_player: playerKey });

  return statuses;
};

const playerStatusEffects = (playerKey) =>
  dedupeStatuses([
    ...legacyPlayerStatuses(playerKey),
    ...props.statusEffects.filter(
      (effect) =>
        String(effect?.target_player ?? "").toLowerCase() === playerKey &&
        !effect?.target_card_id,
    ),
  ]);

const cardHasNecroIdentity = (card) => {
  const tags = Array.isArray(card?.tags) ? card.tags : [];
  return tags.some((tag) => String(tag).toLowerCase() === "necro") ||
    String(card?.element ?? "").toLowerCase() === "necro";
};

const cardHasFusionIdentity = (card) =>
  Boolean(card?.is_fusion_result) ||
  String(card?.origin_type ?? "").toLowerCase() === "fusion" ||
  String(card?.card_type ?? "").toLowerCase() === "fusion";

const cardStatusEffects = (card) => {
  if (!card) return [];
  // Status.target_card_id points at battle_cards.id, not game_cards.id.
  // useBattleSession mappers may expose the same identity under different keys.
  const ids = [card?.battleId, card?.battle_card_id, card?.battleCardId,
    card?.battle_id, card?.id]
    .filter((value) => value !== null && value !== undefined && value !== "")
    .map(String);
  const identitySet = new Set(ids);
  const id = ids[0] ?? null;
  const items = props.statusEffects.filter(
    (effect) => effect?.active !== false &&
      effect?.target_card_id != null &&
      identitySet.has(String(effect.target_card_id)),
  );

  if (cardHasNecroIdentity(card)) {
    items.unshift({
      status_key: "necro_identity",
      metadata: { icon: "☠", label: "NECRO", tone: "necro" },
      target_card_id: id,
    });
  }

  if (cardHasFusionIdentity(card)) {
    items.unshift({
      status_key: "fusion_identity",
      metadata: { icon: "🧬", label: "FUSION", tone: "fusion" },
      target_card_id: id,
    });
  }

  // Put gameplay-relevant Burn in the first three visible status slots.
  return dedupeStatuses(items).sort((a, b) =>
    Number(b.key === "elemental_burn" || b.key === "burn") -
    Number(a.key === "elemental_burn" || a.key === "burn")
  );
};

const visualOnlyCardStatuses = new Set([
  "burn", "elemental_burn", "freeze", "frozen", "stun", "poison", "curse",
  "shield", "water_shield", "synergy_shield", "defense",
]);

const visibleCardStatuses = (card) =>
  cardStatusEffects(card).filter((effect) => !visualOnlyCardStatuses.has(effect.key));

const cardFxFlags = (card) => {
  const keys = new Set(cardStatusEffects(card).map((status) => status.key));
  const id = String(getCardId(card) ?? "");
  const belongsToP1 = props.player1Active.some((item) => String(getCardId(item) ?? "") === id);
  const belongsToP2 = props.player2Active.some((item) => String(getCardId(item) ?? "") === id);
  return {
    defense: keys.has("defense"),
    shield: keys.has("shield") || keys.has("water_shield") || keys.has("synergy_shield") ||
      (belongsToP1 && p1WaterShieldPercent.value > 0) || (belongsToP2 && p2WaterShieldPercent.value > 0),
    necro: keys.has("necro_identity"),
    fusion: keys.has("fusion_identity"),
    burn: keys.has("burn") || keys.has("elemental_burn"),
    freeze: keys.has("freeze") || keys.has("frozen"),
    poison: keys.has("poison"),
    stun: keys.has("stun"),
    curse: keys.has("curse"),
  };
};

const statusTooltip = (status) =>
  `${status.icon} ${status.label}${status.valueText ? ` • ${status.valueText}` : ""}${status.durationText ? ` • ${status.durationText}` : ""}`;


/* =========================================================
   BARRIERS
========================================================= */
const showDefenseBarrier = (
  player,
) => {
  const persistent =
    player === "p1"
      ? p1Defending.value
      : p2Defending.value;
  const combat =
    props.combatFx
      ?.active &&
    props.combatFx
      ?.targetPlayer ===
      player &&
    props.combatFx
      ?.defenseApplied;
  return (
    persistent ||
    combat
  );
};
const showWaterBarrier = (
  player,
) => {
  const persistent =
    player === "p1"
      ? p1WaterShieldPercent.value >
        0
      : p2WaterShieldPercent.value >
        0;
  const combat =
    props.combatFx
      ?.active &&
    props.combatFx
      ?.targetPlayer ===
      player &&
    props.combatFx
      ?.waterShieldApplied;
  return (
    persistent ||
    combat
  );
};
const defenseBreaking = (
  player,
) =>
  props.combatFx
    ?.active &&
  props.combatFx
    ?.targetPlayer ===
    player &&
  props.combatFx
    ?.defenseApplied &&
  props.combatFx
    ?.phase ===
    "impact";
const waterBreaking = (
  player,
) =>
  props.combatFx
    ?.active &&
  props.combatFx
    ?.targetPlayer ===
    player &&
  props.combatFx
    ?.waterShieldApplied &&
  props.combatFx
    ?.phase ===
    "impact";
/* =========================================================
   TURN
========================================================= */
const currentTurn =
  computed(
    () =>
      props.battle
        ?.current_turn ??
      "p1",
  );
const actionPointsEnabled = computed(() =>
  String(props.battle?.ruleset ?? "").toLowerCase() === "tcg_v1" &&
  Boolean(props.battle?.action_points_enabled),
);
const player1ActionPoints = computed(() =>
  Math.max(0, Number(props.battle?.player1_action_points ?? 0) || 0),
);
const player2ActionPoints = computed(() =>
  Math.max(0, Number(props.battle?.player2_action_points ?? 0) || 0),
);
const turnText =
  computed(() => {
    if (
      props.battle
        ?.winner
    ) {
      if (
        props.battle
          .winner ===
        "draw"
      ) {
        return "BATTLE DRAW";
      }
      return `${
        props.battle
          .winner === "p1"
          ? p1Name.value
          : p2Name.value
      } WINS`;
    }
    if (
      props.battle
        ?.status ===
      "question"
    ) {
      return "CODING CHALLENGE";
    }
    return (
      currentTurn.value ===
      "p2"
        ? `${p2Name.value} TURN`
        : `${p1Name.value} TURN`
    );
  });
/* =========================================================
   AVATAR
========================================================= */
const p1Avatar =
  computed(
    () =>
      props.battle
        ?.player1_avatar_url ??
      "",
  );
const p2Avatar =
  computed(
    () =>
      props.battle
        ?.player2_avatar_url ??
      "",
  );
const isAvatarImage = (value) =>
  /^(https?:\/\/|\/|data:image\/)/i.test(String(value ?? "").trim());
/* =========================================================
   POSITION CAPTURE
========================================================= */
const scheduleCapture =
  async () => {
    await nextTick();
    requestAnimationFrame(
      () => {
        captureCardRects();
      },
    );
  };
onMounted(() => {
  void scheduleCapture();
  stageObserver = new ResizeObserver(() => measureStage());
  if (p1StageRef.value) stageObserver.observe(p1StageRef.value);
  if (p2StageRef.value) stageObserver.observe(p2StageRef.value);
  measureStage();
  window.addEventListener('resize', measureStage, { passive: true });
});
onUnmounted(() => {
  stageObserver?.disconnect();
  stageObserver = null;
  window.removeEventListener('resize', measureStage);
});
onUpdated(() => {
  void scheduleCapture();
});
</script>
<template>
  <section class="public-active-field">
    <!-- ===================================================
         HEADER
    ==================================================== -->
    <header class="battle-header">
      <!-- PLAYER 1 -->
      <section
        ref="p1HudRef"
        class="player-hud p1"
        :class="{
          current:
            currentTurn ===
            'p1',
          'defense-active':
            p1Defending,
          'water-active':
            p1WaterShieldPercent >
            0,
          'debuff-active':
            p1AttackDebuffPercent >
            0,
          'power-active':
            p1PowerStrikeReady,
        }"
      >
        <div
          ref="p1AvatarRef"
          class="avatar blue"
        >
          <img v-if="isAvatarImage(p1Avatar)" :src="p1Avatar" :alt="p1Name" />
          <span v-else>{{ p1Avatar || "👦🏻" }}</span>
        </div>
        <div class="player-info">
          <div class="player-name-row">
            <div>
              <span>
                PLAYER 1
              </span>
              <strong>
                {{ p1Name }}
              </strong>
            </div>
            <small>
              Active
              {{ player1Active.length }}
              /
              {{ maxActive }}
              • Bench
              {{ player1BenchCount }}
              /
              {{ maxBench }}
            </small>
          </div>
          <div class="health-line">
            <div class="health-track">
              <div
                class="health-fill blue"
                :style="{
                  width:
                    `${p1HpPercent}%`,
                }"
/>
            </div>
            <strong>
              HP {{ p1Hp }}
              /
              {{ p1MaxHp }}
            </strong>
          </div>
          <div class="skill-heading">
            <span>
              ULTIMATE
            </span>
            <strong>
              {{ p1Skill }}%
            </strong>
          </div>
          <div class="skill-track">
            <div
              class="skill-fill blue"
              :style="{
                width:
                  `${p1Skill}%`,
              }"
/>
          </div>
          <div v-if="playerStatusEffects('p1').length" class="public-status-ribbon left">
            <span
              v-for="status in playerStatusEffects('p1').slice(0, 4)"
              :key="`p1-${status.key}`"
              class="public-status-chip"
              :class="status.tone"
              :title="statusTooltip(status)"
            >
              <b>{{ status.icon }}</b>
              <em>{{ status.label }}</em>
              <small v-if="status.valueText">{{ status.valueText }}</small>
              <small v-if="status.durationText">{{ status.durationText }}</small>
            </span>
            <span
              v-if="playerStatusEffects('p1').length > 4"
              class="public-status-more"
            >
              +{{ playerStatusEffects('p1').length - 4 }}
            </span>
          </div>
        </div>
      </section>
      <!-- CENTER -->
      <section class="center-brand">
        <span class="brand-top">
          CARD BATTLE
        </span>
        <strong>
          NEXUS
        </strong>
        <span class="brand-bottom">
          BATTLE ARENA
        </span>
        <div
          class="turn-chip"
          :class="currentTurn"
        >
          <span>●</span>
          {{ turnText }}
        </div>
        <div class="battle-meta">
          <span>
            ROUND
            {{ battle.round ?? 1 }}
            /
            {{
              battle.total_rounds ??
              "-"
            }}
          </span>
          <span>
            MAX ACTIVE
            {{ maxActive }}
          </span>
          <span v-if="actionPointsEnabled" class="public-ap-meta">
            POIN GILIRAN · P1 {{ player1ActionPoints }} / P2 {{ player2ActionPoints }}
          </span>
          <span>
            {{
              String(
                battle.ruleset ??
                  "classic",
              ).toUpperCase()
            }}
          </span>
        </div>
      </section>
      <!-- PLAYER 2 -->
      <section
        ref="p2HudRef"
        class="player-hud p2"
        :class="{
          current:
            currentTurn ===
            'p2',
          'defense-active':
            p2Defending,
          'water-active':
            p2WaterShieldPercent >
            0,
          'debuff-active':
            p2AttackDebuffPercent >
            0,
          'power-active':
            p2PowerStrikeReady,
        }"
      >
        <div class="player-info">
          <div
            class="
              player-name-row
              right
            "
          >
            <small>
              Active
              {{ player2Active.length }}
              /
              {{ maxActive }}
              • Bench
              {{ player2BenchCount }}
              /
              {{ maxBench }}
            </small>
            <div>
              <span>
                PLAYER 2
              </span>
              <strong>
                {{ p2Name }}
              </strong>
            </div>
          </div>
          <div class="health-line">
            <strong>
              HP {{ p2Hp }}
              /
              {{ p2MaxHp }}
            </strong>
            <div class="health-track">
              <div
                class="health-fill red"
                :style="{
                  width:
                    `${p2HpPercent}%`,
                }"
/>
            </div>
          </div>
          <div class="skill-heading">
            <span>
              ULTIMATE
            </span>
            <strong>
              {{ p2Skill }}%
            </strong>
          </div>
          <div class="skill-track">
            <div
              class="skill-fill red"
              :style="{
                width:
                  `${p2Skill}%`,
              }"
/>
          </div>
          <div v-if="playerStatusEffects('p2').length" class="public-status-ribbon right">
            <span
              v-for="status in playerStatusEffects('p2').slice(0, 4)"
              :key="`p2-${status.key}`"
              class="public-status-chip"
              :class="status.tone"
              :title="statusTooltip(status)"
            >
              <b>{{ status.icon }}</b>
              <em>{{ status.label }}</em>
              <small v-if="status.valueText">{{ status.valueText }}</small>
              <small v-if="status.durationText">{{ status.durationText }}</small>
            </span>
            <span
              v-if="playerStatusEffects('p2').length > 4"
              class="public-status-more"
            >
              +{{ playerStatusEffects('p2').length - 4 }}
            </span>
          </div>
        </div>
        <div
          ref="p2AvatarRef"
          class="avatar red"
        >
          <img v-if="isAvatarImage(p2Avatar)" :src="p2Avatar" :alt="p2Name" />
          <span v-else>{{ p2Avatar || "🧑🏽‍🦱" }}</span>
        </div>
      </section>
    </header>
    <!-- ===================================================
         BATTLEFIELD
    ==================================================== -->
    <section class="battlefield">
      <!-- PLAYER 1 -->
      <section
        ref="p1FieldRef"
        class="field-side p1-field"
      >
        <div class="field-background">
          <div class="giant-symbol">
            ◉
          </div>
        </div>
        <!-- PERSISTENT BARRIERS -->
        <div
          v-if="
            showDefenseBarrier(
              'p1',
            )
          "
          class="
            field-barrier
            defense-barrier
          "
          :class="{
            breaking:
              defenseBreaking(
                'p1',
              ),
          }"
        >
          <span>🛡</span>
        </div>
        <div
          v-if="
            showWaterBarrier(
              'p1',
            )
          "
          class="
            field-barrier
            water-barrier
          "
          :class="{
            breaking:
              waterBreaking(
                'p1',
              ),
          }"
        >
          <span>💧</span>
        </div>
        <div class="field-top">
          <header class="field-title">
            <div>
              <span>
                PLAYER 1
              </span>
              <strong>
                ACTIVE DECK
              </strong>
            </div>
            <em>
              ATTACK ›››
            </em>
          </header>
          <!-- CLEAR STATUS INFO -->
          <div
            v-if="
              p1StatusItems.length
            "
            class="
              status-strip
              left
            "
          >
            <div
              v-for="
                item in
                  p1StatusItems
              "
              :key="
                item.type
              "
              class="battle-status-chip"
              :class="
                item.type
              "
            >
              <span class="status-icon">
                {{ item.icon }}
              </span>
              <div>
                <strong>
                  {{ item.title }}
                </strong>
                <small>
                  {{ item.detail }}
                </small>
              </div>
            </div>
          </div>
        </div>
        <div ref="p1StageRef" class="formation-stage">
          <div
            class="
              formation-grid
              p1-formation
            "
            :class="
              formationClass
            "
            :style="
              formationStyle
            "
          >
            <div
              v-for="(
                card,
                index
              ) in
                player1Slots"
              :key="
                card?.battleId ??
                card?.battle_id ??
                card?.id ??
                `p1-empty-${index}`
              "
              :ref="
                (element) =>
                  registerCardElement(
                    'p1',
                    card,
                    element,
                  )
              "
              class="formation-slot"
              :class="[
                `slot-${index + 1}`,
                getCombatSlotClasses(
                  'p1',
                  card,
                ),
                card ? {
                  'fx-defense-active': cardFxFlags(card).defense,
                  'fx-shield-active': cardFxFlags(card).shield,
                  'fx-necro-active': cardFxFlags(card).necro,
                  'fx-fusion-active': cardFxFlags(card).fusion,
                  'fx-burn-active': cardFxFlags(card).burn,
                  'fx-freeze-active': cardFxFlags(card).freeze,
                  'fx-poison-active': cardFxFlags(card).poison,
                  'fx-stun-active': cardFxFlags(card).stun,
                  'fx-curse-active': cardFxFlags(card).curse,
                } : {},
              ]"
            >
              <BattleCard
                :card="card"
                player="p1"
                facing="right"
                :empty-label="
                  `POKÉMON ${
                    index + 1
                  }`
                "
              />
              <div v-if="card" class="public-card-fx-stack" aria-hidden="true">
                <i v-if="cardFxFlags(card).fusion" class="public-card-fx-layer fx-fusion-layer"></i>
                <i v-if="cardFxFlags(card).necro" class="public-card-fx-layer fx-necro-layer"></i>
              </div>
              <CardStatusVfx
                v-if="card"
                :shield="cardFxFlags(card).shield"
                :defense="cardFxFlags(card).defense"
                :burn="cardFxFlags(card).burn"
                :freeze="cardFxFlags(card).freeze"
                :stun="cardFxFlags(card).stun"
                :poison="cardFxFlags(card).poison"
                :curse="cardFxFlags(card).curse"
              />
              <div
                v-if="card && visibleCardStatuses(card).length"
                class="public-card-statuses p1"
              >
                <span
                  v-for="status in visibleCardStatuses(card).slice(0, 3)"
                  :key="`p1-${getCardId(card)}-${status.key}`"
                  class="public-card-status-chip"
                  :class="status.tone"
                  :title="statusTooltip(status)"
                >
                  <b>{{ status.icon }}</b>
                  <em>{{ status.label }}</em>
                  <small v-if="status.valueText">{{ status.valueText }}</small>
                  <small v-if="status.durationText">{{ status.durationText }}</small>
                </span>
                <span
                  v-if="visibleCardStatuses(card).length > 3"
                  class="public-card-status-chip more"
                >
                  +{{ visibleCardStatuses(card).length - 3 }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="attack-lane p1">
          <div class="lane-line" />
          <span>›</span>
          <span>›</span>
          <span>›</span>
        </div>
      </section>
      <!-- PLAYER 2 -->
      <section
        ref="p2FieldRef"
        class="field-side p2-field"
      >
        <div class="field-background">
          <div class="giant-symbol">
            ◉
          </div>
        </div>
        <div
          v-if="
            showDefenseBarrier(
              'p2',
            )
          "
          class="
            field-barrier
            defense-barrier
          "
          :class="{
            breaking:
              defenseBreaking(
                'p2',
              ),
          }"
        >
          <span>🛡</span>
        </div>
        <div
          v-if="
            showWaterBarrier(
              'p2',
            )
          "
          class="
            field-barrier
            water-barrier
          "
          :class="{
            breaking:
              waterBreaking(
                'p2',
              ),
          }"
        >
          <span>💧</span>
        </div>
        <div class="field-top">
          <header
            class="
              field-title
              right
            "
          >
            <em>
              ‹‹‹ ATTACK
            </em>
            <div>
              <span>
                PLAYER 2
              </span>
              <strong>
                ACTIVE DECK
              </strong>
            </div>
          </header>
          <div
            v-if="
              p2StatusItems.length
            "
            class="
              status-strip
              right
            "
          >
            <div
              v-for="
                item in
                  p2StatusItems
              "
              :key="
                item.type
              "
              class="battle-status-chip"
              :class="
                item.type
              "
            >
              <span class="status-icon">
                {{ item.icon }}
              </span>
              <div>
                <strong>
                  {{ item.title }}
                </strong>
                <small>
                  {{ item.detail }}
                </small>
              </div>
            </div>
          </div>
        </div>
        <div ref="p2StageRef" class="formation-stage">
          <div
            class="
              formation-grid
              p2-formation
            "
            :class="
              formationClass
            "
            :style="
              formationStyle
            "
          >
            <div
              v-for="(
                card,
                index
              ) in
                player2Slots"
              :key="
                card?.battleId ??
                card?.battle_id ??
                card?.id ??
                `p2-empty-${index}`
              "
              :ref="
                (element) =>
                  registerCardElement(
                    'p2',
                    card,
                    element,
                  )
              "
              class="formation-slot"
              :class="[
                `slot-${index + 1}`,
                getCombatSlotClasses(
                  'p2',
                  card,
                ),
                card ? {
                  'fx-defense-active': cardFxFlags(card).defense,
                  'fx-shield-active': cardFxFlags(card).shield,
                  'fx-necro-active': cardFxFlags(card).necro,
                  'fx-fusion-active': cardFxFlags(card).fusion,
                  'fx-burn-active': cardFxFlags(card).burn,
                  'fx-freeze-active': cardFxFlags(card).freeze,
                  'fx-poison-active': cardFxFlags(card).poison,
                  'fx-stun-active': cardFxFlags(card).stun,
                  'fx-curse-active': cardFxFlags(card).curse,
                } : {},
              ]"
            >
              <BattleCard
                :card="card"
                player="p2"
                facing="left"
                :empty-label="
                  `POKÉMON ${
                    index + 1
                  }`
                "
              />
              <div v-if="card" class="public-card-fx-stack" aria-hidden="true">
                <i v-if="cardFxFlags(card).fusion" class="public-card-fx-layer fx-fusion-layer"></i>
                <i v-if="cardFxFlags(card).necro" class="public-card-fx-layer fx-necro-layer"></i>
              </div>
              <CardStatusVfx
                v-if="card"
                :shield="cardFxFlags(card).shield"
                :defense="cardFxFlags(card).defense"
                :burn="cardFxFlags(card).burn"
                :freeze="cardFxFlags(card).freeze"
                :stun="cardFxFlags(card).stun"
                :poison="cardFxFlags(card).poison"
                :curse="cardFxFlags(card).curse"
              />
              <div
                v-if="card && visibleCardStatuses(card).length"
                class="public-card-statuses p2"
              >
                <span
                  v-for="status in visibleCardStatuses(card).slice(0, 3)"
                  :key="`p2-${getCardId(card)}-${status.key}`"
                  class="public-card-status-chip"
                  :class="status.tone"
                  :title="statusTooltip(status)"
                >
                  <b>{{ status.icon }}</b>
                  <em>{{ status.label }}</em>
                  <small v-if="status.valueText">{{ status.valueText }}</small>
                  <small v-if="status.durationText">{{ status.durationText }}</small>
                </span>
                <span
                  v-if="visibleCardStatuses(card).length > 3"
                  class="public-card-status-chip more"
                >
                  +{{ visibleCardStatuses(card).length - 3 }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="attack-lane p2">
          <span>‹</span>
          <span>‹</span>
          <span>‹</span>
          <div class="lane-line" />
        </div>
      </section>
      <div class="center-line" />
      <div class="center-orb">
        <span class="blue-half" />
        <span class="red-half" />
        <i />
      </div>
    </section>
  </section>
</template>
<style scoped>
* {
  box-sizing: border-box;
}
.public-active-field {
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  display: grid;
  grid-template-rows:
    126px
    minmax(0, 1fr);
  overflow: hidden;
  border:
    1px solid
    rgba(75, 129, 160, 0.16);
  border-radius: 18px;
  background: #ffffff;
  box-shadow:
    0 18px 46px
    rgba(55, 94, 119, 0.14);
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}
/* =========================================================
   HEADER
========================================================= */
.battle-header {
  min-width: 0;
  display: grid;
  grid-template-columns:
    minmax(0, 1fr)
    235px
    minmax(0, 1fr);
  overflow: hidden;
  background:
    linear-gradient(
      180deg,
      #ffffff,
      #eef8fc
    );
  box-shadow:
    0 7px 22px
    rgba(53, 94, 119, 0.08);
  z-index: 20;
}
.player-hud {
  min-width: 0;
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  padding:
    12px
    18px;
  background:
    rgba(255, 255, 255, 0.7);
  transition:
    box-shadow 0.2s ease;
}
.player-hud.p1 {
  border-bottom:
    3px solid
    #28b3ec;
  background:
    linear-gradient(
      90deg,
      rgba(36, 172, 235, 0.12),
      rgba(255, 255, 255, 0.72)
    );
}
.player-hud.p2 {
  border-bottom:
    3px solid
    #ed567c;
  background:
    linear-gradient(
      270deg,
      rgba(237, 86, 124, 0.11),
      rgba(255, 255, 255, 0.72)
    );
}
.player-hud.power-active {
  box-shadow:
    inset 0 0 26px
    rgba(245, 181, 42, 0.14);
}
.player-hud.defense-active {
  box-shadow:
    inset 0 0 26px
    rgba(60, 139, 218, 0.14);
}
.player-hud.water-active {
  box-shadow:
    inset 0 0 28px
    rgba(27, 188, 221, 0.16);
}
.player-hud.debuff-active {
  filter:
    saturate(0.9);
}
/* =========================================================
   AVATAR
========================================================= */
.avatar {
  width: 62px;
  height: 62px;
  flex:
    0 0 62px;
  display: grid;
  place-items: center;
  overflow: hidden;
  border:
    4px solid;
  border-radius: 50%;
  background:
    linear-gradient(
      145deg,
      #ffffff,
      #e9f5fa
    );
  box-shadow:
    0 8px 21px
    rgba(50, 91, 116, 0.13);
  font-size: 28px;
}
.avatar.blue {
  border-color: #25ace8;
}
.avatar.red {
  border-color: #ed4e72;
}
.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
/* =========================================================
   INFO
========================================================= */
.player-info {
  min-width: 0;
  flex: 1;
}
.player-name-row {
  display: flex;
  align-items:
    flex-start;
  justify-content:
    space-between;
  gap: 9px;
  margin-bottom: 7px;
}
.player-name-row.right {
  text-align: right;
}
.player-name-row span {
  display: block;
  color: #278ebf;
  font-size: 6px;
  font-weight: 950;
  letter-spacing: 0.1em;
}
.player-hud.p2
.player-name-row span {
  color: #d54d6b;
}
.player-name-row strong {
  display: block;
  margin-top: 2px;
  color: #17324a;
  font-size: 17px;
  font-weight: 950;
}
.player-name-row small {
  color: #6e899c;
  font-size: 6.5px;
  font-weight: 850;
}
/* =========================================================
   HEALTH
========================================================= */
.health-line {
  display: flex;
  align-items: center;
  gap: 8px;
}
.health-line strong {
  flex-shrink: 0;
  color: #264861;
  font-size: 8px;
  font-weight: 950;
}
.health-track {
  height: 12px;
  flex: 1;
  overflow: hidden;
  border:
    1px solid
    rgba(68, 118, 148, 0.15);
  border-radius: 999px;
  background: #dfeaf0;
}
.health-fill {
  height: 100%;
  border-radius: inherit;
}
.health-fill.blue {
  background:
    linear-gradient(
      90deg,
      #18a8ef,
      #40d5e3
    );
}
.health-fill.red {
  margin-left: auto;
  background:
    linear-gradient(
      90deg,
      #ff718b,
      #ef476f
    );
}
/* =========================================================
   SKILL
========================================================= */
.skill-heading {
  display: flex;
  justify-content:
    space-between;
  margin-top: 5px;
  color: #70899b;
  font-size: 5.5px;
  font-weight: 900;
}
.skill-track {
  height: 5px;
  margin-top: 3px;
  overflow: hidden;
  border-radius: 999px;
  background: #dce8ef;
}
.skill-fill {
  height: 100%;
}
.skill-fill.blue {
  background:
    linear-gradient(
      90deg,
      #715eff,
      #2eb7ff
    );
}
.skill-fill.red {
  margin-left: auto;
  background:
    linear-gradient(
      90deg,
      #ff8d5c,
      #ff4e77
    );
}
/* =========================================================
   CENTER
========================================================= */
.center-brand {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.brand-top {
  color: #c3941d;
  font-size: 6px;
  font-weight: 1000;
  letter-spacing: 0.28em;
}
.center-brand > strong {
  color: #28516c;
  font-size: 29px;
  font-weight: 1000;
  letter-spacing: 0.16em;
}
.brand-bottom {
  color: #63869c;
  font-size: 6px;
  font-weight: 950;
  letter-spacing: 0.25em;
}
.turn-chip {
  min-width: 155px;
  margin-top: 7px;
  padding:
    5px
    10px;
  border:
    1px solid
    rgba(45, 149, 203, 0.28);
  border-radius: 999px;
  color: #20739f;
  background: #e8f7fd;
  font-size: 7px;
  font-weight: 950;
}
.battle-meta {
  display: flex;
  gap: 4px;
  margin-top: 4px;
}
.battle-meta span {
  padding:
    2px
    4px;
  border-radius: 4px;
  color: #71899b;
  background: #eef5f8;
  font-size: 4.6px;
  font-weight: 900;
}
.battle-meta .public-ap-meta {
  padding-inline: 7px;
  color: #187a32;
  background: #e9f7e9;
  font-size: 5.8px;
}
/* =========================================================
   FIELD
========================================================= */
.battlefield {
  position: relative;
  display: grid;
  grid-template-columns:
    1fr
    1fr;
  min-height: 0;
  overflow: hidden;
}
.field-side {
  position: relative;
  min-width: 0;
  min-height: 0;
  display: grid;
  grid-template-rows:
    auto
    minmax(0, 1fr)
    42px;
  padding:
    18px
    12px
    14px;
  overflow: hidden;
}
.p1-field {
  background:
    linear-gradient(
      145deg,
      #d8f3ff,
      #bde9fb
    );
}
.p2-field {
  background:
    linear-gradient(
      215deg,
      #ffe4eb,
      #ffcfdc
    );
}
.field-background {
  position: absolute;
  inset: 0;
}
.giant-symbol {
  position: absolute;
  left: 50%;
  top: 55%;
  transform:
    translate(
      -50%,
      -50%
    );
  color:
    rgba(35, 113, 151, 0.08);
  font-size:
    min(31vw, 390px);
}
.p2-field
.giant-symbol {
  color:
    rgba(184, 57, 86, 0.07);
}
/* =========================================================
   FIELD TOP
========================================================= */
.field-top {
  position: relative;
  z-index: 8;
}
.field-title {
  display: flex;
  align-items: center;
  justify-content:
    space-between;
}
.field-title.right {
  text-align: right;
}
.field-title span {
  display: block;
  color: #6d8c9e;
  font-size: 5.5px;
  font-weight: 900;
}
.field-title strong {
  color: #247aa4;
  font-size: 10px;
  font-weight: 1000;
}
.p2-field
.field-title strong {
  color: #bd4b67;
}
.field-title em {
  color:
    rgba(36, 122, 164, 0.58);
  font-size: 7px;
  font-style: normal;
  font-weight: 950;
}
/* =========================================================
   STATUS STRIP
========================================================= */
.status-strip {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-top: 7px;
}
.status-strip.right {
  justify-content: flex-end;
}
.battle-status-chip {
  display: flex;
  align-items: center;
  gap: 5px;
  max-width: 220px;
  padding:
    5px
    7px;
  border-radius: 8px;
  background:
    rgba(255, 255, 255, 0.88);
  box-shadow:
    0 5px 13px
    rgba(50, 84, 104, 0.08);
}
.status-icon {
  font-size: 13px;
}
.battle-status-chip div {
  display: flex;
  flex-direction: column;
}
.battle-status-chip strong {
  font-size: 5.7px;
  font-weight: 1000;
}
.battle-status-chip small {
  margin-top: 1px;
  font-size: 5px;
  font-weight: 850;
}
.battle-status-chip.power {
  color: #976600;
  border:
    1px solid
    rgba(239, 179, 33, 0.4);
  background: #fff8df;
}
.battle-status-chip.defense {
  color: #266fa6;
  border:
    1px solid
    rgba(55, 145, 216, 0.35);
  background: #eaf6ff;
}
.battle-status-chip.water {
  color: #087c9e;
  border:
    1px solid
    rgba(20, 184, 220, 0.35);
  background: #e8fbff;
}
.battle-status-chip.debuff {
  color: #4f70a6;
  border:
    1px solid
    rgba(117, 154, 218, 0.38);
  background: #eff5ff;
}
/* =========================================================
   BARRIERS
========================================================= */
.field-barrier {
  position: absolute;
  left: 8%;
  right: 8%;
  top: 19%;
  bottom: 13%;
  z-index: 3;
  display: grid;
  place-items: center;
  border-radius: 44%;
  pointer-events: none;
}
.field-barrier span {
  font-size:
    clamp(
      70px,
      9vw,
      140px
    );
  opacity: 0.12;
}
.defense-barrier {
  border:
    4px solid
    rgba(64, 145, 220, 0.2);
  box-shadow:
    inset 0 0 45px
    rgba(65, 151, 225, 0.09),
    0 0 34px
    rgba(65, 151, 225, 0.1);
}
.water-barrier {
  border:
    4px solid
    rgba(21, 190, 220, 0.24);
  box-shadow:
    inset 0 0 55px
    rgba(21, 190, 220, 0.12),
    0 0 42px
    rgba(21, 190, 220, 0.13);
}
.field-barrier.breaking {
  animation:
    barrierBreak
    0.48s ease-out;
}
@keyframes barrierBreak {
  0% {
    opacity: 1;
    transform: scale(1);
  }
  30% {
    opacity: 1;
    transform:
      scale(1.05);
    filter:
      brightness(1.65);
  }
  100% {
    opacity: 0;
    transform:
      scale(1.17);
  }
}
/* =========================================================
   FORMATION
========================================================= */
.formation-stage {
  position: relative;
  z-index: 5;
  display: flex;
  align-items: center;
  min-height: 0;
}
.formation-grid {
  width: fit-content;
  max-width: 100%;
  display: grid;
  align-items: center;
  justify-items: center;
  row-gap:
    clamp(
      12px,
      1.6vh,
      18px
    );
  column-gap:
    clamp(
      10px,
      0.8vw,
      14px
    );
}
.p1-formation {
  margin-left: auto;
  margin-right:
    clamp(
      6px,
      0.8vw,
      12px
    );
}
.p2-formation {
  margin-left:
    clamp(
      6px,
      0.8vw,
      12px
    );
  margin-right: auto;
}
.formation-slot {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  transition:
    transform 0.22s ease,
    filter 0.22s ease;
}
/* =========================================================
   FORMATIONS
========================================================= */
.formation-1 {
  grid-template-columns: 1fr;
}
.formation-2 {
  grid-template-columns: 1fr;
}
.formation-3,
.formation-4 {
  grid-template-columns:
    repeat(2, 1fr);
}
.formation-3
.slot-3 {
  grid-column:
    1 / 3;
}
.formation-5 {
  grid-template-columns:
    repeat(6, 1fr);
}
.formation-5
.slot-1 {
  grid-column: 1 / 3;
}
.formation-5
.slot-2 {
  grid-column: 3 / 5;
}
.formation-5
.slot-3 {
  grid-column: 5 / 7;
}
.formation-5
.slot-4 {
  grid-column: 2 / 4;
}
.formation-5
.slot-5 {
  grid-column: 4 / 6;
}
.formation-6 {
  grid-template-columns:
    repeat(3, 1fr);
}
.formation-7 {
  grid-template-columns:
    repeat(8, 1fr);
}
.formation-7
.slot-1 {
  grid-column: 1 / 3;
}
.formation-7
.slot-2 {
  grid-column: 3 / 5;
}
.formation-7
.slot-3 {
  grid-column: 5 / 7;
}
.formation-7
.slot-4 {
  grid-column: 7 / 9;
}
.formation-7
.slot-5 {
  grid-column: 2 / 4;
}
.formation-7
.slot-6 {
  grid-column: 4 / 6;
}
.formation-7
.slot-7 {
  grid-column: 6 / 8;
}
.formation-8 {
  grid-template-columns:
    repeat(4, 1fr);
}
/* =========================================================
   CARD SIZES
========================================================= */
/*
  1 ACTIVE CARD
*/
.formation-1
:deep(.battle-card) {
  width:
    clamp(
      230px,
      16vw,
      270px
    );
  height:
    clamp(
      410px,
      46vh,
      470px
    );
}
/*
  2 ACTIVE CARDS
*/
.formation-2
:deep(.battle-card) {
  width:
    clamp(
      195px,
      13.5vw,
      225px
    );
  height:
    clamp(
      350px,
      40vh,
      405px
    );
}
/*
  3 - 4 ACTIVE CARDS
*/
.formation-3
:deep(.battle-card),
.formation-4
:deep(.battle-card) {
  width:
    clamp(
      165px,
      11.3vw,
      190px
    );
  height:
    clamp(
      300px,
      35vh,
      345px
    );
}
/*
  5 - 6 ACTIVE CARDS
  Ini kondisi pada screenshot MAX ACTIVE = 6.
  Ukurannya sekarang lebih besar dari versi lama.
*/
.formation-5
:deep(.battle-card),
.formation-6
:deep(.battle-card) {
  width:
    clamp(
      145px,
      10.4vw,
      168px
    );
  height:
    clamp(
      275px,
      32vh,
      315px
    );
}
/*
  7 - 8 ACTIVE CARDS
*/
.formation-7
:deep(.battle-card),
.formation-8
:deep(.battle-card) {
  width:
    clamp(
      108px,
      7.2vw,
      126px
    );
  height:
    clamp(
      215px,
      25vh,
      245px
    );
}
/* =========================================================
   POWER STRIKE ATTACKER
========================================================= */
.combat-power-strike
:deep(.battle-card) {
  animation:
    powerStrikeAura
    0.75s ease-in-out
    infinite alternate;
  filter:
    drop-shadow(
      0 0 11px
      #ffc83b
    )
    drop-shadow(
      0 0 25px
      rgba(255, 172, 27, 0.75)
    );
}
@keyframes powerStrikeAura {
  from {
    transform:
      scale(1.02);
  }
  to {
    transform:
      scale(1.07);
  }
}
/* =========================================================
   DEBUFF ATTACKER
========================================================= */
.combat-attack-debuff
:deep(.battle-card) {
  box-shadow:
    0 0 0 4px
    rgba(124, 178, 255, 0.28);
  filter:
    saturate(0.72)
    hue-rotate(8deg)
    drop-shadow(
      0 0 14px
      rgba(106, 174, 255, 0.8)
    );
}
.combat-attack-debuff::before {
  content: "❄ ATK DOWN";
  position: absolute;
  left: 50%;
  top: -17px;
  z-index: 20;
  transform:
    translateX(-50%);
  padding:
    4px
    7px;
  border-radius: 999px;
  color: #3f659d;
  background: #eff6ff;
  font-size: 6px;
  font-weight: 1000;
  white-space: nowrap;
}
/* =========================================================
   TARGET MODIFIERS
========================================================= */
.combat-defense-target::after {
  content: "🛡 DEFENSE -50%";
  position: absolute;
  left: 50%;
  top: -20px;
  z-index: 20;
  transform:
    translateX(-50%);
  padding:
    4px
    7px;
  border-radius: 999px;
  color: #236b9e;
  background: #e9f6ff;
  font-size: 6px;
  font-weight: 1000;
  white-space: nowrap;
}
.combat-water-target::before {
  content: "💧 WATER SHIELD";
  position: absolute;
  left: 50%;
  bottom: -19px;
  z-index: 20;
  transform:
    translateX(-50%);
  padding:
    4px
    7px;
  border-radius: 999px;
  color: #087b9d;
  background: #e7fbff;
  font-size: 6px;
  font-weight: 1000;
  white-space: nowrap;
}
.combat-impact {
  animation:
    targetHit
    0.42s ease;
}
@keyframes targetHit {
  20% {
    transform:
      translateX(-12px);
    filter:
      brightness(1.6);
  }
  45% {
    transform:
      translateX(9px);
  }
  70% {
    transform:
      translateX(-5px);
  }
}
.combat-destroyed {
  animation:
    destroyedCard
    0.55s ease
    forwards;
}
@keyframes destroyedCard {
  to {
    opacity: 0.15;
    filter:
      grayscale(1);
    transform:
      scale(0.83)
      translateY(18px);
  }
}
/* =========================================================
   ATTACK LANE
========================================================= */
.attack-lane {
  display: flex;
  align-items: center;
  gap: 6px;
  opacity: 0.5;
}
.attack-lane.p1 {
  justify-content:
    flex-end;
}
.attack-lane.p2 {
  justify-content:
    flex-start;
}
.lane-line {
  width: 38%;
  height: 2px;
  background:
    currentColor;
}
.attack-lane span {
  font-size: 20px;
  font-weight: 1000;
}
/* =========================================================
   CENTER LINE
========================================================= */
.center-line {
  width: 5px;
  position: absolute;
  left: 50%;
  top: 0;
  bottom: 0;
  z-index: 10;
  transform:
    translateX(-50%);
  background:
    linear-gradient(
      #31b6e9,
      #ffffff,
      #e85474
    );
}
.center-orb {
  width: 74px;
  height: 74px;
  position: absolute;
  left: 50%;
  top: 50%;
  z-index: 12;
  transform:
    translate(
      -50%,
      -50%
    );
  overflow: hidden;
  border:
    4px solid #ffffff;
  border-radius: 50%;
}
.blue-half,
.red-half {
  width: 50%;
  height: 100%;
  position: absolute;
}
.blue-half {
  left: 0;
  background: #238fc7;
}
.red-half {
  right: 0;
  background: #c82d4e;
}
.center-orb i {
  width: 17px;
  height: 17px;
  position: absolute;
  left: 50%;
  top: 50%;
  z-index: 4;
  transform:
    translate(
      -50%,
      -50%
    )
    rotate(45deg);
  background: #ffffff;
}
/* =========================================================
   BATTLE CARD CONTENT SAFETY
   PublicActiveField memberi ruang lebih besar ke BattleCard.
   Override di bawah memastikan angka 3 digit seperti 220 / 312
   tidak berubah menjadi 2... dan judul panjang bisa 2 baris.
========================================================= */
.formation-slot
:deep(.battle-card) {
  min-width: 0;
  min-height: 0;
}
.formation-slot
:deep(.card-title strong) {
  white-space: normal !important;
  text-overflow: clip !important;
  overflow: hidden !important;
  display: -webkit-box !important;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
}
.formation-slot
:deep(.stat-grid) {
  min-width: 0;
}
.formation-slot
:deep(.stat) {
  min-width: 0;
  padding:
    clamp(
      5px,
      0.45vw,
      8px
    );
}
.formation-slot
:deep(.stat strong) {
  width: 100%;
  overflow: visible !important;
  text-overflow: clip !important;
  white-space: nowrap !important;
  font-size:
    clamp(
      18px,
      1.45vw,
      29px
    ) !important;
  letter-spacing:
    -0.045em;
  line-height: 1;
}
.formation-slot
:deep(.hp-heading strong) {
  white-space: nowrap;
}
/* =========================================================
   RESPONSIVE
========================================================= */
@media (
  max-height: 820px
) {
  .public-active-field {
    grid-template-rows:
      108px
      minmax(0, 1fr);
  }
  .formation-grid {
    row-gap: 14px;
    column-gap: 12px;
  }
  .formation-3
  :deep(.battle-card),
  .formation-4
  :deep(.battle-card) {
    width:
      clamp(
        150px,
        10.4vw,
        172px
      );
    height:
      clamp(
        265px,
        32vh,
        305px
      );
  }
  .formation-5
  :deep(.battle-card),
  .formation-6
  :deep(.battle-card) {
    width:
      clamp(
        132px,
        9.4vw,
        150px
      );
    height:
      clamp(
        245px,
        29vh,
        280px
      );
  }
  .formation-7
  :deep(.battle-card),
  .formation-8
  :deep(.battle-card) {
    width:
      clamp(
        98px,
        6.6vw,
        112px
      );
    height:
      clamp(
        195px,
        23vh,
        220px
      );
  }
  .battle-status-chip {
    padding:
      3px
      5px;
  }
}


/* =========================================================
   PHASE 3D.18 • STATUS EFFECT UI
========================================================= */
.public-status-ribbon { display:flex; align-items:center; flex-wrap:wrap; gap:4px; margin-top:5px; }
.public-status-ribbon.right { justify-content:flex-end; }
.public-status-chip, .public-card-status-chip { --status-bg:rgba(255,255,255,.09); --status-border:rgba(255,255,255,.2); --status-text:#edf7ff; display:inline-flex; align-items:center; gap:3px; border:1px solid var(--status-border); background:var(--status-bg); color:var(--status-text); backdrop-filter:blur(9px); }
.public-status-chip { min-height:19px; padding:3px 6px; border-radius:999px; }
.public-status-chip b, .public-card-status-chip b { line-height:1; }
.public-status-chip em, .public-card-status-chip em { font-style:normal; font-weight:950; letter-spacing:.04em; }
.public-status-chip em { font-size:6px; }
.public-status-chip small { font-size:5.5px; font-weight:900; }
.public-status-more { font-size:7px; font-weight:950; opacity:.72; }
.formation-slot { position:relative; }
.public-card-statuses { position:absolute; top:5px; z-index:40; display:flex; align-items:center; flex-wrap:wrap; gap:3px; max-width:calc(100% - 10px); pointer-events:none; }
.public-card-statuses.p1 { left:5px; justify-content:flex-start; }
.public-card-statuses.p2 { right:5px; justify-content:flex-end; }
.public-card-status-chip { min-height:18px; padding:2px 5px; border-radius:7px; box-shadow:0 5px 14px rgba(0,0,0,.18); }
.public-card-status-chip em { font-size:5.5px; }
.public-card-status-chip small { font-size:5px; font-weight:950; }
.public-card-status-chip.more { font-size:6px; font-weight:950; }
.public-status-chip.defense,.public-card-status-chip.defense{--status-bg:rgba(48,127,232,.22);--status-border:rgba(81,158,255,.58)}
.public-status-chip.water,.public-card-status-chip.water{--status-bg:rgba(27,166,218,.22);--status-border:rgba(65,195,241,.58)}
.public-status-chip.power,.public-card-status-chip.power{--status-bg:rgba(221,162,34,.24);--status-border:rgba(255,204,71,.62)}
.public-status-chip.debuff,.public-card-status-chip.debuff,.public-status-chip.freeze,.public-card-status-chip.freeze{--status-bg:rgba(95,122,211,.24);--status-border:rgba(133,162,255,.58)}
.public-status-chip.burn,.public-card-status-chip.burn{--status-bg:rgba(210,71,42,.24);--status-border:rgba(255,105,71,.62)}
.public-status-chip.regen,.public-card-status-chip.regen,.public-status-chip.buff,.public-card-status-chip.buff{--status-bg:rgba(41,157,92,.24);--status-border:rgba(80,216,137,.58)}
.public-status-chip.silence,.public-card-status-chip.silence,.public-status-chip.stun,.public-card-status-chip.stun,.public-status-chip.cooldown,.public-card-status-chip.cooldown{--status-bg:rgba(101,78,136,.26);--status-border:rgba(159,126,209,.56)}
.public-status-chip.poison,.public-card-status-chip.poison,.public-status-chip.necro,.public-card-status-chip.necro{--status-bg:rgba(82,44,107,.3);--status-border:rgba(157,92,199,.58)}
.public-status-chip.bleed,.public-card-status-chip.bleed{--status-bg:rgba(170,43,67,.26);--status-border:rgba(235,83,111,.58)}
@media(max-width:900px){.public-status-chip em,.public-card-status-chip em{display:none}}




/* =========================================================
   PHASE 3D.19 • PUBLIC CARD STATUS VISUAL FX
========================================================= */
.formation-slot { isolation:isolate; }
.public-card-fx-stack,
.public-card-fx-layer { position:absolute; inset:0; pointer-events:none; }
.public-card-fx-stack { z-index:50; overflow:hidden; border-radius:22px; }
.public-card-fx-layer { display:block; border-radius:inherit; }

.public-card-fx-stack .fx-fusion-layer {
  inset:-20%;
  background:conic-gradient(from 0deg,transparent,rgba(75,219,255,.22),rgba(151,82,255,.34),transparent,rgba(244,91,205,.24),transparent);
  filter:blur(15px);
  animation:publicFusionSpin 6.5s linear infinite;
}
.public-card-fx-stack .fx-necro-layer {
  background:radial-gradient(circle at 15% 90%,rgba(121,36,190,.28),transparent 34%),radial-gradient(circle at 85% 16%,rgba(78,24,145,.22),transparent 30%),radial-gradient(circle at 50% 110%,rgba(38,7,75,.32),transparent 46%);
  animation:publicNecroPulse 2.8s ease-in-out infinite;
}
.public-card-fx-stack .fx-defense-layer {
  inset:0;
  background:radial-gradient(ellipse at 50% 55%,rgba(76,184,255,.08),transparent 68%);
  box-shadow:inset 0 -14px 24px -23px rgba(50,168,255,.58);
  animation:publicDefensePulse 1.55s ease-in-out infinite;
}
.public-card-fx-stack .fx-shield-layer {
  z-index:3;
  background:linear-gradient(135deg,rgba(186,239,255,.13),rgba(255,255,255,.025) 42%,rgba(109,209,245,.12));
  box-shadow:inset 0 0 0 2px rgba(190,239,255,.50),inset 0 0 26px rgba(91,207,255,.12),0 0 18px rgba(80,196,246,.22);
  backdrop-filter:blur(1px) saturate(1.08);
}
.public-card-fx-stack .fx-shield-layer::before {
  content:"";position:absolute;top:-35%;left:-55%;width:46%;height:175%;transform:rotate(20deg);background:linear-gradient(to right,transparent,rgba(255,255,255,.32),transparent);animation:publicShieldSweep 2.7s ease-in-out infinite;
}
.public-card-fx-stack .fx-burn-layer {
  background:radial-gradient(circle at 18% 100%,rgba(255,83,20,.36),transparent 26%),radial-gradient(circle at 52% 108%,rgba(255,164,24,.30),transparent 32%),radial-gradient(circle at 86% 100%,rgba(223,50,18,.32),transparent 26%);
  animation:publicBurnFlicker .85s ease-in-out infinite alternate;
}
.public-card-fx-stack .fx-freeze-layer {
  background:linear-gradient(135deg,rgba(177,233,255,.22),transparent 32%,rgba(113,193,239,.14) 72%,rgba(220,249,255,.18)),radial-gradient(circle at 0 0,rgba(233,252,255,.38),transparent 28%),radial-gradient(circle at 100% 100%,rgba(186,231,255,.30),transparent 30%);
  box-shadow:inset 0 0 25px rgba(133,212,255,.26);
}
.public-card-fx-stack .fx-poison-layer {
  background:radial-gradient(circle at 20% 78%,rgba(101,194,77,.22),transparent 25%),radial-gradient(circle at 72% 22%,rgba(137,57,173,.22),transparent 28%),radial-gradient(circle at 82% 86%,rgba(79,164,61,.20),transparent 22%);
  animation:publicPoisonDrift 2.4s ease-in-out infinite alternate;
}
.public-card-fx-stack .fx-stun-layer {
  background:repeating-linear-gradient(118deg,transparent 0 24px,rgba(255,217,73,.18) 25px 27px,transparent 28px 52px);
  mix-blend-mode:multiply;
  animation:publicStunFlash .72s steps(2,end) infinite;
}
.public-card-fx-stack .fx-curse-layer {
  background:radial-gradient(ellipse at 50% 55%,rgba(65,40,105,.22),transparent 62%),linear-gradient(145deg,transparent 36%,rgba(20,16,43,.18) 50%,transparent 68%);
  animation:publicCurseDrift 2.8s ease-in-out infinite alternate;
}

@keyframes publicFusionSpin{to{transform:rotate(360deg)}}
@keyframes publicNecroPulse{0%,100%{opacity:.62;transform:scale(1)}50%{opacity:1;transform:scale(1.035)}}
@keyframes publicDefensePulse{0%,100%{opacity:.62}50%{opacity:1}}
@keyframes publicDefenseSpin{to{transform:rotate(360deg)}}
@keyframes publicShieldSweep{0%{transform:translateX(0) rotate(20deg);opacity:0}20%{opacity:.8}100%{transform:translateX(360%) rotate(20deg);opacity:0}}
@keyframes publicBurnFlicker{from{opacity:.58;filter:brightness(.92)}to{opacity:1;filter:brightness(1.16)}}
@keyframes publicPoisonDrift{from{transform:translate3d(-2px,2px,0) scale(1);opacity:.62}to{transform:translate3d(3px,-3px,0) scale(1.04);opacity:.92}}
@keyframes publicStunFlash{0%,100%{opacity:.22}50%{opacity:.82}}
@keyframes publicCurseDrift{from{opacity:.35;transform:translateY(2px)}to{opacity:.78;transform:translateY(-3px)}}
@media(prefers-reduced-motion:reduce){.public-card-fx-layer,.public-card-fx-layer::before,.public-card-fx-layer::after{animation-duration:.01ms!important;animation-iteration-count:1!important}}


/* PHASE 3D.20: status visibility and true viewport-aware spectator card sizing. */
.public-active-field {
  min-width: 0; min-height:0;
  grid-template-rows: clamp(82px, 12.3vh, 140px) minmax(0,1fr);
  overflow: hidden;
}
.battle-header { min-height:0; grid-template-columns:minmax(0,1fr) clamp(150px,15vw,245px) minmax(0,1fr); }
.player-hud { min-height:0; padding:clamp(5px,.9vh,14px) clamp(6px,.9vw,18px); gap:clamp(4px,.7vw,12px); }
.player-name-row strong { font-size:clamp(13px,1.15vw,23px); }
.center-brand strong { font-size:clamp(20px,2.05vw,38px); }
.field-side { min-height:0; padding:clamp(5px,.8vh,15px) clamp(5px,.7vw,12px); grid-template-rows:auto minmax(0,1fr) clamp(17px,2.7vh,36px); }
.formation-stage { min-width:0; min-height:0; container-type:size; }
.formation-grid { row-gap:clamp(5px,1vh,12px); column-gap:clamp(4px,.65vw,10px); max-height:100%; }
/* Override old vh / vw minimums, which clipped cards on TVs and shorter browser windows. */
.formation-1 :deep(.battle-card), .formation-2 :deep(.battle-card),
.formation-3 :deep(.battle-card), .formation-4 :deep(.battle-card),
.formation-5 :deep(.battle-card), .formation-6 :deep(.battle-card),
.formation-7 :deep(.battle-card), .formation-8 :deep(.battle-card) {
  width: var(--tv-card-w) !important;
  height: var(--tv-card-h) !important;
  min-height:0 !important; min-width:0 !important;
  max-width:var(--tv-card-w);
  max-height:var(--tv-card-h);
}
.formation-slot :deep(.stat strong) { font-size:clamp(12px, calc(var(--tv-card-w) * .115), 27px) !important; }
.formation-slot :deep(.stat-copy strong) { font-size:clamp(12px, calc(var(--tv-card-w) * .11), 24px) !important; }
.formation-slot :deep(.card-title strong),
.formation-slot :deep(.title-hud h2) {
  font-size:clamp(10px, calc(var(--tv-card-w) * .084), 21px) !important;
  line-height:1.1 !important;
}
.public-card-statuses { z-index:70; gap:3px; }
.public-card-status-chip { min-height:22px; padding:4px 6px; border:1px solid var(--status-border, rgba(255,255,255,.7));
  background:var(--status-bg, rgba(33,64,85,.8)); color:#142d41; }
.public-card-status-chip em { font-size:clamp(7px,.67vw,10px); }
.public-card-status-chip small { font-size:clamp(7px,.60vw,10px); }
.public-status-chip em {font-size:clamp(7px,.65vw,10px);}
.public-status-chip small {font-size:clamp(7px,.6vw,10px);}
@media(max-height:720px) {
  .public-active-field {grid-template-rows:clamp(72px,12.1vh,98px) minmax(0,1fr);}
  .field-side {padding-top:4px;padding-bottom:4px;grid-template-rows:auto minmax(0,1fr) 18px;}
  .field-title {margin:0;}
}
@media(max-width:900px) {
  .battle-header {grid-template-columns:minmax(0,1fr) 110px minmax(0,1fr);}
  .player-hud {padding:4px;gap:4px;}
  .avatar {width:30px;height:30px;flex:0 0 30px;}
  .public-card-status-chip em {display:none;}
}
@media(prefers-reduced-motion:reduce) {
}

</style>
