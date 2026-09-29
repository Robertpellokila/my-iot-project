<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue";

import { useRoute } from "vue-router";

import { supabase } from "../lib/supabase";

import { useBattleSession } from "../composables/battle/useBattleSession";

import { useBattleUiSync } from "../composables/battle/useBattleUiSync";

import PublicActiveField from "../components/battle/PublicActiveField.vue";

import BattleZoneStack from "../components/battle/BattleZoneStack.vue";

const route = useRoute();

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

  resetSession,
} = useBattleSession();

const activeFieldRef = ref(null);

const {
  players: liveUi,

  connect: connectBattleUi,

  disconnect: disconnectBattleUi,
} = useBattleUiSync();

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

const fusionAnnouncement = ref(null);

let fusionAnnouncementTimer = null;

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

  fusionAnnouncement.value = event;

  if (fusionAnnouncementTimer) {
    clearTimeout(fusionAnnouncementTimer);
  }

  fusionAnnouncementTimer = setTimeout(
    () => {
      fusionAnnouncement.value = null;

      fusionAnnouncementTimer = null;
    },

    4200,
  );
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

  const [attackerCard, targetCard, rects] = await Promise.all([
    fetchBattleCardById(attackerCardId),

    targetCardId ? fetchBattleCardById(targetCardId) : Promise.resolve(null),

    resolveCombatRects({
      sourcePlayer,

      targetPlayer,

      attackerCardId,

      targetCardId,

      attackMode,
    }),
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

    fromRect: rects.fromRect,

    toRect: rects.toRect,

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
        if (event?.type === "attack") {
          void startCombatAnimation(event);
        }
      },
    )

    .subscribe();
};

const unsubscribeCombatEvents = async () => {
  resetCombatAnimation();

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

    if (
      [
        "graveyard",

        "bench",

        "swap",

        "summon",

        "card_destroyed",

        "fusion",
      ].includes(event.type)
    ) {
      void loadGraveyards();
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
  void loadCurrentBattle();
});

onUnmounted(async () => {
  if (fusionAnnouncementTimer) {
    clearTimeout(fusionAnnouncementTimer);

    fusionAnnouncementTimer = null;
  }

  await Promise.all([
    unsubscribeGraveyards(),

    unsubscribeCombatEvents(),

    disconnectBattleUi(),
  ]);
});
</script>

<template>
  <main class="public-battle-page">
    <div v-if="loading" class="public-state">Loading Battle...</div>

    <div v-else-if="error" class="public-state error">
      {{ error }}
    </div>

    <template v-else-if="battle">
      <!-- =================================================
           PHASE 3D.13 • FUSION EVENT ANNOUNCEMENT
      ================================================== -->

      <Transition name="fusion-pop">
        <div v-if="fusionAnnouncement" class="fusion-event-toast">
          <div class="fusion-event-icon">
            {{ fusionAnnouncement.payload?.recipe_icon ?? "🧬" }}
          </div>

          <div class="fusion-event-copy">
            <small>
              {{
                String(
                  fusionAnnouncement.source_player ?? "PLAYER",
                ).toUpperCase()
              }}
              •
              {{ fusionHistoryKindLabel(fusionAnnouncement) }}
            </small>

            <strong>
              {{ fusionAnnouncement.payload?.recipe_name ?? "Fusion" }}
            </strong>

            <span>
              →
              {{ fusionAnnouncement.payload?.result?.name ?? "Fusion Result" }}
            </span>
          </div>
        </div>
      </Transition>

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

          <section class="fusion-history-modal" @click.stop>
            <header class="fusion-history-header">
              <div>
                <span> NEXUS • BATTLE HISTORY </span>

                <h2>Fusion Timeline</h2>

                <p>Live record semua Fusion, Necro Fusion, dan Fusion Chain.</p>
              </div>

              <button type="button" @click="closeFusionHistory">✕</button>
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

      <div class="public-arena-shell">
        <!-- P1 -->

        <aside class="public-zone-rail">
          <div class="zone-player-label blue">
            <span> PLAYER 1 </span>

            <strong>
              {{ battle.player1_name ?? "Player 1" }}
            </strong>
          </div>

          <BattleZoneStack
            zone="bench"
            side="left"
            accent="blue"
            :cards="player1Bench"
            :max="Number(battle.max_bench ?? 4)"
            :readonly="true"
            :allow-drop="false"
            :draggable-cards="false"
            :mirror-only="true"
            :viewer-open="liveUi.p1.viewerZone === 'bench'"
            :viewer-index="liveUi.p1.viewerIndex"
          />

          <div class="deck-counter blue">
            <span> PHYSICAL DECK </span>

            <strong>
              {{ player1DeckRemaining }}

              /

              {{ player1DeckTotal }}
            </strong>
          </div>

          <BattleZoneStack
            zone="graveyard"
            side="left"
            accent="blue"
            :cards="player1Graveyard"
            :readonly="true"
            :mirror-only="true"
            :viewer-open="liveUi.p1.viewerZone === 'graveyard'"
            :viewer-index="liveUi.p1.viewerIndex"
          />
        </aside>

        <!-- CENTER -->

        <section class="public-arena-center">
          <PublicActiveField
            ref="activeFieldRef"
            :battle="battle"
            :player1-active="player1Active"
            :player2-active="player2Active"
            :player1-bench-count="player1Bench.length"
            :player2-bench-count="player2Bench.length"
            :combat-fx="fieldCombatFx"
          />
        </section>

        <!-- P2 -->

        <aside class="public-zone-rail">
          <div class="zone-player-label red">
            <span> PLAYER 2 </span>

            <strong>
              {{ battle.player2_name ?? "Player 2" }}
            </strong>
          </div>

          <BattleZoneStack
            zone="bench"
            side="right"
            accent="red"
            :cards="player2Bench"
            :max="Number(battle.max_bench ?? 4)"
            :readonly="true"
            :mirror-only="true"
            :viewer-open="liveUi.p2.viewerZone === 'bench'"
            :viewer-index="liveUi.p2.viewerIndex"
          />

          <div class="deck-counter red">
            <span> PHYSICAL DECK </span>

            <strong>
              {{ player2DeckRemaining }}

              /

              {{ player2DeckTotal }}
            </strong>
          </div>

          <BattleZoneStack
            zone="graveyard"
            side="right"
            accent="red"
            :cards="player2Graveyard"
            :readonly="true"
            :mirror-only="true"
            :viewer-open="liveUi.p2.viewerZone === 'graveyard'"
            :viewer-index="liveUi.p2.viewerIndex"
          />
        </aside>
      </div>

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

