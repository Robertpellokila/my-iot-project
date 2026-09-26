<script setup>
import { computed, onMounted, watch } from "vue";

import { supabase } from "../lib/supabase";

// =========================================================
// COMPONENTS
// =========================================================

import PlayerHud from "../components/battle/PlayerHud.vue";

import BattleHeaderCenter from "../components/battle/BattleHeaderCenter.vue";

import BattleField from "../components/battle/BattleField.vue";

import BattleFooter from "../components/battle/BattleFooter.vue";

import CodingQuestionModal from "../components/battle/CodingQuestionModal.vue";

import BattleWinner from "../components/battle/BattleWinner.vue";

// =========================================================
// COMPOSABLES
// =========================================================

import { useBattleAudio } from "../composables/battle/useBattleAudio";

import { useBattleFullscreen } from "../composables/battle/useBattleFullscreen";

import { useBattleEngine } from "../composables/battle/useBattleEngine";

import { useBattleRFID } from "../composables/battle/useBattleRFID";

// =========================================================
// PROPS
//
// LOCAL:
//
// <BattleArena />
//
// PUBLIC TV:
//
// <BattleArena
//   display-only
//   :shared-battle="battle"
//   :shared-player1-active="..."
//   :shared-player2-active="..."
//   :shared-player1-bench="..."
//   :shared-player2-bench="..."
//   :latest-battle-event="..."
// />
// =========================================================

const props = defineProps({
  displayOnly: {
    type: Boolean,
    default: false,
  },

  sharedBattle: {
    type: Object,
    default: null,
  },

  sharedPlayer1Active: {
    type: Array,
    default: () => [],
  },

  sharedPlayer2Active: {
    type: Array,
    default: () => [],
  },

  sharedPlayer1Bench: {
    type: Array,
    default: () => [],
  },

  sharedPlayer2Bench: {
    type: Array,
    default: () => [],
  },

  latestBattleEvent: {
    type: Object,
    default: null,
  },
});

// =========================================================
// DISPLAY MODE
// =========================================================

const isDisplayOnly = computed(() => Boolean(props.displayOnly));

// =========================================================
// AUDIO
// =========================================================

const {
  soundEnabled,
  audioUnlocked,

  unlockAudio,
  playSound,
  toggleSound,

  playBattleEndSounds,

  resetEndSound,
} = useBattleAudio();

// =========================================================
// FULLSCREEN
// =========================================================

const { isFullscreen, toggleFullscreen } = useBattleFullscreen();

// =========================================================
// RFID REFERENCE
//
// Engine membutuhkan isReaderBusy().
// RFID sendiri membutuhkan Engine.
//
// Closure ini memutus circular dependency.
// =========================================================

let rfidInstance = null;

// =========================================================
// BATTLE ENGINE
// =========================================================

const engine = useBattleEngine({
  supabase,

  playSound,

  playBattleEndSounds,

  isDisplayOnly,

  isReaderBusy: (player) => {
    return rfidInstance?.isReaderBusy(player) ?? false;
  },

  // =====================================================
  // ORIGINAL BATTLE CONFIG
  // =====================================================

  basePlayerHp: 200,

  maxActive: 4,

  maxBench: 4,

  maxTotalCards: 8,

  maxSkill: 100,

  basicSkillGain: 25,

  hitSkillGain: 15,

  defenseSkillGain: 10,

  defenseReduction: 0.5,

  ultimateMultiplier: 2,

  healPercent: 0.35,

  questionIntervalRounds: 5,

  questionTable: "coding_questions",
});

// =========================================================
// ENGINE STATE
// =========================================================

