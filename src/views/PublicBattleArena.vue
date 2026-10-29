<script setup>
defineOptions({inheritAttrs:false});
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue";

import { useRoute, useRouter } from "vue-router";

import { supabase } from "../lib/supabase";

import { useBattleSession } from "../composables/battle/useBattleSession";

import { useBattleUiSync } from "../composables/battle/useBattleUiSync";
import { usePublicBattleToasts } from '../composables/battle/usePublicBattleToasts.js';

import { usePublicCardSkills } from "../composables/battle/usePublicCardSkills.js";
import "../components/battle/arena-theme.css";
import PublicActiveField from "../components/battle/PublicActiveField.vue";
import PublicBattleMusic from '../components/battle/PublicBattleMusic.vue';
import BattlePauseNotice from '../components/battle/BattlePauseNotice.vue';
import PublicSkillCinematic from '../components/battle/PublicSkillCinematic.vue';
import PublicQuizDisplay from '../components/battle/PublicQuizDisplay.vue';
import { PUBLIC_BATTLE_VIEWS, isPublicBattleView, normalizePublicBattleLayout } from "../utils/publicBattleLayouts";


const route = useRoute();
const router = useRouter();

const routeCode = computed(() =>
  String(route.params.code ?? "")
    .trim()

    .toUpperCase(),
);

const {
  battle,

  player1Active,

  player2Active,

  player1Bench,

  player2Bench,

  latestBattleEvent,

  loading,

  error,

  currentQuestion,

  currentQuestionRound,

  questionActive,

  questionLoading,

  questionError,

  loadBattle,
  refreshBattle,

  resetSession,
} = useBattleSession();

const activeFieldRef = ref(null);
const latestQuizEvent = ref(null);
const latestSkillEvent = ref(null);
let refreshingPublicBattle = false;
// The shared link also carries the choice for installations awaiting migration 026.
const publicLayout = computed(() => isPublicBattleView(route.query.layout)
  ? route.query.layout : normalizePublicBattleLayout(battle.value?.public_layout));
const publicPageRef = ref(null);
const fullscreenActive = ref(false);
let statusPollTimer = null;
let latestStatusRequest = 0;

const syncFullscreenState = () => {
  fullscreenActive.value = document.fullscreenElement === publicPageRef.value;
};
const togglePublicFullscreen = async () => {
  try {
    if (document.fullscreenElement === publicPageRef.value) {
      await document.exitFullscreen();
    } else if (publicPageRef.value?.requestFullscreen) {
      await publicPageRef.value.requestFullscreen();
    }
  } catch (fullscreenError) {
    console.warn('[PUBLIC BATTLE] Fullscreen not available:', fullscreenError);
  }
  syncFullscreenState();
};


// =========================================================
// PHASE 3D.18 • STATUS EFFECT UI DATA
// =========================================================

const activeStatusEffects = ref([]);

const STATUS_REFRESH_EVENT_TYPES = new Set([
  "attack",
  "card_destroyed",
  "damage",
  "defense",
  "heal",
  "ultimate",
  "synergy",
  "special_effect",
  "special_skill",
  "fusion",
  "summon",
  "graveyard",
  "bench",
  "swap",
  "bonus_skill_used",
  "question_winner",
  "status_tick",
  "status_expired",
  "status_applied",
  "status_added",
  "status_refreshed",
  "status_removed",
  "status_stack_changed",
  "turn_changed",
  "turn_ended",
  "card_move",
  "turn_end",
]);

// RPC is the source of truth; polling is an intentional fallback when the
// spectator only receives the last battle event of an event burst.
const loadStatusEffects = async () => {
  const battleId = battle.value?.id;
  const requestId = ++latestStatusRequest;
  if (!battleId) {
    activeStatusEffects.value = [];
    return;
  }
  try {
    const { data, error: statusError } = await supabase.rpc(
      "get_active_battle_status_effects",
      { p_battle_id: battleId },
    );
    if (statusError) throw statusError;
    // Ignore stale RPC responses when multiple status updates arrive together.
    if (requestId !== latestStatusRequest || battle.value?.id !== battleId) return;
    activeStatusEffects.value = Array.isArray(data) ? data : [];
  } catch (statusError) {
    // Keep the last valid snapshot instead of making FX flicker on transient errors.
    if (requestId === latestStatusRequest) {
      console.error("[PUBLIC BATTLE] load status effects:", statusError);
    }
  }
};

const {
  players: liveUi,
  spotlight: liveSpotlight,

  connect: connectBattleUi,

  disconnect: disconnectBattleUi,
} = useBattleUiSync();

/* =========================================================
   SOUND SYSTEM
   Restored from the older battle arena.
========================================================= */

const SOUND_FILES = {
  attack: "/sounds/attack.mp3",
  hit: "/sounds/hit.mp3",
  defense: "/sounds/defense.mp3",
  heal: "/sounds/heal.mp3",
  ultimate: "/sounds/ultimate.mp3",
  synergy: "/sounds/synergy.mp3",
  summon: "/sounds/summon.mp3",
  bench: "/sounds/bench.mp3",
  swap: "/sounds/swap.mp3",
  warning: "/sounds/warning.mp3",
  question: "/sounds/question.mp3",
  correct: "/sounds/correct.mp3",
  wrong: "/sounds/wrong.mp3",
  win: "/sounds/win.mp3",
  lose: "/sounds/lose.mp3",

  // Tidak membutuhkan asset baru untuk Phase 3D.13.
  // Nanti boleh diganti menjadi /sounds/fusion.mp3 jika kamu punya file khusus.
  fusion: "/sounds/synergy.mp3",
};

const soundEnabled = ref(true);
const audioUnlocked = ref(false);
const audioCache = new Map();

let endSoundPlayed = false;

const getAudio = (name) => {
  if (typeof Audio === "undefined") {
    return null;
  }

  const source = SOUND_FILES[name];

  if (!source) {
    return null;
  }

  if (!audioCache.has(name)) {
    const audio = new Audio(source);

    audio.preload = "auto";

    audio.addEventListener("error", () => {
      console.warn(`[PUBLIC BATTLE AUDIO] gagal memuat ${name}: ${source}`);
    });

    audioCache.set(name, audio);
  }

  return audioCache.get(name);
};

const unlockAudio = async () => {
  if (audioUnlocked.value) {
    return true;
  }

  // Harus dipanggil dari interaksi user karena autoplay policy browser.
  audioUnlocked.value = true;

  const probe = getAudio("attack");

  if (!probe) {
    return true;
  }

  const previousMuted = probe.muted;
  const previousVolume = probe.volume;

  try {
    probe.muted = true;
    probe.volume = 0;
    probe.currentTime = 0;

    await probe.play();

    probe.pause();
    probe.currentTime = 0;
  } catch (audioError) {
    // Interaksi user berikutnya masih boleh mencoba memutar audio lagi.
    console.debug("[PUBLIC BATTLE AUDIO] unlock probe:", audioError);
  } finally {
    probe.muted = previousMuted;
    probe.volume = previousVolume;
  }

  return true;
};

const playSound = async (name, volume = 0.85) => {
  if (!soundEnabled.value || !audioUnlocked.value) {
    return;
  }

  const audio = getAudio(name);

  if (!audio) {
    return;
  }

  try {
    audio.pause();
    audio.currentTime = 0;
    audio.volume = Math.max(0, Math.min(1, Number(volume) || 0));

    await audio.play();
  } catch (audioError) {
    console.debug(`[PUBLIC BATTLE AUDIO] ${name}:`, audioError);
  }
};

const toggleSound = async () => {
  if (!audioUnlocked.value) {
    await unlockAudio();
    soundEnabled.value = true;

    // Feedback kecil agar operator tahu audio sudah aktif.
    void playSound("question", 0.28);

    return;
  }

  soundEnabled.value = !soundEnabled.value;

  if (soundEnabled.value) {
    void playSound("question", 0.28);
  }
};

const handleAudioUnlockInteraction = () => {
  void unlockAudio();
};

const cleanupAudio = () => {
  for (const audio of audioCache.values()) {
    try {
      audio.pause();
      audio.currentTime = 0;
    } catch {
      // ignore cleanup error
    }
  }

  audioCache.clear();
};

/* =========================================================

   HELPERS

========================================================= */

const getCardId = (card) =>
  card?.battleId ?? card?.battle_id ?? card?.id ?? null;

const cardImage = (card) =>
  card?.image_url ?? card?.avatar_url ?? card?.image ?? "";

const normalizeBattleCard = (card) => ({
  ...card,

  battleId: card?.battleId ?? card?.battle_id ?? card?.id ?? null,

  currentHp: Number(card?.current_hp ?? card?.currentHp ?? card?.hp ?? 0),

  baseHp: Number(card?.base_hp ?? card?.baseHp ?? card?.hp ?? 0),
});

/* =========================================================
   PHASE 3D.16 • CANONICAL BATTLE EVENT CONTRACT
========================================================= */

const publicEventPayload = (event) =>
  event?.payload && typeof event.payload === "object"
    ? event.payload
    : {};

const publicEventAffectedCardIds = (event) => {
  const payload = publicEventPayload(event);
  const ids = [];

  if (Array.isArray(payload?.affected_card_ids)) {
    ids.push(...payload.affected_card_ids);
  }

  if (Array.isArray(payload?.targets)) {
    ids.push(...payload.targets.map((target) => target?.target_card_id));
  }

  ids.push(payload?.target_card_id, payload?.battle_card_id);

  if (
    ["card_destroyed", "graveyard", "bench", "swap", "summon"].includes(
      String(event?.type ?? "").toLowerCase(),
    )
  ) {
    ids.push(event?.card_id);
  }

  return [...new Set(
    ids
      .filter((value) => value != null && value !== "")
      .map((value) => String(value)),
  )];
};

const publicEventEffectType = (event) =>
  String(
    publicEventPayload(event)?.effect_type ??
      publicEventPayload(event)?.effect?.type ??
      "",
  ).toLowerCase();

/* =========================================================

   GRAVEYARD

========================================================= */

const player1Graveyard = ref([]);

const player2Graveyard = ref([]);

let graveyardChannel = null;

/* =========================================================
   PHASE 3D.13
   FUSION EVENT / HISTORY
========================================================= */

const fusionHistoryOpen = ref(false);

const fusionHistory = ref([]);

const fusionHistoryLoading = ref(false);

const fusionHistoryError = ref("");

const fusionHistoryMaterials = (event) =>
  Array.isArray(event?.payload?.materials) ? event.payload.materials : [];

const fusionHistoryResult = (event) =>
  event?.payload?.result && typeof event.payload.result === "object"
    ? event.payload.result
    : {};

const fusionHistoryKindLabel = (event) => {
  const kind = String(event?.payload?.fusion_kind ?? "normal").toLowerCase();

  const labels = {
    normal: "NORMAL FUSION",

    necro: "NECRO FUSION",

    chain: "CHAIN FUSION",

    necro_chain: "NECRO CHAIN",
  };

  return labels[kind] ?? kind.replaceAll("_", " ").toUpperCase();
};

