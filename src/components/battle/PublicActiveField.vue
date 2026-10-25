<script setup>
import {
  computed,
  nextTick,
  onMounted,
  onUnmounted,
  onUpdated,
  ref,
} from "vue";
import PublicDisplayCard from "./PublicDisplayCard.vue";
import PublicRosterZone from './PublicRosterZone.vue';
import PublicLiveViewer from './PublicLiveViewer.vue';
import { publicBattleActivity, battleCardId } from '../../utils/publicBattleActivity.js';
import TbcEmblem from "./TbcEmblem.vue";
import CardStatusVfx from "./CardStatusVfx.vue";
import { normalizeBattleStatusKey } from "../../composables/battle/elementalStatus.js";
import { normalizePublicBattleLayout } from "../../utils/publicBattleLayouts.js";
const props = defineProps({
  actionToast: { type: Object, default: null },
  spotlight: { type: Object, default: () => ({ p1: null, p2: null }) },
  liveUi: { type: Object, default: () => ({}) },
  layout: { type: String, default: 'center_duel' },
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
  player1Bench: { type: Array, default: () => [] },
  player2Bench: { type: Array, default: () => [] },
  player1Graveyard: { type: Array, default: () => [] },
  player2Graveyard: { type: Array, default: () => [] },
  player1GraveyardCount: { type: Number, default: 0 },
  player2GraveyardCount: { type: Number, default: 0 },
  player1DeckRemaining: { type: Number, default: 0 },
  player2DeckRemaining: { type: Number, default: 0 },
  announcement: { type: Object, default: null },
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
// Query the current DOM so switching the spotlight cannot leave stale card refs.
const stageRootRef = ref(null);
const cardRectCache = new Map();
const rectToPlainObject = (rect) => rect ? {
  left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom,
  width: rect.width, height: rect.height, x: rect.x, y: rect.y,
  centerX: rect.left + rect.width / 2, centerY: rect.top + rect.height / 2,
} : null;
const cardElementKey = (player, cardId) => `${player}:${String(cardId)}`;
const captureCardRects = () => {
  for (const element of stageRootRef.value?.querySelectorAll('[data-card-id]') ?? []) {
    const rect = element.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      cardRectCache.set(cardElementKey(element.dataset.player, element.dataset.cardId), rectToPlainObject(rect));
    }
  }
};
const getCardRect = (player, cardId) => {
  if (!player || cardId == null) return null;
  const matches = [...(stageRootRef.value?.querySelectorAll('[data-card-id]') ?? [])]
    .filter(el => el.dataset.player === player && el.dataset.cardId === String(cardId));
  const element = matches.find(el => el.dataset.featured === 'true') ?? matches[0];
  const key = cardElementKey(player, cardId);
  if (element) {
    const rect = element.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      const plain = rectToPlainObject(rect);
      cardRectCache.set(key, plain);
      return plain;
    }
  }
  // Keep the last visible target for the destruction animation after a card leaves play.
  return cardRectCache.get(key) ?? null;
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
  studio_shield: {icon:'🛡',label:'SHIELD',tone:'water'},
  studio_defense: {icon:'🛡',label:'DEF UP',tone:'defense'},
  studio_team_defense: {icon:'🛡',label:'TEAM DEF',tone:'defense'},
  studio_attack_buff: {icon:'⚔',label:'ATK UP',tone:'power'},
  studio_attack_debuff: {icon:'↓',label:'ATK DOWN',tone:'debuff'},
  studio_defense_debuff: {icon:'↓',label:'DEF DOWN',tone:'debuff'},
  studio_reduction: {icon:'🛡',label:'DAMAGE GUARD',tone:'defense'},
  studio_mark: {icon:'◎',label:'MARKED',tone:'debuff'},
  studio_delayed_heal: {icon:'+',label:'REGEN',tone:'regen'},
  studio_silence_slot2: {icon:'🔒',label:'SKILL 2 LOCK',tone:'silence'},
  studio_revival_lock: {icon:'⌛',label:'REVIVE WAIT',tone:'cooldown'},
  root: {icon:'🌿',label:'ROOT',tone:'debuff'},
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
    defense: keys.has('studio_defense') || keys.has('studio_team_defense') || keys.has("defense") || (belongsToP1 && p1Defending.value) || (belongsToP2 && p2Defending.value),
    shield: keys.has('studio_shield') || keys.has('studio_reduction') || keys.has("shield") || keys.has("water_shield") || keys.has("synergy_shield") ||
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
const resolvedLayout = computed(() => normalizePublicBattleLayout(props.layout));
const currentTurn = computed(() => {
  const value = String(props.battle?.current_turn ?? '').trim().toLowerCase();
  if (['p1', 'player1', 'player_1'].includes(value)) return 'p1';
  if (['p2', 'player2', 'player_2'].includes(value)) return 'p2';
  return null;
});
const liveTurn = computed(() => props.battle?.status === 'battle' && !props.battle?.winner ? currentTurn.value : null);
const actionPointsEnabled = computed(() =>
  String(props.battle?.ruleset ?? "").toLowerCase() === "tcg_v1" &&
  Boolean(props.battle?.action_points_enabled),
);
const actionPointsPerTurn = computed(() =>
  Math.max(1, Math.min(10, Number(props.battle?.action_points_per_turn ?? 3) || 3)),
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
    if (props.battle?.status === 'finished') return 'BATTLE FINISHED';
    if (!liveTurn.value) return 'WAITING FOR PLAYERS';
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
const failedAvatarImages = ref({ p1: "", p2: "" });
/* =========================================================
   POSITION CAPTURE
========================================================= */
let captureFrame = 0;
const scheduleCapture = async () => {
  await nextTick();
  cancelAnimationFrame(captureFrame);
  captureFrame = requestAnimationFrame(captureCardRects);
};
onMounted(() => {
  void scheduleCapture();
  window.addEventListener('resize', scheduleCapture, { passive: true });
});
onUpdated(scheduleCapture);
onUnmounted(() => {
  cancelAnimationFrame(captureFrame);
  window.removeEventListener('resize', scheduleCapture);
});

const liveActivity = computed(() => publicBattleActivity(props.battle, props.liveUi, {
  p1: { active: props.player1Active, bench: props.player1Bench, graveyard: props.player1Graveyard },
  p2: { active: props.player2Active, bench: props.player2Bench, graveyard: props.player2Graveyard },
}));
const featuredCard = (id, cards) => {
  const fx = props.combatFx;
  const focusId = fx?.active
    ? (fx.sourcePlayer === id ? fx.attackerCardId : fx.targetPlayer === id ? fx.targetCardId : null)
    : null;
  return cards.find(card => String(getCardId(card)) === String(focusId))
    ?? cards.find(card => String(getCardId(card)) === String(props.spotlight[id]?.cardId))
    ?? cards[0] ?? null;
};
const players = computed(() => ['p1', 'p2'].map((id, index) => {
  const first = index === 0;
  const cards = first ? props.player1Active : props.player2Active;
  const bench = first ? props.player1Bench : props.player2Bench;
  const featured = featuredCard(id, cards);
  const statuses = [...cardStatusEffects(featured), ...playerStatusEffects(id)];
  const flags = featured ? cardFxFlags(featured) : {};
  return {
    id, index, cards, bench, featured, statuses, flags,
    isTurn: liveTurn.value === id,
    name: first ? p1Name.value : p2Name.value,
    avatar: first ? p1Avatar.value : p2Avatar.value,
    hp: first ? p1Hp.value : p2Hp.value,
    maxHp: first ? p1MaxHp.value : p2MaxHp.value,
    hpPercent: first ? p1HpPercent.value : p2HpPercent.value,
    ap: first ? player1ActionPoints.value : player2ActionPoints.value,
    skill: first ? p1Skill.value : p2Skill.value,
    graveyard: first ? props.player1GraveyardCount : props.player2GraveyardCount,
    deck: first ? props.player1DeckRemaining : props.player2DeckRemaining,
    callout: flags.burn ? { icon: '🔥', label: 'Burn!', tone: 'burn' }
      : flags.shield || flags.defense ? { icon: '♢', label: 'Shield!', tone: 'shield' }
      : flags.freeze ? { icon: '❄', label: 'Freeze!', tone: 'freeze' }
      : flags.poison ? { icon: '☠', label: 'Poison!', tone: 'poison' }
      : flags.stun ? { icon: 'ϟ', label: 'Stun!', tone: 'stun' }
      : null,
  };
}));
const setPlayerRef = (kind, player, element) => {
  const refs = {
    hud: [p1HudRef, p2HudRef], avatar: [p1AvatarRef, p2AvatarRef],
    field: [p1FieldRef, p2FieldRef], stage: [p1StageRef, p2StageRef],
  };
  refs[kind][player === 'p1' ? 0 : 1].value = element;
};
const summaryRows = computed(() => {
  const rows = players.value.flatMap(player => {
    if (player.callout) return [{
      icon: player.callout.tone === 'shield' ? '🛡' : player.callout.icon,
      text: `${player.featured?.name ?? player.name} ${player.callout.tone === 'shield' ? 'gains' : 'is affected by'}`,
      highlight: player.callout.label,
      tone: player.callout.tone,
    }];
    return player.statuses.slice(0, 1).map(status => ({
      icon: status.icon,
      text: `${player.featured?.name ?? player.name} ·`,
      highlight: status.label,
      tone: status.tone,
    }));
  });
  if (props.announcement) rows.unshift({
    icon: props.announcement.icon,
    text: props.announcement.title,
    highlight: props.announcement.message,
    tone: props.announcement.tone,
  });
  if (liveActivity.value) rows.unshift({ icon: '●', text: `${liveActivity.value.playerName} · ${liveActivity.value.message}`, highlight: liveActivity.value.card?.name ?? '', tone: 'live' });
  if (!rows.length) rows.push({ icon: '✦', text: turnText.value, highlight: '', tone: 'turn' });
  if (rows.length === 1) rows.push({
    icon: '⚔', text: players.value.map(player => player.featured?.name ?? player.name).join('  vs  '),
    highlight: '', tone: 'match',
  });
  return rows.slice(0, 2);
});
</script>

<template>
  <section ref="stageRootRef" class="tbc-stage" :class="[`tbc-layout-${resolvedLayout}`, { 'tbc-live': liveTurn }]" aria-label="Live battle arena">
    <div class="tbc-top-ribbon" aria-hidden="true"></div>
    <div class="tbc-arena-floor" aria-hidden="true"><i></i><i></i></div>
    <div class="tbc-stage-frame" aria-hidden="true"></div>
    <header v-if="resolvedLayout !== 'center_duel'" class="tbc-broadcast-header">
      <TbcEmblem /><span>PUBLIC SPECTATOR <strong>BATTLE VIEW</strong></span>
      <small><i></i> LIVE</small>
    </header>
    <div v-if="resolvedLayout === 'stadium'" class="tbc-scoreboard-rig" aria-hidden="true"></div>
    <div v-if="resolvedLayout === 'stadium'" class="tbc-stadium-pennants" aria-hidden="true">
      <div v-for="side in ['left', 'right']" :key="side" :class="side"><TbcEmblem /><strong>TBC</strong><span>TIMEDOOR<br>ACADEMY</span></div>
    </div>

    <section class="tbc-brand" aria-label="Timedoor Battle Cards">
      <div class="tbc-brand-plaque"><TbcEmblem class="tbc-compass" /><strong>TBC</strong><span>TIMEDOOR BATTLE CARDS</span></div>
      <div class="tbc-round">Round {{ battle.round ?? 1 }}</div>
      <span class="tbc-turn" :class="liveTurn" aria-live="polite">{{ turnText }}</span>
    </section>

    <template v-for="player in players" :key="player.id">
      <section :ref="el => setPlayerRef('hud', player.id, el)" class="tbc-hud" :class="[player.id, { 'is-turn': player.isTurn }]" :aria-label="`${player.name}, HP ${player.hp} / ${player.maxHp}${player.isTurn ? ', giliran aktif' : ''}`">
        <div class="tbc-hud-shape" aria-hidden="true"></div>
        <svg class="tbc-hud-trim" viewBox="0 0 500 230" preserveAspectRatio="none" aria-hidden="true">
          <path d="M13 17 354 48 367 62 391 63 410 82M17 27 335 54 351 72 347 91 363 106 353 127 367 141 350 163 358 179 341 216M47 22 59 40 41 52 56 64M195 44 207 60 190 78 202 91 187 112M396 83 456 132 449 144 475 174 469 206 353 209" />
          <path d="m21 18 11 2-6 8-8-2ZM391 62l9 2 8 12-9-1Z" />
        </svg>
        <div :ref="el => setPlayerRef('avatar', player.id, el)" class="tbc-portrait">
          <img v-if="isAvatarImage(player.avatar) && failedAvatarImages[player.id] !== player.avatar" class="tbc-custom-portrait" :src="player.avatar" :alt="player.name" @error="failedAvatarImages[player.id] = player.avatar" />
          <div v-else class="tbc-trainer-sprite" :class="player.id" aria-hidden="true"></div>
          <span v-if="player.avatar && !isAvatarImage(player.avatar)" class="tbc-avatar-badge" :title="player.name">{{ player.avatar }}</span>
        </div>
        <div class="tbc-hud-info">
          <h2>{{ player.name }}</h2>
          <div class="tbc-hp-label"><span>HP</span><strong>{{ player.hp }}<small>/{{ player.maxHp }}</small></strong></div>
          <div class="tbc-hp-track" role="meter" :aria-label="`${player.name} HP`" :aria-valuenow="player.hp" :aria-valuemin="0" :aria-valuemax="player.maxHp"><i :style="{ width: `${player.hpPercent}%` }"></i></div>
          <div v-if="actionPointsEnabled" class="tbc-ap" :aria-label="`AP ${player.ap} / ${actionPointsPerTurn}`"><b>AP</b><span class="tbc-ap-orbs"><i v-for="point in actionPointsPerTurn" :key="point" :class="{ filled: point <= player.ap }"></i></span><strong>{{ player.ap }}/{{ actionPointsPerTurn }}</strong></div>
          <div v-else class="tbc-ultimate"><b>ULT</b><span><i :style="{ width: `${player.skill}%` }"></i></span><strong>{{ player.skill }}%</strong></div>
        </div>
        <span v-if="player.isTurn" class="tbc-active-turn"><i></i> CURRENT TURN</span>
      </section>

      <aside class="tbc-roster" :class="[player.id, { 'is-live-roster': liveActivity?.side === player.id, 'empty-bench': !player.bench.length, 'empty-active': !player.cards.length }]" :aria-label="`${player.name} cards`">
        <div class="tbc-roster-heading"><strong>{{ player.name }}</strong><span>FIELD</span></div>
        <div class="tbc-roster-zones">
          <PublicRosterZone :cards="player.cards" zone="active" :player="player.id" :capacity="Number(battle.max_active ?? 4)" :featured-id="getCardId(player.featured)" :inspected-id="liveActivity?.cardSide === player.id && liveActivity?.kind !== 'viewer' ? battleCardId(liveActivity.card) : null" :live="liveActivity?.cardSide === player.id && liveActivity?.kind !== 'viewer'" />
          <PublicRosterZone :cards="player.bench" zone="bench" :player="player.id" :capacity="Number(battle.max_bench ?? 4)" :inspected-id="liveActivity?.side === player.id && liveActivity?.zone === 'bench' ? battleCardId(liveActivity.card) : null" :live="liveActivity?.side === player.id && liveActivity?.zone === 'bench'" />
        </div>
        <div class="tbc-roster-counts"><span>DECK <b>{{ player.deck }}</b></span><span :class="{ 'live-graveyard': liveActivity?.side === player.id && liveActivity?.zone === 'graveyard' }">GRAVEYARD <b>{{ player.graveyard }}</b></span></div>
      </aside>

      <section :ref="el => setPlayerRef('field', player.id, el)" class="tbc-hero" :class="[player.id, { 'tbc-burning': player.flags.burn, 'tbc-protected': player.flags.shield || player.flags.defense }]" :aria-label="`${player.name} active card`">
        <div :ref="el => setPlayerRef('stage', player.id, el)" class="tbc-hero-stage">
          <div class="tbc-card-aura" aria-hidden="true"></div>
          <i v-if="player.featured" class="tbc-energy-ring ring-back" aria-hidden="true"></i>
          <div :key="getCardId(player.featured) ?? 'empty'" :data-card-id="getCardId(player.featured)" :data-player="player.id" data-featured="true" class="tbc-featured-card" :class="getCombatSlotClasses(player.id, player.featured)">
            <PublicDisplayCard :card="player.featured" :statuses="player.statuses" />
            <CardStatusVfx v-if="player.featured"
              :shield="player.flags.shield" :defense="player.flags.defense"
              :burn="player.flags.burn" :freeze="player.flags.freeze"
              :stun="player.flags.stun" :poison="player.flags.poison" :curse="player.flags.curse" />
          </div>
          <i v-if="player.featured" class="tbc-energy-ring ring-front" aria-hidden="true"></i>
          <svg v-if="player.flags.shield || player.flags.burn || player.flags.defense" class="tbc-status-swirl" viewBox="0 0 400 500" preserveAspectRatio="none" aria-hidden="true">
            <path d="M56 172C-35 98 255 60 348 142C413 198 102 238 32 292C-28 338 165 437 354 335" />
            <path d="M66 194C-8 130 241 105 336 159M43 306C93 353 260 382 338 339M20 365C102 431 299 408 366 367" />
            <path d="m31 232 4 11 12 2-11 5-2 12-5-11-12-2 11-5Zm327-117 4 10 11 3-10 4-3 11-4-10-11-3 10-4ZM70 402l3 8 9 2-8 4-2 8-4-8-8-2 8-3Z" />
          </svg>
          <div v-if="player.callout" class="tbc-status-callout" :class="player.callout.tone">
            <svg v-if="player.callout.tone === 'shield'" class="tbc-status-emblem" viewBox="0 0 80 100" aria-hidden="true"><path d="M40 5C30 17 15 20 7 20V48C7 70 23 87 40 96C57 87 73 70 73 48V20C57 20 47 13 40 5Z" fill="#27bdff" stroke="#e4ffff" stroke-width="5"/><path d="M40 24C31 31 24 33 21 33V48C21 61 28 73 40 82V24Z" fill="#e4ffff"/></svg>
            <svg v-else-if="player.callout.tone === 'burn'" class="tbc-status-emblem" viewBox="0 0 80 100" aria-hidden="true"><path d="M47 4C53 30 20 31 26 52C30 48 35 42 37 35C40 51 66 52 67 72C68 91 49 97 37 96C9 93 1 70 20 46C18 57 21 62 25 64C15 38 39 30 47 4Z" fill="#e82810" stroke="#fff9ce" stroke-width="4"/><path d="M42 48C46 65 28 66 30 78C32 91 53 92 56 78C60 64 46 65 42 48Z" fill="#ffe74d"/></svg>
            <span v-else>{{ player.callout.icon }}</span><strong>{{ player.callout.label }}</strong>
          </div>
        </div>
      </section>
    </template>

    <PublicLiveViewer v-if="liveActivity?.kind === 'viewer'" :activity="liveActivity" />

    <section class="tbc-battle-log" aria-label="Battle events" aria-live="polite">
      <Transition name="tbc-toast" mode="out-in">
        <div v-if="actionToast" :key="actionToast.key" class="tbc-action-toast" :class="actionToast.player" role="status">
          <span class="tbc-toast-icon" aria-hidden="true">{{ actionToast.icon }}</span>
          <div class="tbc-toast-copy"><small>{{ actionToast.playerName }} <span>· {{ actionToast.title }}</span></small><strong>{{ actionToast.message }}</strong></div>
          <i class="tbc-toast-progress" :style="{ animationDuration: `${actionToast.duration}ms` }" aria-hidden="true"></i>
        </div>
      </Transition>
      <h3 v-if="resolvedLayout === 'side_panel' || resolvedLayout === 'stadium'">BATTLE LOG <span>ROUND {{ battle.round ?? 1 }}</span></h3>
      <div v-for="(row, index) in summaryRows" :key="index" class="tbc-log-row" :class="row.tone"><span class="tbc-log-icon">{{ row.icon }}</span><span>{{ row.text }} <strong>{{ row.highlight }}</strong></span></div>
    </section>
    <div class="tbc-corner-brand" aria-hidden="true"><TbcEmblem class="tbc-corner-compass" /><strong>TBC</strong><small>TIMEDOOR BATTLE CARDS</small></div>
  </section>
</template>

<style scoped>
.tbc-stage { --gold:#f5d577; --navy:#071a43; --blue:#2dd4ff; --purple:#b44aff; position:relative; isolation:isolate; width:100%; height:100%; overflow:hidden; color:white; font-family:'Arial Narrow','Trebuchet MS',Arial,sans-serif; background:#55a7e2 url('/images/tbc-battle-background.png') center / cover no-repeat; }
.tbc-stage * { box-sizing:border-box; }
.tbc-stage-frame { position:absolute; z-index:10; inset:.5%; pointer-events:none; border:.45cqw solid transparent; border-image:linear-gradient(130deg,#ffed9c,#9b632e 16%,#fce18c 42%,#9f6f32 62%,#ffe69b) 1; box-shadow:inset 0 0 0 .2cqw #253353,inset 0 0 2cqw #061e5570; clip-path:polygon(0 0,100% 0,100% 100%,0 100%); }
.tbc-top-ribbon { position:absolute; top:0; left:1%; width:98%; height:16%; background:linear-gradient(155deg,#f8df8c 0 2%,#152544 3% 35%,#bd9047 36% 38%,#152544 40% 61%,#e9bd62 62% 65%,#14263e 67% 96%,#efd286 97%); clip-path:polygon(0 0,28% 42%,40% 56%,50% 36%,61% 56%,74% 38%,100% 0,98% 28%,73% 66%,61% 81%,50% 60%,39% 81%,27% 68%,2% 29%); }
.tbc-brand { position:absolute; z-index:6; left:38.5%; top:4%; width:23%; height:29%; text-align:center; filter:drop-shadow(0 .35cqw .5cqw #0008); }
.tbc-brand-plaque { height:65%; position:relative; padding:1.2cqw .5cqw .5cqw; display:flex; flex-direction:column; align-items:center; justify-content:flex-end; color:var(--gold); background:linear-gradient(135deg,#ffed9b,#a67630 40%,#fff0a2 70%,#ba853a); clip-path:polygon(0 15%,36% 11%,50% 0,64% 11%,100% 15%,87% 100%,13% 100%); }
.tbc-brand-plaque::before { content:''; position:absolute; inset:.25cqw; background:linear-gradient(145deg,#1c3858,#102d50 50%,#061938); clip-path:inherit; z-index:-1; }
.tbc-brand-plaque { isolation:isolate; }
.tbc-compass { position:absolute; top:-.1cqw; width:6cqw; height:4.7cqw; }
.tbc-brand-plaque > strong { font:bold 4.4cqw/.92 Georgia,serif; letter-spacing:-.15cqw; text-shadow:0 .12cqw #7e6130; }
.tbc-brand-plaque > span:last-child { font-size:1.01cqw; font-weight:900; margin-top:.3cqw; }
.tbc-round { position:relative; margin:.7cqw auto 0; width:66%; padding:.45cqw .2cqw; background:var(--gold); clip-path:polygon(8% 0,92% 0,100% 27%,100% 73%,92% 100%,8% 100%,0 73%,0 27%); font-size:2cqw; line-height:1; font-weight:900; color:#ffe695; isolation:isolate; }
.tbc-round::before { content:''; position:absolute; inset:.22cqw; background:#052344; clip-path:inherit; z-index:-1; }
.tbc-turn { display:inline-block; margin-top:.45cqw; padding:.2cqw .65cqw; border-radius:3cqw; color:#fff6d1; background:#06224bbd; font-size:.72cqw; font-weight:800; letter-spacing:.05em; max-width:100%; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.tbc-hud { --accent:var(--blue); position:absolute; z-index:5; top:3.7%; left:1.7%; width:32.6%; height:29.5%; filter:drop-shadow(0 .25cqw .3cqw #09215b99); }
.tbc-hud.p2 { --accent:var(--purple); left:auto; right:1.7%; }
.tbc-hud-shape { position:absolute; inset:0; background:var(--accent); clip-path:polygon(0 0,76% 12%,83% 24%,88% 30%,96% 60%,100% 71%,98% 100%,0 97%); }
.tbc-hud-shape::before { content:''; position:absolute; inset:.25cqw; background:linear-gradient(125deg,#0f64a0d9,#082456 55%,#082048); clip-path:inherit; box-shadow:inset 0 0 1cqw var(--accent); }
.tbc-hud-trim { position:absolute; inset:0; width:100%; height:100%; color:var(--accent); opacity:.5; pointer-events:none; }
.tbc-hud-trim path { fill:none; stroke:currentColor; stroke-width:1.6; }
.tbc-hud-trim path:last-child { fill:currentColor; }
.p2 .tbc-hud-trim { transform:scaleX(-1); }
.tbc-hud-shape::after { content:''; position:absolute; inset:.7cqw; border:.12cqw solid var(--accent); clip-path:inherit; opacity:.75; }
.p2 .tbc-hud-shape { transform:scaleX(-1); }
.p2 .tbc-hud-shape::before { background:linear-gradient(125deg,#7020a7e8,#281453 55%,#271041); }
.tbc-portrait { position:absolute; z-index:2; left:-1%; top:-6%; width:46%; height:108%; overflow:hidden; clip-path:polygon(0 0,100% 0,100% 84%,85% 100%,0 100%); }
.p2 .tbc-portrait { left:auto; right:-1%; width:50%; clip-path:polygon(0 0,100% 0,100% 100%,15% 100%,0 84%); }
.tbc-trainer-sprite { width:100%; height:100%; background-image:url('/images/tbc-trainers.png'); background-size:200% 100%; background-position:left center; background-repeat:no-repeat; filter:drop-shadow(0 0 .3cqw var(--accent)); }
.tbc-trainer-sprite.p2 { background-position:right center; }
.tbc-custom-portrait { height:100%; width:100%; object-fit:cover; object-position:center 25%; }
.tbc-avatar-badge { position:absolute; bottom:3%; left:8%; font-size:1.5cqw; filter:drop-shadow(0 .1cqw .2cqw #000); }
.p2 .tbc-avatar-badge { left:auto; right:8%; }
.tbc-hud-info { position:absolute; top:24%; left:49%; width:47%; }
.p2 .tbc-hud-info { left:4%; }
.tbc-hud-info h2 { margin:0 0 1cqw; padding:0 .3cqw .5cqw; font-size:1.95cqw; font-weight:900; line-height:1.05; text-shadow:0 .14cqw .2cqw #000; border-bottom:.12cqw solid #7ac5ff80; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.p2 .tbc-hud-info h2 { text-align:right; border-color:#cf84ff80; }
.tbc-hp-label { display:flex; justify-content:flex-start; align-items:baseline; gap:2.1cqw; padding:0 .25cqw; line-height:1; }
.tbc-hp-label > span { font-weight:900; font-size:1.65cqw; }
.tbc-hp-label strong { font-family:Arial,sans-serif; font-size:2.65cqw; font-weight:900; letter-spacing:-.05em; }
.p2 .tbc-hp-label { gap:1.5cqw; }
.tbc-hp-label small { font-size:1.45cqw; letter-spacing:-.04em; }
.tbc-hp-track { margin:.5cqw 0; height:1.65cqw; padding:.16cqw; background:#0c2039; border:.13cqw solid #fff0c2; border-radius:.35cqw; box-shadow:0 0 .5cqw #17eaff66; transform:skewX(-4deg); }
.tbc-hp-track > i { display:block; height:100%; border-radius:.12cqw; background:linear-gradient(90deg,#10fa23,#9dff4c); box-shadow:inset 0 .12cqw .2cqw #fff8; transition:width .4s; }
.p2 .tbc-hp-track > i { background:linear-gradient(90deg,#f62a49,#ff6344); }
.tbc-ap,.tbc-ultimate { display:flex; align-items:center; gap:.5cqw; font-size:1.6cqw; line-height:1.2; }
.tbc-ap > b,.tbc-ultimate > b { font-size:1.7cqw; }
.tbc-ap > strong,.tbc-ultimate > strong { font-size:1.35cqw; margin-left:auto; white-space:nowrap; }
.tbc-ap-orbs { display:flex; gap:.35cqw; flex:1; min-width:0; }
.tbc-ap-orbs i { width:1.5cqw; aspect-ratio:1; border-radius:50%; border:.14cqw solid #467cc8; background:#071b47; flex:0 1 1.5cqw; }
.tbc-ap-orbs .filled { border-color:#8df8ff; background:radial-gradient(circle at 38% 28%,white 9%,#bafcff 20%,#26cdff 64%,#1769d5); box-shadow:0 0 .8cqw #16c8ff; }
.p2 .tbc-ap-orbs i { border-color:#8524b4; background:#301052; }
.p2 .tbc-ap-orbs .filled { border-color:#e7aeff; background:radial-gradient(circle at 38% 28%,white 9%,#efc6ff 20%,#c14bff 64%,#6725d7); box-shadow:0 0 .8cqw #bc2eff; }
.tbc-ultimate > span { flex:1; height:.5cqw; background:#030e2a; border-radius:1cqw; overflow:hidden; }
.tbc-ultimate i { display:block; height:100%; background:linear-gradient(90deg,#44eaff,#e9f4ff); }
.p2 .tbc-ultimate i { background:linear-gradient(90deg,#bb46ff,#ffe998); }
.tbc-roster { --accent:var(--blue); position:absolute; z-index:6; left:1.55%; top:34%; width:12.4%; height:35%; padding:.42cqw; background:linear-gradient(135deg,#123b67e8,#081e43e8); border:.2cqw solid var(--accent); border-radius:.5cqw; box-shadow:0 0 .8cqw #43afff66,inset 0 0 .3cqw #72daff; transform:rotate(3deg); }
.tbc-roster.p2 { --accent:var(--purple); left:auto; right:1.55%; transform:rotate(-3deg); background:linear-gradient(225deg,#48226fe8,#251443e8); }
.tbc-roster-counts { display:flex; justify-content:space-between; gap:.3cqw; margin-top:.7cqw; padding:.4cqw; background:#092047d9; border:.1cqw solid #87bfff66; border-radius:.3cqw; font-size:.53cqw; transform:rotate(-3deg); }
.p2 .tbc-roster-counts { transform:rotate(3deg); }
.tbc-roster-counts b { color:var(--gold); font-size:.7cqw; margin-left:.15cqw; }
.tbc-hero { --energy:#32d7ff; position:absolute; z-index:3; left:21%; top:36%; width:17.2%; height:46.5%; }
.tbc-hero.p2 { --energy:#ff8a25; left:auto; right:24.5%; }
.tbc-hero-stage { position:relative; width:100%; height:100%; perspective:80cqw; }
.tbc-featured-card { width:100%; height:100%; position:relative; z-index:3; transform:rotate(-3deg) rotateY(8deg); filter:drop-shadow(0 0 .3cqw white) drop-shadow(0 0 1cqw var(--energy)); transition:filter .25s; }
.p2 .tbc-featured-card { transform:rotate(3deg) rotateY(-8deg); }
.tbc-featured-card :deep(.tbc-card) { height:100%; width:100%; }
.tbc-card-aura { position:absolute; inset:-12% -30%; border-radius:50%; background:radial-gradient(ellipse,color-mix(in srgb,var(--energy) 48%,transparent),transparent 67%); filter:blur(.7cqw); pointer-events:none; }
.tbc-energy-ring { position:absolute; pointer-events:none; left:-37%; top:25%; width:177%; height:47%; border:.22cqw solid transparent; border-top-color:var(--energy); border-bottom-color:#efffff; border-radius:50%; transform:rotate(-17deg); filter:drop-shadow(0 0 .4cqw var(--energy)); box-shadow:0 -.1cqw .4cqw var(--energy),0 .2cqw .8cqw var(--energy); }
.ring-back { z-index:1; top:32%; transform:rotate(16deg); opacity:.75; }
.ring-front { z-index:4; clip-path:polygon(0 48%,100% 48%,100% 100%,0 100%); animation:tbc-ring-glow 2.8s ease-in-out infinite alternate; }
.tbc-status-callout { position:absolute; z-index:7; top:53%; left:89%; display:flex; align-items:center; gap:.45cqw; color:#f7feff; font-size:3.15cqw; font-weight:900; font-style:italic; line-height:1; white-space:nowrap; text-shadow:.13cqw .13cqw #003aa8,-.13cqw -.13cqw #003aa8,0 0 .8cqw #00bdff; filter:drop-shadow(0 0 .5cqw #00caff); }
.tbc-status-callout > span { font-size:5.5cqw; font-style:normal; }
.tbc-status-emblem { width:5.4cqw; height:6.8cqw; overflow:visible; flex:none; }
.tbc-status-swirl { position:absolute; z-index:4; left:-35%; top:-12%; width:170%; height:127%; pointer-events:none; overflow:visible; color:var(--energy); filter:drop-shadow(0 0 .2cqw white) drop-shadow(0 0 .7cqw var(--energy)); }
.tbc-status-swirl path { stroke:currentColor; stroke-width:3; fill:none; }
.tbc-status-swirl path:nth-child(2) { stroke:#f7ffff; stroke-width:1.8; }
.tbc-status-swirl path:last-child { fill:#f3ffff; stroke-width:1; }
.tbc-protected { --energy:#39d6ff; }
.tbc-burning { --energy:#ff7920; }
.tbc-status-callout.burn { text-shadow:.13cqw .13cqw #bb1a00,-.13cqw -.13cqw #bb1a00,0 0 .8cqw #ff6c00; filter:drop-shadow(0 0 .5cqw #ff6200); }
.tbc-arena-floor { position:absolute; inset:71% -15% -31%; pointer-events:none; transform:perspective(35cqw) rotateX(52deg); border-radius:50%; border:.2cqw solid #9cefff; box-shadow:0 0 1cqw #06aaff,inset 0 0 1cqw #0695ff; background:repeating-radial-gradient(ellipse at center,transparent 0 9%,#69c6ff4d 9.3% 9.6%,transparent 10%),repeating-conic-gradient(from 0deg,#66c8ff50 0deg .2deg,transparent .3deg 18deg); opacity:.68; }
.tbc-arena-floor i { position:absolute; inset:18%; border:.1cqw solid #91dbff; border-radius:50%; }
.tbc-arena-floor i:last-child { inset:33%; }
.tbc-battle-log { position:absolute; z-index:8; left:24.8%; bottom:1.8%; width:47%; height:13%; padding:1cqw 2.7cqw; background:linear-gradient(115deg,#173b7c,#08194b); border:.22cqw solid #50adff; outline:.15cqw solid #0c376c; clip-path:polygon(4% 0,96% 0,100% 20%,100% 80%,96% 100%,4% 100%,0 80%,0 20%); box-shadow:inset 0 0 1cqw #3684e588; display:flex; flex-direction:column; justify-content:center; }
.tbc-log-row { display:flex; align-items:center; gap:1.1cqw; min-height:0; height:50%; font-size:1.62cqw; font-weight:800; line-height:1.15; }
.tbc-log-row + .tbc-log-row { border-top:.1cqw solid #4970c277; }
.tbc-log-row > span:last-child { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.tbc-log-row strong { color:#49ddff; font-style:italic; }
.tbc-log-row.burn strong,.tbc-log-row.fire strong { color:#ffce43; text-shadow:0 0 .5cqw #ff3300; }
.tbc-log-icon { font-size:2.05cqw; width:2.1cqw; text-align:center; flex-shrink:0; color:#72e4ff; }
.tbc-corner-brand { position:absolute; z-index:5; bottom:1.5%; right:1%; width:19%; height:12%; padding:1cqw 1cqw .2cqw 3.8cqw; display:flex; flex-direction:column; align-items:center; justify-content:center; background:linear-gradient(140deg,#1a589ccf,#10285de8); border-bottom:.2cqw solid var(--gold); clip-path:polygon(22% 5%,94% 0,100% 25%,100% 100%,0 100%); color:var(--gold); }
.tbc-corner-compass { position:absolute; top:-.3cqw; width:5cqw; height:3cqw; }
.tbc-corner-brand strong { font:bold 3cqw/.9 Georgia,serif; }
.tbc-corner-brand small { font-size:.85cqw; font-weight:900; margin-top:.4cqw; white-space:nowrap; }
.combat-charge { animation:tbc-charge .4s ease-in-out infinite alternate; }
.combat-impact,.combat-damaged { animation:tbc-hit .28s ease-in-out 2; }
.combat-destroyed { opacity:.2; filter:grayscale(1) brightness(2); }
.tbc-active-turn { position:absolute; z-index:4; left:49%; top:12%; display:flex; align-items:center; gap:.35cqw; color:#fff4bf; font:800 .65cqw/1 Arial,sans-serif; letter-spacing:.08em; }
.p2 .tbc-active-turn { left:4%; }
.tbc-active-turn i,.tbc-broadcast-header small i { width:.4cqw; height:.4cqw; border-radius:50%; background:#9affac; box-shadow:0 0 .45cqw #6bffab; }
.tbc-hud.is-turn { filter:drop-shadow(0 0 .45cqw var(--accent)) drop-shadow(0 .25cqw .3cqw #09215b99); }
.tbc-turn.p1 { border-bottom:.15cqw solid var(--blue); }
.tbc-turn.p2 { border-bottom:.15cqw solid var(--purple); }
.tbc-roster-heading { display:none; }
.tbc-broadcast-header { position:absolute; z-index:7; top:2.5%; left:23%; width:54%; height:8%; display:flex; align-items:center; justify-content:center; gap:1.3cqw; background:linear-gradient(110deg,#0b2448,#07172eee); border:.16cqw solid var(--gold); box-shadow:0 .3cqw .9cqw #051c4780,inset 0 0 0 .25cqw #234164; clip-path:polygon(2% 0,98% 0,100% 50%,98% 100%,2% 100%,0 50%); }
.tbc-broadcast-header > svg { width:2.4cqw; height:2.4cqw; color:var(--gold); }
.tbc-broadcast-header > span { font-size:1.5cqw; font-weight:900; letter-spacing:.025em; white-space:nowrap; }
.tbc-broadcast-header > span strong { color:#c8ee87; }
.tbc-broadcast-header small { display:flex; align-items:center; gap:.4cqw; font:800 .63cqw Arial,sans-serif; color:#e8f5ff; }
.tbc-battle-log h3 { margin:0 0 .5cqw; display:flex; justify-content:space-between; font:800 .8cqw Arial,sans-serif; letter-spacing:.08em; color:#ffedb2; }
.tbc-battle-log h3 span { color:#a5b9d8; font-size:.65cqw; }

/* Two horizontal formations with a dedicated spotlight slot in each row. */
.tbc-layout-top_bottom .tbc-top-ribbon { display:none; }
.tbc-layout-top_bottom .tbc-broadcast-header { left:14%; width:72%; height:7.5%; }
.tbc-layout-top_bottom .tbc-brand { left:76%; top:12%; width:20%; height:11%; }
.tbc-layout-top_bottom .tbc-brand-plaque { display:none; }
.tbc-layout-top_bottom .tbc-round { width:80%; margin:0 auto; font-size:1.65cqw; }
.tbc-layout-top_bottom .tbc-turn { font-size:.85cqw; padding:.3cqw .7cqw; }
.tbc-layout-top_bottom .tbc-hud { left:3.2%; right:auto; top:85.5%; width:68%; height:12%; }
.tbc-layout-top_bottom .tbc-hud.p2 { top:12%; }
.tbc-layout-top_bottom .tbc-hud-shape { transform:none; clip-path:polygon(2% 0,98% 0,100% 30%,98% 100%,0 100%,0 25%); }
.tbc-layout-top_bottom .tbc-hud-trim { display:none; }
.tbc-layout-top_bottom .tbc-portrait { top:-10%; left:.5%; right:auto; width:11%; height:110%; clip-path:polygon(0 0,100% 0,100% 85%,83% 100%,0 100%); }
.tbc-layout-top_bottom .tbc-hud-info { top:12%; left:13%; width:82%; height:80%; display:grid; grid-template-columns:38% 1fr; grid-template-rows:42% 37% 21%; column-gap:2cqw; align-items:center; }
.tbc-layout-top_bottom .tbc-hud-info h2 { grid-column:1; grid-row:1; margin:0; padding:0; border:0; text-align:left; font-size:1.3cqw; }
.tbc-layout-top_bottom .tbc-hp-label { grid-row:2; grid-column:1; padding:0; gap:1cqw; }
.tbc-layout-top_bottom .tbc-hp-label > span { font-size:.85cqw; }
.tbc-layout-top_bottom .tbc-hp-label strong { font-size:1.65cqw; }
.tbc-layout-top_bottom .tbc-hp-label small { font-size:1cqw; }
.tbc-layout-top_bottom .tbc-hp-track { grid-row:3; grid-column:1; height:.6cqw; padding:.07cqw; margin:0; width:100%; border-width:.08cqw; }
.tbc-layout-top_bottom .tbc-ap,.tbc-layout-top_bottom .tbc-ultimate { grid-column:2; grid-row:2 / 4; gap:.8cqw; }
.tbc-layout-top_bottom .tbc-ap > b,.tbc-layout-top_bottom .tbc-ultimate > b { font-size:1.2cqw; }
.tbc-layout-top_bottom .tbc-ap-orbs { gap:.4cqw; }
.tbc-layout-top_bottom .tbc-ap-orbs i { width:1.15cqw; flex-basis:1.15cqw; }
.tbc-layout-top_bottom .tbc-ap > strong,.tbc-layout-top_bottom .tbc-ultimate > strong { font-size:1.2cqw; }
.tbc-layout-top_bottom .tbc-active-turn { top:15%; left:56%; font-size:.65cqw; }
.tbc-layout-top_bottom .tbc-roster { left:5%; right:auto; top:63%; width:90%; height:18%; transform:none; padding:.6cqw; border-color:#5382a3; border-radius:.6cqw; background:linear-gradient(90deg,#092c4deb,#092c4d99,#092c4deb); box-shadow:0 .25cqw .8cqw #071b4670,inset 0 0 0 .18cqw #d6b96c50; }
.tbc-layout-top_bottom .tbc-roster.p2 { top:29%; background:linear-gradient(90deg,#251a45eb,#251a4599,#251a45eb); border-color:#96629f; }
.tbc-layout-top_bottom .tbc-roster-counts { position:absolute; top:auto; bottom:-8.3cqw; right:0; width:22%; margin:0; padding:.7cqw; transform:none; font-size:.75cqw; border-color:#d9c380; background:#092340f5; }
.tbc-layout-top_bottom .p2 .tbc-roster-counts { bottom:auto; top:-3.1cqw; }
.tbc-layout-top_bottom .tbc-roster-counts b { font-size:1.15cqw; }
.tbc-layout-top_bottom .tbc-hero { left:45.2%; right:auto; top:60%; width:9.6%; height:25%; z-index:7; }
.tbc-layout-top_bottom .tbc-hero.p2 { top:26%; }
.tbc-layout-top_bottom .tbc-featured-card { transform:none; }
.tbc-layout-top_bottom .tbc-energy-ring { left:-18%; width:136%; border-width:.12cqw; }
.tbc-layout-top_bottom .tbc-status-swirl { left:-20%; width:140%; }
.tbc-layout-top_bottom .tbc-status-callout { top:64%; bottom:auto; left:50%; transform:translateX(-50%); gap:.15cqw; font-size:1.3cqw; }
.tbc-layout-top_bottom .tbc-status-emblem { width:1.8cqw; height:2.3cqw; }
.tbc-layout-top_bottom .tbc-status-callout > span { font-size:2.1cqw; }
.tbc-layout-top_bottom .tbc-battle-log { left:21%; bottom:auto; top:52%; width:58%; height:6.5%; padding:.3cqw 2cqw; border-width:.12cqw; background:linear-gradient(90deg,#09254aeb,#091b40f5,#09254aeb); }
.tbc-layout-top_bottom .tbc-log-row { font-size:.98cqw; gap:.7cqw; }
.tbc-layout-top_bottom .tbc-log-icon { font-size:1.1cqw; width:1.4cqw; }
.tbc-layout-top_bottom .tbc-corner-brand { display:none; }
.tbc-layout-top_bottom .tbc-arena-floor { inset:28% -10% 3%; opacity:.25; }

/* Information stays on the edges; the central arena is reserved for the duel. */
.tbc-layout-side_panel .tbc-top-ribbon { display:none; }
.tbc-layout-side_panel .tbc-brand { left:41%; top:13%; width:18%; height:15%; }
.tbc-layout-side_panel .tbc-brand-plaque { display:none; }
.tbc-layout-side_panel .tbc-round { margin:0 auto; font-size:1.75cqw; width:80%; }
.tbc-layout-side_panel .tbc-turn { font-size:.8cqw; }
.tbc-layout-side_panel .tbc-hud { left:2%; top:14%; width:19%; height:24%; filter:none; }
.tbc-layout-side_panel .tbc-hud.p2 { left:auto; right:2%; }
.tbc-layout-side_panel .tbc-hud-shape { transform:none; clip-path:polygon(5% 0,95% 0,100% 5%,100% 100%,0 100%,0 5%); background:#bfa769; }
.tbc-layout-side_panel .tbc-hud-shape::before { inset:.15cqw; background:linear-gradient(130deg,#183c60,#081b35 80%); box-shadow:none; }
.tbc-layout-side_panel .p2 .tbc-hud-shape::before { background:linear-gradient(230deg,#432b62,#18152d 80%); }
.tbc-layout-side_panel .tbc-hud-trim { display:none; }
.tbc-layout-side_panel .tbc-portrait { top:-3%; left:1%; right:auto; width:43%; height:70%; }
.tbc-layout-side_panel .tbc-hud-info { top:10%; left:6%; width:88%; }
.tbc-layout-side_panel .tbc-hud-info h2 { width:57%; margin:0 0 .7cqw 43%; padding:0 0 .5cqw; font-size:1.4cqw; text-align:left; }
.tbc-layout-side_panel .tbc-hp-label { margin-left:43%; gap:.45cqw; padding:0; }
.tbc-layout-side_panel .tbc-hp-label > span { font-size:.75cqw; }
.tbc-layout-side_panel .tbc-hp-label strong { font-size:1.65cqw; }
.tbc-layout-side_panel .tbc-hp-label small { font-size:.95cqw; }
.tbc-layout-side_panel .tbc-hp-track { margin:1.2cqw 0 .7cqw; height:1.05cqw; }
.tbc-layout-side_panel .tbc-ap,.tbc-layout-side_panel .tbc-ultimate { gap:.55cqw; }
.tbc-layout-side_panel .tbc-ap > b,.tbc-layout-side_panel .tbc-ultimate > b { font-size:1.2cqw; }
.tbc-layout-side_panel .tbc-ap > strong,.tbc-layout-side_panel .tbc-ultimate > strong { font-size:1cqw; }
.tbc-layout-side_panel .tbc-ap-orbs i { width:1cqw; flex-basis:1cqw; }
.tbc-layout-side_panel .tbc-active-turn { top:87%; left:6%; font-size:.6cqw; }
.tbc-layout-side_panel .tbc-hud.is-turn .tbc-hud-shape { background:var(--accent); }
.tbc-layout-side_panel .tbc-roster { left:2%; top:38%; width:19%; height:46%; padding:.85cqw; transform:none; border:.15cqw solid #bfa769; border-top:0; border-radius:0 0 .5cqw .5cqw; background:linear-gradient(#081b35f5,#0b243ff5); box-shadow:0 .5cqw 1cqw #03142e80; }
.tbc-layout-side_panel .tbc-roster.p2 { left:auto; right:2%; background:linear-gradient(#18152df5,#241e3df5); }
.tbc-layout-side_panel .tbc-roster-heading { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:.3cqw; height:2.3cqw; margin-bottom:.4cqw; border-bottom:.1cqw solid #c8ac5a55; }
.tbc-layout-side_panel .tbc-roster-heading strong { font-size:.9cqw; letter-spacing:.06em; color:#ffedb2; }
.tbc-layout-side_panel .tbc-roster-heading span { font-size:.55cqw; color:#b6cce5; }
.tbc-layout-side_panel .tbc-roster-counts { margin-top:.8cqw; transform:none; font-size:.65cqw; padding:.6cqw .4cqw; background:transparent; border:0; border-top:.1cqw solid #d7bb6f55; border-radius:0; }
.tbc-layout-side_panel .tbc-roster-counts b { font-size:.95cqw; }
.tbc-layout-side_panel .tbc-hero { left:29%; top:30%; width:16%; height:43%; }
.tbc-layout-side_panel .tbc-hero.p2 { left:auto; right:29%; }
.tbc-layout-side_panel .tbc-status-callout { left:20%; top:99%; gap:.15cqw; font-size:2.25cqw; }
.tbc-layout-side_panel .tbc-status-emblem { width:3cqw; height:3.8cqw; }
.tbc-layout-side_panel .tbc-status-callout > span { font-size:3cqw; }
.tbc-layout-side_panel .tbc-battle-log { left:24%; width:52%; height:14%; bottom:3%; padding:.8cqw 2cqw; border-color:#d8bd78; background:linear-gradient(110deg,#122e50,#07182ff2); }
.tbc-layout-side_panel .tbc-log-row { font-size:1.13cqw; gap:.6cqw; }
.tbc-layout-side_panel .tbc-log-icon { font-size:1.4cqw; width:1.5cqw; }
.tbc-layout-side_panel .tbc-corner-brand { display:none; }
.tbc-layout-side_panel .tbc-arena-floor { inset:64% 15% -12%; opacity:.5; }

/* A suspended scoreboard and a continuous bottom rail frame the stadium duel. */
.tbc-layout-stadium .tbc-top-ribbon { display:none; }
.tbc-layout-stadium .tbc-broadcast-header { left:20%; width:60%; top:3%; }
.tbc-scoreboard-rig { position:absolute; z-index:2; left:10%; top:15%; width:80%; height:25%; border:.22cqw solid #d9b76d; border-bottom-width:.5cqw; background:linear-gradient(135deg,#233c57,#071932 50%,#233c57); clip-path:polygon(0 0,100% 0,97% 86%,88% 100%,12% 100%,3% 86%); box-shadow:inset 0 0 0 .35cqw #091f3c; }
.tbc-layout-stadium .tbc-brand { left:41.5%; width:17%; top:14%; height:24%; }
.tbc-layout-stadium .tbc-brand-plaque { height:61%; }
.tbc-layout-stadium .tbc-brand-plaque > strong { font-size:3.2cqw; }
.tbc-layout-stadium .tbc-brand-plaque > span:last-child { font-size:.65cqw; }
.tbc-layout-stadium .tbc-compass { width:4.2cqw; height:3.3cqw; }
.tbc-layout-stadium .tbc-round { margin-top:.35cqw; font-size:1.5cqw; width:75%; padding:.3cqw; }
.tbc-layout-stadium .tbc-turn { margin-top:.3cqw; font-size:.65cqw; }
.tbc-layout-stadium .tbc-hud { left:12%; top:16%; width:29%; height:22%; }
.tbc-layout-stadium .tbc-hud.p2 { left:auto; right:12%; }
.tbc-layout-stadium .tbc-hud-info { top:18%; }
.tbc-layout-stadium .tbc-hud-info h2 { margin-bottom:.5cqw; font-size:1.5cqw; padding-bottom:.3cqw; }
.tbc-layout-stadium .tbc-hp-label { gap:.8cqw; }
.tbc-layout-stadium .tbc-hp-label > span { font-size:1cqw; }
.tbc-layout-stadium .tbc-hp-label strong { font-size:2cqw; }
.tbc-layout-stadium .tbc-hp-label small { font-size:1.1cqw; }
.tbc-layout-stadium .tbc-hp-track { height:1.1cqw; margin:.35cqw 0; padding:.1cqw; }
.tbc-layout-stadium .tbc-ap > b,.tbc-layout-stadium .tbc-ultimate > b { font-size:1.1cqw; }
.tbc-layout-stadium .tbc-ap > strong,.tbc-layout-stadium .tbc-ultimate > strong { font-size:1cqw; }
.tbc-layout-stadium .tbc-ap-orbs { gap:.25cqw; }
.tbc-layout-stadium .tbc-ap-orbs i { width:1.05cqw; flex-basis:1.05cqw; }
.tbc-layout-stadium .tbc-active-turn { top:5%; font-size:.55cqw; }
.tbc-layout-stadium .tbc-hero { left:31%; top:42%; width:14.4%; height:37%; }
.tbc-layout-stadium .tbc-hero.p2 { left:auto; right:31%; }
.tbc-layout-stadium .tbc-status-callout { left:42%; top:63%; font-size:2.15cqw; gap:.15cqw; }
.tbc-layout-stadium .tbc-status-emblem { width:2.8cqw; height:3.5cqw; }
.tbc-layout-stadium .tbc-status-callout > span { font-size:2.8cqw; }
.tbc-layout-stadium .tbc-roster { left:3%; top:81%; width:27%; height:16%; transform:none; padding:.65cqw; background:linear-gradient(110deg,#0e3154f5,#091a30f5); border:.15cqw solid #c8ad6d; border-radius:.4cqw; box-shadow:0 .3cqw .8cqw #07142e80; }
.tbc-layout-stadium .tbc-roster.p2 { left:auto; right:3%; background:linear-gradient(250deg,#36214ff5,#18152df5); }
.tbc-layout-stadium .tbc-roster-heading { display:flex; align-items:center; justify-content:space-between; gap:.5cqw; height:1.5cqw; margin-bottom:.4cqw; }
.tbc-layout-stadium .tbc-roster-heading strong { font-size:.9cqw; max-width:44%; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.tbc-layout-stadium .tbc-roster-heading span { font-size:.5cqw; color:#c3d2e5; }
.tbc-layout-stadium .tbc-roster-counts { position:absolute; top:-2.2cqw; right:0; margin:0; transform:none; font-size:.6cqw; padding:.35cqw .6cqw; border-color:#d7bb6f99; }
.tbc-layout-stadium .tbc-roster-counts b { font-size:.85cqw; }
.tbc-layout-stadium .tbc-battle-log { left:31%; width:38%; bottom:3%; height:16%; padding:.8cqw 1.6cqw; border-color:#d8bd78; background:linear-gradient(110deg,#15304b,#07172f); }
.tbc-layout-stadium .tbc-log-row { font-size:1cqw; gap:.6cqw; }
.tbc-layout-stadium .tbc-log-icon { font-size:1.3cqw; width:1.4cqw; }
.tbc-layout-stadium .tbc-corner-brand { display:none; }
.tbc-layout-stadium .tbc-arena-floor { inset:66% 14% -17%; opacity:.5; }
.tbc-stadium-pennants > div { position:absolute; z-index:2; top:21%; left:2.5%; width:7%; height:50%; display:flex; flex-direction:column; align-items:center; gap:1cqw; padding-top:2cqw; color:#ffe49b; background:linear-gradient(90deg,#062d31ee,#0c4c47ed,#092c35ee); border:.22cqw solid #e0be6d; clip-path:polygon(0 0,100% 0,100% 86%,50% 100%,0 86%); }
.tbc-stadium-pennants > .right { left:auto; right:2.5%; }
.tbc-stadium-pennants svg { width:4.7cqw; height:5cqw; }
.tbc-stadium-pennants strong { font:bold 2.3cqw Georgia,serif; margin-top:-2.4cqw; text-shadow:0 .15cqw #092c35; }
.tbc-stadium-pennants span { font:800 .78cqw/1.7 Arial,sans-serif; text-align:center; letter-spacing:.05em; border-top:.1cqw solid #e0be6d66; padding-top:1cqw; }
/* Dedicated areas keep Active and Bench visible even when either is empty. */
.tbc-stage .tbc-roster { display:grid; grid-template-rows:auto minmax(0,1fr) auto; gap:.35cqw; transform:none; padding:.45cqw; }
.tbc-stage .tbc-roster-heading { display:flex; align-items:center; justify-content:space-between; min-width:0; height:auto; gap:.5cqw; margin:0; border:0; }
.tbc-stage .tbc-roster-heading strong { max-width:80%; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; color:#fff4ce; font-size:.85cqw; letter-spacing:.02em; }
.tbc-stage .tbc-roster-heading > span { font-size:.55cqw; color:#b6cce5; }
.tbc-roster-zones { display:grid; grid-template-rows:repeat(2,minmax(0,1fr)); gap:.5cqw; min-height:0; min-width:0; }
.tbc-stage .tbc-roster-counts { position:static; width:auto; transform:none; margin:0; padding:.25cqw .1cqw 0; background:none; border:0; font-size:.62cqw; }
.tbc-stage .tbc-roster-counts b { font-size:.75cqw; }
.tbc-layout-center_duel .tbc-roster { --zone-columns:4; left:1.5%; top:35%; width:24%; height:61%; }
.tbc-layout-center_duel .tbc-roster.p2 { left:auto; right:1.5%; }
.tbc-layout-center_duel .tbc-corner-brand { display:none; }
.tbc-layout-side_panel .tbc-roster { --zone-columns:4; top:38%; width:24%; height:59%; }
.tbc-layout-stadium .tbc-roster { --zone-columns:4; left:2%; top:40%; width:26%; height:57%; }
.tbc-layout-stadium .tbc-roster.p2 { left:auto; right:2%; }
.tbc-layout-stadium .tbc-stadium-pennants > div { height:32%; }
.tbc-layout-top_bottom .tbc-roster { display:block; padding:0; border:0; background:none; box-shadow:none; top:60%; height:25%; }
.tbc-layout-top_bottom .tbc-roster.p2 { top:26%; background:none; }
.tbc-layout-top_bottom .tbc-roster-heading { display:none; }
.tbc-layout-top_bottom .tbc-roster-zones { --zone-columns:4; height:100%; grid-template-rows:minmax(0,1fr); grid-template-columns:minmax(0,1fr) minmax(0,1fr); column-gap:16%; }
.tbc-layout-top_bottom .tbc-roster-counts { position:absolute; right:0; width:22%; bottom:-6.8cqw; padding:.6cqw; border:.1cqw solid #d7bb6f99; background:#092340f5; }
.tbc-layout-top_bottom .p2 .tbc-roster-counts { top:-3.1cqw; bottom:auto; }
.tbc-action-toast { --toast-accent:#f5d577; position:absolute; z-index:2; inset:0; display:flex; align-items:center; gap:1cqw; padding:.8cqw 2.2cqw; background:linear-gradient(110deg,#0e2948,#08172d); border-left:.25cqw solid var(--toast-accent); overflow:hidden; }
.tbc-action-toast.p1 { --toast-accent:#6cddff; }.tbc-action-toast.p2 { --toast-accent:#d09bff; }
.tbc-toast-icon { flex:none; color:var(--toast-accent); font-size:2cqw; }
.tbc-toast-copy { min-width:0; }
.tbc-toast-copy small { display:block; margin-bottom:.35cqw; color:var(--toast-accent); font:800 .75cqw/1.3 Arial,sans-serif; }
.tbc-toast-copy small > span { color:#aec4dc; font-weight:500; }
.tbc-toast-copy > strong { display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:2; overflow:hidden; color:#fff; font:700 1.05cqw/1.35 Arial,sans-serif; overflow-wrap:anywhere; }
.tbc-toast-progress { position:absolute; bottom:0; left:0; width:100%; height:.12cqw; background:var(--toast-accent); transform-origin:left; animation:toast-duration linear forwards; }
.tbc-toast-enter-active,.tbc-toast-leave-active { transition:opacity .18s ease,translate .18s ease; }
.tbc-toast-enter-from,.tbc-toast-leave-to { opacity:0; translate:0 .5cqw; }
.tbc-layout-top_bottom .tbc-action-toast { padding:.35cqw 1.4cqw; gap:.7cqw; }
.tbc-layout-top_bottom .tbc-toast-icon { font-size:1.3cqw; }
.tbc-layout-top_bottom .tbc-toast-copy small { font-size:.65cqw; margin-bottom:.15cqw; }
.tbc-layout-top_bottom .tbc-toast-copy > strong { font-size:.85cqw; -webkit-line-clamp:1; }
@keyframes toast-duration { to { transform:scaleX(0); } }
@keyframes tbc-ring-glow { to { opacity:.6; filter:drop-shadow(0 0 .8cqw var(--energy)); } }
@keyframes tbc-charge { to { filter:brightness(1.35) drop-shadow(0 0 1.5cqw var(--energy)); } }
@keyframes tbc-hit { 50% { translate:.4cqw 0; filter:brightness(1.7); } }
@media(prefers-reduced-motion:reduce) { .tbc-stage * { animation:none!important; transition:none!important; } }
/* Larger team cards use a full row; unused zones reserve only their label. */
.tbc-layout-center_duel .tbc-hero { left:29%; width:17%; }
.tbc-layout-center_duel .tbc-hero.p2 { left:auto; right:29%; }
.tbc-layout-center_duel .tbc-battle-log { left:27%; width:46%; padding:1cqw 1.4cqw; }
.tbc-layout-side_panel .tbc-hud { width:24%; }
.tbc-layout-side_panel .tbc-battle-log { left:27%; width:46%; padding:.8cqw 1.4cqw; }
.tbc-layout-stadium .tbc-stadium-pennants > div { height:25%; }
.tbc-roster.empty-bench .tbc-roster-zones { grid-template-rows:minmax(0,1fr) 4cqw; }
.tbc-roster.empty-active:not(.empty-bench) .tbc-roster-zones { grid-template-rows:4cqw minmax(0,1fr); }
.tbc-layout-top_bottom .tbc-roster.empty-bench .tbc-roster-zones,.tbc-layout-top_bottom .tbc-roster.empty-active .tbc-roster-zones { grid-template-rows:minmax(0,1fr); }
.tbc-roster.is-live-roster { border-color:#ffe695; }
.tbc-roster-counts .live-graveyard { color:#ffe68a; text-decoration:underline; text-underline-offset:.2cqw; }
.tbc-log-row.live .tbc-log-icon { color:#83efbb; font-size:.8cqw; }
.tbc-log-row.live strong { color:#c0eaff; }
</style>