const {
  battleState,

  currentTurn,

  winner,

  isActing,

  roundCount,

  displayRound: localDisplayRound,

  selectedTurnAction,

  selectedBattleCard,

  selectedSkill,

  summonMode,

  player1BattleHp,

  player2BattleHp,

  player1MaxHp,

  player2MaxHp,

  player1Skill,

  player2Skill,

  player1Defending,

  player2Defending,

  player1SynergyShield,

  player2SynergyShield,

  player1AttackDebuff,

  player2AttackDebuff,

  player1Hand,

  player2Hand,

  player1CanSummon,

  player2CanSummon,

  cards,

  bench,

  skills,

  synergy,

  effects,

  questions,

  chooseSummon,

  cancelSummon,

  summonBattleCard,

  continueAfterQuestion: engineContinueAfterQuestion,
} = engine;

// =========================================================
// BENCH REFS
// =========================================================

const {
  selectedBenchCard,

  swapMode,
} = bench;

// =========================================================
// SKILL REFS
// =========================================================

const {
  player1UltimateUsed,

  player2UltimateUsed,

  player1HealUsed,

  player2HealUsed,

  player1CanHeal,

  player2CanHeal,

  player1CanUltimate,

  player2CanUltimate,
} = skills;

// =========================================================
// SYNERGY REFS
// =========================================================

const {
  player1SelectedSynergyInfo,

  player2SelectedSynergyInfo,

  player1CanUseSynergy,

  player2CanUseSynergy,
} = synergy;

// =========================================================
// EFFECT REFS
// =========================================================

const {
  player1ProfileEffect,

  player2ProfileEffect,

  player1ProfilePopup,

  player2ProfilePopup,
} = effects;

// =========================================================
// QUESTION REFS
// =========================================================

const {
  questionMode,

  questionLoading,

  questionError,

  currentQuestion,

  selectedQuestionAnswer,

  questionResult,
} = questions;

// =========================================================
// FETCH RFID CARD
// =========================================================

const fetchCardData = async (uid) => {
  if (!uid) {
    return null;
  }

  try {
    const { data, error } = await supabase
      .from("game_cards")
      .select("*")
      .eq("uid", uid)
      .maybeSingle();

    if (error) {
      console.error("fetchCardData:", error);

      return null;
    }

    if (!data) {
      console.warn("Card RFID tidak ditemukan:", uid);

      return null;
    }

    return data;
  } catch (error) {
    console.error("fetchCardData failed:", error);

    return null;
  }
};

// =========================================================
// RFID
// =========================================================

const rfidEnabled = computed(() => !isDisplayOnly.value);

const rfid = useBattleRFID({
  supabase,

  // =====================================================
  // ENGINE
  // =====================================================

  cards,

  battleState,

  currentTurn,

  winner,

  selectedTurnAction,

  summonMode,

  swapMode,

  isActing,

  questionMode,

  // =====================================================
  // HP
  // =====================================================

  player1BattleHp,

  player2BattleHp,

  player1MaxHp,

  player2MaxHp,

  basePlayerHp: 200,

  // =====================================================
  // CARD
  // =====================================================

  fetchCardData,

  summonBattleCard,

  // =====================================================
  // EFFECT
  // =====================================================

  playSound,

  setProfileEffect: effects.setProfileEffect,

  showProfileMessage: effects.showProfileMessage,

  // =====================================================
  // MODE
  // =====================================================

  enabled: rfidEnabled,
});

rfidInstance = rfid;

// =========================================================
// RFID STATE
// =========================================================

const { readerProcessing } = rfid;

// =========================================================
// SHARED BATTLE
// =========================================================

const displayBattle = computed(() => {
  if (!isDisplayOnly.value) {
    return null;
  }

  return props.sharedBattle ?? null;
});

const displayPlayer1Name = computed(
  () => displayBattle.value?.player1_name ?? "Player 1",
);

const displayPlayer2Name = computed(
  () => displayBattle.value?.player2_name ?? "Player 2",
);
// =========================================================
// DISPLAY HP
// =========================================================

const displayPlayer1Hp = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player1_hp ?? 200);
  }

  return player1BattleHp.value;
});

const displayPlayer2Hp = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player2_hp ?? 200);
  }

  return player2BattleHp.value;
});

const displayPlayer1MaxHp = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player1_max_hp ?? 200);
  }

  return player1MaxHp.value;
});