const fusionHistoryTime = (event) => {
  if (!event?.created_at) {
    return "";
  }

  const date = new Date(event.created_at);

  if (Number.isNaN(date.getTime())) {
    return "";
  }

  return date.toLocaleTimeString([], {
    hour: "2-digit",

    minute: "2-digit",
  });
};

const loadFusionHistory = async () => {
  if (!routeCode.value) {
    fusionHistory.value = [];

    return;
  }

  fusionHistoryLoading.value = true;

  fusionHistoryError.value = "";

  try {
    const { data, error: historyError } = await supabase.rpc(
      "get_battle_fusion_history",
      {
        p_code: routeCode.value,

        p_limit: 30,
      },
    );

    if (historyError) {
      throw historyError;
    }

    if (data?.ok === false) {
      throw new Error(data?.message ?? "Fusion history gagal dimuat.");
    }

    fusionHistory.value = Array.isArray(data?.events) ? data.events : [];
  } catch (historyError) {
    console.error("Load Fusion History:", historyError);

    fusionHistoryError.value =
      historyError?.message ?? "Gagal memuat Fusion history.";
  } finally {
    fusionHistoryLoading.value = false;
  }
};

const openFusionHistory = async () => {
  fusionHistoryOpen.value = true;

  await loadFusionHistory();
};

const closeFusionHistory = () => {
  fusionHistoryOpen.value = false;
};

const showFusionAnnouncement = (event) => {
  if (!event || event.type !== "fusion") {
    return;
  }

  void playSound("fusion", 0.92);
};


/* =========================================================
   PHASE 3D.16 • GENERIC EVENT ANNOUNCEMENT
========================================================= */

const eventAnnouncement = ref(null);
let eventAnnouncementTimer = null;
const processedAnnouncementEvents = new Set();

const showEventAnnouncement = ({
  event = null,
  icon = "✦",
  eyebrow = "BATTLE EVENT",
  title = "EVENT",
  message = "",
  tone = "info",
} = {}) => {
  const key = String(
    event?.id ??
      `${event?.type ?? title}:${event?.created_at ?? ""}:${event?.source_player ?? ""}`,
  );

  if (event && processedAnnouncementEvents.has(key)) {
    return;
  }

  if (event) {
    processedAnnouncementEvents.add(key);

    if (processedAnnouncementEvents.size > 200) {
      const oldest = processedAnnouncementEvents.values().next().value;
      processedAnnouncementEvents.delete(oldest);
    }
  }

  eventAnnouncement.value = {
    icon,
    eyebrow,
    title,
    message,
    tone,
  };

  if (eventAnnouncementTimer) {
    clearTimeout(eventAnnouncementTimer);
  }

  eventAnnouncementTimer = setTimeout(() => {
    eventAnnouncement.value = null;
    eventAnnouncementTimer = null;
  }, 3600);
};

// Fire passive events come from Supabase (never simulate damage in Vue).
// Fire status UI is visual-only. The active card burns via PublicActiveField.
// Damage stays server-authoritative; no BURN banners or textual popups.
const handleFirePassiveEvent = (event) => {
  const payload = publicEventPayload(event);
  const kind = String(event?.type ?? "").toLowerCase();
  if (String(payload?.status_key ?? "").toLowerCase() === "elemental_burn" && kind === "status_tick") {
    void playSound("hit", 0.55);
  }
};

const showReviveAnnouncement = async (event) => {
  const payload = publicEventPayload(event);
  const targetCardId = publicEventAffectedCardIds(event)[0] ?? null;
  const targetCard = targetCardId ? await fetchBattleCardById(targetCardId) : null;
  const restoredHp = Math.max(
    0,
    Number(payload?.result?.restored_hp ?? payload?.restored_hp ?? 0) || 0,
  );

  showEventAnnouncement({
    event,
    icon: "☠️",
    eyebrow: `${String(event?.source_player ?? "PLAYER").toUpperCase()} • NECRO EFFECT`,
    title: "CARD REVIVED",
    message: `${targetCard?.name ?? "A Graveyard Card"} kembali ke Active${
      restoredHp > 0 ? ` dengan ${restoredHp} HP` : ""
    }.`,
    tone: "necro",
  });
};

const loadGraveyards = async () => {
  if (!battle.value?.id) {
    return;
  }

  const {
    data,

    error: graveyardError,
  } = await supabase

    .from("battle_cards")

    .select("*")

    .eq(
      "battle_id",

      battle.value.id,
    )

    .eq(
      "zone",

      "graveyard",
    )

    .order(
      "graveyard_at",

      {
        ascending: true,

        nullsFirst: false,
      },
    );

  if (graveyardError) {
    console.error(
      "Load graveyard:",

      graveyardError,
    );

    return;
  }

  const cards = (data ?? []).map(normalizeBattleCard);

  player1Graveyard.value = cards.filter((card) => card.player === "p1");

  player2Graveyard.value = cards.filter((card) => card.player === "p2");
};

const subscribeGraveyards = () => {
  if (!battle.value?.id || graveyardChannel) {
    return;
  }

  graveyardChannel = supabase

    .channel(`public-graveyard-${battle.value.id}`)

    .on(
      "postgres_changes",

      {
        event: "*",

        schema: "public",

        table: "battle_cards",

        filter: `battle_id=eq.${battle.value.id}`,
      },

      () => {
        void loadGraveyards();
      },
    )

    .subscribe();
};

const unsubscribeGraveyards = async () => {
  if (!graveyardChannel) {
    return;
  }

  try {
    await supabase.removeChannel(graveyardChannel);
  } catch {
    // ignore
  }

  graveyardChannel = null;
};

/* =========================================================

   DECK

========================================================= */

const isTcgV1 = computed(
  () => String(battle.value?.ruleset ?? "classic").toLowerCase() === "tcg_v1",
);

const player1DeckRemaining = computed(() =>
  Math.max(
    0,

    Number(battle.value?.player1_deck_remaining ?? 0) || 0,
  ),
);

const player2DeckRemaining = computed(() =>
  Math.max(
    0,

    Number(battle.value?.player2_deck_remaining ?? 0) || 0,
  ),
);

const player1DeckTotal = computed(() =>
  Math.max(
    0,

    Number(battle.value?.player1_starting_deck ?? 0) || 0,
  ),
);

const player2DeckTotal = computed(() =>
  Math.max(
    0,

    Number(battle.value?.player2_starting_deck ?? 0) || 0,
  ),
);

/* =========================================================

   LIVE DRAG

========================================================= */

const allP1Cards = computed(() => [
  ...player1Active.value,

  ...player1Bench.value,

  ...player1Graveyard.value,
]);

const allP2Cards = computed(() => [
  ...player2Active.value,

  ...player2Bench.value,

  ...player2Graveyard.value,
]);

usePublicCardSkills(battle, computed(() => [...allP1Cards.value, ...allP2Cards.value]));

const findLiveDraggingCard = (playerKey) => {
  const state = liveUi[playerKey];

  if (!state?.draggingCardId) {
    return null;
  }

  const cards = playerKey === "p1" ? allP1Cards.value : allP2Cards.value;

  return (
    cards.find(
      (card) => String(getCardId(card)) === String(state.draggingCardId),
    ) ?? null
  );
};

const p1DraggingCard = computed(() => findLiveDraggingCard("p1"));

const p2DraggingCard = computed(() => findLiveDraggingCard("p2"));

const liveDragLabel = (playerKey) => {
  const state = liveUi[playerKey];

  if (!state) {
    return "";
  }

  if (state.dragTarget === "bench") {
    return "→ BENCH";
  }

  if (state.dragTarget === "active") {
    return "→ ACTIVE";
  }

  return "DRAGGING";
};

/* =========================================================

   COMBAT

========================================================= */

const combatAnimation = ref({
  active: false,

  attackMode: null,

  sourcePlayer: null,

  targetPlayer: null,

  attackerCardId: null,

  targetCardId: null,

  attackerCard: null,

  targetCard: null,

  damage: 0,

  hpBefore: 0,

  hpAfter: 0,

  destroyed: false,

  playerDamage: 0,

  phase: "idle",

  fromRect: null,

  toRect: null,

  baseAttack: 0,

  targetDefense: 0,

  effectiveDefense: 0,

  baseDamage: 0,

  damageMultiplier: 1,

  directAttackMultiplier: 1,

  powerStrikeApplied: false,

  powerStrikeBonusPercent: 0,

  attackDebuffApplied: false,

  attackDebuffPercent: 0,

  defenseApplied: false,

  defenseReductionPercent: 0,

  waterShieldApplied: false,

  waterShieldPercent: 0,
});

let combatChannel = null;

let combatTimers = [];

const processedCombatEvents = new Set();

const resetCombatAnimation = () => {
  combatTimers.forEach(clearTimeout);

  combatTimers = [];

  combatAnimation.value = {
    active: false,

    attackMode: null,

    sourcePlayer: null,

    targetPlayer: null,

    attackerCardId: null,

    targetCardId: null,

    attackerCard: null,

    targetCard: null,

    damage: 0,

    hpBefore: 0,

    hpAfter: 0,

    destroyed: false,

    playerDamage: 0,

    phase: "idle",

    fromRect: null,

    toRect: null,

    baseAttack: 0,

    targetDefense: 0,

    effectiveDefense: 0,

    baseDamage: 0,

    damageMultiplier: 1,

    directAttackMultiplier: 1,

    powerStrikeApplied: false,

    powerStrikeBonusPercent: 0,

    attackDebuffApplied: false,

    attackDebuffPercent: 0,

    defenseApplied: false,

    defenseReductionPercent: 0,

    waterShieldApplied: false,

    waterShieldPercent: 0,
  };
};


/* =========================================================
   PHASE 3D.16 • ULTIMATE AOE CINEMATIC
   Fusion cinematic remains intentionally postponed (3D.14).
========================================================= */

const ultimateAnimation = ref({
  active: false,
  phase: "idle",
  sourcePlayer: null,
  targetPlayer: null,
  sourceCardId: null,
  sourceCard: null,
  sourceRect: null,
  targets: [],
  totalDamage: 0,
  destroyedCount: 0,
  perCardDamage: 0,
});

let ultimateTimers = [];
const processedUltimateEvents = new Set();

const resetUltimateAnimation = () => {
  ultimateTimers.forEach(clearTimeout);
  ultimateTimers = [];

  ultimateAnimation.value = {
    active: false,
    phase: "idle",
    sourcePlayer: null,
    targetPlayer: null,
    sourceCardId: null,
    sourceCard: null,
    sourceRect: null,
    targets: [],
    totalDamage: 0,
    destroyedCount: 0,
    perCardDamage: 0,
  };
};

const queueUltimatePhase = (delay, phase) => {
  ultimateTimers.push(
    setTimeout(() => {
      if (ultimateAnimation.value.active) {
        ultimateAnimation.value.phase = phase;
      }
    }, delay),
  );
};