.public-battle-page {
  width: 100vw;

  height: 100dvh;

  position: fixed;

  inset: 0;

  overflow: hidden;

  background: linear-gradient(
    180deg,
    #dff3ff,
    #edf9ff 46%,

    #e3f3e7
  );

  font-family: Inter, system-ui, sans-serif;
}

/* =========================================================

   MAIN

========================================================= */

.public-arena-shell {
  width: 100%;

  height: 100%;

  display: grid;

  grid-template-columns:
    165px
    minmax(0, 1fr)
    165px;

  gap: 10px;

  padding: 8px 10px;
}

.public-arena-center {
  min-width: 0;

  min-height: 0;
}

/* =========================================================

   RAIL

========================================================= */

.public-zone-rail {
  min-height: 0;

  display: grid;

  grid-template-rows:
    50px
    minmax(0, 1fr)
    34px
    minmax(0, 1fr);

  gap: 8px;
}

.zone-player-label {
  display: flex;

  flex-direction: column;

  justify-content: center;

  padding: 7px 11px;

  border-radius: 12px;

  background: #ffffff;
}

.zone-player-label span {
  font-size: 6px;

  font-weight: 1000;
}

.zone-player-label strong {
  color: #17324a;

  font-size: 12px;
}

.zone-player-label.blue {
  border-left: 4px solid #27aae6;
}

.zone-player-label.red {
  border-right: 4px solid #ec5578;

  text-align: right;
}

.public-zone-rail :deep(.battle-zone-stack) {
  width: 100%;

  height: 100%;

  min-height: 0;
}

.deck-counter {
  display: flex;

  align-items: center;

  justify-content: space-between;

  padding: 0 10px;

  border-radius: 9px;

  background: #ffffff;
}

.deck-counter span {
  font-size: 5.5px;

  font-weight: 950;
}

.deck-counter strong {
  font-size: 10px;
}

.deck-counter.blue strong {
  color: #168bc7;
}

.deck-counter.red strong {
  color: #d54867;
}

/* =========================================================

   STATE

========================================================= */

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
  .public-arena-shell {
    grid-template-columns:
      145px
      minmax(0, 1fr)
      145px;
  }

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

.fusion-event-toast {
  position: fixed;

  top: 22px;
  left: 50%;

  z-index: 9500;

  transform: translateX(-50%);

  display: flex;
  align-items: center;
  gap: 12px;

  min-width: min(420px, 88vw);

  padding: 12px 16px;

  border: 1px solid rgba(118, 86, 196, 0.22);

  border-radius: 16px;

  background: rgba(255, 255, 255, 0.96);

  box-shadow: 0 18px 46px rgba(56, 87, 105, 0.17);

  color: #31546a;

  backdrop-filter: blur(16px);
}

.fusion-event-icon {
  width: 42px;
  height: 42px;

  flex: 0 0 auto;

  display: grid;
  place-items: center;

  border-radius: 13px;

  background: linear-gradient(
    145deg,
    rgba(122, 87, 198, 0.13),
    rgba(83, 164, 206, 0.09)
  );

  font-size: 21px;
}

.fusion-event-copy {
  min-width: 0;

  display: flex;
  flex-direction: column;
  gap: 2px;
}

.fusion-event-copy small {
  color: #7d64bd;

  font-size: 7px;

  font-weight: 1000;

  letter-spacing: 0.09em;
}

.fusion-event-copy strong {
  overflow: hidden;

  color: #31546a;

  font-size: 13px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.fusion-event-copy span {
  color: #708d9f;

  font-size: 10px;

  font-weight: 850;
}

.fusion-history-trigger {
  position: fixed;

  top: 118px;
  left: 50%;

  z-index: 500;

  transform:
    translateX(-50%);

  display: inline-flex;
  align-items: center;
  gap: 7px;

  padding:
    7px 11px;

  border:
    1px solid
    rgba(90, 133, 157, 0.18);

  border-radius:
    999px;

  background:
    rgba(255, 255, 255, 0.94);

  box-shadow:
    0 8px 20px
    rgba(61, 106, 129, 0.10);

  color:
    #486c82;

  font-size:
    7px;

  font-weight:
    1000;

  letter-spacing:
    0.05em;

  cursor: pointer;

  backdrop-filter:
    blur(12px);
}

.fusion-history-trigger > span {
  font-size: 13px;
}

.fusion-history-trigger > b {
  min-width: 19px;
  height: 19px;

  display: grid;
  place-items: center;

  border-radius: 999px;

  color: #6f55b1;

  background: rgba(111, 85, 177, 0.1);
}

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
  .fusion-history-trigger {
    top: 10px;
    right: 10px;
  }

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
</style>