const displayPlayer2MaxHp = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player2_max_hp ?? 200);
  }

  return player2MaxHp.value;
});

// =========================================================
// DISPLAY SKILL
// =========================================================

const displayPlayer1Skill = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player1_skill ?? 0);
  }

  return player1Skill.value;
});

const displayPlayer2Skill = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player2_skill ?? 0);
  }

  return player2Skill.value;
});

// =========================================================
// DISPLAY CURRENT TURN
// =========================================================

const displayCurrentTurn = computed(() => {
  if (displayBattle.value) {
    return displayBattle.value.current_turn ?? "p1";
  }

  return currentTurn.value;
});

// =========================================================
// DISPLAY WINNER
// =========================================================

const displayWinner = computed(() => {
  if (displayBattle.value) {
    return displayBattle.value.winner ?? null;
  }

  return winner.value;
});

// =========================================================
// DISPLAY STATE
// =========================================================

const displayBattleState = computed(() => {
  if (!isDisplayOnly.value) {
    return battleState.value;
  }

  const status = String(displayBattle.value?.status ?? "waiting")
    .trim()
    .toLowerCase();

  if (status === "waiting") {
    return "waiting_p1";
  }

  /*
   * Public BattleField tetap menggunakan
   * layout battle_ready ketika server berada
   * dalam ready/battle/question/finished.
   */

  if (
    status === "ready" ||
    status === "battle" ||
    status === "question" ||
    status === "finished"
  ) {
    return "battle_ready";
  }

  return "waiting_p1";
});

// =========================================================
// DISPLAY ROUND
// =========================================================

const displayRound = computed(() => {
  if (displayBattle.value) {
    return Math.max(
      1,

      Number(displayBattle.value.round ?? 1),
    );
  }

  return localDisplayRound.value;
});

// =========================================================
// DISPLAY CARDS
// =========================================================

const displayPlayer1Active = computed(() => {
  if (isDisplayOnly.value) {
    return props.sharedPlayer1Active ?? [];
  }

  return cards.player1ActiveCards.value;
});

const displayPlayer2Active = computed(() => {
  if (isDisplayOnly.value) {
    return props.sharedPlayer2Active ?? [];
  }

  return cards.player2ActiveCards.value;
});

const displayPlayer1Bench = computed(() => {
  if (isDisplayOnly.value) {
    return props.sharedPlayer1Bench ?? [];
  }

  return cards.player1BenchCards.value;
});

const displayPlayer2Bench = computed(() => {
  if (isDisplayOnly.value) {
    return props.sharedPlayer2Bench ?? [];
  }

  return cards.player2BenchCards.value;
});

// =========================================================
// DISPLAY BUFFS
// =========================================================

const displayPlayer1Defending = computed(() => {
  if (displayBattle.value) {
    return Boolean(displayBattle.value.player1_defending ?? false);
  }

  return player1Defending.value;
});

const displayPlayer2Defending = computed(() => {
  if (displayBattle.value) {
    return Boolean(displayBattle.value.player2_defending ?? false);
  }

  return player2Defending.value;
});

const displayPlayer1Shield = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player1_synergy_shield ?? 0);
  }

  return player1SynergyShield.value;
});

const displayPlayer2Shield = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player2_synergy_shield ?? 0);
  }

  return player2SynergyShield.value;
});

const displayPlayer1Debuff = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player1_attack_debuff ?? 0);
  }

  return player1AttackDebuff.value;
});

const displayPlayer2Debuff = computed(() => {
  if (displayBattle.value) {
    return Number(displayBattle.value.player2_attack_debuff ?? 0);
  }

  return player2AttackDebuff.value;
});

// =========================================================
// DISPLAY EFFECT
// =========================================================

const displayP1Effect = computed(() => player1ProfileEffect.value);

const displayP2Effect = computed(() => player2ProfileEffect.value);

const displayP1Popup = computed(() => player1ProfilePopup.value);

const displayP2Popup = computed(() => player2ProfilePopup.value);

// =========================================================
// DISPLAY TURN TEXT
// =========================================================

