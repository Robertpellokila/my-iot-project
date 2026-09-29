<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from "vue";

import { useRoute } from "vue-router";

import { supabase } from "../lib/supabase";

import { useBattleSession } from "../composables/battle/useBattleSession";

import { useBattleUiSync } from "../composables/battle/useBattleUiSync";

import BattleZoneStack from "../components/battle/BattleZoneStack.vue";

// =========================================================
// ROUTE
// =========================================================

const route = useRoute();

const code = computed(() =>
  String(route.params.code ?? "")
    .trim()
    .toUpperCase(),
);

const player = computed(() =>
  String(route.params.player ?? "p1")
    .trim()
    .toLowerCase() === "p2"
    ? "p2"
    : "p1",
);

const token = computed(() => String(route.query.token ?? "").trim());

// =========================================================
// BATTLE SESSION
// =========================================================

const {
  battle,

  player1Active,
  player2Active,

  player1Bench,
  player2Bench,

  loading,
  error,

  currentQuestion,
  currentQuestionRound,

  questionActive,
  questionLoading,
  questionError,

  maxActive,
  maxBench,

  latestBattleEvent,

  loadBattle,
} = useBattleSession();

// =========================================================
// LOCAL
// =========================================================

const selectedCardId = ref(null);

const actionLoading = ref(false);

const actionMessage = ref("");

const actionError = ref("");

// =========================================================
// ACTION INFORMATION / SPECIAL SKILL UI
// =========================================================

const actionInfoExpanded = ref(false);
const actionInfoModalOpen = ref(false);
const activeActionInfo = ref(null);

const specialSkillModalOpen = ref(false);
const runtimeSpecialSkills = ref([]);
const specialSkillLoading = ref(false);
const selectedSpecialSkillId = ref(null);
const selectedSpecialTargetId = ref(null);

// =========================================================
// PHASE 3D.7 - FUSION UI
// =========================================================

const fusionModalOpen = ref(false);
const runtimeFusions = ref([]);
const fusionLoading = ref(false);
const fusionLoadError = ref("");
const fusionLastMessage = ref("");
const selectedFusionRecipeId = ref(null);

// =========================================================
// PHASE 3D.13 - FUSION BATTLE HISTORY
// =========================================================

const fusionHistoryOpen = ref(false);
const fusionHistory = ref([]);
const fusionHistoryLoading = ref(false);
const fusionHistoryError = ref("");

const fusionHistoryMaterials = (event) =>
  Array.isArray(event?.payload?.materials)
    ? event.payload.materials
    : [];

const fusionHistoryResult = (event) =>
  event?.payload?.result &&
  typeof event.payload.result === "object"
    ? event.payload.result
    : {};

const fusionHistoryKindLabel = (event) => {
  const kind = String(
    event?.payload?.fusion_kind ?? "normal",
  ).toLowerCase();

  const labels = {
    normal: "NORMAL FUSION",
    necro: "NECRO FUSION",
    chain: "CHAIN FUSION",
    necro_chain: "NECRO CHAIN",
  };

  return labels[kind] ?? kind.replaceAll("_", " ").toUpperCase();
};

const fusionHistoryTime = (event) => {
  if (!event?.created_at) return "";

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
  if (!code.value) {
    fusionHistory.value = [];
    return;
  }

  fusionHistoryLoading.value = true;
  fusionHistoryError.value = "";

  try {
    const { data, error } = await supabase.rpc(
      "get_battle_fusion_history",
      {
        p_code: code.value,
        p_limit: 30,
      },
    );

    if (error) {
      throw error;
    }

    if (data?.ok === false) {
      throw new Error(
        data?.message ?? "Fusion history gagal dimuat.",
      );
    }

    fusionHistory.value =
      Array.isArray(data?.events)
        ? data.events
        : [];
  } catch (err) {
    console.error("Load Fusion History:", err);
    fusionHistoryError.value =
      err?.message ?? "Gagal memuat Fusion history.";
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

// =========================================================
// PHASE 2 - TCG TARGETED / DIRECT ATTACK
// =========================================================

const attackTargetMode = ref(false);

const selectedTargetCardId = ref(null);

// =========================================================
// TCG ZONES / DRAG & DROP
// =========================================================

const graveyardCards = ref([]);

const activeDropOver = ref(false);

let graveyardChannel = null;

const getCardId = (card) =>
  card?.battleId ?? card?.battle_id ?? card?.id ?? card?.uid ?? null;

const normalizeBattleCard = (card) => ({
  ...card,

  battleId:
    card?.battleId ??
    card?.id ??
    null,

  benchReturnCount:
    card?.benchReturnCount ??
    card?.bench_return_count ??
    0,

  currentHp:
    card?.currentHp ??
    card?.current_hp ??
    card?.hp ??
    0,

  baseHp:
    card?.baseHp ??
    card?.base_hp ??
    card?.hp ??
    0,
});

// =========================================================
// LIVE PUBLIC UI SYNC
// =========================================================

const {
  connect: connectBattleUi,
  disconnect: disconnectBattleUi,

  openViewer: syncOpenViewer,
  closeViewer: syncCloseViewer,
  setViewerIndex: syncViewerIndex,

  startDrag: syncStartDrag,
  setDragTarget: syncDragTarget,
  endDrag: syncEndDrag,
} = useBattleUiSync();

const handleZoneViewerOpen = ({ zone, index = 0 } = {}) => {
  if (!zone) {
    return;
  }

  void syncOpenViewer(zone, index);
};

const handleZoneViewerClose = () => {
  void syncCloseViewer();
};

const handleZoneViewerIndex = ({ index } = {}) => {
  if (index === undefined || index === null) {
    return;
  }

  void syncViewerIndex(index);
};

const handleZoneDragStart = (card, zone) => {
  if (!card || !zone) {
    return;
  }

  void syncStartDrag(card, zone);
};

const handleZoneDragEnd = () => {
  void syncEndDrag();
};

const handleZoneDragHover = ({ zone } = {}) => {
  void syncDragTarget(zone ?? null);
};

// =========================================================
// TOAST
// =========================================================

const toast = ref({
  show: false,
  type: "success",
  title: "",
  message: "",
});

let toastTimer = null;

const showToast = (type, title, message = "") => {
  if (toastTimer) {
    clearTimeout(toastTimer);

    toastTimer = null;
  }

  toast.value = {
    show: true,
    type,
    title,
    message,
  };

  toastTimer = setTimeout(() => {
    toast.value.show = false;
  }, 3400);
};

const successToast = (title, message = "") => {
  showToast("success", title, message);
};

const warningToast = (title, message = "") => {
  showToast("warning", title, message);
};

const errorToast = (title, message = "") => {
  showToast("error", title, message);
};

// =========================================================
// TCG DRAG & DROP
// =========================================================

const writeDragPayload = (event, card, fromZone) => {
  const payload = {
    cardId: getCardId(card),
    uid: card?.uid ?? null,
    name: card?.name ?? "",
    fromZone,
  };

  event.dataTransfer.effectAllowed = "move";

  event.dataTransfer.setData(
    "application/x-battle-card",
    JSON.stringify(payload),
  );

  event.dataTransfer.setData(
    "text/plain",
    JSON.stringify(payload),
  );
};

const startActiveCardDrag = (event, card) => {
  if (
    actionLoading.value ||
    battleWaiting.value ||
    waitingForRfid.value ||
    questionActive.value ||
    battleFinished.value ||
    !isMyTurn.value ||
    card?.exhausted
  ) {
    event.preventDefault();

    return;
  }

  writeDragPayload(
    event,
    card,
    "active",
  );

  void syncStartDrag(
    card,
    "active",
  );
};

const endActiveCardDrag = () => {
  activeDropOver.value = false;

  void syncDragTarget(null);

  void syncEndDrag();
};

const findCardById = (cards, cardId) =>
  cards.find(
    (card) =>
      String(getCardId(card)) ===
      String(cardId),
  ) ?? null;

const handleBenchDrop = async (payload) => {
  if (
    !payload ||
    payload.fromZone !== "active"
  ) {
    void syncDragTarget(null);

    void syncEndDrag();

    return;
  }

  const card = findCardById(
    activeCards.value,
    payload.cardId,
  );

  if (!card) {
    warningToast(
      "CARD TIDAK DITEMUKAN",
      "Active Card sudah berubah.",
    );

    void syncDragTarget(null);

    void syncEndDrag();

    return;
  }

  try {
    await sendBenchAction(
      "move_to_bench",
      card,
    );
  } finally {
    void syncDragTarget(null);

    void syncEndDrag();
  }
};

const allowActiveDrop = (event) => {
  if (
    actionLoading.value ||
    battleWaiting.value ||
    waitingForRfid.value ||
    questionActive.value ||
    battleFinished.value ||
    !isMyTurn.value
  ) {
    return;
  }

  event.preventDefault();

  event.dataTransfer.dropEffect =
    "move";

  if (!activeDropOver.value) {
    activeDropOver.value = true;

    void syncDragTarget(
      "active",
    );
  }
};

const clearActiveDrop = (event) => {
  const element =
    event?.currentTarget;

  const related =
    event?.relatedTarget;

  if (
    element &&
    related &&
    element.contains(related)
  ) {
    return;
  }

  activeDropOver.value = false;

  void syncDragTarget(null);
};

const readDropPayload = (event) => {
  const raw =
    event.dataTransfer.getData(
      "application/x-battle-card",
    ) ||
    event.dataTransfer.getData(
      "text/plain",
    );

  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const handleActiveDrop = async (event) => {
  activeDropOver.value = false;

  event.preventDefault();

  const payload =
    readDropPayload(event);

  if (
    !payload ||
    payload.fromZone !== "bench"
  ) {
    void syncDragTarget(null);

    void syncEndDrag();

    return;
  }

  const card = findCardById(
    benchCards.value,
    payload.cardId,
  );

  if (!card) {
    warningToast(
      "CARD TIDAK DITEMUKAN",
      "Bench Card sudah berubah.",
    );

    void syncDragTarget(null);

    void syncEndDrag();

    return;
  }

  try {
    await sendBenchAction(
      "return_from_bench",
      card,
    );
  } finally {
    void syncDragTarget(null);

    void syncEndDrag();
  }
};

// =========================================================
// QUESTION
// =========================================================

const selectedQuestionAnswer =
  ref(null);

const bonusUsingId =
  ref(null);

const questionSubmitting =
  ref(false);

const questionResult =
  ref(null);

const questionReward =
  ref(null);

// =========================================================
// BONUS SKILL
// =========================================================

const bonusSkills =
  ref([]);

let bonusChannel =
  null;

// =========================================================
// PLAYER NAMES
// =========================================================

const playerName =
  computed(() => {
    if (!battle.value) {
      return player.value === "p1"
        ? "Player 1"
        : "Player 2";
    }

    return player.value === "p1"
      ? (
          battle.value
            .player1_name ??
          "Player 1"
        )
      : (
          battle.value
            .player2_name ??
          "Player 2"
        );
  });

const enemyName =
  computed(() => {
    if (!battle.value) {
      return player.value === "p1"
        ? "Player 2"
        : "Player 1";
    }

    return player.value === "p1"
      ? (
          battle.value
            .player2_name ??
          "Player 2"
        )
      : (
          battle.value
            .player1_name ??
          "Player 1"
        );
  });

// =========================================================
// CARDS
// =========================================================

const activeCards =
  computed(() =>
    player.value === "p1"
      ? player1Active.value
      : player2Active.value,
  );

const benchCards =
  computed(() =>
    player.value === "p1"
      ? player1Bench.value
      : player2Bench.value,
  );

const enemyActiveCards =
  computed(() =>
    player.value === "p1"
      ? player2Active.value
      : player1Active.value,
  );

const ownDeckRemaining =
  computed(() =>
    Math.max(
      0,

      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_deck_remaining
          : battle.value
              ?.player2_deck_remaining,
      ) || 0,
    ),
  );

const ownDeckTotal =
  computed(() =>
    Math.max(
      0,

      Number(
        player.value === "p1"
          ? (
              battle.value
                ?.player1_starting_deck ??
              battle.value
                ?.deck_size
            )
          : (
              battle.value
                ?.player2_starting_deck ??
              battle.value
                ?.deck_size
            ),
      ) || 0,
    ),
  );

const isTcgV1 =
  computed(
    () =>
      String(
        battle.value
          ?.ruleset ??
          "classic",
      ).toLowerCase() ===
      "tcg_v1",
  );

// =========================================================
// GRAVEYARD
// =========================================================

const loadGraveyardCards =
  async () => {
    if (!battle.value?.id) {
      graveyardCards.value =
        [];

      return;
    }

    const {
      data,
      error: graveyardError,
    } =
      await supabase
        .from(
          "battle_cards",
        )
        .select("*")
        .eq(
          "battle_id",
          battle.value.id,
        )
        .eq(
          "player",
          player.value,
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

    graveyardCards.value =
      (data ?? []).map(
        normalizeBattleCard,
      );
  };

const subscribeGraveyard =
  () => {
    if (
      !battle.value?.id ||
      graveyardChannel
    ) {
      return;
    }

    graveyardChannel =
      supabase
        .channel(
          `player-graveyard-${battle.value.id}-${player.value}`,
        )
        .on(
          "postgres_changes",

          {
            event: "*",

            schema: "public",

            table:
              "battle_cards",

            filter:
              `battle_id=eq.${battle.value.id}`,
          },

          () => {
            void loadGraveyardCards();
          },
        )
        .subscribe();
  };

// =========================================================
// INITIAL BATTLE STATE
// =========================================================

const battleWaiting =
  computed(
    () =>
      battle.value?.status ===
        "waiting" ||
      battle.value?.status ===
        "ready",
  );

const initialCardsRequired =
  computed(() =>
    Math.max(
      1,

      Number(
        battle.value
          ?.initial_cards_required ??
          1,
      ),
    ),
  );

const initialCardCount =
  computed(
    () =>
      activeCards.value.length +
      benchCards.value.length,
  );

const initialReady =
  computed(
    () =>
      initialCardCount.value >=
      initialCardsRequired.value,
  );

// =========================================================
// HP
// =========================================================

const ownHp =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_hp
          : battle.value
              ?.player2_hp,
      ) || 0,
  );

const ownMaxHp =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_max_hp
          : battle.value
              ?.player2_max_hp,
      ) || 200,
  );

const enemyHp =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player2_hp
          : battle.value
              ?.player1_hp,
      ) || 0,
  );

const enemyMaxHp =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player2_max_hp
          : battle.value
              ?.player1_max_hp,
      ) || 200,
  );

const ownHpPercent =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        (
          ownHp.value /
          Math.max(
            1,
            ownMaxHp.value,
          )
        ) * 100,
      ),
    ),
  );

const enemyHpPercent =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        (
          enemyHp.value /
          Math.max(
            1,
            enemyMaxHp.value,
          )
        ) * 100,
      ),
    ),
  );

// =========================================================
// SKILL
// =========================================================

const ownSkill =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_skill
          : battle.value
              ?.player2_skill,
      ) || 0,
  );

// =========================================================
// EFFECT
// =========================================================

const ownDefending =
  computed(() =>
    Boolean(
      player.value === "p1"
        ? battle.value
            ?.player1_defending
        : battle.value
            ?.player2_defending,
    ),
  );

const ownShield =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_synergy_shield
          : battle.value
              ?.player2_synergy_shield,
      ) || 0,
  );

const ownDebuff =
  computed(
    () =>
      Number(
        player.value === "p1"
          ? battle.value
              ?.player1_attack_debuff
          : battle.value
              ?.player2_attack_debuff,
      ) || 0,
  );

// =========================================================
// ONE-TIME / PERSISTENT ACTION STATE
// =========================================================

const ownUltimateUsed =
  computed(() =>
    Boolean(
      player.value === "p1"
        ? battle.value
            ?.player1_ultimate_used
        : battle.value
            ?.player2_ultimate_used,
    ),
  );

const ownHealUsed =
  computed(() =>
    Boolean(
      player.value === "p1"
        ? battle.value
            ?.player1_heal_used
        : battle.value
            ?.player2_heal_used,
    ),
  );

const ownSynergyUsed =
  computed(() => {
    const value =
      player.value === "p1"
        ? battle.value
            ?.player1_synergy_used
        : battle.value
            ?.player2_synergy_used;

    return (
      value &&
      typeof value === "object" &&
      !Array.isArray(value)
        ? value
        : {}
    );
  });

const ownPowerStrikeReady =
  computed(() =>
    Boolean(
      player.value === "p1"
        ? battle.value
            ?.player1_power_strike_ready
        : battle.value
            ?.player2_power_strike_ready,
    ),
  );

// =========================================================
// FINISHED
// =========================================================

const battleFinished =
  computed(
    () =>
      Boolean(
        battle.value?.winner,
      ) ||
      battle.value?.status ===
        "finished",
  );

const didWin =
  computed(
    () =>
      battle.value?.winner ===
      player.value,
  );

// =========================================================
// SUMMON / RFID
// =========================================================

const waitingForRfid =
  computed(
    () =>
      battle.value
        ?.pending_action ===
        "summon" &&
      battle.value
        ?.pending_action_player ===
        player.value,
  );

const enemyWaitingForRfid =
  computed(
    () =>
      battle.value
        ?.pending_action ===
        "summon" &&
      battle.value
        ?.pending_action_player &&
      battle.value
        ?.pending_action_player !==
        player.value,
  );

// =========================================================
// TURN
// =========================================================

const isMyTurn =
  computed(() => {
    if (!battle.value) {
      return false;
    }

    return (
      battle.value.status ===
        "battle" &&
      battle.value.current_turn ===
        player.value &&
      !questionActive.value &&
      !battleFinished.value
    );
  });

// =========================================================
// TURN TEXT
// =========================================================

const turnText =
  computed(() => {
    if (
      battleFinished.value
    ) {
      return didWin.value
        ? "YOU WIN"
        : "BATTLE FINISHED";
    }

    if (
      battleWaiting.value
    ) {
      return initialReady.value
        ? "WAITING OPPONENT"
        : "SCAN INITIAL CARD";
    }

    if (
      questionActive.value
    ) {
      return "CODING CHALLENGE";
    }

    if (
      waitingForRfid.value
    ) {
      return "SCAN RFID NOW";
    }

    if (
      enemyWaitingForRfid.value
    ) {
      return "OPPONENT SUMMONING";
    }

    if (
      isMyTurn.value
    ) {
      return "YOUR TURN";
    }

    return `${enemyName.value.toUpperCase()} TURN`;
  });

// =========================================================
// SELECTED CARD
// =========================================================

const selectedCard =
  computed(
    () =>
      activeCards.value.find(
        (card) =>
          getCardId(card) ===
          selectedCardId.value,
      ) ?? null,
  );

const selectedTargetCard =
  computed(
    () =>
      enemyActiveCards.value.find(
        (card) =>
          getCardId(card) ===
          selectedTargetCardId.value,
      ) ?? null,
  );

const targetedAttackPreview =
  computed(() => {
    if (
      !selectedCard.value ||
      !selectedTargetCard.value
    ) {
      return null;
    }

    const attack =
      Math.max(
        0,

        Number(
          selectedCard.value
            .attack ??
            0,
        ) || 0,
      );

    const defense =
      Math.max(
        0,

        Number(
          selectedTargetCard.value
            .defense ??
            0,
        ) || 0,
      );

    const targetHp =
      Math.max(
        0,

        Number(
          selectedTargetCard.value
            .current_hp ??
            selectedTargetCard.value
              .currentHp ??
            selectedTargetCard.value
              .hp ??
            0,
        ) || 0,
      );

    const baseDamage =
      Math.max(
        1,

        attack -
          defense,
      );

    return {
      attack,

      defense,

      targetHp,

      baseDamage,

      hpAfter:
        Math.max(
          0,

          targetHp -
            baseDamage,
        ),

      wouldDestroy:
        baseDamage >=
          targetHp &&
        targetHp > 0,
    };
  });

// =========================================================
// PHASE 3D.7 - FUSION RUNTIME
// =========================================================

const fusionFeatureEnabled = computed(() =>
  Boolean(
    isTcgV1.value &&
      battle.value?.fusion_enabled !== false,
  ),
);

const readyFusions = computed(() =>
  runtimeFusions.value.filter(
    (recipe) => Boolean(recipe?.available),
  ),
);

const canFusionUi = computed(() =>
  Boolean(
    fusionFeatureEnabled.value &&
      readyFusions.value.length > 0,
  ),
);

const selectedFusion = computed(() => {
  const selected = readyFusions.value.find(
    (recipe) => recipe.recipe_id === selectedFusionRecipeId.value,
  );

  return selected ?? readyFusions.value[0] ?? null;
});

const normalizeFusionRpcPayload = (raw) => {
  let payload = raw;

  if (typeof payload === "string") {
    try {
      payload = JSON.parse(payload);
    } catch (parseError) {
      console.error("Parse get_player_fusions payload:", parseError, payload);
      return { ok: false, message: "Response Fusion server tidak valid.", recipes: [] };
    }
  }

  if (Array.isArray(payload)) {
    return { ok: true, enabled: true, recipes: payload };
  }

  if (payload && typeof payload === "object") {
    // Some clients/wrappers may return { data: {...} }.
    if (payload.data && typeof payload.data === "object" && !Array.isArray(payload.data)) {
      payload = payload.data;
    }

    return {
      ...payload,
      recipes: Array.isArray(payload.recipes) ? payload.recipes : [],
    };
  }

  return { ok: false, message: "Response Fusion kosong.", recipes: [] };
};

const loadPlayerFusions = async () => {
  fusionLoadError.value = "";
  fusionLastMessage.value = "";

  if (!battle.value?.id) {
    fusionLoadError.value = "Battle belum siap.";
    return;
  }

  if (!fusionFeatureEnabled.value) {
    runtimeFusions.value = [];
    selectedFusionRecipeId.value = null;
    fusionLoadError.value = "Fusion tidak aktif pada battle ini.";
    return;
  }

  if (!code.value) {
    fusionLoadError.value = "Battle code tidak ditemukan dari URL.";
    return;
  }

  if (!token.value) {
    fusionLoadError.value = "Player token tidak ditemukan dari URL.";
    return;
  }

  fusionLoading.value = true;

  try {
    const { data, error: fusionError } = await supabase.rpc(
      "get_player_fusions",
      {
        p_code: code.value,
        p_player: player.value,
        p_token: token.value,
      },
    );

    if (fusionError) {
      console.error("get_player_fusions RPC error:", fusionError);
      throw new Error(
        fusionError?.message ||
          fusionError?.details ||
          "RPC get_player_fusions gagal.",
      );
    }

    const payload = normalizeFusionRpcPayload(data);

    console.log("[FUSION] get_player_fusions", {
      code: code.value,
      player: player.value,
      payload,
    });

    if (payload?.ok === false) {
      throw new Error(payload?.message ?? "Fusion Recipe gagal dimuat.");
    }

    fusionLastMessage.value = String(payload?.message ?? "");

    const rows = Array.isArray(payload?.recipes) ? payload.recipes : [];

    // UI hanya boleh mengetahui / menampilkan Fusion yang BENAR-BENAR READY.
    // Recipe yang materialnya belum lengkap, sudah dipakai, atau locked tetap
    // boleh dikembalikan backend untuk diagnostic, tetapi tidak masuk state UI.
    const readyRows = rows.filter(
      (recipe) =>
        recipe?.available === true &&
        recipe?.matcher_available !== false &&
        recipe?.limit_reached !== true,
    );

    runtimeFusions.value = readyRows;

    const stillExists = readyRows.some(
      (recipe) => recipe?.recipe_id === selectedFusionRecipeId.value,
    );

    if (!stillExists) {
      selectedFusionRecipeId.value =
        readyRows[0]?.recipe_id ??
        null;
    }
  } catch (err) {
    console.error("Load Fusion Recipes:", err);
    fusionLoadError.value = err?.message ?? "Gagal memuat Fusion Recipe.";
    runtimeFusions.value = [];
    selectedFusionRecipeId.value = null;
  } finally {
    fusionLoading.value = false;
  }
};

const fusionRequirementLabel = (requirement) => {
  const type = String(requirement?.type ?? requirement?.material_type ?? "").toLowerCase();

  if (type === "exact_card") {
    return requirement?.card_code || "EXACT CARD";
  }

  if (type === "one_of") {
    const codes = Array.isArray(requirement?.card_codes)
      ? requirement.card_codes
      : [];

    return codes.length ? codes.join(" / ") : "ONE OF";
  }

  if (type === "tag") {
    return `#${requirement?.tag || "TAG"}`;
  }

  return type ? type.toUpperCase() : "MATERIAL";
};

const fusionRequirementProgress = (requirement) => {
  const have = Math.max(0, Number(requirement?.eligible_count ?? 0) || 0);
  const need = Math.max(1, Number(requirement?.quantity ?? 1) || 1);

  return {
    have,
    need,
    ready: have >= need,
  };
};

const fusionZoneText = (requirement) => {
  const zones = Array.isArray(requirement?.allowed_zones)
    ? requirement.allowed_zones
    : [];

  if (!zones.length) {
    return "ANY ZONE";
  }

  return zones.map((zone) => String(zone).toUpperCase()).join(" + ");
};

const fusionStat = (recipe, field) =>
  Math.max(
    0,
    Number(recipe?.calculated_stats?.[field] ?? 0) || 0,
  );

const openFusionModal = async (recipe = null) => {
  if (!fusionFeatureEnabled.value) {
    warningToast("FUSION DISABLED", "Fusion tidak aktif pada battle ini.");
    return;
  }

  // Open immediately so loading/error state is visible instead of being
  // silently converted into an empty recipe list.
  fusionModalOpen.value = true;

  await loadPlayerFusions();

  const requestedId = recipe?.recipe_id ?? null;
  const requestedRecipe = requestedId
    ? readyFusions.value.find((item) => item?.recipe_id === requestedId)
    : null;

  const preferred =
    requestedRecipe ??
    readyFusions.value[0] ??
    null;

  selectedFusionRecipeId.value = preferred?.recipe_id ?? null;
};

const closeFusionModal = (silent = false) => {
  fusionModalOpen.value = false;

  if (!silent) {
    // closing the modal is not a battle action
  }
};

const chooseFusion = (recipe) => {
  selectedFusionRecipeId.value = recipe?.recipe_id ?? null;
};

const submitFusion = async () => {
  if (!validateActionTurn()) {
    return;
  }

  const recipe = selectedFusion.value;

  if (!recipe) {
    warningToast("FUSION", "Pilih Fusion Recipe terlebih dahulu.");
    return;
  }

  if (!recipe.available) {
    warningToast(
      "FUSION BELUM READY",
      recipe?.message ?? "Material Fusion belum lengkap.",
    );
    return;
  }

  actionLoading.value = true;

  try {
    const { data, error: rpcError } = await supabase.rpc(
      "submit_battle_action",
      {
        p_code: code.value,
        p_player: player.value,
        p_token: token.value,
        p_action: "fusion",
        p_card_id: null,
        p_payload: {
          recipe_id: recipe.recipe_id,
        },
      },
    );

    if (rpcError) {
      throw rpcError;
    }

    if (data?.ok === false) {
      warningToast(
        "FUSION DITOLAK",
        data?.message ?? "Fusion ditolak server.",
      );
      return;
    }

    successToast(
      `${recipe.icon || "🧬"} FUSION SUCCESS`,
      data?.result_name
        ? `${data.result_name} berhasil dipanggil.`
        : data?.message ?? "Fusion berhasil dilakukan.",
    );

    closeFusionModal(true);
    selectedCardId.value = null;
    attackTargetMode.value = false;
    selectedTargetCardId.value = null;

    await loadBattle(code.value);
    await Promise.all([
      loadGraveyardCards(),
      loadPlayerFusions(),
    ]);
  } catch (err) {
    console.error("Fusion:", err);
    errorToast(
      "FUSION ERROR",
      err?.message ?? "Gagal melakukan Fusion.",
    );
  } finally {
    actionLoading.value = false;
  }
};

// =========================================================
// PHASE 3C - SPECIAL SKILL RUNTIME
// =========================================================

const battleRound = computed(() =>
  Math.max(1, Number(battle.value?.round ?? 1) || 1),
);

const specialSkillFeatureEnabled = computed(() =>
  Boolean(
    isTcgV1.value &&
      battle.value?.special_card_skills_enabled !== false,
  ),
);

const normalizeJsonObject = (value) =>
  value && typeof value === "object" && !Array.isArray(value) ? value : {};

