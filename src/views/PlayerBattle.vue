<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from "vue";

import { useRoute } from "vue-router";

import { supabase } from "../lib/supabase";

import { useBattleSession } from "../composables/battle/useBattleSession";

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
// QUESTION
// =========================================================

const selectedQuestionAnswer = ref(null);

const bonusUsingId = ref(null);

const questionSubmitting = ref(false);

const questionResult = ref(null);

const questionReward = ref(null);

// =========================================================
// BONUS SKILL
// =========================================================

const bonusSkills = ref([]);

let bonusChannel = null;

// =========================================================
// PLAYER NAMES
// =========================================================

const playerName = computed(() => {
  if (!battle.value) {
    return player.value === "p1" ? "Player 1" : "Player 2";
  }

  return player.value === "p1"
    ? (battle.value.player1_name ?? "Player 1")
    : (battle.value.player2_name ?? "Player 2");
});

const enemyName = computed(() => {
  if (!battle.value) {
    return player.value === "p1" ? "Player 2" : "Player 1";
  }

  return player.value === "p1"
    ? (battle.value.player2_name ?? "Player 2")
    : (battle.value.player1_name ?? "Player 1");
});

// =========================================================
// CARDS
// =========================================================

const activeCards = computed(() =>
  player.value === "p1" ? player1Active.value : player2Active.value,
);

const benchCards = computed(() =>
  player.value === "p1" ? player1Bench.value : player2Bench.value,
);

// =========================================================
// INITIAL BATTLE STATE
// =========================================================

const battleWaiting = computed(
  () => battle.value?.status === "waiting" || battle.value?.status === "ready",
);

const initialCardsRequired = computed(() =>
  Math.max(
    1,

    Number(battle.value?.initial_cards_required ?? 1),
  ),
);

const initialCardCount = computed(
  () => activeCards.value.length + benchCards.value.length,
);

const initialReady = computed(
  () => initialCardCount.value >= initialCardsRequired.value,
);

// =========================================================
// HP
// =========================================================

const ownHp = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player1_hp
        : battle.value?.player2_hp,
    ) || 0,
);

const ownMaxHp = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player1_max_hp
        : battle.value?.player2_max_hp,
    ) || 200,
);

const enemyHp = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player2_hp
        : battle.value?.player1_hp,
    ) || 0,
);

const enemyMaxHp = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player2_max_hp
        : battle.value?.player1_max_hp,
    ) || 200,
);

const ownHpPercent = computed(() =>
  Math.max(
    0,

    Math.min(
      100,

      (ownHp.value / Math.max(1, ownMaxHp.value)) * 100,
    ),
  ),
);

const enemyHpPercent = computed(() =>
  Math.max(
    0,

    Math.min(
      100,

      (enemyHp.value / Math.max(1, enemyMaxHp.value)) * 100,
    ),
  ),
);

// =========================================================
// SKILL
// =========================================================

const ownSkill = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player1_skill
        : battle.value?.player2_skill,
    ) || 0,
);

// =========================================================
// EFFECT
// =========================================================

const ownDefending = computed(() =>
  Boolean(
    player.value === "p1"
      ? battle.value?.player1_defending
      : battle.value?.player2_defending,
  ),
);

const ownShield = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player1_synergy_shield
        : battle.value?.player2_synergy_shield,
    ) || 0,
);

const ownDebuff = computed(
  () =>
    Number(
      player.value === "p1"
        ? battle.value?.player1_attack_debuff
        : battle.value?.player2_attack_debuff,
    ) || 0,
);

// =========================================================
// FINISHED
// =========================================================

const battleFinished = computed(
  () => Boolean(battle.value?.winner) || battle.value?.status === "finished",
);

const didWin = computed(() => battle.value?.winner === player.value);

// =========================================================
// SUMMON / RFID
// =========================================================

const waitingForRfid = computed(
  () =>
    battle.value?.pending_action === "summon" &&
    battle.value?.pending_action_player === player.value,
);

const enemyWaitingForRfid = computed(
  () =>
    battle.value?.pending_action === "summon" &&
    battle.value?.pending_action_player &&
    battle.value?.pending_action_player !== player.value,
);

// =========================================================
// TURN
// =========================================================

const isMyTurn = computed(() => {
  if (!battle.value) {
    return false;
  }

  return (
    battle.value.status === "battle" &&
    battle.value.current_turn === player.value &&
    !questionActive.value &&
    !battleFinished.value
  );
});

// =========================================================
// TURN TEXT
// =========================================================

const turnText = computed(() => {
  if (battleFinished.value) {
    return didWin.value ? "YOU WIN" : "BATTLE FINISHED";
  }

  if (battleWaiting.value) {
    return initialReady.value ? "WAITING OPPONENT" : "SCAN INITIAL CARD";
  }

  if (questionActive.value) {
    return "CODING CHALLENGE";
  }

  if (waitingForRfid.value) {
    return "SCAN RFID NOW";
  }

  if (enemyWaitingForRfid.value) {
    return "OPPONENT SUMMONING";
  }

  if (isMyTurn.value) {
    return "YOUR TURN";
  }

  return `${enemyName.value.toUpperCase()} TURN`;
});

// =========================================================
// SELECTED CARD
// =========================================================

const selectedCard = computed(
  () =>
    activeCards.value.find(
      (card) => (card.battleId ?? card.id) === selectedCardId.value,
    ) ?? null,
);

// =========================================================
// UI ONLY - SKILL AVAILABILITY
// =========================================================

const canUltimateUi = computed(() => ownSkill.value >= 100);

const canHealUi = computed(
  () => ownHp.value > 0 && ownHp.value <= ownMaxHp.value * 0.5,
);

const selectedElementCount = computed(() => {
  const element = selectedCard.value?.element;

  if (!element) {
    return 0;
  }

  return activeCards.value.filter(
    (card) =>
      String(card.element ?? "").toLowerCase() ===
        String(element).toLowerCase() && !card.exhausted,
  ).length;
});

const canSynergyUi = computed(() =>
  Boolean(selectedCard.value && selectedElementCount.value >= 2),
);

const canSummonUi = computed(() => activeCards.value.length < maxActive.value);

const skillLockText = (type) => {
  if (type === "ultimate" && !canUltimateUi.value) {
    return `${ownSkill.value}%`;
  }

  if (type === "heal" && !canHealUi.value) {
    return "HP > 50%";
  }

  if (type === "synergy" && !canSynergyUi.value) {
    return "LOCKED";
  }

  if (type === "summon" && !canSummonUi.value) {
    return "FULL";
  }

  return "";
};

// =========================================================
// CARD SELECTION
// =========================================================

const selectCard = (card) => {
  if (battleWaiting.value) {
    warningToast(
      "BATTLE BELUM DIMULAI",
      "Tunggu sampai kedua player selesai melakukan initial scan.",
    );

    return;
  }

  if (questionActive.value) {
    warningToast(
      "QUESTION IN PROGRESS",
      "Selesaikan Coding Challenge terlebih dahulu.",
    );

    return;
  }

  if (!isMyTurn.value) {
    warningToast("BUKAN TURN KAMU", `Sekarang giliran ${enemyName.value}.`);

    return;
  }

  if (waitingForRfid.value) {
    warningToast("SUMMON MODE ACTIVE", "Scan RFID Card terlebih dahulu.");

    return;
  }

  if (card.exhausted) {
    warningToast("CARD EXHAUSTED", "Card ini tidak dapat digunakan.");

    return;
  }

  selectedCardId.value = card.battleId ?? card.id;

  successToast("CARD SELECTED", card.name);
};

// =========================================================
// VALIDATE TURN BEFORE ACTION
// =========================================================

const validateActionTurn = () => {
  if (battleWaiting.value) {
    warningToast(
      "BATTLE BELUM DIMULAI",
      "Lakukan Initial Scan terlebih dahulu.",
    );

    return false;
  }

  if (questionActive.value) {
    warningToast("CODING CHALLENGE ACTIVE", "Jawab question terlebih dahulu.");

    return false;
  }

  if (!isMyTurn.value) {
    warningToast("BUKAN TURN KAMU", `Sekarang giliran ${enemyName.value}.`);

    return false;
  }

  if (waitingForRfid.value) {
    warningToast("SCAN RFID DULU", "Summon sedang aktif. Tempelkan RFID Card.");

    return false;
  }

  return true;
};

// =========================================================
// SUBMIT ACTION
// =========================================================