const displayTurnText = computed(() => {
  // =====================================================
  // WINNER
  // =====================================================
  if (displayWinner.value === "p1") {
    return `${displayPlayer1Name.value.toUpperCase()} WINS`;
  }

  if (displayWinner.value === "p2") {
    return `${displayPlayer2Name.value.toUpperCase()} WINS`;
  }

  // =====================================================
  // PUBLIC TV
  // =====================================================

  if (isDisplayOnly.value) {
    const status = String(displayBattle.value?.status ?? "waiting")
      .trim()
      .toLowerCase();

    if (status === "waiting") {
      return "SCAN P1 & P2";
    }

    if (status === "question" || displayBattle.value?.question_active) {
      return "CODING CHALLENGE";
    }

    if (status === "finished") {
      return "BATTLE FINISHED";
    }

    return displayCurrentTurn.value === "p2"
      ? `${displayPlayer2Name.value.toUpperCase()} TURN`
      : `${displayPlayer1Name.value.toUpperCase()} TURN`;
  }

  // =====================================================
  // LOCAL INITIAL RFID
  // =====================================================

  if (battleState.value !== "battle_ready") {
    const p1Ready = cards.player1Cards.value.length > 0;

    const p2Ready = cards.player2Cards.value.length > 0;

    if (readerProcessing.value.p1 && readerProcessing.value.p2) {
      return "SCANNING BOTH PLAYERS";
    }

    if (readerProcessing.value.p1) {
      return "SCANNING PLAYER 1";
    }

    if (readerProcessing.value.p2) {
      return "SCANNING PLAYER 2";
    }

    if (!p1Ready && !p2Ready) {
      return "SCAN P1 & P2";
    }

    return p1Ready ? "WAITING FOR PLAYER 2" : "WAITING FOR PLAYER 1";
  }

  // =====================================================
  // QUESTION
  // =====================================================

  if (questionMode.value) {
    return "CODING CHALLENGE";
  }

  // =====================================================
  // SUMMON
  // =====================================================

  if (summonMode.value) {
    return currentTurn.value === "p1" ? "P1 — SCAN SUMMON" : "P2 — SCAN SUMMON";
  }

  // =====================================================
  // SWAP
  // =====================================================

  if (swapMode.value) {
    return currentTurn.value === "p1"
      ? "P1 — SELECT SWAP TARGET"
      : "P2 — SELECT SWAP TARGET";
  }

  // =====================================================
  // NORMAL
  // =====================================================

  return currentTurn.value === "p1" ? "PLAYER 1 TURN" : "PLAYER 2 TURN";
});

// =========================================================
// REALTIME PUBLIC EFFECTS
// =========================================================