const normalizeJsonArray = (value) => (Array.isArray(value) ? value : []);

const skillTargetSpec = (skill) => normalizeJsonObject(skill?.target_spec);
const skillCostSpec = (skill) => normalizeJsonObject(skill?.cost_spec);
const skillLimits = (skill) => normalizeJsonObject(skill?.limits);
const skillEffects = (skill) => normalizeJsonArray(skill?.effects);

const loadSelectedCardSpecialSkills = async () => {
  runtimeSpecialSkills.value = [];
  selectedSpecialSkillId.value = null;
  selectedSpecialTargetId.value = null;

  if (
    !battle.value?.id ||
    !selectedCard.value ||
    !specialSkillFeatureEnabled.value
  ) {
    return;
  }

  const cardId = getCardId(selectedCard.value);

  if (!cardId) {
    return;
  }

  specialSkillLoading.value = true;

  try {
    const { data: skills, error: skillError } = await supabase
      .from("battle_card_skills")
      .select("*")
      .eq("battle_id", battle.value.id)
      .eq("battle_card_id", cardId)
      .eq("player", player.value)
      .order("priority", { ascending: true })
      .order("skill_code", { ascending: true });

    if (skillError) {
      throw skillError;
    }

    const rows = skills ?? [];
    const ids = rows.map((skill) => skill.id).filter(Boolean);
    const usageCount = new Map();

    if (ids.length) {
      const { data: uses, error: useError } = await supabase
        .from("battle_special_skill_uses")
        .select("battle_card_skill_id, usage_number")
        .eq("battle_id", battle.value.id)
        .in("battle_card_skill_id", ids);

      if (useError) {
        throw useError;
      }

      for (const use of uses ?? []) {
        const key = use.battle_card_skill_id;
        const previous = usageCount.get(key) ?? 0;
        const current = Number(use.usage_number ?? 0) || 0;
        usageCount.set(key, Math.max(previous, current));
      }
    }

    runtimeSpecialSkills.value = rows.map((skill) => ({
      ...skill,
      usage_count: usageCount.get(skill.id) ?? 0,
    }));
  } catch (err) {
    console.error("Load Special Skills:", err);
    runtimeSpecialSkills.value = [];
  } finally {
    specialSkillLoading.value = false;
  }
};

const specialSkillReadyState = (skill) => {
  if (!skill) {
    return {
      ready: false,
      status: "NO SKILL",
      reason: "Special Skill tidak tersedia.",
    };
  }

  if (!specialSkillFeatureEnabled.value) {
    return {
      ready: false,
      status: "DISABLED",
      reason: "Special Skill dinonaktifkan pada battle ini.",
    };
  }

  if (!selectedCard.value) {
    return {
      ready: false,
      status: "SELECT CARD",
      reason: "Pilih Active Card terlebih dahulu.",
    };
  }

  const limits = skillLimits(skill);
  const cost = skillCostSpec(skill);
  const uses = Number(skill.usage_count ?? 0) || 0;
  const oncePerBattle = Boolean(limits.once_per_battle);
  const configuredMax = Number(limits.max_uses ?? 0) || 0;
  const maxUses = oncePerBattle ? 1 : configuredMax > 0 ? configuredMax : null;

  if (maxUses !== null && uses >= maxUses) {
    return {
      ready: false,
      status: "USED",
      reason: oncePerBattle
        ? "Skill ini hanya dapat digunakan 1× per battle."
        : `Batas penggunaan ${maxUses}× sudah tercapai.`,
    };
  }

  const cooldownUntil = Number(skill.cooldown_until_round ?? 0) || 0;

  if (cooldownUntil > 0 && battleRound.value <= cooldownUntil) {
    return {
      ready: false,
      status: `CD R${cooldownUntil + 1}`,
      reason: `Cooldown aktif. Skill tersedia kembali pada Round ${cooldownUntil + 1}.`,
    };
  }

  const costType = String(cost.type ?? "none").toLowerCase();
  const costValue = Math.max(0, Number(cost.value ?? cost.amount ?? 0) || 0);

  if (
    ["skill_gauge", "ultimate_gauge"].includes(costType) &&
    ownSkill.value < costValue
  ) {
    return {
      ready: false,
      status: `${ownSkill.value}/${costValue} GAUGE`,
      reason: `Membutuhkan ${costValue} Skill Gauge.`,
    };
  }

  return {
    ready: true,
    status: "READY",
    reason: "Special Skill siap digunakan.",
  };
};

const readySpecialSkills = computed(() =>
  runtimeSpecialSkills.value.filter(
    (skill) => specialSkillReadyState(skill).ready,
  ),
);

const canSpecialUi = computed(() =>
  Boolean(selectedCard.value && readySpecialSkills.value.length > 0),
);

const selectedSpecialSkill = computed(() => {
  const selected = runtimeSpecialSkills.value.find(
    (skill) => skill.id === selectedSpecialSkillId.value,
  );

  return selected ?? runtimeSpecialSkills.value[0] ?? null;
});

const selectedSpecialTargetType = computed(() =>
  String(
    skillTargetSpec(selectedSpecialSkill.value).type ??
      skillTargetSpec(selectedSpecialSkill.value).target ??
      "",
  )
    .trim()
    .toLowerCase(),
);

const selectedSpecialTargetRequired = computed(() => {
  const spec = skillTargetSpec(selectedSpecialSkill.value);

  if (typeof spec.required === "boolean") {
    return spec.required;
  }

  return [
    "enemy_active",
    "ally_active",
    "any_active",
    "enemy_graveyard",
    "ally_graveyard",
    "any_card",
  ].includes(selectedSpecialTargetType.value);
});

const specialTargetCards = computed(() => {
  const type = selectedSpecialTargetType.value;

  if (type === "enemy_active") {
    return enemyActiveCards.value;
  }

  if (type === "ally_active" || type === "any_active") {
    return activeCards.value;
  }

  if (type === "ally_graveyard") {
    return graveyardCards.value;
  }

  if (["self", "self_card", "source_card"].includes(type)) {
    return selectedCard.value ? [selectedCard.value] : [];
  }

  return [];
});

const selectedSpecialTarget = computed(() =>
  specialTargetCards.value.find(
    (card) => getCardId(card) === selectedSpecialTargetId.value,
  ) ?? null,
);

const formatSpecialTarget = (skill) => {
  const type = String(skillTargetSpec(skill).type ?? "").toLowerCase();
  const labels = {
    enemy_active: "Enemy Active Card",
    ally_active: "Ally Active Card",
    any_active: "Any Active Card",
    self: "Self",
    self_card: "Source Card",
    source_card: "Source Card",
    self_player: "Self Player",
    source_player: "Self Player",
    enemy_player: "Enemy Player",
    opponent_player: "Enemy Player",
    ally_graveyard: "Ally Graveyard",
    enemy_graveyard: "Enemy Graveyard",
  };

  return labels[type] ?? (type ? type.replaceAll("_", " ").toUpperCase() : "Automatic");
};

const formatSpecialCost = (skill) => {
  const cost = skillCostSpec(skill);
  const type = String(cost.type ?? "none").toLowerCase();
  const value = Math.max(0, Number(cost.value ?? cost.amount ?? 0) || 0);

  if (["", "none", "free"].includes(type)) {
    return "Free";
  }

  if (["skill_gauge", "ultimate_gauge"].includes(type)) {
    return `${value} Skill Gauge`;
  }

  return `${type.replaceAll("_", " ")} ${value}`.trim();
};

const formatSpecialLimits = (skill) => {
  const limits = skillLimits(skill);
  const parts = [];
  const cooldown = Math.max(0, Number(limits.cooldown_rounds ?? limits.cooldown ?? 0) || 0);
  const maxUses = Math.max(0, Number(limits.max_uses ?? 0) || 0);

  if (limits.once_per_battle) {
    parts.push("1× per battle");
  } else if (maxUses > 0) {
    parts.push(`max ${maxUses}×`);
  } else {
    parts.push("unlimited uses");
  }

  parts.push(cooldown > 0 ? `${cooldown} round cooldown` : "no cooldown");

  return parts.join(" • ");
};

const describeAmount = (amount) => {
  if (!amount || typeof amount !== "object") {
    return "";
  }

  const mode = String(amount.mode ?? "fixed").toLowerCase();
  const value = Number(amount.value ?? 0) || 0;

  if (mode === "fixed") {
    return `${value}`;
  }

  if (mode.includes("percent")) {
    return `${Math.round(value * 100)}%`;
  }

  return `${value} (${mode.replaceAll("_", " ")})`;
};

const describeSpecialEffects = (skill) => {
  const effects = skillEffects(skill);

  if (!effects.length) {
    return ["Tidak ada effect yang dikonfigurasi."];
  }

  return effects.map((effect) => {
    const type = String(effect?.type ?? "effect").toLowerCase();
    const amount = describeAmount(effect?.amount);
    const labels = {
      damage_card: "Damage Card",
      heal_card: "Heal Card",
      damage_player: "Damage Player",
      heal_player: "Heal Player",
      add_skill_gauge: "Tambah Skill Gauge",
      revive: "Revive",
      add_status: "Tambah Status",
      remove_status: "Hapus Status",
      move_zone: "Pindah Zone",
      set_card_exhausted: "Set Exhausted",
    };

    const label = labels[type] ?? type.replaceAll("_", " ").toUpperCase();
    return amount ? `${label}: ${amount}` : label;
  });
};

// =========================================================
// PLAYER SKILL INFO / AVAILABILITY
//
// Ini sengaja dibuat data-driven supaya nanti Special Skill
// dan Fusion bisa masuk ke panel yang sama tanpa merombak UI.
// =========================================================

const normalizeElement =
  (value) =>
    String(
      value ?? "",
    )
      .trim()
      .toLowerCase();

const formatPercent =
  (ratio) =>
    Math.round(
      Math.max(
        0,
        Number(ratio) || 0,
      ) *
        100,
    );

const SYNERGY_INFO = {
  grass: {
    icon: "🌿",
    name: "NATURE RESTORE",
    values: {
      2: 30,
      3: 45,
      4: 60,
    },
  },

  fire: {
    icon: "🔥",
    name: "BLAZE BURST",
    values: {
      2: 1.5,
      3: 1.8,
      4: 2.2,
    },
  },

  water: {
    icon: "💧",
    name: "AQUA BARRIER",
    values: {
      2: 40,
      3: 60,
      4: 80,
    },
  },

  electric: {
    icon: "⚡",
    name: "VOLT CHARGE",
    values: {
      2: 40,
      3: 70,
      4: 100,
    },
  },

  ice: {
    icon: "❄️",
    name: "FROST CURSE",
    values: {
      2: 25,
      3: 40,
      4: 60,
    },
  },

  dark: {
    icon: "🌑",
    name: "SHADOW BURST",
    values: {
      2: 1.4,
      3: 1.7,
      4: 2,
    },
  },
};

const selectedElement =
  computed(() =>
    normalizeElement(
      selectedCard.value
        ?.element,
    ),
  );

const selectedCardAttack =
  computed(() =>
    Math.max(
      0,

      Number(
        selectedCard.value
          ?.attack ??
          0,
      ) || 0,
    ),
  );

const selectedElementCount =
  computed(() => {
    const element =
      selectedElement.value;

    if (!element) {
      return 0;
    }

    return activeCards.value.filter(
      (card) =>
        normalizeElement(
          card.element,
        ) === element &&
        !card.exhausted,
    ).length;
  });

const selectedSynergyUsed =
  computed(() => {
    const element =
      selectedElement.value;

    if (!element) {
      return false;
    }

    return Boolean(
      ownSynergyUsed.value[
        element
      ],
    );
  });

const selectedSynergyInfo =
  computed(() => {
    if (!selectedCard.value) {
      return {
        icon: "✧",
        name: "SYNERGY",
        element: "",
        points: 0,
        supported: false,
        used: false,
        ready: false,
        status: "SELECT CARD",
        effect:
          "Pilih Active Card untuk melihat Synergy element-nya.",
        detail:
          "Synergy membutuhkan minimal 2 Active Card non-exhausted dengan element yang sama.",
      };
    }

    const element =
      selectedElement.value;

    const config =
      SYNERGY_INFO[
        element
      ];

    if (!config) {
      return {
        icon: "✧",
        name: "NO SYNERGY",
        element,
        points:
          selectedElementCount.value,
        supported: false,
        used: false,
        ready: false,
        status:
          "UNSUPPORTED",
        effect:
          `${
            element
              ? element.toUpperCase()
              : "UNKNOWN"
          } belum memiliki Synergy.`,
        detail:
          "Element Synergy yang tersedia: Grass, Fire, Water, Electric, Ice, dan Dark.",
      };
    }

    const points =
      Math.min(
        4,
        selectedElementCount.value,
      );

    const tier =
      points >= 4
        ? 4
        : points >= 3
          ? 3
          : 2;

    const value =
      config.values[tier];

    const used =
      selectedSynergyUsed.value;

    const ready =
      points >= 2 &&
      !used;

    const attack =
      selectedCardAttack.value;

    let effect = "";
    let detail = "";

    if (
      element ===
      "grass"
    ) {
      const estimated =
        Math.round(
          ownMaxHp.value *
            (value / 100),
        );

      effect =
        `Restore ${value}% Max HP (hingga +${estimated} HP).`;

      detail =
        "2 cards = 30% • 3 cards = 45% • 4+ cards = 60%. Heal tetap dibatasi Max HP.";
    }

    else if (
      element ===
      "fire"
    ) {
      const baseDamage =
        Math.max(
          1,
          Math.round(
            attack *
              value,
          ),
        );

      effect =
        `Selected Card ATK ×${value} → ${baseDamage} base damage.`;

      detail =
        "2 cards = ×1.5 • 3 cards = ×1.8 • 4+ cards = ×2.2. Attack Debuff, Defense, dan Water Shield dapat mengurangi final damage.";
    }

    else if (
      element ===
      "water"
    ) {
      effect =
        `Aqua Barrier: next incoming damage -${value}%.`;

      detail =
        "2 cards = -40% • 3 cards = -60% • 4+ cards = -80%. Shield dikonsumsi saat menerima serangan.";
    }

    else if (
      element ===
      "electric"
    ) {
      effect =
        `Ultimate Gauge +${value}% (maksimum 100%).`;

      detail =
        "2 cards = +40 • 3 cards = +70 • 4+ cards = +100 Ultimate Gauge.";
    }

    else if (
      element ===
      "ice"
    ) {
      effect =
        `Enemy next attack damage -${value}%.`;

      detail =
        "2 cards = -25% • 3 cards = -40% • 4+ cards = -60%. Debuff dikonsumsi ketika lawan menyerang.";
    }

    else if (
      element ===
      "dark"
    ) {
      const baseDamage =
        Math.max(
          1,
          Math.round(
            attack *
              value,
          ),
        );

      effect =
        `Selected Card ATK ×${value} → ${baseDamage} base damage.`;

      detail =
        "2 cards = ×1.4 • 3 cards = ×1.7 • 4+ cards = ×2.0. Mengabaikan normal Defense; Water Shield dan Attack Debuff tetap berlaku.";
    }

    return {
      icon:
        config.icon,

      name:
        config.name,

      element,

      points,

      supported: true,

      used,

      ready,

      status:
        used
          ? "USED"
          : ready
            ? "READY"
            : `${points}/2 REQUIRED`,

      effect:
        points >= 2
          ? effect
          : `Butuh 2 ${element.toUpperCase()} Active Cards. Pada 2 cards: ${effect}`,

      detail,
    };
  });

const canAttackUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ),
  );

const canDefenseUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ),
  );

const canUltimateUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ) &&
      ownSkill.value >=
        100 &&
      !ownUltimateUsed.value,
  );

const canHealUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ) &&
      ownHp.value > 0 &&
      ownHp.value <=
        ownMaxHp.value *
          0.5 &&
      !ownHealUsed.value,
  );

const canSynergyUi =
  computed(
    () =>
      Boolean(
        selectedSynergyInfo
          .value
          ?.ready,
      ),
  );

const canSummonUi =
  computed(() => {
    const activeSpace =
      activeCards.value.length <
      maxActive.value;

    if (!isTcgV1.value) {
      return activeSpace;
    }

    return (
      activeSpace &&
      ownDeckRemaining.value >
        0
    );
  });

const skillLockText =
  (type) => {
    if (
      type === "attack" &&
      !selectedCard.value
    ) {
      return "SELECT CARD";
    }

    if (
      type === "defense"
    ) {
      if (!selectedCard.value) {
        return "SELECT CARD";
      }

      if (ownDefending.value) {
        return "ACTIVE";
      }
    }

    if (
      type === "ultimate"
    ) {
      if (
        ownUltimateUsed.value
      ) {
        return "USED";
      }

      if (!selectedCard.value) {
        return "SELECT CARD";
      }

      if (
        ownSkill.value < 100
      ) {
        return `${ownSkill.value}% / 100%`;
      }
    }

    if (
      type === "heal"
    ) {
      if (
        ownHealUsed.value
      ) {
        return "USED";
      }

      if (!selectedCard.value) {
        return "SELECT CARD";
      }

      if (
        ownHp.value >
        ownMaxHp.value *
          0.5
      ) {
        return "HP > 50%";
      }
    }

    if (
      type === "synergy"
    ) {
      return (
        selectedSynergyInfo
          .value
          ?.status ??
        "SELECT CARD"
      );
    }

    if (
      type === "summon" &&
      !canSummonUi.value
    ) {
      if (
        isTcgV1.value &&
        ownDeckRemaining.value <=
          0
      ) {
        return "DECK EMPTY";
      }

      return "ACTIVE FULL";
    }

    if (type === "special") {
      if (!specialSkillFeatureEnabled.value) {
        return "DISABLED";
      }

      if (!selectedCard.value) {
        return "SELECT CARD";
      }

      if (specialSkillLoading.value) {
        return "LOADING";
      }

      if (!runtimeSpecialSkills.value.length) {
        return "NO SKILL";
      }

      if (!canSpecialUi.value) {
        return specialSkillReadyState(runtimeSpecialSkills.value[0]).status;
      }
    }

    return "";
  };

const skillInfoItems =
  computed(() => {
    const card =
      selectedCard.value;

    const attack =
      selectedCardAttack.value;

    const directBase =
      Math.max(
        1,
        Math.round(
          attack * 0.5,
        ),
      );

    const healAmount =
      Math.round(
        ownMaxHp.value *
          0.35,
      );

    const ultimateBase =
      Math.max(
        1,
        Math.round(
          attack * 2,
        ),
      );

    const directReady =
      isTcgV1.value &&
      Boolean(
        battle.value
          ?.direct_attack_enabled,
      ) &&
      enemyActiveCards.value
        .length === 0;

    const attackModifiers =
      [];

    if (
      ownPowerStrikeReady.value
    ) {
      attackModifiers.push(
        "Power Strike READY: next attack ×1.50 (+50%)",
      );
    }

    if (
      ownDebuff.value > 0
    ) {
      attackModifiers.push(
        `Attack Debuff: next attack -${formatPercent(
          ownDebuff.value,
        )}%`,
      );
    }

    const attackDetail =
      !card
        ? "Pilih Active Card sebagai attacker."
        : isTcgV1.value
          ? directReady
            ? `Enemy tidak memiliki Active Card. Direct Attack memakai 50% ATK: ${attack} × 0.50 = ${directBase} base Player HP damage.`
            : `Targeted Attack memakai max(1, ATK − target DEF). ATK card terpilih: ${attack}.`
          : `Basic Attack memakai ATK card terpilih: ${attack}.`;

    return [
      {
        key: "attack",
        icon: "⚔️",
        title:
          directReady
            ? "DIRECT ATTACK"
            : "ATTACK",
        status:
          card
            ? "READY"
            : "SELECT CARD",
        ready:
          Boolean(card),
        effect:
          attackDetail,
        detail:
          attackModifiers.length
            ? attackModifiers.join(
                " • ",
              )
            : "Attack berakhir dengan perpindahan turn.",
      },

      {
        key: "defense",
        icon: "🛡️",
        title: "DEFENSE",
        status:
          ownDefending.value
            ? "ACTIVE"
            : card
              ? "READY"
              : "SELECT CARD",
        ready:
          Boolean(card),
        effect:
          "Next incoming damage ×0.50 (-50%).",
        detail:
          "Memberi +10 Ultimate Gauge. Defense dikonsumsi saat serangan lawan mengenainya.",
      },

      {
        key: "ultimate",
        icon: "⚡",
        title: "ULTIMATE",
        status:
          ownUltimateUsed.value
            ? "USED"
            : !card
              ? "SELECT CARD"
              : ownSkill.value >=
                  100
                ? "READY"
                : `${ownSkill.value}% / 100%`,
        ready:
          canUltimateUi.value,
        effect:
          card
            ? `Selected Card ATK ×2 → ${ultimateBase} base damage.`
            : "Pilih Active Card untuk menghitung Ultimate.",
        detail:
          "Membutuhkan 100% Ultimate Gauge, gauge kembali ke 0, dan hanya 1× per battle. Attack Debuff, Defense, dan Water Shield dapat mengubah final damage.",
      },

      {
        key: "heal",
        icon: "💚",
        title: "HEAL",
        status:
          ownHealUsed.value
            ? "USED"
            : !card
              ? "SELECT CARD"
              : canHealUi.value
                ? "READY"
                : "HP > 50%",
        ready:
          canHealUi.value,
        effect:
          `Restore 35% Max HP (hingga +${healAmount} HP).`,
        detail:
          "Hanya tersedia ketika Player HP ≤ 50%, dibatasi Max HP, dan hanya 1× per battle.",
      },

      {
        key: "synergy",
        icon:
          selectedSynergyInfo
            .value.icon,
        title:
          selectedSynergyInfo
            .value.name,
        status:
          selectedSynergyInfo
            .value.status,
        ready:
          canSynergyUi.value,
        effect:
          selectedSynergyInfo
            .value.effect,
        detail:
          selectedSynergyInfo
            .value.detail,
      },

      {
        key: "summon",
        icon: "🎴",
        title: "SUMMON",
        status:
          waitingForRfid.value
            ? "SCAN RFID"
            : canSummonUi.value
              ? "READY"
              : skillLockText(
                  "summon",
                ),
        ready:
          canSummonUi.value,
        effect:
          isTcgV1.value
            ? `RFID → Active. Physical Deck tersisa ${ownDeckRemaining.value}/${ownDeckTotal.value}.`
            : "Scan RFID untuk menambahkan card ke Active Deck.",
        detail:
          `Active ${activeCards.value.length}/${maxActive.value}. Summon membutuhkan slot Active yang tersedia${
            isTcgV1.value
              ? " dan Physical Deck > 0."
              : "."
          }`,
      },
    ];
  });

// =========================================================
// ACTION INFO MODAL + SPECIAL SKILL ACTION
// =========================================================

const specialActionInfo = computed(() => {
  const skill = readySpecialSkills.value[0] ?? runtimeSpecialSkills.value[0] ?? null;
  const state = skill ? specialSkillReadyState(skill) : null;

  return {
    key: "special",
    icon: skill?.icon || "✨",
    title: skill?.name ? `SPECIAL • ${skill.name}` : "SPECIAL SKILL",
    status: specialSkillLoading.value
      ? "LOADING"
      : skill
        ? state?.status ?? "LOCKED"
        : selectedCard.value
          ? "NO SKILL"
          : "SELECT CARD",
    ready: Boolean(skill && state?.ready),
    effect: skill
      ? skill.description || describeSpecialEffects(skill).join(" • ")
      : "Kemampuan bawaan kartu TCG V1.",
    detail: skill
      ? `${formatSpecialTarget(skill)} • ${formatSpecialCost(skill)} • ${formatSpecialLimits(skill)}`
      : "Pilih card yang mempunyai Special Skill.",
  };
});

const fusionActionInfo = computed(() => {
  const recipe = readyFusions.value[0] ?? null;

  return {
    key: "fusion",
    icon: recipe?.icon || "🧬",
    title: recipe?.recipe_name ? `FUSION • ${recipe.recipe_name}` : "FUSION",
    status: fusionLoading.value
      ? "LOADING"
      : !fusionFeatureEnabled.value
        ? "DISABLED"
        : recipe
          ? recipe.available
            ? "READY"
            : recipe.status || "MATERIALS"
          : "NO RECIPE",
    ready: Boolean(recipe?.available),
    effect: recipe
      ? `${recipe.result_name || "Fusion Result"} • ${recipe.required_material_count || 0} material`
      : "Gabungkan material card untuk memanggil Fusion Card.",
    detail: recipe
      ? `${recipe.material_destination || "graveyard"} → ${recipe.result_zone || "active"} • ${recipe.consumes_turn === false ? "Free Action" : "Consumes Turn"}`
      : "Fusion Recipe dan material ditentukan sepenuhnya oleh server.",
  };
});

const actionInfoItems = computed(() => [
  ...skillInfoItems.value,
  specialActionInfo.value,
  fusionActionInfo.value,
]);

const openActionInfo = (info) => {
  if (!info) {
    return;
  }

  if (info.key === "special") {
    openSpecialSkillModal();
    return;
  }

  if (info.key === "fusion") {
    void openFusionModal();
    return;
  }

  activeActionInfo.value = info;
  actionInfoModalOpen.value = true;
};

const openActionInfoByKey = (key) => {
  const info = actionInfoItems.value.find((item) => item.key === key);

  if (info) {
    openActionInfo(info);
  }
};

const closeActionInfoModal = () => {
  actionInfoModalOpen.value = false;
  activeActionInfo.value = null;
};

const openSpecialSkillModal = (skill = null) => {
  if (!selectedCard.value) {
    warningToast("PILIH CARD", "Pilih Active Card terlebih dahulu.");
    return;
  }

  if (!specialSkillFeatureEnabled.value) {
    warningToast("SPECIAL SKILL DISABLED", "Special Skill tidak aktif pada battle ini.");
    return;
  }

  if (!runtimeSpecialSkills.value.length) {
    warningToast("NO SPECIAL SKILL", `${selectedCard.value.name} tidak memiliki Special Skill.`);
    return;
  }

  const preferred =
    skill ?? readySpecialSkills.value[0] ?? runtimeSpecialSkills.value[0];

  selectedSpecialSkillId.value = preferred?.id ?? null;
  selectedSpecialTargetId.value = null;
  specialSkillModalOpen.value = true;
};

const closeSpecialSkillModal = (silent = false) => {
  specialSkillModalOpen.value = false;
  selectedSpecialTargetId.value = null;

  if (!silent) {
    // intentionally no toast; closing an info modal is not an action
  }
};

const chooseSpecialSkill = (skill) => {
  selectedSpecialSkillId.value = skill?.id ?? null;
  selectedSpecialTargetId.value = null;
};

const chooseSpecialTarget = (card) => {
  selectedSpecialTargetId.value = getCardId(card);
};

const submitSpecialSkill = async () => {
  if (!validateActionTurn()) {
    return;
  }

  const source = selectedCard.value;
  const skill = selectedSpecialSkill.value;

  if (!source || !skill) {
    warningToast("SPECIAL SKILL", "Pilih card dan Special Skill terlebih dahulu.");
    return;
  }

  const readiness = specialSkillReadyState(skill);

  if (!readiness.ready) {
    warningToast("SPECIAL SKILL LOCKED", readiness.reason);
    return;
  }

  if (selectedSpecialTargetRequired.value && !selectedSpecialTarget.value) {
    warningToast("PILIH TARGET", "Pilih target Special Skill terlebih dahulu.");
    return;
  }

  const sourceId = getCardId(source);
  const targetId = selectedSpecialTarget.value
    ? getCardId(selectedSpecialTarget.value)
    : null;

  actionLoading.value = true;

  try {
    const { data, error: rpcError } = await supabase.rpc(
      "submit_battle_action",
      {
        p_code: code.value,
        p_player: player.value,
        p_token: token.value,
        p_action: "special_skill",
        p_card_id: sourceId,
        p_payload: {
          skill_id: skill.id,
          target_card_id: targetId,
        },
      },
    );

    if (rpcError) {
      throw rpcError;
    }

    if (data?.ok === false) {
      warningToast("SPECIAL SKILL DITOLAK", data?.message ?? "Skill ditolak server.");
      return;
    }

    const damage = Number(data?.damage ?? 0) || 0;
    const heal = Number(data?.heal ?? 0) || 0;
    const parts = [];

    if (damage > 0) {
      parts.push(`${damage} damage`);
    }

    if (heal > 0) {
      parts.push(`+${heal} heal`);
    }

    successToast(
      `${skill.icon || "✨"} ${String(skill.name ?? skill.skill_code ?? "SPECIAL").toUpperCase()}`,
      data?.message ?? (parts.length ? parts.join(" • ") : "Special Skill berhasil digunakan."),
    );

    closeSpecialSkillModal(true);

    if (data?.ends_turn !== false) {
      selectedCardId.value = null;
    }

    await loadBattle(code.value);
    await loadSelectedCardSpecialSkills();
  } catch (err) {
    console.error("Special Skill:", err);
    errorToast("SPECIAL SKILL ERROR", err?.message ?? "Gagal menggunakan Special Skill.");
  } finally {
    actionLoading.value = false;
  }
};