const submitAction = async (actionType) => {
  actionError.value = "";

  actionMessage.value = "";

  if (!battle.value) {
    return;
  }

  if (!token.value) {
    errorToast("TOKEN TIDAK VALID", "Player token tidak ditemukan.");

    return;
  }

  /*
   * SUMMON boleh dicek dengan rule turn yang sama.
   */

  if (!validateActionTurn()) {
    return;
  }

  const cardRequired = actionType !== "summon";

  if (cardRequired && !selectedCard.value) {
    warningToast("PILIH CARD", "Pilih Active Card terlebih dahulu.");

    return;
  }

  if (actionType === "ultimate" && ownSkill.value < 100) {
    warningToast(
      "ULTIMATE BELUM READY",
      `Gauge kamu masih ${ownSkill.value}%.`,
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

        p_action: actionType,

        p_card_id: cardRequired ? (selectedCard.value?.id ?? null) : null,

        p_payload: {},
      },
    );

    if (rpcError) {
      throw rpcError;
    }

    if (data?.ok === false) {
      const message = data?.message ?? "Action ditolak.";

      /*
       * Wrong turn dari server.
       */

      if (
        message.toLowerCase().includes("giliran") ||
        message.toLowerCase().includes("turn")
      ) {
        warningToast("BUKAN TURN KAMU", message);
      } else {
        warningToast("ACTION DITOLAK", message);
      }

      return;
    }

    // =====================================================
    // SUMMON
    // =====================================================

    if (actionType === "summon" && data?.waiting_rfid) {
      selectedCardId.value = null;

      successToast(
        "SUMMON MODE ACTIVE",
        `Scan card menggunakan ${
          player.value === "p1" ? "RC522-P1" : "RC522-P2"
        }.`,
      );

      return;
    }

    selectedCardId.value = null;

    successToast(
      `${actionType.toUpperCase()} SUCCESS`,
      data?.message ?? "Action berhasil diproses.",
    );
  } catch (err) {
    console.error("Submit action:", err);

    errorToast("ACTION ERROR", err?.message ?? "Gagal memproses action.");
  } finally {
    actionLoading.value = false;
  }
};

// =========================================================
// BENCH ACTION
// =========================================================

const sendBenchAction = async (actionType, card) => {
  if (!validateActionTurn()) {
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

        p_action: actionType,

        p_card_id: card.id,

        p_payload: {},
      },
    );

    if (rpcError) {
      throw rpcError;
    }

    if (data?.ok === false) {
      warningToast(
        "BENCH ACTION DITOLAK",
        data?.message ?? "Action tidak dapat dilakukan.",
      );

      return;
    }

    successToast(
      "BENCH UPDATED",
      data?.message ?? "Card berhasil dipindahkan.",
    );
  } catch (err) {
    errorToast("BENCH ERROR", err?.message ?? "Gagal memproses Bench.");
  } finally {
    actionLoading.value = false;
  }
};

// =========================================================
// QUESTION
// =========================================================

// =========================================================
// QUESTION ANSWER
// =========================================================

const answerQuestion = async (index) => {
  // =====================================================
  // PREVENT DOUBLE SUBMIT
  // =====================================================

  if (questionSubmitting.value || questionResult.value) {
    return;
  }

  // =====================================================
  // GET QUESTION ROUND ID
  //
  // Primary:
  // currentQuestionRound.id
  //
  // Fallback:
  // battle.current_question_round_id
  // =====================================================

  const questionRoundId =
    currentQuestionRound.value?.id ??
    battle.value?.current_question_round_id ??
    null;

  console.log("ANSWER QUESTION", {
    index,
    questionRoundId,
    currentQuestionRound: currentQuestionRound.value,
    battleQuestionRoundId: battle.value?.current_question_round_id,
  });

  // =====================================================
  // QUESTION ROUND MISSING
  // =====================================================

  if (!questionRoundId) {
    errorToast("QUESTION ERROR", "Question Round ID belum tersedia.");

    console.error("Question round ID missing", {
      battle: battle.value,

      currentQuestionRound: currentQuestionRound.value,
    });

    return;
  }

  // =====================================================
  // TOKEN
  // =====================================================

  if (!token.value) {
    errorToast("TOKEN TIDAK VALID", "Player token tidak ditemukan.");

    return;
  }

  // =====================================================
  // SELECT ANSWER
  // =====================================================

  selectedQuestionAnswer.value = index;

  questionSubmitting.value = true;

  try {
    console.log("SUBMIT QUESTION ANSWER", {
      code: code.value,

      player: player.value,

      questionRoundId,

      answerIndex: index,
    });

    const { data, error: rpcError } = await supabase.rpc(
      "submit_battle_question_answer",

      {
        p_code: code.value,

        p_player: player.value,

        p_token: token.value,

        p_question_round_id: questionRoundId,

        p_answer_index: index,
      },
    );

    console.log("QUESTION RPC RESULT", {
      data,
      rpcError,
    });

    if (rpcError) {
      throw rpcError;
    }

    // ===================================================
    // SERVER REJECTED
    // ===================================================

    if (data?.ok === false) {
      warningToast(
        "ANSWER DITOLAK",

        data?.message ?? "Jawaban tidak dapat diproses.",
      );

      return;
    }

    // ===================================================
    // CORRECT
    // ===================================================

    if (data?.correct === true) {
      questionResult.value = "correct";

      questionReward.value = data?.reward ?? null;

      // refresh reward dari database
      await loadBonusSkills();

      successToast(
        "🏆 FIRST CORRECT!",
        data?.reward
          ? `Bonus skill: ${bonusLabel(data.reward)}`
          : "Jawaban benar!",
      );

      return;
    }

    // ===================================================
    // OTHER PLAYER ALREADY WON
    // ===================================================

    if (data?.already_finished === true) {
      questionResult.value = "lost";

      warningToast(
        "TOO LATE",
        "Player lain sudah menjawab benar terlebih dahulu.",
      );

      return;
    }

    // ===================================================
    // WRONG
    // ===================================================

    questionResult.value = "wrong";

    warningToast("JAWABAN SALAH", data?.message ?? "Jawaban kamu belum benar.");
  } catch (err) {
    console.error("QUESTION SUBMIT ERROR", err);

    errorToast(
      "QUESTION ERROR",

      err?.message ?? "Gagal mengirim jawaban.",
    );
  } finally {
    questionSubmitting.value = false;
  }
};

// =========================================================
// BONUS
// =========================================================

const bonusLabel = (skill) => {
  const labels = {
    power_strike: "Power Strike",

    iron_guard: "Iron Guard",

    recovery: "Recovery",

    overcharge: "Overcharge",

    cleanse: "Cleanse",
  };

  return labels[skill] ?? skill;
};

const bonusIcon = (skill) => {
  const icons = {
    power_strike: "⚔️",

    iron_guard: "🛡️",

    recovery: "💚",

    overcharge: "⚡",

    cleanse: "✨",
  };

  return icons[skill] ?? "✨";
};

// =========================================================
// LOAD BONUS
// =========================================================

const loadBonusSkills = async () => {
  if (!battle.value?.id) {
    return;
  }

  const { data, error: bonusError } = await supabase
    .from("battle_bonus_skills")
    .select("*")
    .eq("battle_id", battle.value.id)
    .eq("player", player.value)
    .order("created_at", {
      ascending: false,
    });

  if (bonusError) {
    return;
  }

  bonusSkills.value = data ?? [];
};

const useBonusSkill = async (bonus) => {
  if (!bonus || bonus.used || bonusUsingId.value) {
    return;
  }

  if (questionActive.value) {
    warningToast(
      "CODING CHALLENGE ACTIVE",
      "Selesaikan question terlebih dahulu.",
    );

    return;
  }

  if (!isMyTurn.value) {
    warningToast("BUKAN TURN KAMU", `Sekarang giliran ${enemyName.value}.`);

    return;
  }

  bonusUsingId.value = bonus.id;

  try {
    const { data, error: rpcError } = await supabase.rpc(
      "use_battle_bonus_skill",
      {
        p_code: code.value,

        p_player: player.value,

        p_token: token.value,

        p_bonus_id: bonus.id,
      },
    );

    if (rpcError) {
      throw rpcError;
    }

    if (data?.ok === false) {
      warningToast(
        "BONUS DITOLAK",
        data?.message ?? "Bonus tidak dapat digunakan.",
      );

      return;
    }

    await loadBonusSkills();

    const skill = data?.skill_type ?? bonus.skill_type;

    let message = data?.message ?? "Bonus berhasil digunakan.";

    if (skill === "power_strike") {
      message = "Basic Attack berikutnya mendapatkan +50% damage.";
    } else if (skill === "iron_guard") {
      message = "Defense aktif.";
    } else if (skill === "recovery") {
      message = data?.heal
        ? `HP pulih +${data.heal}.`
        : "HP berhasil dipulihkan.";
    } else if (skill === "overcharge") {
      message = "Ultimate Gauge bertambah +50.";
    } else if (skill === "cleanse") {
      message = "Attack debuff berhasil dihapus.";
    }

    successToast(
      `${bonusIcon(skill)} ${bonusLabel(skill).toUpperCase()}`,
      message,
    );
  } catch (err) {
    console.error("Use bonus:", err);

    errorToast("BONUS ERROR", err?.message ?? "Gagal menggunakan bonus skill.");
  } finally {
    bonusUsingId.value = null;
  }
};

// =========================================================
// BONUS REALTIME
// =========================================================

const subscribeBonusSkills = () => {
  if (!battle.value?.id) {
    return;
  }

  bonusChannel = supabase
    .channel(`bonus-${battle.value.id}-${player.value}`)

    .on(
      "postgres_changes",

      {
        event: "*",

        schema: "public",

        table: "battle_bonus_skills",

        filter: `battle_id=eq.${battle.value.id}`,
      },

      (payload) => {
        if (
          payload.new?.player === player.value ||
          payload.old?.player === player.value
        ) {
          void loadBonusSkills();
        }
      },
    )

    .subscribe();
};