const handleRealtimeBattleEvent = (event) => {
  if (!event || !isDisplayOnly.value) {
    return;
  }

  const type = String(event.type ?? "")
    .trim()
    .toLowerCase();

  const payload = event.payload ?? {};

  const sourcePlayer = event.source_player ?? payload.source_player ?? null;

  const targetPlayer = event.target_player ?? payload.target_player ?? null;

  // =====================================================
  // ACTION REQUEST
  // =====================================================

  if (type === "action_request") {
    return;
  }

  // =====================================================
  // ATTACK
  // =====================================================

  if (type === "attack") {
    void playSound("attack");

    const damage = Number(payload.damage ?? payload.amount ?? 0);

    if (targetPlayer && damage > 0) {
      effects.showDamage(targetPlayer, damage);
    }

    return;
  }

  // =====================================================
  // DAMAGE
  // =====================================================

  if (type === "damage") {
    const damage = Number(payload.damage ?? payload.amount ?? 0);

    if (targetPlayer) {
      effects.showDamage(targetPlayer, damage);
    }

    return;
  }

  // =====================================================
  // DEFENSE
  // =====================================================

  if (type === "defense") {
    if (sourcePlayer) {
      effects.showDefense(sourcePlayer);
    }

    return;
  }

  // =====================================================
  // HEAL
  // =====================================================

  if (type === "heal") {
    const amount = Number(payload.amount ?? payload.heal ?? 0);

    if (sourcePlayer) {
      effects.showHeal(sourcePlayer, amount);
    }

    return;
  }

  // =====================================================
  // ULTIMATE
  // =====================================================

  if (type === "ultimate") {
    if (sourcePlayer) {
      effects.showUltimate(sourcePlayer);
    }

    return;
  }

  // =====================================================
  // SYNERGY
  // =====================================================

  if (type === "synergy") {
    if (sourcePlayer) {
      effects.showSynergy(
        sourcePlayer,

        payload.message ?? payload.text ?? "✨ SYNERGY",
      );
    }

    return;
  }

  // =====================================================
  // SUMMON
  // =====================================================

  if (type === "summon") {
    if (sourcePlayer) {
      effects.showSummon(
        sourcePlayer,

        Number(payload.hp_gain ?? payload.hp ?? 0),
      );
    }

    return;
  }

  // =====================================================
  // BENCH
  // =====================================================

  if (type === "bench") {
    void playSound("bench");

    return;
  }

  // =====================================================
  // SWAP
  // =====================================================

  if (type === "swap") {
    void playSound("swap");

    return;
  }

  // =====================================================
  // WARNING
  // =====================================================

  if (type === "warning") {
    if (sourcePlayer) {
      effects.showWarning(
        sourcePlayer,

        payload.message ?? "WARNING",
      );
    }

    return;
  }

  // =====================================================
  // WIN
  // =====================================================

  if (type === "win") {
    void playSound("win", 0.95);

    return;
  }

  // =====================================================
  // LOSE
  // =====================================================

  if (type === "lose") {
    void playSound("lose", 0.65);
  }
};

// =========================================================
// WATCH PUBLIC BATTLE EVENT
// =========================================================

watch(
  () => props.latestBattleEvent,

  (event) => {
    if (!event) {
      return;
    }

    handleRealtimeBattleEvent(event);
  },
);

// =========================================================
// CARD CLICK
// =========================================================

const handleActiveCardClick = (player, card) => {
  if (isDisplayOnly.value) {
    return;
  }

  bench.handleActiveCardClick(player, card);
};

// =========================================================
// ACTIVE -> BENCH
// =========================================================

const handleMoveToBench = (player, card) => {
  if (isDisplayOnly.value) {
    return;
  }

  void bench.moveToBench(player, card);
};

// =========================================================
// BENCH -> ACTIVE
// =========================================================

const handleReturnFromBench = (player, card) => {
  if (isDisplayOnly.value) {
    return;
  }

  void bench.returnFromBench(player, card);
};

// =========================================================
// PLAY SKILL
// =========================================================

const handleSkill = (player, skill) => {
  if (isDisplayOnly.value) {
    return;
  }

  void skills.playSkill(player, skill);
};

// =========================================================
// PLAY SYNERGY
// =========================================================

const handleSynergy = (player) => {
  if (isDisplayOnly.value) {
    return;
  }

  void synergy.playSynergy(player);
};

// =========================================================
// SUMMON
// =========================================================

const handleSummon = (player) => {
  if (isDisplayOnly.value) {
    return;
  }

  if (summonMode.value && currentTurn.value === player) {
    cancelSummon();

    return;
  }

  chooseSummon(player);
};

// =========================================================
// CANCEL SWAP
// =========================================================

const handleCancelSwap = () => {
  if (isDisplayOnly.value) {
    return;
  }

  bench.cancelSwap();
};

// =========================================================
// QUESTION ANSWER
// =========================================================

const handleQuestionAnswer = (index) => {
  if (isDisplayOnly.value) {
    return;
  }

  questions.answerCodingQuestion(index);
};

// =========================================================
// QUESTION CONTINUE
// =========================================================

const handleQuestionContinue = () => {
  if (isDisplayOnly.value) {
    return;
  }

  /*
   * Jangan panggil
   * questions.continueAfterQuestion()
   * secara langsung.
   *
   * Engine harus ikut melepas
   * isActing.
   */

  engineContinueAfterQuestion();
};

