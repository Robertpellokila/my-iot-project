<script setup>
import SkillIcon from '../components/battle/SkillIcon.vue';
import PlayerActionPanel from '../components/battle/PlayerActionPanel.vue';
import { useActionDialogFocus } from '../composables/battle/useActionDialogFocus.js';
import QuizBonusChoices from '../components/battle/QuizBonusChoices.vue';
import {effectSummary,synergyRuleState} from '../lib/battle/battleRuleCatalog.js';
import { skillCooldown, skillApCost } from '../lib/battle/skillState.js';
import {defineAsyncComponent} from 'vue';
import {EMPTY_WORKSPACE} from '../lib/questions/scratchBlocks.js';
const BlockWorkspace=defineAsyncComponent(()=>import('../components/questions/BlockWorkspace.vue'));
import QuizTimer from '../components/questions/QuizTimer.vue';
import QuizBlockList from '../components/questions/QuizBlockList.vue';
import { codeLines, shuffleItems } from '../lib/questions/questionModel.js';
import { quizClockState } from '../lib/questions/quizClock.js';
import { ref, computed, onMounted, onUnmounted, watch } from "vue";

import { useRoute } from "vue-router";

import { supabase } from "../lib/supabase";

import { useBattleSession } from "../composables/battle/useBattleSession";

import { useBattleUiSync } from "../composables/battle/useBattleUiSync";
import { spotlightTurn } from '../utils/battleSpotlight.js';

import BattleZoneStack from "../components/battle/BattleZoneStack.vue";
import CardStatusVfx from "../components/battle/CardStatusVfx.vue";
import { normalizeBattleStatusKey } from "../composables/battle/elementalStatus.js";
import { playerErrorMessage, safePlayerMessage } from "../utils/playerErrorMessage.js";
import { formatTcgType, getTcgComboTypeKey } from "../utils/tcgTypes.js";

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

const playerAvatarOptions = [
  "🐻", "🐼", "🐸", "🐱", "🐶", "🐰", "🦊", "🐵",
  "🐨", "🐯", "🐧", "🐙", "🦄", "🐲", "🐤", "🐢",
];

const avatarPickerOpen = ref(false);
const avatarDraft = ref("");
const avatarSaving = ref(false);
const avatarSaveError = ref("");

const ownAvatar = computed(() => {
  const key = player.value === "p1" ? "player1_avatar_url" : "player2_avatar_url";
  return String(battle.value?.[key] ?? "").trim();
});

const ownAvatarImage = computed(() =>
  /^(https?:\/\/|\/|data:image\/)/i.test(ownAvatar.value) ? ownAvatar.value : "",
);
const avatarSelectionRequired = computed(() =>
  Boolean(battle.value) &&
  !ownAvatarImage.value &&
  !playerAvatarOptions.includes(ownAvatar.value),
);

const openAvatarPicker = () => {
  avatarSaveError.value = "";
  avatarDraft.value = playerAvatarOptions.includes(ownAvatar.value)
    ? ownAvatar.value
    : "";
  avatarPickerOpen.value = true;
};

const savePlayerAvatar = async () => {
  if (!playerAvatarOptions.includes(avatarDraft.value) || avatarSaving.value) return;
  avatarSaving.value = true;
  avatarSaveError.value = "";
  try {
    const { data, error: rpcError } = await supabase.rpc("set_battle_player_avatar", {
      p_code: code.value,
      p_player: player.value,
      p_token: token.value,
      p_avatar: avatarDraft.value,
    });
    if (rpcError) throw rpcError;
    if (!data?.ok) throw new Error(data?.message || "Avatar belum berhasil disimpan.");

    const key = player.value === "p1" ? "player1_avatar_url" : "player2_avatar_url";
    if (battle.value) battle.value[key] = avatarDraft.value;
    avatarPickerOpen.value = false;
  } catch (saveError) {
    avatarSaveError.value = playerErrorMessage(saveError, "Avatar belum berhasil disimpan. Coba lagi.");
  } finally {
    avatarSaving.value = false;
  }
};

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

  refreshBattle,

  latestBattleEvent,

  loadBattle,
} = useBattleSession();

// =========================================================
// LOADING UX
// Full-screen loader hanya untuk initial connection.
// Refresh setelah action (Fusion/Special Skill/etc.) tetap menjaga arena terlihat.
// =========================================================

const initialBattleLoading = computed(() =>
  Boolean(loading.value && !battle.value),
);

const battleRefreshing = computed(() =>
  Boolean(loading.value && battle.value),
);

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
const selectedSpecialOption = ref('');
const selectedSpecialBenchId = ref('');
const selectedSpecialTargetIds = ref([]);

// =========================================================
// PHASE 3D.7 - FUSION UI
// =========================================================

const fusionModalOpen = ref(false);
const runtimeFusions = ref([]);
const fusionLoading = ref(false);
const fusionLoadError = ref("");
const fusionLastMessage = ref("");
const selectedFusionRecipeId = ref(null);

const comboAttackModalOpen = ref(false);
const comboParticipantIds = ref([]);
const comboPrimaryCardId = ref(null);
const comboTargetCardId = ref(null);
const comboRuleCatalog = ref([]);

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
      playerErrorMessage(err, "Fusion history belum dapat dimuat. Coba muat ulang battle.");
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

let graveyardChannel = null;

const getCardId = (card) =>
  card?.battleId ?? card?.battle_card_id ?? card?.battleCardId ??
  card?.id ?? card?.battle_id ?? card?.uid ?? null;

const getBenchReturnCount = (card) =>
  Number(card?.benchReturnCount ?? card?.bench_return_count ?? 0);

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
// HP BAR HELPERS
// =========================================================

const getCardCurrentHp = (card) =>
  Math.max(
    0,
    Number(
      card?.current_hp ??
      card?.currentHp ??
      card?.hp ??
      0,
    ) || 0,
  );

const getCardMaxHp = (card) =>
  Math.max(
    1,
    Number(
      card?.base_hp ??
      card?.baseHp ??
      card?.hp ??
      1,
    ) || 1,
  );

const getCardHpPercent = (card) =>
  Math.max(
    0,
    Math.min(
      100,
      (getCardCurrentHp(card) / getCardMaxHp(card)) * 100,
    ),
  );

const getHpStateClass = (percent) => {
  const value = Math.max(0, Math.min(100, Number(percent) || 0));

  if (value <= 25) {
    return "critical";
  }

  if (value <= 55) {
    return "warning";
  }

  return "healthy";
};

const getCardHpState = (card) =>
  getHpStateClass(getCardHpPercent(card));

// =========================================================
// LIVE PUBLIC UI SYNC
// =========================================================

const {
  connect: connectBattleUi,
  disconnect: disconnectBattleUi,

  openViewer: syncOpenViewer,
  closeViewer: syncCloseViewer,
  focusCards: syncFocusCards,
  skillIntent: syncSkillIntent,

} = useBattleUiSync();

const sharedViewer = ref(null);
const viewedPileCard = (zone, index) => (zone === 'bench' ? benchCards.value : graveyardCards.value)[index];
const handleZoneViewerOpen = ({ zone, index = 0 } = {}) => {
  if (!['bench', 'graveyard'].includes(zone)) return;
  sharedViewer.value = { zone, index };
  if (isMyTurn.value && !questionActive.value) {
    void syncOpenViewer(zone, index, spotlightTurn(battle.value), getCardId(viewedPileCard(zone, index)));
  }
};

const handleZoneViewerClose = () => {
  sharedViewer.value = null;
  void syncCloseViewer();
};

const handleZoneViewerIndex = ({ zone, index } = {}) => {
  if (index == null || !['bench', 'graveyard'].includes(zone)) return;
  sharedViewer.value = { zone, index };
  if (isMyTurn.value && !questionActive.value) {
    void syncOpenViewer(zone, index, spotlightTurn(battle.value), getCardId(viewedPileCard(zone, index)));
  }
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
    title: safePlayerMessage(title, "BATTLE UPDATE"),
    message: safePlayerMessage(
      message,
      "Aksi belum dapat diproses. Perbarui battle lalu coba lagi.",
    ),
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
// PLAYER BATTLE SOUND SYSTEM
// =========================================================

const SOUND_FILES = {
  attack: "/sounds/attack.mp3",
  hit: "/sounds/hit.mp3",
  defense: "/sounds/defense.mp3",
  heal: "/sounds/heal.mp3",
  ultimate: "/sounds/ultimate.mp3",
  synergy: "/sounds/synergy.mp3",
  fusion: "/sounds/synergy.mp3",
  summon: "/sounds/summon.mp3",
  bench: "/sounds/bench.mp3",
  swap: "/sounds/swap.mp3",
  warning: "/sounds/warning.mp3",
  question: "/sounds/question.mp3",
  correct: "/sounds/correct.mp3",
  wrong: "/sounds/wrong.mp3",
  win: "/sounds/win.mp3",
  lose: "/sounds/lose.mp3",
};

const soundEnabled = ref(true);
const audioUnlocked = ref(false);
const audioCache = new Map();
const soundTimers = new Set();
const processedSoundEventIds = new Set();

const getAudio = (name) => {
  if (typeof Audio === "undefined") {
    return null;
  }

  const src = SOUND_FILES[name];

  if (!src) {
    return null;
  }

  if (!audioCache.has(name)) {
    const audio = new Audio(src);
    audio.preload = "auto";
    audio.playsInline = true;
    audioCache.set(name, audio);
  }

  return audioCache.get(name);
};

const preloadBattleSounds = () => {
  Object.keys(SOUND_FILES).forEach((name) => {
    const audio = getAudio(name);

    try {
      audio?.load?.();
    } catch {
      // preload is best effort only
    }
  });
};

const unlockAudio = async () => {
  if (audioUnlocked.value) {
    return true;
  }

  const probe = getAudio("question") ?? getAudio("attack");

  if (!probe) {
    audioUnlocked.value = true;
    return true;
  }

  try {
    const previousVolume = probe.volume;
    probe.volume = 0;
    probe.currentTime = 0;

    const playResult = probe.play();

    if (playResult && typeof playResult.then === "function") {
      await playResult;
    }

    probe.pause();
    probe.currentTime = 0;
    probe.volume = previousVolume || 1;

    audioUnlocked.value = true;
    return true;
  } catch (audioError) {
    console.debug("Audio masih dikunci browser:", audioError);
    return false;
  }
};

const playSound = async (name, volume = 0.78) => {
  if (!soundEnabled.value) {
    return false;
  }

  if (!audioUnlocked.value) {
    return false;
  }

  const audio = getAudio(name);

  if (!audio) {
    return false;
  }

  try {
    audio.pause();
    audio.currentTime = 0;
    audio.volume = Math.max(0, Math.min(1, Number(volume) || 0.78));

    const result = audio.play();

    if (result && typeof result.then === "function") {
      await result;
    }

    return true;
  } catch (audioError) {
    console.debug(`Sound ${name} gagal diputar:`, audioError);
    return false;
  }
};

const scheduleSound = (name, delay = 0, volume = 0.78) => {
  const timer = setTimeout(() => {
    soundTimers.delete(timer);
    void playSound(name, volume);
  }, Math.max(0, Number(delay) || 0));

  soundTimers.add(timer);
  return timer;
};

const clearScheduledSounds = () => {
  soundTimers.forEach((timer) => clearTimeout(timer));
  soundTimers.clear();
};

const stopAllBattleSounds = () => {
  clearScheduledSounds();

  audioCache.forEach((audio) => {
    try {
      audio.pause();
      audio.currentTime = 0;
    } catch {
      // ignore audio cleanup failures
    }
  });
};

const audioUnlockHandler = () => {
  void unlockAudio();
};

const registerAudioUnlock = () => {
  if (typeof window === "undefined") {
    return;
  }

  window.addEventListener("pointerdown", audioUnlockHandler, { passive: true });
  window.addEventListener("touchstart", audioUnlockHandler, { passive: true });
  window.addEventListener("keydown", audioUnlockHandler);
};

const unregisterAudioUnlock = () => {
  if (typeof window === "undefined") {
    return;
  }

  window.removeEventListener("pointerdown", audioUnlockHandler);
  window.removeEventListener("touchstart", audioUnlockHandler);
  window.removeEventListener("keydown", audioUnlockHandler);
};

const toggleBattleSound = async () => {
  soundEnabled.value = !soundEnabled.value;

  if (!soundEnabled.value) {
    stopAllBattleSounds();
    return;
  }

  const unlocked = await unlockAudio();

  if (unlocked) {
    void playSound("question", 0.28);
  }
};

const battleSoundLabel = computed(() => {
  if (!soundEnabled.value) {
    return "SOUND OFF";
  }

  return audioUnlocked.value ? "SOUND ON" : "TAP FOR SOUND";
});

const soundEventKey = (event) =>
  String(
    event?.id ??
      `${event?.type ?? "event"}:${event?.created_at ?? ""}:${event?.source_player ?? ""}:${event?.card_id ?? ""}`,
  );

const rememberSoundEvent = (event) => {
  const key = soundEventKey(event);

  if (processedSoundEventIds.has(key)) {
    return false;
  }

  processedSoundEventIds.add(key);

  if (processedSoundEventIds.size > 300) {
    const oldest = processedSoundEventIds.values().next().value;
    processedSoundEventIds.delete(oldest);
  }

  return true;
};

const handleBattleSoundEvent = (event) => {
  if (!event || !rememberSoundEvent(event)) {
    return;
  }

  const type = String(event.type ?? "").toLowerCase();
  const payload =
    event.payload && typeof event.payload === "object"
      ? event.payload
      : {};

  const targetsCurrentPlayer =
    String(event.target_player ?? payload.target_player ?? "").toLowerCase() ===
    player.value;

  switch (type) {
    case "attack": {
      void playSound("attack", 0.82);
      scheduleSound("hit", 260, targetsCurrentPlayer ? 0.92 : 0.72);
      break;
    }

    case "defense":
      void playSound("defense", 0.72);
      break;

    case "ultimate": {
      void playSound("ultimate", 0.95);

      const targetCount = Math.max(
        1,
        Number(payload?.target_count ?? 1) || 1,
      );

      const hitBursts = Math.min(targetCount, 4);

      for (let index = 0; index < hitBursts; index += 1) {
        scheduleSound(
          "hit",
          300 + index * 125,
          Math.max(0.58, 0.9 - index * 0.07),
        );
      }

      break;
    }

    case "heal":
      void playSound("heal", 0.72);
      break;

    case "synergy":
      void playSound("synergy", 0.82);
      break;

    case "special_skill": {
      const effects = Array.isArray(payload.effects) ? payload.effects : [];
      const hasDamage = effects.some((effect) =>
        String(effect?.type ?? "").toLowerCase().includes("damage"),
      );

      void playSound(hasDamage ? "ultimate" : "synergy", hasDamage ? 0.88 : 0.76);

      if (hasDamage) {
        scheduleSound("hit", 330, 0.82);
      }
      break;
    }

    case "fusion":
      void playSound("fusion", 0.9);
      break;

    case "summon":
      void playSound("summon", 0.78);
      break;

    case "bench":
      void playSound("bench", 0.6);
      break;

    case "swap":
      void playSound("swap", 0.68);
      break;

    case "card_destroyed":
      scheduleSound("warning", 180, 0.62);
      break;

    case "graveyard":
      void playSound("warning", 0.48);
      break;

    case "rfid_warning":
      if (event.source_player === player.value) {
        void playSound("warning", 0.64);
      }
      break;

    case "win":
      if (String(event.source_player ?? "").toLowerCase() === player.value) {
        void playSound("win", 0.95);
      } else {
        void playSound("lose", 0.88);
      }
      break;

    case "special_effect": {
      const effectType = String(payload?.effect_type ?? "").toLowerCase();

      if (effectType === "revive") {
        void playSound("summon", 0.78);
      } else if (effectType === "move_zone" && payload?.result?.to_zone === "graveyard") {
        void playSound("warning", 0.44);
      }
      break;
    }

    default:
      break;
  }
};

// =========================================================
// PHASE 3C.1 • NECRO SOUL REBIRTH CINEMATIC
// =========================================================

const necroRebirthCinematic = ref({
  show: false,
  phase: "idle",
  source: null,
  target: null,
});

let necroRebirthTimers = [];

const clearNecroRebirthTimers = () => {
  necroRebirthTimers.forEach((timer) => clearTimeout(timer));
  necroRebirthTimers = [];
};

const necroCardImage = (card) =>
  card?.image_url ?? card?.avatar_url ?? card?.image ?? "";

const necroRestoredHp = (card) =>
  Math.max(
    1,
    Math.round(
      (Number(card?.base_hp ?? card?.baseHp ?? card?.hp ?? 1) || 1) * 0.5,
    ),
  );

const startNecroRebirthCinematic = ({ source, target } = {}) => {
  if (!source || !target) {
    return;
  }

  clearNecroRebirthTimers();

  necroRebirthCinematic.value = {
    show: true,
    phase: "sacrifice",
    source: { ...source },
    target: { ...target },
  };

  void playSound("warning", 0.48);
  vibrateDevice([45, 35, 65]);

  necroRebirthTimers.push(
    setTimeout(() => {
      if (!necroRebirthCinematic.value.show) return;
      necroRebirthCinematic.value.phase = "soul";
      void playSound("synergy", 0.72);
    }, 620),
  );

  necroRebirthTimers.push(
    setTimeout(() => {
      if (!necroRebirthCinematic.value.show) return;
      necroRebirthCinematic.value.phase = "revive";
      void playSound("summon", 0.86);
      vibrateDevice([55, 35, 80, 35, 110]);
    }, 1320),
  );

  necroRebirthTimers.push(
    setTimeout(() => {
      if (!necroRebirthCinematic.value.show) return;
      necroRebirthCinematic.value.phase = "result";
      void playSound("heal", 0.62);
    }, 2050),
  );

  necroRebirthTimers.push(
    setTimeout(() => {
      necroRebirthCinematic.value = {
        show: false,
        phase: "idle",
        source: null,
        target: null,
      };
      necroRebirthTimers = [];
    }, 3300),
  );
};

// =========================================================
// ACTIVE / BENCH BUTTON ACTIONS
// =========================================================

const canUseBenchMoveAction = () =>
  isMyTurn.value &&
  !actionLoading.value &&
  !battleWaiting.value &&
  !waitingForRfid.value &&
  !questionActive.value &&
  !battleFinished.value &&
  canSpendActionPoints(configuredActionPointCost("switch", 1));

const canMoveActiveCardToBench = (card) =>
  Boolean(
    card &&
      !card.exhausted &&
      benchCards.value.length < maxBench.value &&
      canUseBenchMoveAction(),
  );

const moveActiveCardToBench = async (card) => {
  if (!canMoveActiveCardToBench(card)) return;
  await sendBenchAction("move_to_bench", card);
};

const canReturnBenchCard = (card) => {
  if (
    !card ||
    card.exhausted ||
    Number(card.currentHp ?? card.current_hp ?? card.hp ?? 0) <= 0 ||
    getBenchReturnCount(card) >= 1 ||
    !canUseBenchMoveAction()
  ) {
    return false;
  }

  const hasOpenActiveSlot = activeCards.value.length < maxActive.value;
  if (hasOpenActiveSlot) return true;

  return Boolean(
    selectedCard.value &&
      !selectedCard.value.exhausted &&
      Number(selectedCard.value.currentHp ?? selectedCard.value.current_hp ?? selectedCard.value.hp ?? 0) > 0,
  );
};

const returnBenchCardToActive = async (card) => {
  if (!canReturnBenchCard(card)) {
    if (
      activeCards.value.length >= maxActive.value &&
      !selectedCard.value
    ) {
      warningToast(
        "PILIH KARTU ACTIVE",
        "Pilih kartu Active yang ingin ditukar terlebih dahulu.",
      );
    }
    return;
  }

  const hasOpenActiveSlot = activeCards.value.length < maxActive.value;
  if (hasOpenActiveSlot) {
    await sendBenchAction("return_from_bench", card);
    return;
  }

  await sendBenchAction("switch_active", card, {
    active_card_id: getCardId(selectedCard.value),
  });
};

const benchReturnActionLabel = computed(() => {
  if (activeCards.value.length < maxActive.value) {
    return "KEMBALI KE ACTIVE";
  }

  return selectedCard.value
    ? `TUKAR DENGAN ${selectedCard.value.name}`
    : "PILIH ACTIVE UNTUK TUKAR";
});

const benchReturnActionHint = computed(() => {
  const cost = configuredActionPointCost("switch", 1);
  if (activeCards.value.length < maxActive.value) {
    return `Masuk ke slot Active yang kosong • biaya ${cost} poin giliran.`;
  }

  return selectedCard.value
    ? `Menukar posisi dengan ${selectedCard.value.name} • biaya ${cost} poin giliran.`
    : "Pilih kartu Active terlebih dahulu, lalu tekan tombol ini.";
});

const benchReturnActionEnabled = computed(() => {
  if (!canUseBenchMoveAction()) return false;
  if (activeCards.value.length < maxActive.value) return true;

  return Boolean(
    selectedCard.value &&
      !selectedCard.value.exhausted &&
      Number(selectedCard.value.currentHp ?? selectedCard.value.current_hp ?? selectedCard.value.hp ?? 0) > 0,
  );
});

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

const questionRewardChoices =
  ref([]);

const bonusChoiceRoundId =
  ref(null);

const bonusChoiceSubmitting =
  ref(false);
const bonusChoiceSelectedCode=ref(null);
const quizBonusCatalog=computed(()=>Array.isArray(battle.value?.quiz_bonus_rules_snapshot)?battle.value.quiz_bonus_rules_snapshot:[]);
const bonusChoiceOptions=computed(()=>questionRewardChoices.value.map(code=>{
 const rule=quizBonusCatalog.value.find(item=>item.code===code);
 return {code,name:bonusLabel(code),icon:bonusIcon(code),summary:bonusDescription(code),description:rule?.description||''};
}));

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


// =========================================================
// PHASE 3D.18 • STATUS EFFECT UI
// Generic battle_status_effects + legacy combat/session flags.
// =========================================================

const activeStatusEffects = ref([]);
const statusEffectsLoading = ref(false);
let firePassiveStatusPoll = null;

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
  "status_removed",
  "status_refreshed",
]);