const ultimateTargetStyle = (target) => ({
  left: `${target?.rect?.centerX ?? window.innerWidth / 2}px`,
  top: `${target?.rect?.centerY ?? window.innerHeight / 2}px`,
});

const ultimateSourceStyle = computed(() => {
  const rect = ultimateAnimation.value.sourceRect;

  if (!rect) {
    return {};
  }

  return {
    left: `${rect.centerX}px`,
    top: `${rect.centerY}px`,
  };
});

const startUltimateAoeAnimation = async (event) => {
  if (!event || String(event.type ?? "").toLowerCase() !== "ultimate") {
    return false;
  }

  const payload = publicEventPayload(event);
  const attackMode = String(payload?.attack_mode ?? "").toLowerCase();

  if (attackMode !== "ultimate_aoe") {
    return false;
  }

  const eventKey = String(event.id ?? event.created_at ?? "ultimate");

  if (processedUltimateEvents.has(eventKey)) {
    return true;
  }

  processedUltimateEvents.add(eventKey);

  if (processedUltimateEvents.size > 120) {
    const oldest = processedUltimateEvents.values().next().value;
    processedUltimateEvents.delete(oldest);
  }

  const sourcePlayer = String(event.source_player ?? "").toLowerCase();
  const targetPlayer = String(
    event.target_player ?? (sourcePlayer === "p1" ? "p2" : "p1"),
  ).toLowerCase();

  const sourceCardId =
    payload?.source_card_id ?? payload?.attacker_card_id ?? event.card_id ?? null;

  const rawTargets = Array.isArray(payload?.targets) ? payload.targets : [];
  const affectedIds = publicEventAffectedCardIds(event);

  await nextTick();
  activeFieldRef.value?.captureCardRects?.();
  await new Promise((resolve) => requestAnimationFrame(resolve));

  const sourceRect = sourceCardId
    ? activeFieldRef.value?.getCardRect?.(sourcePlayer, sourceCardId) ??
      fallbackRect(sourcePlayer, "card")
    : fallbackRect(sourcePlayer, "card");

  const normalizedTargets = (
    rawTargets.length
      ? rawTargets
      : affectedIds.map((targetCardId) => ({ target_card_id: targetCardId }))
  ).map((target, index) => {
    const targetCardId = target?.target_card_id ?? affectedIds[index] ?? null;
    const rect = targetCardId
      ? activeFieldRef.value?.getCardRect?.(targetPlayer, targetCardId) ??
        fallbackRect(targetPlayer, "card")
      : fallbackRect(targetPlayer, "card");

    return {
      ...target,
      target_card_id: targetCardId,
      rect,
      effective_damage: Math.max(
        0,
        Number(target?.effective_damage ?? payload?.per_card_damage ?? 0) || 0,
      ),
      hp_before: Math.max(0, Number(target?.hp_before ?? 0) || 0),
      hp_after: Math.max(0, Number(target?.hp_after ?? 0) || 0),
      destroyed: Boolean(target?.destroyed),
    };
  });

  const sourceCard = sourceCardId ? await fetchBattleCardById(sourceCardId) : null;

  resetUltimateAnimation();

  ultimateAnimation.value = {
    active: true,
    phase: "charge",
    sourcePlayer,
    targetPlayer,
    sourceCardId,
    sourceCard,
    sourceRect,
    targets: normalizedTargets,
    totalDamage: Math.max(
      0,
      Number(payload?.total_effective_damage ?? payload?.damage ?? 0) || 0,
    ),
    destroyedCount: Math.max(0, Number(payload?.destroyed_count ?? 0) || 0),
    perCardDamage: Math.max(0, Number(payload?.per_card_damage ?? 0) || 0),
  };

  void playSound("ultimate", 0.96);

  queueUltimatePhase(620, "burst");
  queueUltimatePhase(1120, "impact");
  queueUltimatePhase(1850, "result");
  queueUltimatePhase(3050, "exit");

  const burstCount = Math.min(Math.max(normalizedTargets.length, 1), 5);

  for (let index = 0; index < burstCount; index += 1) {
    ultimateTimers.push(
      setTimeout(() => {
        if (ultimateAnimation.value.active) {
          void playSound("hit", Math.max(0.54, 0.9 - index * 0.07));
        }
      }, 1050 + index * 115),
    );
  }

  ultimateTimers.push(
    setTimeout(() => {
      resetUltimateAnimation();
    }, 3600),
  );

  return true;
};

/* =========================================================

   FIELD FX

========================================================= */

const fieldCombatFx = computed(() => ({
  active: combatAnimation.value.active,

  attackMode: combatAnimation.value.attackMode,

  phase: combatAnimation.value.phase,

  sourcePlayer: combatAnimation.value.sourcePlayer,

  targetPlayer: combatAnimation.value.targetPlayer,

  attackerCardId: combatAnimation.value.attackerCardId,

  targetCardId: combatAnimation.value.targetCardId,

  destroyed: combatAnimation.value.destroyed,

  powerStrikeApplied: combatAnimation.value.powerStrikeApplied,

  attackDebuffApplied: combatAnimation.value.attackDebuffApplied,

  attackDebuffPercent: combatAnimation.value.attackDebuffPercent,

  defenseApplied: combatAnimation.value.defenseApplied,

  waterShieldApplied: combatAnimation.value.waterShieldApplied,

  waterShieldPercent: combatAnimation.value.waterShieldPercent,
}));

/* =========================================================

   MODIFIER PANEL

========================================================= */

const combatModifierItems = computed(() => {
  const state = combatAnimation.value;

  const items = [];

  if (state.powerStrikeApplied) {
    items.push({
      type: "power",

      icon: "⚡",

      title: "POWER STRIKE",

      effect: `DAMAGE ×1.50 (+${state.powerStrikeBonusPercent || 50}%)`,
    });
  }

  if (state.attackDebuffApplied) {
    items.push({
      type: "debuff",

      icon: "❄",

      title: "ATTACK DEBUFF",

      effect: `ATTACK DAMAGE -${state.attackDebuffPercent}%`,
    });
  }

  if (state.defenseApplied) {
    items.push({
      type: "defense",

      icon: "🛡",

      title: "DEFENSE",

      effect: `INCOMING DAMAGE -${state.defenseReductionPercent || 50}%`,
    });
  }

  if (state.waterShieldApplied) {
    items.push({
      type: "water",

      icon: "💧",

      title: "WATER SHIELD",

      effect: `INCOMING DAMAGE -${state.waterShieldPercent}%`,
    });
  }

  return items;
});

const combatFormulaTitle = computed(() => {
  const state = combatAnimation.value;

  if (state.attackMode === "direct") {
    const directPercent = Math.round(state.directAttackMultiplier * 100);

    return `ATK ${state.baseAttack} × DIRECT ${directPercent}% = BASE ${state.baseDamage}`;
  }

  return `ATK ${state.baseAttack} − DEF ${state.effectiveDefense} = BASE ${state.baseDamage}`;
});

/* =========================================================

   PLAYER NAMES

========================================================= */

const combatPlayerName = computed(() =>
  combatAnimation.value.sourcePlayer === "p2"
    ? (battle.value?.player2_name ?? "Player 2")
    : (battle.value?.player1_name ?? "Player 1"),
);

const combatTargetPlayerName = computed(() =>
  combatAnimation.value.targetPlayer === "p1"
    ? (battle.value?.player1_name ?? "Player 1")
    : (battle.value?.player2_name ?? "Player 2"),
);

const combatAvatar = computed(() =>
  combatAnimation.value.sourcePlayer === "p2" ? "🧑🏽‍🦱" : "👦🏻",
);

const combatDirectionClass = computed(() =>
  combatAnimation.value.sourcePlayer === "p2" ? "from-right" : "from-left",
);

const combatIsDirect = computed(
  () => combatAnimation.value.attackMode === "direct",
);

/* =========================================================

   CARD LOOKUP

========================================================= */

const findBattleCardById = (id) =>
  [
    ...player1Active.value,

    ...player2Active.value,

    ...player1Bench.value,

    ...player2Bench.value,

    ...player1Graveyard.value,

    ...player2Graveyard.value,
  ].find((card) => String(getCardId(card)) === String(id)) ?? null;

const fetchBattleCardById = async (id) => {
  if (!id) {
    return null;
  }

  const local = findBattleCardById(id);

  if (local) {
    return local;
  }

  const {
    data,

    error: lookupError,
  } = await supabase

    .from("battle_cards")

    .select("*")

    .eq(
      "id",

      id,
    )

    .maybeSingle();

  if (lookupError) {
    console.error(lookupError);

    return null;
  }

  return data ? normalizeBattleCard(data) : null;
};

const { current: actionToast, receive: receiveActionToast } = usePublicBattleToasts({
  battle,
  findCard: findBattleCardById,
  fetchCard: fetchBattleCardById,
});

/* =========================================================

   POSITION

========================================================= */

const fallbackRect = (
  player,

  type,
) => ({
  centerX: player === "p1" ? window.innerWidth * 0.4 : window.innerWidth * 0.6,

  centerY:
    type === "player" ? window.innerHeight * 0.14 : window.innerHeight * 0.55,

  width: 140,

  height: 280,
});

const resolveCombatRects = async ({
  sourcePlayer,

  targetPlayer,

  attackerCardId,

  targetCardId,

  attackMode,
}) => {
  await nextTick();

  activeFieldRef.value?.captureCardRects?.();

  await new Promise((resolve) => requestAnimationFrame(resolve));

  const fromRect =
    activeFieldRef.value?.getCardRect?.(
      sourcePlayer,

      attackerCardId,
    ) ??
    fallbackRect(
      sourcePlayer,

      "card",
    );

  const toRect =
    attackMode === "direct"
      ? (activeFieldRef.value?.getPlayerTargetRect?.(targetPlayer) ??
        fallbackRect(
          targetPlayer,

          "player",
        ))
      : (activeFieldRef.value?.getCardRect?.(
          targetPlayer,

          targetCardId,
        ) ??
        fallbackRect(
          targetPlayer,

          "card",
        ));

  return {
    fromRect,

    toRect,
  };
};

/* =========================================================

   FLYING CARD

========================================================= */

const flyingCardStyle = computed(() => {
  const from = combatAnimation.value.fromRect;

  const to = combatAnimation.value.toRect;

  if (!from || !to) {
    return {};
  }

  const width = Math.max(
    110,

    Math.min(
      170,

      from.width ?? 140,
    ),
  );

  const height = width * 1.95;

  return {
    "--start-left": `${from.centerX - width / 2}px`,

    "--start-top": `${from.centerY - height / 2}px`,

    "--target-left": `${to.centerX - width / 2}px`,

    "--target-top": `${to.centerY - height / 2}px`,

    "--card-width": `${width}px`,

    "--card-height": `${height}px`,
  };
});

const impactStyle = computed(() => {
  const rect = combatAnimation.value.toRect;

  if (!rect) {
    return {};
  }

  return {
    left: `${rect.centerX}px`,

    top: `${rect.centerY}px`,
  };
});