// =========================================================
// CARD SELECTION
// =========================================================

const selectCard =
  (card) => {
    if (
      battleWaiting.value
    ) {
      warningToast(
        "BATTLE BELUM DIMULAI",

        "Tunggu sampai kedua player selesai melakukan initial scan.",
      );

      return;
    }

    if (
      questionActive.value
    ) {
      warningToast(
        "QUESTION IN PROGRESS",

        "Selesaikan Coding Challenge terlebih dahulu.",
      );

      return;
    }

    if (
      !isMyTurn.value
    ) {
      warningToast(
        "BUKAN TURN KAMU",

        `Sekarang giliran ${enemyName.value}.`,
      );

      return;
    }

    if (
      waitingForRfid.value
    ) {
      warningToast(
        "SUMMON MODE ACTIVE",

        "Scan RFID Card terlebih dahulu.",
      );

      return;
    }

    if (
      card.exhausted
    ) {
      warningToast(
        "CARD EXHAUSTED",

        "Card ini tidak dapat digunakan.",
      );

      return;
    }

    selectedCardId.value =
      getCardId(card);

    successToast(
      "CARD SELECTED",

      card.name,
    );
  };

// =========================================================
// VALIDATE TURN BEFORE ACTION
// =========================================================

const validateActionTurn =
  () => {
    if (
      battleWaiting.value
    ) {
      warningToast(
        "BATTLE BELUM DIMULAI",

        "Lakukan Initial Scan terlebih dahulu.",
      );

      return false;
    }

    if (
      questionActive.value
    ) {
      warningToast(
        "CODING CHALLENGE ACTIVE",

        "Jawab question terlebih dahulu.",
      );

      return false;
    }

    if (
      !isMyTurn.value
    ) {
      warningToast(
        "BUKAN TURN KAMU",

        `Sekarang giliran ${enemyName.value}.`,
      );

      return false;
    }

    if (
      waitingForRfid.value
    ) {
      warningToast(
        "SCAN RFID DULU",

        "Summon sedang aktif. Tempelkan RFID Card.",
      );

      return false;
    }

    return true;
  };

// =========================================================
// PHASE 2 - TARGETED / DIRECT ATTACK
// =========================================================

const cancelTargetAttack =
  (silent = false) => {
    attackTargetMode.value =
      false;

    selectedTargetCardId.value =
      null;

    if (!silent) {
      warningToast(
        "ATTACK CANCELLED",

        "Pemilihan target dibatalkan.",
      );
    }
  };

const directAttackAvailable =
  computed(
    () =>
      isTcgV1.value &&
      Boolean(
        battle.value
          ?.direct_attack_enabled,
      ) &&
      enemyActiveCards.value
        .length === 0,
  );

const beginAttackAction =
  () => {
    if (
      !validateActionTurn()
    ) {
      return;
    }

    if (
      !selectedCard.value
    ) {
      warningToast(
        "PILIH ATTACKER",

        "Pilih Active Card yang akan menyerang.",
      );

      return;
    }

    if (
      !isTcgV1.value
    ) {
      void submitAction(
        "attack",
      );

      return;
    }

    if (
      !enemyActiveCards.value
        .length
    ) {
      if (
        !battle.value
          ?.direct_attack_enabled
      ) {
        warningToast(
          "DIRECT ATTACK DISABLED",

          "Lawan tidak memiliki Active Card, tetapi Direct Attack dinonaktifkan untuk battle ini.",
        );

        return;
      }

      void submitDirectAttack();

      return;
    }

    selectedTargetCardId.value =
      null;

    attackTargetMode.value =
      true;

    successToast(
      "SELECT TARGET",

      `Pilih Active Card milik ${enemyName.value}, lalu konfirmasi serangan.`,
    );
  };

// =========================================================
// DIRECT ATTACK
// =========================================================

const submitDirectAttack =
  async () => {
    actionError.value =
      "";

    actionMessage.value =
      "";

    if (
      !validateActionTurn()
    ) {
      return;
    }

    if (
      !isTcgV1.value
    ) {
      return;
    }

    if (
      !selectedCard.value
    ) {
      warningToast(
        "PILIH ATTACKER",

        "Pilih Active Card yang akan melakukan Direct Attack.",
      );

      return;
    }

    if (
      enemyActiveCards.value
        .length > 0
    ) {
      warningToast(
        "TARGET CARD REQUIRED",

        `${enemyName.value} masih memiliki Active Card. Pilih target terlebih dahulu.`,
      );

      return;
    }

    if (
      !battle.value
        ?.direct_attack_enabled
    ) {
      warningToast(
        "DIRECT ATTACK DISABLED",

        "Direct Attack dinonaktifkan untuk battle ini.",
      );

      return;
    }

    const attackerId =
      getCardId(
        selectedCard.value,
      );

    if (!attackerId) {
      errorToast(
        "CARD ID ERROR",

        "Attacker tidak memiliki Battle Card ID.",
      );

      return;
    }

    actionLoading.value =
      true;

    attackTargetMode.value =
      false;

    selectedTargetCardId.value =
      null;

    try {
      const attackerName =
        selectedCard.value
          ?.name ??
        "Card";

      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "submit_battle_action",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_action:
              "attack",

            p_card_id:
              attackerId,

            p_payload: {},
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      if (
        data?.ok === false
      ) {
        warningToast(
          "DIRECT ATTACK DITOLAK",

          data?.message ??
            "Direct Attack ditolak server.",
        );

        return;
      }

      const damage =
        Number(
          data?.damage ??
            data?.final_damage ??
            data?.player_damage ??
            0,
        ) || 0;

      const winner =
        data?.winner ??
        null;

      let message =
        `${attackerName} menyerang ${enemyName.value} langsung`;

      if (damage > 0) {
        message +=
          ` dan memberikan ${damage} Player HP damage.`;
      } else {
        message += ".";
      }

      if (winner) {
        message +=
          " Battle selesai.";
      }

      successToast(
        winner
          ? "🏆 DIRECT ATTACK FINISH"
          : "💥 DIRECT HIT",

        message,
      );

      selectedCardId.value =
        null;
    } catch (err) {
      console.error(
        "Direct attack:",
        err,
      );

      errorToast(
        "DIRECT ATTACK ERROR",

        err?.message ??
          "Gagal memproses Direct Attack.",
      );
    } finally {
      actionLoading.value =
        false;
    }
  };

// =========================================================
// TARGET SELECTION
// =========================================================

const selectAttackTarget =
  (card) => {
    if (
      !attackTargetMode.value ||
      actionLoading.value
    ) {
      return;
    }

    const id =
      getCardId(card);

    if (!id) {
      return;
    }

    selectedTargetCardId.value =
      id;
  };

// =========================================================
// TARGETED ATTACK
// =========================================================

const submitTargetedAttack =
  async () => {
    actionError.value =
      "";

    actionMessage.value =
      "";

    if (
      !validateActionTurn()
    ) {
      cancelTargetAttack(
        true,
      );

      return;
    }

    if (
      !selectedCard.value
    ) {
      warningToast(
        "ATTACKER TIDAK ADA",

        "Pilih Active Card yang akan menyerang.",
      );

      cancelTargetAttack(
        true,
      );

      return;
    }

    if (
      !selectedTargetCard.value
    ) {
      warningToast(
        "PILIH TARGET",

        "Pilih satu Active Card lawan.",
      );

      return;
    }

    const attackerId =
      getCardId(
        selectedCard.value,
      );

    const targetId =
      getCardId(
        selectedTargetCard.value,
      );

    if (
      !attackerId ||
      !targetId
    ) {
      errorToast(
        "CARD ID ERROR",

        "Attacker atau target tidak memiliki Battle Card ID.",
      );

      return;
    }

    actionLoading.value =
      true;

    try {
      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "submit_battle_action",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_action:
              "attack",

            p_card_id:
              attackerId,

            p_payload: {
              target_card_id:
                targetId,
            },
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      if (
        data?.ok === false
      ) {
        warningToast(
          "ATTACK DITOLAK",

          data?.message ??
            "Targeted attack ditolak server.",
        );

        return;
      }

      const damage =
        Number(
          data?.damage ??
            data?.final_damage ??
            0,
        ) || 0;

      const playerDamage =
        Number(
          data?.player_damage ??
            0,
        ) || 0;

      const destroyed =
        Boolean(
          data?.destroyed,
        );

      const targetName =
        selectedTargetCard.value
          ?.name ??
        "Target";

      let message =
        data?.message ??
        `${selectedCard.value.name} memberikan ${damage} damage ke ${targetName}.`;

      if (destroyed) {
        message +=
          ` ${targetName} masuk Graveyard.`;

        if (
          playerDamage > 0
        ) {
          message +=
            ` ${enemyName.value} menerima ${playerDamage} destruction damage.`;
        }
      }

      successToast(
        destroyed
          ? "💥 CARD DESTROYED"
          : "⚔ ATTACK SUCCESS",

        message,
      );

      selectedCardId.value =
        null;

      attackTargetMode.value =
        false;

      selectedTargetCardId.value =
        null;
    } catch (err) {
      console.error(
        "Targeted attack:",
        err,
      );

      errorToast(
        "ATTACK ERROR",

        err?.message ??
          "Gagal memproses targeted attack.",
      );
    } finally {
      actionLoading.value =
        false;
    }
  };

// =========================================================
// SUBMIT ACTION
// =========================================================

const submitAction =
  async (actionType) => {
    actionError.value =
      "";

    actionMessage.value =
      "";

    if (!battle.value) {
      return;
    }

    if (!token.value) {
      errorToast(
        "TOKEN TIDAK VALID",

        "Player token tidak ditemukan.",
      );

      return;
    }

    if (
      !validateActionTurn()
    ) {
      return;
    }

    if (
      actionType ===
        "attack" &&
      isTcgV1.value
    ) {
      beginAttackAction();

      return;
    }

    const cardRequired =
      actionType !==
      "summon";

    if (
      cardRequired &&
      !selectedCard.value
    ) {
      warningToast(
        "PILIH CARD",

        "Pilih Active Card terlebih dahulu.",
      );

      return;
    }

    if (
      actionType ===
        "ultimate" &&
      ownSkill.value < 100
    ) {
      warningToast(
        "ULTIMATE BELUM READY",

        `Gauge kamu masih ${ownSkill.value}%.`,
      );

      return;
    }

    actionLoading.value =
      true;

    try {
      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "submit_battle_action",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_action:
              actionType,

            p_card_id:
              cardRequired
                ? getCardId(
                    selectedCard.value,
                  )
                : null,

            p_payload: {},
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      if (
        data?.ok === false
      ) {
        const message =
          data?.message ??
          "Action ditolak.";

        if (
          message
            .toLowerCase()
            .includes(
              "giliran",
            ) ||
          message
            .toLowerCase()
            .includes(
              "turn",
            )
        ) {
          warningToast(
            "BUKAN TURN KAMU",

            message,
          );
        } else {
          warningToast(
            "ACTION DITOLAK",

            message,
          );
        }

        return;
      }

      if (
        actionType ===
          "summon" &&
        data?.waiting_rfid
      ) {
        selectedCardId.value =
          null;

        successToast(
          "SUMMON MODE ACTIVE",

          `Scan card menggunakan ${
            player.value ===
            "p1"
              ? "RC522-P1"
              : "RC522-P2"
          }.`,
        );

        return;
      }

      selectedCardId.value =
        null;

      attackTargetMode.value =
        false;

      selectedTargetCardId.value =
        null;

      successToast(
        `${actionType.toUpperCase()} SUCCESS`,

        data?.message ??
          "Action berhasil diproses.",
      );
    } catch (err) {
      console.error(
        "Submit action:",
        err,
      );

      errorToast(
        "ACTION ERROR",

        err?.message ??
          "Gagal memproses action.",
      );
    } finally {
      actionLoading.value =
        false;
    }
  };

// =========================================================
// BENCH ACTION
// =========================================================

const sendBenchAction =
  async (
    actionType,
    card,
  ) => {
    if (
      !validateActionTurn()
    ) {
      return;
    }

    actionLoading.value =
      true;

    try {
      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "submit_battle_action",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_action:
              actionType,

            p_card_id:
              card.id,

            p_payload: {},
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      if (
        data?.ok === false
      ) {
        warningToast(
          "BENCH ACTION DITOLAK",

          data?.message ??
            "Action tidak dapat dilakukan.",
        );

        return;
      }

      successToast(
        "BENCH UPDATED",

        data?.message ??
          "Card berhasil dipindahkan.",
      );
    } catch (err) {
      errorToast(
        "BENCH ERROR",

        err?.message ??
          "Gagal memproses Bench.",
      );
    } finally {
      actionLoading.value =
        false;
    }
  };

// =========================================================
// QUESTION ANSWER
//
// FIX:
// 1. battle.current_question_round_id diprioritaskan karena
//    battle session adalah sumber state realtime utama.
// 2. stale response dari question lama tidak boleh mengunci
//    question baru.
// 3. interaction state di-reset setiap Question baru muncul.
// =========================================================

const effectiveQuestionRoundId =
  computed(
    () =>
      battle.value
        ?.current_question_round_id ??
      currentQuestionRound.value
        ?.id ??
      null,
  );

const questionSubmissionRoundId =
  ref(null);

const questionReady =
  computed(
    () =>
      Boolean(
        questionActive.value &&
        currentQuestion.value &&
        effectiveQuestionRoundId
          .value &&
        !questionLoading.value &&
        !questionError.value,
      ),
  );

const questionInteractionLocked =
  computed(
    () =>
      questionSubmitting.value ||
      Boolean(
        questionResult.value,
      ) ||
      !questionReady.value,
  );

const resetQuestionInteraction =
  () => {
    selectedQuestionAnswer.value =
      null;

    questionSubmitting.value =
      false;

    questionResult.value =
      null;

    questionReward.value =
      null;

    questionSubmissionRoundId.value =
      null;
  };

const answerQuestion =
  async (index) => {
    if (
      questionInteractionLocked
        .value
    ) {
      return;
    }

    const questionRoundId =
      effectiveQuestionRoundId
        .value;

    if (!questionRoundId) {
      errorToast(
        "QUESTION SYNC",

        "Question Round ID belum tersedia. Tunggu sebentar lalu pilih jawaban.",
      );

      return;
    }

    if (!token.value) {
      errorToast(
        "TOKEN TIDAK VALID",

        "Player token tidak ditemukan.",
      );

      return;
    }

    selectedQuestionAnswer.value =
      index;

    questionSubmitting.value =
      true;

    questionSubmissionRoundId.value =
      questionRoundId;

    try {
      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "submit_battle_question_answer",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_question_round_id:
              questionRoundId,

            p_answer_index:
              index,
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      /*
       * Question bisa berganti lewat realtime ketika RPC
       * masih berjalan. Response dari round lama tidak boleh
       * mengubah state question baru.
       */
      if (
        effectiveQuestionRoundId
          .value !==
        questionRoundId
      ) {
        return;
      }

      if (
        data?.ok === false
      ) {
        selectedQuestionAnswer.value =
          null;

        warningToast(
          "ANSWER DITOLAK",

          data?.message ??
            "Jawaban tidak dapat diproses.",
        );

        return;
      }

      if (
        data?.correct === true
      ) {
        questionResult.value =
          "correct";

        questionReward.value =
          data?.reward ??
          null;

        await loadBonusSkills();

        successToast(
          "🏆 FIRST CORRECT!",

          data?.reward
            ? `Bonus skill: ${bonusLabel(
                data.reward,
              )}`
            : "Jawaban benar!",
        );

        return;
      }

      if (
        data?.already_finished ===
        true
      ) {
        questionResult.value =
          "lost";

        warningToast(
          "TOO LATE",

          "Player lain sudah menjawab benar terlebih dahulu.",
        );

        return;
      }

      /*
       * Satu attempt per Question tetap dipertahankan.
       * Kalau server menyatakan wrong, option dikunci sampai
       * round Question selesai seperti behavior sebelumnya.
       */
      questionResult.value =
        "wrong";

      warningToast(
        "JAWABAN SALAH",

        data?.message ??
          "Jawaban kamu belum benar.",
      );
    } catch (err) {
      console.error(
        "QUESTION SUBMIT ERROR",

        err,
      );

      /*
       * Network / RPC error bukan jawaban final.
       * Buka kembali tombol supaya pemain dapat retry.
       */
      if (
        effectiveQuestionRoundId
          .value ===
        questionRoundId
      ) {
        selectedQuestionAnswer.value =
          null;
      }

      errorToast(
        "QUESTION ERROR",

        err?.message ??
          "Gagal mengirim jawaban. Silakan coba lagi.",
      );
    } finally {
      if (
        questionSubmissionRoundId
          .value ===
        questionRoundId
      ) {
        questionSubmitting.value =
          false;

        questionSubmissionRoundId.value =
          null;
      }
    }
  };

// =========================================================
// BONUS
// =========================================================

const bonusLabel =
  (skill) => {
    const labels = {
      power_strike:
        "Power Strike",

      iron_guard:
        "Iron Guard",

      recovery:
        "Recovery",

      overcharge:
        "Overcharge",

      cleanse:
        "Cleanse",
    };

    return labels[skill] ??
      skill;
  };

const bonusIcon =
  (skill) => {
    const icons = {
      power_strike:
        "⚔️",

      iron_guard:
        "🛡️",

      recovery:
        "💚",

      overcharge:
        "⚡",

      cleanse:
        "✨",
    };

    return icons[skill] ??
      "✨";
  };

const bonusDescription =
  (skill) => {
    const descriptions = {
      power_strike:
        "Next Attack damage ×1.50 (+50%). Dikonsumsi setelah serangan.",

      iron_guard:
        "Aktifkan Defense: next incoming damage ×0.50 (-50%).",

      recovery:
        "Restore 25% Max Player HP.",

      overcharge:
        "Ultimate Gauge +50%, maksimum 100%.",

      cleanse:
        "Menghapus Attack Debuff yang sedang aktif.",
    };

    return (
      descriptions[skill] ??
      "Bonus skill dari Coding Challenge."
    );
  };

// =========================================================
// LOAD BONUS
// =========================================================

const loadBonusSkills =
  async () => {
    if (
      !battle.value?.id
    ) {
      return;
    }

    const {
      data,
      error: bonusError,
    } =
      await supabase
        .from(
          "battle_bonus_skills",
        )
        .select("*")
        .eq(
          "battle_id",
          battle.value.id,
        )
        .eq(
          "player",
          player.value,
        )
        .order(
          "created_at",

          {
            ascending:
              false,
          },
        );

    if (bonusError) {
      return;
    }

    bonusSkills.value =
      data ?? [];
  };

const useBonusSkill =
  async (bonus) => {
    if (
      !bonus ||
      bonus.used ||
      bonusUsingId.value
    ) {
      return;
    }

    if (
      questionActive.value
    ) {
      warningToast(
        "CODING CHALLENGE ACTIVE",

        "Selesaikan question terlebih dahulu.",
      );

      return;
    }

    if (
      !isMyTurn.value
    ) {
      warningToast(
        "BUKAN TURN KAMU",

        `Sekarang giliran ${enemyName.value}.`,
      );

      return;
    }

    bonusUsingId.value =
      bonus.id;

    try {
      const {
        data,
        error: rpcError,
      } =
        await supabase.rpc(
          "use_battle_bonus_skill",

          {
            p_code:
              code.value,

            p_player:
              player.value,

            p_token:
              token.value,

            p_bonus_id:
              bonus.id,
          },
        );

      if (rpcError) {
        throw rpcError;
      }

      if (
        data?.ok === false
      ) {
        warningToast(
          "BONUS DITOLAK",

          data?.message ??
            "Bonus tidak dapat digunakan.",
        );

        return;
      }

      await loadBonusSkills();

      const skill =
        data?.skill_type ??
        bonus.skill_type;

      let message =
        data?.message ??
        "Bonus berhasil digunakan.";

      if (
        skill ===
        "power_strike"
      ) {
        message =
          "Basic Attack berikutnya mendapatkan +50% damage.";
      } else if (
        skill ===
        "iron_guard"
      ) {
        message =
          "Defense aktif.";
      } else if (
        skill ===
        "recovery"
      ) {
        message =
          data?.heal
            ? `HP pulih +${data.heal}.`
            : "HP berhasil dipulihkan.";
      } else if (
        skill ===
        "overcharge"
      ) {
        message =
          "Ultimate Gauge bertambah +50.";
      } else if (
        skill ===
        "cleanse"
      ) {
        message =
          "Attack debuff berhasil dihapus.";
      }

      successToast(
        `${bonusIcon(skill)} ${bonusLabel(skill).toUpperCase()}`,

        message,
      );
    } catch (err) {
      console.error(
        "Use bonus:",
        err,
      );

      errorToast(
        "BONUS ERROR",

        err?.message ??
          "Gagal menggunakan bonus skill.",
      );
    } finally {
      bonusUsingId.value =
        null;
    }
  };

// =========================================================
// BONUS REALTIME
// =========================================================

const subscribeBonusSkills =
  () => {
    if (
      !battle.value?.id
    ) {
      return;
    }

    bonusChannel =
      supabase
        .channel(
          `bonus-${battle.value.id}-${player.value}`,
        )
        .on(
          "postgres_changes",

          {
            event: "*",

            schema: "public",

            table:
              "battle_bonus_skills",

            filter:
              `battle_id=eq.${battle.value.id}`,
          },

          (payload) => {
            if (
              payload.new
                ?.player ===
                player.value ||
              payload.old
                ?.player ===
                player.value
            ) {
              void loadBonusSkills();
            }
          },
        )
        .subscribe();
  };

// =========================================================
// WATCHERS
// =========================================================

watch(
  effectiveQuestionRoundId,

  (
    roundId,
    previousRoundId,
  ) => {
    if (
      roundId &&
      roundId !==
        previousRoundId
    ) {
      resetQuestionInteraction();
    }
  },
);

watch(
  questionActive,

  (
    active,
    previous,
  ) => {
    /*
     * Question harus mengambil alih seluruh interaction.
     * Ini menutup Target Picker, drag state, dan viewer yang
     * sebelumnya dapat berada di atas / menangkap klik.
     */
    if (
      active &&
      !previous
    ) {
      resetQuestionInteraction();

      cancelTargetAttack(
        true,
      );

      activeDropOver.value =
        false;

      selectedTargetCardId.value =
        null;

      void syncDragTarget(
        null,
      );

      void syncEndDrag();

      void syncCloseViewer();
    }

    if (
      !active &&
      previous
    ) {
      resetQuestionInteraction();
    }
  },

  {
    immediate: true,
  },
);

watch(
  waitingForRfid,

  (
    waiting,
    previous,
  ) => {
    if (
      waiting &&
      !previous
    ) {
      successToast(
        "📡 SUMMON READY",

        "Scan RFID Card sekarang.",
      );
    }

    if (
      !waiting &&
      previous
    ) {
      successToast(
        "✨ SUMMON SELESAI",

        "Card berhasil ditambahkan dan turn berpindah.",
      );
    }
  },
);

watch(
  initialReady,

  (
    ready,
    previous,
  ) => {
    if (
      ready &&
      !previous &&
      battleWaiting.value
    ) {
      successToast(
        "PLAYER READY",

        "Initial Card selesai. Menunggu opponent.",
      );
    }
  },
);

watch(
  () =>
    battle.value?.status,

  (
    status,
    previous,
  ) => {
    if (
      status ===
        "battle" &&
      (
        previous ===
          "waiting" ||
        previous ===
          "ready"
      )
    ) {
      successToast(
        "⚔️ BATTLE START",

        isMyTurn.value
          ? "Kamu mendapatkan turn pertama."
          : `${enemyName.value} mendapatkan turn pertama.`,
      );
    }
  },
);

// =========================================================
// BATTLE EVENT
// =========================================================

watch(
  latestBattleEvent,

  (event) => {
    if (!event) {
      return;
    }

    const message =
      String(
        event.payload
          ?.message ??
          "",
      );

    if (
      event.type ===
        "rfid_warning" &&
      event.source_player ===
        player.value
    ) {
      const normalized =
        message.toUpperCase();

      if (
        normalized.includes(
          "ALREADY",
        ) ||
        normalized.includes(
          "USED",
        )
      ) {
        warningToast(
          "KARTU SUDAH PERNAH DIGUNAKAN",

          "Gunakan RFID Card lain.",
        );
      } else if (
        normalized.includes(
          "WAIT FOR PLAYER",
        ) ||
        normalized.includes(
          "TURN",
        )
      ) {
        warningToast(
          "BUKAN TURN KAMU",

          message,
        );
      } else if (
        normalized.includes(
          "PRESS SUMMON",
        )
      ) {
        warningToast(
          "TEKAN SUMMON DULU",

          "Aktifkan Summon sebelum melakukan scan RFID.",
        );
      } else if (
        normalized.includes(
          "QUESTION",
        )
      ) {
        warningToast(
          "QUESTION IN PROGRESS",

          "RFID tidak dapat digunakan saat Coding Challenge.",
        );
      } else if (
        normalized.includes(
          "NOT REGISTERED",
        )
      ) {
        warningToast(
          "CARD BELUM TERDAFTAR",

          "Daftarkan RFID Card terlebih dahulu.",
        );
      } else {
        warningToast(
          "RFID WARNING",

          message ||
            "RFID scan ditolak.",
        );
      }

      return;
    }

    if (
      event.type ===
        "summon" &&
      event.source_player ===
        player.value &&
      event.payload?.phase ===
        "battle"
    ) {
      const hpGain =
        Number(
          event.payload
            ?.hp_gain ??
            0,
        );

      successToast(
        "✨ SUMMON SUCCESS",

        hpGain > 0
          ? `HP bertambah +${hpGain}.`
          : "Card berhasil masuk ke Active Deck.",
      );

      selectedCardId.value =
        null;

      return;
    }
  },
);

watch(
  latestBattleEvent,

  (event) => {
    if (!event) {
      return;
    }

    if (
      event.type ===
        "graveyard" ||
      event.type ===
        "bench" ||
      event.type ===
        "swap" ||
      event.type ===
        "summon" ||
      event.type ===
        "card_destroyed"
    ) {
      void loadGraveyardCards();
    }
  },
);

// =========================================================
// TARGET MODE SAFETY
// =========================================================

watch(
  [
    () =>
      battle.value
        ?.current_turn,

    () =>
      battle.value
        ?.status,

    questionActive,
  ],

  () => {
    if (
      attackTargetMode.value &&
      (
        !isMyTurn.value ||
        questionActive.value ||
        battleFinished.value
      )
    ) {
      cancelTargetAttack(
        true,
      );
    }
  },
);

watch(
  selectedCardId,

  () => {
    if (
      attackTargetMode.value
    ) {
      selectedTargetCardId.value =
        null;
    }

    closeSpecialSkillModal(true);
    void loadSelectedCardSpecialSkills();
  },
);

watch(
  [
    () => battle.value?.round,
    () => battle.value?.special_card_skills_enabled,
  ],
  () => {
    if (selectedCard.value) {
      void loadSelectedCardSpecialSkills();
    }
  },
);

watch(
  [
    () => battle.value?.current_turn,
    () => battle.value?.status,
    questionActive,
  ],
  () => {
    if (
      !isMyTurn.value ||
      questionActive.value ||
      battleFinished.value
    ) {
      closeSpecialSkillModal(true);
      closeFusionModal(true);
      closeActionInfoModal();
    }
  },
);