const STATUS_VISUALS = {
  studio_shield: {icon:'🛡',label:'SHIELD',tone:'water'},
  studio_defense: {icon:'🛡',label:'DEF UP',tone:'defense'},
  studio_team_defense: {icon:'🛡',label:'TEAM DEF',tone:'defense'},
  studio_attack_buff: {icon:'⚔',label:'ATK UP',tone:'power'},
  studio_attack_debuff: {icon:'↓',label:'ATK DOWN',tone:'debuff'},
  studio_defense_debuff: {icon:'↓',label:'DEF DOWN',tone:'debuff'},
  studio_reduction: {icon:'🛡',label:'DAMAGE GUARD',tone:'defense'},
  studio_mark: {icon:'◎',label:'MARKED',tone:'debuff'},
  studio_delayed_heal: {icon:'+',label:'REGEN',tone:'water'},
  studio_silence_slot2: {icon:'⊘',label:'SKILL 2 LOCK',tone:'debuff'},
  studio_revival_lock: {icon:'⌛',label:'REVIVE WAIT',tone:'debuff'},
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

const statusMetadata = (effect) =>
  effect?.metadata && typeof effect.metadata === "object"
    ? effect.metadata
    : {};

const statusVisual = (effect) => {
  const key = normalizeStatusKey(effect);
  const meta = statusMetadata(effect);
  const fallbackLabel = key.replaceAll("_", " ").toUpperCase();

  return {
    key,
    icon: String(meta.icon ?? STATUS_VISUALS[key]?.icon ?? "✦"),
    label: String(meta.label ?? meta.name ?? STATUS_VISUALS[key]?.label ?? fallbackLabel),
    tone: String(meta.tone ?? STATUS_VISUALS[key]?.tone ?? (effect?.value < 0 ? "debuff" : "buff")),
  };
};

const statusPercent = (value) => {
  const numeric = Number(value ?? 0) || 0;
  const percent = Math.abs(numeric) <= 1 ? numeric * 100 : numeric;
  return Math.round(Math.abs(percent));
};

const statusValueText = (effect) => {
  const key = normalizeStatusKey(effect);
  const value = Number(effect?.value ?? 0) || 0;
  const stacks = Math.max(1, Number(effect?.stacks ?? 1) || 1);
  const percentKeys = new Set([
    "defense",
    "water_shield",
    "synergy_shield",
    "shield",
    "attack_debuff",
    "power_strike",
    "power_strike_ready",
  ]);

  const parts = [];
  if (percentKeys.has(key) && value !== 0) {
    parts.push(`${statusPercent(value)}%`);
  } else if (value !== 0) {
    parts.push(`${Math.abs(value)}`);
  }

  if (stacks > 1) {
    parts.push(`×${stacks}`);
  }

  return parts.join(" ");
};

const statusDurationText = (effect) => {
  const turns = Number(effect?.remaining_turns ?? 0) || 0;
  const rounds = Number(effect?.remaining_rounds ?? 0) || 0;

  if (turns > 0) return `${turns}T`;
  if (rounds > 0) return `${rounds}R`;
  return "";
};

const enrichStatus = (effect) => ({
  ...effect,
  ...statusVisual(effect),
  valueText: statusValueText(effect),
  durationText: statusDurationText(effect),
});

const dedupeStatuses = (items) => {
  const map = new Map();

  for (const item of items.map(enrichStatus)) {
    const key = `${item.key}:${item.target_card_id ?? "player"}`;
    const current = map.get(key);

    if (!current || (!current.valueText && item.valueText)) {
      map.set(key, item);
    }
  }

  return [...map.values()];
};

const loadStatusEffects = async () => {
  if (!battle.value?.id) {
    activeStatusEffects.value = [];
    return;
  }

  statusEffectsLoading.value = true;

  try {
    const { data, error: statusError } = await supabase.rpc(
      "get_active_battle_status_effects",
      { p_battle_id: battle.value.id },
    );

    if (statusError) {
      throw statusError;
    }

    activeStatusEffects.value = Array.isArray(data) ? data : [];
  } catch (statusError) {
    console.error("Load status effects:", statusError);
    activeStatusEffects.value = [];
  } finally {
    statusEffectsLoading.value = false;
  }
};

const legacyPlayerStatuses = (playerKey) => {
  if (!battle.value) return [];

  const isP1 = playerKey === "p1";
  const statuses = [];
  const defending = Boolean(
    isP1 ? battle.value.player1_defending : battle.value.player2_defending,
  );
  const shield = Number(
    isP1 ? battle.value.player1_synergy_shield : battle.value.player2_synergy_shield,
  ) || 0;
  const debuff = Number(
    isP1 ? battle.value.player1_attack_debuff : battle.value.player2_attack_debuff,
  ) || 0;
  const power = Boolean(
    isP1 ? battle.value.player1_power_strike_ready : battle.value.player2_power_strike_ready,
  );

  if (defending) {
    statuses.push({ status_key: "defense", value: 0.5, target_player: playerKey, scope: "player" });
  }
  if (shield > 0) {
    statuses.push({ status_key: "water_shield", value: shield, target_player: playerKey, scope: "player" });
  }
  if (debuff > 0) {
    statuses.push({ status_key: "attack_debuff", value: debuff, target_player: playerKey, scope: "player" });
  }
  if (power) {
    statuses.push({ status_key: "power_strike_ready", value: 0.5, target_player: playerKey, scope: "player" });
  }

  return statuses;
};

const getPlayerStatusEffects = (playerKey) =>
  dedupeStatuses([
    ...legacyPlayerStatuses(playerKey),
    ...activeStatusEffects.value.filter(
      (effect) =>
        String(effect?.target_player ?? "").toLowerCase() === playerKey &&
        !effect?.target_card_id,
    ),
  ]);

const ownStatusEffects = computed(() => getPlayerStatusEffects(player.value));
const enemyStatusEffects = computed(() =>
  getPlayerStatusEffects(player.value === "p1" ? "p2" : "p1"),
);

const cardHasNecroIdentity = (card) => {
  const tags = Array.isArray(card?.tags) ? card.tags : [];
  return tags.some((tag) => String(tag).toLowerCase() === "necro") ||
    String(card?.element ?? "").toLowerCase() === "necro";
};

const cardHasFusionIdentity = (card) =>
  Boolean(card?.is_fusion_result) ||
  String(card?.origin_type ?? "").toLowerCase() === "fusion" ||
  String(card?.card_type ?? "").toLowerCase() === "fusion";

const getCardStatusEffects = (card) => {
  const id = getCardId(card);
  if (!id) return [];

  const items = activeStatusEffects.value.filter(
    (effect) => String(effect?.target_card_id ?? "") === String(id),
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

  // Bubble temporary Burn above identity statuses in the 3-chip card UI.
  return dedupeStatuses(items).sort((a, b) =>
    Number(b.key === "elemental_burn" || b.key === "burn") -
    Number(a.key === "elemental_burn" || a.key === "burn")
  );
};

const getCardFxFlags = (card) => {
  const keys = new Set(getCardStatusEffects(card).map((status) => status.key));
  const ownShield = Number(player.value === "p1"
    ? battle.value?.player1_synergy_shield
    : battle.value?.player2_synergy_shield) > 0;

  return {
    defense: keys.has("defense") || keys.has('studio_defense') || keys.has('studio_team_defense'),
    shield: keys.has('studio_shield') || keys.has('studio_reduction') || keys.has("shield") || keys.has("water_shield") || keys.has("synergy_shield") || ownShield,
    necro: keys.has("necro_identity"),
    fusion: keys.has("fusion_identity"),
    burn: keys.has("burn") || keys.has("elemental_burn"),
    freeze: keys.has("freeze") || keys.has("frozen"),
    poison: keys.has("poison"),
    stun: keys.has("stun"),
    curse: keys.has("curse"),
  };
};

const visualOnlyCardStatuses = new Set([
  "burn", "elemental_burn", "freeze", "frozen", "stun", "poison", "curse",
  "shield", "water_shield", "synergy_shield", "defense",
]);

const visibleCardStatuses = (card) =>
  getCardStatusEffects(card).filter((status) => !visualOnlyCardStatuses.has(status.key));

const statusTooltip = (status) => {
  const value = status.valueText ? ` • ${status.valueText}` : "";
  const duration = status.durationText ? ` • ${status.durationText}` : "";
  return `${status.icon} ${status.label}${value}${duration}`;
};

// =========================================================
// PLAYER INCOMING EVENT FEEDBACK
// Toast + card shake + screen impact + device vibration.
// Vibration API is best-effort and only runs on supported browsers/devices.
// =========================================================

const incomingReactionCardIds = ref([]);
const incomingImpactActive = ref(false);
const incomingImpactFlash = ref("");
const deckReactionActive = ref(false);

let incomingCardTimer = null;
let incomingImpactTimer = null;
let incomingFlashTimer = null;
let deckReactionTimer = null;

const processedIncomingEventIds = new Set();

const canVibrateDevice = () =>
  typeof navigator !== "undefined" &&
  typeof navigator.vibrate === "function";

const vibrateDevice = (pattern = 40) => {
  if (!canVibrateDevice()) {
    return false;
  }

  try {
    return navigator.vibrate(pattern);
  } catch (vibrationError) {
    console.debug("Device vibration unavailable:", vibrationError);
    return false;
  }
};

const stopDeviceVibration = () => {
  if (!canVibrateDevice()) {
    return;
  }

  try {
    navigator.vibrate(0);
  } catch {
    // best effort only
  }
};

const clearReactionTimer = (timer) => {
  if (timer) {
    clearTimeout(timer);
  }
};

const triggerDeckReaction = ({ vibrate = false } = {}) => {
  clearReactionTimer(deckReactionTimer);
  deckReactionActive.value = false;

  requestAnimationFrame(() => {
    deckReactionActive.value = true;
  });

  if (vibrate) {
    vibrateDevice([25, 30, 25]);
  }

  deckReactionTimer = setTimeout(() => {
    deckReactionActive.value = false;
    deckReactionTimer = null;
  }, 700);
};

const triggerIncomingReaction = ({
  cardId = null,
  cardIds = [],
  strength = "medium",
  flash = "damage",
  deck = false,
} = {}) => {
  clearReactionTimer(incomingCardTimer);
  clearReactionTimer(incomingImpactTimer);
  clearReactionTimer(incomingFlashTimer);

  const reactionIds = [
    ...(Array.isArray(cardIds) ? cardIds : []),
    cardId,
  ]
    .filter((value) => value != null && value !== "")
    .map((value) => String(value));

  incomingReactionCardIds.value = [...new Set(reactionIds)];

  if (incomingReactionCardIds.value.length) {
    incomingCardTimer = setTimeout(() => {
      incomingReactionCardIds.value = [];
      incomingCardTimer = null;
    }, strength === "heavy" ? 900 : 700);
  }

  incomingImpactActive.value = false;
  incomingImpactFlash.value = "";

  requestAnimationFrame(() => {
    incomingImpactActive.value = true;
    incomingImpactFlash.value = flash;
  });

  incomingImpactTimer = setTimeout(() => {
    incomingImpactActive.value = false;
    incomingImpactTimer = null;
  }, strength === "heavy" ? 620 : 440);

  incomingFlashTimer = setTimeout(() => {
    incomingImpactFlash.value = "";
    incomingFlashTimer = null;
  }, strength === "heavy" ? 720 : 520);

  if (deck) {
    triggerDeckReaction();
  }

  const pattern =
    strength === "heavy"
      ? [120, 55, 140, 55, 180]
      : strength === "light"
        ? [35]
        : [70, 40, 95];

  vibrateDevice(pattern);
};

const isIncomingReactionCard = (card) => {
  const id = getCardId(card);

  return (
    id != null &&
    incomingReactionCardIds.value.includes(String(id))
  );
};

const findOwnCardById = (cardId) => {
  if (!cardId) {
    return null;
  }

  const allOwnCards = [
    ...activeCards.value,
    ...benchCards.value,
    ...graveyardCards.value,
  ];
  const requestedId = String(cardId);
  const exactBattleCard = allOwnCards.find((card) =>
    [card?.battleId, card?.battle_card_id, card?.battleCardId]
      .some((value) => value != null && String(value) === requestedId),
  );
  return exactBattleCard ?? null;
};

const battleEventPayload = (event) =>
  event?.payload && typeof event.payload === "object"
    ? event.payload
    : {};

const battleEventAffectedCardIds = (event) => {
  const payload = battleEventPayload(event);
  const ids = [];

  if (Array.isArray(payload?.affected_card_ids)) {
    ids.push(...payload.affected_card_ids);
  }

  if (Array.isArray(payload?.targets)) {
    ids.push(
      ...payload.targets.map((target) => target?.target_card_id),
    );
  }

  ids.push(
    payload?.target_card_id,
  );

  if (
    [
      "card_destroyed",
      "graveyard",
      "bench",
      "swap",
      "summon",
    ].includes(String(event?.type ?? "").toLowerCase())
  ) {
    ids.push(event?.card_id);
  }

  return [...new Set(
    ids
      .filter((value) => value != null && value !== "")
      .map((value) => String(value)),
  )];
};

const incomingEventTargetCardId = (event) => {
  const payload = battleEventPayload(event);
  const candidates = [
    payload?.target_card_id,
    ...(Array.isArray(payload?.targets)
      ? payload.targets.map((target) => target?.target_card_id)
      : []),
    ...(Array.isArray(payload?.affected_card_ids) ? payload.affected_card_ids : []),
  ].filter((value) => value != null && value !== "");
  return candidates.find((id) => findOwnCardById(id)) ?? null;
};

const incomingEventTargetsPlayer = (event) => {
  const payload =
    event?.payload && typeof event.payload === "object"
      ? event.payload
      : {};

  const playerCandidates = [
    event?.target_player,
    payload?.target_player,
    payload?.player,
    payload?.owner,
    payload?.card_player,
    payload?.target_owner,
  ]
    .filter(Boolean)
    .map((value) => String(value).toLowerCase());

  if (playerCandidates.includes(player.value)) {
    return true;
  }

  const targetCardIds = battleEventAffectedCardIds(event);

  return targetCardIds.some((cardId) => Boolean(findOwnCardById(cardId)));
};

const incomingEventKey = (event) =>
  String(
    event?.id ??
      `${event?.type ?? "event"}:${event?.created_at ?? ""}:${event?.source_player ?? ""}:${incomingEventTargetCardId(event) ?? ""}`,
  );

const rememberIncomingEvent = (event) => {
  const key = incomingEventKey(event);

  if (processedIncomingEventIds.has(key)) {
    return false;
  }

  processedIncomingEventIds.add(key);

  if (processedIncomingEventIds.size > 250) {
    const oldest = processedIncomingEventIds.values().next().value;
    processedIncomingEventIds.delete(oldest);
  }

  return true;
};

const notifyIncomingBattleEvent = (event) => {
  if (!event || !rememberIncomingEvent(event)) {
    return;
  }

  const payload =
    event.payload && typeof event.payload === "object"
      ? event.payload
      : {};

  const sourcePlayer = String(event.source_player ?? "").toLowerCase();
  const opponentSource = Boolean(sourcePlayer && sourcePlayer !== player.value);
  const targetsMe = incomingEventTargetsPlayer(event);
  const targetCardId = incomingEventTargetCardId(event);
  const targetCard = findOwnCardById(targetCardId);
  const targetVisualId = targetCard ? getCardId(targetCard) : targetCardId;
  const targetName =
    targetCard?.name ??
    payload?.target_card_name ??
    payload?.card_name ??
    "Kartu kamu";

  const damage = Math.max(
    0,
    Number(
      payload?.final_damage ??
        payload?.effective_damage ??
        payload?.damage ??
        0,
    ) || 0,
  );

  if (event.type === "attack" && opponentSource && targetsMe) {
    const attackMode = String(payload?.attack_mode ?? "").toLowerCase();

    if (attackMode === "direct") {
      errorToast(
        "💥 DIRECT HIT",
        damage > 0
          ? `${enemyName.value} menyerang langsung. Player HP -${damage}.`
          : `${enemyName.value} melakukan Direct Attack.`,
      );

      triggerIncomingReaction({
        strength: "heavy",
        flash: "direct",
      });

      return;
    }

    const hpBefore = Number(payload?.target_hp_before ?? 0) || 0;
    const hpAfter = Number(payload?.target_hp_after ?? 0) || 0;
    const hpText =
      hpBefore > 0 || hpAfter > 0
        ? ` • HP ${hpBefore} → ${hpAfter}`
        : "";

    warningToast(
      "⚔️ KARTU DISERANG",
      `${targetName}${damage > 0 ? ` menerima ${damage} damage` : " diserang"}${hpText}.`,
    );

    triggerIncomingReaction({
      cardId: targetVisualId,
      strength: payload?.destroyed ? "heavy" : "medium",
      flash: payload?.destroyed ? "danger" : "damage",
    });

    return;
  }

  if (event.type === "card_destroyed" && opponentSource && targetsMe) {
    errorToast(
      "☠️ KARTU HANCUR",
      `${targetName} dihancurkan dan masuk ke Graveyard.`,
    );

    triggerIncomingReaction({
      cardId: targetVisualId,
      strength: "heavy",
      flash: "danger",
      deck: true,
    });

    return;
  }

  if (event.type === "ultimate" && opponentSource && targetsMe) {
    const ultimateTargets = Array.isArray(payload?.targets)
      ? payload.targets
      : [];

    const canonicalTargetIds = battleEventAffectedCardIds(event);

    const ownUltimateTargets = ultimateTargets.filter((target) =>
      findOwnCardById(target?.target_card_id),
    );

    const targetIds = [
      ...new Set(
        [
          ...ownUltimateTargets.map((target) => target?.target_card_id),
          ...canonicalTargetIds.filter((cardId) => findOwnCardById(cardId)),
        ]
          .filter(Boolean)
          .map((cardId) => String(getCardId(findOwnCardById(cardId)) ?? cardId)),
      ),
    ];

    const hitCount = Math.max(
      0,
      Number(payload?.target_count ?? ownUltimateTargets.length) || 0,
    );

    const destroyedCount = Math.max(
      0,
      Number(payload?.destroyed_count ?? 0) || 0,
    );

    const totalDamage = Math.max(
      0,
      Number(payload?.total_effective_damage ?? payload?.damage ?? 0) || 0,
    );

    errorToast(
      "💥 ULTIMATE AOE MUSUH",
      `${enemyName.value} menghantam ${hitCount || targetIds.length || "semua"} Active Card${
        totalDamage > 0 ? ` • ${totalDamage} total damage` : ""
      }${destroyedCount > 0 ? ` • ${destroyedCount} hancur` : ""}.`,
    );

    triggerIncomingReaction({
      cardIds: targetIds,
      cardId: targetVisualId,
      strength: "heavy",
      flash: "danger",
    });

    return;
  }

  if (event.type === "synergy" && opponentSource && targetsMe && damage > 0) {
    warningToast(
      "✨ SYNERGY MUSUH",
      payload?.message ?? `${enemyName.value} mengaktifkan Synergy.`,
    );

    triggerIncomingReaction({
      cardId: targetVisualId,
      strength: "medium",
      flash: "effect",
    });

    return;
  }

  if (event.type === "graveyard" && sourcePlayer === player.value) {
    const reason = String(payload?.reason ?? "").toLowerCase();

    if (reason && reason !== "destroyed") {
      warningToast(
        "☠️ CARD KE GRAVEYARD",
        payload?.message ?? `${targetName} dipindahkan ke Graveyard.`,
      );

      triggerIncomingReaction({
        cardId: event?.card_id ?? targetCardId,
        strength: "light",
        flash: "deck",
        deck: true,
      });
    }

    return;
  }

  if (event.type === "fusion" && opponentSource) {
    // Toast Fusion sudah ditangani watcher Phase 3D.13.
    // Di sini cukup beri haptic ringan agar player menyadari perubahan arena.
    vibrateDevice([30, 30, 45]);
    return;
  }

  if (
    event.type === "special_effect" &&
    opponentSource &&
    battleEventEffectType(event) === "revive"
  ) {
    const restoredHp = Math.max(
      0,
      Number(payload?.result?.restored_hp ?? payload?.restored_hp ?? 0) || 0,
    );

    successToast(
      "☠️ OPPONENT REVIVE",
      restoredHp > 0
        ? `${enemyName.value} membangkitkan Card dari Graveyard dengan ${restoredHp} HP.`
        : `${enemyName.value} membangkitkan Card dari Graveyard.`,
    );

    vibrateDevice([35, 35, 55]);
    return;
  }

  const ignoredGenericTypes = new Set([
    "attack",
    "card_destroyed",
    "damage",
    "ultimate",
    "synergy",
    "fusion",
    "win",
    "rfid_warning",
  ]);

  if (
    opponentSource &&
    targetsMe &&
    !ignoredGenericTypes.has(String(event.type ?? "").toLowerCase())
  ) {
    const eventLabel = String(event.type ?? "effect")
      .replaceAll("_", " ")
      .toUpperCase();

    warningToast(
      `⚠️ ${eventLabel}`,
      payload?.message ?? `${enemyName.value} memberi effect ke kamu.`,
    );

    triggerIncomingReaction({
      cardId: targetVisualId,
      strength: "medium",
      flash: "effect",
      deck: Boolean(targetCardId),
    });
  }
};

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

const actionPointsEnabled = computed(
  () => isTcgV1.value && Boolean(battle.value?.action_points_enabled),
);

const configuredActionPointCost = (action, fallback = 1) => {
  const value = Number(battle.value?.action_costs?.[action]);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
};

const actionPointsPerTurn = computed(() =>
  Math.max(1, Number(battle.value?.action_points_per_turn ?? 3) || 3),
);

const maxAttacksPerCard = computed(() =>
  Math.max(1, Number(battle.value?.max_attacks_per_card ?? 1) || 1),
);

const tripleComboEnabled = computed(() => Boolean(battle.value?.triple_combo_enabled));
const formationEnabled = computed(() => Boolean(battle.value?.formation_enabled));
const comboEnabled = computed(() => battle.value?.combo_enabled !== false);

const cardAttacksUsedThisTurn = (card) => {
  const currentTurn = Number(battle.value?.turn_index ?? 1);
  if (Number(card?.attack_turn_index ?? -1) === currentTurn) {
    return Math.max(0, Number(card?.attacks_this_turn ?? 0));
  }
  return Number(card?.last_attacked_turn ?? -1) === currentTurn
    ? maxAttacksPerCard.value
    : 0;
};

const comboEligibleActiveCards = computed(() =>
  activeCards.value.filter((card) =>
    Number(card?.current_hp ?? card?.hp ?? 0) > 0 &&
    !card?.exhausted &&
    cardAttacksUsedThisTurn(card) < maxAttacksPerCard.value,
  ),
);

const selectedComboParticipants = computed(() =>
  comboParticipantIds.value
    .map((id) => comboEligibleActiveCards.value.find((card) => String(getCardId(card)) === String(id)))
    .filter(Boolean),
);

const comboActionPointCost = computed(() =>
  selectedComboParticipants.value.length >= 4
    ? configuredActionPointCost("ultimate_combo", 3)
    : selectedComboParticipants.value.length >= 3
    ? configuredActionPointCost("triple_combo", 3)
    : configuredActionPointCost("combo_attack", 2),
);

const comboTypeKey = computed(() =>
  selectedComboParticipants.value.length >= 2
    ? getTcgComboTypeKey(selectedComboParticipants.value.map((card) => card.element))
    : null,
);

const selectedComboRule = computed(() =>
  comboRuleCatalog.value.find((rule) => rule.type_keys?.join("+") === comboTypeKey.value) ?? null,
);

const ownActionPoints = computed(() =>
  Math.max(
    0,
    Number(
      player.value === "p1"
        ? battle.value?.player1_action_points
        : battle.value?.player2_action_points,
    ) || 0,
  ),
);

const enemyActionPoints = computed(() =>
  Math.max(
    0,
    Number(
      player.value === "p1"
        ? battle.value?.player2_action_points
        : battle.value?.player1_action_points,
    ) || 0,
  ),
);

const maxBenchSlots = computed(() =>
  Math.max(0, Number(battle.value?.max_bench ?? 4) || 0),
);

const canSpendActionPoints = (cost = 1) =>
  !actionPointsEnabled.value || ownActionPoints.value >= cost;

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

const ownHpState = computed(() =>
  getHpStateClass(ownHpPercent.value),
);

const enemyHpState = computed(() =>
  getHpStateClass(enemyHpPercent.value),
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
// PERSISTENT ACTION STATE / LEGACY FLAGS
// =========================================================

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

const turnClockNow = ref(Date.now());
const turnClockServerOffsetMs = ref(0);
const turnTimerVisible = computed(() => {
  const current = battle.value;
  return Boolean(
    current?.status === "battle" &&
    !current?.question_active &&
    !questionActive.value &&
    !battleFinished.value &&
    current?.turn_deadline_at,
  );
});
const turnSecondsRemaining = computed(() => {
  if (!turnTimerVisible.value) return null;
  const deadline = Date.parse(battle.value?.turn_deadline_at ?? "");
  if (!Number.isFinite(deadline)) return null;
  return Math.max(0, Math.ceil((deadline - (turnClockNow.value + turnClockServerOffsetMs.value)) / 1000));
});
const turnClockUrgent = computed(() => (turnSecondsRemaining.value ?? 99) <= 10);

let turnClockTickInterval = null;
let turnClockSyncInterval = null;
let turnClockSyncPending = false;
let lastTurnClockNotice = "";

const syncBattleTurnClock = async () => {
  if (!code.value || !player.value || !token.value || turnClockSyncPending) return;
  turnClockSyncPending = true;

  try {
    const { data, error: syncError } = await supabase.rpc("tcg_sync_battle_turn", {
      p_code: code.value,
      p_player: player.value,
      p_token: token.value,
    });

    if (syncError) throw syncError;
    if (!data?.ok) return;

    if (data.server_now) {
      turnClockServerOffsetMs.value = Date.parse(data.server_now) - Date.now();
    }

    const noticeKey = `${data.timed_player ?? ""}:${data.turn_deadline_at ?? ""}:${data.grace_granted ? "grace" : data.timed_out ? "expired" : ""}`;
    if (noticeKey !== lastTurnClockNotice && data.grace_granted && data.timed_player === player.value) {
      lastTurnClockNotice = noticeKey;
      warningToast("WAKTU SAMBUNG ULANG", "Kamu mendapat tambahan 10 detik untuk menyambungkan kembali.");
    } else if (noticeKey !== lastTurnClockNotice && data.timed_out && data.timed_player === player.value) {
      lastTurnClockNotice = noticeKey;
      warningToast("GILIRAN BERAKHIR", "Waktu habis, giliran sudah berpindah ke lawan.");
    }
  } catch (syncError) {
    console.warn("Sinkronisasi countdown giliran gagal:", syncError);
  } finally {
    turnClockSyncPending = false;
  }
};

const onTurnClockVisibilityChange = () => {
  if (document.visibilityState === "visible") {
    turnClockNow.value = Date.now();
    void syncBattleTurnClock();
  }
};

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

const selectedCardAlreadyAttacked = computed(() =>
  Boolean(
    selectedCard.value &&
      actionPointsEnabled.value &&
      cardAttacksUsedThisTurn(selectedCard.value) >= maxAttacksPerCard.value,
  ),
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
      readyFusions.value.length > 0 &&
      canSpendActionPoints(configuredActionPointCost("fusion", 2)),
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
    fusionLoadError.value = playerErrorMessage(
      err,
      "Resep Fusion belum dapat dimuat. Coba muat ulang battle.",
    );
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

          // Phase 3D.15 - idempotency key.
          // Double-click atau retry network untuk attempt Fusion yang sama
          // akan mengirim key logis yang sama ke backend.
          request_id: [
            "fusion",
            battle.value?.id ?? code.value,
            player.value,
            recipe.recipe_id,
            `use-${Math.max(1, Number(recipe?.usage_count ?? 0) + 1)}`,
            `round-${Math.max(0, Number(battle.value?.round ?? 0))}`,
          ].join(":"),
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

    // Phase 3D.16.1 - Fast post-Fusion refresh.
    // Jangan jalankan refresh besar secara serial; itu membuat PlayerBattle
    // terlihat seperti reconnect penuh. Semua sumber penting direfresh paralel.
    await Promise.allSettled([
      loadBattle(code.value),
      loadGraveyardCards(),
      loadPlayerFusions(),
      loadFusionHistory(),
    ]);
  } catch (err) {
    console.error("Fusion:", err);
    errorToast(
      "FUSION ERROR",
      playerErrorMessage(err, "Fusion gagal diproses. Coba lagi."),
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

let skillLoadVersion = 0;
const loadSelectedCardSpecialSkills = async () => {
  const version = ++skillLoadVersion;
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

    if (version !== skillLoadVersion) return;
    runtimeSpecialSkills.value = rows.map((skill) => ({
      ...skill,
      usage_count: usageCount.get(skill.id) ?? 0,
    }));
  } catch (err) {
    console.error("Load Special Skills:", err);
    if (version === skillLoadVersion) runtimeSpecialSkills.value = [];
  } finally {
    if (version === skillLoadVersion) specialSkillLoading.value = false;
  }
};

const specialSkillActionPointCost = skill => skillApCost(skill, configuredActionPointCost('special_skill', 1));

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

  if (skill.disabled || skill.activation_timing !== 'main_phase') return { ready:false, status:'DISABLED', reason:'Skill sedang dinonaktifkan.' };
  const sourceStatuses = activeStatusEffects.value.filter(status => status.target_card_id === getCardId(selectedCard.value));
  if (sourceStatuses.some(status => status.status_key === 'studio_revival_lock')) return {ready:false,status:'REVIVED',reason:'Attack/Skill tersedia pada giliran berikutnya.'};
  if (String(skill.metadata?.master_metadata?.slot) === '2' && sourceStatuses.some(status => status.status_key === 'studio_silence_slot2')) return {ready:false,status:'LOCKED',reason:'Skill 2 sedang dikunci.'};
  const cooldown = skillCooldown(skill, battle.value, player.value);
  if (cooldown.remaining) return { ready:false, status:`CD ${cooldown.remaining}`, reason:`Tersedia setelah ${cooldown.remaining} ${cooldown.unit}.` };

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

  const actionPointCost = specialSkillActionPointCost(skill);
  if (actionPointsEnabled.value && ownActionPoints.value < actionPointCost) {
    return {
      ready: false,
      status: `${actionPointCost} POIN GILIRAN DIBUTUHKAN`,
      reason: `Skill ini membutuhkan ${actionPointCost} poin giliran. Poinmu saat ini ${ownActionPoints.value}.`,
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

  return selected ?? null;
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
  if (type === 'ally_field') return [...activeCards.value, ...benchCards.value];

  if (type === "ally_graveyard") {
    const recall = skillEffects(selectedSpecialSkill.value).some(effect => effect.program?.operations?.some(item => item.type === 'revive'));
    return recall ? graveyardCards.value.filter(card => !card.is_fusion_result && !card.fusion_consumed && card.origin_type !== 'fusion' && card.card_kind !== 'fusion') : graveyardCards.value;
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
    enemy_active: "Kartu Active lawan",
    ally_active: "Kartu Activemu",
    ally_field: "Active / Bench milikmu",
    any_active: "Kartu Active yang tersedia",
    self: "Kartu ini",
    self_card: "Kartu ini",
    source_card: "Kartu ini",
    self_player: "Pemainmu",
    source_player: "Pemainmu",
    enemy_player: "Pemain lawan",
    opponent_player: "Pemain lawan",
    ally_graveyard: "Graveyard milikmu",
    enemy_graveyard: "Graveyard lawan",
  };

  return labels[type] ?? (type ? type.replaceAll("_", " ").toUpperCase() : "Otomatis");
};

const formatSpecialCost = (skill) => {
  const cost = skillCostSpec(skill);
  const type = String(cost.type ?? "none").toLowerCase();
  const value = Math.max(0, Number(cost.value ?? cost.amount ?? 0) || 0);

  if (["", "none", "free"].includes(type)) {
    return "Tanpa biaya tambahan";
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
    parts.push("Pemakaian tidak dibatasi");
  }

  const cd = skillCooldown(skill, battle.value, player.value);
  parts.push(cd.duration > 0 ? `Cooldown ${cd.duration} ${cd.unit}` : "Tanpa cooldown");

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
    if (type === 'studio_skill') return skill.description || 'Ikuti efek kartu.';
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
    if(Array.isArray(battle.value?.synergy_rules_snapshot))return synergyRuleState(battle.value.synergy_rules_snapshot,selectedCard.value,activeCards.value,ownSynergyUsed.value);
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
      ) &&
      !selectedCardAlreadyAttacked.value &&
      canSpendActionPoints(configuredActionPointCost("attack", 1)),
  );

const canDefenseUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ) &&
      canSpendActionPoints(configuredActionPointCost("defense", 1)),
  );

const canUltimateUi =
  computed(
    () =>
      Boolean(
        selectedCard.value,
      ) &&
      enemyActiveCards.value.length > 0 &&
      ownSkill.value >=
        100 &&
      canSpendActionPoints(configuredActionPointCost("ultimate", 2)),
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
      !ownHealUsed.value &&
      canSpendActionPoints(configuredActionPointCost("heal", 1)),
  );

const canSynergyUi =
  computed(
    () =>
      Boolean(
      selectedSynergyInfo
          .value
          ?.ready,
      ) &&
      canSpendActionPoints(configuredActionPointCost("synergy", 1)),
  );

const canSummonUi =
  computed(() => {
    const activeSpace = activeCards.value.length < maxActive.value;

    if (!isTcgV1.value) {
      return activeSpace;
    }

    return (
      activeSpace &&
      ownDeckRemaining.value >
        0 &&
      canSpendActionPoints(configuredActionPointCost("summon", 1))
    );
  });

const canComboAttackUi = computed(() =>
  actionPointsEnabled.value &&
    comboEnabled.value &&
    comboEligibleActiveCards.value.length >= 2 &&
    canSpendActionPoints(configuredActionPointCost("combo_attack", 2)),
);

const skillLockText =
  (type) => {
    if (type === "combo") {
      if (!isTcgV1.value) return "TCG ONLY";
      if (!actionPointsEnabled.value) return "POIN GILIRAN NONAKTIF · BATTLE BARU";
      if (!comboEnabled.value) return "COMBO OFF IN SETUP";
      if (comboEligibleActiveCards.value.length < 2) {
        return activeCards.value.length < 2
          ? "NEED 2 ACTIVE CARDS"
          : "ACTIVE CARDS ALREADY USED / BLOCKED";
      }
      if (!canSpendActionPoints(configuredActionPointCost("combo_attack", 2))) {
        return `${ownActionPoints.value} POIN GILIRAN TERSISA`;
      }
    }

    if (
      type === "attack" &&
      selectedCardAlreadyAttacked.value
    ) {
      return "ALREADY ATTACKED";
    }

    const actionKey = { combo: "combo_attack", special: "special_skill" }[type] ?? type;
    const apCost = configuredActionPointCost(actionKey, {
      attack: 1,
      defense: 1,
      ultimate: 2,
      heal: 1,
      synergy: 1,
      summon: 1,
      special: 1,
      fusion: 2,
      combo: 2,
    }[type] ?? 1);
    if (
      actionPointsEnabled.value &&
      apCost &&
      !canSpendActionPoints(apCost)
    ) {
      return `${ownActionPoints.value} POIN GILIRAN TERSISA`;
    }

    if (type === "summon" && activeCards.value.length >= maxActive.value) {
      return "ACTIVE FULL · MOVE A CARD TO BENCH";
    }

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
      if (!selectedCard.value) {
        return "SELECT CARD";
      }

      if (!enemyActiveCards.value.length) {
        return "NO ENEMY ACTIVE";
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

      return activeCards.value.length >= maxActive.value &&
        benchCards.value.length >= maxBench.value
        ? "FIELD FULL"
        : "ACTIVE + BENCH FULL";
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
            : "Attack berakhir dengan perpindahan turn. Normal Attack memberi +10 Ultimate Gauge ke attacker; player yang diserang mendapat +5. Electric Synergy dan skill gauge tetap dapat mengisi jauh lebih cepat.",
      },

      {
        key: "defense",
        icon: "🛡️",
        title: actionPointsEnabled.value ? "DEFENSE STAT · PASSIVE" : "DEFENSE",
        status:
          actionPointsEnabled.value
            ? "PASSIVE"
            : ownDefending.value
            ? "ACTIVE"
            : card
              ? "READY"
              : "SELECT CARD",
        ready:
          Boolean(card),
        effect:
          actionPointsEnabled.value
            ? "DEF mengurangi damage serangan kartu secara otomatis. Shield hanya berasal dari skill kartu."
            : "Next incoming damage ×0.50 (-50%).",
        detail:
          actionPointsEnabled.value
            ? "Tidak ada tombol Defense manual di TCG v1. Periksa stat DEF pada kartu dan aktifkan skill Shield bila tersedia."
            : "Memberi +5 Ultimate Gauge. Defense dikonsumsi saat serangan lawan mengenainya.",
      },

      {
        key: "ultimate",
        icon: "⚡",
        title: "ULTIMATE AOE",
        status:
          !card
            ? "SELECT CARD"
            : !enemyActiveCards.value.length
              ? "NO ENEMY ACTIVE"
              : ownSkill.value >= 100
                ? "READY"
                : `${ownSkill.value}% / 100%`,
        ready:
          canUltimateUi.value,
        effect:
          card
            ? `Semua Enemy Active Card menerima ATK ×2 → ${ultimateBase} raw damage per card.`
            : "Pilih Active Card untuk menghitung Ultimate.",
        detail:
          "Membutuhkan 100% Ultimate Gauge lalu gauge kembali ke 0. Ultimate dapat dipakai lagi setiap gauge penuh, mengabaikan Card DEF, menghapus Defense/Water Shield musuh, dan tidak memberi direct damage ke Player HP.",
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
            ? `Scan RFID → Active. Physical Deck tersisa ${ownDeckRemaining.value}/${ownDeckTotal.value}.`
            : "Scan RFID untuk menambahkan card ke Active Deck.",
        detail:
          `Active ${activeCards.value.length}/${maxActive.value} • Bench ${benchCards.value.length}/${maxBench.value}. Summon hanya memakai slot Active yang tersedia${
            isTcgV1.value
              ? " dan Physical Deck > 0. Jika Active penuh, pindahkan satu kartu ke Bench sebelum summon."
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
      ? `${specialSkillActionPointCost(skill)} poin giliran • ${formatSpecialTarget(skill)} • ${formatSpecialCost(skill)} • ${formatSpecialLimits(skill)}`
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

let skillChoiceId = null;
const publishSkillChoice = () => {
  if (!specialSkillModalOpen.value || !isMyTurn.value || questionActive.value || !selectedCard.value) { void syncSkillIntent(null); return; }
  void syncSkillIntent({id:skillChoiceId,cardId:getCardId(selectedCard.value),skillId:selectedSpecialSkillId.value,phase:selectedSpecialSkillId.value?'selected':'choosing',turn:spotlightTurn(battle.value),at:Date.now()});
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

  const preferred = skill;

  selectedSpecialSkillId.value = preferred?.id ?? null;
  selectedSpecialTargetId.value = null;
  specialSkillModalOpen.value = true;
  selectedSpecialOption.value = '';
  selectedSpecialBenchId.value = '';
  selectedSpecialTargetIds.value = [];
  skillChoiceId = crypto.randomUUID();
  publishSkillChoice();
};

const closeSpecialSkillModal = (silent = false) => {
  specialSkillModalOpen.value = false;
  void syncSkillIntent(null);
  selectedSpecialTargetId.value = null;

  if (!silent) {
    // intentionally no toast; closing an info modal is not an action
  }
};

const chooseSpecialSkill = (skill) => {
  selectedSpecialSkillId.value = skill?.id ?? null;
  selectedSpecialTargetId.value = null;
  selectedSpecialOption.value = '';
  selectedSpecialBenchId.value = '';
  selectedSpecialTargetIds.value = [];
  publishSkillChoice();
};

const chooseSpecialTarget = (card) => {
  const id = getCardId(card);
  const limit = Number(skillTargetSpec(selectedSpecialSkill.value).max_targets ?? 1);
  if (limit > 1) {
    const current = selectedSpecialTargetIds.value;
    selectedSpecialTargetIds.value = current.includes(id) ? current.filter(value => value !== id) : current.length < limit ? [...current,id] : [...current.slice(1),id];
    selectedSpecialTargetId.value = selectedSpecialTargetIds.value[0] ?? null;
  } else selectedSpecialTargetId.value = id;
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
  const spec = skillTargetSpec(skill);
  if (spec.choices?.length && !spec.choices.some(option => option.id === selectedSpecialOption.value)) { warningToast('PILIH EFEK', 'Pilih satu efek skill terlebih dahulu.'); return; }
  if (spec.needs_bench && !selectedSpecialBenchId.value) { warningToast('PILIH BENCH', 'Pilih kartu Bench untuk ditukar.'); return; }

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

  const skillCode = String(skill?.skill_code ?? skill?.code ?? "").toLowerCase();
  const isSoulRebirth = skillCode === "soul_rebirth";
  const soulRebirthSourceSnapshot = isSoulRebirth ? { ...source } : null;
  const soulRebirthTargetSnapshot =
    isSoulRebirth && selectedSpecialTarget.value
      ? { ...selectedSpecialTarget.value }
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
          action_id: crypto.randomUUID(),
          target_card_id: targetId,
          target_card_ids: selectedSpecialTargetIds.value,
          skill_option: selectedSpecialOption.value,
          bench_card_id: selectedSpecialBenchId.value || null,
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

    if (isSoulRebirth && soulRebirthTargetSnapshot) {
      const restoredHp = necroRestoredHp(soulRebirthTargetSnapshot);

      successToast(
        "☠️ SOUL REBIRTH",
        `${soulRebirthTargetSnapshot.name ?? "Card"} bangkit ke Active dengan ${restoredHp} HP. ${soulRebirthSourceSnapshot?.name ?? "Necro Card"} dikorbankan.`,
      );

      startNecroRebirthCinematic({
        source: soulRebirthSourceSnapshot,
        target: soulRebirthTargetSnapshot,
      });
    } else {
      successToast(
        `✨ ${String(skill.name ?? skill.skill_code ?? "SPECIAL").toUpperCase()}`,
        data?.message ?? (parts.length ? parts.join(" • ") : "Special Skill berhasil digunakan."),
      );
    }

    closeSpecialSkillModal(true);

    if (data?.ends_turn !== false) {
      selectedCardId.value = null;
    }

    await Promise.all([
      loadBattle(code.value),
      loadGraveyardCards(),
    ]);

    await loadSelectedCardSpecialSkills();
  } catch (err) {
    console.error("Special Skill:", err);
    errorToast(
      "SPECIAL SKILL ERROR",
      playerErrorMessage(err, "Skill gagal digunakan. Perbarui battle lalu coba lagi."),
    );
  } finally {
    actionLoading.value = false;
  }
};

// =========================================================
// CARD SELECTION
// =========================================================

const selectCard =
  (card) => {
    if (actionLoading.value) return;
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

    // Re-selecting the same card is still an explicit choice on a new turn.
    if (selectedCardId.value === getCardId(card)) {
      void syncFocusCards({ selectedCardId: getCardId(card), turn: spotlightTurn(battle.value) });
    }
    selectedCardId.value =
      getCardId(card);

    // Selection is already acknowledged in the persistent command context.
  };

// =========================================================
// VALIDATE TURN BEFORE ACTION
// =========================================================

const validateActionTurn =
  () => {
    if (actionLoading.value) return false;
    if (turnTimerVisible.value && turnSecondsRemaining.value === 0) {
      warningToast('WAKTU GILIRAN HABIS', 'Menunggu giliran berikutnya. Aksi belum dikirim.');
      void syncBattleTurnClock();
      return false;
    }
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

    if (selectedCardAlreadyAttacked.value) {
      warningToast(
        "ATTACK SUDAH DIPAKAI",
        `Kartu ini sudah memakai ${maxAttacksPerCard.value} kesempatan serang pada giliran ini.`,
      );
      return;
    }

    const attackApCost = configuredActionPointCost("attack", 1);
    if (!canSpendActionPoints(attackApCost)) {
      warningToast("POIN GILIRAN TIDAK CUKUP", `Serangan membutuhkan ${attackApCost} poin giliran.`);
      return;
    }

    if (
      !isTcgV1.value
    ) {
      requestPanelReview('attack');

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

      requestPanelReview('attack', true);

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

        playerErrorMessage(err, "Direct Attack gagal diproses. Perbarui battle lalu coba lagi."),
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

        playerErrorMessage(err, "Serangan gagal diproses. Perbarui battle lalu coba lagi."),
      );
    } finally {
      actionLoading.value =
        false;
    }
  };

// =========================================================
// SUBMIT ACTION
// =========================================================

const openComboAttackModal = () => {
  if (!validateActionTurn()) return;
  if (!canComboAttackUi.value) {
    warningToast("COMBO BELUM SIAP", `Combo membutuhkan sedikitnya dua kartu Active yang masih memiliki kesempatan menyerang dan ${configuredActionPointCost("combo_attack", 2)} poin giliran.`);
    return;
  }

  const primary = comboEligibleActiveCards.value.find((card) =>
    String(getCardId(card)) === String(getCardId(selectedCard.value)),
  ) ?? comboEligibleActiveCards.value[0];
  const defaultParticipants = [
    primary,
    ...comboEligibleActiveCards.value.filter((card) => String(getCardId(card)) !== String(getCardId(primary))).slice(0, 1),
  ].filter(Boolean);
  comboParticipantIds.value = defaultParticipants.map((card) => getCardId(card));
  comboPrimaryCardId.value = getCardId(primary) ?? null;
  comboTargetCardId.value = getCardId(enemyActiveCards.value[0]) ?? null;
  comboAttackModalOpen.value = true;
  if (!comboRuleCatalog.value.length) {
    void supabase
      .from("tcg_combo_rule_catalog")
      .select("rule_kind,type_keys,combo_name,ap_cost,bonus_damage,assist_multipliers,status_key,status_target,effect_json")
      .eq("enabled", true)
      .then(({ data, error: queryError }) => {
        if (queryError) return;
        comboRuleCatalog.value = Array.isArray(data) ? data : [];
      });
  }
};

const toggleComboParticipant = (card) => {
  const id = getCardId(card);
  if (!id) return;
  const exists = comboParticipantIds.value.some((item) => String(item) === String(id));
  if (exists) {
    comboParticipantIds.value = comboParticipantIds.value.filter((item) => String(item) !== String(id));
    if (String(comboPrimaryCardId.value) === String(id)) {
      comboPrimaryCardId.value = comboParticipantIds.value[0] ?? null;
    }
    return;
  }
  const maxParticipants = formationEnabled.value ? 4 : tripleComboEnabled.value ? 3 : 2;
  if (comboParticipantIds.value.length >= maxParticipants) {
    warningToast("BATAS PESERTA", `Battle ini membatasi combo ke ${maxParticipants} kartu.`);
    return;
  }
  comboParticipantIds.value = [...comboParticipantIds.value, id];
  if (!comboPrimaryCardId.value) comboPrimaryCardId.value = id;
};

const setComboPrimary = (card) => {
  const id = getCardId(card);
  if (!id) return;
  if (!comboParticipantIds.value.some((item) => String(item) === String(id))) {
    toggleComboParticipant(card);
  }
  if (comboParticipantIds.value.some((item) => String(item) === String(id))) {
    comboPrimaryCardId.value = id;
  }
};

const closeComboAttackModal = () => {
  comboAttackModalOpen.value = false;
};

const submitComboAttack = async () => {
  if (!validateActionTurn()) return;
  if (selectedComboParticipants.value.length < 2 || !comboPrimaryCardId.value) {
    warningToast("PILIH KARTU ACTIVE", "Pilih minimal dua kartu Active dan tentukan kartu utama.");
    return;
  }
  if (selectedComboParticipants.value.length === 3 && !tripleComboEnabled.value) {
    warningToast("TRIPLE COMBO NONAKTIF", "Game Setup belum mengaktifkan Triple Combo.");
    return;
  }
  if (selectedComboParticipants.value.length === 4 && !formationEnabled.value) {
    warningToast("FORMATION NONAKTIF", "Game Setup belum mengaktifkan Formation.");
    return;
  }
  if (!canSpendActionPoints(comboActionPointCost.value)) {
    warningToast("POIN GILIRAN TIDAK CUKUP", `Combo ini membutuhkan ${comboActionPointCost.value} poin giliran.`);
    return;
  }
  if (enemyActiveCards.value.length && !comboTargetCardId.value) {
    warningToast("PILIH TARGET", `Pilih Active Card milik ${enemyName.value}.`);
    return;
  }

  actionLoading.value = true;
  try {
    const { data, error: rpcError } = await supabase.rpc("submit_battle_action", {
      p_code: code.value,
      p_player: player.value,
      p_token: token.value,
      p_action: "combo_attack",
      p_card_id: comboPrimaryCardId.value,
      p_payload: {
        participant_card_ids: [
          comboPrimaryCardId.value,
          ...comboParticipantIds.value.filter((id) => String(id) !== String(comboPrimaryCardId.value)),
        ],
        target_card_id: comboTargetCardId.value || null,
      },
    });
    if (rpcError) throw rpcError;
    if (data?.ok === false) {
      warningToast("COMBO DITOLAK", data?.message ?? "Combo Attack tidak dapat dilakukan.");
      return;
    }

    closeComboAttackModal();
    selectedCardId.value = null;
    successToast(
      data?.combo_name ?? "COMBO ATTACK",
      `${data?.damage ?? 0} damage${data?.healing ? ` • pulih ${data.healing} HP` : ""}. ${selectedComboParticipants.value.length} kartu Active memakai kesempatan serangnya.`,
    );
  } catch (err) {
    errorToast("COMBO ERROR", playerErrorMessage(err, "Combo Attack gagal. Perbarui battle lalu coba lagi."));
  } finally {
    actionLoading.value = false;
  }
};

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

    const cardRequired = !["summon", "end_turn", "pass_turn"].includes(actionType);

    const defaultActionCost = {
      attack: 1,
      defense: 1,
      ultimate: 2,
      heal: 1,
      synergy: 1,
      summon: 1,
      special_skill: 1,
      fusion: 2,
    }[actionType] ?? 0;
    const actionCost = configuredActionPointCost(actionType, defaultActionCost);
    if (actionPointsEnabled.value && actionCost > ownActionPoints.value) {
      warningToast(
        "POIN GILIRAN TIDAK CUKUP",
        `${actionType.toUpperCase()} membutuhkan ${actionCost} poin giliran; tersisa ${ownActionPoints.value}.`,
      );
      return;
    }

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
      !enemyActiveCards.value.length
    ) {
      warningToast(
        "ULTIMATE TIDAK PUNYA TARGET",

        "Musuh tidak memiliki Active Card yang dapat terkena Ultimate.",
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
        await loadBattle(code.value);

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

      if (actionType === "ultimate") {
        const hitCount = Math.max(
          0,
          Number(data?.ultimate_target_count ?? 0) || 0,
        );
        const destroyedCount = Math.max(
          0,
          Number(data?.ultimate_destroyed_count ?? 0) || 0,
        );

        successToast(
          "⚡ ULTIMATE AOE SUCCESS",
          `${hitCount} Active Card terkena Ultimate${
            destroyedCount > 0 ? ` • ${destroyedCount} hancur` : ""
          }. Gauge kembali ke 0%.`,
        );
      } else {
        successToast(
          `${actionType.toUpperCase()} SUCCESS`,

          data?.message ??
            "Action berhasil diproses.",
        );
      }
    } catch (err) {
      console.error(
        "Submit action:",
        err,
      );

      errorToast(
        "ACTION ERROR",

        playerErrorMessage(err, "Aksi gagal diproses. Perbarui battle lalu coba lagi."),
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
    payload = {},
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
              getCardId(card),

            p_payload: payload,
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

        playerErrorMessage(err, "Kartu gagal dipindahkan. Coba lagi."),
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
      (questionTimeLimitSeconds.value > 0 && questionSecondsRemaining.value === 0) ||
      !questionReady.value,
  );

const questionTimeLimitSeconds = computed(() =>
  Math.max(0, Number(currentQuestion.value?.duration_seconds ?? battle.value?.question_time_limit_seconds ?? 0) || 0),
);
const questionImageUrl = computed(() => {
  const question = currentQuestion.value;
  if (!question) return "";
  // The score-debugging seed previously pointed at a generic logic image.
  // Use its matching illustration while keeping every other supplied image.
  if (question.id === "3e41c09d-1a15-5628-aa58-c78f2ad6f29b") {
    return "/images/questions/score-increment.svg";
  }
  return question.image_url ?? "";
});
const questionCodeLines = computed(() => codeLines(currentQuestion.value?.code_snippet));
const questionLearningEnabled = computed(() =>
  battle.value?.question_learning_enabled !== false,
);
const questionSecondsRemaining = ref(null);
const questionHintStep = ref(0);
const questionCorrectOption = ref("");
const questionBlockOrder = ref([]);
const questionWorkspace = ref(structuredClone(EMPTY_WORKSPACE));
watch(() => currentQuestion.value?.id, () => { questionWorkspace.value=JSON.parse(JSON.stringify(currentQuestion.value?.block_config?.initial ?? EMPTY_WORKSPACE)); });
const timedOutQuestionRound = ref(null);
let questionClockInterval = null;
let questionTimeoutRetryAt = 0;

const updateQuestionClock = () => {
  const limit = questionTimeLimitSeconds.value;
  const createdAt = currentQuestionRound.value?.created_at;
  if (!limit || !createdAt || !questionActive.value || currentQuestionRound.value?.winner_player) {
    questionSecondsRemaining.value = null;
    return;
  }
  questionSecondsRemaining.value = quizClockState(currentQuestionRound.value, limit).remaining;
  if (questionSecondsRemaining.value === 0) void expireQuestionRound();
};

const expireQuestionRound = async () => {
  const roundId = effectiveQuestionRoundId.value;
  if (!roundId || timedOutQuestionRound.value === roundId || !token.value || Date.now() < questionTimeoutRetryAt) return;
  timedOutQuestionRound.value = roundId;
  try {
    const { data, error: timeoutError } = await supabase.rpc("finish_battle_question_timeout", {
      p_code: code.value,
      p_player: player.value,
      p_token: token.value,
      p_question_round_id: roundId,
    });
    if (timeoutError) throw timeoutError;
    if (data?.timed_out) {
      questionResult.value = "timeout";
      void playSound("warning", 0.65);
      void refreshBattle();
    } else {
      timedOutQuestionRound.value = null;
      questionTimeoutRetryAt = Date.now() + 3000;
    }
  } catch (timeoutError) {
    timedOutQuestionRound.value = null;
    questionTimeoutRetryAt = Date.now() + 3000;
    console.error("Question timeout:", timeoutError);
  }
};

const initializeQuestionBlocks = () => {
  const blocks = Array.isArray(currentQuestion.value?.blocks)
    ? currentQuestion.value.blocks
    : [];
  questionBlockOrder.value = shuffleItems(blocks.map((text, originalIndex) => ({ text: String(text), originalIndex })));
  questionHintStep.value = 0;
};

const submitQuestionBlockOrder = () => {
  void answerQuestion(0, {
    order: questionBlockOrder.value.map((block) => block.originalIndex),
  });
};

const revealNextQuestionHint = () => {
  questionHintStep.value = Math.min(questionHints.value.length, questionHintStep.value + 1);
};

const questionRecommendation = computed(() => {
  const topic = String(currentQuestion.value?.learning_topic ?? currentQuestion.value?.category ?? "coding dasar")
    .replaceAll("_", " ");
  const links = {
    scratch: "https://scratch.mit.edu/ideas",
    block_coding: "https://scratch.mit.edu/ideas",
    programming_basics: "https://developer.mozilla.org/en-US/docs/Learn",
  };
  return {
    topic,
    url: currentQuestion.value?.learning_url || links[currentQuestion.value?.category] || "",
  };
});
const questionHints = computed(() =>
  [currentQuestion.value?.hint_1, currentQuestion.value?.hint_2]
    .map((hint) => String(hint ?? "").trim())
    .filter(Boolean),
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

    questionRewardChoices.value =
      [];

    bonusChoiceRoundId.value =
      null;

    questionCorrectOption.value = "";

    questionSubmissionRoundId.value =
      null;
  };

const answerQuestion =
  async (index, interactiveAnswer = null) => {
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
      const { data, error: rpcError } = await supabase.rpc(
        interactiveAnswer
          ? "submit_battle_interactive_question_answer"
          : "submit_battle_question_answer",
        interactiveAnswer
          ? {
              p_code: code.value,
              p_player: player.value,
              p_token: token.value,
              p_question_round_id: questionRoundId,
              p_interactive_answer: interactiveAnswer,
            }
          : {
              p_code: code.value,
              p_player: player.value,
              p_token: token.value,
              p_question_round_id: questionRoundId,
              p_answer_index: index,
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

      questionCorrectOption.value = String(data?.correct_option ?? "");

      if (data?.timed_out === true) {
        questionResult.value = "timeout";
        return;
      }

      if (
        data?.correct === true
      ) {
        questionResult.value =
          "correct";

        questionRewardChoices.value =
          Array.isArray(data?.reward_choices)
            ? data.reward_choices
            : [];

        bonusChoiceRoundId.value =
          questionRewardChoices.value.length
            ? questionRoundId
            : null;

        questionReward.value =
          data?.reward ??
          null;

        await loadBonusSkills();

        void playSound("correct", 0.86);

        successToast(
          "🏆 FIRST CORRECT!",

          questionRewardChoices.value.length
            ? `Pilih satu dari ${questionRewardChoices.value.length} bonus skill untuk melanjutkan battle.`
            : data?.reward
              ? `Bonus skill: ${bonusLabel(data.reward)}`
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

        void playSound("warning", 0.62);

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

      void playSound("wrong", 0.8);

      // The second wrong answer resolves the round on the server. Refresh
      // this player's session too, so the quiz closes even if realtime is late.
      void refreshBattle();

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

        playerErrorMessage(err, "Jawaban belum dapat dikirim. Silakan coba lagi."),
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
    const rule=quizBonusCatalog.value.find(item=>item.code===skill);
    if(rule)return rule.name;
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
    const rule=quizBonusCatalog.value.find(item=>item.code===skill);
    if(rule)return rule.icon;
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
    const rule=quizBonusCatalog.value.find(item=>item.code===skill);
    if(rule)return effectSummary(rule);
    const descriptions = {
      power_strike:
        "Serangan basic berikutnya memberi +50% damage dan habis setelah digunakan.",

      iron_guard:
        "Defense aktif; damage dari serangan berikutnya berkurang 50%.",

      recovery:
        "Memulihkan 25% HP maksimum pemain.",

      overcharge:
        "Menambah 50 poin Ultimate Gauge, maksimal 100.",

      cleanse:
        "Menghapus efek penurunan Attack yang sedang aktif.",
    };

    return (
      descriptions[skill] ??
      "Bonus skill dari Coding Challenge."
    );
  };

// =========================================================
// LOAD BONUS
// =========================================================

const loadPendingBonusChoice =
  async () => {
    if (!battle.value?.id || !token.value) return null;
    const sessionId=battle.value.id;

    const { data, error: choiceError } = await supabase.rpc(
      "get_battle_question_bonus_choice",
      {
        p_code: code.value,
        p_player: player.value,
        p_token: token.value,
      },
    );

    if (choiceError || data?.ok === false) {
      if (choiceError) console.warn("Load quiz skill choices:", choiceError);
      return null;
    }

    if(battle.value?.id!==sessionId || (effectiveQuestionRoundId.value && data?.question_round_id && effectiveQuestionRoundId.value!==data.question_round_id))return null;
    const choices = Array.isArray(data?.choices) ? data.choices : [];
    if (!data?.pending || choices.length < 1 || choices.length > 6) return null;

    bonusChoiceRoundId.value = data.question_round_id;
    questionRewardChoices.value = choices;
    questionReward.value = null;
    questionResult.value = "correct";
    selectedQuestionAnswer.value = Number.isInteger(data.winner_answer)
      ? data.winner_answer
      : null;
    return data;
  };

const chooseQuestionBonus =
  async (skillType) => {
    const roundId = bonusChoiceRoundId.value;
    if (
      !roundId ||
      bonusChoiceSubmitting.value ||
      !questionRewardChoices.value.includes(skillType)
    ) return;

    bonusChoiceSubmitting.value = true;
    bonusChoiceSelectedCode.value=skillType;
    try {
      const { data, error: choiceError } = await supabase.rpc(
        "choose_battle_question_bonus",
        {
          p_code: code.value,
          p_player: player.value,
          p_token: token.value,
          p_question_round_id: roundId,
          p_skill_type: skillType,
        },
      );

      if (choiceError) throw choiceError;
      if (data?.ok === false) {
        warningToast("PILIHAN SKILL DITOLAK", data?.message ?? "Skill belum dapat dipilih.");
        return;
      }

      const selectedSkill = data?.skill_type ?? skillType;
      if(bonusChoiceRoundId.value!==roundId){await loadBonusSkills();return;}
      questionReward.value = selectedSkill;
      questionRewardChoices.value = [];
      bonusChoiceRoundId.value = null;
      await loadBonusSkills();
      void playSound("correct", 0.72);
      successToast(
        bonusLabel(selectedSkill).toUpperCase(),
        "Skill sudah masuk ke panel Bonus Skills. Gunakan saat giliranmu.",
      );
    } catch (err) {
      console.error("Pilih bonus skill:", err);
      errorToast(
        "SKILL ERROR",
        playerErrorMessage(err, "Pilihan skill gagal disimpan. Coba lagi."),
      );
    } finally {
      bonusChoiceSubmitting.value = false;
      bonusChoiceSelectedCode.value=null;
    }
  };

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
      bonusUsingId.value || waitingForRfid.value || actionLoading.value || battleFinished.value || turnSecondsRemaining.value===0
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

      const rule=quizBonusCatalog.value.find(item=>item.code===skill);
      const message=rule
        ? data?.effect_type==='heal_percent'||data?.effect_type==='heal_flat'
          ? `HP pemain pulih +${data.heal??0}.`
          : data?.effect_type==='add_gauge'
            ? `Ultimate Gauge bertambah +${data.gauge_added??0}.`
            : effectSummary(rule)
        : data?.message??bonusDescription(skill);

      successToast(
        bonusLabel(skill).toUpperCase(),

        message,
      );
    } catch (err) {
      console.error(
        "Use bonus:",
        err,
      );

      errorToast(
        "BONUS ERROR",

        playerErrorMessage(err, "Bonus skill gagal digunakan. Coba lagi."),
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
  () => currentQuestionRound.value?.winner_player,
  (winner) => {
    if (!winner) return;
    if (winner === player.value) {
      void loadPendingBonusChoice();
    } else {
      questionResult.value = "lost";
    }
  },
);

watch(
  () => `${effectiveQuestionRoundId.value}:${currentQuestion.value?.id}`,
  () => {
    initializeQuestionBlocks();
    timedOutQuestionRound.value = null;
  },
);

watch(
  [
    questionActive,
    effectiveQuestionRoundId,
    () => currentQuestionRound.value?.created_at,
    () => currentQuestionRound.value?.winner_player,
    questionTimeLimitSeconds,
  ],
  ([active, roundId, , winner]) => {
    if (questionClockInterval) {
      window.clearInterval(questionClockInterval);
      questionClockInterval = null;
    }
    questionSecondsRemaining.value = null;
    if (!active || !roundId || winner || questionTimeLimitSeconds.value <= 0) return;
    updateQuestionClock();
    questionClockInterval = window.setInterval(updateQuestionClock, 250);
  },
  { immediate: true },
);

watch(
  questionActive,

  (
    active,
    previous,
  ) => {
    /*
     * Question harus mengambil alih seluruh interaction.
     * Ini menutup Target Picker dan viewer yang sebelumnya
     * dapat berada di atas / menangkap klik.
     */
    if (
      active &&
      !previous
    ) {
      resetQuestionInteraction();

      cancelTargetAttack(
        true,
      );

      selectedTargetCardId.value =
        null;

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
// PHASE 3D.16 • EVENT CONTRACT HELPERS
// =========================================================

const battleEventContractVersion = (event) =>
  String(battleEventPayload(event)?.event_contract ?? "legacy");

const battleEventEffectType = (event) =>
  String(
    battleEventPayload(event)?.effect_type ??
      battleEventPayload(event)?.effect?.type ??
      "",
  ).toLowerCase();

// =========================================================
// PHASE 3D.18 • STATUS REFRESH
// =========================================================

watch(
  latestBattleEvent,
  (event) => {
    const type = String(event?.type ?? "").toLowerCase();
    if (STATUS_REFRESH_EVENT_TYPES.has(type)) {
      void loadStatusEffects();
    }
  },
);

watch(
  () => battle.value?.id,
  (battleId, previousBattleId) => {
    if (battleId && battleId !== previousBattleId) {
      void loadStatusEffects();
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
      void loadGraveyardCards();
    }
  },
);

// =========================================================
// REALTIME BATTLE SOUND
// =========================================================

watch(
  latestBattleEvent,
  (event) => {
    handleBattleSoundEvent(event);
  },
);

watch(
  questionActive,
  (active, previous) => {
    if (active && !previous) {
      void playSound("question", 0.74);
    }
  },
);

// =========================================================
// INCOMING PLAYER NOTIFICATION / HAPTIC
// =========================================================

watch(
  latestBattleEvent,
  (event) => {
    notifyIncomingBattleEvent(event);
  },
);

watch(
  ownDeckRemaining,
  (current, previous) => {
    if (
      previous == null ||
      Number(current) >= Number(previous)
    ) {
      return;
    }

    // Deck count turun: beri visual pulse.
    // Toast Summon tetap memakai flow existing agar tidak duplicate.
    triggerDeckReaction({ vibrate: true });
  },
);

// =========================================================
// TARGET MODE SAFETY
// =========================================================

watch(() => spotlightTurn(battle.value), () => {
  sharedViewer.value = null;
  void syncCloseViewer();
});

watch(selectedCardId, id => {
  if (id != null && isMyTurn.value) {
    void syncFocusCards({ selectedCardId: id, turn: spotlightTurn(battle.value) });
  }
});
watch(selectedTargetCardId, id => {
  if (id != null && isMyTurn.value) {
    void syncFocusCards({ targetCardId: id, turn: spotlightTurn(battle.value) });
  }
});
watch([comboPrimaryCardId, comboTargetCardId], ([source, target], [previousSource, previousTarget]) => {
  if (!isMyTurn.value) return;
  void syncFocusCards({
    selectedCardId: source !== previousSource ? source : null,
    targetCardId: target !== previousTarget ? target : null,
    turn: spotlightTurn(battle.value),
  });
});

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
        "ultimate",
        "special_effect",
        "special_skill",
        "fusion",
      ].includes(String(event.type ?? "").toLowerCase())
    ) {
      void loadPlayerFusions();
    }

    if (event.type === "fusion") {
      void loadFusionHistory();
      // Graveyard refresh sudah ditangani watcher zone/event di atas.
      // Jangan request data yang sama dua kali untuk satu event Fusion.

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

// Display existing engine readiness; previews never submit a battle action.
const pendingPanelAction = ref(null);
const cancelSummon = async () => {
  const requestId=battle.value?.pending_summon_request_id;
  if (actionLoading.value || !waitingForRfid.value || !isMyTurn.value || !requestId) return;
  actionLoading.value=true;
  try {
    const {data,error:cancelError}=await supabase.rpc('cancel_battle_summon',{
      p_code:code.value,p_player:player.value,p_token:token.value,p_request_id:requestId,
    });
    if(cancelError)throw cancelError;
    if(data?.ok){
      const refunded=Math.max(0,Number(data.action_points_refunded)||0);
      successToast('SUMMON DIBATALKAN',refunded ? `${refunded} AP dikembalikan. Kamu bisa memilih aksi lain.` : 'Kamu bisa memilih aksi lain.');
    } else warningToast('SUMMON TIDAK DIBATALKAN',data?.message || 'Kondisi kartu berubah. Periksa lapanganmu.');
  } catch(cancelError){
    errorToast('PEMBATALAN GAGAL',cancelError?.code==='PGRST202'
      ? 'Pembatalan belum tersedia pada server battle ini.'
      : playerErrorMessage(cancelError,'Status pembatalan belum terkonfirmasi. Periksa battle sebelum mencoba lagi.'));
  } finally {
    // Refresh on rejection/timeout too: a scan may have won the race.
    try { await Promise.all([loadBattle(code.value),loadGraveyardCards()]); }
    finally { actionLoading.value=false; }
  }
};
const panelBlockReason = computed(() => {
  if (questionActive.value) return 'Selesaikan kuis terlebih dahulu.';
  if (battleFinished.value) return 'Pertandingan sudah selesai.';
  if (waitingForRfid.value) return 'Tempelkan kartu ke pembaca RFID untuk menyelesaikan Summon.';
  if (actionLoading.value) return 'Aksi sebelumnya sedang diproses.';
  if (!isMyTurn.value) return `Tunggu giliranmu. Sekarang giliran ${enemyName.value}.`;
  if (turnSecondsRemaining.value === 0) return 'Waktu giliran habis. Menunggu pergantian giliran.';
  return '';
});
const actionPanelContext = computed(() => ({
  card: selectedCard.value, myTurn: isMyTurn.value,
  apEnabled: actionPointsEnabled.value, ap: ownActionPoints.value, maxAp: actionPointsPerTurn.value,
  seconds: turnTimerVisible.value ? turnSecondsRemaining.value : null,
  scanning: waitingForRfid.value,
  canCancelSummon:Boolean(battle.value?.pending_summon_request_id && isMyTurn.value && turnSecondsRemaining.value!==0),
  cancelSummonHint:!Object.hasOwn(battle.value??{},'pending_summon_request_id') ? 'Pembatalan belum tersedia pada server battle ini.'
    : turnSecondsRemaining.value===0 ? 'Waktu giliran habis. Menunggu pembaruan battle.' : 'Menyinkronkan status scan…',
  scope: `${spotlightTurn(battle.value)}:${selectedCardId.value ?? ''}`,
  interrupted: questionActive.value || waitingForRfid.value || battleFinished.value || !isMyTurn.value,
  hint: (waitingForRfid.value ? 'Belum ada kartu baru yang masuk.' : panelBlockReason.value) || (selectedCard.value
    ? `ATK ${selectedCard.value.attack ?? 0} · DEF ${selectedCard.value.defense ?? 0} — pilih aksi untuk kartu ini.`
    : 'Pilih kartu di lapangan atau panggil kartu baru.'),
}));
const panelActions = computed(() => {
  const needCard = selectedCard.value ? '' : 'Pilih kartu Active terlebih dahulu.';
  const noAp = (key, fallback) => canSpendActionPoints(configuredActionPointCost(key, fallback))
    ? '' : `Butuh ${configuredActionPointCost(key, fallback)} AP; kamu memiliki ${ownActionPoints.value} AP.`;
  const make = (key, label, icon, fallback, enabled, reason, description, primary = false) => {
    const blocked = panelBlockReason.value || reason;
    const cost = configuredActionPointCost(key === 'combo' ? 'combo_attack' : key, fallback);
    return {key, label, icon, primary, description, cost,
      ready: Boolean(enabled && !blocked), reason: blocked,
      shortReason: blocked === needCard && needCard ? 'Pilih kartu dulu' : blocked?.startsWith('Butuh ') ? 'AP belum cukup' : blocked?.startsWith('Tunggu giliran') ? 'Giliran lawan' : blocked ? 'Lihat syarat' : '',
      costLabel: actionPointsEnabled.value ? `${cost} AP` : 'Satu aksi',
    };
  };
  const attackReason = needCard || (selectedCardAlreadyAttacked.value ? 'Kesempatan serang kartu ini sudah habis pada giliran ini.' : '')
    || (isTcgV1.value && !enemyActiveCards.value.length && !directAttackAvailable.value ? 'Lawan tidak memiliki kartu Active dan serangan langsung tidak diaktifkan.' : '') || noAp('attack', 1);
  const summonReason = activeCards.value.length >= maxActive.value ? 'Active penuh. Pindahkan satu kartu ke Bench terlebih dahulu.'
    : isTcgV1.value && ownDeckRemaining.value <= 0 ? 'Deck-mu sudah habis.' : noAp('summon', 1);
  const skillsReason = needCard || (!specialSkillFeatureEnabled.value ? 'Skill kartu tidak diaktifkan pada pertandingan ini.' : '')
    || (specialSkillLoading.value ? 'Sedang memuat skill kartu.' : '') || (!runtimeSpecialSkills.value.length ? 'Kartu ini tidak memiliki skill yang tersedia pada battle ini.' : '');
  const actions = [
    make('summon', 'Panggil kartu', '◉', 1, canSummonUi.value, summonReason, 'Mulai Summon, lalu scan UID kartu fisik terdaftar ke slot Active yang kosong.', true),
    make('attack', 'Serang', '⚔', 1, canAttackUi.value, attackReason, 'Pilih target lawan dan periksa serangan sebelum mengonfirmasi.', true),
    make('special', 'Skill kartu', readySpecialSkills.value[0]?.icon || runtimeSpecialSkills.value[0]?.icon, 1, Boolean(selectedCard.value && runtimeSpecialSkills.value.length), skillsReason, 'Lihat kedua skill, biaya, target, cooldown dan alasan terkuncinya. Memilih skill belum menjalankan aksi.', true),
  ];
  // Skill inspection remains available even when both skills are cooling down.
  actions[2].costLabel = `${runtimeSpecialSkills.value.length} skill · ${readySpecialSkills.value.length} siap`;
  if (isTcgV1.value && comboEnabled.value) actions.push(make('combo', 'Combo', '⚒', 2, canComboAttackUi.value,
    comboEligibleActiveCards.value.length < 2 ? 'Perlu sedikitnya dua kartu Active yang masih boleh menyerang.' : !actionPointsEnabled.value ? 'Combo memerlukan aturan AP yang aktif.' : noAp('combo_attack', 2),
    'Serangan bersama dari kartu Active. Pilih peserta, kartu utama, lalu target lawan.'));
  if (fusionFeatureEnabled.value) actions.push(make('fusion', 'Fusion', '◇', 2,
    !fusionLoading.value && canSpendActionPoints(configuredActionPointCost('fusion', 2)),
    fusionLoading.value ? 'Sedang memeriksa resep Fusion.' : noAp('fusion', 2),
    'Lihat resep, material, dan kartu hasil. Material baru dikonsumsi setelah kamu mengonfirmasi.'));
  actions.push(make('ultimate', 'Ultimate', 'ϟ', 2, canUltimateUi.value,
    needCard || (!enemyActiveCards.value.length ? 'Tidak ada kartu Active lawan untuk terkena Ultimate.' : '') || (ownSkill.value < 100 ? `Gauge Ultimate ${ownSkill.value}%; perlu 100%.` : '') || noAp('ultimate', 2),
    'Serangan Ultimate ke kartu-kartu Active lawan. Periksa sasaran dan biaya; gauge terpakai setelah berhasil.'));
  actions.push(make('heal', 'Pulihkan HP', '✚', 1, canHealUi.value,
    needCard || (ownHealUsed.value ? 'Jatah Heal pada pertandingan ini sudah dipakai.' : '') || (ownHp.value > ownMaxHp.value * .5 ? 'HP pemain harus 50% atau lebih rendah untuk memakai Heal.' : '') || noAp('heal', 1),
    'Memulihkan HP pemain sesuai aturan battle. Pemulihan HP kartu menggunakan skill kartu.'));
  actions.push(make('synergy', 'Synergy', '✧', 1, canSynergyUi.value,
    needCard || (!selectedSynergyInfo.value?.ready ? selectedSynergyInfo.value?.effect || 'Kombinasi kartu belum memenuhi syarat Synergy.' : '') || noAp('synergy', 1),
    selectedSynergyInfo.value?.effect || 'Aktifkan efek dari kombinasi tipe kartu yang memenuhi syarat.'));
  if (!actionPointsEnabled.value) actions.push(make('defense', 'Bertahan', '🛡', 1, canDefenseUi.value, needCard,
    'Memakai aksi bertahan sesuai aturan Classic. Periksa efek sebelum mengonfirmasi.'));
  if (actionPointsEnabled.value) actions.push(make('end_turn', 'Akhiri giliran', '→|', 0, isMyTurn.value, '', 'Menyerahkan giliran kepada lawan. Sisa AP tidak dibawa ke giliran berikutnya.'));
  return actions;
});

function requestPanelReview(key, direct = false) {
  if (panelBlockReason.value) return;
  pendingPanelAction.value = {key, direct, sourceId:selectedCardId.value, scope:spotlightTurn(battle.value)};
}
const panelReview = computed(() => {
  const pending = pendingPanelAction.value;
  if (!pending) return null;
  const action = panelActions.value.find(item => item.key === pending.key);
  if (!action) return null;
  const isEnd = pending.key === 'end_turn';
  const directChanged = pending.key === 'attack' && pending.direct && !directAttackAvailable.value;
  const facts = isEnd ? [{label:'Giliran berikutnya',value:enemyName.value}]
    : [{label:'Kartu sumber',value:selectedCard.value?.name ?? '—'}, {label:'Sasaran',value:pending.key === 'attack' ? enemyName.value : pending.key === 'ultimate' ? `${enemyActiveCards.value.length} kartu Active lawan` : pending.key === 'heal' ? playerName.value : 'Sesuai efek aksi'}];
  if (actionPointsEnabled.value) facts.push({label:'Biaya',value:`${action.cost} AP`},{label:'AP setelah aksi',value:isEnd ? '0 AP — giliran berakhir' : `${Math.max(0,ownActionPoints.value-action.cost)} AP`});
  return { title:isEnd ? 'Akhiri giliranmu?' : `${pending.direct ? 'Serangan langsung' : action.label}?`,
    description:pending.direct ? 'Kartu ini akan menyerang HP pemain lawan. Periksa biaya sebelum melanjutkan.' : action.description, facts,
    warning:isEnd && ownActionPoints.value > 0 ? `Masih ada ${ownActionPoints.value} AP. AP ini tidak akan disimpan.` : pending.direct ? 'Serangan langsung mengenai HP pemain karena tidak ada kartu Active lawan.' : '',
    ready:action.ready && !directChanged,
    reason:directChanged ? 'Kondisi target berubah. Batalkan dan pilih serangan kembali.' : action.ready ? '' : action.reason,
    confirmLabel:isEnd ? 'Ya, akhiri giliran' : 'Konfirmasi aksi',
  };
});
function choosePanelAction(key) {
  const action = panelActions.value.find(item => item.key === key);
  if (!action?.ready || panelBlockReason.value) return;
  if (key === 'attack') beginAttackAction();
  else if (key === 'special') openSpecialSkillModal();
  else if (key === 'combo') void openComboAttackModal();
  else if (key === 'fusion') void openFusionModal();
  else if (key === 'summon') void submitAction('summon');
  else requestPanelReview(key);
}
async function confirmPanelAction() {
  if (actionLoading.value || !panelReview.value?.ready) return;
  const pending = pendingPanelAction.value;
  if (!pending || pending.scope !== spotlightTurn(battle.value) || (pending.key !== 'end_turn' && pending.sourceId !== selectedCardId.value)) return;
  if (pending.direct) await submitDirectAttack();
  else await submitAction(pending.key);
  pendingPanelAction.value = null;
}
watch([() => spotlightTurn(battle.value), selectedCardId, () => selectedCard.value ? getCardId(selectedCard.value) : null, isMyTurn, questionActive, waitingForRfid, battleFinished], () => {
  pendingPanelAction.value = null;
  if (panelBlockReason.value && !actionLoading.value) closeComboAttackModal();
});
useActionDialogFocus([
  {open:attackTargetMode,selector:'.target-picker-panel',close:() => cancelTargetAttack(true)},
  {open:specialSkillModalOpen,selector:'.special-skill-modal',close:() => closeSpecialSkillModal(true)},
  {open:comboAttackModalOpen,selector:'.combo-attack-modal',close:closeComboAttackModal},
  {open:fusionModalOpen,selector:'.fusion-modal',close:() => closeFusionModal(true)},
], actionLoading);

onMounted(
  async () => {
    preloadBattleSounds();
    registerAudioUnlock();

    if (!code.value) {
      return;
    }

    await loadBattle(
      code.value,
      { requireActive: true },
    );

    if (
      battle.value
    ) {
      turnClockNow.value = Date.now();
      void syncBattleTurnClock();
      turnClockTickInterval = window.setInterval(() => {
        turnClockNow.value = Date.now();
      }, 1000);
      turnClockSyncInterval = window.setInterval(() => {
        void syncBattleTurnClock();
      }, 3000);
      document.addEventListener("visibilitychange", onTurnClockVisibilityChange);

      if (!firePassiveStatusPoll) {
        firePassiveStatusPoll = window.setInterval(() => {
          if (battle.value?.id) void loadStatusEffects();
        }, 2500);
      }
      await Promise.all([
        loadBonusSkills(),

        loadPendingBonusChoice(),

        loadGraveyardCards(),

        loadPlayerFusions(),

        loadFusionHistory(),

        loadStatusEffects(),
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
        if (isMyTurn.value) {
          await syncFocusCards({
            selectedCardId: selectedCardId.value,
            targetCardId: selectedTargetCardId.value,
            turn: spotlightTurn(battle.value),
          });
          if (sharedViewer.value && !questionActive.value) {
            const { zone, index } = sharedViewer.value;
            await syncOpenViewer(zone, index, spotlightTurn(battle.value), getCardId(viewedPileCard(zone, index)));
          }
        }
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
    document.body.classList.remove("tcg-card-dragging");

    if (turnClockTickInterval) {
      window.clearInterval(turnClockTickInterval);
      turnClockTickInterval = null;
    }
    if (turnClockSyncInterval) {
      window.clearInterval(turnClockSyncInterval);
      turnClockSyncInterval = null;
    }
    document.removeEventListener("visibilitychange", onTurnClockVisibilityChange);
    if (questionClockInterval) {
      window.clearInterval(questionClockInterval);
      questionClockInterval = null;
    }
    if (firePassiveStatusPoll) {
      window.clearInterval(firePassiveStatusPoll);
      firePassiveStatusPoll = null;
    }
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

    clearReactionTimer(incomingCardTimer);
    clearReactionTimer(incomingImpactTimer);
    clearReactionTimer(incomingFlashTimer);
    clearReactionTimer(deckReactionTimer);
    clearNecroRebirthTimers();
    necroRebirthCinematic.value = {
      show: false,
      phase: "idle",
      source: null,
      target: null,
    };
    stopDeviceVibration();
    unregisterAudioUnlock();
    stopAllBattleSounds();

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
    :class="[
      player,
      {
        'incoming-impact': incomingImpactActive,
        'deck-reacting': deckReactionActive,
      },
    ]"
  >
    <!-- INCOMING IMPACT FLASH -->

    <Transition name="impact-flash">
      <div
        v-if="incomingImpactFlash"
        class="incoming-impact-flash"
        :class="incomingImpactFlash"
      />
    </Transition>

    <Transition name="target-picker">
      <div v-if="avatarSelectionRequired || avatarPickerOpen" class="avatar-picker-overlay">
        <div
          class="avatar-picker-backdrop"
          @click="!avatarSelectionRequired && (avatarPickerOpen = false)"
        />
        <section class="avatar-picker-panel" role="dialog" aria-modal="true" aria-labelledby="avatar-picker-title">
          <span class="avatar-picker-eyebrow">TIMEDOOR BATTLE</span>
          <h2 id="avatar-picker-title">Pilih avatar pemain</h2>
          <p v-if="ownAvatarImage">Foto dari Game Setup sedang digunakan. Memilih avatar di bawah akan mengganti foto di halaman battle dan layar pertandingan.</p>
          <p v-else>Avatar ini akan terlihat di halaman battle dan layar pertandingan.</p>
          <img
            v-if="ownAvatarImage"
            class="avatar-current-photo"
            :src="ownAvatarImage"
            :alt="`Foto ${playerName} yang sedang digunakan`"
          />
          <div class="avatar-picker-grid" role="radiogroup" aria-label="Pilihan avatar">
            <button
              v-for="avatar in playerAvatarOptions"
              :key="avatar"
              type="button"
              class="avatar-choice"
              :class="{ selected: avatarDraft === avatar }"
              role="radio"
              :aria-checked="avatarDraft === avatar"
              :aria-label="`Pilih avatar ${avatar}`"
              @click="avatarDraft = avatar; avatarSaveError = ''"
            >{{ avatar }}</button>
          </div>
          <p v-if="avatarSaveError" class="avatar-picker-error" role="alert">{{ avatarSaveError }}</p>
          <div class="avatar-picker-actions">
            <button
              v-if="!avatarSelectionRequired"
              type="button"
              class="avatar-cancel"
              :disabled="avatarSaving"
              @click="avatarPickerOpen = false"
            >{{ ownAvatarImage ? "Tetap pakai foto" : "Nanti" }}</button>
            <button
              type="button"
              class="avatar-confirm"
              :disabled="!avatarDraft || avatarSaving"
              @click="savePlayerAvatar"
            >{{ avatarSaving ? "Menyimpan…" : "Pakai avatar ini" }}</button>
          </div>
        </section>
      </div>
    </Transition>

    <!-- PHASE 3C.1 • NECRO SOUL REBIRTH -->

    <Transition name="necro-rebirth">
      <div
        v-if="necroRebirthCinematic.show"
        class="necro-rebirth-overlay"
        :class="`phase-${necroRebirthCinematic.phase}`"
      >
        <div class="necro-rebirth-vignette" />

        <section class="necro-rebirth-stage">
          <article class="necro-rebirth-card sacrifice-card">
            <div class="necro-card-aura" />
            <img
              v-if="necroCardImage(necroRebirthCinematic.source)"
              :src="necroCardImage(necroRebirthCinematic.source)"
              :alt="necroRebirthCinematic.source?.name"
            />
            <div v-else class="necro-card-placeholder">☠</div>
            <strong>{{ necroRebirthCinematic.source?.name ?? "Necro Card" }}</strong>
            <small>SACRIFICE</small>
          </article>

          <div class="necro-soul-core">
            <span>☠</span>
            <i />
            <b>SOUL</b>
          </div>

          <article class="necro-rebirth-card revived-card">
            <div class="necro-card-aura" />
            <img
              v-if="necroCardImage(necroRebirthCinematic.target)"
              :src="necroCardImage(necroRebirthCinematic.target)"
              :alt="necroRebirthCinematic.target?.name"
            />
            <div v-else class="necro-card-placeholder">✦</div>
            <strong>{{ necroRebirthCinematic.target?.name ?? "Revived Card" }}</strong>
            <small>REVIVE • {{ necroRestoredHp(necroRebirthCinematic.target) }} HP</small>
          </article>
        </section>

        <div class="necro-rebirth-copy">
          <small>NECRO SPECIAL SKILL</small>
          <h2>SOUL REBIRTH</h2>
          <p>One soul falls. Another returns.</p>
        </div>
      </div>
    </Transition>

    <!-- PLAYER SOUND CONTROL -->

    <button
      type="button"
      class="battle-sound-toggle"
      :class="{
        muted: !soundEnabled,
        locked: soundEnabled && !audioUnlocked,
      }"
      @click.stop="toggleBattleSound"
    >
      <span class="battle-sound-icon">
        {{ soundEnabled && audioUnlocked ? "🔊" : "🔇" }}
      </span>

      <span class="battle-sound-copy">
        {{ battleSoundLabel }}
      </span>
    </button>

    <!-- NON-BLOCKING BATTLE REFRESH -->

    <Transition name="battle-sync">
      <div
        v-if="battleRefreshing"
        class="battle-sync-chip"
        role="status"
        aria-live="polite"
      >
        <span class="battle-sync-spinner" />
        <span>SYNCING</span>
      </div>
    </Transition>

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
      v-if="initialBattleLoading"
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
          <button
            type="button"
            class="player-avatar"
            :aria-label="`Avatar ${playerName}. Klik untuk mengganti avatar.`"
            title="Ganti avatar"
            @click="openAvatarPicker"
          >
            <img v-if="ownAvatarImage" :src="ownAvatarImage" :alt="`Avatar ${playerName}`" />
            <span v-else>{{ ownAvatar || (player === "p1" ? "👦🏻" : "🧑🏽‍🦱") }}</span>
          </button>

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
              :class="ownHpState"
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

          <div v-if="ownStatusEffects.length" class="hud-status-strip">
            <span
              v-for="status in ownStatusEffects.slice(0, 4)"
              :key="`own-${status.key}`"
              class="battle-status-chip"
              :class="status.tone"
              :title="statusTooltip(status)"
            >
              <b>{{ status.icon }}</b>
              <em>{{ status.label }}</em>
              <small v-if="status.valueText">{{ status.valueText }}</small>
              <small v-if="status.durationText">{{ status.durationText }}</small>
            </span>
            <span v-if="ownStatusEffects.length > 4" class="status-more">
              +{{ ownStatusEffects.length - 4 }}
            </span>
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

            <span v-if="actionPointsEnabled" class="turn-ap-summary" title="Poin Giliran dipakai untuk melakukan aksi. Poin terisi kembali saat giliranmu dimulai.">
              <b>{{ ownActionPoints }} Poin Giliran</b> tersisa
              <small>• lawan {{ enemyActionPoints }} poin</small>
            </span>

            <span
              v-if="turnTimerVisible && turnSecondsRemaining !== null"
              class="turn-countdown"
              :class="{ urgent: turnClockUrgent }"
              :aria-label="`${turnSecondsRemaining} detik ${isMyTurn ? 'tersisa untuk giliranmu' : 'tersisa untuk giliran lawan'}`"
            >
              <b>◷ {{ turnSecondsRemaining }}s</b>
              <small>{{ isMyTurn ? "SISA GILIRANMU" : "WAKTU GILIRAN LAWAN" }}</small>
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
              :class="enemyHpState"
              :style="{
                width:
                  `${enemyHpPercent}%`,
              }"
            />
          </div>

          <div v-if="enemyStatusEffects.length" class="enemy-status-strip">
            <span
              v-for="status in enemyStatusEffects.slice(0, 3)"
              :key="`enemy-${status.key}`"
              class="battle-status-chip compact"
              :class="status.tone"
              :title="statusTooltip(status)"
            >
              <b>{{ status.icon }}</b>
              <small>{{ status.valueText || status.label }}</small>
            </span>
            <span v-if="enemyStatusEffects.length > 3" class="status-more">
              +{{ enemyStatusEffects.length - 3 }}
            </span>
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
          :draggable-cards="false"
          :show-bench-action="true"
          :bench-action-enabled="benchReturnActionEnabled"
          :bench-action-label="benchReturnActionLabel"
          :bench-action-hint="benchReturnActionHint"
          @viewer-open="
            handleZoneViewerOpen
          "
          @viewer-close="
            handleZoneViewerClose
          "
          @viewer-index-change="
            handleZoneViewerIndex
          "
          @bench-action="
            returnBenchCardToActive
          "
        />

        <!-- ACTIVE -->

        <section
          class="
            cyber-panel
            active-panel
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
              <span
                class="deck-remaining-chip"
                :class="{
                  'incoming-deck-hit': deckReactionActive,
                }"
              >
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
            class="deck-slots"
            :style="{ '--active-slot-count': maxActive }"
          >
            <article
              v-for="card in activeCards"
              :key="
                card.battleId ??
                card.id
              "
              class="
                cyber-card
              "
              :class="[
                {
                  selected:
                    selectedCardId ===
                    (
                      card.battleId ??
                      card.id
                    ),

                  exhausted:
                    card.exhausted,

                  'incoming-hit':
                    isIncomingReactionCard(card),
                },
                {
                  'fx-defense-active': getCardFxFlags(card).defense,
                  'fx-shield-active': getCardFxFlags(card).shield,
                  'fx-necro-active': getCardFxFlags(card).necro,
                  'fx-fusion-active': getCardFxFlags(card).fusion,
                  'fx-burn-active': getCardFxFlags(card).burn,
                  'fx-freeze-active': getCardFxFlags(card).freeze,
                  'fx-poison-active': getCardFxFlags(card).poison,
                  'fx-stun-active': getCardFxFlags(card).stun,
                  'fx-curse-active': getCardFxFlags(card).curse,
                },
              ]"
              @click="
                selectCard(card)
              "
            >
              <div class="card-fx-stack" aria-hidden="true">
                <i v-if="getCardFxFlags(card).fusion" class="card-fx-layer fx-fusion-layer"></i>
                <i v-if="getCardFxFlags(card).necro" class="card-fx-layer fx-necro-layer"></i>
              </div>
              <CardStatusVfx
                :shield="getCardFxFlags(card).shield"
                :defense="getCardFxFlags(card).defense"
                :burn="getCardFxFlags(card).burn"
                :freeze="getCardFxFlags(card).freeze"
                :stun="getCardFxFlags(card).stun"
                :poison="getCardFxFlags(card).poison"
                :curse="getCardFxFlags(card).curse"
              />

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

                <div
                  v-if="visibleCardStatuses(card).length"
                  class="card-status-row"
                >
                  <span
                    v-for="status in visibleCardStatuses(card).slice(0, 3)"
                    :key="`${getCardId(card)}-${status.key}`"
                    class="card-status-badge"
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
                    class="card-status-badge more"
                  >
                    +{{ visibleCardStatuses(card).length - 3 }}
                  </span>
                </div>

                <div class="card-hp-block">
                  <div class="card-hp-copy">
                    <span>CARD HP</span>

                    <strong>
                      {{ getCardCurrentHp(card) }}
                      /
                      {{ getCardMaxHp(card) }}
                    </strong>
                  </div>

                  <div class="card-hp-track">
                    <div
                      class="card-hp-fill"
                      :class="getCardHpState(card)"
                      :style="{
                        width: `${getCardHpPercent(card)}%`,
                      }"
                    >
                      <span class="card-hp-shine" />
                    </div>
                  </div>
                </div>

                <div class="cyber-card-image">
                  <img
                    v-if="
                      card.image_url
                    "
                    draggable="false"
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

                <button
                  type="button"
                  class="card-zone-action"
                  :disabled="!canMoveActiveCardToBench(card)"
                  @click.stop="moveActiveCardToBench(card)"
                >
                  <span aria-hidden="true">↓</span>
                  <span class="card-zone-action-copy">
                    Pindahkan ke Bench
                    <small>
                      {{ configuredActionPointCost("switch", 1) }} poin giliran
                    </small>
                  </span>
                </button>
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

          <section class="target-picker-panel" role="dialog" aria-modal="true" aria-labelledby="attack-picker-title" tabindex="-1">
            <header class="target-picker-header">
              <div>
                <span class="eyebrow">
                  SERANG • PILIH TARGET → PERIKSA → KONFIRMASI
                </span>

                <h2 id="attack-picker-title">
                  Pilih kartu lawan
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
                    <div class="target-card-hp-copy">
                      <span>HP</span>

                      <b>
                        {{ getCardCurrentHp(card) }}
                        /
                        {{ getCardMaxHp(card) }}
                      </b>
                    </div>

                    <div class="target-card-hp-track">
                      <div
                        class="target-card-hp-fill"
                        :class="getCardHpState(card)"
                        :style="{
                          width: `${getCardHpPercent(card)}%`,
                        }"
                      />
                    </div>
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

            <div class="battle-action-receipt" aria-live="polite">
              <span><b>{{ selectedCard?.name }}</b> → {{ selectedTargetCard?.name || 'Pilih target lawan' }}</span>
              <span v-if="actionPointsEnabled">Biaya <b>{{ configuredActionPointCost('attack', 1) }} AP</b> · sisa {{ Math.max(0, ownActionPoints - configuredActionPointCost('attack', 1)) }} AP</span>
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
                Batal
              </button>

              <button
                type="button"
                class="
                  target-confirm-button
                "
                :disabled="
                  !selectedTargetCard ||
                  !!panelBlockReason ||
                  actionLoading
                "
                @click="
                  submitTargetedAttack
                "
              >
                {{
                  actionLoading
                    ? "ATTACKING..."
                    : "Konfirmasi serangan"
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
              bonusUsingId || Boolean(panelBlockReason)
            "
            @click="
              useBonusSkill(
                bonus,
              )
            "
          >
            <span class="bonus-item-icon"><SkillIcon :icon="bonusIcon(bonus.skill_type)" :name="bonusLabel(bonus.skill_type)"/></span>

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
                      : panelBlockReason || "Siap · gunakan tanpa AP"
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


      <!-- SPECIAL SKILL MODAL -->

      <Transition name="target-picker">
        <div v-if="specialSkillModalOpen" class="action-detail-overlay special-overlay">
          <div class="action-detail-backdrop" @click="closeSpecialSkillModal" />

          <section class="special-skill-modal" role="dialog" aria-modal="true" aria-labelledby="special-picker-title" tabindex="-1" @click.stop>
            <header class="special-modal-header">
              <div>
                <span class="eyebrow">SKILL KARTU • PILIH SKILL → TARGET → KONFIRMASI</span>
                <h2 id="special-picker-title">{{ selectedCard?.name || "Pilih kartu" }}</h2>
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
                  v-for="(skill, skillIndex) in runtimeSpecialSkills"
                  :key="skill.id"
                  type="button"
                  class="special-skill-tab"
                  :aria-pressed="selectedSpecialSkill?.id === skill.id"
                  :class="{
                    selected: selectedSpecialSkill?.id === skill.id,
                    ready: specialSkillReadyState(skill).ready,
                  }"
                  @click="chooseSpecialSkill(skill)"
                >
                  <span class="special-tab-icon"><SkillIcon :icon="skill.icon" :name="skill.name" /></span>
                  <div>
                    <span class="skill-slot-label">Skill {{ skillIndex + 1 }} · {{ specialSkillActionPointCost(skill) }} AP</span>
                    <strong>{{ skill.name }}</strong>
                    <small class="skill-ready-reason">{{ specialSkillReadyState(skill).ready ? 'Siap digunakan' : specialSkillReadyState(skill).reason }}</small>
                    <small>{{ skill.description }}</small>
                    <small>Target: {{ formatSpecialTarget(skill) }} · {{ formatSpecialLimits(skill) }}</small>
                  </div>
                </button>
              </div>

              <p v-if="!selectedSpecialSkill" class="special-empty-state">Pilih skill yang ingin digunakan.</p>
              <div v-if="selectedSpecialSkill" class="special-detail-layout">
                <div class="special-detail-main">
                  <div class="special-skill-hero">
                    <div class="special-skill-hero-icon">
                      <SkillIcon :icon="selectedSpecialSkill.icon" :name="selectedSpecialSkill.name" />
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
                      <span>POIN GILIRAN</span>
                      <strong>{{ specialSkillActionPointCost(selectedSpecialSkill) }} poin</strong>
                    </div>
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
                      <span>SETELAH DIGUNAKAN</span>
                      <strong>
                        {{ selectedSpecialSkill.consumes_turn || (actionPointsEnabled && ownActionPoints - specialSkillActionPointCost(selectedSpecialSkill) <= 0) ? "Giliran berakhir" : "Giliran berlanjut" }}
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
                  <label v-if="skillTargetSpec(selectedSpecialSkill).choices?.length" class="studio-skill-choice">Pilih efek
                    <select v-model="selectedSpecialOption" aria-label="Pilih efek skill"><option disabled value="">Pilih satu efek…</option><option v-for="option in skillTargetSpec(selectedSpecialSkill).choices" :key="option.id" :value="option.id">{{ option.label }}</option></select>
                  </label>
                  <label v-if="skillTargetSpec(selectedSpecialSkill).needs_bench" class="studio-skill-choice">Kartu Bench untuk Switch
                    <select v-model="selectedSpecialBenchId" aria-label="Kartu Bench untuk Switch"><option disabled value="">Pilih kartu Bench…</option><option v-for="card in benchCards" :key="getCardId(card)" :value="getCardId(card)">{{ card.name }}</option></select>
                  </label>
                  <p v-if="skillTargetSpec(selectedSpecialSkill).max_targets > 1">Pilih 1–{{ skillTargetSpec(selectedSpecialSkill).max_targets }} target yang berbeda.</p>

                  <template v-if="selectedSpecialTargetRequired">
                    <p>Pilih target sebelum menggunakan skill.</p>

                    <div v-if="specialTargetCards.length" class="special-target-grid">
                      <button
                        v-for="card in specialTargetCards"
                        :key="getCardId(card)"
                        type="button"
                        class="special-target-card"
                        :class="{ selected: selectedSpecialTargetId === getCardId(card) || selectedSpecialTargetIds.includes(getCardId(card)) }"
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

              <div v-if="selectedSpecialSkill" class="battle-action-receipt" aria-live="polite">
                <span><b>{{ selectedCard?.name }}</b> → {{ selectedSpecialTargetIds.length > 1 ? selectedSpecialTargetIds.map(id => specialTargetCards.find(card => getCardId(card) === id)?.name).filter(Boolean).join(', ') : selectedSpecialTarget?.name || formatSpecialTarget(selectedSpecialSkill) }}</span>
                <span v-if="actionPointsEnabled">Biaya <b>{{ specialSkillActionPointCost(selectedSpecialSkill) }} AP</b> · sisa {{ Math.max(0, ownActionPoints - specialSkillActionPointCost(selectedSpecialSkill)) }} AP</span>
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
                    !!panelBlockReason ||
                    !selectedSpecialSkill ||
                    !specialSkillReadyState(selectedSpecialSkill).ready ||
                    (skillTargetSpec(selectedSpecialSkill).choices?.length && !selectedSpecialOption) ||
                    (skillTargetSpec(selectedSpecialSkill).needs_bench && !selectedSpecialBenchId) ||
                    (selectedSpecialTargetRequired && !selectedSpecialTarget)
                  "
                  @click="submitSpecialSkill"
                >
                  {{ actionLoading ? "Memproses…" : `Gunakan ${selectedSpecialSkill?.name || 'skill'}` }}
                </button>
              </footer>
            </template>
          </section>
        </div>
      </Transition>

      <!-- ASSIST / TYPE COMBO ATTACK -->

      <Transition name="target-picker">
        <div
          v-if="comboAttackModalOpen"
          class="action-detail-overlay combo-attack-overlay"
          @click.self="closeComboAttackModal"
        >
          <div class="action-detail-backdrop" @click="closeComboAttackModal" />
          <section class="combo-attack-modal" role="dialog" aria-modal="true" aria-labelledby="combo-picker-title" tabindex="-1" @click.stop>
            <header class="combo-attack-header">
              <div>
                <span class="eyebrow">COMBO ATTACK • {{ comboActionPointCost }} POIN GILIRAN</span>
                <h2 id="combo-picker-title">Pilih kartu Active untuk Combo</h2>
                <p>Pilih minimal dua kartu Active yang belum menyerang. Kartu Bench tidak dapat ikut combo; kartu utama menyumbang ATK penuh dan kartu bantuan mengikuti multiplier aturan combo.</p>
              </div>
              <button type="button" class="modal-close" aria-label="Tutup" @click="closeComboAttackModal">✕</button>
            </header>

            <div class="combo-choice-section">
              <strong>ACTIVE CARD · PILIH {{ tripleComboEnabled ? "2–3" : "2" }}{{ formationEnabled ? " ATAU 4" : "" }}</strong>
              <div class="combo-card-options">
                <div
                  v-for="card in comboEligibleActiveCards"
                  :key="getCardId(card)"
                  class="combo-card-option-wrap"
                  :class="{ selected: comboParticipantIds.some((id) => String(id) === String(getCardId(card))) }"
                >
                  <button type="button" class="combo-card-option" @click="toggleComboParticipant(card)">
                    <img v-if="card.avatar_url || card.image_url" :src="card.avatar_url || card.image_url" :alt="card.name" />
                    <span class="combo-card-option-copy">
                      <b>{{ card.name }}</b>
                  <small>{{ formatTcgType(card.element) }} • ATK {{ card.attack ?? 0 }}<template v-if="String(comboPrimaryCardId) !== String(getCardId(card))"> → kontribusi bantuan</template></small>
                    </span>
                    <span v-if="comboParticipantIds.some((id) => String(id) === String(getCardId(card)))" class="combo-choice-check">✓</span>
                  </button>
                  <button
                    type="button"
                    class="combo-primary-choice"
                    :class="{ selected: String(comboPrimaryCardId) === String(getCardId(card)) }"
                    :disabled="!comboParticipantIds.some((id) => String(id) === String(getCardId(card)))"
                    @click="setComboPrimary(card)"
                  >{{ String(comboPrimaryCardId) === String(getCardId(card)) ? "UTAMA" : "JADIKAN UTAMA" }}</button>
                </div>
              </div>
              <p v-if="comboEligibleActiveCards.length < 2" class="combo-direct-note">Perlu dua kartu Active yang belum menggunakan kesempatan serangnya.</p>
              <p v-if="comboRuleCatalog.length && selectedComboParticipants.length >= 2" class="combo-synergy-preview">
                <b>{{ selectedComboRule?.combo_name ?? (battle?.generic_combo_enabled && selectedComboParticipants.length === 2 ? "Combined Strike" : "Combo belum memiliki aturan tipe") }}</b>
                <span>{{ selectedComboParticipants.map((card) => formatTcgType(card.element)).join(" + ") }}</span>
                <small>{{ selectedComboRule?.effect_json?.summary ?? (selectedComboRule ? "Efek synergy aktif" : battle?.generic_combo_enabled && selectedComboParticipants.length === 2 ? "Serangan bantuan tanpa bonus tipe" : "Pilih kombinasi yang memiliki synergy") }}</small>
              </p>
            </div>

            <div v-if="enemyActiveCards.length" class="combo-choice-section">
              <strong>TARGET ACTIVE LAWAN</strong>
              <div class="combo-card-options">
                <button
                  v-for="card in enemyActiveCards"
                  :key="getCardId(card)"
                  type="button"
                  class="combo-card-option target"
                  :class="{ selected: String(comboTargetCardId) === String(getCardId(card)) }"
                  @click="comboTargetCardId = getCardId(card)"
                >
                  <img v-if="card.avatar_url || card.image_url" :src="card.avatar_url || card.image_url" :alt="card.name" />
                  <span class="combo-card-option-copy">
                    <b>{{ card.name }}</b>
                    <small>HP {{ card.current_hp ?? card.hp }} • DEF {{ card.defense ?? 0 }}</small>
                  </span>
                  <span v-if="String(comboTargetCardId) === String(getCardId(card))" class="combo-choice-check">✓</span>
                </button>
              </div>
            </div>
            <p v-else class="combo-direct-note">Tidak ada Active Card lawan. Combo akan mengenai HP player lawan jika Direct Attack diizinkan.</p>

            <div class="battle-action-receipt" aria-live="polite"><span><b>{{ selectedComboParticipants.map(card => card.name).join(' + ') }}</b> → {{ enemyActiveCards.find(card => getCardId(card) === comboTargetCardId)?.name || enemyName }}</span><span>Biaya <b>{{ comboActionPointCost }} AP</b> · sisa {{ Math.max(0, ownActionPoints - comboActionPointCost) }} AP</span></div>
            <footer class="combo-attack-actions">
              <span>{{ ownActionPoints }} AP tersedia</span>
              <button type="button" class="modal-primary secondary" @click="closeComboAttackModal">BATAL</button>
              <button type="button" class="modal-primary combo-submit" :disabled="actionLoading || !!panelBlockReason || selectedComboParticipants.length < 2 || (enemyActiveCards.length > 0 && !comboTargetCardId) || !canSpendActionPoints(comboActionPointCost)" @click="submitComboAttack">
                {{ actionLoading ? "MENYERANG..." : `COMBO ATTACK • ${comboActionPointCost} POIN` }}
              </button>
            </footer>
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

          <section class="fusion-modal" role="dialog" aria-modal="true" aria-labelledby="fusion-picker-title" tabindex="-1" @click.stop>
            <header class="fusion-modal-header">
              <div>
                <span class="eyebrow">FUSION • PILIH RESEP → PERIKSA MATERIAL → KONFIRMASI</span>
                <h2 id="fusion-picker-title">Gabungkan kartu</h2>
                <p>
                  Pilih resep, periksa kartu material dan hasilnya. Kartu material
                  baru dipakai setelah kamu mengonfirmasi Fusion.
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

              <div class="battle-action-receipt" aria-live="polite"><span><b>{{ selectedFusion?.materials?.map(card => card.name).join(' + ') || 'Pilih material sesuai resep' }}</b> → {{ selectedFusion?.result_name || 'Pilih resep' }}</span><span v-if="actionPointsEnabled">Biaya <b>{{ configuredActionPointCost('fusion', 2) }} AP</b> · sisa {{ Math.max(0, ownActionPoints - configuredActionPointCost('fusion', 2)) }} AP</span></div>
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
                    !!panelBlockReason ||
                    !canSpendActionPoints(configuredActionPointCost('fusion', 2)) ||
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

      <PlayerActionPanel
        v-if="battle.status === 'battle'"
        :context="actionPanelContext"
        :actions="panelActions"
        :review="panelReview"
        :busy="actionLoading"
        @choose="choosePanelAction"
        @confirm="confirmPanelAction"
        @cancel="pendingPanelAction = null"
        @cancel-summon="cancelSummon"
      />

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
            <div class="question-modal-topline">
              <span class="question-round-label">🧠 QUIZ ROUND {{ currentQuestionRound?.round_number ?? battle.round }}</span>
              <QuizTimer :round="currentQuestionRound" :seconds="questionTimeLimitSeconds" />
            </div>
            <span class="hud-label">
              {{ questionLearningEnabled ? "CHALLENGE & BELAJAR" : "CODING CHALLENGE" }}
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

              <img v-if="questionImageUrl" class="question-illustration" :src="questionImageUrl" alt="Ilustrasi untuk pertanyaan" />

              <pre
                v-if="currentQuestion.question_type !== 'find_bug' && currentQuestion.code_snippet"
                class="question-code"
              ><code>{{ currentQuestion.code_snippet }}</code></pre>

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

              <div v-if="currentQuestion.question_type==='scratch_blocks'" class="question-block-order">
                <BlockWorkspace :key="effectiveQuestionRoundId" v-model="questionWorkspace" :config="currentQuestion.block_config" :disabled="questionInteractionLocked" label="Susun jawabanmu"/>
                <button type="button" class="question-submit-button" :disabled="questionInteractionLocked" @click="answerQuestion(0,{workspace:questionWorkspace})">KIRIM PROGRAM</button>
              </div>
              <div
                v-else-if="currentQuestion.question_type === 'block_order'"
                class="question-block-order"
              >
                <div class="question-interaction-heading">
                  <strong>Susun blok sesuai urutan program</strong>
                  <small>Seret blok atau gunakan tombol panah.</small>
                </div>
                <QuizBlockList v-model="questionBlockOrder" :disabled="questionInteractionLocked" />
                <button class="question-submit-button" type="button" :disabled="questionInteractionLocked || questionBlockOrder.length < 2" @click="submitQuestionBlockOrder">KIRIM URUTAN</button>
              </div>

              <div v-else-if="currentQuestion.question_type === 'find_bug'" class="question-code-choice">
                <div v-for="(line, index) in questionCodeLines" :key="index" class="question-code-line">
                  <span>{{ index + 1 }}</span>
                  <button type="button" :class="{ selected: selectedQuestionAnswer === index, correct: questionResult === 'correct' && selectedQuestionAnswer === index, wrong: questionResult === 'wrong' && selectedQuestionAnswer === index }" :disabled="questionInteractionLocked || index > 3" @click="answerQuestion(index, { line_index: index })"><code>{{ line }}</code><b>↗</b></button>
                </div>
              </div>

              <div
                v-else-if="currentQuestion.question_type === 'choice'"
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

              <div v-if="questionLearningEnabled && !questionResult && (currentQuestion.hint_1 || currentQuestion.hint_2)" class="question-hints">
                <div v-for="(hint, index) in questionHints.slice(0, questionHintStep)" :key="index"><span>Petunjuk {{ index + 1 }}</span><p>{{ hint }}</p></div>
                <button v-if="questionHintStep < questionHints.length" type="button" @click="revealNextQuestionHint">{{ questionHintStep ? "LIHAT PETUNJUK BERIKUTNYA" : "MINTA PETUNJUK" }}</button>
              </div>

              <section v-if="questionResult" class="question-learning-feedback" :class="questionResult">
                <strong>{{ questionResult === 'correct' ? 'Benar! Pelajari alasannya' : questionResult === 'wrong' ? 'Belum tepat — mari pahami konsepnya' : questionResult === 'lost' ? 'Pemain lain menjawab lebih dahulu' : 'Waktu menjawab habis' }}</strong>
                <p v-if="questionLearningEnabled && currentQuestion.explanation">{{ currentQuestion.explanation }}</p>
                <p v-if="questionLearningEnabled && questionResult === 'wrong' && questionCorrectOption"><b>Jawaban yang benar:</b> {{ questionCorrectOption }}</p>
                <div v-if="questionLearningEnabled && questionResult === 'wrong'" class="recommended-material">
                  <span>Materi untuk dipelajari</span>
                  <strong>{{ questionRecommendation.topic }}</strong>
                  <a v-if="questionRecommendation.url" :href="questionRecommendation.url" target="_blank" rel="noopener noreferrer">BUKA MATERI ↗</a>
                </div>
                <small v-if="questionResult === 'wrong' && questionActive" class="question-waiting-opponent">
                  Jawaban tersimpan. Menunggu pemain lain menyelesaikan kuis.
                </small>
                <small v-if="questionResult === 'correct' && questionReward">Bonus skill: {{ bonusLabel(questionReward) }}. Gunakan saat giliranmu.</small>
                <small v-else-if="questionResult === 'correct' && battle?.question_bonus_enabled === false">Bonus skill tidak diaktifkan untuk battle ini.</small>
              </section>
            </template>
          </section>
        </div>
      </Transition>

      <!-- WINNER -->
      <QuizBonusChoices v-if="questionResult === 'correct' && questionRewardChoices.length && bonusChoiceRoundId && !battleFinished"
        :options="bonusChoiceOptions" :busy="bonusChoiceSubmitting" :selected-code="bonusChoiceSelectedCode" :player-name="playerName"
        :explanation="questionLearningEnabled ? currentQuestion?.explanation : ''" @choose="chooseQuestionBonus"/>

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
.studio-skill-choice{display:grid;gap:8px;margin:14px 0;font-weight:700}
.studio-skill-choice select{width:100%;min-width:0;padding:12px;border:1px solid #b9d3c2;border-radius:10px;background:#fff;color:#153e2a;font:inherit}
.special-tab-icon { display:block; width:46px; height:46px; flex-shrink:0; }
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

/* =========================================================
   PLAYER SOUND CONTROL
========================================================= */

.battle-sound-toggle {
  position: fixed;
  right: 18px;
  top: 92px;
  z-index: 12050;
  min-height: 34px;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 10px;
  border: 1px solid rgba(74, 198, 255, 0.34);
  border-radius: 999px;
  color: #c8efff;
  background: rgba(7, 18, 34, 0.82);
  box-shadow:
    0 8px 22px rgba(0, 0, 0, 0.2),
    inset 0 0 12px rgba(43, 197, 255, 0.06);
  backdrop-filter: blur(10px);
  cursor: pointer;
  user-select: none;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    opacity 0.18s ease;
}

.battle-sound-toggle:hover {
  transform: translateY(-1px);
  border-color: rgba(74, 198, 255, 0.7);
}

.battle-sound-toggle.muted {
  opacity: 0.62;
  border-color: rgba(255, 255, 255, 0.12);
}

.battle-sound-toggle.locked {
  animation: soundUnlockPulse 1.8s ease-in-out infinite;
}

/* Phase 3D.16.1 • non-blocking refresh indicator */
.battle-sync-chip {
  position: fixed;
  top: 134px;
  right: 18px;
  z-index: 11020;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 7px 11px;
  border: 1px solid rgba(67, 154, 210, 0.2);
  border-radius: 999px;
  background: rgba(239, 249, 255, 0.88);
  box-shadow: 0 8px 26px rgba(42, 93, 124, 0.14);
  backdrop-filter: blur(12px);
  color: #24485f;
  font-size: 7px;
  font-weight: 950;
  letter-spacing: 0.12em;
  pointer-events: none;
}

.battle-sync-spinner {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 2px solid rgba(66, 149, 202, 0.2);
  border-top-color: rgba(41, 135, 196, 0.95);
  animation: battleSyncSpin 0.7s linear infinite;
}

.battle-sync-enter-active,
.battle-sync-leave-active {
  transition: opacity 0.16s ease, transform 0.16s ease;
}

.battle-sync-enter-from,
.battle-sync-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}

@keyframes battleSyncSpin {
  to { transform: rotate(360deg); }
}


.battle-sound-icon {
  font-size: 14px;
  line-height: 1;
}

.battle-sound-copy {
  font-size: 7px;
  font-weight: 1000;
  letter-spacing: 0.08em;
  white-space: nowrap;
}

@keyframes soundUnlockPulse {
  0%,
  100% {
    box-shadow:
      0 8px 22px rgba(0, 0, 0, 0.2),
      0 0 0 rgba(45, 203, 255, 0);
  }

  50% {
    box-shadow:
      0 8px 22px rgba(0, 0, 0, 0.2),
      0 0 18px rgba(45, 203, 255, 0.34);
  }
}

@media (max-width: 760px) {
  .battle-sound-toggle {
    top: 82px;
    right: 10px;
    min-height: 30px;
    padding: 5px 8px;
  }

  .battle-sound-copy {
    font-size: 6px;
  }

  .battle-sync-chip {
    top: 120px;
    right: 10px;
  }
}

/* =========================================================
   INCOMING EVENT FEEDBACK
========================================================= */

.player-battle-ui.incoming-impact {
  animation: playerIncomingImpact 0.44s cubic-bezier(0.36, 0.07, 0.19, 0.97);
}

@keyframes playerIncomingImpact {
  0%,
  100% {
    transform: translate3d(0, 0, 0);
  }

  18% {
    transform: translate3d(-5px, 1px, 0);
  }

  36% {
    transform: translate3d(5px, -1px, 0);
  }

  54% {
    transform: translate3d(-3px, 0, 0);
  }

  72% {
    transform: translate3d(3px, 1px, 0);
  }
}

.incoming-impact-flash {
  position: fixed;
  inset: 0;
  z-index: 9998;
  pointer-events: none;
  opacity: 0;
}

.incoming-impact-flash.damage {
  background:
    radial-gradient(
      circle at center,
      rgba(255, 255, 255, 0.1),
      rgba(255, 75, 88, 0.18) 68%,
      rgba(189, 24, 48, 0.34) 100%
    );
}

.incoming-impact-flash.danger,
.incoming-impact-flash.direct {
  background:
    radial-gradient(
      circle at center,
      rgba(255, 255, 255, 0.14),
      rgba(255, 61, 78, 0.26) 62%,
      rgba(132, 8, 31, 0.5) 100%
    );
}

.incoming-impact-flash.effect {
  background:
    radial-gradient(
      circle at center,
      rgba(255, 255, 255, 0.08),
      rgba(118, 91, 255, 0.18) 64%,
      rgba(62, 31, 142, 0.3) 100%
    );
}

.incoming-impact-flash.deck {
  background:
    radial-gradient(
      circle at center,
      rgba(255, 255, 255, 0.08),
      rgba(255, 174, 51, 0.14) 65%,
      rgba(196, 105, 10, 0.24) 100%
    );
}

.impact-flash-enter-active {
  animation: incomingFlash 0.52s ease-out;
}

.impact-flash-leave-active {
  transition: opacity 0.14s ease;
}

.impact-flash-leave-to {
  opacity: 0;
}

@keyframes incomingFlash {
  0% {
    opacity: 0;
  }

  22% {
    opacity: 1;
  }

  100% {
    opacity: 0;
  }
}

.cyber-card.incoming-hit {
  z-index: 12;
  border-color: rgba(255, 62, 83, 0.95);
  box-shadow:
    0 0 0 4px rgba(255, 67, 87, 0.17),
    0 0 30px rgba(255, 47, 73, 0.52),
    0 18px 38px rgba(80, 25, 38, 0.24);
  animation: incomingCardShake 0.66s cubic-bezier(0.36, 0.07, 0.19, 0.97);
}

@keyframes incomingCardShake {
  0%,
  100% {
    transform: translate3d(0, 0, 0) rotate(0deg);
  }

  12% {
    transform: translate3d(-8px, 1px, 0) rotate(-1.1deg);
  }

  24% {
    transform: translate3d(8px, -1px, 0) rotate(1deg);
  }

  36% {
    transform: translate3d(-7px, 0, 0) rotate(-0.8deg);
  }

  48% {
    transform: translate3d(6px, 1px, 0) rotate(0.7deg);
  }

  62% {
    transform: translate3d(-4px, 0, 0) rotate(-0.4deg);
  }

  78% {
    transform: translate3d(3px, 0, 0) rotate(0.25deg);
  }
}

.deck-remaining-chip.incoming-deck-hit {
  color: #9b4d00;
  background: rgba(255, 220, 154, 0.94);
  box-shadow:
    0 0 0 4px rgba(255, 178, 45, 0.15),
    0 0 20px rgba(255, 150, 22, 0.34);
  animation: incomingDeckPulse 0.68s ease-out;
}

@keyframes incomingDeckPulse {
  0% {
    transform: scale(1);
  }

  30% {
    transform: scale(1.13);
  }

  58% {
    transform: scale(0.97);
  }

  100% {
    transform: scale(1);
  }
}

@media (prefers-reduced-motion: reduce) {
  .player-battle-ui.incoming-impact,
  .cyber-card.incoming-hit,
  .deck-remaining-chip.incoming-deck-hit,
  .impact-flash-enter-active {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}


/* =========================================================
   PHASE 3D.18 • STATUS EFFECT UI
========================================================= */

.hud-status-strip,
.enemy-status-strip,
.card-status-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
}

.hud-status-strip {
  margin-top: 6px;
}

.enemy-status-strip {
  justify-content: flex-end;
  margin-top: 5px;
}

.battle-status-chip,
.card-status-badge {
  --status-bg: rgba(92, 118, 138, 0.12);
  --status-border: rgba(92, 118, 138, 0.28);
  --status-text: #355468;
  display: inline-flex;
  align-items: center;
  gap: 3px;
  border: 1px solid var(--status-border);
  background: var(--status-bg);
  color: var(--status-text);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.6);
}

.battle-status-chip {
  min-height: 20px;
  padding: 3px 6px;
  border-radius: 999px;
}

.battle-status-chip b,
.card-status-badge b {
  font-style: normal;
  line-height: 1;
}

.battle-status-chip em,
.card-status-badge em {
  font-style: normal;
  font-weight: 950;
  letter-spacing: 0.04em;
}

.battle-status-chip em { font-size: 5.8px; }
.battle-status-chip small { font-size: 5.5px; font-weight: 900; }
.battle-status-chip.compact em { display: none; }
.status-more { font-size: 6px; font-weight: 950; color: #718999; }

.card-status-row {
  min-height: 19px;
  margin: 4px 0 6px;
}

.card-status-badge {
  min-height: 18px;
  padding: 2px 5px;
  border-radius: 7px;
  max-width: 100%;
}

.card-status-badge em {
  max-width: 76px;
  overflow: hidden;
  font-size: 5.7px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-status-badge small { font-size: 5.3px; font-weight: 950; }
.card-status-badge.more { font-size: 6px; font-weight: 950; }

.battle-status-chip.defense,
.card-status-badge.defense { --status-bg: rgba(62, 139, 220, 0.12); --status-border: rgba(62, 139, 220, 0.38); --status-text: #286ea7; }
.battle-status-chip.water,
.card-status-badge.water { --status-bg: rgba(44, 172, 220, 0.12); --status-border: rgba(44, 172, 220, 0.38); --status-text: #187ca7; }
.battle-status-chip.power,
.card-status-badge.power { --status-bg: rgba(240, 176, 42, 0.14); --status-border: rgba(240, 176, 42, 0.42); --status-text: #9b6900; }
.battle-status-chip.debuff,
.card-status-badge.debuff,
.battle-status-chip.freeze,
.card-status-badge.freeze { --status-bg: rgba(96, 143, 218, 0.12); --status-border: rgba(96, 143, 218, 0.38); --status-text: #536eae; }
.battle-status-chip.burn,
.card-status-badge.burn { --status-bg: rgba(238, 92, 58, 0.12); --status-border: rgba(238, 92, 58, 0.38); --status-text: #bd4c2f; }
.battle-status-chip.regen,
.card-status-badge.regen,
.battle-status-chip.buff,
.card-status-badge.buff { --status-bg: rgba(57, 185, 118, 0.12); --status-border: rgba(57, 185, 118, 0.4); --status-text: #288456; }
.battle-status-chip.silence,
.card-status-badge.silence,
.battle-status-chip.stun,
.card-status-badge.stun,
.battle-status-chip.cooldown,
.card-status-badge.cooldown { --status-bg: rgba(115, 102, 148, 0.12); --status-border: rgba(115, 102, 148, 0.36); --status-text: #69598d; }
.battle-status-chip.poison,
.card-status-badge.poison,
.battle-status-chip.necro,
.card-status-badge.necro { --status-bg: rgba(110, 71, 137, 0.13); --status-border: rgba(110, 71, 137, 0.42); --status-text: #674080; }
.battle-status-chip.bleed,
.card-status-badge.bleed { --status-bg: rgba(192, 58, 79, 0.12); --status-border: rgba(192, 58, 79, 0.38); --status-text: #a43850; }

@media (max-width: 680px) {
  .battle-status-chip em { display: none; }
  .card-status-badge em { max-width: 52px; }
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
  padding: 0;
  cursor: pointer;
  font-family: inherit;
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}

.player-avatar:hover {
  transform: translateY(-2px) scale(1.03);
  box-shadow: 0 10px 28px rgba(47, 118, 168, 0.24);
}

.player-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-picker-overlay {
  position: fixed;
  inset: 0;
  z-index: 13000;
  display: grid;
  place-items: center;
  padding: 18px;
}

.avatar-picker-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(10, 39, 54, 0.48);
  backdrop-filter: blur(10px);
}

.avatar-picker-panel {
  position: relative;
  z-index: 1;
  width: min(100%, 560px);
  padding: 30px;
  border: 1px solid rgba(74, 167, 113, 0.22);
  border-radius: 28px;
  color: #173d2b;
  background: linear-gradient(145deg, #fff, #f1fbf1);
  box-shadow: 0 28px 90px rgba(7, 34, 24, 0.28);
  text-align: center;
}

.avatar-picker-eyebrow {
  color: #15963b;
  font-size: 10px;
  font-weight: 950;
  letter-spacing: 0.18em;
}

.avatar-picker-panel h2 {
  margin: 8px 0 6px;
  color: #123c27;
  font-size: clamp(23px, 4vw, 30px);
}

.avatar-picker-panel > p {
  margin: 0 0 20px;
  color: #668171;
  font-size: 14px;
}

.avatar-current-photo {
  display: block;
  width: 72px;
  height: 72px;
  margin: 0 auto 20px;
  border: 2px solid #d8eadb;
  border-radius: 50%;
  object-fit: cover;
  object-position: center top;
}

.avatar-picker-grid {
  display: grid;
  grid-template-columns: repeat(8, minmax(0, 1fr));
  gap: 9px;
}

.avatar-choice {
  aspect-ratio: 1;
  min-width: 0;
  display: grid;
  place-items: center;
  padding: 0;
  border: 1px solid #d8eadb;
  border-radius: 17px;
  color: #234c35;
  background: #fff;
  box-shadow: 0 4px 12px rgba(25, 73, 45, 0.06);
  cursor: pointer;
  font-size: clamp(25px, 5vw, 34px);
  transition: transform 0.16s ease, border-color 0.16s ease, background 0.16s ease;
}

.avatar-choice:hover {
  transform: translateY(-3px);
}

.avatar-choice.selected {
  border: 2px solid #14a83a;
  background: #e6f8e8;
  box-shadow: 0 0 0 3px rgba(20, 168, 58, 0.12);
}

.avatar-picker-error {
  margin: 14px 0 0 !important;
  color: #b83343 !important;
  font-weight: 750;
}

.avatar-picker-actions {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 22px;
}

.avatar-picker-actions button {
  min-height: 46px;
  padding: 0 20px;
  border: 1px solid transparent;
  border-radius: 14px;
  cursor: pointer;
  font-weight: 850;
}

.avatar-picker-actions button:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.avatar-cancel {
  border-color: #d8eadb !important;
  color: #4e715a;
  background: white;
}

.avatar-confirm {
  color: white;
  background: #11a936;
  box-shadow: 0 8px 18px rgba(17, 169, 54, 0.2);
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
  border-radius: inherit;
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

.turn-core div .turn-countdown {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  margin-top: 8px;
  padding: 5px 9px;
  border: 1px solid #cbe5cf;
  border-radius: 999px;
  color: #176e32;
  background: #f2fbf3;
  font-variant-numeric: tabular-nums;
}

.turn-core .turn-countdown b {
  font-size: 13px;
  letter-spacing: 0;
}

.turn-core .turn-countdown small {
  color: #5b8063;
  font-size: 7px;
  font-weight: 900;
  letter-spacing: .07em;
}

.turn-core div .turn-countdown.urgent {
  border-color: #efc5b8;
  color: #b33b2f;
  background: #fff1ed;
  animation: turnClockPulse .85s ease-in-out infinite alternate;
}

.turn-core .turn-countdown.urgent small {
  color: #9a4a3c;
}

@keyframes turnClockPulse {
  to { box-shadow: 0 0 0 4px rgba(197, 62, 44, .09); }
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
      1900px
    );

  position: relative;

  z-index: 5;

  display: grid;

  grid-template-columns:
    210px
    minmax(
      0,
      1fr
    )
    210px;

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

  grid-template-columns: repeat(var(--active-slot-count, 4), minmax(190px, 1fr));

  align-items: start;
  justify-content: center;

  gap: 18px;
  max-width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  padding: 2px 2px 10px;
  overscroll-behavior-x: contain;
  scrollbar-width: thin;
  scrollbar-color: rgba(90, 153, 187, .45) transparent;
}

/* =========================================================
   PHASE 3D.19 • CARD STATUS VISUAL FX
   Visual-only. Battle logic remains server-authoritative.
========================================================= */

.card-fx-stack,
.card-fx-layer {
  position: absolute;
  inset: 0;
  border-radius: inherit;
  pointer-events: none;
}

.card-fx-stack {
  z-index: 24;
  overflow: hidden;
}

.card-fx-layer {
  display: block;
}

/* Fusion: neon rotating energy frame */
.fx-fusion-layer {
  inset: -20%;
  background:
    conic-gradient(
      from 0deg,
      transparent 0deg,
      rgba(75, 219, 255, 0.22) 65deg,
      rgba(151, 82, 255, 0.34) 135deg,
      transparent 210deg,
      rgba(244, 91, 205, 0.24) 285deg,
      transparent 360deg
    );
  filter: blur(15px);
  animation: cardFxFusionSpin 6.5s linear infinite;
}

.cyber-card.fx-fusion-active {
  border-color: rgba(132, 83, 235, 0.72);
  box-shadow:
    0 0 0 2px rgba(93, 203, 255, 0.14),
    0 0 24px rgba(131, 77, 230, 0.28),
    0 14px 30px rgba(50, 91, 153, 0.14);
}

/* Necro: violet soul mist */
.fx-necro-layer {
  background:
    radial-gradient(circle at 15% 90%, rgba(121, 36, 190, 0.28), transparent 34%),
    radial-gradient(circle at 85% 16%, rgba(78, 24, 145, 0.22), transparent 30%),
    radial-gradient(circle at 50% 110%, rgba(38, 7, 75, 0.32), transparent 46%);
  filter: saturate(1.18);
  animation: cardFxNecroPulse 2.8s ease-in-out infinite;
}

.cyber-card.fx-necro-active {
  box-shadow:
    0 0 0 2px rgba(133, 71, 185, 0.14),
    0 0 22px rgba(101, 49, 157, 0.26),
    0 12px 30px rgba(58, 36, 91, 0.16);
}

/* Defense: blue protective pulse */
.fx-defense-layer {
  inset: 0;
  background: radial-gradient(ellipse at 50% 55%, rgba(76, 184, 255, .08), transparent 68%);
  box-shadow:
    inset 0 -14px 24px -23px rgba(50, 168, 255, .58);
  animation: cardFxDefensePulse 1.55s ease-in-out infinite;
}

/* Shield: transparent glass barrier above card content */
.fx-shield-layer {
  z-index: 4;
  background:
    linear-gradient(135deg, rgba(186, 239, 255, 0.13), rgba(255,255,255,0.025) 42%, rgba(109, 209, 245, 0.12));
  box-shadow:
    inset 0 0 0 2px rgba(190, 239, 255, 0.46),
    inset 0 0 26px rgba(91, 207, 255, 0.10),
    0 0 18px rgba(80, 196, 246, 0.20);
  backdrop-filter: blur(1.2px) saturate(1.08);
}

.fx-shield-layer::before {
  content: "";
  position: absolute;
  top: -35%;
  left: -55%;
  width: 46%;
  height: 175%;
  transform: rotate(20deg);
  background: linear-gradient(to right, transparent, rgba(255,255,255,0.30), transparent);
  animation: cardFxShieldSweep 2.7s ease-in-out infinite;
}

/* Burn: ember edge + rising glow */
.fx-burn-layer {
  background:
    radial-gradient(circle at 18% 100%, rgba(255, 83, 20, 0.34), transparent 26%),
    radial-gradient(circle at 52% 108%, rgba(255, 164, 24, 0.28), transparent 32%),
    radial-gradient(circle at 86% 100%, rgba(223, 50, 18, 0.30), transparent 26%);
  animation: cardFxBurnFlicker 0.85s ease-in-out infinite alternate;
}

.cyber-card.fx-burn-active {
  filter: saturate(1.12);
}

/* Freeze: frost vignette */
.fx-freeze-layer {
  background:
    linear-gradient(135deg, rgba(177, 233, 255, 0.20), transparent 32%, rgba(113, 193, 239, 0.14) 72%, rgba(220, 249, 255, 0.18)),
    radial-gradient(circle at 0 0, rgba(233, 252, 255, 0.35), transparent 28%),
    radial-gradient(circle at 100% 100%, rgba(186, 231, 255, 0.28), transparent 30%);
  box-shadow: inset 0 0 24px rgba(133, 212, 255, 0.24);
}

.cyber-card.fx-freeze-active {
  filter: saturate(0.82) brightness(1.03);
}

/* Poison: toxic haze */
.fx-poison-layer {
  background:
    radial-gradient(circle at 20% 78%, rgba(101, 194, 77, 0.20), transparent 25%),
    radial-gradient(circle at 72% 22%, rgba(137, 57, 173, 0.20), transparent 28%),
    radial-gradient(circle at 82% 86%, rgba(79, 164, 61, 0.18), transparent 22%);
  animation: cardFxPoisonDrift 2.4s ease-in-out infinite alternate;
}

.cyber-card.fx-poison-active {
  filter: saturate(1.08);
}

/* Stun: electric flashing overlay */
.fx-stun-layer {
  background:
    repeating-linear-gradient(
      118deg,
      transparent 0 24px,
      rgba(255, 217, 73, 0.16) 25px 27px,
      transparent 28px 52px
    );
  mix-blend-mode: multiply;
  animation: cardFxStunFlash 0.72s steps(2, end) infinite;
}

.cyber-card.fx-stun-active {
  filter: brightness(1.04);
}

.fx-curse-layer {
  background: radial-gradient(ellipse at 50% 55%, rgba(65, 40, 105, .22), transparent 62%),
    linear-gradient(145deg, transparent 36%, rgba(20, 16, 43, .18) 50%, transparent 68%);
  animation: cardFxCurseDrift 2.8s ease-in-out infinite alternate;
}
.cyber-card.fx-curse-active { filter: saturate(.92) brightness(.98); }

@keyframes cardFxFusionSpin { to { transform: rotate(360deg); } }
@keyframes cardFxNecroPulse { 0%,100% { opacity:.62; transform:scale(1); } 50% { opacity:1; transform:scale(1.035); } }
@keyframes cardFxDefensePulse { 0%,100% { opacity:.62; } 50% { opacity:1; box-shadow: inset 0 0 22px rgba(76,184,255,.20),0 0 24px rgba(50,168,255,.32); } }
@keyframes cardFxDefenseSpin { to { transform: rotate(360deg); } }
@keyframes cardFxShieldSweep { 0% { transform:translateX(0) rotate(20deg); opacity:0; } 20% { opacity:.8; } 100% { transform:translateX(360%) rotate(20deg); opacity:0; } }
@keyframes cardFxBurnFlicker { from { opacity:.58; filter:brightness(.92); } to { opacity:1; filter:brightness(1.15); } }
@keyframes cardFxPoisonDrift { from { transform:translate3d(-2px,2px,0) scale(1); opacity:.62; } to { transform:translate3d(3px,-3px,0) scale(1.04); opacity:.92; } }
@keyframes cardFxStunFlash { 0%,100% { opacity:.22; } 50% { opacity:.82; } }
@keyframes cardFxCurseDrift { from { opacity:.35; transform:translateY(2px); } to { opacity:.78; transform:translateY(-3px); } }

@media (prefers-reduced-motion: reduce) {
  .card-fx-layer,
  .card-fx-layer::before,
  .card-fx-layer::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}

/* CARD */

.cyber-card {
  min-height: 290px;
  width: 100%;
  max-width: 350px;

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

  padding-bottom: 2px;
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

.card-hp-block {
  margin-bottom: 9px;
}

.card-hp-copy {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 5px;
}

.card-hp-copy span {
  color: #6c879a;
  font-size: 7px;
  font-weight: 950;
  letter-spacing: 0.08em;
}

.card-hp-copy strong {
  color: #244b66;
  font-size: 10px;
  font-weight: 950;
}

.card-hp-track,
.target-card-hp-track {
  width: 100%;
  height: 8px;
  overflow: hidden;
  border: 1px solid rgba(72, 119, 148, 0.12);
  border-radius: 999px;
  background: rgba(78, 117, 142, 0.14);
  box-shadow: inset 0 1px 2px rgba(15, 40, 56, 0.08);
}

.card-hp-fill,
.target-card-hp-fill,
.hud-hp-fill,
.enemy-mini-fill {
  height: 100%;
  position: relative;
  overflow: hidden;
  border-radius: inherit;
  transition:
    width 0.38s cubic-bezier(0.2, 0.8, 0.2, 1),
    background 0.2s ease,
    box-shadow 0.2s ease;
}

.card-hp-fill.healthy,
.target-card-hp-fill.healthy,
.hud-hp-fill.healthy,
.enemy-mini-fill.healthy {
  background: linear-gradient(90deg, #18c873, #62e2b8);
  box-shadow: 0 0 8px rgba(38, 210, 137, 0.34);
}

.card-hp-fill.warning,
.target-card-hp-fill.warning,
.hud-hp-fill.warning,
.enemy-mini-fill.warning {
  background: linear-gradient(90deg, #f0a620, #ffd95e);
  box-shadow: 0 0 8px rgba(244, 177, 38, 0.32);
}

.card-hp-fill.critical,
.target-card-hp-fill.critical,
.hud-hp-fill.critical,
.enemy-mini-fill.critical {
  background: linear-gradient(90deg, #df3f5e, #ff6b6b);
  box-shadow: 0 0 9px rgba(229, 58, 89, 0.38);
  animation: hpCriticalPulse 0.9s ease-in-out infinite alternate;
}

.card-hp-shine {
  width: 28%;
  height: 100%;
  position: absolute;
  left: -35%;
  top: 0;
  transform: skewX(-22deg);
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.72), transparent);
  animation: cardHpShine 2.4s ease-in-out infinite;
}

@keyframes cardHpShine {
  0%, 58% { left: -35%; }
  100% { left: 120%; }
}

@keyframes hpCriticalPulse {
  from { filter: brightness(0.92); }
  to { filter: brightness(1.22); }
}

.cyber-card.incoming-hit .card-hp-track {
  animation: cardHpHitFlash 0.55s ease;
}

@keyframes cardHpHitFlash {
  0%, 100% { box-shadow: inset 0 1px 2px rgba(15, 40, 56, 0.08); }
  45% { box-shadow: 0 0 0 3px rgba(255, 72, 91, 0.18), 0 0 18px rgba(255, 72, 91, 0.45); }
}

.cyber-card-image {
  width: 100%;
  aspect-ratio: 1 / 1;
  height: auto;
  max-height: 290px;

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

  object-fit: contain;
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

.card-zone-action {
  width: 100%;
  min-height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  margin-top: 12px;
  padding: 7px 10px;
  border: 1px solid rgba(18, 159, 71, 0.2);
  border-radius: 10px;
  color: #087c35;
  background: #eefaf1;
  font-size: 9px;
  font-weight: 950;
  line-height: 1.2;
  cursor: pointer;
  transition: transform 0.16s ease, background 0.16s ease, box-shadow 0.16s ease;
}

.card-zone-action > span:first-child {
  font-size: 13px;
  line-height: 1;
}

.card-zone-action-copy {
  display: grid;
  gap: 2px;
}

.card-zone-action-copy small {
  color: #648573;
  font-size: 7px;
  font-weight: 800;
}

.card-zone-action:not(:disabled):hover {
  transform: translateY(-1px);
  background: #dff5e5;
  box-shadow: 0 5px 14px rgba(10, 151, 62, 0.12);
}

.card-zone-action:disabled {
  color: #82938a;
  border-color: #e0e8e2;
  background: #f0f3f1;
  cursor: not-allowed;
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
  flex-direction: column;
  gap: 6px;
  margin-top: 9px;
  padding: 6px 7px;
  border-radius: 7px;
  background: rgba(232, 244, 250, 0.76);
}

.target-card-hp-copy {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 7px;
}

.target-card-hp-track {
  height: 6px;
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

.question-modal-topline { position:sticky; top:-1px; z-index:3; background:#fff; padding:10px 0; display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:12px; }
.question-round-label { color:#18803a; font-size:10px; font-weight:900; letter-spacing:.12em; }
.question-countdown { padding:7px 11px; border-radius:999px; color:#13732f; background:#eaf7ec; font-size:12px; font-weight:900; font-variant-numeric:tabular-nums; }
.question-countdown.urgent { color:#b23a2f; background:#fff0ec; animation:questionTimerPulse .8s ease-in-out infinite alternate; }
@keyframes questionTimerPulse { to { transform:scale(1.06); } }
.question-illustration { display:block; width:min(100%,460px); max-height:230px; margin:14px auto; border:1px solid #e2ede3; border-radius:14px; object-fit:contain; background:#f8fcf8; }
.question-card .hud-label { color:#23813e; }
.question-block-order,.question-code-choice { display:grid; gap:9px; margin-top:15px; }
.question-interaction-heading { display:grid; gap:4px; margin-bottom:2px; color:#174d2b; }
.question-interaction-heading strong { font-size:13px; }
.question-interaction-heading small { color:#6e8574; font-size:10px; }
.question-block-item { display:flex; align-items:center; gap:10px; min-height:46px; padding:7px 9px; border:1px solid #d9e9dc; border-radius:11px; color:#225536; background:#f5fbf5; cursor:grab; }
.question-block-item code { flex:1; overflow-wrap:anywhere; font-size:12px; }
.block-grip { color:#78927e; font-size:18px; }
.block-move-controls { display:flex; gap:4px; }
.block-move-controls button { width:28px; height:28px; border:1px solid #cde2d0; border-radius:8px; color:#126d2b; background:#fff; cursor:pointer; }
.block-move-controls button:disabled { opacity:.35; cursor:default; }
.question-submit-button { min-height:42px; margin-top:5px; border:0; border-radius:11px; color:#fff; background:#159a39; font-size:11px; font-weight:900; letter-spacing:.08em; cursor:pointer; }
.question-submit-button:disabled { opacity:.5; cursor:default; }
.question-code-choice { padding:10px; border:1px solid #e1ebe2; border-radius:13px; background:#f7faf7; }
.question-code-line { display:grid; grid-template-columns:28px minmax(0,1fr); align-items:center; gap:7px; }
.question-code-line > span { color:#768b7b; text-align:right; font:11px ui-monospace,monospace; }
.question-code-line button { display:flex; align-items:center; justify-content:space-between; gap:10px; min-height:35px; padding:7px 9px; border:1px solid transparent; border-radius:8px; color:#284e36; text-align:left; background:transparent; cursor:pointer; }
.question-code-line button:hover:not(:disabled),.question-code-line button.selected { border-color:#a7d7ae; background:#e9f7eb; }
.question-code-line button.correct { color:#0a7b2d; background:#dff4e2; }
.question-code-line button.wrong { color:#a74236; background:#fff0ec; }
.question-code-line button:disabled { cursor:default; }
.question-code-line code { overflow-wrap:anywhere; font:12px ui-monospace,SFMono-Regular,Menlo,monospace; }
.question-hints,.question-learning-feedback { margin-top:15px; padding:13px 14px; border:1px solid #d9e9dc; border-radius:13px; color:#28553a; background:#f6fbf6; }
.question-hints > div { margin:0 0 8px; }
.question-hints > div span,.recommended-material > span { color:#598066; font-size:9px; font-weight:900; letter-spacing:.09em; text-transform:uppercase; }
.question-hints p,.question-learning-feedback p { margin:4px 0 0; color:#3d5f48; font-size:12px; line-height:1.5; }
.question-hints > button,.recommended-material a { display:inline-flex; align-items:center; min-height:31px; padding:0 10px; border:1px solid #c5e0ca; border-radius:8px; color:#13712d; background:#fff; font-size:9px; font-weight:900; letter-spacing:.06em; text-decoration:none; cursor:pointer; }
.question-learning-feedback > strong { color:#167b34; font-size:13px; }
.question-learning-feedback.wrong { border-color:#ead8b6; background:#fffbf2; }
.question-learning-feedback.wrong > strong { color:#98611a; }
.question-learning-feedback.lost,.question-learning-feedback.timeout { border-color:#dfe6dc; background:#f5f7f3; }
.recommended-material { display:grid; justify-items:start; gap:5px; margin-top:11px; padding-top:10px; border-top:1px solid #dfe9df; }
.recommended-material strong { color:#1a5f30; font-size:12px; text-transform:capitalize; }
.question-learning-feedback > small { display:block; margin-top:8px; color:#4c7655; font-weight:700; }
.question-learning-feedback > .question-waiting-opponent { color:#8a641d; }
.question-bonus-choice { display:grid; gap:10px; margin-top:13px; padding-top:12px; border-top:1px solid #dcebdc; }
.question-bonus-choice > div:first-child { display:grid; gap:3px; }
.question-bonus-choice > div:first-child strong { color:#176d2e; font-size:12px; }
.question-bonus-choice > div:first-child span { color:#607865; font-size:10px; line-height:1.45; }
.question-bonus-options { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:8px; }
.question-bonus-options > button { display:grid; grid-template-columns:32px minmax(0,1fr); align-items:start; gap:8px; min-width:0; padding:10px; border:1px solid #cce4ce; border-radius:11px; color:#245230; text-align:left; background:linear-gradient(145deg,#fff,#f0f9f0); cursor:pointer; transition:transform .16s ease,border-color .16s ease,box-shadow .16s ease; }
.question-bonus-options > button:hover:not(:disabled) { transform:translateY(-2px); border-color:#5bb568; box-shadow:0 7px 17px #16852c1a; }
.question-bonus-options > button:disabled { opacity:.65; cursor:wait; }
.question-bonus-icon { display:grid; place-items:center; width:32px; height:32px; border-radius:9px; background:#e0f3e2; font-size:18px; }
.question-bonus-copy { display:grid; gap:4px; min-width:0; }
.question-bonus-copy b { color:#1d6731; font-size:11px; }
.question-bonus-copy small { color:#607865; font-size:9px; line-height:1.4; }
.question-bonus-action { grid-column:2; color:#16812f; font-size:8px; font-weight:900; letter-spacing:.08em; }
@media(max-width:620px) {
  .question-card { padding:18px; border-radius:18px; }
  .question-card h2 { margin-bottom:14px; font-size:20px; }
  .question-text { font-size:15px; }
  .question-illustration { max-height:170px; }
  .question-bonus-options { grid-template-columns:1fr; }
  .question-bonus-options > button { grid-template-columns:36px minmax(0,1fr) auto; align-items:center; }
  .question-bonus-icon { width:36px; height:36px; }
  .question-bonus-action { grid-column:auto; }
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
    gap: 12px;
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
    gap: 10px;
  }

  .cyber-card {
    min-height: 265px;
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
  .avatar-picker-panel {
    padding: 22px 16px;
    border-radius: 22px;
  }

  .avatar-picker-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 10px;
  }

  .avatar-choice {
    border-radius: 15px;
    font-size: 32px;
  }

  .avatar-picker-actions button {
    min-height: 44px;
    padding: 0 14px;
  }

  .cyber-card {
    min-height: 245px;
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



/* =========================================================
   PHASE 3C.1 • NECRO SOUL REBIRTH CINEMATIC
========================================================= */
.necro-rebirth-overlay {
  position: fixed;
  inset: 0;
  z-index: 17000;
  display: grid;
  place-items: center;
  overflow: hidden;
  pointer-events: none;
  background: rgba(19, 12, 30, 0.28);
  backdrop-filter: blur(3px);
}

.necro-rebirth-vignette {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 50% 52%, rgba(178, 100, 255, 0.18), transparent 24%),
    radial-gradient(circle at 50% 50%, transparent 25%, rgba(22, 12, 31, 0.55) 78%);
}

.necro-rebirth-stage {
  width: min(760px, 86vw);
  position: relative;
  z-index: 2;
  display: grid;
  grid-template-columns: minmax(150px, 1fr) 150px minmax(150px, 1fr);
  align-items: center;
  gap: 28px;
}

.necro-rebirth-card {
  min-width: 0;
  position: relative;
  display: grid;
  justify-items: center;
  gap: 8px;
  transition: all 0.55s cubic-bezier(0.2, 0.8, 0.2, 1);
}

.necro-rebirth-card img,
.necro-card-placeholder {
  width: clamp(130px, 17vw, 190px);
  aspect-ratio: 2 / 3;
  position: relative;
  z-index: 2;
  object-fit: cover;
  border: 3px solid rgba(238, 221, 255, 0.9);
  border-radius: 18px;
  background: #1d1428;
  box-shadow: 0 22px 60px rgba(23, 10, 34, 0.46);
}

.necro-card-placeholder {
  display: grid;
  place-items: center;
  color: #efe0ff;
  font-size: 62px;
}

.necro-rebirth-card strong {
  max-width: 210px;
  overflow: hidden;
  color: #fff;
  font-size: 14px;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.necro-rebirth-card small {
  color: #d8baf4;
  font-size: 8px;
  font-weight: 950;
  letter-spacing: 0.13em;
}

.necro-card-aura {
  width: 72%;
  aspect-ratio: 1;
  position: absolute;
  top: 32%;
  z-index: 1;
  border-radius: 50%;
  background: rgba(164, 82, 225, 0.36);
  filter: blur(30px);
  transform: translateY(-50%) scale(0.7);
  opacity: 0;
  transition: all 0.5s ease;
}

.necro-soul-core {
  width: 132px;
  height: 132px;
  position: relative;
  display: grid;
  place-items: center;
  border: 1px solid rgba(218, 180, 255, 0.48);
  border-radius: 50%;
  color: #f3e7ff;
  background: radial-gradient(circle, rgba(125, 58, 179, 0.86), rgba(42, 22, 57, 0.88) 66%, transparent 68%);
  box-shadow: 0 0 55px rgba(147, 75, 210, 0.38);
}

.necro-soul-core span {
  font-size: 48px;
}

.necro-soul-core b {
  position: absolute;
  bottom: -24px;
  font-size: 7px;
  letter-spacing: 0.3em;
}

.necro-soul-core i {
  position: absolute;
  inset: -13px;
  border: 2px dashed rgba(218, 180, 255, 0.48);
  border-radius: 50%;
  animation: necroSoulSpin 2.6s linear infinite;
}

.necro-rebirth-copy {
  position: absolute;
  left: 50%;
  bottom: max(36px, 7vh);
  z-index: 3;
  transform: translateX(-50%);
  text-align: center;
  color: #fff;
}

.necro-rebirth-copy small {
  color: #cfa9ef;
  font-size: 8px;
  font-weight: 950;
  letter-spacing: 0.2em;
}

.necro-rebirth-copy h2 {
  margin: 5px 0 2px;
  font-size: clamp(24px, 4vw, 46px);
  letter-spacing: 0.08em;
  text-shadow: 0 0 30px rgba(181, 102, 242, 0.58);
}

.necro-rebirth-copy p {
  margin: 0;
  color: #dcc8eb;
  font-size: 11px;
}

.phase-sacrifice .sacrifice-card {
  animation: necroSacrificeShake 0.62s ease both;
}

.phase-sacrifice .sacrifice-card .necro-card-aura,
.phase-soul .sacrifice-card .necro-card-aura {
  opacity: 1;
  transform: translateY(-50%) scale(1.2);
}

.phase-soul .sacrifice-card {
  transform: translateX(74px) scale(0.72);
  opacity: 0.18;
  filter: grayscale(0.8) brightness(0.6);
}

.revived-card {
  opacity: 0.08;
  transform: translateX(-38px) scale(0.78);
  filter: brightness(0.35);
}

.phase-revive .revived-card,
.phase-result .revived-card {
  opacity: 1;
  transform: translateX(0) scale(1);
  filter: brightness(1);
}

.phase-revive .revived-card .necro-card-aura,
.phase-result .revived-card .necro-card-aura {
  opacity: 1;
  background: rgba(103, 219, 170, 0.34);
  transform: translateY(-50%) scale(1.25);
}

.phase-revive .necro-soul-core {
  animation: necroSoulBurst 0.72s ease-out both;
}

.phase-result .sacrifice-card {
  opacity: 0;
  transform: translateX(100px) scale(0.55);
}

@keyframes necroSoulSpin {
  to { transform: rotate(360deg); }
}

@keyframes necroSacrificeShake {
  0%, 100% { transform: translateX(0) rotate(0); }
  20% { transform: translateX(-7px) rotate(-1deg); }
  40% { transform: translateX(8px) rotate(1deg); }
  60% { transform: translateX(-5px) rotate(-0.6deg); }
  80% { transform: translateX(4px) rotate(0.5deg); }
}

@keyframes necroSoulBurst {
  0% { transform: scale(1); filter: brightness(1); }
  40% { transform: scale(1.35); filter: brightness(1.8); }
  100% { transform: scale(0.84); filter: brightness(0.9); }
}

.necro-rebirth-enter-active,
.necro-rebirth-leave-active {
  transition: opacity 0.22s ease;
}

.necro-rebirth-enter-from,
.necro-rebirth-leave-to {
  opacity: 0;
}

@media (max-width: 720px) {
  .necro-rebirth-stage {
    width: 92vw;
    grid-template-columns: minmax(90px, 1fr) 80px minmax(90px, 1fr);
    gap: 10px;
  }

  .necro-soul-core {
    width: 72px;
    height: 72px;
  }

  .necro-soul-core span {
    font-size: 30px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .necro-rebirth-card,
  .necro-soul-core,
  .necro-soul-core i {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* Quiz reward and skill text follow the Timedoor light battle palette. */
.question-card,
.question-card :is(h2, .question-text, .question-learning-feedback, .question-bonus-choice, .question-bonus-copy, .question-bonus-action) {
  color: #21472b;
}
.question-card h2 { color: #193d24; }
.question-card .question-text { color: #2c5133; }
.question-card .question-learning-feedback,
.question-card .question-hints { border-color: #d6e8d6; background: #f5faf3; color: #36583c; }
.question-card .question-learning-feedback p,
.question-card .question-hints p,
.question-card .question-bonus-copy small,
.question-card .question-bonus-choice > div:first-child span { color: #536f58; }
.question-card .question-bonus-options > button {
  border-color: #cfe4cf;
  background: linear-gradient(145deg, #fff, #f2f9ef);
  color: #21472b;
}
.question-card .question-bonus-options > button b { color: #176d2e; }
.question-card .question-bonus-options > button small { color: #536f58; }
.question-card .question-bonus-action { color: #16812f; }
.bonus-panel { border-color: #dce9db; background: #fff; }
.bonus-panel .panel-heading h2,
.bonus-item,
.bonus-item strong { color: #193d24; }
.bonus-description,
.bonus-item small { color: #607865; }
.bonus-item { border-color: #cfe4cf; background: linear-gradient(145deg, #fff, #f2f9ef); }
.bonus-item-icon { background: #e6f5e5; }

.turn-ap-summary {
  color: #245b33;
  font-weight: 800;
}
.turn-ap-summary b {
  display: inline-grid;
  min-width: 38px;
  min-height: 24px;
  place-items: center;
  margin-right: 4px;
  padding: 0 7px;
  border: 1px solid #b7dfb8;
  border-radius: 999px;
  color: #11762c;
  background: #eaf7e8;
}
.turn-ap-summary small { color: #66816a; font-weight: 700; }

.control-console.action-points-console {
  grid-template-columns: 20px repeat(2, minmax(0, 1fr)) minmax(120px, 1.1fr) repeat(6, minmax(0, 1fr)) 20px;
}
.combo-attack-skill { border-color: #b9dcbc; background: linear-gradient(150deg, #f8fff6, #e7f6e5); color: #1b6330; }
.combo-attack-skill .console-icon { color: #108c32; }
.end-turn-skill { border-color: #d7e5d6; background: #f7faf5; color: #47634b; }
.end-turn-skill .console-icon { color: #6c8d6f; }

.combo-attack-modal {
  position: relative;
  z-index: 2;
  width: min(760px, calc(100vw - 28px));
  max-height: min(88vh, 900px);
  overflow: auto;
  padding: 24px;
  border: 1px solid #d7ead6;
  border-radius: 24px;
  color: #21472b;
  background: linear-gradient(145deg, #fff, #f4faf1);
  box-shadow: 0 24px 80px rgba(24, 66, 34, .24);
}
.combo-attack-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; margin-bottom: 18px; }
.combo-attack-header h2 { margin: 7px 0 6px; color: #173e24; font-size: clamp(22px, 4vw, 30px); }
.combo-attack-header p { max-width: 620px; margin: 0; color: #647c67; line-height: 1.5; }
.combo-choice-section { margin-top: 16px; }
.combo-choice-section > strong { display: block; margin-bottom: 9px; color: #397247; font-size: 11px; letter-spacing: .12em; }
.combo-card-options { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 9px; }
.combo-card-option-wrap { min-width: 0; display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: stretch; gap: 6px; }
.combo-card-option-wrap .combo-card-option { min-height: 78px; }
.combo-primary-choice { align-self: stretch; max-width: 116px; padding: 8px; border: 1px solid #d6e7d4; border-radius: 12px; color: #397247; background: #f7fbf5; font-size: 9px; font-weight: 900; cursor: pointer; }
.combo-primary-choice:disabled { opacity: .5; cursor: not-allowed; }
.combo-primary-choice.selected { border-color: #20a342; color: #fff; background: #20a342; }
.combo-card-option { min-width: 0; display: flex; align-items: center; gap: 10px; padding: 10px; border: 1px solid #d6e7d4; border-radius: 14px; text-align: left; color: #21472b; background: #fff; cursor: pointer; }
.combo-card-option.selected { border-color: #20a342; background: #edf8e9; box-shadow: 0 0 0 2px rgba(24, 169, 58, .12); }
.combo-card-option img { width: 48px; height: 58px; flex: 0 0 auto; border-radius: 8px; object-fit: cover; background: #e6f2e2; }
.combo-card-option-copy { min-width: 0; display: grid; gap: 4px; }
.combo-card-option-copy b { overflow: hidden; color: #20482b; text-overflow: ellipsis; white-space: nowrap; }
.combo-card-option-copy small { color: #66806a; font-size: 11px; line-height: 1.35; }
.combo-choice-check { margin-left: auto; color: #108c32; font-weight: 900; }
.combo-synergy-preview { display: grid; gap: 4px; margin: 12px 0 0; padding: 13px 15px; border: 1px solid #c8e5c5; border-radius: 14px; color: #245633; background: linear-gradient(120deg, #f1faef, #fff); }
.combo-synergy-preview > span { color: #398348; font-size: 12px; font-weight: 850; }
.combo-synergy-preview > small { color: #66806a; line-height: 1.4; }
.combo-direct-note { margin: 14px 0 0; padding: 12px 14px; border: 1px solid #d4e6d2; border-radius: 12px; color: #5c765f; background: #f4faf1; }
.combo-attack-actions { display: flex; align-items: center; justify-content: flex-end; gap: 10px; margin-top: 22px; }
.combo-attack-actions > span { margin-right: auto; color: #397247; font-size: 13px; font-weight: 850; }

@media (max-width: 1150px) {
  .control-console.action-points-console { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (max-width: 900px) {
  .control-console.action-points-console { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .combo-attack-modal { padding: 18px; }
}
@media (max-width: 560px) {
  .combo-card-options { grid-template-columns: 1fr; }
  .combo-primary-choice { max-width: 100px; }
  .combo-attack-actions { flex-wrap: wrap; }
  .combo-attack-actions > span { width: 100%; }
}


/* Command bar height follows its actual content, including mobile and RFID mode. */
.player-battle-ui{padding-bottom:calc(var(--action-panel-height,220px) + 52px)}
.deck-slots{justify-content:start}
.fusion-history-fab{bottom:calc(var(--action-panel-height,220px) + 24px)}
.battle-action-receipt{display:flex;flex-wrap:wrap;justify-content:space-between;gap:10px 20px;padding:14px 16px;margin-top:18px;background:#eff6e8;border:1px solid #d7e6cc;border-radius:11px;color:#385b3f;font:500 12px/1.7 Inter,Arial,sans-serif;overflow-wrap:anywhere}
.special-skill-tabs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));overflow:visible;gap:12px}
.special-skill-tab{min-width:0;align-items:start;padding:16px;gap:14px;background:#f7faf3;border-color:#d6e4d4;border-radius:12px}
.special-skill-tab>div{min-width:0;overflow-wrap:anywhere}.special-skill-tab .special-tab-icon{flex:none;width:48px;height:48px}
.special-skill-tab strong{font-size:16px;line-height:1.4;margin:6px 0}.special-skill-tab small{font-size:12px;line-height:1.7;font-weight:500;color:#667e6a;margin-top:8px}
.special-skill-tab .skill-slot-label{font-size:10px;letter-spacing:.08em;font-weight:800;color:#497649}
.special-skill-tab .skill-ready-reason{font-weight:700;color:#8c642f}.special-skill-tab.ready .skill-ready-reason{color:#257543}
.special-skill-tab.selected{border-color:#2b824d;box-shadow:0 0 0 2px #cce6bd}.special-skill-tab.ready{background:#f2f8ea}
.special-modal-header p,.special-skill-hero p,.special-target-panel p{font-size:13px;line-height:1.8}.special-skill-hero h3{font-size:22px}
.special-metric-grid>div>span,.special-effects-panel>span,.special-target-panel>span{font-size:10px}.special-metric-grid>div>strong{font-size:12px;line-height:1.6}.special-effects-panel li,.special-readiness span{font-size:12px;line-height:1.8}
.special-target-card strong{font-size:12px}.special-target-card small{font-size:11px}.special-modal-actions button,.fusion-modal-actions button{min-height:44px;font-size:12px}
.target-picker-panel:focus,.special-skill-modal:focus,.combo-attack-modal:focus,.fusion-modal:focus{outline:none}
.special-skill-tab:focus-visible,.special-target-card:focus-visible{outline:3px solid #27889a;outline-offset:3px}
@media(max-width:760px){.deck-slots{grid-template-columns:repeat(2,minmax(0,1fr));overflow:visible}.battle-stage{grid-template-columns:repeat(2,minmax(0,1fr))}.special-skill-tabs{grid-template-columns:1fr}.special-skill-tab{padding:14px}.special-skill-tab strong{font-size:15px}.special-modal-actions{grid-template-columns:minmax(65px,.4fr) minmax(0,1fr)}.battle-action-receipt{font-size:11px;padding:12px}.fusion-history-fab{right:12px}}
@media(prefers-reduced-motion:reduce){.target-picker-enter-active,.target-picker-leave-active{transition:none}}
</style>