// =========================================================
// RESET ARENA
// =========================================================

const resetArena = () => {
  if (isDisplayOnly.value) {
    return;
  }

  // =====================================================
  // RESET GAME
  // =====================================================

  engine.resetArena();

  // =====================================================
  // RESET RFID UID + PROCESSING
  // =====================================================

  rfid.resetRFID();

  // =====================================================
  // ALLOW END SOUND NEXT BATTLE
  // =====================================================

  resetEndSound();
};

// =========================================================
// DISPLAY MODE CHANGED
//
// Normalnya BattleArena tidak berganti mode saat mounted.
// Ini hanya safety agar listener RFID tidak tertinggal.
// =========================================================

watch(
  isDisplayOnly,

  async (displayOnly) => {
    if (displayOnly) {
      await rfid.stopBattleListener();

      return;
    }

    rfid.setupBattleListener();
  },
);

// =========================================================
// MOUNT
// =========================================================

onMounted(() => {
  /*
   * RFID hanya aktif pada local/admin arena.
   */

  if (!isDisplayOnly.value) {
    rfid.setupBattleListener();
  }
});
</script>

<template>
  <div
    class="battle-game"
    :class="{
      'battle-display-only': isDisplayOnly,
    }"
    tabindex="0"
    @pointerdown.capture="unlockAudio"
    @keydown.capture="unlockAudio"
  >
    <!-- ===================================================
         HEADER
    ==================================================== -->

    <header class="battle-header">
      <!-- =================================================
           PLAYER 1
      ================================================== -->

      <PlayerHud
        player="p1"
        :name="displayBattle?.player1_name ?? 'Player 1'"
        avatar="👦🏻"
        :hp="displayPlayer1Hp"
        :max-hp="displayPlayer1MaxHp"
        :skill="displayPlayer1Skill"
        :active-count="displayPlayer1Active.length"
        :bench-count="displayPlayer1Bench.length"
        :current-turn="displayCurrentTurn"
        :battle-state="displayBattleState"
        :battle-ready="displayBattleState === 'battle_ready'"
        :winner="displayWinner"
        :ultimate-used="isDisplayOnly ? false : player1UltimateUsed"
        :can-ultimate="isDisplayOnly ? false : player1CanUltimate"
        :defending="displayPlayer1Defending"
        :synergy-shield="displayPlayer1Shield"
        :attack-debuff="displayPlayer1Debuff"
        :effect="displayP1Effect"
        :popup="displayP1Popup"
      />

      <!-- =================================================
           CENTER
      ================================================== -->

      <BattleHeaderCenter
        :turn-text="displayTurnText"
        :current-turn="displayCurrentTurn"
        :round="displayRound"
        :battle-code="sharedBattle?.code ?? ''"
        :sound-enabled="soundEnabled"
        :is-fullscreen="isFullscreen"
        :display-only="isDisplayOnly"
        @toggle-sound="toggleSound"
        @toggle-fullscreen="toggleFullscreen"
      />

      <!-- =================================================
           PLAYER 2
      ================================================== -->

      <PlayerHud
        player="p2"
        :name="displayBattle?.player2_name ?? 'Player 2'"
        avatar="🧑🏽‍🦱"
        :hp="displayPlayer2Hp"
        :max-hp="displayPlayer2MaxHp"
        :skill="displayPlayer2Skill"
        :active-count="displayPlayer2Active.length"
        :bench-count="displayPlayer2Bench.length"
        :current-turn="displayCurrentTurn"
        :battle-state="displayBattleState"
        :battle-ready="displayBattleState === 'battle_ready'"
        :winner="displayWinner"
        :ultimate-used="isDisplayOnly ? false : player2UltimateUsed"
        :can-ultimate="isDisplayOnly ? false : player2CanUltimate"
        :defending="displayPlayer2Defending"
        :synergy-shield="displayPlayer2Shield"
        :attack-debuff="displayPlayer2Debuff"
        :effect="displayP2Effect"
        :popup="displayP2Popup"
      />
    </header>

    <!-- ===================================================
         BATTLE FIELD
    ==================================================== -->

    <BattleField
      :player1-active="displayPlayer1Active"
      :player2-active="displayPlayer2Active"
      :player1-bench="displayPlayer1Bench"
      :player2-bench="displayPlayer2Bench"
      :latest-battle-event="latestBattleEvent"
      :selected-card="isDisplayOnly ? null : selectedBattleCard"
      :selected-bench-card="isDisplayOnly ? null : selectedBenchCard"
      :current-turn="displayCurrentTurn"
      :battle-state="displayBattleState"
      :winner="displayWinner"
      :selected-turn-action="isDisplayOnly ? null : selectedTurnAction"
      :is-acting="isDisplayOnly ? false : isActing"
      :summon-mode="isDisplayOnly ? false : summonMode"
      :swap-mode="isDisplayOnly ? false : swapMode"
      :interactive="!isDisplayOnly"
      @active-card-click="handleActiveCardClick"
      @move-to-bench="handleMoveToBench"
      @return-from-bench="handleReturnFromBench"
    />

    <!-- ===================================================
         LOCAL CONTROLS
    ==================================================== -->

    <BattleFooter
      v-if="!isDisplayOnly"
      :player1-hand="player1Hand"
      :player2-hand="player2Hand"
      :selected-card="selectedBattleCard"
      :selected-skill="selectedSkill"
      :current-turn="currentTurn"
      :battle-state="battleState"
      :winner="winner"
      :selected-turn-action="selectedTurnAction"
      :is-acting="isActing"
      :summon-mode="summonMode"
      :swap-mode="swapMode"
      :player1-ultimate-used="player1UltimateUsed"
      :player2-ultimate-used="player2UltimateUsed"
      :player1-heal-used="player1HealUsed"
      :player2-heal-used="player2HealUsed"
      :player1-can-ultimate="player1CanUltimate"
      :player2-can-ultimate="player2CanUltimate"
      :player1-can-heal="player1CanHeal"
      :player2-can-heal="player2CanHeal"
      :player1-skill="player1Skill"
      :player2-skill="player2Skill"
      :player1-can-summon="player1CanSummon"
      :player2-can-summon="player2CanSummon"
      :player1-synergy-info="player1SelectedSynergyInfo"
      :player2-synergy-info="player2SelectedSynergyInfo"
      :player1-can-use-synergy="player1CanUseSynergy"
      :player2-can-use-synergy="player2CanUseSynergy"
      :can-use-skill="skills.canUseSkill"
      :interactive="true"
      @play-skill="handleSkill"
      @use-skill="handleSkill"
      @play-synergy="handleSynergy"
      @use-synergy="handleSynergy"
      @summon="handleSummon"
      @cancel-summon="cancelSummon"
      @cancel-swap="handleCancelSwap"
    />

    <!-- ===================================================
         CODING QUESTION
    ==================================================== -->

    <CodingQuestionModal
      v-if="!isDisplayOnly"
      :visible="questionMode"
      :round="displayRound"
      :loading="questionLoading"
      :error="questionError"
      :question="currentQuestion"
      :selected-answer="selectedQuestionAnswer"
      :result="questionResult"
      :allow-answer="!questionLoading"
      :allow-continue="Boolean(questionResult)"
      @answer="handleQuestionAnswer"
      @continue="handleQuestionContinue"
    />

    <!-- ===================================================
         WINNER
    ==================================================== -->

    <BattleWinner
      :winner="displayWinner"
      :player1-name="displayBattle?.player1_name ?? 'Player 1'"
      :player2-name="displayBattle?.player2_name ?? 'Player 2'"
      :show-reset="!isDisplayOnly"
      @reset="resetArena"
    />
  </div>