watch(
  latestBattleEvent,
  (event) => {
    if (!event || !fusionFeatureEnabled.value) {
      return;
    }

    if (
      [
        "summon",
        "graveyard",
        "bench",
        "swap",
        "card_destroyed",
        "fusion",
      ].includes(event.type)
    ) {
      void loadPlayerFusions();
    }

    if (event.type === "fusion") {
      void loadFusionHistory();
      void loadGraveyardCards();

      // The acting player already gets the direct submitFusion toast.
      // Show a realtime notification mainly for the opponent.
      if (event.source_player !== player.value) {
        const resultName =
          event.payload?.result?.name ??
          "Fusion Result";

        const recipeName =
          event.payload?.recipe_name ??
          "Fusion";

        successToast(
          "🧬 OPPONENT FUSION",
          `${recipeName} → ${resultName}`,
        );
      }
    }
  },
);

watch(
  [
    () => battle.value?.fusion_enabled,
    () => battle.value?.id,
  ],
  () => {
    if (fusionFeatureEnabled.value) {
      void loadPlayerFusions();
    } else {
      runtimeFusions.value = [];
      selectedFusionRecipeId.value = null;
      closeFusionModal(true);
    }
  },
);

// =========================================================
// MOUNT
// =========================================================

onMounted(
  async () => {
    if (!code.value) {
      return;
    }

    await loadBattle(
      code.value,
    );

    if (
      battle.value
    ) {
      await Promise.all([
        loadBonusSkills(),

        loadGraveyardCards(),

        loadPlayerFusions(),

        loadFusionHistory(),
      ]);

      subscribeBonusSkills();

      subscribeGraveyard();

      try {
        await connectBattleUi({
          battleId:
            battle.value.id,

          role:
            "player",

          player:
            player.value,
        });
      } catch (
        uiSyncError
      ) {
        console.error(
          "Battle UI sync:",

          uiSyncError,
        );
      }
    }
  },
);

// =========================================================
// UNMOUNT
// =========================================================

onUnmounted(
  async () => {
    try {
      await disconnectBattleUi();
    } catch (
      uiSyncError
    ) {
      console.error(
        "Disconnect Battle UI sync:",

        uiSyncError,
      );
    }

    if (toastTimer) {
      clearTimeout(
        toastTimer,
      );
    }

    if (
      bonusChannel
    ) {
      await supabase
        .removeChannel(
          bonusChannel,
        );

      bonusChannel =
        null;
    }

    if (
      graveyardChannel
    ) {
      await supabase
        .removeChannel(
          graveyardChannel,
        );

      graveyardChannel =
        null;
    }
  },
);
</script>

<template>
  <main
    class="player-battle-ui"
    :class="player"
  >
    <!-- TOAST -->

    <Transition name="toast">
      <div
        v-if="toast.show"
        class="game-toast"
        :class="toast.type"
      >
        <div class="toast-glow" />

        <div class="toast-icon">
          <template
            v-if="
              toast.type ===
              'success'
            "
          >
            ✓
          </template>

          <template
            v-else-if="
              toast.type ===
              'warning'
            "
          >
            ⚠
          </template>

          <template v-else>
            ✕
          </template>
        </div>

        <div class="toast-copy">
          <strong>
            {{ toast.title }}
          </strong>

          <span
            v-if="toast.message"
          >
            {{ toast.message }}
          </span>
        </div>
      </div>
    </Transition>

    <!-- BACKGROUND -->

    <div class="arena-background">
      <div class="arena-grid" />

      <div
        class="
          background-glow
          glow-left
        "
      />

      <div
        class="
          background-glow
          glow-right
        "
      />

      <div class="center-pokeball">
        ◉
      </div>
    </div>

    <!-- LOADING -->

    <section
      v-if="loading"
      class="state-screen"
    >
      <div class="loading-ring" />

      <strong>
        CONNECTING TO BATTLE
      </strong>

      <span>
        Synchronizing battle session...
      </span>
    </section>

    <!-- ERROR -->

    <section
      v-else-if="error"
      class="
        state-screen
        state-error
      "
    >
      <strong>
        BATTLE UNAVAILABLE
      </strong>

      <span>
        {{ error }}
      </span>
    </section>

    <!-- TOKEN -->

    <section
      v-else-if="!token"
      class="
        state-screen
        state-error
      "
    >
      <strong>
        INVALID PLAYER LINK
      </strong>

      <span>
        Player token tidak ditemukan.
      </span>
    </section>

    <!-- MAIN BATTLE -->

    <template
      v-else-if="battle"
    >
      <!-- TOP HUD -->

      <header class="top-hud">
        <section class="player-identity">
          <div class="player-avatar">
            {{
              player === "p1"
                ? "👨🏻"
                : "👩🏻"
            }}
          </div>

          <div class="identity-copy">
            <span class="hud-label">
              {{
                player === "p1"
                  ? "PLAYER 1"
                  : "PLAYER 2"
              }}
            </span>

            <strong>
              {{ playerName }}
            </strong>

            <small>
              Battle {{ code }}
            </small>
          </div>
        </section>

        <!-- HP / SKILL -->

        <section class="combat-stats">
          <div class="hp-title">
            <span>HP</span>

            <strong>
              {{ ownHp }} /
              {{ ownMaxHp }}
            </strong>
          </div>

          <div class="hud-hp-track">
            <div
              class="hud-hp-fill"
              :style="{
                width:
                  `${ownHpPercent}%`,
              }"
            />
          </div>

          <div class="gauge-title">
            <span>ULTIMATE</span>

            <strong>
              {{ ownSkill }}%
            </strong>
          </div>

          <div class="hud-skill-track">
            <div
              class="hud-skill-fill"
              :style="{
                width:
                  `${Math.min(
                    100,
                    ownSkill,
                  )}%`,
              }"
            />
          </div>
        </section>

        <!-- DECK -->

        <section class="deck-mini-status">
          <span>
            PHYSICAL DECK
          </span>

          <strong>
            {{ ownDeckRemaining }}
            /
            {{ ownDeckTotal }}
          </strong>

          <small v-if="isTcgV1">
            TCG V1
          </small>

          <small v-else>
            CLASSIC
          </small>
        </section>

        <!-- TURN -->

        <section
          class="turn-core"
          :class="{
            active: isMyTurn,
            scanning:
              waitingForRfid,
            waiting:
              battleWaiting,
          }"
        >
          <span class="turn-arrow">
            ‹‹
          </span>

          <div>
            <strong>
              {{ turnText }}
            </strong>

            <span>
              ROUND

              {{ battle.round ?? 1 }}

              /

              {{
                battle.total_rounds ??
                "-"
              }}
            </span>
          </div>

          <span class="turn-arrow">
            ››
          </span>
        </section>

        <!-- ENEMY -->

        <section class="enemy-mini-status">
          <span>VS</span>

          <strong>
            {{ enemyName }}
          </strong>

          <small>
            HP {{ enemyHp }} /
            {{ enemyMaxHp }}
          </small>

          <div class="enemy-mini-track">
            <div
              class="enemy-mini-fill"
              :style="{
                width:
                  `${enemyHpPercent}%`,
              }"
            />
          </div>
        </section>
      </header>

      <!-- INITIAL RFID -->

      <Transition name="rfid-panel">
        <section
          v-if="battleWaiting"
          class="
            notification-panel
            initial-panel
          "
        >
          <div class="notification-icon">
            {{
              initialReady
                ? "✓"
                : "📡"
            }}
          </div>

          <div>
            <span>
              {{
                initialReady
                  ? "PLAYER READY"
                  : "INITIAL DECK SETUP"
              }}
            </span>

            <strong>
              {{
                initialReady
                  ? "WAITING FOR OPPONENT"
                  : "SCAN INITIAL CARD"
              }}
            </strong>

            <p>
              {{
                initialReady
                  ? "Initial deck kamu sudah siap."
                  : `Gunakan ${
                      player === "p1"
                        ? "RC522-P1"
                        : "RC522-P2"
                    }`
              }}
            </p>
          </div>

          <div class="notification-counter">
            {{ initialCardCount }}

            /

            {{ initialCardsRequired }}
          </div>
        </section>
      </Transition>

      <!-- SUMMON RFID -->

      <Transition name="rfid-panel">
        <section
          v-if="waitingForRfid"
          class="
            notification-panel
            summon-panel
          "
        >
          <div
            class="
              notification-icon
              pulse-icon
            "
          >
            📡
          </div>

          <div>
            <span>
              SUMMON MODE ACTIVE
            </span>

            <strong>
              SCAN RFID CARD NOW
            </strong>

            <p>
              Gunakan

              {{
                player === "p1"
                  ? "RC522-P1"
                  : "RC522-P2"
              }}
            </p>
          </div>

          <div class="scan-indicator">
            WAITING RFID
          </div>
        </section>
      </Transition>

      <!-- BUFFS -->

      <div
        v-if="
          ownDefending ||
          ownShield ||
          ownDebuff
        "
        class="buff-strip"
      >
        <span v-if="ownDefending">
          🛡 DEFENSE ACTIVE
        </span>

        <span v-if="ownShield">
          💧 SHIELD

          {{
            Math.round(
              ownShield * 100,
            )
          }}%
        </span>

        <span v-if="ownDebuff">
          ❄ ATK -

          {{
            Math.round(
              ownDebuff * 100,
            )
          }}%
        </span>
      </div>

      <!-- GAME FIELD -->

      <main
        class="
          battle-stage
          tcg-stage
        "
      >
        <!-- BENCH -->

        <BattleZoneStack
          class="
            side-zone
            bench-side-zone
          "
          zone="bench"
          side="left"
          :cards="benchCards"
          :max="maxBench"
          :accent="
            player === 'p1'
              ? 'blue'
              : 'red'
          "
          :allow-drop="
            isMyTurn &&
            !actionLoading &&
            !waitingForRfid &&
            !battleWaiting &&
            !questionActive &&
            !battleFinished
          "
          :draggable-cards="
            isMyTurn &&
            !actionLoading &&
            !waitingForRfid &&
            !battleWaiting &&
            !questionActive &&
            !battleFinished
          "
          @viewer-open="
            handleZoneViewerOpen
          "
          @viewer-close="
            handleZoneViewerClose
          "
          @viewer-index-change="
            handleZoneViewerIndex
          "
          @drag-start="
            (card) =>
              handleZoneDragStart(
                card,
                'bench',
              )
          "
          @drag-end="
            handleZoneDragEnd
          "
          @drag-hover="
            handleZoneDragHover
          "
          @drop-card="
            handleBenchDrop
          "
        />

        <!-- ACTIVE -->

        <section
          class="
            cyber-panel
            active-panel
            active-drop-zone
          "
          :class="{
            'drag-over-active':
              activeDropOver,
          }"
          @dragover="
            allowActiveDrop
          "
          @dragleave="
            clearActiveDrop
          "
          @drop="
            handleActiveDrop
          "
        >
          <header class="cyber-panel-header">
            <div class="panel-title">
              <span class="panel-icon">
                ◉
              </span>

              <strong>
                ACTIVE FIELD
              </strong>
            </div>

            <div class="active-header-meta">
              <span class="deck-remaining-chip">
                DECK
                {{ ownDeckRemaining }}
                /
                {{ ownDeckTotal }}
              </span>

              <span class="panel-count">
                {{ activeCards.length }}
                /
                {{ maxActive }}
              </span>
            </div>
          </header>

          <div
            v-if="activeDropOver"
            class="active-drop-hint"
          >
            ↓ DROP BENCH CARD TO RETURN ACTIVE
          </div>

          <div class="deck-slots">
            <article
              v-for="card in activeCards"
              :key="
                card.battleId ??
                card.id
              "
              class="
                cyber-card
                active-draggable-card
              "
              :class="{
                selected:
                  selectedCardId ===
                  (
                    card.battleId ??
                    card.id
                  ),

                exhausted:
                  card.exhausted,
              }"
              :draggable="
                isMyTurn &&
                !actionLoading &&
                !waitingForRfid &&
                !battleWaiting &&
                !questionActive &&
                !battleFinished &&
                !card.exhausted
              "
              @click="
                selectCard(card)
              "
              @dragstart="
                startActiveCardDrag(
                  $event,
                  card,
                )
              "
              @dragend="
                endActiveCardDrag
              "
            >
              <div class="drag-handle">
                ⋮⋮
              </div>

              <div class="cyber-card-inner">
                <header>
                  <strong>
                    {{ card.name }}
                  </strong>

                  <span>
                    {{
                      card.element ||
                      "neutral"
                    }}
                  </span>
                </header>

                <small>
                  CARD HP

                  {{
                    card.current_hp ??
                    card.currentHp ??
                    card.hp ??
                    0
                  }}

                  /

                  {{
                    card.base_hp ??
                    card.baseHp ??
                    card.hp ??
                    0
                  }}
                </small>

                <div class="cyber-card-image">
                  <img
                    v-if="
                      card.image_url
                    "
                    :src="
                      card.image_url
                    "
                    :alt="
                      card.name
                    "
                  />

                  <div
                    v-else
                    class="image-placeholder"
                  >
                    ◉
                  </div>
                </div>

                <footer class="card-combat-stats">
                  <div>
                    <span>
                      ATTACK
                    </span>

                    <strong>
                      {{
                        card.attack ??
                        0
                      }}
                    </strong>
                  </div>

                  <div>
                    <span>
                      DEFENSE
                    </span>

                    <strong>
                      {{
                        card.defense ??
                        0
                      }}
                    </strong>
                  </div>
                </footer>
              </div>

              <div class="drag-instruction">
                DRAG → BENCH
              </div>
            </article>

            <article
              v-for="
                slot in Math.max(
                  0,

                  maxActive -
                    activeCards.length,
                )
              "
              :key="
                `active-empty-${slot}`
              "
              class="
                cyber-card
                empty-card
              "
            >
              <div class="empty-ball">
                ◉
              </div>

              <span>
                Active

                {{
                  activeCards.length +
                  slot
                }}
              </span>
            </article>
          </div>
        </section>

        <!-- GRAVEYARD -->

        <BattleZoneStack
          class="
            side-zone
            graveyard-side-zone
          "
          zone="graveyard"
          side="right"
          :cards="
            graveyardCards
          "
          :accent="
            player === 'p1'
              ? 'blue'
              : 'red'
          "
          :readonly="true"
          :allow-drop="false"
          :draggable-cards="
            false
          "
          @viewer-open="
            handleZoneViewerOpen
          "
          @viewer-close="
            handleZoneViewerClose
          "
          @viewer-index-change="
            handleZoneViewerIndex
          "
        />
      </main>

      <!-- TARGETED ATTACK SELECTOR -->

      <Transition name="target-picker">
        <div
          v-if="
            attackTargetMode
          "
          class="target-picker-overlay"
        >
          <div
            class="target-picker-backdrop"
            @click="
              cancelTargetAttack()
            "
          />

          <section class="target-picker-panel">
            <header class="target-picker-header">
              <div>
                <span class="eyebrow">
                  PHASE 2 • TARGETED COMBAT
                </span>

                <h2>
                  SELECT ENEMY TARGET
                </h2>

                <p>
                  Attacker:

                  <strong>
                    {{
                      selectedCard
                        ?.name
                    }}
                  </strong>
                </p>
              </div>

              <button
                type="button"
                class="target-close-button"
                :disabled="
                  actionLoading
                "
                @click="
                  cancelTargetAttack()
                "
              >
                ✕
              </button>
            </header>

            <div class="target-picker-attacker">
              <div>
                <span>
                  ATTACKER
                </span>

                <strong>
                  {{
                    selectedCard
                      ?.name
                  }}
                </strong>
              </div>

              <div class="target-attacker-stats">
                <span>
                  ATK

                  <b>
                    {{
                      selectedCard
                        ?.attack ??
                      0
                    }}
                  </b>
                </span>

                <span>
                  CARD HP

                  <b>
                    {{
                      selectedCard
                        ?.current_hp ??
                      selectedCard
                        ?.currentHp ??
                      selectedCard
                        ?.hp ??
                      0
                    }}
                  </b>
                </span>
              </div>
            </div>

            <div class="target-picker-help">
              Pilih satu Active Card milik

              <strong>
                {{ enemyName }}
              </strong>

              sebagai target.
            </div>

            <div class="target-card-grid">
              <button
                v-for="
                  card in
                    enemyActiveCards
                "
                :key="
                  getCardId(card)
                "
                type="button"
                class="target-card"
                :class="{
                  selected:
                    selectedTargetCardId ===
                    getCardId(card),
                }"
                :disabled="
                  actionLoading
                "
                @click="
                  selectAttackTarget(
                    card,
                  )
                "
              >
                <div class="target-card-image">
                  <img
                    v-if="
                      card.image_url
                    "
                    :src="
                      card.image_url
                    "
                    :alt="
                      card.name
                    "
                  />

                  <div
                    v-else
                    class="
                      target-image-placeholder
                    "
                  >
                    ◉
                  </div>

                  <span
                    v-if="
                      selectedTargetCardId ===
                      getCardId(
                        card,
                      )
                    "
                    class="
                      target-lock-badge
                    "
                  >
                    TARGET LOCKED
                  </span>
                </div>

                <div class="target-card-body">
                  <strong>
                    {{ card.name }}
                  </strong>

                  <small>
                    {{
                      card.element ||
                      "neutral"
                    }}
                  </small>

                  <div class="target-card-hp">
                    <span>HP</span>

                    <b>
                      {{
                        card.current_hp ??
                        card.currentHp ??
                        card.hp ??
                        0
                      }}

                      /

                      {{
                        card.base_hp ??
                        card.baseHp ??
                        card.hp ??
                        0
                      }}
                    </b>
                  </div>

                  <div class="target-card-stats">
                    <span>
                      ATK

                      <b>
                        {{
                          card.attack ??
                          0
                        }}
                      </b>
                    </span>

                    <span>
                      DEF

                      <b>
                        {{
                          card.defense ??
                          0
                        }}
                      </b>
                    </span>
                  </div>
                </div>
              </button>
            </div>

            <div
              v-if="
                selectedTargetCard &&
                targetedAttackPreview
              "
              class="target-preview"
            >
              <div class="target-preview-title">
                DAMAGE PREVIEW
              </div>

              <div class="target-preview-flow">
                <span>
                  ATK

                  <b>
                    {{
                      targetedAttackPreview
                        .attack
                    }}
                  </b>
                </span>

                <span class="preview-operator">
                  −
                </span>

                <span>
                  DEF

                  <b>
                    {{
                      targetedAttackPreview
                        .defense
                    }}
                  </b>
                </span>

                <span class="preview-operator">
                  =
                </span>

                <span class="preview-damage">
                  BASE DAMAGE

                  <b>
                    {{
                      targetedAttackPreview
                        .baseDamage
                    }}
                  </b>
                </span>
              </div>

              <div class="target-preview-result">
                <span>
                  {{
                    selectedTargetCard
                      .name
                  }}
                </span>

                <strong>
                  {{
                    targetedAttackPreview
                      .targetHp
                  }}

                  →

                  {{
                    targetedAttackPreview
                      .hpAfter
                  }}

                  HP
                </strong>

                <em
                  v-if="
                    targetedAttackPreview
                      .wouldDestroy
                  "
                >
                  ☠ WOULD BE DESTROYED
                </em>
              </div>

              <small>
                Preview memakai formula dasar ATK − DEF.
                Power Strike, Defense, Shield, debuff,
                synergy, atau modifier server dapat
                mengubah final damage.
              </small>
            </div>

            <footer class="target-picker-actions">
              <button
                type="button"
                class="
                  target-cancel-button
                "
                :disabled="
                  actionLoading
                "
                @click="
                  cancelTargetAttack()
                "
              >
                CANCEL
              </button>

              <button
                type="button"
                class="
                  target-confirm-button
                "
                :disabled="
                  !selectedTargetCard ||
                  actionLoading
                "
                @click="
                  submitTargetedAttack
                "
              >
                {{
                  actionLoading
                    ? "ATTACKING..."
                    : "CONFIRM ATTACK"
                }}
              </button>
            </footer>
          </section>
        </div>
      </Transition>

      <!-- BONUS SKILLS -->

      <section
        v-if="
          bonusSkills.length
        "
        class="
          bonus-panel
          glass-panel
        "
      >
        <div class="panel-heading">
          <div>
            <span class="eyebrow">
              QUESTION REWARD
            </span>

            <h2>
              Bonus Skills
            </h2>
          </div>
        </div>

        <div class="bonus-list">
          <button
            v-for="
              bonus in
                bonusSkills
            "
            :key="
              bonus.id
            "
            type="button"
            class="
              bonus-item
              bonus-button
            "
            :class="{
              used:
                bonus.used,

              ready:
                !bonus.used,
            }"
            :disabled="
              bonus.used ||
              bonusUsingId ===
                bonus.id
            "
            @click="
              useBonusSkill(
                bonus,
              )
            "
          >
            <span class="bonus-item-icon">
              {{
                bonusIcon(
                  bonus.skill_type,
                )
              }}
            </span>

            <div>
              <strong>
                {{
                  bonusLabel(
                    bonus.skill_type,
                  )
                }}
              </strong>

              <small>
                {{
                  bonusUsingId ===
                  bonus.id
                    ? "ACTIVATING..."
                    : bonus.used
                      ? "USED"
                      : "READY - CLICK TO USE"
                }}
              </small>

              <em class="bonus-description">
                {{
                  bonusDescription(
                    bonus.skill_type,
                  )
                }}
              </em>
            </div>
          </button>
        </div>
      </section>

      <!-- SKILL READY BALLOONS -->

      <Transition name="target-picker">
        <div
          v-if="
            battle.status === 'battle' &&
            (canUltimateUi || canSynergyUi || canSpecialUi || canFusionUi)
          "
          class="skill-ready-balloons"
          :class="{ expanded: actionInfoExpanded }"
        >
          <button
            v-if="canUltimateUi"
            type="button"
            class="ready-balloon ultimate"
            @click="openActionInfoByKey('ultimate')"
          >
            <span>⚡</span>
            <div>
              <strong>ULTIMATE READY</strong>
              <small>Klik untuk detail</small>
            </div>
          </button>

          <button
            v-if="canSynergyUi"
            type="button"
            class="ready-balloon synergy"
            @click="openActionInfoByKey('synergy')"
          >
            <span>{{ selectedSynergyInfo.icon }}</span>
            <div>
              <strong>{{ selectedSynergyInfo.name }}</strong>
              <small>Synergy siap • klik detail</small>
            </div>
          </button>

          <button
            v-if="canSpecialUi"
            type="button"
            class="ready-balloon special"
            @click="openSpecialSkillModal()"
          >
            <span>{{ readySpecialSkills[0]?.icon || '✨' }}</span>
            <div>
              <strong>{{ readySpecialSkills[0]?.name || 'SPECIAL READY' }}</strong>
              <small>Special Skill siap • klik detail</small>
            </div>
          </button>


          <button
            v-if="canFusionUi"
            type="button"
            class="ready-balloon fusion"
            @click="openFusionModal(readyFusions[0])"
          >
            <span>{{ readyFusions[0]?.icon || "🧬" }}</span>
            <div>
              <strong>{{ readyFusions[0]?.recipe_name || "FUSION READY" }}</strong>
              <small>Fusion siap • klik detail</small>
            </div>
          </button>
        </div>
      </Transition>

      <!-- ACTION INFORMATION -->

      <section
        v-if="battle.status === 'battle'"
        class="skill-info-panel glass-panel"
        :class="{ 'is-collapsed': !actionInfoExpanded }"
      >
        <!-- COLLAPSED: hanya handle kecil di tengah -->
        <button
          v-if="!actionInfoExpanded"
          type="button"
          class="action-info-collapsed-toggle"
          aria-label="Expand action information"
          title="Buka Action Information"
          @click="actionInfoExpanded = true"
        >
          <span class="action-info-handle-line"></span>
          <span class="action-info-handle-arrow">⌃</span>
        </button>

        <!-- EXPANDED: tampilkan header + tombol-tombol info -->
        <template v-else>
          <header class="skill-info-header">
            <div>
              <span class="eyebrow">ACTION INFORMATION</span>

              <strong>
                {{ selectedCard ? selectedCard.name : "Select an Active Card" }}
              </strong>
            </div>

            <div class="action-info-header-actions">
              <div class="player-status-summary">
                <span v-if="ownPowerStrikeReady" class="status-pill power">
                  ⚡ POWER STRIKE +50%
                </span>

                <span v-if="ownDefending" class="status-pill defense">
                  🛡 DEFENSE -50%
                </span>

                <span v-if="ownShield > 0" class="status-pill water">
                  💧 SHIELD -{{ formatPercent(ownShield) }}%
                </span>

                <span v-if="ownDebuff > 0" class="status-pill debuff">
                  ❄ ATK -{{ formatPercent(ownDebuff) }}%
                </span>
              </div>

              <button
                type="button"
                class="action-info-toggle"
                @click="actionInfoExpanded = false"
              >
                <span>COLLAPSE</span>
                <b>⌄</b>
              </button>
            </div>
          </header>

          <Transition name="action-info-expand">
            <div class="action-info-button-grid">
              <button
                v-for="info in actionInfoItems"
                :key="info.key"
                type="button"
                class="action-info-button"
                :class="[
                  info.key,
                  {
                    ready: info.ready,
                    locked: !info.ready,
                    used: info.status === 'USED',
                    active: info.status === 'ACTIVE',
                  },
                ]"
                @click="openActionInfo(info)"
              >
                <span class="action-info-button-icon">{{ info.icon }}</span>

                <span class="action-info-button-copy">
                  <strong>{{ info.title }}</strong>
                  <small>{{ info.status }}</small>
                </span>

                <span class="action-info-button-open">INFO ↗</span>
              </button>
            </div>
          </Transition>
        </template>
      </section>

      <!-- ACTION INFO MODAL -->

      <Transition name="target-picker">
        <div
          v-if="actionInfoModalOpen && activeActionInfo"
          class="action-detail-overlay"
        >
          <div class="action-detail-backdrop" @click="closeActionInfoModal" />

          <section class="action-detail-modal" @click.stop>
            <header>
              <div class="action-detail-title">
                <span>{{ activeActionInfo.icon }}</span>
                <div>
                  <small>ACTION GUIDE</small>
                  <h2>{{ activeActionInfo.title }}</h2>
                </div>
              </div>

              <button type="button" class="modal-close" @click="closeActionInfoModal">
                ✕
              </button>
            </header>

            <div
              class="action-detail-status"
              :class="{ ready: activeActionInfo.ready }"
            >
              {{ activeActionInfo.status }}
            </div>

            <div class="action-detail-block">
              <span>EFFECT</span>
              <p>{{ activeActionInfo.effect }}</p>
            </div>

            <div class="action-detail-block">
              <span>MECHANIC</span>
              <p>{{ activeActionInfo.detail }}</p>
            </div>

            <button type="button" class="modal-primary secondary" @click="closeActionInfoModal">
              TUTUP
            </button>
          </section>
        </div>
      </Transition>

      <!-- SPECIAL SKILL MODAL -->

      <Transition name="target-picker">
        <div v-if="specialSkillModalOpen" class="action-detail-overlay special-overlay">
          <div class="action-detail-backdrop" @click="closeSpecialSkillModal" />

          <section class="special-skill-modal" @click.stop>
            <header class="special-modal-header">
              <div>
                <span class="eyebrow">PHASE 3C • CARD SPECIAL SKILL</span>
                <h2>{{ selectedCard?.name || "Selected Card" }}</h2>
                <p>Pilih skill, baca mekaniknya, tentukan target jika diperlukan, lalu aktifkan.</p>
              </div>

              <button type="button" class="modal-close" @click="closeSpecialSkillModal">
                ✕
              </button>
            </header>

            <div v-if="specialSkillLoading" class="special-empty-state">
              Loading Special Skill...
            </div>

            <div v-else-if="!runtimeSpecialSkills.length" class="special-empty-state">
              Card ini tidak memiliki Special Skill.
            </div>

            <template v-else>
              <div class="special-skill-tabs">
                <button
                  v-for="skill in runtimeSpecialSkills"
                  :key="skill.id"
                  type="button"
                  class="special-skill-tab"
                  :class="{
                    selected: selectedSpecialSkill?.id === skill.id,
                    ready: specialSkillReadyState(skill).ready,
                  }"
                  @click="chooseSpecialSkill(skill)"
                >
                  <span>{{ skill.icon || "✨" }}</span>
                  <div>
                    <strong>{{ skill.name }}</strong>
                    <small>{{ specialSkillReadyState(skill).status }}</small>
                  </div>
                </button>
              </div>

              <div v-if="selectedSpecialSkill" class="special-detail-layout">
                <div class="special-detail-main">
                  <div class="special-skill-hero">
                    <div class="special-skill-hero-icon">
                      {{ selectedSpecialSkill.icon || "✨" }}
                    </div>

                    <div>
                      <span>SPECIAL SKILL</span>
                      <h3>{{ selectedSpecialSkill.name }}</h3>
                      <p>
                        {{
                          selectedSpecialSkill.description ||
                          "Tidak ada deskripsi tambahan untuk skill ini."
                        }}
                      </p>
                    </div>
                  </div>

                  <div class="special-metric-grid">
                    <div>
                      <span>TARGET</span>
                      <strong>{{ formatSpecialTarget(selectedSpecialSkill) }}</strong>
                    </div>
                    <div>
                      <span>COST</span>
                      <strong>{{ formatSpecialCost(selectedSpecialSkill) }}</strong>
                    </div>
                    <div>
                      <span>LIMIT</span>
                      <strong>{{ formatSpecialLimits(selectedSpecialSkill) }}</strong>
                    </div>
                    <div>
                      <span>TURN</span>
                      <strong>
                        {{ selectedSpecialSkill.consumes_turn ? "Consumes Turn" : "Free Action" }}
                      </strong>
                    </div>
                  </div>

                  <div class="special-effects-panel">
                    <span>EFFECTS</span>
                    <ul>
                      <li
                        v-for="(effectText, effectIndex) in describeSpecialEffects(selectedSpecialSkill)"
                        :key="effectIndex"
                      >
                        {{ effectText }}
                      </li>
                    </ul>
                  </div>

                  <div
                    class="special-readiness"
                    :class="{ ready: specialSkillReadyState(selectedSpecialSkill).ready }"
                  >
                    <strong>{{ specialSkillReadyState(selectedSpecialSkill).status }}</strong>
                    <span>{{ specialSkillReadyState(selectedSpecialSkill).reason }}</span>
                  </div>
                </div>

                <aside class="special-target-panel">
                  <span>TARGET SELECTION</span>

                  <template v-if="selectedSpecialTargetRequired">
                    <p>Pilih target sebelum menggunakan skill.</p>

                    <div v-if="specialTargetCards.length" class="special-target-grid">
                      <button
                        v-for="card in specialTargetCards"
                        :key="getCardId(card)"
                        type="button"
                        class="special-target-card"
                        :class="{ selected: selectedSpecialTargetId === getCardId(card) }"
                        @click="chooseSpecialTarget(card)"
                      >
                        <img v-if="card.image_url" :src="card.image_url" :alt="card.name" />
                        <span v-else class="special-target-placeholder">◉</span>
                        <strong>{{ card.name }}</strong>
                        <small>
                          HP
                          {{ card.current_hp ?? card.currentHp ?? card.hp ?? 0 }}
                        </small>
                      </button>
                    </div>

                    <div v-else class="special-empty-target">
                      Target yang sesuai tidak tersedia.
                    </div>
                  </template>

                  <template v-else>
                    <p>
                      Target dipilih otomatis:
                      <strong>{{ formatSpecialTarget(selectedSpecialSkill) }}</strong>
                    </p>
                  </template>
                </aside>
              </div>

              <footer class="special-modal-actions">
                <button type="button" class="modal-primary secondary" @click="closeSpecialSkillModal">
                  BATAL
                </button>

                <button
                  type="button"
                  class="modal-primary special-use-button"
                  :disabled="
                    actionLoading ||
                    !selectedSpecialSkill ||
                    !specialSkillReadyState(selectedSpecialSkill).ready ||
                    (selectedSpecialTargetRequired && !selectedSpecialTarget)
                  "
                  @click="submitSpecialSkill"
                >
                  {{ actionLoading ? "ACTIVATING..." : "USE SPECIAL SKILL" }}
                </button>
              </footer>
            </template>
          </section>
        </div>
      </Transition>

      <!-- FUSION LAB MODAL -->

      <Transition name="target-picker">
        <div
          v-if="fusionModalOpen"
          class="action-detail-overlay fusion-overlay"
        >
          <div class="action-detail-backdrop" @click="closeFusionModal" />

          <section class="fusion-modal" @click.stop>
            <header class="fusion-modal-header">
              <div>
                <span class="eyebrow">PHASE 3D • FUSION LAB</span>
                <h2>Fusion Engine</h2>
                <p>
                  Pilih recipe. Material yang tampil hanya preview; server tetap menentukan
                  kombinasi final saat tombol FUSE ditekan.
                </p>
              </div>

              <button type="button" class="modal-close" @click="closeFusionModal">
                ✕
              </button>
            </header>

            <div v-if="fusionLoading" class="fusion-empty-state">
              Memeriksa Fusion Recipe...
            </div>

            <div v-else-if="fusionLoadError" class="fusion-empty-state fusion-empty-error">
              <strong>Fusion Recipe gagal dimuat</strong>
              <span>{{ fusionLoadError }}</span>
              <button type="button" class="fusion-retry-btn" @click="loadPlayerFusions">
                COBA LAGI
              </button>
            </div>

            <div v-else-if="!readyFusions.length" class="fusion-empty-state">
              <strong>Belum ada Fusion yang siap.</strong>
              <span>Fusion hanya akan muncul ketika seluruh material requirement sudah terpenuhi.</span>
              <button type="button" class="fusion-retry-btn" @click="loadPlayerFusions">
                CEK MATERIAL LAGI
              </button>
            </div>

            <template v-else>
              <div class="fusion-tabs">
                <button
                  v-for="recipe in readyFusions"
                  :key="recipe.recipe_id"
                  type="button"
                  class="fusion-tab"
                  :class="{
                    selected: selectedFusion?.recipe_id === recipe.recipe_id,
                    ready: recipe.available,
                    used: recipe.limit_reached,
                  }"
                  @click="chooseFusion(recipe)"
                >
                  <span>{{ recipe.icon || "🧬" }}</span>
                  <div>
                    <strong>{{ recipe.recipe_name }}</strong>
                    <small>{{ recipe.available ? "READY" : recipe.status || "MATERIALS" }}</small>
                  </div>
                </button>
              </div>

              <div v-if="selectedFusion" class="fusion-detail-layout">
                <div class="fusion-detail-main">
                  <div class="fusion-result-hero">
                    <img
                      v-if="selectedFusion.result_image"
                      :src="selectedFusion.result_image"
                      :alt="selectedFusion.result_name"
                    />
                    <div v-else class="fusion-result-placeholder">
                      {{ selectedFusion.icon || "🧬" }}
                    </div>

                    <div>
                      <span>FUSION RESULT</span>
                      <h3>{{ selectedFusion.result_name }}</h3>
                      <p>
                        {{
                          selectedFusion.description ||
                          "Fusion Card akan dipanggil ke Active Zone."
                        }}
                      </p>
                    </div>
                  </div>

                  <div class="fusion-stat-grid">
                    <div>
                      <span>HP</span>
                      <strong>
                        {{ selectedFusion.calculated_stats ? fusionStat(selectedFusion, "hp") : "—" }}
                      </strong>
                    </div>
                    <div>
                      <span>ATK</span>
                      <strong>
                        {{ selectedFusion.calculated_stats ? fusionStat(selectedFusion, "attack") : "—" }}
                      </strong>
                    </div>
                    <div>
                      <span>DEF</span>
                      <strong>
                        {{ selectedFusion.calculated_stats ? fusionStat(selectedFusion, "defense") : "—" }}
                      </strong>
                    </div>
                    <div>
                      <span>TURN</span>
                      <strong>
                        {{ selectedFusion.consumes_turn === false ? "FREE" : "CONSUMES" }}
                      </strong>
                    </div>
                  </div>

                  <div class="fusion-requirements-panel">
                    <div class="fusion-section-heading">
                      <span>MATERIAL REQUIREMENTS</span>
                      <strong>
                        {{ selectedFusion.required_material_count || 0 }} MATERIAL
                      </strong>
                    </div>

                    <div class="fusion-requirement-list">
                      <div
                        v-for="requirement in selectedFusion.requirements || []"
                        :key="requirement.requirement_id"
                        class="fusion-requirement-row"
                        :class="{ ready: fusionRequirementProgress(requirement).ready }"
                      >
                        <span class="fusion-check">
                          {{ fusionRequirementProgress(requirement).ready ? "✓" : "×" }}
                        </span>

                        <div>
                          <strong>
                            {{ fusionRequirementLabel(requirement) }} ×{{ requirement.quantity || 1 }}
                          </strong>
                          <small>{{ fusionZoneText(requirement) }}</small>
                        </div>

                        <b>
                          {{ fusionRequirementProgress(requirement).have }}/{{ fusionRequirementProgress(requirement).need }}
                        </b>
                      </div>
                    </div>
                  </div>

                  <div class="fusion-server-match">
                    <div class="fusion-section-heading">
                      <span>SERVER MATCH</span>
                      <strong>
                        {{ selectedFusion.materials?.length || 0 }} SELECTED
                      </strong>
                    </div>

                    <div v-if="selectedFusion.materials?.length" class="fusion-material-grid">
                      <article
                        v-for="material in selectedFusion.materials"
                        :key="material.battle_card_id"
                        class="fusion-material-card"
                      >
                        <span>{{ String(material.zone || "").toUpperCase() }}</span>
                        <strong>{{ material.name }}</strong>
                        <small>{{ material.card_code }}</small>
                        <em>
                          HP {{ material.base_hp }} • ATK {{ material.attack }} • DEF {{ material.defense }}
                        </em>
                      </article>
                    </div>

                    <div v-else class="fusion-no-match">
                      Material lengkap belum ditemukan oleh server matcher.
                    </div>
                  </div>
                </div>

                <aside class="fusion-status-panel">
                  <span>FUSION STATUS</span>

                  <div
                    class="fusion-readiness"
                    :class="{ ready: selectedFusion.available }"
                  >
                    <strong>
                      {{ selectedFusion.available ? "READY" : selectedFusion.status || "LOCKED" }}
                    </strong>
                    <p>{{ selectedFusion.message }}</p>
                  </div>

                  <div class="fusion-rule-summary">
                    <div>
                      <span>RESULT ZONE</span>
                      <strong>{{ String(selectedFusion.result_zone || "active").toUpperCase() }}</strong>
                    </div>
                    <div>
                      <span>MATERIAL →</span>
                      <strong>{{ String(selectedFusion.material_destination || "graveyard").toUpperCase() }}</strong>
                    </div>
                    <div>
                      <span>USES</span>
                      <strong>
                        {{ selectedFusion.usage_count || 0 }}/{{ selectedFusion.max_uses || "∞" }}
                      </strong>
                    </div>
                  </div>
                </aside>
              </div>

              <footer class="fusion-modal-actions">
                <button
                  type="button"
                  class="modal-primary secondary"
                  @click="closeFusionModal"
                >
                  BATAL
                </button>

                <button
                  type="button"
                  class="modal-primary fusion-use-button"
                  :disabled="
                    actionLoading ||
                    !selectedFusion ||
                    !selectedFusion.available
                  "
                  @click="submitFusion"
                >
                  {{
                    actionLoading
                      ? "FUSING..."
                      : selectedFusion?.available
                        ? `FUSE → ${selectedFusion.result_name}`
                        : "FUSION NOT READY"
                  }}
                </button>
              </footer>
            </template>
          </section>
        </div>
      </Transition>

      <!-- =====================================================
           PHASE 3D.13 - FUSION HISTORY
      ====================================================== -->

      <button
        v-if="
          battle?.status === 'battle' &&
          fusionFeatureEnabled
        "
        type="button"
        class="fusion-history-fab"
        @click="openFusionHistory"
      >
        <span>🧬</span>
        <strong>FUSION LOG</strong>
        <b>{{ fusionHistory.length }}</b>
      </button>

      <Transition name="target-picker">
        <div
          v-if="fusionHistoryOpen"
          class="fusion-history-overlay"
        >
          <div
            class="fusion-history-backdrop"
            @click="closeFusionHistory"
          />

          <section
            class="fusion-history-modal"
            @click.stop
          >
            <header class="fusion-history-header">
              <div>
                <span>PHASE 3D.13 • BATTLE HISTORY</span>
                <h2>Fusion Timeline</h2>
                <p>
                  Semua Fusion dicatat oleh server, termasuk material,
                  recipe, result, Necro, dan Fusion Chain.
                </p>
              </div>

              <button
                type="button"
                @click="closeFusionHistory"
              >
                ✕
              </button>
            </header>

            <div
              v-if="fusionHistoryLoading"
              class="fusion-history-state"
            >
              Loading Fusion history...
            </div>

            <div
              v-else-if="fusionHistoryError"
              class="fusion-history-state error"
            >
              <strong>History gagal dimuat</strong>
              <span>{{ fusionHistoryError }}</span>

              <button
                type="button"
                @click="loadFusionHistory"
              >
                COBA LAGI
              </button>
            </div>

            <div
              v-else-if="!fusionHistory.length"
              class="fusion-history-state"
            >
              Belum ada Fusion dalam battle ini.
            </div>

            <div
              v-else
              class="fusion-history-list"
            >
              <article
                v-for="event in fusionHistory"
                :key="event.id"
                class="fusion-history-item"
              >
                <div class="fusion-history-marker">
                  {{
                    event.payload?.recipe_icon ||
                    "🧬"
                  }}
                </div>

                <div class="fusion-history-body">
                  <div class="fusion-history-meta">
                    <span
                      :class="
                        event.source_player === 'p1'
                          ? 'p1'
                          : 'p2'
                      "
                    >
                      {{
                        String(
                          event.source_player ||
                          "player",
                        ).toUpperCase()
                      }}
                    </span>

                    <b>
                      {{ fusionHistoryKindLabel(event) }}
                    </b>

                    <time>
                      {{ fusionHistoryTime(event) }}
                    </time>
                  </div>

                  <h3>
                    {{
                      event.payload?.recipe_name ||
                      "Fusion"
                    }}
                  </h3>

                  <div class="fusion-history-combo">
                    <div class="fusion-history-materials">
                      <span
                        v-for="material in fusionHistoryMaterials(event)"
                        :key="
                          material.battle_card_id ||
                          `${material.card_code}-${material.zone}`
                        "
                        class="fusion-history-material"
                      >
                        <small>
                          {{
                            String(
                              material.zone ||
                              "material",
                            ).toUpperCase()
                          }}
                        </small>

                        <strong>
                          {{
                            material.name ||
                            material.card_code ||
                            "Material"
                          }}
                        </strong>
                      </span>
                    </div>

                    <span class="fusion-history-arrow">
                      →
                    </span>

                    <div class="fusion-history-result">
                      <img
                        v-if="
                          fusionHistoryResult(event)
                            .image_url
                        "
                        :src="
                          fusionHistoryResult(event)
                            .image_url
                        "
                        :alt="
                          fusionHistoryResult(event)
                            .name
                        "
                      />

                      <div>
                        <small>FUSION RESULT</small>

                        <strong>
                          {{
                            fusionHistoryResult(event)
                              .name ||
                            "Fusion Result"
                          }}
                        </strong>

                        <span>
                          HP {{
                            fusionHistoryResult(event)
                              .base_hp ??
                            event.payload
                              ?.calculated_stats
                              ?.hp ??
                            "-"
                          }}
                          • ATK {{
                            fusionHistoryResult(event)
                              .attack ??
                            event.payload
                              ?.calculated_stats
                              ?.attack ??
                            "-"
                          }}
                          • DEF {{
                            fusionHistoryResult(event)
                              .defense ??
                            event.payload
                              ?.calculated_stats
                              ?.defense ??
                            "-"
                          }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </article>
            </div>
          </section>
        </div>
      </Transition>

      <!-- CONTROL CONSOLE -->

      <footer
        v-if="
          battle.status ===
          'battle'
        "
        class="control-console"
      >
        <div
          class="
            console-decoration
            left
          "
        >
          //
        </div>

        <!-- ATTACK -->

        <button
          type="button"
          class="
            console-skill
            attack-skill
          "
          :class="{
            dimmed:
              waitingForRfid ||
              questionActive ||
              battleFinished,

            targeting:
              attackTargetMode,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished
          "
          @click="
            beginAttackAction
          "
        >
          <span class="console-icon">
            ⚔
          </span>

          <strong>
            {{
              attackTargetMode
                ? "SELECT TARGET"
                : directAttackAvailable
                  ? "DIRECT ATTACK"
                  : "ATTACK"
            }}
          </strong>

          <small>
            {{
              isTcgV1
                ? directAttackAvailable
                  ? "50% ATK → HP"
                  : "TARGETED"
                : "BASIC"
            }}
          </small>
        </button>

        <!-- DEFENSE -->

        <button
          type="button"
          class="
            console-skill
            defense-skill
          "
          :class="{
            dimmed:
              waitingForRfid ||
              questionActive ||
              battleFinished,

            unavailable:
              !canDefenseUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canDefenseUi
          "
          @click="
            submitAction(
              'defense',
            )
          "
        >
          <span class="console-icon">
            🛡
          </span>

          <strong>
            DEFENSE
          </strong>

          <small>
            {{
              ownDefending
                ? "ACTIVE • -50%"
                : canDefenseUi
                  ? "-50% NEXT HIT • +10 GAUGE"
                  : skillLockText(
                      "defense",
                    )
            }}
          </small>
        </button>

        <!-- SUMMON -->

        <button
          type="button"
          class="summon-core"
          :class="{
            active:
              waitingForRfid,

            unavailable:
              !canSummonUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canSummonUi
          "
          @click="
            submitAction(
              'summon',
            )
          "
        >
          <div class="summon-core-inner">
            <span>
              {{
                waitingForRfid
                  ? "📡"
                  : "◉"
              }}
            </span>

            <strong>
              {{
                waitingForRfid
                  ? "SCAN RFID"
                  : "SUMMON"
              }}
            </strong>

            <small
              v-if="
                !canSummonUi
              "
            >
              {{
                skillLockText(
                  "summon",
                )
              }}
            </small>

            <small v-else>
              +
            </small>
          </div>
        </button>

        <!-- ULTIMATE -->

        <button
          type="button"
          class="
            console-skill
            ultimate-skill
          "
          :class="{
            unavailable:
              !canUltimateUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canUltimateUi
          "
          @click="
            submitAction(
              'ultimate',
            )
          "
        >
          <span class="console-icon">
            ⚡
          </span>

          <strong>
            ULTIMATE
          </strong>

          <small>
            {{
              ownUltimateUsed
                ? "USED"
                : canUltimateUi
                  ? "ATK ×2 • READY"
                  : skillLockText(
                      "ultimate",
                    )
            }}
          </small>
        </button>

        <!-- HEAL -->

        <button
          type="button"
          class="
            console-skill
            heal-skill
          "
          :class="{
            unavailable:
              !canHealUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canHealUi
          "
          @click="
            submitAction(
              'heal',
            )
          "
        >
          <span class="console-icon">
            ✦
          </span>

          <strong>
            HEAL
          </strong>

          <small>
            {{
              ownHealUsed
                ? "USED"
                : canHealUi
                  ? "35% MAX HP • READY"
                  : skillLockText(
                      "heal",
                    )
            }}
          </small>
        </button>

        <!-- SYNERGY -->

        <button
          type="button"
          class="
            console-skill
            synergy-skill
          "
          :class="{
            unavailable:
              !canSynergyUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canSynergyUi
          "
          @click="
            submitAction(
              'synergy',
            )
          "
        >
          <span class="console-icon">
            ✧
          </span>

          <strong>
            SYNERGY
          </strong>

          <small>
            {{
              canSynergyUi
                ? `${
                    selectedSynergyInfo
                      .element
                      .toUpperCase()
                  } • ${
                    selectedElementCount
                  } CARDS`
                : skillLockText(
                    "synergy",
                  )
            }}
          </small>
        </button>

        <!-- SPECIAL SKILL -->

        <button
          type="button"
          class="console-skill special-skill"
          :class="{
            unavailable: !canSpecialUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !selectedCard ||
            !runtimeSpecialSkills.length
          "
          @click="openSpecialSkillModal()"
        >
          <span class="console-icon">
            {{ readySpecialSkills[0]?.icon || runtimeSpecialSkills[0]?.icon || "✨" }}
          </span>

          <strong>SPECIAL</strong>

          <small>
            {{
              canSpecialUi
                ? `${readySpecialSkills[0]?.name || "READY"} • READY`
                : skillLockText("special")
            }}
          </small>
        </button>

        <!-- FUSION -->

        <button
          type="button"
          class="console-skill fusion-skill"
          :class="{
            unavailable: !canFusionUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !fusionFeatureEnabled
          "
          @click="openFusionModal()"
        >
          <span class="console-icon">
            {{ readyFusions[0]?.icon || "🧬" }}
          </span>

          <strong>FUSION</strong>

          <small>
            {{
              fusionLoading
                ? "CHECKING..."
                : canFusionUi
                  ? `${readyFusions.length} READY`
                  : fusionLoadError
                    ? "LOAD ERROR"
                    : fusionFeatureEnabled
                      ? "NO MATCH"
                      : "DISABLED"
            }}
          </small>
        </button>

        <div
          class="
            console-decoration
            right
          "
        >
          //
        </div>
      </footer>

      <!-- SELECTED CARD -->

      <div
        v-if="
          selectedCard
        "
        class="
          selected-card-chip
        "
      >
        SELECTED

        <strong>
          {{
            selectedCard.name
          }}
        </strong>
      </div>

      <!-- QUESTION -->

      <Transition name="question">
        <div
          v-if="
            battle &&
            questionActive
          "
          class="
            question-overlay
          "
        >
          <div
            class="
              question-backdrop
            "
          />

          <section
            class="
              question-card
            "
            @click.stop
            @pointerdown.stop
          >
            <span class="hud-label">
              CODING CHALLENGE
            </span>

            <h2>
              Answer Faster Than

              {{ enemyName }}
            </h2>

            <div
              v-if="
                questionLoading
              "
              class="
                question-state
              "
            >
              Loading question...
            </div>

            <div
              v-else-if="
                questionError
              "
              class="
                question-state
              "
            >
              {{
                questionError
              }}
            </div>

            <template
              v-else-if="
                currentQuestion
              "
            >
              <div
                class="
                  question-text
                "
              >
                {{
                  currentQuestion
                    .question
                }}
              </div>

              <pre
                v-if="
                  currentQuestion
                    .code
                "
                class="
                  question-code
                "
              ><code>{{ currentQuestion.code }}</code></pre>

              <div
                v-if="
                  !effectiveQuestionRoundId
                "
                class="
                  question-sync-state
                "
              >
                <span>
                  ↻
                </span>

                <div>
                  <strong>
                    SYNCING QUESTION ROUND
                  </strong>

                  <small>
                    Tunggu sebentar. Tombol jawaban akan aktif otomatis.
                  </small>
                </div>
              </div>

              <div
                class="
                  question-options
                "
              >
                <button
                  v-for="(
                    option,
                    index
                  ) in
                    currentQuestion
                      .options"
                  :key="index"
                  type="button"
                  class="
                    question-option
                  "
                  :class="{
                    selected:
                      selectedQuestionAnswer ===
                      index,

                    correct:
                      selectedQuestionAnswer ===
                        index &&
                      questionResult ===
                        'correct',

                    wrong:
                      selectedQuestionAnswer ===
                        index &&
                      questionResult ===
                        'wrong',
                  }"
                  :disabled="
                    questionInteractionLocked
                  "
                  @click="
                    answerQuestion(
                      index,
                    )
                  "
                >
                  <span>
                    {{
                      String.fromCharCode(
                        65 + index,
                      )
                    }}
                  </span>

                  {{ option }}
                </button>
              </div>
            </template>
          </section>
        </div>
      </Transition>

      <!-- WINNER -->

      <Transition name="question">
        <div
          v-if="
            battleFinished
          "
          class="
            winner-overlay
          "
        >
          <section
            class="
              winner-card
            "
          >
            <span>
              BATTLE FINISHED
            </span>

            <h1>
              {{
                didWin
                  ? "YOU WIN!"
                  : battle.winner ===
                      "draw"
                    ? "DRAW"
                    : "BATTLE OVER"
              }}
            </h1>

            <strong>
              {{
                battle.winner ===
                "draw"
                  ? "NO WINNER"
                  : battle.winner ===
                      "p1"
                    ? (
                        battle.player1_name ??
                        "Player 1"
                      )
                    : (
                        battle.player2_name ??
                        "Player 2"
                      )
              }}
            </strong>
          </section>
        </div>
      </Transition>
    </template>
  </main>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