/* =========================================================

   PHASE

========================================================= */

const queueCombatPhase = (
  delay,

  phase,
) => {
  combatTimers.push(
    setTimeout(
      () => {
        if (combatAnimation.value.active) {
          combatAnimation.value.phase = phase;
        }
      },

      delay,
    ),
  );
};

const queueCombatSound = (delay, name, volume = 0.85) => {
  combatTimers.push(
    setTimeout(() => {
      if (combatAnimation.value.active) {
        void playSound(name, volume);
      }
    }, delay),
  );
};

/* =========================================================

   START ATTACK

========================================================= */

const startCombatAnimation = async (event) => {
  if (!event || event.type !== "attack") {
    return;
  }

  const payload = event.payload ?? {};

  const eventKey = String(event.id ?? event.created_at);

  if (processedCombatEvents.has(eventKey)) {
    return;
  }

  processedCombatEvents.add(eventKey);

  const attackMode = String(payload.attack_mode ?? "").toLowerCase();

  if (!["targeted_card", "direct"].includes(attackMode)) {
    return;
  }

  const attackerCardId = payload.attacker_card_id ?? event.card_id;

  const targetCardId = payload.target_card_id ?? null;

  const sourcePlayer = event.source_player;

  const targetPlayer =
    event.target_player ?? (sourcePlayer === "p1" ? "p2" : "p1");

  activeFieldRef.value?.captureCardRects?.();

  const [attackerCard, targetCard] = await Promise.all([
    fetchBattleCardById(attackerCardId),

    targetCardId ? fetchBattleCardById(targetCardId) : Promise.resolve(null),
  ]);

  resetCombatAnimation();

  combatAnimation.value = {
    active: true,

    attackMode,

    sourcePlayer,

    targetPlayer,

    attackerCardId,

    targetCardId,

    attackerCard,

    targetCard,

    damage: Number(payload.final_damage ?? payload.damage ?? 0) || 0,

    hpBefore:
      Number(
        attackMode === "direct"
          ? payload.player_hp_before
          : payload.target_hp_before,
      ) || 0,

    hpAfter:
      Number(
        attackMode === "direct"
          ? payload.player_hp_after
          : payload.target_hp_after,
      ) || 0,

    destroyed: Boolean(payload.destroyed),

    playerDamage: Number(payload.player_damage ?? 0) || 0,

    phase: "avatar",

    fromRect: null,

    toRect: null,

    baseAttack: Number(payload.base_attack ?? 0) || 0,

    targetDefense: Number(payload.target_defense ?? 0) || 0,

    effectiveDefense:
      Number(payload.effective_defense ?? payload.target_defense ?? 0) || 0,

    baseDamage: Number(payload.base_damage ?? payload.final_damage ?? 0) || 0,

    damageMultiplier: Number(payload.damage_multiplier ?? 1) || 1,

    directAttackMultiplier: Number(payload.direct_attack_multiplier ?? 1) || 1,

    powerStrikeApplied: Boolean(
      payload.power_strike_applied ?? payload.power_strike,
    ),

    powerStrikeBonusPercent:
      Number(
        payload.power_strike_bonus_percent ?? (payload.power_strike ? 50 : 0),
      ) || 0,

    attackDebuffApplied: Boolean(payload.attack_debuff_applied),

    attackDebuffPercent: Number(payload.attack_debuff_percent ?? 0) || 0,

    defenseApplied: Boolean(payload.defense_applied),

    defenseReductionPercent:
      Number(payload.defense_reduction_percent ?? 0) || 0,

    waterShieldApplied: Boolean(payload.water_shield_applied),

    waterShieldPercent:
      Number(payload.water_shield_reduction_percent ?? 0) || 0,
  };

  // Promote the accepted source/target to the duel before measuring. Otherwise
  // an unselected target's roster thumbnail becomes the animation destination.
  const animation = combatAnimation.value;
  const rects = await resolveCombatRects({ sourcePlayer, targetPlayer, attackerCardId, targetCardId, attackMode });
  if (combatAnimation.value !== animation) return;
  Object.assign(animation, rects);

  // Attack cue dimulai bersamaan dengan cinematic.
  void playSound("attack", combatAnimation.value.powerStrikeApplied ? 1 : 0.82);

  // Defense / Water Shield cue ketika charge muncul.
  if (
    combatAnimation.value.defenseApplied ||
    combatAnimation.value.waterShieldApplied
  ) {
    queueCombatSound(430, "defense", 0.75);
  }

  // Impact cue tepat sebelum phase impact.
  queueCombatSound(1320, "hit", combatAnimation.value.destroyed ? 1 : 0.9);

  queueCombatPhase(
    420,

    "charge",
  );

  queueCombatPhase(
    950,

    "strike",
  );

  queueCombatPhase(
    1370,

    "impact",
  );

  queueCombatPhase(
    1880,

    combatAnimation.value.destroyed ? "destroyed" : "result",
  );

  queueCombatPhase(
    2900,

    "exit",
  );

  combatTimers.push(
    setTimeout(
      resetCombatAnimation,

      3400,
    ),
  );
};

/* =========================================================

   REALTIME ATTACK

========================================================= */

const subscribeCombatEvents = () => {
  if (!battle.value?.id || combatChannel) {
    return;
  }

  combatChannel = supabase

    .channel(`public-combat-${battle.value.id}`)

    .on(
      "postgres_changes",

      {
        event: "INSERT",

        schema: "public",

        table: "battle_events",

        filter: `battle_id=eq.${battle.value.id}`,
      },

      ({ new: event }) => {
        if (String(event?.type).startsWith('question_')) latestQuizEvent.value = event;
        receiveActionToast(event);
        if (event?.type === 'special_skill') { latestSkillEvent.value = event; void loadStatusEffects(); }
        if (event?.type === "attack") {
          void startCombatAnimation(event);
        }
        if (event?.type === 'status_applied' || event?.type === 'status_tick') {
          void loadStatusEffects();
          handleFirePassiveEvent(event);
        }

        if (event?.type === "ultimate") {
          void startUltimateAoeAnimation(event);
        }
      },
    )

    .subscribe();
};

const unsubscribeCombatEvents = async () => {
  resetCombatAnimation();
  resetUltimateAnimation();

  if (!combatChannel) {
    return;
  }

  await supabase.removeChannel(combatChannel);

  combatChannel = null;
};

/* =========================================================

   QUESTION

========================================================= */

const showQuestion = computed(() =>
  Boolean(
    battle.value &&
    (questionActive.value || battle.value.status === "question"),
  ),
);

const questionWinner = computed(
  () => currentQuestionRound.value?.winner_player ?? null,
);

const questionWinnerName = computed(() =>
  questionWinner.value === "p1"
    ? (battle.value?.player1_name ?? "Player 1")
    : questionWinner.value === "p2"
      ? (battle.value?.player2_name ?? "Player 2")
      : "",
);

const questionLevel = computed(() =>
  String(currentQuestion.value?.difficulty ?? "").toUpperCase(),
);

watch(
  showQuestion,
  (active, previous) => {
    if (active && !previous) {
      void playSound("question", 0.78);
    }
  },
);

watch(
  () => [battle.value?.status, battle.value?.winner],
  ([status, winner]) => {
    if ((status === "finished" || winner) && !endSoundPlayed) {
      endSoundPlayed = true;
      void playSound("win", 0.95);
    }
  },
);

/* =========================================================

   CONNECT

========================================================= */

const connectPublicLiveUi = async () => {
  if (!battle.value?.id) {
    return;
  }

  await connectBattleUi({
    battleId: battle.value.id,

    role: "spectator",

    player: null,
  });
};

const loadCurrentBattle = async () => {
  await loadBattle(routeCode.value);

  if (!battle.value) {
    return;
  }

  await Promise.all([
    loadGraveyards(),

    loadFusionHistory(),

    loadStatusEffects(),

    connectPublicLiveUi(),
  ]);

  subscribeGraveyards();

  subscribeCombatEvents();
};

watch(
  latestBattleEvent,

  (event) => {
    if (!event) {
      return;
    }

    const eventType = String(event.type ?? "").toLowerCase();
    if (eventType.startsWith('question_')) latestQuizEvent.value = event;
    receiveActionToast(event);

    if (STATUS_REFRESH_EVENT_TYPES.has(eventType)) {
      void loadStatusEffects();
    }
    if (eventType === 'status_applied' || eventType === 'status_tick') {
      handleFirePassiveEvent(event);
    }

    if (
      [
        "graveyard",
        "bench",
        "swap",
        "summon",
        "card_destroyed",
        "ultimate",
        "special_effect",
        "special_skill",
        "fusion",
      ].includes(String(event.type ?? "").toLowerCase())
    ) {
      void loadGraveyards();
    }

    if (event.type === "summon") {
      void playSound("summon", 0.82);
    }

    if (event.type === "bench" || (event.type === 'card_move' && event.payload?.action === 'move_to_bench')) {
      void playSound("bench", 0.72);
    }

    if (event.type === "swap" || (event.type === 'card_move' && ['return_from_bench', 'switch_active'].includes(event.payload?.action))) {
      void playSound("swap", 0.78);
    }

    if (event.type === "defense") {
      void playSound("defense", 0.78);
    }

    if (event.type === "heal") {
      void playSound("heal", 0.82);
    }

    if (event.type === "ultimate") {
      const handledAoe = startUltimateAoeAnimation(event);

      void Promise.resolve(handledAoe).then((handled) => {
        if (!handled) {
          void playSound("ultimate", 0.92);
        }
      });
    }

    if (event.type === "synergy") {
      void playSound("synergy", 0.86);
    }

    if (event.type === "special_effect") {
      const effectType = publicEventEffectType(event);

      if (effectType === "revive") {
        void showReviveAnnouncement(event);
        void playSound("summon", 0.82);
        setTimeout(() => void playSound("heal", 0.68), 260);
      } else if (
        effectType === "move_zone" &&
        String(publicEventPayload(event)?.result?.to_zone ?? "").toLowerCase() === "graveyard"
      ) {
        void playSound("warning", 0.52);
      }
    }

    if (event.type === "fusion") {
      void loadFusionHistory();

      showFusionAnnouncement(event);
    }

    if (event.type === "attack") {
      void startCombatAnimation(event);
    }
  },
);

onMounted(() => {
  document.body.classList.add('public-tv-mode');
  document.addEventListener('fullscreenchange', syncFullscreenState);
  // Sync every 2.5s even when battle events are coalesced or missed.
  statusPollTimer = window.setInterval(() => {
    if (document.visibilityState === 'visible' && battle.value?.id &&
        battle.value.status !== 'finished') void loadStatusEffects();
    if (document.visibilityState === 'visible' && battle.value?.id && battle.value.status !== 'finished' && !refreshingPublicBattle) {
      refreshingPublicBattle = true;
      void refreshBattle().finally(() => { refreshingPublicBattle = false; });
    }
  }, 2500);
  // Browser mengizinkan audio setelah minimal satu interaksi user.
  window.addEventListener("pointerdown", handleAudioUnlockInteraction, {
    once: true,
    capture: true,
  });

  window.addEventListener("keydown", handleAudioUnlockInteraction, {
    once: true,
    capture: true,
  });

  void loadCurrentBattle();
});