</template>

<!--
  PENTING:

  STYLE INI SENGAJA TIDAK "scoped".

  BattleArena sekarang terdiri dari child components.
  Kalau style dibuat scoped, selector dari BattleArena tidak
  bisa menjangkau DOM di dalam PlayerHud / BattleField /
  BattleFooter dengan cara yang sama seperti file monolith lama.

  Jadi wrapper-level original styles dibuat GLOBAL.
-->

<style>
/* =========================================================
   GENERAL
========================================================= */

* {
  box-sizing: border-box;
}

button {
  font: inherit;
}

/* =========================================================
   BATTLE ROOT
========================================================= */

.battle-game {
  width: 100%;

  height: 100vh;

  min-width: 1200px;

  min-height: 760px;

  display: flex;

  flex-direction: column;

  overflow: hidden;

  position: relative;

  color: white;

  outline: none;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    "Segoe UI",
    sans-serif;

  background: #020713;
}

/* =========================================================
   HEADER
========================================================= */

.battle-header {
  height: 128px;

  flex-shrink: 0;

  display: grid;

  grid-template-columns:
    1fr
    310px
    1fr;

  position: relative;

  z-index: 50;

  background: linear-gradient(180deg, #071227, #030a18);

  box-shadow: 0 10px 35px rgba(0, 0, 0, 0.75);
}

/* =========================================================
   PLAYER HUD
========================================================= */

.battle-game .player-hud {
  display: flex;

  align-items: center;

  gap: 15px;

  padding: 13px 25px;

  position: relative;

  overflow: visible;
}

.battle-game .hud-blue {
  border-bottom: 3px solid #159dff;

  background: linear-gradient(90deg, rgba(0, 124, 255, 0.23), transparent);
}

.battle-game .hud-red {
  justify-content: flex-end;

  border-bottom: 3px solid #ff3156;

  background: linear-gradient(270deg, rgba(255, 23, 66, 0.22), transparent);
}

.battle-game .hud-current-blue {
  box-shadow: inset 0 0 35px rgba(0, 178, 255, 0.18);
}

.battle-game .hud-current-red {
  box-shadow: inset 0 0 35px rgba(255, 24, 60, 0.18);
}

/* =========================================================
   PLAYER AVATAR
========================================================= */

.battle-game .player-avatar {
  width: 68px;

  height: 68px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border-radius: 50%;

  font-size: 34px;

  background: #101a30;
}

.battle-game .avatar-blue {
  border: 4px solid #20c7ff;

  box-shadow: 0 0 22px rgba(0, 180, 255, 0.75);
}

.battle-game .avatar-red {
  border: 4px solid #ff3d60;

  box-shadow: 0 0 22px rgba(255, 30, 70, 0.7);
}

/* =========================================================
   PLAYER STATUS
========================================================= */

.battle-game .player-status {
  width: 100%;

  max-width: 500px;
}

.battle-game .player-status-right {
  text-align: right;
}

.battle-game .player-name {
  display: flex;

  justify-content: space-between;

  margin-bottom: 6px;

  font-size: 15px;

  font-weight: 900;
}

.battle-game .pokemon-count {
  color: #9fb1ca;

  font-size: 8px;

  font-weight: 700;
}

/* =========================================================
   FULLSCREEN
========================================================= */

.battle-game:fullscreen {
  width: 100vw;

  height: 100vh;

  min-width: 1200px;

  min-height: 760px;
}

/* =========================================================
   PUBLIC TV
========================================================= */

.battle-display-only {
  height: 100vh;
}

/* =========================================================
   IMPORTANT LAYOUT SUPPORT
========================================================= */

.battle-game > .arena,
.battle-game > .battle-field {
  flex: 1 1 auto;

  min-height: 0;
}

.battle-game > .battle-footer {
  flex: 0 0 auto;
}

/* =========================================================
   SMALLER SCREEN SAFETY

   Original arena memang dirancang untuk desktop / TV
   dengan minimum width 1200px.

   Kita tidak mengubah layout menjadi mobile agar visual
   BattleArena tidak berubah seperti refactor sebelumnya.
========================================================= */

@media (max-width: 1199px) {
  .battle-game {
    overflow: auto;
  }
}
</style>