button {
  font: inherit;
}

.player-battle-ui {
  --player-accent: #249fe8;
  --player-accent-soft: #74caff;

  width: 100%;
  min-height: 100vh;

  position: relative;

  overflow-x: hidden;

  padding: 20px 24px 315px;

  color: #17324a;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    "Segoe UI",
    sans-serif;

  background:
    linear-gradient(
      180deg,
      #dff3ff 0%,
      #edf9ff 22%,
      #e8f7ec 55%,
      #d6efd9 100%
    );
}

.player-battle-ui.p2 {
  --player-accent: #ed567c;
  --player-accent-soft: #ff98b1;
}

/* BACKGROUND */

.arena-background {
  position: fixed;

  inset: 0;

  z-index: 0;

  overflow: hidden;

  pointer-events: none;

  background:
    radial-gradient(
      circle at 50% 45%,
      rgba(
        255,
        255,
        255,
        0.95
      ) 0%,
      rgba(
        255,
        255,
        255,
        0.35
      ) 18%,
      transparent 42%
    ),
    linear-gradient(
      180deg,
      #d8efff 0%,
      #effaff 28%,
      #d9f0dd 65%,
      #c5e5cc 100%
    );
}

.arena-background::before {
  content: "";

  position: absolute;

  left: 6%;
  right: 6%;

  top: 20%;
  bottom: 13%;

  border:
    4px solid
    rgba(
      255,
      255,
      255,
      0.28
    );

  border-radius: 70px;

  box-shadow:
    inset 0 0 0 2px
    rgba(
      69,
      146,
      94,
      0.06
    );
}

.arena-background::after {
  content: "";

  width: 480px;
  height: 480px;

  position: absolute;

  left: 50%;
  top: 48%;

  transform:
    translate(
      -50%,
      -50%
    );

  border:
    5px solid
    rgba(
      255,
      255,
      255,
      0.25
    );

  border-radius: 50%;
}

.arena-grid {
  position: absolute;

  inset: 0;

  opacity: 0.22;

  background-image:
    linear-gradient(
      rgba(
        255,
        255,
        255,
        0.08
      )
      1px,
      transparent 1px
    ),
    linear-gradient(
      90deg,
      rgba(
        255,
        255,
        255,
        0.08
      )
      1px,
      transparent 1px
    );

  background-size:
    60px 60px;
}

.background-glow {
  width: 500px;
  height: 500px;

  position: absolute;

  border-radius: 50%;

  filter:
    blur(130px);

  opacity: 0.18;
}

.glow-left {
  left: -190px;
  top: 120px;

  background: #64bfff;
}

.glow-right {
  right: -190px;
  bottom: 90px;

  background: #8ddfa5;
}

.center-pokeball {
  position: absolute;

  left: 50%;
  top: 50%;

  transform:
    translate(
      -50%,
      -50%
    );

  color:
    rgba(
      65,
      133,
      165,
      0.055
    );

  font-size:
    clamp(
      250px,
      32vw,
      500px
    );

  line-height: 1;
}

/* TOP HUD */

.top-hud {
  width:
    min(
      100%,
      1450px
    );

  min-height: 120px;

  position: relative;

  z-index: 10;

  display: grid;

  grid-template-columns:
    1.05fr
    1.15fr
    0.65fr
    1fr
    0.85fr;

  align-items: center;

  gap: 18px;

  margin:
    0
    auto
    18px;

  padding:
    20px
    24px;

  border:
    1px solid
    rgba(
      84,
      133,
      165,
      0.2
    );

  border-radius: 24px;

  background:
    rgba(
      255,
      255,
      255,
      0.75
    );

  backdrop-filter:
    blur(16px);

  box-shadow:
    0
    16px
    40px
    rgba(
      48,
      87,
      112,
      0.1
    );
}

/* PLAYER */

.player-identity {
  display: flex;

  align-items: center;

  gap: 16px;
}

.player-avatar {
  width: 74px;
  height: 74px;

  flex:
    0
    0
    74px;

  display: grid;

  place-items: center;

  overflow: hidden;

  border:
    4px solid
    var(
      --player-accent
    );

  border-radius: 50%;

  color: #17324a;

  background:
    linear-gradient(
      145deg,
      #ffffff,
      #e6f5ff
    );

  box-shadow:
    0
    8px
    25px
    rgba(
      47,
      118,
      168,
      0.16
    );

  font-size: 33px;
}