onUnmounted(async () => {
  ++latestStatusRequest;
  if (statusPollTimer !== null) window.clearInterval(statusPollTimer);
  statusPollTimer = null;
  document.body.classList.remove('public-tv-mode');
  document.removeEventListener('fullscreenchange', syncFullscreenState);
  window.removeEventListener("pointerdown", handleAudioUnlockInteraction, true);
  window.removeEventListener("keydown", handleAudioUnlockInteraction, true);

  cleanupAudio();

  if (eventAnnouncementTimer) {
    clearTimeout(eventAnnouncementTimer);
    eventAnnouncementTimer = null;
  }

  await Promise.all([
    unsubscribeGraveyards(),

    unsubscribeCombatEvents(),

    disconnectBattleUi(),
  ]);
});
</script>

<template>
  <main ref="publicPageRef" class="public-battle-page">
    <BattlePauseNotice :battle="battle"/>
    <div v-if="loading" class="public-state">Loading Battle...</div>

    <div v-else-if="error" class="public-state error">
      {{ error }}
    </div>

    <template v-else-if="battle">
      <!-- =================================================
           PUBLIC BATTLE SOUND CONTROL
      ================================================== -->

      <button
        type="button"
        class="public-sound-control"
        :class="{
          enabled: soundEnabled && audioUnlocked,
          locked: !audioUnlocked,
        }"
        :title="
          !audioUnlocked
            ? 'Klik untuk mengaktifkan sound effect'
            : soundEnabled
              ? 'Sound effect aktif'
              : 'Sound effect dimatikan'
        "
        @click="toggleSound"
      >
        <span>
          {{ soundEnabled && audioUnlocked ? "🔊" : "🔇" }}
        </span>

        <strong>
          {{
            !audioUnlocked
              ? "ENABLE SOUND"
              : soundEnabled
                ? "SOUND ON"
                : "SOUND OFF"
          }}
        </strong>
      </button>

      <label class="public-layout-control"><span>Layout penonton</span><select :value="publicLayout" @change="router.replace({query:{...route.query,layout:$event.target.value}})" aria-label="Layout penonton"><option v-for="view in PUBLIC_BATTLE_VIEWS" :key="view.id" :value="view.id">{{view.name}}</option></select></label>

      <PublicBattleMusic :ducked="combatAnimation.active || ultimateAnimation.active || showQuestion" />

      <button
        type="button"
        class="public-fullscreen-control"
        :aria-label="fullscreenActive ? 'Keluar dari fullscreen' : 'Tampilkan fullscreen TV'"
        :title="fullscreenActive ? 'Exit fullscreen' : 'Fullscreen untuk TV'"
        @click="togglePublicFullscreen"
      >
        <span aria-hidden="true">{{ fullscreenActive ? '⤡' : '⛶' }}</span>
        <strong>{{ fullscreenActive ? 'EXIT FULLSCREEN' : 'TV FULLSCREEN' }}</strong>
      </button>

      <!-- =================================================
           PHASE 3D.13 • FUSION HISTORY BUTTON
      ================================================== -->

      <button
        type="button"
        class="fusion-history-trigger"
        @click="openFusionHistory"
      >
        <span> 🧬 </span>

        <strong> FUSION HISTORY </strong>

        <b>
          {{ fusionHistory.length }}
        </b>
      </button>

      <!-- =================================================
           PHASE 3D.13 • FUSION HISTORY MODAL
      ================================================== -->

      <Transition name="fusion-pop">
        <div v-if="fusionHistoryOpen" class="fusion-history-overlay">
          <div class="fusion-history-backdrop" @click="closeFusionHistory" />

          <section class="fusion-history-modal arena-frame" role="dialog" aria-modal="true" aria-label="Fusion Timeline" @click.stop>
            <header class="fusion-history-header">
              <div>
                <span> NEXUS • BATTLE HISTORY </span>

                <h2>Fusion Timeline</h2>

                <p>Live record semua Fusion, Necro Fusion, dan Fusion Chain.</p>
              </div>

              <button type="button" class="modal-close" aria-label="Tutup Fusion Timeline" @click="closeFusionHistory">✕</button>
            </header>

            <div v-if="fusionHistoryLoading" class="fusion-history-state">
              Loading Fusion history...
            </div>

            <div
              v-else-if="fusionHistoryError"
              class="fusion-history-state error"
            >
              <strong> History gagal dimuat </strong>

              <span>
                {{ fusionHistoryError }}
              </span>

              <button type="button" @click="loadFusionHistory">
                COBA LAGI
              </button>
            </div>

            <div v-else-if="!fusionHistory.length" class="fusion-history-state">
              Belum ada Fusion dalam battle ini.
            </div>

            <div v-else class="fusion-history-list">
              <article
                v-for="event in fusionHistory"
                :key="event.id"
                class="fusion-history-entry"
              >
                <div class="fusion-history-top">
                  <span :class="event.source_player === 'p1' ? 'blue' : 'red'">
                    {{ String(event.source_player ?? "player").toUpperCase() }}
                  </span>

                  <b>
                    {{ fusionHistoryKindLabel(event) }}
                  </b>

                  <time>
                    {{ fusionHistoryTime(event) }}
                  </time>
                </div>

                <h3>
                  <span>
                    {{ event.payload?.recipe_icon ?? "🧬" }}
                  </span>

                  {{ event.payload?.recipe_name ?? "Fusion" }}
                </h3>

                <div class="fusion-history-combo">
                  <div class="fusion-history-materials">
                    <div
                      v-for="material in fusionHistoryMaterials(event)"
                      :key="
                        material.battle_card_id ??
                        `${material.card_code}-${material.zone}`
                      "
                      class="fusion-history-material"
                    >
                      <small>
                        {{ String(material.zone ?? "material").toUpperCase() }}
                      </small>

                      <strong>
                        {{ material.name ?? material.card_code ?? "Material" }}
                      </strong>
                    </div>
                  </div>

                  <div class="fusion-history-arrow">→</div>

                  <div class="fusion-history-result">
                    <img
                      v-if="fusionHistoryResult(event).image_url"
                      :src="fusionHistoryResult(event).image_url"
                      :alt="fusionHistoryResult(event).name"
                    />

                    <div>
                      <small> FUSION RESULT </small>

                      <strong>
                        {{ fusionHistoryResult(event).name ?? "Fusion Result" }}
                      </strong>

                      <span>
                        HP
                        {{
                          fusionHistoryResult(event).base_hp ??
                          event.payload?.calculated_stats?.hp ??
                          "-"
                        }}
                        • ATK
                        {{
                          fusionHistoryResult(event).attack ??
                          event.payload?.calculated_stats?.attack ??
                          "-"
                        }}
                        • DEF
                        {{
                          fusionHistoryResult(event).defense ??
                          event.payload?.calculated_stats?.defense ??
                          "-"
                        }}
                      </span>
                    </div>
                  </div>
                </div>
              </article>
            </div>
          </section>
        </div>
      </Transition>

      <div class="tbc-public-frame">
        <PublicQuizDisplay :battle="battle" :question="currentQuestion" :round="currentQuestionRound" :active="showQuestion" :loading="questionLoading" :error="questionError || ''" :event="latestQuizEvent" />
        <PublicSkillCinematic :battle="battle" :live-ui="liveUi" :event="latestSkillEvent" :paused="showQuestion || battle.teacher_paused" :cards="[...player1Active, ...player2Active, ...player1Bench, ...player2Bench]" />
        <PublicActiveField
          :layout="publicLayout"
          ref="activeFieldRef"
          :battle="battle"
          :spotlight="liveSpotlight"
          :live-ui="liveUi"
          :player1-graveyard="player1Graveyard"
          :player2-graveyard="player2Graveyard"
          :player1-active="player1Active"
          :player2-active="player2Active"
          :player1-bench-count="player1Bench.length"
          :player2-bench-count="player2Bench.length"
          :player1-bench="player1Bench"
          :player2-bench="player2Bench"
          :player1-graveyard-count="player1Graveyard.length"
          :player2-graveyard-count="player2Graveyard.length"
          :player1-deck-remaining="player1DeckRemaining"
          :player2-deck-remaining="player2DeckRemaining"
          :announcement="eventAnnouncement"
          :action-toast="actionToast"
          :combat-fx="fieldCombatFx"
          :status-effects="activeStatusEffects"
        />
      </div>

      <p class="tbc-orientation-hint">Putar layar untuk melihat arena lebih besar.</p>

      <!-- =================================================
           PHASE 3D.16 • ULTIMATE AOE CINEMATIC
      ================================================== -->

      <Transition name="ultimate-aoe">
        <div
          v-if="ultimateAnimation.active"
          class="ultimate-aoe-overlay"
          :class="[
            `phase-${ultimateAnimation.phase}`,
            ultimateAnimation.sourcePlayer,
          ]"
        >
          <div class="ultimate-aoe-backdrop" />

          <div class="ultimate-aoe-title">
            <small>
              {{ String(ultimateAnimation.sourcePlayer ?? 'PLAYER').toUpperCase() }}
              • ALL ACTIVE TARGETS
            </small>
            <h2>ULTIMATE AOE</h2>
            <p>DEF IGNORED • DEFENSE & SHIELD BROKEN</p>
          </div>

          <div
            class="ultimate-source-card"
            :style="ultimateSourceStyle"
          >
            <img
              v-if="cardImage(ultimateAnimation.sourceCard)"
              :src="cardImage(ultimateAnimation.sourceCard)"
              :alt="ultimateAnimation.sourceCard?.name"
            />
            <div v-else>⚡</div>
          </div>

          <div class="ultimate-energy-core">
            <span>⚡</span>
            <b>×2 ATK</b>
          </div>

          <div
            v-for="target in ultimateAnimation.targets"
            :key="target.target_card_id ?? target.name"
            class="ultimate-target-impact"
            :class="{ destroyed: target.destroyed }"
            :style="ultimateTargetStyle(target)"
          >
            <span>✦</span>
            <strong>-{{ target.effective_damage }}</strong>
            <small>
              {{ target.hp_before }} → {{ target.hp_after }} HP
            </small>
            <em v-if="target.destroyed">☠ DESTROYED</em>
          </div>

          <div class="ultimate-aoe-summary">
            <span>
              {{ ultimateAnimation.targets.length }} TARGETS
            </span>
            <strong>
              {{ ultimateAnimation.totalDamage }} TOTAL DAMAGE
            </strong>
            <b v-if="ultimateAnimation.destroyedCount > 0">
              {{ ultimateAnimation.destroyedCount }} DESTROYED
            </b>
          </div>
        </div>
      </Transition>

      <!-- =================================================

           COMBAT MODIFIER CINEMATIC

      ================================================== -->

      <Transition name="combat">
        <div
          v-if="combatAnimation.active"
          class="combat-overlay"
          :class="[combatDirectionClass, `phase-${combatAnimation.phase}`]"
        >
          <div class="combat-backdrop">
            <!-- ATTACKER PLAYER -->

            <div class="cinematic-player" :class="combatAnimation.sourcePlayer">
              <div class="big-avatar">
                {{ combatAvatar }}
              </div>

              <strong>
                {{ combatPlayerName }}
              </strong>
            </div>

            <!-- =================================================

               CLEAR MODIFIER INFORMATION

          ================================================== -->

            <section class="combat-breakdown">
              <span class="breakdown-eyebrow"> DAMAGE CALCULATION </span>

              <strong class="formula-title">
                {{ combatFormulaTitle }}
              </strong>

              <div v-if="combatModifierItems.length" class="modifier-list">
                <div
                  v-for="item in combatModifierItems"
                  :key="item.type"
                  class="modifier-row"
                  :class="item.type"
                >
                  <span class="modifier-icon">
                    {{ item.icon }}
                  </span>

                  <div>
                    <strong>
                      {{ item.title }}
                    </strong>

                    <small>
                      {{ item.effect }}
                    </small>
                  </div>
                </div>
              </div>

              <div class="final-damage-row">
                <span> FINAL DAMAGE </span>

                <strong>
                  {{ combatAnimation.damage }}
                </strong>
              </div>
            </section>

            <!-- ATTACK CARD -->

            <div
              class="flying-attack-card"
              :class="{
                'power-card': combatAnimation.powerStrikeApplied,

                'debuff-card': combatAnimation.attackDebuffApplied,
              }"
              :style="flyingCardStyle"
            >
              <img
                v-if="cardImage(combatAnimation.attackerCard)"
                :src="cardImage(combatAnimation.attackerCard)"
              />

              <div v-else>◉</div>
            </div>

            <!-- DEFENSE SHIELD -->

            <div
              v-if="combatAnimation.defenseApplied"
              class="cinematic-shield defense"
              :class="{
                breaking: combatAnimation.phase === 'impact',
              }"
              :style="impactStyle"
            >
              <span>🛡</span>

              <strong> DEFENSE </strong>

              <small>
                INCOMING DAMAGE -{{
                  combatAnimation.defenseReductionPercent || 50
                }}%
              </small>
            </div>

            <!-- WATER SHIELD -->

            <div
              v-if="combatAnimation.waterShieldApplied"
              class="cinematic-shield water"
              :class="{
                breaking: combatAnimation.phase === 'impact',
              }"
              :style="impactStyle"
            >
              <span>💧</span>

              <strong> WATER SHIELD </strong>

              <small>
                INCOMING DAMAGE -{{ combatAnimation.waterShieldPercent }}%
              </small>
            </div>

            <!-- IMPACT -->

            <div
              class="impact-effect"
              :class="{
                strong: combatAnimation.powerStrikeApplied,
              }"
              :style="impactStyle"
            >
              ✦
            </div>

            <!-- DAMAGE -->

            <div class="damage-result" :style="impactStyle">
              <span> FINAL DAMAGE </span>

              <strong> -{{ combatAnimation.damage }} </strong>

              <small>
                {{ combatAnimation.hpBefore }}

                →

                {{ combatAnimation.hpAfter }}

                HP
              </small>
            </div>

            <div v-if="combatAnimation.destroyed" class="destroyed-label">
              ☠ CARD DESTROYED
            </div>

            <div v-if="combatIsDirect" class="direct-label">
              DIRECT HIT •

              {{ combatTargetPlayerName }}
            </div>
          </div>
        </div>
      </Transition>
    </template>
  </main>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