// =========================================================
// QUESTION RESET
// =========================================================

watch(
  () => currentQuestionRound.value?.id,

  () => {
    selectedQuestionAnswer.value = null;

    questionResult.value = null;

    questionReward.value = null;
  },
);

// =========================================================
// WAITING RFID
// =========================================================

watch(
  waitingForRfid,

  (waiting, previous) => {
    if (waiting && !previous) {
      successToast("📡 SUMMON READY", "Scan RFID Card sekarang.");
    }

    if (!waiting && previous) {
      successToast(
        "✨ SUMMON SELESAI",
        "Card berhasil ditambahkan dan turn berpindah.",
      );
    }
  },
);

// =========================================================
// INITIAL READY
// =========================================================

watch(
  initialReady,

  (ready, previous) => {
    if (ready && !previous && battleWaiting.value) {
      successToast("PLAYER READY", "Initial Card selesai. Menunggu opponent.");
    }
  },
);

// =========================================================
// STATUS → BATTLE
// =========================================================

watch(
  () => battle.value?.status,

  (status, previous) => {
    if (
      status === "battle" &&
      (previous === "waiting" || previous === "ready")
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

    const message = String(event.payload?.message ?? "");

    // =====================================================
    // RFID WARNING FOR THIS PLAYER
    // =====================================================

    if (event.type === "rfid_warning" && event.source_player === player.value) {
      const normalized = message.toUpperCase();

      if (normalized.includes("ALREADY") || normalized.includes("USED")) {
        warningToast("KARTU SUDAH PERNAH DIGUNAKAN", "Gunakan RFID Card lain.");
      } else if (
        normalized.includes("WAIT FOR PLAYER") ||
        normalized.includes("TURN")
      ) {
        warningToast("BUKAN TURN KAMU", message);
      } else if (normalized.includes("PRESS SUMMON")) {
        warningToast(
          "TEKAN SUMMON DULU",
          "Aktifkan Summon sebelum melakukan scan RFID.",
        );
      } else if (normalized.includes("QUESTION")) {
        warningToast(
          "QUESTION IN PROGRESS",
          "RFID tidak dapat digunakan saat Coding Challenge.",
        );
      } else if (normalized.includes("NOT REGISTERED")) {
        warningToast(
          "CARD BELUM TERDAFTAR",
          "Daftarkan RFID Card terlebih dahulu.",
        );
      } else {
        warningToast("RFID WARNING", message || "RFID scan ditolak.");
      }

      return;
    }

    // =====================================================
    // SUMMON SUCCESS
    // =====================================================

    if (
      event.type === "summon" &&
      event.source_player === player.value &&
      event.payload?.phase === "battle"
    ) {
      const hpGain = Number(event.payload?.hp_gain ?? 0);

      successToast(
        "✨ SUMMON SUCCESS",
        hpGain > 0
          ? `HP bertambah +${hpGain}.`
          : "Card berhasil masuk ke Active Deck.",
      );

      selectedCardId.value = null;

      return;
    }
  },
);

// =========================================================
// MOUNT
// =========================================================

onMounted(async () => {
  if (!code.value) {
    return;
  }

  await loadBattle(code.value);

  if (battle.value) {
    await loadBonusSkills();

    subscribeBonusSkills();
  }
});

// =========================================================
// UNMOUNT
// =========================================================

onUnmounted(async () => {
  if (toastTimer) {
    clearTimeout(toastTimer);
  }

  if (bonusChannel) {
    await supabase.removeChannel(bonusChannel);

    bonusChannel = null;
  }
});
</script>

<template>
  <main class="player-battle-ui" :class="player">
    <!-- ===================================================
         TOAST - LOGIC LAMA TETAP
    ==================================================== -->

    <Transition name="toast">
      <div v-if="toast.show" class="game-toast" :class="toast.type">
        <div class="toast-glow" />

        <div class="toast-icon">
          <template v-if="toast.type === 'success'"> ✓ </template>

          <template v-else-if="toast.type === 'warning'"> ⚠ </template>

          <template v-else> ✕ </template>
        </div>

        <div class="toast-copy">
          <strong>
            {{ toast.title }}
          </strong>

          <span v-if="toast.message">
            {{ toast.message }}
          </span>
        </div>
      </div>
    </Transition>

    <!-- ===================================================
         BACKGROUND
    ==================================================== -->

    <div class="arena-background">
      <div class="arena-grid" />

      <div class="background-glow glow-left" />

      <div class="background-glow glow-right" />

      <div class="center-pokeball">◉</div>
    </div>

    <!-- ===================================================
         LOADING
    ==================================================== -->

    <section v-if="loading" class="state-screen">
      <div class="loading-ring" />

      <strong> CONNECTING TO BATTLE </strong>

      <span> Synchronizing battle session... </span>
    </section>

    <!-- ===================================================
         ERROR
    ==================================================== -->

    <section v-else-if="error" class="state-screen state-error">
      <strong> BATTLE UNAVAILABLE </strong>

      <span>
        {{ error }}
      </span>
    </section>

    <!-- ===================================================
         TOKEN
    ==================================================== -->

    <section v-else-if="!token" class="state-screen state-error">
      <strong> INVALID PLAYER LINK </strong>

      <span> Player token tidak ditemukan. </span>
    </section>

    <!-- ===================================================
         MAIN BATTLE
    ==================================================== -->

    <template v-else-if="battle">
      <!-- =================================================
           TOP HUD
      ================================================== -->

      <header class="top-hud">
        <!-- PLAYER -->

        <section class="player-identity">
          <div class="player-avatar">
            {{ player === "p1" ? "👨🏻" : "👩🏻" }}
          </div>

          <div class="identity-copy">
            <span class="hud-label">
              {{ player === "p1" ? "PLAYER 1" : "PLAYER 2" }}
            </span>

            <strong>
              {{ playerName }}
            </strong>

            <small> Battle {{ code }} </small>
          </div>
        </section>

        <!-- HP / SKILL -->

        <section class="combat-stats">
          <div class="hp-title">
            <span> HP </span>

            <strong> {{ ownHp }} / {{ ownMaxHp }} </strong>
          </div>

          <div class="hud-hp-track">
            <div
              class="hud-hp-fill"
              :style="{
                width: `${ownHpPercent}%`,
              }"
            />
          </div>

          <div class="gauge-title">
            <span> ULTIMATE </span>

            <strong> {{ ownSkill }}% </strong>
          </div>

          <div class="hud-skill-track">
            <div
              class="hud-skill-fill"
              :style="{
                width: `${Math.min(100, ownSkill)}%`,
              }"
            />
          </div>
        </section>

        <!-- TURN -->

        <section
          class="turn-core"
          :class="{
            active: isMyTurn,

            scanning: waitingForRfid,

            waiting: battleWaiting,
          }"
        >
          <span class="turn-arrow"> ‹‹ </span>

          <div>
            <strong>
              {{ turnText }}
            </strong>

            <span>
              ROUND

              {{ battle.round ?? 1 }}

              /

              {{ battle.total_rounds ?? "-" }}
            </span>
          </div>

          <span class="turn-arrow"> ›› </span>
        </section>

        <!-- ENEMY -->

        <section class="enemy-mini-status">
          <span> VS </span>

          <strong>
            {{ enemyName }}
          </strong>

          <small> HP {{ enemyHp }} / {{ enemyMaxHp }} </small>

          <div class="enemy-mini-track">
            <div
              class="enemy-mini-fill"
              :style="{
                width: `${enemyHpPercent}%`,
              }"
            />
          </div>
        </section>
      </header>

      <!-- =================================================
           INITIAL RFID
      ================================================== -->

      <Transition name="rfid-panel">
        <section v-if="battleWaiting" class="notification-panel initial-panel">
          <div class="notification-icon">
            {{ initialReady ? "✓" : "📡" }}
          </div>

          <div>
            <span>
              {{ initialReady ? "PLAYER READY" : "INITIAL DECK SETUP" }}
            </span>

            <strong>
              {{ initialReady ? "WAITING FOR OPPONENT" : "SCAN INITIAL CARD" }}
            </strong>

            <p>
              {{
                initialReady
                  ? "Initial deck kamu sudah siap."
                  : `Gunakan ${player === "p1" ? "RC522-P1" : "RC522-P2"}`
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

      <!-- =================================================
           SUMMON RFID
      ================================================== -->

      <Transition name="rfid-panel">
        <section v-if="waitingForRfid" class="notification-panel summon-panel">
          <div class="notification-icon pulse-icon">📡</div>

          <div>
            <span> SUMMON MODE ACTIVE </span>

            <strong> SCAN RFID CARD NOW </strong>

            <p>
              Gunakan

              {{ player === "p1" ? "RC522-P1" : "RC522-P2" }}
            </p>
          </div>

          <div class="scan-indicator">WAITING RFID</div>
        </section>
      </Transition>

      <!-- =================================================
           BUFFS
      ================================================== -->

      <div v-if="ownDefending || ownShield || ownDebuff" class="buff-strip">
        <span v-if="ownDefending"> 🛡 DEFENSE ACTIVE </span>

        <span v-if="ownShield">
          💧 SHIELD

          {{ Math.round(ownShield * 100) }}%
        </span>

        <span v-if="ownDebuff">
          ❄ ATK -

          {{ Math.round(ownDebuff * 100) }}%
        </span>
      </div>

      <!-- =================================================
           GAME FIELD
      ================================================== -->

      <main class="battle-stage">
        <!-- ===============================================
             ACTIVE DECK
        ================================================ -->

        <section class="cyber-panel active-panel">
          <header class="cyber-panel-header">
            <div class="panel-title">
              <span class="panel-icon"> ◉ </span>

              <strong> ACTIVE DECK </strong>
            </div>

            <span class="panel-count">
              {{ activeCards.length }}

              /

              {{ maxActive }}
            </span>
          </header>

          <div class="deck-slots">
            <!-- EXISTING CARDS -->

            <article
              v-for="card in activeCards"
              :key="card.battleId ?? card.id"
              class="cyber-card"
              :class="{
                selected: selectedCardId === (card.battleId ?? card.id),

                exhausted: card.exhausted,
              }"
              @click="selectCard(card)"
            >
              <div class="cyber-card-inner">
                <header>
                  <strong>
                    {{ card.name }}
                  </strong>

                  <span>
                    {{ card.element || "neutral" }}
                  </span>
                </header>

                <small> CARD HP {{ card.hp }} </small>

                <div class="cyber-card-image">
                  <img
                    v-if="card.image_url"
                    :src="card.image_url"
                    :alt="card.name"
                  />

                  <div v-else class="image-placeholder">◉</div>
                </div>

                <footer class="card-combat-stats">
                  <div>
                    <span> ATTACK </span>

                    <strong>
                      {{ card.attack }}
                    </strong>
                  </div>

                  <div>
                    <span> DEFENSE </span>

                    <strong>
                      {{ card.defense ?? 0 }}
                    </strong>
                  </div>
                </footer>
              </div>

              <button
                type="button"
                class="card-secondary-action"
                :disabled="actionLoading || waitingForRfid || battleWaiting"
                @click.stop="sendBenchAction('move_to_bench', card)"
              >
                MOVE TO BENCH
              </button>
            </article>

            <!-- EMPTY ACTIVE -->

            <article
              v-for="slot in Math.max(0, maxActive - activeCards.length)"
              :key="`active-empty-${slot}`"
              class="cyber-card empty-card"
            >
              <div class="empty-ball">◉</div>

              <span>
                Pokémon
                {{ activeCards.length + slot }}
              </span>
            </article>
          </div>
        </section>

        <!-- ===============================================
             BENCH
        ================================================ -->

        <section class="cyber-panel bench-panel">
          <header class="cyber-panel-header">
            <div class="panel-title">
              <span class="panel-icon"> ◉ </span>

              <strong> BENCH </strong>
            </div>

            <span class="panel-count">
              {{ benchCards.length }}

              /

              {{ maxBench }}
            </span>
          </header>

          <div class="deck-slots bench-slots">
            <!-- ===========================================
                 BENCH CARD
                 Sekarang sama lengkap dengan ACTIVE
            ============================================ -->

            <article
              v-for="card in benchCards"
              :key="card.battleId ?? card.id"
              class="cyber-card bench-cyber-card"
              :class="{
                exhausted: card.exhausted,
              }"
            >
              <div class="cyber-card-inner">
                <header>
                  <strong>
                    {{ card.name }}
                  </strong>

                  <span>
                    {{ card.element || "neutral" }}
                  </span>
                </header>

                <small> CARD HP {{ card.hp }} </small>

                <!-- IMAGE BENCH -->

                <div class="cyber-card-image">
                  <img
                    v-if="card.image_url"
                    :src="card.image_url"
                    :alt="card.name"
                  />

                  <div v-else class="image-placeholder">◉</div>
                </div>

                <footer class="card-combat-stats bench-card-stats">
                  <div>
                    <span> ATTACK </span>

                    <strong>
                      {{ card.attack }}
                    </strong>
                  </div>

                  <div>
                    <span> DEFENSE </span>

                    <strong>
                      {{ card.defense ?? 0 }}
                    </strong>
                  </div>

                  <small>
                    RETURN
                    {{ card.benchReturnCount ?? 0 }}
                    /1
                  </small>
                </footer>
              </div>

              <div v-if="card.exhausted" class="card-exhausted-overlay">
                <strong> EXHAUSTED </strong>

                <span> CANNOT RETURN </span>
              </div>

              <button
                v-else
                type="button"
                class="card-secondary-action"
                :disabled="actionLoading || waitingForRfid || battleWaiting"
                @click="sendBenchAction('return_from_bench', card)"
              >
                RETURN ACTIVE
              </button>
            </article>

            <!-- EMPTY BENCH -->

            <article
              v-for="slot in Math.max(0, maxBench - benchCards.length)"
              :key="`bench-empty-${slot}`"
              class="cyber-card empty-card bench-empty"
            >
              <div class="empty-ball">◉</div>

              <span> Bench {{ slot }} </span>
            </article>
          </div>
        </section>
      </main>

      <!-- =================================================
           BONUS SKILL REWARD
      ================================================== -->

      <section v-if="bonusSkills.length" class="bonus-panel glass-panel">
        <div class="panel-heading">
          <div>
            <span class="eyebrow"> QUESTION REWARD </span>

            <h2>Bonus Skills</h2>
          </div>
        </div>

        <div class="bonus-list">
          <button
            v-for="bonus in bonusSkills"
            :key="bonus.id"
            type="button"
            class="bonus-item bonus-button"
            :class="{
              used: bonus.used,

              ready: !bonus.used,
            }"
            :disabled="bonus.used || bonusUsingId === bonus.id"
            @click="useBonusSkill(bonus)"
          >
            <span class="bonus-item-icon">
              {{ bonusIcon(bonus.skill_type) }}
            </span>

            <div>
              <strong>
                {{ bonusLabel(bonus.skill_type) }}
              </strong>

              <small>
                {{
                  bonusUsingId === bonus.id
                    ? "ACTIVATING..."
                    : bonus.used
                      ? "USED"
                      : "READY - CLICK TO USE"
                }}
              </small>
            </div>
          </button>
        </div>
      </section>

      <!-- =================================================
           BOTTOM CONTROL CONSOLE
      ================================================== -->

      <footer v-if="battle.status === 'battle'" class="control-console">
        <div class="console-decoration left">//</div>

        <!-- ATTACK -->

        <button
          type="button"
          class="console-skill attack-skill"
          :class="{
            dimmed: waitingForRfid || questionActive || battleFinished,
          }"
          :disabled="
            actionLoading || waitingForRfid || questionActive || battleFinished
          "
          @click="submitAction('attack')"
        >
          <span class="console-icon"> ⚔ </span>

          <strong> ATTACK </strong>

          <small> BASIC </small>
        </button>

        <!-- DEFENSE -->

        <button
          type="button"
          class="console-skill defense-skill"
          :class="{
            dimmed: waitingForRfid || questionActive || battleFinished,
          }"
          :disabled="
            actionLoading || waitingForRfid || questionActive || battleFinished
          "
          @click="submitAction('defense')"
        >
          <span class="console-icon"> 🛡 </span>

          <strong> DEFENSE </strong>

          <small> -50% DMG </small>
        </button>

        <!-- SUMMON CENTER -->

        <button
          type="button"
          class="summon-core"
          :class="{
            active: waitingForRfid,

            unavailable: !canSummonUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canSummonUi
          "
          @click="submitAction('summon')"
        >
          <div class="summon-core-inner">
            <span>
              {{ waitingForRfid ? "📡" : "◉" }}
            </span>

            <strong>
              {{ waitingForRfid ? "SCAN RFID" : "SUMMON" }}
            </strong>

            <small v-if="!canSummonUi"> ACTIVE FULL </small>

            <small v-else> + </small>
          </div>
        </button>

        <!-- ULTIMATE -->

        <button
          type="button"
          class="console-skill ultimate-skill"
          :class="{
            unavailable: !canUltimateUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canUltimateUi
          "
          @click="submitAction('ultimate')"
        >
          <span class="console-icon"> ⚡ </span>

          <strong> ULTIMATE </strong>

          <small>
            {{ canUltimateUi ? "READY" : skillLockText("ultimate") }}
          </small>
        </button>

        <!-- HEAL -->

        <button
          type="button"
          class="console-skill heal-skill"
          :class="{
            unavailable: !canHealUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canHealUi
          "
          @click="submitAction('heal')"
        >
          <span class="console-icon"> ✦ </span>

          <strong> HEAL </strong>

          <small>
            {{ canHealUi ? "READY" : skillLockText("heal") }}
          </small>
        </button>

        <!-- SYNERGY -->

        <button
          type="button"
          class="console-skill synergy-skill"
          :class="{
            unavailable: !canSynergyUi,
          }"
          :disabled="
            actionLoading ||
            waitingForRfid ||
            questionActive ||
            battleFinished ||
            !canSynergyUi
          "
          @click="submitAction('synergy')"
        >
          <span class="console-icon"> ✧ </span>

          <strong> SYNERGY </strong>

          <small>
            {{ canSynergyUi ? "READY" : skillLockText("synergy") }}
          </small>
        </button>

        <div class="console-decoration right">//</div>
      </footer>

      <!-- =================================================
           SELECTED CARD INFO
      ================================================== -->

      <div v-if="selectedCard" class="selected-card-chip">
        SELECTED

        <strong>
          {{ selectedCard.name }}
        </strong>
      </div>

      <!-- =================================================
           QUESTION - LOGIC TETAP
      ================================================== -->

      <Transition name="question">
        <div v-if="battle && questionActive" class="question-overlay">
          <div class="question-backdrop" />

          <section class="question-card">
            <span class="hud-label"> CODING CHALLENGE </span>

            <h2>
              Answer Faster Than

              {{ enemyName }}
            </h2>

            <div v-if="questionLoading" class="question-state">
              Loading question...
            </div>

            <div v-else-if="questionError" class="question-state">
              {{ questionError }}
            </div>

            <template v-else-if="currentQuestion">
              <div class="question-text">
                {{ currentQuestion.question }}
              </div>

              <pre
                v-if="currentQuestion.code"
                class="question-code"
              ><code>{{ currentQuestion.code }}</code></pre>

              <div class="question-options">
                <button
                  v-for="(option, index) in currentQuestion.options"
                  :key="index"
                  type="button"
                  class="question-option"
                  :class="{
                    selected: selectedQuestionAnswer === index,

                    correct:
                      selectedQuestionAnswer === index &&
                      questionResult === 'correct',

                    wrong:
                      selectedQuestionAnswer === index &&
                      questionResult === 'wrong',
                  }"
                  :disabled="questionSubmitting || Boolean(questionResult)"
                  @click="answerQuestion(index)"
                >
                  <span>
                    {{ String.fromCharCode(65 + index) }}
                  </span>

                  {{ option }}
                </button>
              </div>
            </template>
          </section>
        </div>
      </Transition>

      <!-- =================================================
           WINNER
      ================================================== -->

      <Transition name="question">
        <div v-if="battleFinished" class="winner-overlay">
          <section class="winner-card">
            <span> BATTLE FINISHED </span>

            <h1>
              {{
                didWin
                  ? "YOU WIN!"
                  : battle.winner === "draw"
                    ? "DRAW"
                    : "BATTLE OVER"
              }}
            </h1>

            <strong>
              {{
                battle.winner === "draw"
                  ? "NO WINNER"
                  : battle.winner === "p1"
                    ? (battle.player1_name ?? "Player 1")
                    : (battle.player2_name ?? "Player 2")
              }}
            </strong>
          </section>
        </div>
      </Transition>
    </template>
  </main>