.identity-copy span,
.hud-label {
  display: block;

  color:
    var(
      --player-accent
    );

  font-size: 9px;

  font-weight: 900;

  letter-spacing:
    0.13em;
}

.identity-copy strong {
  display: block;

  margin:
    3px 0;

  color: #17324a;

  font-size: 26px;

  line-height: 1;
}

.identity-copy small {
  color: #68849a;

  font-size: 9px;
}

/* COMBAT STATS */

.combat-stats {
  padding:
    6px
    18px;

  border-left:
    1px solid
    rgba(
      79,
      129,
      160,
      0.15
    );
}

.hp-title,
.gauge-title {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 10px;

  color: #5d7990;

  font-size: 8px;

  font-weight: 800;

  letter-spacing:
    0.07em;
}

.hp-title strong {
  color: #17324a;

  font-size: 14px;
}

.gauge-title {
  margin-top: 10px;
}

.gauge-title strong {
  color: #506a80;

  font-size: 10px;
}

.hud-hp-track,
.hud-skill-track,
.enemy-mini-track {
  width: 100%;
  height: 9px;

  margin-top: 5px;

  overflow: hidden;

  border-radius:
    999px;

  background:
    rgba(
      71,
      110,
      139,
      0.13
    );
}

.hud-hp-fill {
  height: 100%;

  border-radius:
    inherit;

  background:
    linear-gradient(
      90deg,
      #28aefe,
      #62e2b8
    );

  transition:
    width 0.3s ease;
}

.hud-skill-fill {
  height: 100%;

  border-radius:
    inherit;

  background:
    linear-gradient(
      90deg,
      #7568ff,
      #a96eff
    );

  transition:
    width 0.3s ease;
}

/* TURN */

.turn-core {
  min-height: 76px;

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 15px;

  padding:
    12px
    18px;

  border:
    1px solid
    rgba(
      75,
      132,
      168,
      0.23
    );

  border-radius: 20px;

  color: #5d7588;

  background:
    rgba(
      245,
      251,
      255,
      0.72
    );

  text-align: center;
}

.turn-core.active {
  color: #147548;

  border-color:
    rgba(
      48,
      181,
      109,
      0.32
    );

  background:
    rgba(
      218,
      250,
      230,
      0.78
    );

  box-shadow:
    0
    10px
    25px
    rgba(
      54,
      159,
      105,
      0.1
    );
}

.turn-core.scanning {
  border-color:
    rgba(
      29,
      155,
      226,
      0.35
    );

  background:
    rgba(
      220,
      244,
      255,
      0.88
    );
}

.turn-core.waiting {
  opacity: 0.8;
}

.turn-core strong {
  display: block;

  font-size: 17px;

  letter-spacing:
    0.09em;
}

.turn-core div span {
  display: block;

  margin-top: 4px;

  font-size: 8px;

  font-weight: 800;
}

.turn-arrow {
  color:
    var(
      --player-accent
    );

  font-size: 19px;

  font-weight: 900;
}

/* ENEMY */

.enemy-mini-status {
  padding:
    5px
    0
    5px
    16px;

  border-left:
    1px solid
    rgba(
      225,
      88,
      113,
      0.16
    );
}

.enemy-mini-status
> span {
  color: #dd4c70;

  font-size: 8px;

  font-weight: 900;
}

.enemy-mini-status strong {
  display: block;

  margin:
    3px 0;

  color: #17324a;

  font-size: 15px;
}

.enemy-mini-status small {
  color: #73899b;

  font-size: 8px;
}

.enemy-mini-fill {
  height: 100%;

  border-radius:
    inherit;

  background:
    linear-gradient(
      90deg,
      #ff6687,
      #ff9b6b
    );
}

/* DECK */

.deck-mini-status {
  padding:
    5px
    14px;

  border-left:
    1px solid
    rgba(
      68,
      129,
      165,
      0.13
    );

  border-right:
    1px solid
    rgba(
      68,
      129,
      165,
      0.13
    );

  text-align: center;
}

.deck-mini-status
> span {
  display: block;

  color: #7290a5;

  font-size: 7px;

  font-weight: 900;

  letter-spacing:
    0.08em;
}

.deck-mini-status strong {
  display: block;

  margin:
    3px 0;

  color:
    var(
      --player-accent
    );

  font-size: 17px;
}

.deck-mini-status small {
  color: #849aaa;

  font-size: 7px;

  font-weight: 850;
}

/* NOTIFICATION */

.notification-panel {
  width:
    min(
      100%,
      1200px
    );

  min-height: 78px;

  position: relative;

  z-index: 15;

  display: grid;

  grid-template-columns:
    auto
    1fr
    auto;

  align-items: center;

  gap: 15px;

  margin:
    0
    auto
    16px;

  padding:
    16px
    20px;

  border:
    1px solid
    rgba(
      55,
      147,
      208,
      0.25
    );

  border-radius: 18px;

  color: #17324a;

  background:
    rgba(
      239,
      250,
      255,
      0.86
    );

  backdrop-filter:
    blur(14px);

  box-shadow:
    0
    12px
    26px
    rgba(
      59,
      116,
      152,
      0.09
    );
}

.notification-icon {
  width: 48px;
  height: 48px;

  display: grid;

  place-items: center;

  border:
    1px solid
    rgba(
      44,
      150,
      215,
      0.35
    );

  border-radius: 50%;

  color:
    var(
      --player-accent
    );

  background:
    rgba(
      255,
      255,
      255,
      0.68
    );

  font-size: 21px;
}

.notification-panel span {
  color:
    var(
      --player-accent
    );

  font-size: 8px;

  font-weight: 900;

  letter-spacing:
    0.1em;
}

.notification-panel strong {
  display: block;

  margin:
    3px 0;

  color: #17324a;

  font-size: 14px;
}

.notification-panel p {
  margin: 0;

  color: #6c879b;

  font-size: 9px;
}

.notification-counter,
.scan-indicator {
  color:
    var(
      --player-accent
    );

  font-size: 13px;

  font-weight: 900;
}

.pulse-icon {
  animation:
    scanPulse
    1.2s
    infinite;
}

/* BUFF */

.buff-strip {
  position: relative;

  z-index: 10;

  display: flex;

  justify-content:
    center;

  flex-wrap: wrap;

  gap: 8px;

  margin:
    0
    auto
    14px;
}

.buff-strip span {
  padding:
    7px
    11px;

  border:
    1px solid
    rgba(
      68,
      129,
      165,
      0.18
    );

  border-radius:
    999px;

  color: #41647e;

  background:
    rgba(
      255,
      255,
      255,
      0.68
    );

  font-size: 8px;

  font-weight: 800;

  box-shadow:
    0
    6px
    15px
    rgba(
      51,
      97,
      125,
      0.06
    );
}

/* BATTLE STAGE */

.battle-stage {
  width:
    min(
      100%,
      1550px
    );

  position: relative;

  z-index: 5;

  display: grid;

  grid-template-columns:
    158px
    minmax(
      0,
      1fr
    )
    158px;

  align-items:
    start;

  gap: 18px;

  margin:
    0
    auto;
}

.side-zone {
  position: sticky;

  top: 18px;
}

.active-panel {
  min-width: 0;
}

.active-header-meta {
  display: flex;

  align-items: center;

  gap: 8px;
}

.deck-remaining-chip {
  padding:
    6px
    10px;

  border-radius:
    999px;

  color:
    var(
      --player-accent
    );

  background:
    rgba(
      220,
      239,
      249,
      0.72
    );

  font-size: 8px;

  font-weight: 950;
}

.active-drop-zone {
  transition:
    border-color
      0.18s ease,
    box-shadow
      0.18s ease,
    transform
      0.18s ease;
}

.active-drop-zone.drag-over-active {
  border-color:
    var(
      --player-accent
    );

  box-shadow:
    0 0 0 4px
      rgba(
        45,
        158,
        225,
        0.1
      ),
    0 20px 45px
      rgba(
        55,
        94,
        119,
        0.14
      );

  transform:
    translateY(-2px);
}

.active-drop-hint {
  position: relative;

  z-index: 4;

  margin:
    -5px
    0
    14px;

  padding:
    9px
    12px;

  border:
    1px dashed
    var(
      --player-accent
    );

  border-radius: 11px;

  color:
    var(
      --player-accent
    );

  background:
    rgba(
      255,
      255,
      255,
      0.65
    );

  font-size: 8px;

  font-weight: 950;

  text-align: center;

  letter-spacing:
    0.07em;
}

.active-draggable-card[
  draggable="true"
] {
  cursor: grab;
}

.active-draggable-card[
  draggable="true"
]:active {
  cursor: grabbing;
}

.drag-handle {
  position: absolute;

  right: 13px;
  bottom: 10px;

  z-index: 5;

  color: #7d9bb0;

  font-size: 12px;

  font-weight: 950;
}

.drag-instruction {
  position: absolute;

  left: 12px;
  bottom: 11px;

  z-index: 4;

  color: #7c95a8;

  font-size: 6px;

  font-weight: 900;

  letter-spacing:
    0.07em;
}

/* PANEL */

.cyber-panel {
  min-height: 300px;

  position: relative;

  padding:
    22px
    26px
    26px;

  overflow: hidden;

  border:
    1px solid
    rgba(
      85,
      134,
      165,
      0.2
    );

  border-radius: 26px;

  background:
    rgba(
      255,
      255,
      255,
      0.7
    );

  backdrop-filter:
    blur(15px);

  box-shadow:
    0
    16px
    38px
    rgba(
      55,
      94,
      119,
      0.09
    );
}

.cyber-panel::before {
  content: "";

  position: absolute;

  inset: 0;

  pointer-events: none;

  background:
    linear-gradient(
      120deg,
      rgba(
        255,
        255,
        255,
        0.4
      ),
      transparent 35%
    );
}

.cyber-panel-header {
  position: relative;

  z-index: 2;

  display: flex;

  align-items: center;

  justify-content:
    space-between;

  margin-bottom:
    18px;
}

.panel-title {
  display: flex;

  align-items: center;

  gap: 10px;
}

.panel-icon {
  color:
    var(
      --player-accent
    );

  font-size: 18px;
}

.panel-title strong {
  color: #24435c;

  font-size: 16px;

  letter-spacing:
    0.08em;
}

.panel-count {
  padding:
    6px
    10px;

  border-radius:
    999px;

  color: #477391;

  background:
    rgba(
      220,
      239,
      249,
      0.72
    );

  font-size: 10px;

  font-weight: 900;
}

/* DECK GRID */

.deck-slots {
  position: relative;

  z-index: 2;

  display: grid;

  grid-template-columns:
    repeat(
      auto-fit,
      minmax(
        150px,
        1fr
      )
    );

  align-items: start;

  gap: 18px;
}

/* CARD */

.cyber-card {
  min-height: 290px;

  position: relative;

  padding: 10px;

  overflow: hidden;

  border:
    2px solid
    rgba(
      67,
      153,
      210,
      0.25
    );

  border-radius: 22px;

  color: #17324a;

  background:
    rgba(
      255,
      255,
      255,
      0.9
    );

  box-shadow:
    0
    9px
    24px
    rgba(
      60,
      108,
      137,
      0.1
    );

  cursor: pointer;

  transition:
    transform
      0.18s ease,
    border-color
      0.18s ease,
    box-shadow
      0.18s ease;
}

.cyber-card:hover {
  transform:
    translateY(-4px);

  border-color:
    rgba(
      31,
      157,
      229,
      0.45
    );

  box-shadow:
    0
    14px
    30px
    rgba(
      54,
      115,
      153,
      0.15
    );
}

.cyber-card.selected {
  border-color:
    var(
      --player-accent
    );

  box-shadow:
    0 0 0 4px
      rgba(
        45,
        158,
        225,
        0.12
      ),
    0 16px 30px
      rgba(
        50,
        112,
        151,
        0.14
      );
}

.cyber-card.exhausted {
  opacity: 0.45;

  filter:
    grayscale(0.75);
}

.cyber-card-inner {
  position: relative;

  z-index: 1;

  padding-bottom: 25px;
}

.cyber-card-inner header {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 8px;

  margin-bottom: 4px;
}

.cyber-card-inner header strong {
  max-width: 68%;

  overflow: hidden;

  color: #19354c;

  font-size: 12px;

  text-overflow:
    ellipsis;

  white-space: nowrap;
}

.cyber-card-inner header span {
  padding:
    4px
    7px;

  border-radius:
    999px;

  color: #297cad;

  background:
    rgba(
      48,
      156,
      218,
      0.1
    );

  font-size: 7px;

  font-weight: 900;

  text-transform:
    uppercase;
}

.cyber-card-inner
> small {
  display: block;

  margin-bottom: 8px;

  color: #6c879a;

  font-size: 10px;

  font-weight: 700;
}

.cyber-card-image {
  width: 100%;
  height: 170px;

  overflow: hidden;

  margin-bottom: 10px;

  border:
    1px solid
    rgba(
      77,
      132,
      164,
      0.15
    );

  border-radius: 15px;

  background: #e6f1f6;
}

.cyber-card-image img {
  width: 100%;
  height: 100%;

  display: block;

  object-fit: cover;
}

.image-placeholder {
  width: 100%;
  height: 100%;

  display: grid;

  place-items: center;

  color: #72a5c4;

  background:
    linear-gradient(
      145deg,
      #edf7fb,
      #dcebf2
    );

  font-size: 38px;
}

.cyber-card-inner footer {
  display: flex;

  align-items:
    flex-end;

  justify-content:
    space-between;

  gap: 8px;
}

.cyber-card-inner footer span {
  display: block;

  color: #6e8497;

  font-size: 7px;

  font-weight: 800;
}

.cyber-card-inner footer strong {
  color: #17324a;

  font-size: 23px;
}

.cyber-card-inner footer small {
  color: #6e8497;

  font-size: 7px;

  font-weight: 800;
}

/* SECONDARY */

.card-secondary-action {
  width:
    calc(
      100% -
      20px
    );

  min-height: 30px;

  position: absolute;

  left: 10px;
  bottom: 9px;

  z-index: 3;

  border: 0;

  border-radius: 10px;

  color: #ffffff;

  background:
    linear-gradient(
      135deg,
      #38aef2,
      #2188d6
    );

  box-shadow:
    0
    6px
    14px
    rgba(
      44,
      127,
      180,
      0.15
    );

  font-size: 7px;

  font-weight: 900;

  cursor: pointer;
}

.card-secondary-action:hover:not(:disabled) {
  filter:
    brightness(1.05);
}

.card-secondary-action:disabled {
  opacity: 0.38;

  cursor: not-allowed;

  box-shadow: none;
}

/* EMPTY */

.empty-card {
  min-height: 250px;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 12px;

  border:
    2px dashed
    rgba(
      76,
      139,
      177,
      0.25
    );

  color: #7595aa;

  background:
    rgba(
      247,
      253,
      255,
      0.45
    );

  cursor: default;

  box-shadow: none;
}

.empty-card:hover {
  transform: none;

  box-shadow: none;
}

.empty-ball {
  width: 60px;
  height: 60px;

  display: grid;

  place-items: center;

  border:
    2px solid
    rgba(
      51,
      144,
      200,
      0.34
    );

  border-radius: 50%;

  color: #5aa5d0;

  background:
    rgba(
      255,
      255,
      255,
      0.55
    );

  font-size: 30px;
}

.empty-card span {
  font-size: 9px;

  font-weight: 700;
}

/* TARGET PICKER */

.target-picker-overlay {
  position: fixed;

  inset: 0;

  z-index: 12000;

  display: grid;

  place-items: center;

  padding: 24px;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}

.target-picker-backdrop {
  position: absolute;

  inset: 0;

  background:
    rgba(
      236,
      247,
      255,
      0.78
    );

  backdrop-filter:
    blur(12px);
}

.target-picker-panel {
  width:
    min(
      100%,
      1040px
    );

  max-height:
    calc(
      100dvh -
      48px
    );

  position: relative;

  z-index: 2;

  overflow-y: auto;

  padding: 24px;

  border:
    1px solid
    rgba(
      65,
      151,
      201,
      0.28
    );

  border-radius: 24px;

  color: #17324a;

  background:
    linear-gradient(
      145deg,
      rgba(
        255,
        255,
        255,
        0.98
      ),
      rgba(
        236,
        247,
        253,
        0.98
      )
    );

  box-shadow:
    0
    26px
    70px
    rgba(
      68,
      119,
      149,
      0.20
    ),
    inset
    0
    1px
    0
    rgba(
      255,
      255,
      255,
      .95
    );
}

.target-picker-header {
  display: flex;

  align-items:
    flex-start;

  justify-content:
    space-between;

  gap: 20px;

  padding-bottom: 18px;

  border-bottom:
    1px solid
    rgba(
      61,
      116,
      151,
      0.12
    );
}

.target-picker-header h2 {
  margin:
    5px
    0
    0;

  color: #1e4a67;

  font-size: 24px;

  letter-spacing:
    0.04em;
}

.target-picker-header p {
  margin:
    7px
    0
    0;

  color: #6f8799;

  font-size: 10px;
}

.target-picker-header p strong {
  color: #254e69;
}

.target-close-button {
  width: 42px;
  height: 42px;

  flex: none;

  display: grid;

  place-items: center;

  border:
    1px solid
    rgba(
      71,
      132,
      169,
      0.16
    );

  border-radius: 11px;

  color: #6f8799;

  background:
    rgba(
      255,
      255,
      255,
      0.78
    );

  cursor: pointer;
}

.target-close-button:hover:not(:disabled) {
  color: #d13c5d;

  border-color:
    rgba(
      226,
      68,
      101,
      0.35
    );

  background: #fff;
}

.target-picker-attacker {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 20px;

  margin-top: 18px;

  padding:
    12px
    14px;

  border:
    1px solid
    rgba(
      42,
      160,
      210,
      0.18
    );

  border-radius: 12px;

  background:
    rgba(
      222,
      246,
      255,
      0.65
    );
}

.target-picker-attacker
> div:first-child {
  display: flex;

  flex-direction:
    column;

  gap: 3px;
}

.target-picker-attacker span {
  color: #6e8799;

  font-size: 7px;

  font-weight: 950;

  letter-spacing:
    0.1em;
}

.target-picker-attacker strong,
.target-attacker-stats b {
  color: #214b66;
}

.target-picker-attacker strong {
  font-size: 13px;
}

.target-attacker-stats {
  display: flex;

  gap: 8px;
}

.target-attacker-stats span {
  min-width: 88px;

  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 8px;

  padding:
    7px
    9px;

  border:
    1px solid
    rgba(
      68,
      131,
      168,
      0.08
    );

  border-radius: 8px;

  color: #638096;

  background:
    rgba(
      255,
      255,
      255,
      .78
    );
}

.target-attacker-stats b {
  font-size: 10px;
}

.target-picker-help {
  margin:
    17px
    0
    10px;

  color: #74899b;

  font-size: 9px;

  text-align: center;
}

.target-picker-help strong {
  color: #d54867;
}

.target-card-grid {
  display: grid;

  grid-template-columns:
    repeat(
      4,
      minmax(
        0,
        1fr
      )
    );

  gap: 12px;
}

.target-card {
  min-width: 0;

  overflow: hidden;

  padding: 0;

  border:
    2px solid
    rgba(
      67,
      126,
      162,
      0.14
    );

  border-radius: 15px;

  color: #294f69;

  background:
    linear-gradient(
      160deg,
      #ffffff,
      #edf7fc
    );

  box-shadow:
    0
    10px
    24px
    rgba(
      74,
      125,
      153,
      0.10
    );

  cursor: pointer;

  transition:
    transform
      0.2s ease,
    border-color
      0.2s ease,
    box-shadow
      0.2s ease;
}

.target-card:hover:not(:disabled) {
  transform:
    translateY(-4px);

  border-color:
    rgba(
      232,
      88,
      118,
      0.46
    );

  box-shadow:
    0
    14px
    28px
    rgba(
      88,
      132,
      155,
      0.14
    );
}

.target-card.selected {
  transform:
    translateY(-5px);

  border-color:
    #e85a78;

  box-shadow:
    0
    0
    0
    3px
    rgba(
      232,
      90,
      120,
      0.10
    ),
    0
    14px
    30px
    rgba(
      187,
      78,
      104,
      0.18
    );
}

.target-card:disabled {
  cursor: default;

  opacity: 0.7;
}

.target-card-image {
  height: 190px;

  position: relative;

  overflow: hidden;

  background: #e8f3f8;
}

.target-card-image img {
  width: 100%;
  height: 100%;

  object-fit: cover;
}

.target-image-placeholder {
  width: 100%;
  height: 100%;

  display: grid;

  place-items: center;

  color: #ff5778;

  font-size: 54px;

  opacity: 0.26;
}

.target-lock-badge {
  position: absolute;

  left: 50%;
  bottom: 9px;

  transform:
    translateX(-50%);

  padding:
    5px
    8px;

  border-radius:
    999px;

  color: white;

  background:
    rgba(
      226,
      32,
      74,
      0.88
    );

  box-shadow:
    0
    0
    15px
    rgba(
      255,
      49,
      94,
      0.42
    );

  font-size: 6px;

  font-weight: 950;

  letter-spacing:
    0.08em;

  white-space: nowrap;
}

.target-card-body {
  padding: 11px;
}

.target-card-body
> strong {
  display: block;

  overflow: hidden;

  color: #244b66;

  font-size: 11px;

  text-overflow:
    ellipsis;

  white-space: nowrap;
}

.target-card-body
> small {
  display: block;

  margin-top: 2px;

  color: #cf5670;

  font-size: 6px;

  font-weight: 900;

  text-transform:
    uppercase;
}

.target-card-hp {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 7px;

  margin-top: 9px;

  padding:
    6px
    7px;

  border-radius: 7px;

  background:
    rgba(
      232,
      244,
      250,
      0.76
    );
}

.target-card-hp span,
.target-card-stats span {
  color: #6b8396;

  font-size: 6px;

  font-weight: 900;
}

.target-card-hp b,
.target-card-stats b {
  color: #244b66;

  font-size: 9px;
}

.target-card-stats {
  display: grid;

  grid-template-columns:
    1fr
    1fr;

  gap: 6px;

  margin-top: 7px;
}

.target-card-stats span {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 5px;

  padding: 6px;

  border-radius: 7px;

  background:
    rgba(
      232,
      244,
      250,
      0.76
    );
}

.target-preview {
  margin-top: 16px;

  padding: 13px;

  border:
    1px solid
    rgba(
      210,
      158,
      38,
      0.22
    );

  border-radius: 12px;

  background:
    rgba(
      255,
      246,
      207,
      0.58
    );
}

.target-preview-title {
  color: #ae7a11;

  font-size: 7px;

  font-weight: 950;

  letter-spacing:
    0.12em;
}

.target-preview-flow {
  display: flex;

  align-items: center;

  justify-content:
    center;

  flex-wrap: wrap;

  gap: 9px;

  margin-top: 9px;
}

.target-preview-flow span {
  display: flex;

  align-items: center;

  gap: 5px;

  padding:
    6px
    8px;

  border:
    1px solid
    rgba(
      115,
      137,
      150,
      0.08
    );

  border-radius: 7px;

  color: #6a8194;

  background:
    rgba(
      255,
      255,
      255,
      .74
    );

  font-size: 7px;

  font-weight: 900;
}

.target-preview-flow b,
.target-preview-result strong {
  color: #244b66;
}

.target-preview-flow b {
  font-size: 10px;
}

.target-preview-flow
.preview-operator {
  padding: 0;

  color: #8aa0b0;

  background:
    transparent;

  font-size: 15px;
}

.target-preview-flow
.preview-damage {
  color: #c94b68;

  background:
    rgba(
      255,
      225,
      232,
      0.72
    );
}

.target-preview-result {
  display: flex;

  align-items: center;

  justify-content:
    center;

  flex-wrap: wrap;

  gap: 10px;

  margin-top: 10px;

  font-size: 9px;
}

.target-preview-result span {
  color: #6d8293;
}

.target-preview-result em {
  padding:
    4px
    7px;

  border-radius:
    999px;

  color: #ff8ca3;

  background:
    rgba(
      255,
      61,
      102,
      0.09
    );

  font-size: 7px;

  font-style: normal;

  font-weight: 950;
}

.target-preview
> small {
  display: block;

  margin-top: 10px;

  color: #718797;

  font-size: 7px;

  line-height: 1.5;

  text-align: center;
}

.target-picker-actions {
  display: flex;

  justify-content:
    flex-end;

  gap: 9px;

  margin-top: 17px;

  padding-top: 15px;

  border-top:
    1px solid
    rgba(
      76,
      126,
      157,
      0.10
    );
}

.target-cancel-button,
.target-confirm-button {
  min-width: 150px;

  padding:
    10px
    14px;

  border-radius: 9px;

  font-size: 9px;

  font-weight: 950;

  letter-spacing:
    0.05em;

  cursor: pointer;
}

.target-cancel-button {
  color: #667f92;

  border:
    1px solid
    rgba(
      76,
      126,
      157,
      0.18
    );

  background:
    rgba(
      255,
      255,
      255,
      .78
    );
}

.target-confirm-button {
  border: 0;

  color: white;

  background:
    linear-gradient(
      90deg,
      #df4264,
      #f16d89
    );

  box-shadow:
    0
    8px
    22px
    rgba(
      213,
      71,
      102,
      0.20
    );
}

.target-cancel-button:disabled,
.target-confirm-button:disabled {
  opacity: 0.36;

  cursor: not-allowed;
}

.attack-skill.targeting {
  box-shadow:
    0
    0
    0
    2px
    rgba(
      255,
      83,
      118,
      0.35
    ),
    0
    0
    25px
    rgba(
      255,
      62,
      103,
      0.24
    );
}

.target-picker-enter-active,
.target-picker-leave-active {
  transition:
    opacity
    0.2s ease;
}

.target-picker-enter-active
.target-picker-panel,
.target-picker-leave-active
.target-picker-panel {
  transition:
    opacity
      0.2s ease,
    transform
      0.2s ease;
}

.target-picker-enter-from,
.target-picker-leave-to {
  opacity: 0;
}

.target-picker-enter-from
.target-picker-panel,
.target-picker-leave-to
.target-picker-panel {
  opacity: 0;

  transform:
    translateY(
      14px
    )
    scale(
      0.98
    );
}

/* SKILL INFO */

.skill-info-panel {
  width:
    min(
      calc(
        100% -
        32px
      ),
      1250px
    );

  position: fixed;

  left: 50%;
  bottom: 142px;

  z-index: 149;

  transform:
    translateX(-50%);

  padding:
    10px
    12px;

  border:
    1px solid
    rgba(
      74,
      132,
      166,
      0.22
    );

  border-radius: 20px;

  background:
    rgba(
      255,
      255,
      255,
      0.93
    );

  backdrop-filter:
    blur(18px);

  box-shadow:
    0
    15px
    42px
    rgba(
      46,
      75,
      95,
      0.13
    );
}

.skill-info-header {
  min-height: 28px;

  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 12px;

  margin-bottom: 8px;
}

.skill-info-header
.eyebrow {
  display: block;

  color:
    var(
      --player-accent
    );

  font-size: 5.5px;

  font-weight: 950;

  letter-spacing:
    0.11em;
}

.skill-info-header
> div:first-child
> strong {
  display: block;

  margin-top: 2px;

  color: #18364e;

  font-size: 10px;

  font-weight: 950;
}

.player-status-summary {
  display: flex;

  align-items: center;

  justify-content:
    flex-end;

  flex-wrap: wrap;

  gap: 5px;
}

.status-pill {
  padding:
    4px
    7px;

  border-radius:
    999px;

  font-size: 5.5px;

  font-weight: 950;

  white-space: nowrap;
}

.status-pill.power {
  color: #986800;

  border:
    1px solid
    rgba(
      221,
      166,
      31,
      0.28
    );

  background: #fff6d8;
}

.status-pill.defense {
  color: #276c9f;

  border:
    1px solid
    rgba(
      56,
      143,
      210,
      0.27
    );

  background: #eaf6ff;
}

.status-pill.water {
  color: #087c9e;

  border:
    1px solid
    rgba(
      21,
      181,
      214,
      0.27
    );

  background: #e7fbff;
}

.status-pill.debuff {
  color: #536fa2;

  border:
    1px solid
    rgba(
      111,
      147,
      207,
      0.28
    );

  background: #eff5ff;
}