/* Keep the reference composition together at every viewport size. */
.public-battle-page {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding-bottom:44px;
  width: 100vw;
  height: 100vh;
  height: 100dvh;
  overflow: hidden;
  overscroll-behavior: none;
  color: #fff9e7;
  background: #e7f4fc url('/images/battle-arena/stadium-v1.webp') center / cover;
  font-family: Inter, system-ui, sans-serif;
}

.tbc-public-frame {
  position: relative;
  width: min(100vw, calc((100dvh - 44px) * 16 / 9));
  aspect-ratio: 16 / 9;
  container-type: size;
  flex: none;
  overflow: hidden;
}

.tbc-orientation-hint { display: none; }
@media (orientation: portrait) and (max-width: 760px) {
  .tbc-orientation-hint { display: block; position: absolute; top: calc(50% + 28vw); margin: 16px; font-size: 12px; text-align: center; color: #b9ccec; }
}

.tbc-mirror-viewers {
  display: none;
}

.public-sound-control,
.public-fullscreen-control,
.fusion-history-trigger {
  position: fixed;
  z-index: 9500;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-height: 24px;
  padding: 4px 8px;
  border: 1px solid #dcb85780;
  border-radius: 5px;
  color: #f2d57e;
  background: #06152ce6;
  box-shadow: 0 2px 9px #0005;
  backdrop-filter: blur(6px);
  cursor: pointer;
  user-select: none;
  transition: background 150ms ease, border-color 150ms ease;
}

.public-sound-control:hover,
.public-fullscreen-control:hover,
.fusion-history-trigger:hover {
  border-color: #ffe398;
  background: #10274ef2;
}

.public-sound-control:focus-visible,
.public-fullscreen-control:focus-visible,
.fusion-history-trigger:focus-visible {
  outline: 2px solid #fff0b4;
  outline-offset: 2px;
}

.public-sound-control { left: 4px; bottom: 4px; }
.public-fullscreen-control { right: 4px; bottom: 4px; }
.fusion-history-trigger { left: 4px; bottom: 34px; }

.public-sound-control span,
.public-fullscreen-control span,
.fusion-history-trigger > span {
  font-size: 13px;
  line-height: 1;
}

.public-sound-control strong,
.public-fullscreen-control strong,
.fusion-history-trigger strong {
  font-size: 8px;
  font-weight: 800;
  letter-spacing: .035em;
}

.fusion-history-trigger > b {
  display: grid;
  place-items: center;
  min-width: 16px;
  height: 16px;
  border-radius: 50%;
  color: #f2d57e;
  background: #f2d57e18;
  font-size: 8px;
}

.public-state {
  width: 100%;

  height: 100%;

  display: grid;

  place-items: center;

  color: #5f7c90;

  background: #edf8fc;
}

/* =========================================================

   COMBAT

========================================================= */

.combat-overlay {
  position: fixed;

  inset: 0;

  z-index: 10000;

  overflow: hidden;

  pointer-events: none;
}

.combat-backdrop {
  position: absolute;

  inset: 0;

  background: rgba(221, 237, 245, 0.54);

  backdrop-filter: blur(2px);
}

/* =========================================================

   BIG AVATAR

========================================================= */

.cinematic-player {
  width: 330px;

  position: absolute;

  top: 50%;

  z-index: 10;

  transform: translateY(-50%);

  display: flex;

  flex-direction: column;

  align-items: center;

  opacity: 0;

  transition: all 0.4s ease;
}

.cinematic-player.p1 {
  left: -260px;
}

.cinematic-player.p2 {
  right: -260px;
}

.phase-avatar .cinematic-player.p1,
.phase-charge .cinematic-player.p1,
.phase-strike .cinematic-player.p1,
.phase-impact .cinematic-player.p1,
.phase-result .cinematic-player.p1,
.phase-destroyed .cinematic-player.p1 {
  left: 10px;

  opacity: 1;
}

.phase-avatar .cinematic-player.p2,
.phase-charge .cinematic-player.p2,
.phase-strike .cinematic-player.p2,
.phase-impact .cinematic-player.p2,
.phase-result .cinematic-player.p2,
.phase-destroyed .cinematic-player.p2 {
  right: 10px;

  opacity: 1;
}

.big-avatar {
  font-size: 210px;

  filter: drop-shadow(0 18px 24px rgba(35, 59, 76, 0.2));
}

.cinematic-player strong {
  padding: 8px 14px;

  border-radius: 10px;

  color: #17324a;

  background: rgba(255, 255, 255, 0.92);

  font-size: 16px;
}

/* =========================================================

   BREAKDOWN

========================================================= */

.combat-breakdown {
  width: 320px;

  position: fixed;

  left: 50%;

  top: 90px;

  z-index: 120;

  transform: translateX(-50%);

  padding: 13px 15px;

  border: 1px solid rgba(75, 125, 156, 0.2);

  border-radius: 16px;

  background: rgba(255, 255, 255, 0.96);

  box-shadow: 0 16px 38px rgba(45, 72, 90, 0.18);

  opacity: 0;

  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.phase-charge .combat-breakdown,
.phase-strike .combat-breakdown,
.phase-impact .combat-breakdown,
.phase-result .combat-breakdown,
.phase-destroyed .combat-breakdown {
  opacity: 1;

  transform: translateX(-50%) translateY(6px);
}

.breakdown-eyebrow {
  color: #7d92a1;

  font-size: 6px;

  font-weight: 950;

  letter-spacing: 0.13em;
}

.formula-title {
  display: block;

  margin-top: 5px;

  color: #17324a;

  font-size: 11px;
}

.modifier-list {
  display: grid;

  gap: 5px;

  margin-top: 9px;
}

.modifier-row {
  display: flex;

  align-items: center;

  gap: 8px;

  padding: 6px 8px;

  border-radius: 8px;
}

.modifier-icon {
  font-size: 18px;
}

.modifier-row div {
  display: flex;

  flex-direction: column;
}

.modifier-row strong {
  font-size: 7px;

  font-weight: 1000;
}

.modifier-row small {
  margin-top: 1px;

  font-size: 6px;

  font-weight: 850;
}

.modifier-row.power {
  color: #8a6200;

  background: #fff6d5;
}

.modifier-row.debuff {
  color: #466aa1;

  background: #edf4ff;
}

.modifier-row.defense {
  color: #236a9e;

  background: #e9f6ff;
}

.modifier-row.water {
  color: #087b9b;

  background: #e6fbff;
}

.final-damage-row {
  display: flex;

  align-items: center;

  justify-content: space-between;

  margin-top: 9px;

  padding-top: 8px;

  border-top: 1px solid #dce8ee;
}

.final-damage-row span {
  color: #718897;

  font-size: 7px;

  font-weight: 950;
}

.final-damage-row strong {
  color: #dd4768;

  font-size: 25px;
}

/* =========================================================

   FLYING CARD

========================================================= */

.flying-attack-card {
  width: var(--card-width);

  height: var(--card-height);

  position: fixed;

  left: var(--start-left);

  top: var(--start-top);

  z-index: 80;

  overflow: hidden;

  border: 3px solid #f0d05e;

  border-radius: 17px;

  background: #ffffff;

  opacity: 0;

  transition: all 0.38s cubic-bezier(0.18, 0.82, 0.18, 1);
}

.flying-attack-card img {
  width: 100%;

  height: 100%;

  object-fit: cover;
}

.phase-charge .flying-attack-card {
  opacity: 1;
}

.phase-strike .flying-attack-card,
.phase-impact .flying-attack-card {
  left: var(--target-left);

  top: var(--target-top);

  opacity: 1;

  transform: scale(1.05);
}

.flying-attack-card.power-card {
  box-shadow:
    0 0 22px #ffc83d,
    0 0 60px rgba(255, 173, 24, 0.55);
}

.flying-attack-card.debuff-card {
  filter: saturate(0.65) drop-shadow(0 0 15px rgba(93, 163, 255, 0.8));
}

/* =========================================================

   CINEMATIC SHIELDS

========================================================= */

.cinematic-shield {
  width: 180px;

  height: 180px;

  position: fixed;

  z-index: 90;

  transform: translate(
    -50%,

    -50%
  );

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  border-radius: 50%;

  opacity: 0.92;
}

.cinematic-shield > span {
  font-size: 55px;
}

.cinematic-shield strong {
  margin-top: 5px;

  font-size: 10px;
}

.cinematic-shield small {
  font-size: 7px;

  font-weight: 900;
}

.cinematic-shield.defense {
  color: #216a9e;

  border: 4px solid rgba(59, 145, 216, 0.7);

  background: rgba(231, 247, 255, 0.83);

  box-shadow: 0 0 40px rgba(42, 142, 219, 0.36);
}

.cinematic-shield.water {
  color: #087b9b;

  border: 4px solid rgba(26, 190, 220, 0.72);

  background: rgba(224, 251, 255, 0.82);

  box-shadow: 0 0 45px rgba(20, 184, 220, 0.4);
}

.cinematic-shield.breaking {
  animation: cinematicShieldBreak 0.55s ease-out forwards;
}

@keyframes cinematicShieldBreak {
  30% {
    transform: translate(
        -50%,

        -50%
      )
      scale(1.17);

    filter: brightness(1.6);
  }

  100% {
    transform: translate(
        -50%,

        -50%
      )
      scale(1.45);

    opacity: 0;
  }
}

/* =========================================================

   IMPACT

========================================================= */

.impact-effect {
  position: fixed;

  z-index: 110;

  transform: translate(
    -50%,

    -50%
  );

  color: #ffffff;

  font-size: 110px;

  opacity: 0;
}

.phase-impact .impact-effect {
  animation: impactFx 0.55s ease-out;
}

.phase-impact .impact-effect.strong {
  font-size: 150px;

  text-shadow:
    0 0 25px #ffbf33,
    0 0 65px #ff5c2e;
}

@keyframes impactFx {
  20% {
    opacity: 1;

    transform: translate(
        -50%,

        -50%
      )
      scale(1.3);
  }

  100% {
    opacity: 0;
  }
}

/* =========================================================

   DAMAGE RESULT

========================================================= */

.damage-result {
  position: fixed;

  z-index: 130;

  transform: translate(
    -50%,

    -130%
  );

  display: flex;

  align-items: center;

  gap: 8px;

  padding: 8px 12px;

  border-radius: 11px;

  color: #17324a;

  background: rgba(255, 255, 255, 0.96);

  box-shadow: 0 12px 28px rgba(48, 77, 96, 0.18);

  opacity: 0;
}

.phase-impact .damage-result,
.phase-result .damage-result,
.phase-destroyed .damage-result {
  opacity: 1;
}

.damage-result span {
  color: #738897;

  font-size: 6px;

  font-weight: 950;
}

.damage-result strong {
  color: #df4869;

  font-size: 27px;
}

.damage-result small {
  color: #526f82;

  font-size: 8px;

  font-weight: 900;
}

/* =========================================================

   RESULT LABELS

========================================================= */

.destroyed-label,
.direct-label {
  position: fixed;

  left: 50%;

  bottom: 100px;

  z-index: 130;

  transform: translateX(-50%);

  padding: 10px 16px;

  border-radius: 11px;

  color: #ffffff;

  font-size: 12px;

  font-weight: 1000;
}

.destroyed-label {
  background: #c93f5c;
}

.direct-label {
  background: linear-gradient(135deg, #dd4768, #ff785d);
}

/* =========================================================

   TRANSITION

========================================================= */

.combat-enter-active,
.combat-leave-active {
  transition: opacity 0.2s ease;
}

.combat-enter-from,
.combat-leave-to {
  opacity: 0;
}

/* =========================================================

   RESPONSIVE

========================================================= */

@media (max-width: 1300px) {
  .combat-breakdown {
    width: 280px;
  }

  .big-avatar {
    font-size: 175px;
  }
}

/* =========================================================
   PHASE 3D.13
   FUSION EVENT / HISTORY
   Added on top of the user's existing PublicBattle UI.
========================================================= */

.fusion-history-overlay {
  position: fixed;

  inset: 0;

  z-index: 9800;

  display: grid;
  place-items: center;

  padding: 24px;
}

.fusion-history-backdrop {
  position: absolute;

  inset: 0;

  background: rgba(59, 82, 97, 0.28);

  backdrop-filter: blur(12px);
}

.fusion-history-modal {
  width: min(920px, 94vw);

  max-height: min(760px, 88vh);

  position: relative;

  z-index: 1;

  display: flex;
  flex-direction: column;

  overflow: hidden;

  border: 1px solid rgba(89, 129, 153, 0.16);

  border-radius: 22px;

  background: rgba(248, 253, 255, 0.98);

  box-shadow: 0 28px 80px rgba(57, 83, 99, 0.23);
}

.fusion-history-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;

  padding: 20px 22px;

  border-bottom: 1px solid rgba(74, 119, 144, 0.1);

  background: linear-gradient(180deg, #f7fdff, #eff8fb);
}

.fusion-history-header > div {
  min-width: 0;
}

.fusion-history-header span {
  color: #7659b7;

  font-size: 7px;

  font-weight: 1000;

  letter-spacing: 0.11em;
}

.fusion-history-header h2 {
  margin: 4px 0;

  color: #2d5268;

  font-size: 23px;
}

.fusion-history-header p {
  margin: 0;

  color: #7690a1;

  font-size: 10px;
}

.fusion-history-header > button {
  width: 34px;
  height: 34px;

  flex: 0 0 auto;

  border: 1px solid rgba(79, 121, 146, 0.15);

  border-radius: 11px;

  background: #ffffff;

  color: #607f91;

  font-size: 14px;

  cursor: pointer;
}

.fusion-history-state {
  min-height: 220px;

  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 7px;

  padding: 28px;

  color: #7893a4;

  text-align: center;
}

.fusion-history-state.error {
  color: #b34f70;
}

.fusion-history-state button {
  margin-top: 7px;

  padding: 8px 11px;

  border: 0;

  border-radius: 9px;

  background: #6e55b1;

  color: #ffffff;

  font-family: inherit;

  font-size: 8px;

  font-weight: 1000;

  cursor: pointer;
}

.fusion-history-list {
  overflow: auto;

  display: grid;
  gap: 11px;

  padding: 16px 20px 22px;
}

.fusion-history-entry {
  padding: 13px;

  border: 1px solid rgba(76, 121, 145, 0.1);

  border-radius: 16px;

  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.97),
    rgba(244, 250, 252, 0.96)
  );
}

.fusion-history-top {
  display: flex;
  align-items: center;
  gap: 7px;

  font-size: 7px;

  font-weight: 1000;

  letter-spacing: 0.07em;
}

.fusion-history-top > span {
  padding: 3px 6px;

  border-radius: 999px;
}

.fusion-history-top > span.blue {
  color: #0a8fc5;

  background: rgba(20, 164, 218, 0.1);
}

.fusion-history-top > span.red {
  color: #d34e70;

  background: rgba(224, 79, 112, 0.1);
}

.fusion-history-top > b {
  color: #7659b7;
}

.fusion-history-top > time {
  margin-left: auto;

  color: #99adba;
}

.fusion-history-entry h3 {
  display: flex;
  align-items: center;
  gap: 6px;

  margin: 6px 0 10px;

  color: #31556b;

  font-size: 14px;
}

.fusion-history-combo {
  display: grid;

  grid-template-columns:
    minmax(0, 1fr)
    auto
    minmax(210px, 0.85fr);

  align-items: center;

  gap: 10px;
}

.fusion-history-materials {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.fusion-history-material {
  min-width: 105px;

  display: inline-flex;
  flex-direction: column;
  gap: 2px;

  padding: 7px 8px;

  border: 1px solid rgba(80, 124, 148, 0.11);

  border-radius: 9px;

  background: #ffffff;
}

.fusion-history-material small,
.fusion-history-result small {
  color: #89a1af;

  font-size: 6px;

  font-weight: 1000;

  letter-spacing: 0.07em;
}

.fusion-history-material strong {
  color: #4b6d80;

  font-size: 9px;
}

.fusion-history-arrow {
  color: #9174ca;

  font-size: 19px;

  font-weight: 1000;
}

.fusion-history-result {
  min-width: 0;

  display: flex;
  align-items: center;
  gap: 8px;

  padding: 8px;

  border: 1px solid rgba(111, 85, 177, 0.14);

  border-radius: 11px;

  background: rgba(111, 85, 177, 0.055);
}

.fusion-history-result img {
  width: 40px;
  height: 50px;

  flex: 0 0 auto;

  object-fit: cover;

  border-radius: 7px;
}

.fusion-history-result > div {
  min-width: 0;

  display: flex;
  flex-direction: column;
  gap: 2px;
}

.fusion-history-result strong {
  overflow: hidden;

  color: #3e6075;

  font-size: 10px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.fusion-history-result span {
  color: #738d9e;

  font-size: 7px;

  font-weight: 850;
}

.fusion-pop-enter-active,
.fusion-pop-leave-active {
  transition:
    opacity 0.22s ease,
    transform 0.22s ease;
}

.fusion-pop-enter-from,
.fusion-pop-leave-to {
  opacity: 0;
}

@media (max-width: 760px) {
  .fusion-history-overlay {
    padding: 10px;
  }

  .fusion-history-combo {
    grid-template-columns: 1fr;
  }

  .fusion-history-arrow {
    justify-self: center;

    transform: rotate(90deg);
  }
}


/* =========================================================
   PHASE 3D.16 • ULTIMATE AOE CINEMATIC
========================================================= */

.ultimate-aoe-overlay {
  position: fixed;
  inset: 0;
  z-index: 12450;
  overflow: hidden;
  pointer-events: none;
  color: #fff;
}

.ultimate-aoe-backdrop {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at center, rgba(132, 89, 255, 0.20), transparent 42%),
    rgba(11, 11, 27, 0.72);
  backdrop-filter: blur(3px);
  opacity: 0;
  animation: ultimateBackdropIn 0.45s ease forwards;
}

.ultimate-aoe-title {
  position: absolute;
  top: 7vh;
  left: 50%;
  z-index: 4;
  transform: translateX(-50%);
  text-align: center;
  text-shadow: 0 6px 22px rgba(0, 0, 0, 0.55);
}

.ultimate-aoe-title small {
  display: block;
  margin-bottom: 4px;
  color: #d4c8ff;
  font-size: clamp(8px, 0.7vw, 11px);
  font-weight: 950;
  letter-spacing: 0.14em;
}

.ultimate-aoe-title h2 {
  margin: 0;
  font-size: clamp(30px, 4.2vw, 68px);
  line-height: 0.92;
  letter-spacing: 0.02em;
}

.ultimate-aoe-title p {
  margin: 8px 0 0;
  color: #d9d0f6;
  font-size: clamp(8px, 0.8vw, 12px);
  font-weight: 900;
  letter-spacing: 0.08em;
}

.ultimate-source-card {
  position: fixed;
  z-index: 5;
  width: clamp(82px, 8vw, 132px);
  aspect-ratio: 0.58;
  transform: translate(-50%, -50%) scale(0.78);
  border: 2px solid rgba(210, 190, 255, 0.88);
  border-radius: 14px;
  overflow: hidden;
  display: grid;
  place-items: center;
  background: rgba(37, 25, 70, 0.92);
  box-shadow:
    0 0 34px rgba(149, 105, 255, 0.68),
    0 0 80px rgba(109, 74, 220, 0.38);
  opacity: 0;
}

.ultimate-source-card img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.phase-charge .ultimate-source-card,
.phase-burst .ultimate-source-card,
.phase-impact .ultimate-source-card,
.phase-result .ultimate-source-card {
  animation: ultimateSourceCharge 1.05s cubic-bezier(0.2, 0.8, 0.2, 1) forwards;
}

.ultimate-energy-core {
  position: fixed;
  left: 50%;
  top: 50%;
  z-index: 3;
  width: clamp(100px, 12vw, 190px);
  height: clamp(100px, 12vw, 190px);
  transform: translate(-50%, -50%) scale(0.2);
  display: grid;
  place-items: center;
  border-radius: 50%;
  background:
    radial-gradient(circle, rgba(255, 255, 255, 0.98) 0 8%, rgba(177, 143, 255, 0.95) 24%, rgba(111, 67, 226, 0.52) 54%, transparent 72%);
  filter: drop-shadow(0 0 36px rgba(162, 120, 255, 0.86));
  opacity: 0;
}

.ultimate-energy-core span {
  font-size: clamp(34px, 5vw, 78px);
  filter: drop-shadow(0 0 15px rgba(255,255,255,.9));
}

.ultimate-energy-core b {
  position: absolute;
  bottom: 2px;
  color: #fff;
  font-size: clamp(8px, 0.8vw, 12px);
  letter-spacing: 0.08em;
}

.phase-burst .ultimate-energy-core,
.phase-impact .ultimate-energy-core,
.phase-result .ultimate-energy-core {
  animation: ultimateCoreBurst 1.1s ease-out forwards;
}

.ultimate-target-impact {
  position: fixed;
  z-index: 6;
  transform: translate(-50%, -50%) scale(0.25);
  min-width: 112px;
  display: grid;
  place-items: center;
  text-align: center;
  opacity: 0;
}

.phase-impact .ultimate-target-impact,
.phase-result .ultimate-target-impact {
  animation: ultimateTargetHit 0.68s cubic-bezier(0.18, 0.82, 0.22, 1) forwards;
}

.ultimate-target-impact > span {
  position: absolute;
  font-size: clamp(62px, 8vw, 130px);
  color: rgba(211, 184, 255, 0.92);
  text-shadow:
    0 0 18px rgba(255, 255, 255, 0.95),
    0 0 48px rgba(144, 94, 255, 0.9);
  animation: ultimateImpactSpin 0.65s ease-out both;
}

.ultimate-target-impact strong,
.ultimate-target-impact small,
.ultimate-target-impact em {
  position: relative;
  z-index: 2;
  text-shadow: 0 3px 12px rgba(0,0,0,.8);
}

.ultimate-target-impact strong {
  margin-top: 8px;
  font-size: clamp(22px, 2.6vw, 42px);
  color: #fff;
}

.ultimate-target-impact small {
  margin-top: 2px;
  font-size: clamp(7px, 0.7vw, 10px);
  font-weight: 900;
}

.ultimate-target-impact em {
  margin-top: 4px;
  padding: 3px 7px;
  border-radius: 999px;
  background: rgba(220, 51, 87, 0.82);
  font-size: clamp(7px, 0.65vw, 9px);
  font-style: normal;
  font-weight: 950;
}

.ultimate-target-impact.destroyed strong {
  color: #ff9eb2;
}

.ultimate-aoe-summary {
  position: absolute;
  left: 50%;
  bottom: 7vh;
  z-index: 8;
  transform: translateX(-50%) translateY(14px);
  min-width: min(620px, 82vw);
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 16px;
  padding: 12px 18px;
  border: 1px solid rgba(219, 202, 255, 0.32);
  border-radius: 16px;
  background: rgba(25, 17, 48, 0.82);
  box-shadow: 0 16px 48px rgba(0,0,0,.32);
  opacity: 0;
}

.phase-result .ultimate-aoe-summary,
.phase-exit .ultimate-aoe-summary {
  animation: ultimateSummaryIn 0.42s ease forwards;
}

.ultimate-aoe-summary span,
.ultimate-aoe-summary b {
  color: #d3c7f2;
  font-size: clamp(8px, 0.75vw, 11px);
  font-weight: 900;
}

.ultimate-aoe-summary strong {
  color: #fff;
  font-size: clamp(11px, 1vw, 16px);
}

.ultimate-aoe-summary b {
  color: #ff91ac;
}

.phase-exit.ultimate-aoe-overlay {
  animation: ultimateOverlayExit 0.55s ease forwards;
}

.ultimate-aoe-enter-active,
.ultimate-aoe-leave-active {
  transition: opacity 0.2s ease;
}

.ultimate-aoe-enter-from,
.ultimate-aoe-leave-to {
  opacity: 0;
}

@keyframes ultimateBackdropIn {
  to { opacity: 1; }
}

@keyframes ultimateSourceCharge {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.65) rotate(-5deg); }
  58% { opacity: 1; transform: translate(-50%, -50%) scale(1.08) rotate(2deg); }
  100% { opacity: 1; transform: translate(-50%, -50%) scale(1) rotate(0deg); }
}