</template>

<style scoped>
/* =========================================================
   RESET
========================================================= */

* {
  box-sizing: border-box;
}

button {
  font: inherit;
}

/* =========================================================
   ROOT
========================================================= */

.player-battle-ui {
  --player-accent: #249fe8;
  --player-accent-soft: #74caff;

  width: 100%;
  min-height: 100vh;

  position: relative;

  overflow-x: hidden;

  padding: 20px 24px 180px;

  color: #17324a;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    "Segoe UI",
    sans-serif;

  background: linear-gradient(
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

/* =========================================================
   ARENA BACKGROUND
========================================================= */

.arena-background {
  position: fixed;

  inset: 0;

  z-index: 0;

  overflow: hidden;

  pointer-events: none;

  background:
    radial-gradient(
      circle at 50% 45%,
      rgba(255, 255, 255, 0.95) 0%,
      rgba(255, 255, 255, 0.35) 18%,
      transparent 42%
    ),
    linear-gradient(180deg, #d8efff 0%, #effaff 28%, #d9f0dd 65%, #c5e5cc 100%);
}

/* subtle arena field */

.arena-background::before {
  content: "";

  position: absolute;

  left: 6%;
  right: 6%;

  top: 20%;
  bottom: 13%;

  border: 4px solid rgba(255, 255, 255, 0.28);

  border-radius: 70px;

  box-shadow: inset 0 0 0 2px rgba(69, 146, 94, 0.06);
}

/* center circle */

.arena-background::after {
  content: "";

  width: 480px;
  height: 480px;

  position: absolute;

  left: 50%;
  top: 48%;

  transform: translate(-50%, -50%);

  border: 5px solid rgba(255, 255, 255, 0.25);

  border-radius: 50%;
}

.arena-grid {
  position: absolute;

  inset: 0;

  opacity: 0.22;

  background-image:
    linear-gradient(rgba(255, 255, 255, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.08) 1px, transparent 1px);

  background-size: 60px 60px;
}

.background-glow {
  width: 500px;
  height: 500px;

  position: absolute;

  border-radius: 50%;

  filter: blur(130px);

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

  transform: translate(-50%, -50%);

  color: rgba(65, 133, 165, 0.055);

  font-size: clamp(250px, 32vw, 500px);

  line-height: 1;
}

/* =========================================================
   TOP HUD
========================================================= */

.top-hud {
  width: min(100%, 1450px);

  min-height: 120px;

  position: relative;

  z-index: 10;

  display: grid;

  grid-template-columns:
    1.1fr
    1.25fr
    1fr
    0.9fr;

  align-items: center;

  gap: 18px;

  margin: 0 auto 18px;

  padding: 20px 24px;

  border: 1px solid rgba(84, 133, 165, 0.2);

  border-radius: 24px;

  background: rgba(255, 255, 255, 0.75);

  backdrop-filter: blur(16px);

  box-shadow: 0 16px 40px rgba(48, 87, 112, 0.1);
}

/* =========================================================
   PLAYER ID
========================================================= */

.player-identity {
  display: flex;

  align-items: center;

  gap: 16px;
}

.player-avatar {
  width: 74px;
  height: 74px;

  flex: 0 0 74px;

  display: grid;

  place-items: center;

  overflow: hidden;

  border: 4px solid var(--player-accent);

  border-radius: 50%;

  color: #17324a;

  background: linear-gradient(145deg, #ffffff, #e6f5ff);

  box-shadow: 0 8px 25px rgba(47, 118, 168, 0.16);

  font-size: 33px;
}

.identity-copy span,
.hud-label {
  display: block;

  color: var(--player-accent);

  font-size: 9px;

  font-weight: 900;

  letter-spacing: 0.13em;
}

.identity-copy strong {
  display: block;

  margin: 3px 0;

  color: #17324a;

  font-size: 26px;

  line-height: 1;
}

.identity-copy small {
  color: #68849a;

  font-size: 9px;
}

/* =========================================================
   COMBAT STATS
========================================================= */

.combat-stats {
  padding: 6px 18px;

  border-left: 1px solid rgba(79, 129, 160, 0.15);
}

.hp-title,
.gauge-title {
  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 10px;

  color: #5d7990;

  font-size: 8px;

  font-weight: 800;

  letter-spacing: 0.07em;
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

  border-radius: 999px;

  background: rgba(71, 110, 139, 0.13);
}

.hud-hp-fill {
  height: 100%;

  border-radius: inherit;

  background: linear-gradient(90deg, #28aefe, #62e2b8);

  transition: width 0.3s ease;
}

.hud-skill-fill {
  height: 100%;

  border-radius: inherit;

  background: linear-gradient(90deg, #7568ff, #a96eff);

  transition: width 0.3s ease;
}

/* =========================================================
   TURN CENTER
========================================================= */

.turn-core {
  min-height: 76px;

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 15px;

  padding: 12px 18px;

  border: 1px solid rgba(75, 132, 168, 0.23);

  border-radius: 20px;

  color: #5d7588;

  background: rgba(245, 251, 255, 0.72);

  text-align: center;
}

.turn-core.active {
  color: #147548;

  border-color: rgba(48, 181, 109, 0.32);

  background: rgba(218, 250, 230, 0.78);

  box-shadow: 0 10px 25px rgba(54, 159, 105, 0.1);
}

.turn-core.scanning {
  border-color: rgba(29, 155, 226, 0.35);

  background: rgba(220, 244, 255, 0.88);
}

.turn-core.waiting {
  opacity: 0.8;
}

.turn-core strong {
  display: block;

  font-size: 17px;

  letter-spacing: 0.09em;
}

.turn-core div span {
  display: block;

  margin-top: 4px;

  font-size: 8px;

  font-weight: 800;
}

.turn-arrow {
  color: var(--player-accent);

  font-size: 19px;

  font-weight: 900;
}

/* =========================================================
   ENEMY STATUS
========================================================= */

.enemy-mini-status {
  padding: 5px 0 5px 16px;

  border-left: 1px solid rgba(225, 88, 113, 0.16);
}

.enemy-mini-status > span {
  color: #dd4c70;

  font-size: 8px;

  font-weight: 900;
}

.enemy-mini-status strong {
  display: block;

  margin: 3px 0;

  color: #17324a;

  font-size: 15px;
}

.enemy-mini-status small {
  color: #73899b;

  font-size: 8px;
}

.enemy-mini-fill {
  height: 100%;

  border-radius: inherit;

  background: linear-gradient(90deg, #ff6687, #ff9b6b);
}

/* =========================================================
   RFID / INITIAL PANEL
========================================================= */

.notification-panel {
  width: min(100%, 1200px);

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

  margin: 0 auto 16px;

  padding: 16px 20px;

  border: 1px solid rgba(55, 147, 208, 0.25);

  border-radius: 18px;

  color: #17324a;

  background: rgba(239, 250, 255, 0.86);

  backdrop-filter: blur(14px);

  box-shadow: 0 12px 26px rgba(59, 116, 152, 0.09);
}

.notification-icon {
  width: 48px;
  height: 48px;

  display: grid;

  place-items: center;

  border: 1px solid rgba(44, 150, 215, 0.35);

  border-radius: 50%;

  color: var(--player-accent);

  background: rgba(255, 255, 255, 0.68);

  font-size: 21px;
}

.notification-panel span {
  color: var(--player-accent);

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.1em;
}

.notification-panel strong {
  display: block;

  margin: 3px 0;

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
  color: var(--player-accent);

  font-size: 13px;

  font-weight: 900;
}

.pulse-icon {
  animation: scanPulse 1.2s infinite;
}

/* =========================================================
   BUFF STRIP
========================================================= */

.buff-strip {
  position: relative;

  z-index: 10;

  display: flex;

  justify-content: center;

  flex-wrap: wrap;

  gap: 8px;

  margin: 0 auto 14px;
}

.buff-strip span {
  padding: 7px 11px;

  border: 1px solid rgba(68, 129, 165, 0.18);

  border-radius: 999px;

  color: #41647e;

  background: rgba(255, 255, 255, 0.68);

  font-size: 8px;

  font-weight: 800;

  box-shadow: 0 6px 15px rgba(51, 97, 125, 0.06);
}

/* =========================================================
   BATTLE STAGE
========================================================= */

.battle-stage {
  width: min(100%, 1450px);

  position: relative;

  z-index: 5;

  display: grid;

  gap: 18px;

  margin: 0 auto;
}

/* =========================================================
   PANEL
========================================================= */

.cyber-panel {
  min-height: 300px;

  position: relative;

  padding: 22px 26px 26px;

  overflow: hidden;

  border: 1px solid rgba(85, 134, 165, 0.2);

  border-radius: 26px;

  background: rgba(255, 255, 255, 0.7);

  backdrop-filter: blur(15px);

  box-shadow: 0 16px 38px rgba(55, 94, 119, 0.09);
}

.cyber-panel::before {
  content: "";

  position: absolute;

  inset: 0;

  pointer-events: none;

  background: linear-gradient(
    120deg,
    rgba(255, 255, 255, 0.4),
    transparent 35%
  );
}

.cyber-panel-header {
  position: relative;

  z-index: 2;

  display: flex;

  align-items: center;

  justify-content: space-between;

  margin-bottom: 18px;
}

.panel-title {
  display: flex;

  align-items: center;

  gap: 10px;
}

.panel-icon {
  color: var(--player-accent);

  font-size: 18px;
}

.panel-title strong {
  color: #24435c;

  font-size: 16px;

  letter-spacing: 0.08em;
}

.panel-count {
  padding: 6px 10px;

  border-radius: 999px;

  color: #477391;

  background: rgba(220, 239, 249, 0.72);

  font-size: 10px;

  font-weight: 900;
}

/* =========================================================
   DECK GRID
========================================================= */

.deck-slots {
  position: relative;

  z-index: 2;

  display: grid;

  grid-template-columns: repeat(4, minmax(150px, 220px));

  align-items: start;

  gap: 18px;
}

/* =========================================================
   CARD
========================================================= */

.cyber-card {
  min-height: 290px;

  position: relative;

  padding: 10px;

  overflow: hidden;

  border: 2px solid rgba(67, 153, 210, 0.25);

  border-radius: 22px;

  color: #17324a;

  background: rgba(255, 255, 255, 0.9);

  box-shadow: 0 9px 24px rgba(60, 108, 137, 0.1);

  cursor: pointer;

  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    box-shadow 0.18s ease;
}

.cyber-card:hover {
  transform: translateY(-4px);

  border-color: rgba(31, 157, 229, 0.45);

  box-shadow: 0 14px 30px rgba(54, 115, 153, 0.15);
}

.cyber-card.selected {
  border-color: var(--player-accent);

  box-shadow:
    0 0 0 4px rgba(45, 158, 225, 0.12),
    0 16px 30px rgba(50, 112, 151, 0.14);
}

.cyber-card.exhausted {
  opacity: 0.45;

  filter: grayscale(0.75);
}

.cyber-card-inner {
  position: relative;

  z-index: 1;

  padding-bottom: 35px;
}

.cyber-card-inner header {
  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 8px;

  margin-bottom: 4px;
}

.cyber-card-inner header strong {
  max-width: 68%;

  overflow: hidden;

  color: #19354c;

  font-size: 12px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.cyber-card-inner header span {
  padding: 4px 7px;

  border-radius: 999px;

  color: #297cad;

  background: rgba(48, 156, 218, 0.1);

  font-size: 7px;

  font-weight: 900;

  text-transform: uppercase;
}

.cyber-card-inner > small {
  display: block;

  margin-bottom: 8px;

  color: #6c879a;

  font-size: 10px;

  font-weight: 700;
}

/* =========================================================
   CARD IMAGE
========================================================= */

.cyber-card-image {
  width: 100%;
  height: 170px;

  overflow: hidden;

  margin-bottom: 10px;

  border: 1px solid rgba(77, 132, 164, 0.15);

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

  background: linear-gradient(145deg, #edf7fb, #dcebf2);

  font-size: 38px;
}

/* =========================================================
   CARD FOOTER
========================================================= */

.cyber-card-inner footer {
  display: flex;

  align-items: flex-end;

  justify-content: space-between;

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

/* =========================================================
   MOVE / RETURN BUTTON
========================================================= */

.card-secondary-action {
  width: calc(100% - 20px);

  min-height: 30px;

  position: absolute;

  left: 10px;
  bottom: 9px;

  z-index: 3;

  border: 0;

  border-radius: 10px;

  color: #ffffff;

  background: linear-gradient(135deg, #38aef2, #2188d6);

  box-shadow: 0 6px 14px rgba(44, 127, 180, 0.15);

  font-size: 7px;

  font-weight: 900;

  cursor: pointer;
}

.card-secondary-action:hover:not(:disabled) {
  filter: brightness(1.05);
}

.card-secondary-action:disabled {
  opacity: 0.38;

  cursor: not-allowed;

  box-shadow: none;
}

/* =========================================================
   EMPTY SLOT
========================================================= */

.empty-card {
  min-height: 250px;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 12px;

  border: 2px dashed rgba(76, 139, 177, 0.25);

  color: #7595aa;

  background: rgba(247, 253, 255, 0.45);

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

  border: 2px solid rgba(51, 144, 200, 0.34);

  border-radius: 50%;

  color: #5aa5d0;

  background: rgba(255, 255, 255, 0.55);

  font-size: 30px;
}

.empty-card span {
  font-size: 9px;

  font-weight: 700;
}

/* =========================================================
   BENCH
========================================================= */

.bench-panel {
  min-height: 280px;
}

.bench-cyber-card {
  border-color: rgba(100, 153, 185, 0.26);
}

.bench-cyber-card::after {
  content: "BENCH";

  position: absolute;

  right: 12px;
  top: 12px;

  z-index: 4;

  padding: 4px 7px;

  border-radius: 999px;

  color: #5a7e95;

  background: rgba(236, 246, 252, 0.9);

  font-size: 6px;

  font-weight: 900;

  letter-spacing: 0.08em;
}

.card-exhausted-overlay {
  position: absolute;

  inset: 0;

  z-index: 6;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  border-radius: inherit;

  color: #a13f52;

  background: rgba(255, 245, 247, 0.88);

  backdrop-filter: blur(4px);
}

.card-exhausted-overlay strong {
  font-size: 13px;
}

.card-exhausted-overlay span {
  margin-top: 4px;

  font-size: 8px;
}

/* =========================================================
   BONUS SKILLS
========================================================= */

.bonus-hud {
  width: min(100%, 1150px);

  position: relative;

  z-index: 10;

  margin: 16px auto;

  padding: 14px 16px;

  border: 1px solid rgba(225, 181, 58, 0.18);

  border-radius: 17px;

  background: rgba(255, 252, 233, 0.78);

  box-shadow: 0 9px 24px rgba(103, 89, 40, 0.07);
}

.bonus-hud > span {
  color: #b08419;

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.1em;
}

.bonus-hud > div {
  display: flex;

  flex-wrap: wrap;

  gap: 8px;

  margin-top: 9px;
}

.bonus-chip {
  display: flex;

  align-items: center;

  gap: 6px;

  padding: 8px 10px;

  border: 1px solid rgba(199, 158, 40, 0.17);

  border-radius: 10px;

  color: #6e5a1c;

  background: rgba(255, 255, 255, 0.55);

  font-size: 8px;
}

.bonus-chip.used {
  opacity: 0.4;
}

/* =========================================================
   FIXED CONTROL BAR
========================================================= */

.control-console {
  width: min(calc(100% - 32px), 1250px);

  min-height: 110px;

  position: fixed;

  left: 50%;
  bottom: 18px;

  z-index: 150;

  display: grid;

  grid-template-columns:
    20px
    repeat(2, minmax(0, 1fr))
    minmax(120px, 1.1fr)
    repeat(3, minmax(0, 1fr))
    20px;

  align-items: center;

  gap: 10px;

  padding: 14px 18px;

  transform: translateX(-50%);

  border: 1px solid rgba(75, 128, 160, 0.23);

  border-radius: 26px;

  background: rgba(255, 255, 255, 0.88);

  backdrop-filter: blur(18px);

  box-shadow: 0 20px 60px rgba(46, 75, 95, 0.18);
}

.console-decoration {
  color: var(--player-accent);

  text-align: center;

  font-size: 11px;

  font-weight: 900;
}

/* =========================================================
   CONTROL BUTTON
========================================================= */

.console-skill {
  min-height: 76px;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 3px;

  border: 1px solid rgba(87, 134, 163, 0.18);

  border-radius: 18px;

  color: #29465e;

  background: rgba(246, 251, 254, 0.96);

  box-shadow: 0 6px 15px rgba(58, 95, 119, 0.06);

  cursor: pointer;

  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease,
    background 0.15s ease;
}

.console-skill:hover:not(:disabled) {
  transform: translateY(-3px);

  background: #ffffff;

  box-shadow: 0 11px 20px rgba(47, 93, 122, 0.11);
}

.console-icon {
  font-size: 23px;
}

.console-skill strong {
  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.07em;
}

.console-skill small {
  color: #7a91a2;

  font-size: 6px;

  font-weight: 800;
}

/* ATTACK */

.attack-skill {
  border-color: rgba(225, 93, 101, 0.23);
}

/* DEFENSE */

.defense-skill {
  border-color: rgba(55, 139, 219, 0.23);
}

/* ULTIMATE */

.ultimate-skill {
  border-color: rgba(129, 100, 228, 0.23);
}

/* HEAL */

.heal-skill {
  border-color: rgba(47, 184, 113, 0.23);
}

/* SYNERGY */

.synergy-skill {
  border-color: rgba(218, 170, 49, 0.25);
}

/* =========================================================
   DISABLED SKILLS
========================================================= */

.console-skill.unavailable,
.console-skill.dimmed,
.console-skill:disabled {
  opacity: 0.38;

  filter: grayscale(0.6);

  cursor: not-allowed;

  transform: none;

  box-shadow: none;
}

/* =========================================================
   SUMMON
========================================================= */

.summon-core {
  min-height: 92px;

  border: 0;

  border-radius: 24px;

  color: #ffffff;

  background: linear-gradient(135deg, #42b5f4, #278ddd);

  box-shadow: 0 12px 28px rgba(42, 136, 199, 0.23);

  cursor: pointer;

  transition:
    transform 0.16s ease,
    box-shadow 0.16s ease;
}

.summon-core:hover:not(:disabled) {
  transform: translateY(-3px) scale(1.015);

  box-shadow: 0 16px 34px rgba(42, 136, 199, 0.3);
}

.summon-core.active {
  animation: summonPulse 1.2s infinite;
}

.summon-core.unavailable,
.summon-core:disabled {
  opacity: 0.38;

  filter: grayscale(0.55);

  cursor: not-allowed;

  box-shadow: none;
}

.summon-core-inner {
  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 2px;
}

.summon-core-inner span {
  font-size: 26px;
}

.summon-core-inner strong {
  font-size: 10px;

  font-weight: 900;

  letter-spacing: 0.08em;
}

.summon-core-inner small {
  color: rgba(255, 255, 255, 0.78);

  font-size: 7px;

  font-weight: 800;
}

/* =========================================================
   SELECTED CARD CHIP
========================================================= */

.selected-card-chip {
  position: fixed;

  right: 22px;
  bottom: 145px;

  z-index: 145;

  display: flex;

  align-items: center;

  gap: 6px;

  padding: 8px 12px;

  border: 1px solid rgba(60, 137, 185, 0.22);

  border-radius: 999px;

  color: #658198;

  background: rgba(255, 255, 255, 0.92);

  backdrop-filter: blur(10px);

  box-shadow: 0 8px 22px rgba(55, 94, 119, 0.11);

  font-size: 7px;

  font-weight: 800;
}

.selected-card-chip strong {
  color: #17324a;
}

/* =========================================================
   TOAST
========================================================= */

.game-toast {
  width: min(92vw, 650px);

  min-height: 82px;

  position: fixed;

  left: 50%;
  top: 22px;

  z-index: 9999;

  display: flex;

  align-items: center;

  gap: 15px;

  padding: 16px 20px;

  overflow: hidden;

  transform: translateX(-50%);

  border: 1px solid rgba(255, 255, 255, 0.5);

  border-radius: 20px;

  background: rgba(255, 255, 255, 0.94);

  backdrop-filter: blur(18px);

  box-shadow: 0 20px 55px rgba(40, 72, 94, 0.18);
}

.toast-glow {
  width: 150px;
  height: 150px;

  position: absolute;

  left: -70px;
  top: -35px;

  border-radius: 50%;

  filter: blur(45px);

  opacity: 0.2;
}

.game-toast.success {
  color: #175b3b;

  border-color: rgba(46, 185, 111, 0.32);

  background: rgba(235, 255, 244, 0.96);
}

.game-toast.success .toast-glow {
  background: #63dc9a;
}

.game-toast.warning {
  color: #72500d;

  border-color: rgba(224, 176, 52, 0.36);

  background: rgba(255, 250, 228, 0.97);
}

.game-toast.warning .toast-glow {
  background: #f3ca57;
}

.game-toast.error {
  color: #842d42;

  border-color: rgba(223, 81, 111, 0.35);

  background: rgba(255, 238, 242, 0.97);
}

.game-toast.error .toast-glow {
  background: #ef738f;
}

.toast-icon {
  width: 50px;
  height: 50px;

  flex: 0 0 50px;

  position: relative;

  z-index: 2;

  display: grid;

  place-items: center;

  border-radius: 50%;

  background: rgba(255, 255, 255, 0.7);

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

  letter-spacing: 0.04em;
}

.toast-copy span {
  display: block;

  margin-top: 4px;

  color: currentColor;

  opacity: 0.75;

  font-size: 10px;
}

/* =========================================================
   LOADING / ERROR STATE
========================================================= */

.state-screen {
  min-height: 100vh;

  position: relative;

  z-index: 20;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

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

  border: 3px solid rgba(68, 138, 180, 0.14);

  border-top-color: #399fdf;

  border-radius: 50%;

  animation: spin 0.7s linear infinite;
}

.state-error strong {
  color: #ba405a;
}

/* =========================================================
   QUESTION OVERLAY
========================================================= */

.question-overlay,
.winner-overlay {
  position: fixed;

  inset: 0;

  z-index: 7000;

  display: grid;

  place-items: center;

  padding: 20px;
}

.question-backdrop {
  position: absolute;

  inset: 0;

  background: rgba(70, 104, 123, 0.42);

  backdrop-filter: blur(9px);
}

.question-card {
  width: min(100%, 720px);

  max-height: calc(100vh - 40px);

  position: relative;

  z-index: 2;

  overflow-y: auto;

  padding: 26px;

  border: 1px solid rgba(80, 139, 176, 0.25);

  border-radius: 24px;

  color: #17324a;

  background: rgba(255, 255, 255, 0.96);

  box-shadow: 0 28px 80px rgba(45, 72, 90, 0.22);
}

.question-card h2 {
  margin: 8px 0 20px;

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

  border: 1px solid rgba(78, 128, 158, 0.16);

  border-radius: 14px;

  color: #284e68;

  background: #f2f8fb;

  font-size: 11px;

  white-space: pre-wrap;
}

.question-options {
  display: grid;

  gap: 9px;

  margin-top: 16px;
}

.question-option {
  min-height: 54px;

  display: flex;

  align-items: center;

  padding: 8px 12px;

  border: 1px solid rgba(75, 133, 168, 0.18);

  border-radius: 14px;

  color: #36566d;

  text-align: left;

  background: rgba(246, 251, 254, 0.95);

  cursor: pointer;

  transition:
    border-color 0.15s ease,
    background 0.15s ease;
}

.question-option:hover:not(:disabled) {
  border-color: rgba(48, 151, 214, 0.38);

  background: #ffffff;
}

.question-option > span {
  width: 32px;
  height: 32px;

  flex: 0 0 32px;

  display: grid;

  place-items: center;

  margin-right: 10px;

  border-radius: 9px;

  color: #2b8bc7;

  background: rgba(49, 154, 216, 0.09);

  font-weight: 900;
}

.question-option.selected {
  border-color: rgba(47, 150, 212, 0.48);
}

.question-option.correct {
  color: #21663f;

  border-color: rgba(49, 181, 104, 0.35);

  background: rgba(232, 251, 240, 0.94);
}

.question-option.wrong {
  color: #993d51;

  border-color: rgba(216, 71, 102, 0.34);

  background: rgba(255, 239, 242, 0.96);
}

.question-state {
  padding: 50px 0;

  color: #6a869a;

  text-align: center;
}

/* =========================================================
   WINNER
========================================================= */

.winner-overlay {
  background: rgba(80, 110, 126, 0.4);

  backdrop-filter: blur(10px);
}

.winner-card {
  width: min(90vw, 460px);

  padding: 42px;

  border: 1px solid rgba(57, 146, 203, 0.25);

  border-radius: 26px;

  color: #17324a;

  text-align: center;

  background: rgba(255, 255, 255, 0.97);

  box-shadow: 0 30px 90px rgba(43, 73, 91, 0.22);
}

.winner-card > span {
  color: var(--player-accent);

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.1em;
}

.winner-card h1 {
  margin: 8px 0;

  color: #17324a;

  font-size: 35px;
}

/* =========================================================
   TRANSITIONS
========================================================= */

.toast-enter-active,
.toast-leave-active,
.rfid-panel-enter-active,
.rfid-panel-leave-active,
.question-enter-active,
.question-leave-active {
  transition:
    opacity 0.22s ease,
    transform 0.22s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;

  transform: translateX(-50%) translateY(-35px);
}

.rfid-panel-enter-from,
.rfid-panel-leave-to {
  opacity: 0;

  transform: translateY(-8px);
}

/* =========================================================
   ANIMATION
========================================================= */

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@keyframes scanPulse {
  0%,
  100% {
    box-shadow: 0 0 0 0 rgba(53, 162, 222, 0.25);
  }

  50% {
    box-shadow: 0 0 0 14px rgba(53, 162, 222, 0);
  }
}

@keyframes summonPulse {
  0%,
  100% {
    box-shadow: 0 12px 28px rgba(42, 136, 199, 0.22);
  }

  50% {
    box-shadow: 0 16px 38px rgba(42, 136, 199, 0.38);
  }
}

/* =========================================================
   TABLET
========================================================= */

@media (max-width: 1150px) {
  .player-battle-ui {
    padding: 14px 14px 220px;
  }

  .top-hud {
    grid-template-columns:
      1fr
      1fr;

    gap: 14px;
  }

  .deck-slots {
    grid-template-columns: repeat(4, minmax(120px, 1fr));

    gap: 12px;
  }

  .cyber-card-image {
    height: 145px;
  }

  .control-console {
    bottom: 10px;

    grid-template-columns: repeat(3, minmax(0, 1fr));

    width: min(calc(100% - 20px), 800px);

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
    bottom: 205px;
  }
}

/* =========================================================
   MOBILE
========================================================= */

@media (max-width: 760px) {
  .player-battle-ui {
    padding: 10px 10px 330px;
  }

  .top-hud {
    display: flex;

    flex-direction: column;

    align-items: stretch;

    padding: 16px;

    border-radius: 20px;
  }

  .player-identity {
    justify-content: center;
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
    grid-column: 1 / -1;

    text-align: center;
  }

  .cyber-panel {
    padding: 17px 14px;

    border-radius: 20px;
  }

  .deck-slots {
    grid-template-columns: repeat(2, minmax(0, 1fr));

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
    width: calc(100% - 16px);

    bottom: 8px;

    grid-template-columns: repeat(2, minmax(0, 1fr));

    gap: 8px;

    padding: 10px;

    border-radius: 20px;
  }

  .console-skill {
    min-height: 65px;

    border-radius: 14px;
  }

  .summon-core {
    grid-column: 1 / -1;

    min-height: 70px;

    border-radius: 16px;
  }

  .selected-card-chip {
    right: 12px;

    bottom: 310px;
  }

  .game-toast {
    width: calc(100vw - 20px);

    top: 10px;

    min-height: 70px;

    padding: 13px 15px;
  }

  .toast-icon {
    width: 42px;
    height: 42px;

    flex-basis: 42px;
  }

  .toast-copy strong {
    font-size: 13px;
  }

  .toast-copy span {
    font-size: 9px;
  }
}

/* =========================================================
   SMALL MOBILE
========================================================= */

@media (max-width: 480px) {
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

  .cyber-card-inner header strong {
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
/* =========================================================
   QUESTION REWARD / BONUS SKILLS
========================================================= */

.bonus-panel {
  width: min(100%, 1450px);

  position: relative;
  z-index: 12;

  margin: 18px auto 130px;

  padding: 18px 22px;

  border: 1px solid rgba(80, 145, 185, 0.22);

  border-radius: 22px;

  background: rgba(255, 255, 255, 0.82);

  backdrop-filter: blur(16px);

  box-shadow: 0 16px 38px rgba(48, 87, 112, 0.1);
}

.bonus-panel .panel-heading {
  display: flex;

  align-items: center;

  justify-content: space-between;

  margin-bottom: 14px;
}

.bonus-panel .panel-heading .eyebrow {
  display: block;

  margin-bottom: 3px;

  color: var(--player-accent);

  font-size: 10px;

  font-weight: 900;

  letter-spacing: 1.4px;
}

.bonus-panel .panel-heading h2 {
  margin: 0;

  color: #17324a;

  font-size: 18px;

  font-weight: 900;
}

/* =========================================================
   BONUS LIST
========================================================= */

.bonus-list {
  display: grid;

  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));

  gap: 12px;
}

/* =========================================================
   BONUS CARD
========================================================= */

.bonus-item {
  min-height: 82px;

  display: flex;

  align-items: center;

  gap: 14px;

  padding: 14px 16px;

  border: 1px solid rgba(60, 145, 200, 0.22);

  border-radius: 16px;

  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.96),
    rgba(235, 248, 255, 0.92)
  );

  color: #17324a;

  text-align: left;

  box-shadow: 0 8px 20px rgba(45, 110, 150, 0.08);
}

/* =========================================================
   ICON
========================================================= */

.bonus-item-icon {
  width: 48px;

  height: 48px;

  flex: 0 0 48px;

  display: grid;

  place-items: center;

  border-radius: 14px;

  background: linear-gradient(
    135deg,
    rgba(65, 170, 235, 0.14),
    rgba(110, 210, 250, 0.22)
  );

  font-size: 25px;

  box-shadow: inset 0 0 0 1px rgba(60, 145, 205, 0.12);
}

/* =========================================================
   TEXT
========================================================= */

.bonus-item > div {
  min-width: 0;

  display: flex;

  flex-direction: column;

  gap: 4px;
}

.bonus-item strong {
  color: #17324a;

  font-size: 14px;

  font-weight: 900;

  letter-spacing: 0.2px;
}

.bonus-item small {
  color: #5c7c92;

  font-size: 9px;

  font-weight: 800;

  letter-spacing: 0.7px;
}

/* =========================================================
   CLICKABLE BUTTON
========================================================= */

.bonus-button {
  width: 100%;

  appearance: none;

  cursor: pointer;

  transition:
    transform 0.16s ease,
    box-shadow 0.16s ease,
    border-color 0.16s ease;
}

.bonus-button.ready {
  border-color: rgba(40, 160, 225, 0.32);
}

.bonus-button.ready:hover {
  transform: translateY(-3px);

  border-color: var(--player-accent);

  box-shadow: 0 14px 28px rgba(35, 125, 175, 0.16);
}

.bonus-button.ready:active {
  transform: translateY(-1px);
}

/* =========================================================
   USED
========================================================= */

.bonus-button.used {
  opacity: 0.42;

  cursor: not-allowed;

  filter: grayscale(0.65);
}

.bonus-button.used small {
  color: #8898a4;
}

.bonus-button:disabled {
  cursor: not-allowed;
}

/* =========================================================
   PLAYER 2 ACCENT
========================================================= */

.player-battle-ui.p2 .bonus-item-icon {
  background: linear-gradient(
    135deg,
    rgba(237, 86, 124, 0.12),
    rgba(255, 150, 180, 0.22)
  );
}

.player-battle-ui.p2 .bonus-button.ready:hover {
  border-color: var(--player-accent);
}

/* =========================================================
   MOBILE
========================================================= */

@media (max-width: 768px) {
  .bonus-panel {
    margin: 14px auto 150px;

    padding: 14px;

    border-radius: 18px;
  }

  .bonus-list {
    grid-template-columns: 1fr;
  }

  .bonus-item {
    min-height: 74px;

    padding: 12px;
  }

  .bonus-item-icon {
    width: 42px;

    height: 42px;

    flex-basis: 42px;

    font-size: 22px;
  }
}

.card-combat-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;

  align-items: end;
}


.card-combat-stats > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}


.card-combat-stats > div:last-child {
  text-align: right;
}


.card-combat-stats span {
  font-size: 8px;
  font-weight: 900;
  opacity: .7;
}


.card-combat-stats strong {
  font-size: 20px;
  line-height: 1;
}


.bench-card-stats {
  grid-template-columns:
    1fr
    1fr
    auto;
}


.bench-card-stats small {
  align-self: end;
  text-align: right;
}
</style>