.skill-info-grid {
  display: grid;

  grid-template-columns:
    repeat(
      6,
      minmax(
        0,
        1fr
      )
    );

  gap: 7px;
}

.skill-info-card {
  min-width: 0;
  min-height: 92px;

  display: flex;

  flex-direction: column;

  padding:
    8px
    9px;

  border:
    1px solid
    rgba(
      77,
      129,
      160,
      0.15
    );

  border-radius: 12px;

  color: #39586e;

  background:
    rgba(
      246,
      251,
      254,
      0.9
    );
}

.skill-info-card.ready {
  border-color:
    rgba(
      51,
      158,
      218,
      0.25
    );

  background:
    rgba(
      249,
      253,
      255,
      0.98
    );
}

.skill-info-card.used {
  opacity: 0.62;

  filter:
    grayscale(0.25);
}

.skill-info-card.active {
  border-color:
    rgba(
      55,
      144,
      216,
      0.36
    );

  box-shadow:
    inset
    0
    0
    15px
    rgba(
      55,
      144,
      216,
      0.08
    );
}

.skill-info-card-head {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 6px;

  margin-bottom: 5px;
}

.skill-info-card-head
> div {
  min-width: 0;

  flex: 1;
}

.skill-info-icon {
  flex:
    0
    0
    auto;

  font-size: 17px;
}

.skill-info-card-head
strong {
  display: block;

  overflow: hidden;

  color: #1d4059;

  font-size: 6.5px;

  font-weight: 1000;

  letter-spacing:
    0.04em;

  text-overflow:
    ellipsis;

  white-space: nowrap;
}

.skill-info-card-head
em {
  display: block;

  margin-top: 1px;

  color:
    var(
      --player-accent
    );

  font-size: 5px;

  font-style: normal;

  font-weight: 950;
}

.skill-info-card.locked
.skill-info-card-head
em {
  color: #8c9aa4;
}

.skill-info-card.used
.skill-info-card-head
em {
  color: #a76c79;
}

.skill-info-card p {
  margin: 0;

  color: #334f64;

  font-size: 5.9px;

  font-weight: 850;

  line-height: 1.35;
}

.skill-info-card
> small {
  display: block;

  margin-top: auto;

  padding-top: 5px;

  color: #708695;

  font-size: 5.2px;

  line-height: 1.35;
}

.skill-info-card.attack {
  border-top:
    3px solid
    #e85e6b;
}

.skill-info-card.defense {
  border-top:
    3px solid
    #3b91d7;
}

.skill-info-card.ultimate {
  border-top:
    3px solid
    #8064db;
}

.skill-info-card.heal {
  border-top:
    3px solid
    #39b976;
}

.skill-info-card.synergy {
  border-top:
    3px solid
    #d7a92e;
}

.skill-info-card.summon {
  border-top:
    3px solid
    var(
      --player-accent
    );
}

/* ACTION INFO COMPACT / MODAL */

.action-info-header-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  flex-wrap: wrap;
}

.action-info-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 30px;
  padding: 0 12px;
  border: 1px solid rgba(63, 137, 181, 0.2);
  border-radius: 999px;
  color: #25506b;
  background: rgba(238, 248, 255, 0.9);
  font-size: 6px;
  font-weight: 1000;
  letter-spacing: 0.08em;
  cursor: pointer;
}

.action-info-toggle:hover {
  background: #ffffff;
  border-color: rgba(63, 137, 181, 0.4);
}

.action-info-button-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 7px;
}

.action-info-button {
  min-width: 0;
  min-height: 52px;
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 7px 8px;
  border: 1px solid rgba(77, 129, 160, 0.15);
  border-radius: 12px;
  color: #39586e;
  background: rgba(246, 251, 254, 0.94);
  cursor: pointer;
  text-align: left;
  transition: transform 0.14s ease, border-color 0.14s ease, box-shadow 0.14s ease;
}

.action-info-button:hover {
  transform: translateY(-2px);
  border-color: rgba(43, 141, 198, 0.34);
  box-shadow: 0 7px 18px rgba(44, 93, 124, 0.08);
}

.action-info-button.ready {
  background: rgba(250, 254, 255, 0.99);
}

.action-info-button.locked,
.action-info-button.used {
  opacity: 0.64;
}

.action-info-button-icon {
  font-size: 18px;
  flex: 0 0 auto;
}

.action-info-button-copy {
  min-width: 0;
  flex: 1;
}

.action-info-button-copy strong,
.action-info-button-copy small {
  display: block;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.action-info-button-copy strong {
  color: #1d4059;
  font-size: 6.2px;
  font-weight: 1000;
}

.action-info-button-copy small {
  margin-top: 2px;
  color: var(--player-accent);
  font-size: 5px;
  font-weight: 950;
}

.action-info-button-open {
  color: #7b93a3;
  font-size: 4.8px;
  font-weight: 950;
  white-space: nowrap;
}

.action-info-button.attack { border-top: 3px solid #e85e6b; }
.action-info-button.defense { border-top: 3px solid #3b91d7; }
.action-info-button.ultimate { border-top: 3px solid #8064db; }
.action-info-button.heal { border-top: 3px solid #39b976; }
.action-info-button.synergy { border-top: 3px solid #d7a92e; }
.action-info-button.summon { border-top: 3px solid var(--player-accent); }
.action-info-button.special { border-top: 3px solid #a45de0; }

.action-info-expand-enter-active,
.action-info-expand-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}

.action-info-expand-enter-from,
.action-info-expand-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

.skill-ready-balloons {
  position: fixed;
  left: 50%;
  bottom: 205px;
  z-index: 165;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transform: translateX(-50%);
  pointer-events: none;
  transition: bottom 0.2s ease;
}

.skill-ready-balloons.expanded {
  bottom: 266px;
}

.ready-balloon {
  pointer-events: auto;
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 150px;
  padding: 9px 12px;
  border: 1px solid rgba(83, 115, 164, 0.2);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 12px 30px rgba(45, 73, 101, 0.16);
  color: #263e57;
  cursor: pointer;
  animation: skillReadyFloat 2.4s ease-in-out infinite;
}

.ready-balloon > span {
  font-size: 21px;
}

.ready-balloon div {
  min-width: 0;
  text-align: left;
}

.ready-balloon strong,
.ready-balloon small {
  display: block;
}

.ready-balloon strong {
  font-size: 7px;
  font-weight: 1000;
  white-space: nowrap;
}

.ready-balloon small {
  margin-top: 2px;
  color: #7a8e9e;
  font-size: 5px;
  font-weight: 800;
}

.ready-balloon.ultimate { border-color: rgba(128, 100, 219, 0.35); }
.ready-balloon.synergy { border-color: rgba(215, 169, 46, 0.38); }
.ready-balloon.special { border-color: rgba(164, 93, 224, 0.4); }
.ready-balloon.fusion { border-color: rgba(232, 90, 132, 0.42); }

@keyframes skillReadyFloat {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-5px); }
}

.action-detail-overlay {
  position: fixed;
  inset: 0;
  z-index: 13000;
  display: grid;
  place-items: center;
  padding: 20px;
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}

.action-detail-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(226, 241, 250, 0.78);
  backdrop-filter: blur(10px);
}

.action-detail-modal,
.special-skill-modal {
  position: relative;
  z-index: 1;
  width: min(92vw, 620px);
  max-height: min(86dvh, 760px);
  overflow: auto;
  padding: 22px;
  border: 1px solid rgba(63, 132, 173, 0.22);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow: 0 28px 80px rgba(42, 75, 98, 0.22);
}

.special-skill-modal {
  width: min(94vw, 980px);
}

.action-detail-modal > header,
.special-modal-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.action-detail-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.action-detail-title > span {
  font-size: 34px;
}

.action-detail-title small,
.special-modal-header .eyebrow {
  color: var(--player-accent);
  font-size: 8px;
  font-weight: 1000;
  letter-spacing: 0.11em;
}

.action-detail-title h2,
.special-modal-header h2 {
  margin: 3px 0 0;
  color: #173a54;
  font-size: 20px;
  font-weight: 1000;
}

.special-modal-header p {
  margin: 5px 0 0;
  color: #718898;
  font-size: 11px;
}

.modal-close {
  width: 36px;
  height: 36px;
  border: 1px solid rgba(66, 120, 154, 0.16);
  border-radius: 12px;
  color: #557487;
  background: #f5fbff;
  cursor: pointer;
}

.action-detail-status {
  display: inline-flex;
  margin: 18px 0 8px;
  padding: 6px 10px;
  border-radius: 999px;
  color: #788e9d;
  background: #edf4f8;
  font-size: 8px;
  font-weight: 1000;
}

.action-detail-status.ready {
  color: #15865b;
  background: #e7f9ef;
}

.action-detail-block {
  margin-top: 12px;
  padding: 14px;
  border: 1px solid rgba(74, 126, 158, 0.14);
  border-radius: 14px;
  background: #f8fcff;
}

.action-detail-block > span,
.special-target-panel > span,
.special-effects-panel > span {
  color: #8195a2;
  font-size: 7px;
  font-weight: 1000;
  letter-spacing: 0.11em;
}

.action-detail-block p {
  margin: 6px 0 0;
  color: #29485e;
  font-size: 12px;
  line-height: 1.55;
}

.modal-primary {
  min-height: 42px;
  padding: 0 18px;
  border: 0;
  border-radius: 13px;
  color: #ffffff;
  background: linear-gradient(135deg, #3faaf0, #2e8ed4);
  font-size: 9px;
  font-weight: 1000;
  letter-spacing: 0.06em;
  cursor: pointer;
}

.modal-primary.secondary {
  margin-top: 16px;
  color: #486879;
  background: #edf5f9;
}

.modal-primary:disabled {
  opacity: 0.38;
  cursor: not-allowed;
}

.special-skill-tabs {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  margin-top: 18px;
  padding-bottom: 5px;
}

.special-skill-tab {
  flex: 0 0 auto;
  min-width: 170px;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 10px 12px;
  border: 1px solid rgba(86, 129, 160, 0.16);
  border-radius: 14px;
  color: #36566b;
  background: #f7fbfe;
  cursor: pointer;
  text-align: left;
}

.special-skill-tab.selected {
  border-color: rgba(164, 93, 224, 0.55);
  box-shadow: 0 0 0 3px rgba(164, 93, 224, 0.08);
}

.special-skill-tab.ready {
  background: #fbf8ff;
}

.special-skill-tab > span {
  font-size: 22px;
}

.special-skill-tab strong,
.special-skill-tab small {
  display: block;
}

.special-skill-tab strong {
  font-size: 9px;
  font-weight: 1000;
}

.special-skill-tab small {
  margin-top: 2px;
  color: #8a71a8;
  font-size: 6px;
  font-weight: 900;
}

.special-detail-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(250px, 0.65fr);
  gap: 16px;
  margin-top: 16px;
}

.special-detail-main,
.special-target-panel {
  min-width: 0;
}

.special-skill-hero {
  display: flex;
  gap: 14px;
  padding: 16px;
  border: 1px solid rgba(164, 93, 224, 0.16);
  border-radius: 18px;
  background: linear-gradient(135deg, #fbf8ff, #f4fbff);
}

.special-skill-hero-icon {
  width: 58px;
  height: 58px;
  flex: 0 0 58px;
  display: grid;
  place-items: center;
  border-radius: 17px;
  background: #ffffff;
  box-shadow: 0 8px 22px rgba(84, 73, 114, 0.08);
  font-size: 30px;
}

.special-skill-hero span {
  color: #a45de0;
  font-size: 7px;
  font-weight: 1000;
  letter-spacing: 0.12em;
}

.special-skill-hero h3 {
  margin: 3px 0 4px;
  color: #243c56;
  font-size: 18px;
}

.special-skill-hero p {
  margin: 0;
  color: #6b8190;
  font-size: 10px;
  line-height: 1.5;
}

.special-metric-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 10px;
}

.special-metric-grid > div {
  padding: 10px;
  border: 1px solid rgba(78, 128, 158, 0.12);
  border-radius: 12px;
  background: #f8fcfe;
}

.special-metric-grid span,
.special-metric-grid strong {
  display: block;
}

.special-metric-grid span {
  color: #8295a1;
  font-size: 6px;
  font-weight: 1000;
}

.special-metric-grid strong {
  margin-top: 3px;
  color: #315168;
  font-size: 8px;
}

.special-effects-panel,
.special-readiness,
.special-target-panel {
  margin-top: 10px;
  padding: 13px;
  border: 1px solid rgba(76, 126, 157, 0.13);
  border-radius: 14px;
  background: #f9fcfe;
}

.special-effects-panel ul {
  margin: 7px 0 0;
  padding-left: 18px;
  color: #355469;
  font-size: 9px;
  line-height: 1.55;
}

.special-readiness {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.special-readiness strong {
  color: #9a5d6f;
  font-size: 8px;
}

.special-readiness span {
  color: #748995;
  font-size: 8px;
  text-align: right;
}

.special-readiness.ready strong {
  color: #14916a;
}

.special-target-panel {
  margin-top: 0;
}

.special-target-panel p {
  color: #6f8695;
  font-size: 9px;
  line-height: 1.45;
}

.special-target-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 10px;
}

.special-target-card {
  min-width: 0;
  padding: 7px;
  border: 1px solid rgba(76, 127, 158, 0.15);
  border-radius: 12px;
  background: #ffffff;
  color: #34556c;
  cursor: pointer;
}

.special-target-card.selected {
  border-color: #a45de0;
  box-shadow: 0 0 0 3px rgba(164, 93, 224, 0.1);
}

.special-target-card img,
.special-target-placeholder {
  width: 100%;
  height: 82px;
  display: grid;
  place-items: center;
  object-fit: cover;
  border-radius: 9px;
  background: #eef7fb;
  font-size: 25px;
}

.special-target-card strong,
.special-target-card small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.special-target-card strong {
  margin-top: 6px;
  font-size: 8px;
}

.special-target-card small {
  margin-top: 2px;
  color: #8497a3;
  font-size: 6px;
}

.special-empty-state,
.special-empty-target {
  margin-top: 16px;
  padding: 20px;
  border: 1px dashed rgba(92, 135, 160, 0.24);
  border-radius: 14px;
  color: #748a98;
  background: #f8fcfe;
  text-align: center;
  font-size: 10px;
}

.special-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 9px;
  margin-top: 16px;
}

.special-use-button {
  background: linear-gradient(135deg, #aa63e4, #7e4fca);
}

.special-skill {
  border-color: rgba(164, 93, 224, 0.3);
  background: linear-gradient(180deg, rgba(252, 248, 255, 0.98), rgba(247, 251, 254, 0.96));
}

.fusion-skill {
  border-color: rgba(232, 90, 132, 0.32);
  background: linear-gradient(180deg, rgba(255, 247, 250, 0.98), rgba(251, 246, 255, 0.96));
}

.fusion-modal {
  position: relative;
  z-index: 2;
  width: min(1080px, calc(100vw - 40px));
  max-height: min(820px, calc(100dvh - 40px));
  overflow: auto;
  padding: 22px;
  border: 1px solid rgba(222, 92, 135, 0.24);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow: 0 30px 90px rgba(64, 43, 68, 0.28);
}

.fusion-modal-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  padding-bottom: 16px;
  border-bottom: 1px solid rgba(87, 134, 163, 0.13);
}

.fusion-modal-header h2,
.fusion-result-hero h3 {
  margin: 4px 0;
  color: #273d54;
}

.fusion-modal-header p,
.fusion-result-hero p {
  margin: 0;
  color: #7890a1;
  font-size: 12px;
  line-height: 1.55;
}

.fusion-empty-state {
  padding: 42px 20px;
  color: #7a91a2;
  text-align: center;
  font-weight: 800;
}

.fusion-tabs {
  display: flex;
  gap: 10px;
  margin: 18px 0;
  overflow-x: auto;
  padding-bottom: 4px;
}

.fusion-tab {
  flex: 0 0 210px;
  min-height: 66px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid rgba(87, 134, 163, 0.18);
  border-radius: 16px;
  background: #f8fbfd;
  color: #344f65;
  text-align: left;
  cursor: pointer;
}

.fusion-tab > span {
  font-size: 25px;
}

.fusion-tab div {
  min-width: 0;
  display: grid;
  gap: 3px;
}

.fusion-tab strong,
.fusion-tab small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.fusion-tab strong {
  font-size: 10px;
}

.fusion-tab small {
  color: #8398a7;
  font-size: 8px;
  font-weight: 900;
}

.fusion-tab.selected {
  border-color: rgba(213, 73, 124, 0.48);
  box-shadow: 0 8px 24px rgba(213, 73, 124, 0.12);
}

.fusion-tab.ready {
  background: linear-gradient(135deg, rgba(255, 244, 248, 0.98), rgba(248, 245, 255, 0.98));
}

.fusion-tab.used {
  opacity: 0.55;
}

.fusion-detail-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(220px, 0.65fr);
  gap: 16px;
}

.fusion-detail-main,
.fusion-status-panel {
  display: grid;
  align-content: start;
  gap: 14px;
}

.fusion-result-hero {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border: 1px solid rgba(226, 93, 139, 0.16);
  border-radius: 20px;
  background: linear-gradient(135deg, rgba(255, 248, 251, 0.98), rgba(248, 250, 255, 0.98));
}

.fusion-result-hero img,
.fusion-result-placeholder {
  width: 82px;
  height: 82px;
  flex: 0 0 82px;
  border-radius: 16px;
  object-fit: cover;
  display: grid;
  place-items: center;
  background: rgba(225, 95, 145, 0.08);
  font-size: 34px;
}

.fusion-result-hero > div:last-child > span,
.fusion-section-heading > span,
.fusion-status-panel > span,
.fusion-stat-grid span,
.fusion-rule-summary span {
  color: #8ba0ae;
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.11em;
}

.fusion-stat-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 9px;
}

.fusion-stat-grid > div,
.fusion-rule-summary > div {
  display: grid;
  gap: 4px;
  padding: 12px;
  border: 1px solid rgba(87, 134, 163, 0.14);
  border-radius: 14px;
  background: #fbfdfe;
}

.fusion-stat-grid strong,
.fusion-rule-summary strong {
  color: #314d64;
  font-size: 14px;
}

.fusion-requirements-panel,
.fusion-server-match,
.fusion-status-panel {
  padding: 15px;
  border: 1px solid rgba(87, 134, 163, 0.14);
  border-radius: 18px;
  background: #fbfdfe;
}

.fusion-section-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
}

.fusion-section-heading strong {
  color: #5c7183;
  font-size: 9px;
}

.fusion-requirement-list {
  display: grid;
  gap: 8px;
}

.fusion-requirement-row {
  display: grid;
  grid-template-columns: 30px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 10px;
  border: 1px solid rgba(210, 89, 128, 0.16);
  border-radius: 13px;
  background: rgba(255, 248, 250, 0.65);
}

.fusion-requirement-row.ready {
  border-color: rgba(54, 174, 112, 0.23);
  background: rgba(244, 254, 248, 0.78);
}

.fusion-check {
  width: 26px;
  height: 26px;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: rgba(211, 85, 128, 0.1);
  color: #c4517a;
  font-weight: 1000;
}

.fusion-requirement-row.ready .fusion-check {
  background: rgba(54, 174, 112, 0.12);
  color: #28955f;
}

.fusion-requirement-row div {
  min-width: 0;
  display: grid;
  gap: 2px;
}

.fusion-requirement-row strong {
  color: #334f65;
  font-size: 10px;
}

.fusion-requirement-row small {
  color: #899ba8;
  font-size: 8px;
}

.fusion-requirement-row b {
  color: #556f83;
  font-size: 10px;
}

.fusion-material-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.fusion-material-card {
  display: grid;
  gap: 3px;
  padding: 11px;
  border: 1px solid rgba(87, 134, 163, 0.14);
  border-radius: 13px;
  background: white;
}

.fusion-material-card > span,
.fusion-material-card small {
  color: #8da0ae;
  font-size: 8px;
  font-weight: 900;
}

.fusion-material-card strong {
  color: #324e64;
  font-size: 11px;
}

.fusion-material-card em {
  color: #758b9b;
  font-size: 8px;
  font-style: normal;
}

.fusion-no-match {
  padding: 18px;
  border-radius: 12px;
  color: #8a9ba7;
  background: rgba(238, 244, 247, 0.7);
  text-align: center;
  font-size: 10px;
}

.fusion-readiness {
  padding: 15px;
  border: 1px solid rgba(211, 85, 128, 0.18);
  border-radius: 15px;
  background: rgba(255, 247, 250, 0.8);
}

.fusion-readiness.ready {
  border-color: rgba(53, 172, 111, 0.24);
  background: rgba(244, 254, 248, 0.85);
}

.fusion-readiness strong {
  color: #bd4c74;
  font-size: 15px;
}

.fusion-readiness.ready strong {
  color: #29945f;
}

.fusion-readiness p {
  margin: 7px 0 0;
  color: #788d9d;
  font-size: 10px;
  line-height: 1.5;
}

.fusion-rule-summary {
  display: grid;
  gap: 8px;
}

.fusion-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 9px;
  margin-top: 17px;
}