@keyframes ultimateCoreBurst {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.15); }
  35% { opacity: 1; transform: translate(-50%, -50%) scale(1.14); }
  100% { opacity: 0.88; transform: translate(-50%, -50%) scale(1); }
}

@keyframes ultimateTargetHit {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.25); }
  38% { opacity: 1; transform: translate(-50%, -50%) scale(1.18); }
  100% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
}

@keyframes ultimateImpactSpin {
  0% { transform: scale(0.15) rotate(0deg); opacity: 0; }
  45% { transform: scale(1.1) rotate(85deg); opacity: 1; }
  100% { transform: scale(0.88) rotate(145deg); opacity: 0.55; }
}

@keyframes ultimateSummaryIn {
  to { opacity: 1; transform: translateX(-50%) translateY(0); }
}

@keyframes ultimateOverlayExit {
  to { opacity: 0; transform: scale(1.02); }
}

@media (prefers-reduced-motion: reduce) {
  .ultimate-source-card,
  .ultimate-energy-core,
  .ultimate-target-impact,
  .ultimate-target-impact > span,
  .ultimate-aoe-summary,
  .ultimate-aoe-overlay {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}


/* Spectator mode owns the viewport, including when the browser goes fullscreen. */
:global(body.public-tv-mode),
:global(body.public-tv-mode #app) {
  margin: 0;
  width: 100%;
  height: 100%;
  overflow: hidden !important;
  overscroll-behavior: none;
}

@media (max-width: 760px), (max-height: 500px) {
  .public-sound-control strong,
  .public-fullscreen-control strong,
  .fusion-history-trigger strong {
    display: none;
  }

  .public-sound-control,
  .public-fullscreen-control,
  .fusion-history-trigger {
    min-height: 22px;
    padding: 3px 5px;
  }

  .fusion-history-trigger { bottom: 31px; }
}
</style>

<style scoped>
.public-battle-page{isolation:isolate;background:#c0e2ef}.public-battle-page::before{content:'';position:absolute;inset:-25px;z-index:-1;background:url('/images/battle-arena/stadium-v1.webp') center/cover;filter:blur(14px) brightness(.65)}.public-battle-page::after{content:'';position:fixed;inset:auto 0 0;height:44px;background:#f0f9fff5;border-top:1px solid #abcfe3;z-index:9400;pointer-events:none}.tbc-orientation-hint{color:#fff;background:#143d67e6;padding:10px 16px;border-radius:8px}.public-battle-page :deep(.battle-pause-notice){top:auto;bottom:50px;width:min(620px,calc(100% - 24px));padding:8px 16px}
.public-layout-control{position:fixed;z-index:9500;bottom:5px;left:50%;transform:translateX(-50%);display:flex;align-items:center;gap:8px;padding:3px 8px;border:1px solid #b9d9ea;border-radius:8px;background:#f4fbfff5;color:#204c79;font-size:10px;font-weight:700}
.public-layout-control select{max-width:170px;background:transparent;border:0;color:#103568;font:700 11px Inter,Arial,sans-serif;padding:4px;cursor:pointer}.public-layout-control select:focus-visible{outline:2px solid #147ead;border-radius:3px}
.public-sound-control,.public-fullscreen-control,.fusion-history-trigger{color:#21567e;background:#f4fbfff5;border-color:#bbdceb;box-shadow:0 2px 8px #10386b22;bottom:8px;min-height:28px;border-radius:8px}
.public-sound-control:hover,.public-fullscreen-control:hover,.fusion-history-trigger:hover{background:#e2f5ff;border-color:#2888b8}.public-sound-control:focus-visible,.public-fullscreen-control:focus-visible,.fusion-history-trigger:focus-visible{outline-color:#087ed0}
.fusion-history-trigger{left:235px}.fusion-history-trigger>b{background:#e8dcfc;color:#6536a8}.public-battle-page :deep(.public-music){bottom:8px}.public-battle-page :deep(.public-music summary){background:#f4fbfff5;color:#21567e;border-color:#bbdceb;min-height:28px;border-radius:8px}
.fusion-history-overlay{background:#0b315b55;backdrop-filter:blur(5px)}.fusion-history-modal{color:#173b68}.fusion-history-header{background:transparent;border-bottom-color:#c8dfef}.fusion-history-header h2{color:#143e74}.fusion-history-header span{color:#1678ac}.fusion-history-header p{color:#537796}.fusion-history-entry{background:#f1f8ff;border-color:#c7def0;color:#244775}.fusion-history-entry h3{color:#143e74}.fusion-history-state{color:#42688b}
@media(max-width:1000px){.fusion-history-trigger{left:80px}.public-battle-page :deep(.public-music){left:40px}.public-battle-page :deep(.public-music summary strong),.public-sound-control strong,.fusion-history-trigger strong,.public-fullscreen-control strong{display:none}.public-layout-control>span{display:none}}
</style>
