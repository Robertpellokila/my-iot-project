<script setup>
import {playerBattleAvatar} from '../../utils/playerBattleAvatar.js';
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
import { publicFeaturedCard, publicTurnSeconds, publicTurnSide } from "../../utils/publicBattlePresentation.js";
import CardStatusVfx from "./CardStatusVfx.vue";
import { normalizeBattleStatusKey } from "../../composables/battle/elementalStatus.js";
import { isPublicBattleView } from "../../utils/publicBattleLayouts.js";
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
      ),
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
const resolvedLayout = computed(() => isPublicBattleView(props.layout) ? props.layout : 'center_duel');
const currentTurn = computed(() => publicTurnSide(props.battle));
const clockNow = ref(Date.now());
let clockInterval;
onMounted(() => { clockInterval = setInterval(() => { clockNow.value = Date.now(); }, 250); });
onUnmounted(() => clearInterval(clockInterval));
const secondsRemaining = computed(() => publicTurnSeconds(props.battle, clockNow.value));
const roundLimit = computed(() => props.battle?.max_rounds ?? props.battle?.total_rounds ?? 10);
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
    if (props.battle?.teacher_paused) return 'DIJEDA HOST';
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
const p1Avatar=computed(()=>playerBattleAvatar(props.battle,'p1'));
const p2Avatar=computed(()=>playerBattleAvatar(props.battle,'p2'));
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
const players = computed(() => ['p1', 'p2'].map((id, index) => {
  const first = index === 0;
  const cards = first ? props.player1Active : props.player2Active;
  const bench = first ? props.player1Bench : props.player2Bench;
  const featured = publicFeaturedCard(props.battle, props.liveUi, id, cards, props.combatFx);
  const statuses = [...cardStatusEffects(featured), ...playerStatusEffects(id)];
  const flags = featured ? cardFxFlags(featured) : {};
  return {
    id, index, cards, bench, featured, statuses, flags,
    graveyardCards: first ? props.player1Graveyard : props.player2Graveyard,
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
  <section ref="stageRootRef" class="tbc-stage" :class="[`tbc-layout-${resolvedLayout}`, {'tbc-live':liveTurn,'tbc-paused':battle.teacher_paused}]" aria-label="Live battle arena">
    <div class="tbc-stadium-backdrop" aria-hidden="true"></div>
    <div class="tbc-arena-floor" aria-hidden="true"></div>
    <section class="tbc-brand" aria-label="Status pertandingan">
      <strong v-if="resolvedLayout === 'stadium'" class="tbc-league">TBC</strong>
      <div class="tbc-round">ROUND {{battle.round ?? 1}} / {{roundLimit}}</div>
      <div class="tbc-timer" :class="{urgent:secondsRemaining !== null && secondsRemaining <= 10}" role="timer" aria-label="Waktu giliran"><span aria-hidden="true">{{battle.teacher_paused ? 'Ⅱ' : '◷'}}</span><b>{{secondsRemaining === null ? '—' : secondsRemaining}}<small v-if="secondsRemaining !== null">s</small></b></div>
      <span class="tbc-turn" :class="liveTurn" aria-live="polite">{{turnText}}</span>
    </section>
    <div class="tbc-versus" aria-hidden="true">VS</div>
    <template v-for="player in players" :key="player.id">
      <section :ref="el => setPlayerRef('hud',player.id,el)" class="tbc-hud" :class="[player.id,{'is-turn':player.isTurn}]" :aria-label="`${player.name}, HP ${player.hp} / ${player.maxHp}${player.isTurn ? ', giliran aktif' : ''}`">
        <div :ref="el => setPlayerRef('avatar',player.id,el)" class="tbc-portrait">
          <img v-if="isAvatarImage(player.avatar) && failedAvatarImages[player.id] !== player.avatar" :src="player.avatar" :alt="player.name" @error="failedAvatarImages[player.id] = player.avatar" />
          <span v-else aria-hidden="true">{{!isAvatarImage(player.avatar) && player.avatar ? player.avatar : player.name.slice(0,1)}}</span>
        </div>
        <div class="tbc-hud-info">
          <div class="tbc-player-name"><span>PLAYER {{player.index+1}}</span><h2>{{player.name}}</h2><b v-if="player.isTurn" class="tbc-active-turn">● GILIRAN AKTIF</b></div>
          <div class="tbc-hp-label"><span>HP</span><strong>{{player.hp}} <small>/ {{player.maxHp}}</small></strong></div>
          <div class="tbc-hp-track" role="meter" :aria-label="`${player.name} HP`" :aria-valuenow="player.hp" :aria-valuemin="0" :aria-valuemax="player.maxHp"><i :style="{width:`${player.hpPercent}%`}" :class="{low:player.hpPercent<=25}"></i></div>
          <div class="tbc-ultimate"><b>Ultimate</b><span><i :style="{width:`${player.skill}%`}"></i></span><strong>{{player.skill}}%</strong></div>
          <div v-if="actionPointsEnabled" class="tbc-ap" :aria-label="`AP ${player.ap} / ${actionPointsPerTurn}`"><b>AP</b><span class="tbc-ap-orbs"><i v-for="point in actionPointsPerTurn" :key="point" :class="{filled:point<=player.ap}"></i></span><strong>{{player.ap}} / {{actionPointsPerTurn}}</strong></div>
        </div>
      </section>
      <aside class="tbc-roster" :class="[player.id,{'is-live-roster':liveActivity?.side===player.id}]" :aria-label="`${player.name} cards`">
        <div class="tbc-roster-heading"><strong>{{player.name}} <span>TEAM</span></strong><span>DECK <b>{{player.deck}}</b></span></div>
        <div class="tbc-roster-zones">
          <PublicRosterZone :cards="player.cards" zone="active" :player="player.id" :capacity="maxActive" :featured-id="getCardId(player.featured)" :inspected-id="liveActivity?.cardSide===player.id && liveActivity?.kind!=='viewer' ? battleCardId(liveActivity.card) : null" :live="liveActivity?.cardSide===player.id && liveActivity?.kind!=='viewer'" />
          <PublicRosterZone :cards="player.bench" zone="bench" :player="player.id" :capacity="maxBench" :inspected-id="liveActivity?.side===player.id && liveActivity?.zone==='bench' ? battleCardId(liveActivity.card) : null" :live="liveActivity?.side===player.id && liveActivity?.zone==='bench'" />
          <PublicRosterZone :cards="player.graveyardCards" zone="graveyard" :player="player.id" :inspected-id="liveActivity?.side===player.id && liveActivity?.zone==='graveyard' ? battleCardId(liveActivity.card) : null" :live="liveActivity?.side===player.id && liveActivity?.zone==='graveyard'" />
        </div>
      </aside>
      <section :ref="el => setPlayerRef('field',player.id,el)" class="tbc-hero" :class="[player.id,{'is-turn':player.isTurn,'tbc-burning':player.flags.burn,'tbc-protected':player.flags.shield||player.flags.defense}]" :aria-label="`${player.name} active card`">
        <span class="tbc-hero-label" :class="{'is-turn':player.isTurn}">{{player.isTurn ? '◉ ' : ''}}{{player.name}}{{player.isTurn ? ' · ACTIVE' : ''}}</span>
        <div :ref="el => setPlayerRef('stage',player.id,el)" class="tbc-hero-stage">
          <div class="tbc-card-aura" aria-hidden="true"></div>
          <div :key="getCardId(player.featured) ?? 'empty'" :data-card-id="getCardId(player.featured)" :data-player="player.id" data-featured="true" class="tbc-featured-card" :class="getCombatSlotClasses(player.id,player.featured)">
            <PublicDisplayCard :card="player.featured" :statuses="player.statuses" />
            <CardStatusVfx v-if="player.featured" :shield="player.flags.shield" :defense="player.flags.defense" :burn="player.flags.burn" :freeze="player.flags.freeze" :stun="player.flags.stun" :poison="player.flags.poison" :curse="player.flags.curse" />
          </div>
          <div v-if="player.callout" class="tbc-status-callout" :class="player.callout.tone"><span>{{player.callout.icon}}</span><strong>{{player.callout.label}}</strong></div>
        </div>
      </section>
    </template>
    <PublicLiveViewer v-if="liveActivity?.kind==='viewer'" :activity="liveActivity" />
    <section class="tbc-battle-log" aria-label="Battle events" aria-live="polite">
      <Transition name="tbc-toast" mode="out-in"><div v-if="actionToast" :key="actionToast.key" class="tbc-action-toast" :class="actionToast.player" role="status"><span class="tbc-toast-icon" aria-hidden="true">{{actionToast.icon}}</span><div class="tbc-toast-copy"><small>{{actionToast.playerName}} <span>· {{actionToast.title}}</span></small><strong>{{actionToast.message}}</strong></div><i class="tbc-toast-progress" :style="{animationDuration:`${actionToast.duration}ms`}" aria-hidden="true"></i></div></Transition>
      <div v-for="(row,index) in summaryRows" :key="index" class="tbc-log-row" :class="row.tone"><span class="tbc-log-icon">{{row.icon}}</span><span>{{row.text}} <strong>{{row.highlight}}</strong></span></div>
    </section>
    <div class="tbc-broadcast-badge"><i></i> LIVE <span>{{battle.code}}</span></div>
  </section>
</template>
<style scoped src="./public-arena.css"></style>