.fusion-use-button {
  background: linear-gradient(135deg, #df5d8b, #8658c8);
}

/* CONTROL */

.control-console {
  width:
    min(
      calc(
        100% -
        32px
      ),
      1250px
    );

  min-height: 110px;

  position: fixed;

  left: 50%;
  bottom: 18px;

  z-index: 150;

  display: grid;

  grid-template-columns:
    20px
    repeat(
      2,
      minmax(
        0,
        1fr
      )
    )
    minmax(
      120px,
      1.1fr
    )
    repeat(
      5,
      minmax(
        0,
        1fr
      )
    )
    20px;

  align-items: center;

  gap: 10px;

  padding:
    14px
    18px;

  transform:
    translateX(-50%);

  border:
    1px solid
    rgba(
      75,
      128,
      160,
      0.23
    );

  border-radius: 26px;

  background:
    rgba(
      255,
      255,
      255,
      0.88
    );

  backdrop-filter:
    blur(18px);

  box-shadow:
    0
    20px
    60px
    rgba(
      46,
      75,
      95,
      0.18
    );
}

.console-decoration {
  color:
    var(
      --player-accent
    );

  text-align: center;

  font-size: 11px;

  font-weight: 900;
}

.console-skill {
  min-height: 76px;

  display: flex;

  flex-direction:
    column;

  align-items: center;

  justify-content:
    center;

  gap: 3px;

  border:
    1px solid
    rgba(
      87,
      134,
      163,
      0.18
    );

  border-radius: 18px;

  color: #29465e;

  background:
    rgba(
      246,
      251,
      254,
      0.96
    );

  box-shadow:
    0
    6px
    15px
    rgba(
      58,
      95,
      119,
      0.06
    );

  cursor: pointer;

  transition:
    transform
      0.15s ease,
    box-shadow
      0.15s ease,
    background
      0.15s ease;
}

.console-skill:hover:not(:disabled) {
  transform:
    translateY(-3px);

  background:
    #ffffff;

  box-shadow:
    0
    11px
    20px
    rgba(
      47,
      93,
      122,
      0.11
    );
}

.console-icon {
  font-size: 23px;
}

.console-skill strong {
  font-size: 8px;

  font-weight: 900;

  letter-spacing:
    0.07em;
}

.console-skill small {
  color: #7a91a2;

  font-size: 6px;

  font-weight: 800;
}

.attack-skill {
  border-color:
    rgba(
      225,
      93,
      101,
      0.23
    );
}

.defense-skill {
  border-color:
    rgba(
      55,
      139,
      219,
      0.23
    );
}

.ultimate-skill {
  border-color:
    rgba(
      129,
      100,
      228,
      0.23
    );
}

.heal-skill {
  border-color:
    rgba(
      47,
      184,
      113,
      0.23
    );
}

.synergy-skill {
  border-color:
    rgba(
      218,
      170,
      49,
      0.25
    );
}

.console-skill.unavailable,
.console-skill.dimmed,
.console-skill:disabled {
  opacity: 0.38;

  filter:
    grayscale(0.6);

  cursor: not-allowed;

  transform: none;

  box-shadow: none;
}

/* SUMMON */

.summon-core {
  min-height: 92px;

  border: 0;

  border-radius: 24px;

  color: #ffffff;

  background:
    linear-gradient(
      135deg,
      #42b5f4,
      #278ddd
    );

  box-shadow:
    0
    12px
    28px
    rgba(
      42,
      136,
      199,
      0.23
    );

  cursor: pointer;

  transition:
    transform
      0.16s ease,
    box-shadow
      0.16s ease;
}

.summon-core:hover:not(:disabled) {
  transform:
    translateY(-3px)
    scale(1.015);

  box-shadow:
    0
    16px
    34px
    rgba(
      42,
      136,
      199,
      0.3
    );
}

.summon-core.active {
  animation:
    summonPulse
    1.2s
    infinite;
}

.summon-core.unavailable,
.summon-core:disabled {
  opacity: 0.38;

  filter:
    grayscale(0.55);

  cursor: not-allowed;

  box-shadow: none;
}

.summon-core-inner {
  display: flex;

  flex-direction:
    column;

  align-items: center;

  justify-content:
    center;

  gap: 2px;
}

.summon-core-inner span {
  font-size: 26px;
}

.summon-core-inner strong {
  font-size: 10px;

  font-weight: 900;

  letter-spacing:
    0.08em;
}

.summon-core-inner small {
  color:
    rgba(
      255,
      255,
      255,
      0.78
    );

  font-size: 7px;

  font-weight: 800;
}

/* SELECTED */

.selected-card-chip {
  position: fixed;

  right: 22px;
  top: 118px;
  bottom: auto;

  z-index: 145;

  display: flex;

  align-items: center;

  gap: 6px;

  padding:
    8px
    12px;

  border:
    1px solid
    rgba(
      60,
      137,
      185,
      0.22
    );

  border-radius:
    999px;

  color: #658198;

  background:
    rgba(
      255,
      255,
      255,
      0.92
    );

  backdrop-filter:
    blur(10px);

  box-shadow:
    0
    8px
    22px
    rgba(
      55,
      94,
      119,
      0.11
    );

  font-size: 7px;

  font-weight: 800;
}

.selected-card-chip strong {
  color: #17324a;
}

/* TOAST */

.game-toast {
  width:
    min(
      92vw,
      650px
    );

  min-height: 82px;

  position: fixed;

  left: 50%;
  top: 22px;

  z-index: 50000;

  display: flex;

  align-items: center;

  gap: 15px;

  padding:
    16px
    20px;

  overflow: hidden;

  transform:
    translateX(-50%);

  border:
    1px solid
    rgba(
      255,
      255,
      255,
      0.5
    );

  border-radius: 20px;

  background:
    rgba(
      255,
      255,
      255,
      0.94
    );

  backdrop-filter:
    blur(18px);

  box-shadow:
    0
    20px
    55px
    rgba(
      40,
      72,
      94,
      0.18
    );
}

.toast-glow {
  width: 150px;
  height: 150px;

  position: absolute;

  left: -70px;
  top: -35px;

  border-radius: 50%;

  filter:
    blur(45px);

  opacity: 0.2;
}

.game-toast.success {
  color: #175b3b;

  border-color:
    rgba(
      46,
      185,
      111,
      0.32
    );

  background:
    rgba(
      235,
      255,
      244,
      0.96
    );
}

.game-toast.success
.toast-glow {
  background:
    #63dc9a;
}

.game-toast.warning {
  color: #72500d;

  border-color:
    rgba(
      224,
      176,
      52,
      0.36
    );

  background:
    rgba(
      255,
      250,
      228,
      0.97
    );
}

.game-toast.warning
.toast-glow {
  background:
    #f3ca57;
}

.game-toast.error {
  color: #842d42;

  border-color:
    rgba(
      223,
      81,
      111,
      0.35
    );

  background:
    rgba(
      255,
      238,
      242,
      0.97
    );
}

.game-toast.error
.toast-glow {
  background:
    #ef738f;
}

.toast-icon {
  width: 50px;
  height: 50px;

  flex:
    0
    0
    50px;

  position: relative;

  z-index: 2;

  display: grid;

  place-items: center;

  border-radius: 50%;

  background:
    rgba(
      255,
      255,
      255,
      0.7
    );

  font-size: 21px;

  font-weight: 900;
}

.toast-copy {
  position: relative;

  z-index: 2;
}

.toast-copy strong {
  display: block;

  font-size: 15px;

  font-weight: 900;

  letter-spacing:
    0.04em;
}

.toast-copy span {
  display: block;

  margin-top: 4px;

  color:
    currentColor;

  opacity: 0.75;

  font-size: 10px;
}

/* STATE */

.state-screen {
  min-height: 100vh;

  position: relative;

  z-index: 20;

  display: flex;

  flex-direction:
    column;

  align-items: center;

  justify-content:
    center;

  gap: 8px;

  color: #718b9d;
}

.state-screen strong {
  color: #19364e;

  font-size: 14px;
}

.loading-ring {
  width: 40px;
  height: 40px;

  margin-bottom: 10px;

  border:
    3px solid
    rgba(
      68,
      138,
      180,
      0.14
    );

  border-top-color:
    #399fdf;

  border-radius: 50%;

  animation:
    spin
    0.7s
    linear
    infinite;
}

.state-error strong {
  color: #ba405a;
}

/* QUESTION */

.question-overlay,
.winner-overlay {
  position: fixed;

  inset: 0;

  display: grid;

  place-items: center;

  padding: 20px;
}

.question-overlay {
  z-index: 30000;

  pointer-events: auto;
}

.winner-overlay {
  z-index: 40000;
}

.question-backdrop {
  position: absolute;

  inset: 0;

  background:
    rgba(
      70,
      104,
      123,
      0.42
    );

  backdrop-filter:
    blur(9px);
}

.question-card {
  width:
    min(
      100%,
      720px
    );

  max-height:
    calc(
      100vh -
      40px
    );

  position: relative;

  z-index: 2;

  pointer-events: auto;

  overflow-y: auto;

  padding: 26px;

  border:
    1px solid
    rgba(
      80,
      139,
      176,
      0.25
    );

  border-radius: 24px;

  color: #17324a;

  background:
    rgba(
      255,
      255,
      255,
      0.96
    );

  box-shadow:
    0
    28px
    80px
    rgba(
      45,
      72,
      90,
      0.22
    );
}

.question-card h2 {
  margin:
    8px
    0
    20px;

  color: #17324a;
}

.question-text {
  color: #203f56;

  font-size: 17px;

  font-weight: 800;

  line-height: 1.5;
}

.question-code {
  margin-top: 14px;

  padding: 14px;

  overflow-x: auto;

  border:
    1px solid
    rgba(
      78,
      128,
      158,
      0.16
    );

  border-radius: 14px;

  color: #284e68;

  background:
    #f2f8fb;

  font-size: 11px;

  white-space:
    pre-wrap;
}

.question-options {
  display: grid;

  gap: 9px;

  margin-top: 16px;
}

.question-sync-state {
  display: flex;

  align-items: center;

  gap: 10px;

  margin:
    12px
    0;

  padding:
    10px
    12px;

  border:
    1px solid
    rgba(
      53,
      151,
      210,
      0.22
    );

  border-radius: 12px;

  color: #4b7189;

  background:
    rgba(
      235,
      247,
      253,
      0.95
    );
}

.question-sync-state
> span {
  font-size: 22px;

  animation:
    spin
    0.85s
    linear
    infinite;
}

.question-sync-state
div {
  display: flex;

  flex-direction: column;
}

.question-sync-state
strong {
  color: #2a6d96;

  font-size: 7px;

  font-weight: 1000;

  letter-spacing:
    0.06em;
}

.question-sync-state
small {
  margin-top: 2px;

  color: #71899a;

  font-size: 6px;

  font-weight: 750;
}

.question-option {
  min-height: 54px;

  display: flex;

  align-items: center;

  padding:
    8px
    12px;

  border:
    1px solid
    rgba(
      75,
      133,
      168,
      0.18
    );

  border-radius: 14px;

  color: #36566d;

  text-align: left;

  background:
    rgba(
      246,
      251,
      254,
      0.95
    );

  cursor: pointer;

  position: relative;

  z-index: 3;

  pointer-events: auto;

  touch-action: manipulation;

  transition:
    border-color
      0.15s ease,
    background
      0.15s ease;
}

.question-option:hover:not(:disabled) {
  border-color:
    rgba(
      48,
      151,
      214,
      0.38
    );

  background: #ffffff;
}

.question-option
> span {
  width: 32px;
  height: 32px;

  flex:
    0
    0
    32px;

  display: grid;

  place-items: center;

  margin-right: 10px;

  border-radius: 9px;

  color: #2b8bc7;

  background:
    rgba(
      49,
      154,
      216,
      0.09
    );

  font-weight: 900;
}

.question-option.selected {
  border-color:
    rgba(
      47,
      150,
      212,
      0.48
    );
}

.question-option.correct {
  color: #21663f;

  border-color:
    rgba(
      49,
      181,
      104,
      0.35
    );

  background:
    rgba(
      232,
      251,
      240,
      0.94
    );
}

.question-option.wrong {
  color: #993d51;

  border-color:
    rgba(
      216,
      71,
      102,
      0.34
    );

  background:
    rgba(
      255,
      239,
      242,
      0.96
    );
}

.question-state {
  padding:
    50px
    0;

  color: #6a869a;

  text-align: center;
}

/* WINNER */

.winner-overlay {
  background:
    rgba(
      80,
      110,
      126,
      0.4
    );

  backdrop-filter:
    blur(10px);
}

.winner-card {
  width:
    min(
      90vw,
      460px
    );

  padding: 42px;

  border:
    1px solid
    rgba(
      57,
      146,
      203,
      0.25
    );

  border-radius: 26px;

  color: #17324a;

  text-align: center;

  background:
    rgba(
      255,
      255,
      255,
      0.97
    );

  box-shadow:
    0
    30px
    90px
    rgba(
      43,
      73,
      91,
      0.22
    );
}

.winner-card
> span {
  color:
    var(
      --player-accent
    );

  font-size: 8px;

  font-weight: 900;

  letter-spacing:
    0.1em;
}

.winner-card h1 {
  margin:
    8px
    0;

  color: #17324a;

  font-size: 35px;
}

/* BONUS */

.bonus-panel {
  width:
    min(
      100%,
      1450px
    );

  position: relative;

  z-index: 12;

  margin:
    18px
    auto
    130px;

  padding:
    18px
    22px;

  border:
    1px solid
    rgba(
      80,
      145,
      185,
      0.22
    );

  border-radius: 22px;

  background:
    rgba(
      255,
      255,
      255,
      0.82
    );

  backdrop-filter:
    blur(16px);

  box-shadow:
    0
    16px
    38px
    rgba(
      48,
      87,
      112,
      0.1
    );
}

.bonus-panel
.panel-heading {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  margin-bottom: 14px;
}

.bonus-panel
.panel-heading
.eyebrow {
  display: block;

  margin-bottom: 3px;

  color:
    var(
      --player-accent
    );

  font-size: 10px;

  font-weight: 900;

  letter-spacing:
    1.4px;
}

.bonus-panel
.panel-heading
h2 {
  margin: 0;

  color: #17324a;

  font-size: 18px;

  font-weight: 900;
}

.bonus-description {
  display: block;

  margin-top: 4px;

  color: #6d8292;

  font-size: 6px;

  font-style: normal;

  font-weight: 750;

  line-height: 1.35;
}

.bonus-list {
  display: grid;

  grid-template-columns:
    repeat(
      auto-fit,
      minmax(
        210px,
        1fr
      )
    );

  gap: 12px;
}

.bonus-item {
  min-height: 82px;

  display: flex;

  align-items: center;

  gap: 14px;

  padding:
    14px
    16px;

  border:
    1px solid
    rgba(
      60,
      145,
      200,
      0.22
    );

  border-radius: 16px;

  background:
    linear-gradient(
      135deg,
      rgba(
        255,
        255,
        255,
        0.96
      ),
      rgba(
        235,
        248,
        255,
        0.92
      )
    );

  color: #17324a;

  text-align: left;

  box-shadow:
    0
    8px
    20px
    rgba(
      45,
      110,
      150,
      0.08
    );
}

.bonus-item-icon {
  width: 48px;
  height: 48px;

  flex:
    0
    0
    48px;

  display: grid;

  place-items: center;

  border-radius: 14px;

  background:
    linear-gradient(
      135deg,
      rgba(
        65,
        170,
        235,
        0.14
      ),
      rgba(
        110,
        210,
        250,
        0.22
      )
    );

  font-size: 25px;

  box-shadow:
    inset
    0
    0
    0
    1px
    rgba(
      60,
      145,
      205,
      0.12
    );
}

.bonus-item
> div {
  min-width: 0;

  display: flex;

  flex-direction:
    column;

  gap: 4px;
}

.bonus-item strong {
  color: #17324a;

  font-size: 14px;

  font-weight: 900;
}

.bonus-item small {
  color: #5c7c92;

  font-size: 9px;

  font-weight: 800;
}

.bonus-button {
  width: 100%;

  appearance: none;

  cursor: pointer;

  transition:
    transform
      0.16s ease,
    box-shadow
      0.16s ease,
    border-color
      0.16s ease;
}

.bonus-button.ready {
  border-color:
    rgba(
      40,
      160,
      225,
      0.32
    );
}

.bonus-button.ready:hover {
  transform:
    translateY(-3px);

  border-color:
    var(
      --player-accent
    );

  box-shadow:
    0
    14px
    28px
    rgba(
      35,
      125,
      175,
      0.16
    );
}

.bonus-button.used {
  opacity: 0.42;

  cursor: not-allowed;

  filter:
    grayscale(0.65);
}

.bonus-button:disabled {
  cursor: not-allowed;
}

.player-battle-ui.p2
.bonus-item-icon {
  background:
    linear-gradient(
      135deg,
      rgba(
        237,
        86,
        124,
        0.12
      ),
      rgba(
        255,
        150,
        180,
        0.22
      )
    );
}

/* COMBAT STATS */

.card-combat-stats {
  display: grid !important;

  grid-template-columns:
    1fr
    1fr;

  gap: 8px;

  align-items: end;
}

.card-combat-stats
> div {
  display: flex;

  flex-direction:
    column;

  gap: 2px;
}

.card-combat-stats
> div:last-child {
  text-align: right;
}

.card-combat-stats span {
  font-size: 8px !important;

  font-weight: 900;

  opacity: .7;
}

.card-combat-stats strong {
  font-size: 20px !important;

  line-height: 1;
}

/* TRANSITIONS */

.toast-enter-active,
.toast-leave-active,
.rfid-panel-enter-active,
.rfid-panel-leave-active,
.question-enter-active,
.question-leave-active {
  transition:
    opacity
      0.22s ease,
    transform
      0.22s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;

  transform:
    translateX(-50%)
    translateY(-35px);
}

.rfid-panel-enter-from,
.rfid-panel-leave-to {
  opacity: 0;

  transform:
    translateY(-8px);
}

/* ANIMATION */

@keyframes spin {
  to {
    transform:
      rotate(360deg);
  }
}

@keyframes scanPulse {
  0%,
  100% {
    box-shadow:
      0
      0
      0
      0
      rgba(
        53,
        162,
        222,
        0.25
      );
  }

  50% {
    box-shadow:
      0
      0
      0
      14px
      rgba(
        53,
        162,
        222,
        0
      );
  }
}

@keyframes summonPulse {
  0%,
  100% {
    box-shadow:
      0
      12px
      28px
      rgba(
        42,
        136,
        199,
        0.22
      );
  }

  50% {
    box-shadow:
      0
      16px
      38px
      rgba(
        42,
        136,
        199,
        0.38
      );
  }
}

/* RESPONSIVE */

@media (
  max-width: 1180px
) {
  .battle-stage {
    grid-template-columns:
      125px
      minmax(
        0,
        1fr
      )
      125px;

    gap: 12px;
  }
}

@media (
  max-width: 1150px
) {
  .player-battle-ui {
    padding:
      14px
      14px
      430px;
  }

  .top-hud {
    grid-template-columns:
      1fr
      1fr;

    gap: 14px;
  }

  .deck-slots {
    grid-template-columns:
      repeat(
        4,
        minmax(
          120px,
          1fr
        )
      );

    gap: 12px;
  }

  .cyber-card-image {
    height: 145px;
  }

  .control-console {
    bottom: 10px;

    grid-template-columns:
      repeat(
        3,
        minmax(
          0,
          1fr
        )
      );

    width:
      min(
        calc(
          100% -
          20px
        ),
        800px
      );

    min-height: auto;

    padding: 12px;
  }

  .console-decoration {
    display: none;
  }

  .summon-core {
    min-height: 76px;

    border-radius: 18px;
  }

  .selected-card-chip {
    top: 108px;
    bottom: auto;
  }

  .skill-info-panel {
    bottom: 188px;

    width:
      min(
        calc(
          100% -
          20px
        ),
        800px
      );
  }

  .skill-info-grid {
    grid-template-columns:
      repeat(
        3,
        minmax(
          0,
          1fr
        )
      );
  }
}

@media (
  max-width: 900px
) {
  .battle-stage {
    grid-template-columns:
      1fr
      1fr;
  }

  .active-panel {
    grid-column:
      1 / -1;

    grid-row: 1;
  }

  .bench-side-zone {
    grid-column: 1;

    grid-row: 2;

    justify-self:
      start;
  }

  .graveyard-side-zone {
    grid-column: 2;

    grid-row: 2;

    justify-self:
      end;
  }

  .side-zone {
    position: relative;

    top: auto;
  }

  .top-hud {
    grid-template-columns:
      1fr
      1fr;
  }

  .deck-mini-status {
    border-left: 0;

    border-right: 0;
  }

  .target-picker-overlay {
    padding: 10px;
  }

  .target-picker-panel {
    max-height:
      calc(
        100dvh -
        20px
      );

    padding: 17px;
  }

  .target-card-grid {
    grid-template-columns:
      repeat(
        2,
        minmax(
          0,
          1fr
        )
      );
  }

  .target-card-image {
    height: 150px;
  }

  .target-picker-attacker {
    align-items:
      flex-start;

    flex-direction:
      column;
  }

  .target-picker-actions {
    display: grid;

    grid-template-columns:
      1fr
      1fr;
  }

  .target-cancel-button,
  .target-confirm-button {
    min-width: 0;
  }
}

@media (
  max-width: 760px
) {
  .player-battle-ui {
    padding:
      10px
      10px
      500px;
  }

  .top-hud {
    display: flex;

    flex-direction:
      column;

    align-items:
      stretch;

    padding: 16px;

    border-radius: 20px;
  }

  .player-identity {
    justify-content:
      center;
  }

  .combat-stats,
  .enemy-mini-status {
    border-left: 0;
  }

  .turn-core {
    min-height: 68px;
  }

  .notification-panel {
    grid-template-columns:
      auto
      1fr;
  }

  .notification-counter,
  .scan-indicator {
    grid-column:
      1 / -1;

    text-align: center;
  }

  .cyber-panel {
    padding:
      17px
      14px;

    border-radius: 20px;
  }

  .deck-slots {
    grid-template-columns:
      repeat(
        2,
        minmax(
          0,
          1fr
        )
      );

    gap: 10px;
  }

  .cyber-card {
    min-height: 265px;
  }

  .cyber-card-image {
    height: 125px;
  }

  .empty-card {
    min-height: 230px;
  }

  .control-console {
    width:
      calc(
        100% -
        16px
      );

    bottom: 8px;

    grid-template-columns:
      repeat(
        2,
        minmax(
          0,
          1fr
        )
      );

    gap: 8px;

    padding: 10px;

    border-radius: 20px;
  }

  .console-skill {
    min-height: 65px;

    border-radius: 14px;
  }

  .summon-core {
    grid-column:
      1 / -1;

    min-height: 70px;

    border-radius: 16px;
  }

  .selected-card-chip {
    right: 12px;

    top: 102px;
    bottom: auto;
  }

  .skill-info-panel {
    width:
      calc(
        100% -
        16px
      );

    bottom: 312px;

    padding:
      8px;

    border-radius: 16px;
  }

  .skill-info-header {
    align-items:
      flex-start;

    flex-direction:
      column;

    gap: 5px;
  }

  .player-status-summary {
    justify-content:
      flex-start;
  }

  .skill-info-grid {
    display: grid;

    grid-auto-flow:
      column;

    grid-template-columns:
      none;

    grid-auto-columns:
      220px;

    overflow-x: auto;

    gap: 7px;

    padding-bottom: 3px;

    overscroll-behavior-x:
      contain;

    scroll-snap-type:
      x proximity;
  }

  .skill-info-card {
    min-height: 104px;

    scroll-snap-align:
      start;
  }

  .game-toast {
    width:
      calc(
        100vw -
        20px
      );

    top: 10px;

    min-height: 70px;

    padding:
      13px
      15px;
  }

  .bonus-panel {
    margin:
      14px
      auto
      150px;

    padding: 14px;

    border-radius: 18px;
  }

  .bonus-list {
    grid-template-columns:
      1fr;
  }

  .bonus-item {
    min-height: 74px;

    padding: 12px;
  }

  .bonus-item-icon {
    width: 42px;
    height: 42px;

    flex-basis:
      42px;

    font-size: 22px;
  }
}

@media (
  max-width: 620px
) {
  .battle-stage {
    grid-template-columns:
      1fr
      1fr;

    gap: 10px;
  }

  .deck-remaining-chip {
    display: none;
  }

  .active-header-meta {
    margin-left: auto;
  }
}

@media (
  max-width: 480px
) {
  .deck-slots {
    grid-template-columns:
      1fr
      1fr;
  }

  .cyber-card {
    min-height: 245px;
  }

  .cyber-card-image {
    height: 105px;
  }

  .cyber-card-inner
  header
  strong {
    font-size: 10px;
  }

  .player-avatar {
    width: 62px;
    height: 62px;

    flex-basis: 62px;
  }

  .identity-copy strong {
    font-size: 21px;
  }
}


@media (max-width: 1150px) {
  .action-info-button-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .skill-ready-balloons {
    bottom: 260px;
    max-width: calc(100vw - 24px);
    overflow-x: auto;
  }

  .skill-ready-balloons.expanded {
    bottom: 330px;
  }
}

@media (max-width: 760px) {
  .action-info-header-actions {
    width: 100%;
    justify-content: space-between;
  }

  .action-info-toggle {
    margin-left: auto;
  }

  .action-info-button-grid {
    display: grid;
    grid-auto-flow: column;
    grid-template-columns: none;
    grid-auto-columns: 180px;
    overflow-x: auto;
  }

  .skill-ready-balloons {
    width: calc(100% - 20px);
    bottom: 402px;
    justify-content: flex-start;
    overflow-x: auto;
  }

  .skill-ready-balloons.expanded {
    bottom: 470px;
  }

  .ready-balloon {
    flex: 0 0 auto;
  }

  .action-detail-overlay {
    padding: 10px;
  }

  .action-detail-modal,
  .special-skill-modal,
  .fusion-modal {
    width: 100%;
    max-height: calc(100dvh - 20px);
    padding: 16px;
    border-radius: 18px;
  }

  .special-detail-layout,
  .fusion-detail-layout {
    grid-template-columns: 1fr;
  }

  .fusion-stat-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .fusion-material-grid {
    grid-template-columns: 1fr;
  }

  .special-target-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .special-modal-actions,
  .fusion-modal-actions {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .special-modal-actions .modal-primary,
  .fusion-modal-actions .modal-primary {
    margin-top: 0;
  }
}



/* =========================================================
   ACTION INFORMATION - COLLAPSED HANDLE
   Saat collapse, panel besar benar-benar hilang dan hanya
   menyisakan tombol kecil di tengah di atas action console.
========================================================= */

.skill-info-panel.is-collapsed {
  width: auto !important;
  min-width: 0 !important;
  min-height: 0 !important;
  height: 24px !important;
  padding: 0 !important;
  border: 0 !important;
  border-radius: 999px !important;
  background: transparent !important;
  backdrop-filter: none !important;
  box-shadow: none !important;
  overflow: visible !important;
}

.action-info-collapsed-toggle {
  width: 62px;
  height: 24px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  border: 1px solid rgba(63, 137, 181, 0.22);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.96);
  color: var(--player-accent);
  box-shadow: 0 6px 18px rgba(35, 88, 120, 0.13);
  cursor: pointer;
  transition:
    width 0.16s ease,
    transform 0.16s ease,
    border-color 0.16s ease,
    box-shadow 0.16s ease;
}

.action-info-collapsed-toggle:hover {
  width: 70px;
  transform: translateY(-2px);
  border-color: rgba(63, 137, 181, 0.45);
  box-shadow: 0 8px 22px rgba(35, 88, 120, 0.18);
}

.action-info-handle-line {
  width: 24px;
  height: 3px;
  border-radius: 999px;
  background: currentColor;
  opacity: 0.8;
}

.action-info-handle-arrow {
  margin-top: 2px;
  font-size: 10px;
  line-height: 1;
  font-weight: 1000;
}

@media (max-width: 900px) {
  .skill-info-panel.is-collapsed {
    width: auto !important;
    padding: 0 !important;
    border-radius: 999px !important;
  }

  .action-info-collapsed-toggle {
    width: 54px;
    height: 22px;
  }
}



/* PHASE 3D.7 - Fusion loader diagnostics */
.fusion-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.fusion-empty-state > span {
  max-width: 760px;
  text-align: center;
  opacity: 0.8;
}

.fusion-empty-error strong {
  color: #b42318;
}

.fusion-retry-btn {
  margin-top: 4px;
  border: 1px solid rgba(14, 165, 233, 0.28);
  border-radius: 999px;
  padding: 9px 18px;
  background: rgba(255, 255, 255, 0.9);
  color: #0369a1;
  font-weight: 900;
  font-size: 11px;
  letter-spacing: 0.08em;
  cursor: pointer;
}

.fusion-retry-btn:hover {
  transform: translateY(-1px);
}

/* =========================================================
   PHASE 3D.13 — FUSION BATTLE HISTORY
========================================================= */

.fusion-history-fab {
  position: fixed;
  z-index: 170;
  right: 24px;
  bottom: 112px;

  display: inline-flex;
  align-items: center;
  gap: 8px;

  padding: 9px 12px;

  border:
    1px solid
    rgba(126, 87, 194, 0.20);

  border-radius:
    999px;

  background:
    rgba(255, 255, 255, 0.92);

  box-shadow:
    0 12px 30px
    rgba(45, 73, 94, 0.14);

  color:
    #36556a;

  font-size: 9px;
  font-weight: 950;
  letter-spacing: 0.05em;

  cursor: pointer;

  backdrop-filter:
    blur(14px);
}

.fusion-history-fab > span {
  font-size: 14px;
}

.fusion-history-fab > b {
  min-width: 20px;
  height: 20px;

  display: inline-grid;
  place-items: center;

  border-radius:
    999px;

  background:
    rgba(126, 87, 194, 0.10);

  color:
    #7552bd;
}

.fusion-history-overlay {
  position: fixed;
  z-index: 920;
  inset: 0;

  display: grid;
  place-items: center;

  padding: 26px;
}

.fusion-history-backdrop {
  position: absolute;
  inset: 0;

  background:
    rgba(35, 52, 66, 0.28);

  backdrop-filter:
    blur(12px);
}

.fusion-history-modal {
  width:
    min(920px, 94vw);

  max-height:
    min(760px, 88vh);

  position: relative;
  z-index: 1;

  display: flex;
  flex-direction: column;

  overflow: hidden;

  border:
    1px solid
    rgba(126, 87, 194, 0.16);

  border-radius:
    24px;

  background:
    rgba(255, 255, 255, 0.97);

  box-shadow:
    0 30px 80px
    rgba(39, 59, 74, 0.24);
}

.fusion-history-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;

  padding:
    22px 24px 18px;

  border-bottom:
    1px solid
    rgba(79, 111, 131, 0.10);
}

.fusion-history-header span {
  color:
    #8870c8;

  font-size:
    8px;

  font-weight:
    950;

  letter-spacing:
    0.12em;
}

.fusion-history-header h2 {
  margin:
    4px 0 4px;

  color:
    #29495f;

  font-size:
    24px;
}

.fusion-history-header p {
  margin: 0;

  max-width:
    620px;

  color:
    #7890a0;

  font-size:
    11px;

  line-height:
    1.55;
}

.fusion-history-header > button {
  width: 36px;
  height: 36px;

  flex: 0 0 auto;

  border:
    1px solid
    rgba(90, 119, 138, 0.15);

  border-radius:
    12px;

  background:
    #f5fafc;

  color:
    #607d90;

  cursor: pointer;
}

.fusion-history-state {
  min-height: 230px;

  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;

  padding: 30px;

  color:
    #7890a0;

  text-align: center;
}

.fusion-history-state.error {
  color:
    #b44f72;
}

.fusion-history-state button {
  margin-top: 8px;

  padding:
    8px 12px;

  border: 0;
  border-radius:
    10px;

  background:
    #7552bd;

  color:
    #ffffff;

  font-size:
    9px;
  font-weight:
    900;

  cursor: pointer;
}

.fusion-history-list {
  overflow: auto;

  display: grid;
  gap: 12px;

  padding:
    18px 22px 24px;
}

.fusion-history-item {
  display: grid;
  grid-template-columns:
    46px
    minmax(0, 1fr);
  gap: 14px;

  padding: 14px;

  border:
    1px solid
    rgba(72, 108, 130, 0.10);

  border-radius:
    18px;

  background:
    linear-gradient(
      135deg,
      rgba(249, 253, 255, 0.98),
      rgba(247, 243, 255, 0.96)
    );
}

.fusion-history-marker {
  width: 42px;
  height: 42px;

  display: grid;
  place-items: center;

  border-radius:
    14px;

  background:
    rgba(126, 87, 194, 0.10);

  font-size:
    20px;
}

.fusion-history-meta {
  display: flex;
  align-items: center;
  gap: 8px;

  margin-bottom: 3px;

  font-size:
    7px;

  font-weight:
    950;

  letter-spacing:
    0.07em;
}

.fusion-history-meta > span {
  padding:
    3px 6px;

  border-radius:
    999px;
}

.fusion-history-meta > span.p1 {
  color:
    #0a8cc4;

  background:
    rgba(12, 166, 222, 0.10);
}

.fusion-history-meta > span.p2 {
  color:
    #d94c70;

  background:
    rgba(231, 79, 117, 0.10);
}

.fusion-history-meta > b {
  color:
    #7552bd;
}

.fusion-history-meta > time {
  margin-left: auto;

  color:
    #9aadba;
}

.fusion-history-body h3 {
  margin:
    0 0 10px;

  color:
    #29495f;

  font-size:
    15px;
}

.fusion-history-combo {
  display: grid;
  grid-template-columns:
    minmax(0, 1fr)
    auto
    minmax(210px, 0.9fr);

  align-items: center;
  gap: 10px;
}

.fusion-history-materials {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}

.fusion-history-material {
  display: inline-flex;
  flex-direction: column;
  gap: 2px;

  min-width: 110px;

  padding:
    8px 9px;

  border:
    1px solid
    rgba(75, 113, 136, 0.10);

  border-radius:
    10px;

  background:
    rgba(255, 255, 255, 0.84);
}

.fusion-history-material small,
.fusion-history-result small {
  color:
    #8ba0ae;

  font-size:
    6px;

  font-weight:
    950;

  letter-spacing:
    0.08em;
}

.fusion-history-material strong {
  color:
    #47677a;

  font-size:
    9px;
}

.fusion-history-arrow {
  color:
    #9c82d3;

  font-size:
    20px;

  font-weight:
    950;
}

.fusion-history-result {
  display: flex;
  align-items: center;
  gap: 9px;

  padding:
    9px;

  border:
    1px solid
    rgba(126, 87, 194, 0.14);

  border-radius:
    12px;

  background:
    rgba(126, 87, 194, 0.06);
}

.fusion-history-result img {
  width: 42px;
  height: 52px;

  flex: 0 0 auto;

  object-fit: cover;

  border-radius:
    8px;
}

.fusion-history-result > div {
  min-width: 0;

  display: flex;
  flex-direction: column;
  gap: 2px;
}

.fusion-history-result strong {
  overflow: hidden;

  color:
    #3c5570;

  font-size:
    11px;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;
}

.fusion-history-result span {
  color:
    #758d9c;

  font-size:
    7px;

  font-weight:
    800;
}

@media (max-width: 760px) {
  .fusion-history-fab {
    right: 12px;
    bottom: 100px;
  }

  .fusion-history-overlay {
    padding: 10px;
  }

  .fusion-history-combo {
    grid-template-columns:
      1fr;
  }

  .fusion-history-arrow {
    transform:
      rotate(90deg);

    justify-self:
      center;
  }
}

</style>