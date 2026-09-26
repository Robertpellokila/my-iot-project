<script setup>
import {
  ref,
  computed,
  onMounted,
  onUnmounted,
} from 'vue';

import { supabase } from '../lib/supabase';

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
});

const isDisplayOnly = computed(() => props.displayOnly);


/* =========================================================
   GAME CONFIG
========================================================= */

const BASE_PLAYER_HP = 200;

const MAX_ACTIVE = 4;
const MAX_BENCH = 4;
const MAX_TOTAL_CARDS = 8;

const MAX_SKILL = 100;

const BASIC_SKILL_GAIN = 25;
const HIT_SKILL_GAIN = 15;
const DEFENSE_SKILL_GAIN = 10;

const DEFENSE_REDUCTION = 0.5;

const ULTIMATE_MULTIPLIER = 2;

const HEAL_PERCENT = 0.35;

let battleCardCounter = 0;


/* =========================================================
   GENERAL STATE
========================================================= */

const battleState = ref('waiting_p1');

/*
waiting_p1
summoning_p1
waiting_p2
summoning_p2
battle_ready
*/

// Pengunci per reader: initial scan P1 dan P2 dapat berjalan paralel.
const readerProcessing = ref({
  p1: false,
  p2: false,
});

// UID yang sedang dicari dan yang sudah masuk ke pertandingan.
const pendingUids = new Set();
const usedUids = new Set();

// Mencegah hasil fetch lama mengubah pertandingan sesudah reset.
let battleGeneration = 0;

const READER_PLAYER = {
  'RC522-P1': 'p1',
  'RC522-P2': 'p2',
};

const isActing = ref(false);

let realtimeChannel;


/* =========================================================
   SOUND SYSTEM
========================================================= */

const SOUND_FILES = {
  attack: '/sounds/attack.mp3',
  hit: '/sounds/hit.mp3',
  defense: '/sounds/defense.mp3',
  heal: '/sounds/heal.mp3',
  ultimate: '/sounds/ultimate.mp3',
  synergy: '/sounds/synergy.mp3',
  summon: '/sounds/summon.mp3',
  bench: '/sounds/bench.mp3',
  swap: '/sounds/swap.mp3',
  warning: '/sounds/warning.mp3',
  question: '/sounds/question.mp3',
  correct: '/sounds/correct.mp3',
  wrong: '/sounds/wrong.mp3',
  win: '/sounds/win.mp3',
  lose: '/sounds/lose.mp3',
};

const soundEnabled = ref(true);
const audioUnlocked = ref(false);
const audioCache = new Map();
let endSoundPlayed = false;

const getAudio = (name) => {
  if (typeof Audio === 'undefined') return null;
  if (!SOUND_FILES[name]) return null;

  if (!audioCache.has(name)) {
    const audio = new Audio(SOUND_FILES[name]);
    audio.preload = 'auto';
    audioCache.set(name, audio);
  }

  return audioCache.get(name);
};

const unlockAudio = () => {
  if (audioUnlocked.value) return;
  audioUnlocked.value = true;
};

const playSound = async (name, volume = 0.85) => {
  if (!soundEnabled.value || !audioUnlocked.value) return;

  const audio = getAudio(name);
  if (!audio) return;

  try {
    audio.pause();
    audio.currentTime = 0;
    audio.volume = clamp(volume, 0, 1);
    await audio.play();
  } catch (error) {
    console.warn(`Sound ${name} gagal diputar:`, error);
  }
};

const toggleSound = () => {
  soundEnabled.value = !soundEnabled.value;
  unlockAudio();

  if (soundEnabled.value) {
    void playSound('question', 0.35);
  }
};

const playBattleEndSounds = async () => {
  if (endSoundPlayed) return;
  endSoundPlayed = true;

  await playSound('win', 0.95);

  // Arena dimainkan pada satu browser, jadi efek kalah diputar sesudah fanfare menang.
  setTimeout(() => {
    void playSound('lose', 0.65);
  }, 900);
};


/* =========================================================
   FULLSCREEN
========================================================= */

const isFullscreen = ref(false);

const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

const toggleFullscreen = async () => {
  try {
    if (!document.fullscreenElement) {
      await document.documentElement.requestFullscreen();
    } else {
      await document.exitFullscreen();
    }
  } catch (error) {
    console.error('Fullscreen gagal:', error);
  }
};


/* =========================================================
   CODING QUESTION EVERY 5 ROUNDS
========================================================= */

const QUESTION_INTERVAL_ROUNDS = 5;
const QUESTION_TABLE = 'coding_questions';

const roundCount = ref(0);
const questionMode = ref(false);
const questionLoading = ref(false);
const questionError = ref(null);
const currentQuestion = ref(null);
const selectedQuestionAnswer = ref(null);
const questionResult = ref(null);
const lastQuestionId = ref(null);

const normalizeQuestion = (row) => {
  if (!row) return null;

  let options = [];

  if (Array.isArray(row.options)) {
    options = row.options;
  } else if (row.options && typeof row.options === 'object') {
    options = Object.values(row.options);
  } else {
    options = [
      row.option_a ?? row.a,
      row.option_b ?? row.b,
      row.option_c ?? row.c,
      row.option_d ?? row.d,
    ].filter(value => value !== undefined && value !== null && String(value).trim() !== '');
  }

  const rawCorrect = row.correct_answer ?? row.correct_option ?? row.answer ?? row.correct_index;
  let correctIndex = -1;

  if (typeof rawCorrect === 'number') {
    correctIndex = rawCorrect >= 1 && rawCorrect <= options.length
      ? rawCorrect - 1
      : rawCorrect;
  } else {
    const text = String(rawCorrect ?? '').trim();
    const letter = text.toUpperCase();

    if (['A', 'B', 'C', 'D'].includes(letter)) {
      correctIndex = letter.charCodeAt(0) - 65;
    } else {
      correctIndex = options.findIndex(option => String(option).trim() === text);
    }
  }

  return {
    id: row.id ?? row.question_id ?? `${Date.now()}`,
    question: row.question ?? row.question_text ?? row.pertanyaan ?? 'Coding Question',
    options,
    correctIndex,
    explanation: row.explanation ?? row.penjelasan ?? '',
  };
};

const fetchCodingQuestion = async () => {
  questionLoading.value = true;
  questionError.value = null;
  currentQuestion.value = null;

  try {
    const { data, error } = await supabase
      .from(QUESTION_TABLE)
      .select('*')
      .limit(100);

    if (error) throw error;
    if (!data?.length) throw new Error(`Tabel ${QUESTION_TABLE} belum memiliki question.`);

    let candidates = data;

    if (data.length > 1 && lastQuestionId.value !== null) {
      candidates = data.filter(row => (row.id ?? row.question_id) !== lastQuestionId.value);
      if (!candidates.length) candidates = data;
    }

    const row = candidates[Math.floor(Math.random() * candidates.length)];
    const normalized = normalizeQuestion(row);

    if (!normalized || normalized.options.length < 2 || normalized.correctIndex < 0) {
      throw new Error('Format coding question tidak valid.');
    }

    currentQuestion.value = normalized;
    lastQuestionId.value = normalized.id;
  } catch (error) {
    console.error('Gagal mengambil coding question:', error);
    questionError.value = error?.message || 'Gagal mengambil pertanyaan dari database.';
  } finally {
    questionLoading.value = false;
  }
};

const startQuestionBreak = async () => {
  questionMode.value = true;
  selectedQuestionAnswer.value = null;
  questionResult.value = null;
  questionError.value = null;
  void playSound('question');
  await fetchCodingQuestion();
};

const answerCodingQuestion = (index) => {
  if (questionLoading.value || questionResult.value || !currentQuestion.value) return;

  selectedQuestionAnswer.value = index;
  questionResult.value = index === currentQuestion.value.correctIndex
    ? 'correct'
    : 'wrong';

  void playSound(questionResult.value === 'correct' ? 'correct' : 'wrong');
};

const continueAfterQuestion = () => {
  questionMode.value = false;
  questionLoading.value = false;
  questionError.value = null;
  currentQuestion.value = null;
  selectedQuestionAnswer.value = null;
  questionResult.value = null;
  isActing.value = false;
};

const showReaderWarning = (player, message) => {
  void playSound('warning');
  void showProfileMessage(player, `⚠ ${message}`);
};


/* =========================================================
   PARTY / CARDS
========================================================= */

const player1Cards = ref([]);
const player2Cards = ref([]);


/* =========================================================
   ACTIVE CARDS
========================================================= */

const player1ActiveCards = computed(() =>
  player1Cards.value.filter(
    card =>
      card.zone === 'active' &&
      !card.exhausted
  )
);

const player2ActiveCards = computed(() =>
  player2Cards.value.filter(
    card =>
      card.zone === 'active' &&
      !card.exhausted
  )
);


/* =========================================================
   BENCH
========================================================= */

const player1BenchCards = computed(() =>
  player1Cards.value.filter(
    card => card.zone === 'bench'
  )
);

const player2BenchCards = computed(() =>
  player2Cards.value.filter(
    card => card.zone === 'bench'
  )
);


/* =========================================================
   PLAYER HP
========================================================= */

const player1BattleHp = ref(
  BASE_PLAYER_HP
);

const player2BattleHp = ref(
  BASE_PLAYER_HP
);

const player1MaxHp = ref(
  BASE_PLAYER_HP
);

const player2MaxHp = ref(
  BASE_PLAYER_HP
);


/* =========================================================
   TURN SYSTEM
========================================================= */

const currentTurn = ref('p1');

/*
null
skill
synergy
summon
*/

const selectedTurnAction = ref(null);

const selectedBattleCard = ref(null);

const selectedSkill = ref(null);

const summonMode = ref(false);

const winner = ref(null);


/* =========================================================
   BENCH SWAP SYSTEM
========================================================= */

/*
Jika active slot penuh dan kita ingin
mengembalikan kartu dari Bench,

player pilih SWAP,
kemudian klik Active Card
yang ingin ditukar.
*/

const swapMode = ref(false);

const selectedBenchCard = ref(null);


/* =========================================================
   ULTIMATE GAUGE
========================================================= */

const player1Skill = ref(0);
const player2Skill = ref(0);


/* =========================================================
   SHARED DISPLAY STATE
   - Admin/dev mode uses local refs.
   - Public TV mode reads state supplied by Supabase.
========================================================= */

const normalizeSharedCard = card => ({
  ...card,
  battleId: card?.battleId ?? card?.id,
});

const displayPlayer1ActiveCards = computed(() =>
  isDisplayOnly.value
    ? props.sharedPlayer1Active.map(normalizeSharedCard)
    : player1ActiveCards.value
);

const displayPlayer2ActiveCards = computed(() =>
  isDisplayOnly.value
    ? props.sharedPlayer2Active.map(normalizeSharedCard)
    : player2ActiveCards.value
);

const displayPlayer1BenchCards = computed(() =>
  isDisplayOnly.value
    ? props.sharedPlayer1Bench.map(normalizeSharedCard)
    : player1BenchCards.value
);

const displayPlayer2BenchCards = computed(() =>
  isDisplayOnly.value
    ? props.sharedPlayer2Bench.map(normalizeSharedCard)
    : player2BenchCards.value
);

const displayPlayer1Hp = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player1_hp ?? BASE_PLAYER_HP)
    : player1BattleHp.value
);

const displayPlayer1MaxHp = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player1_max_hp ?? BASE_PLAYER_HP)
    : player1MaxHp.value
);

const displayPlayer2Hp = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player2_hp ?? BASE_PLAYER_HP)
    : player2BattleHp.value
);

const displayPlayer2MaxHp = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player2_max_hp ?? BASE_PLAYER_HP)
    : player2MaxHp.value
);

const displayPlayer1Skill = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player1_skill ?? 0)
    : player1Skill.value
);

const displayPlayer2Skill = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.player2_skill ?? 0)
    : player2Skill.value
);

const displayCurrentTurn = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? props.sharedBattle.current_turn
    : currentTurn.value
);

const displayWinner = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? props.sharedBattle.winner
    : winner.value
);

const displayRound = computed(() =>
  isDisplayOnly.value && props.sharedBattle
    ? Number(props.sharedBattle.round ?? 1)
    : roundCount.value + 1
);

const displayBattleState = computed(() => {
  if (!isDisplayOnly.value || !props.sharedBattle) {
    return battleState.value;
  }

  const status = props.sharedBattle.status;

  if (status === 'waiting') return 'waiting_p1';
  if (status === 'ready' || status === 'battle' || status === 'question' || status === 'finished') {
    return 'battle_ready';
  }

  return battleState.value;
});

const displayPlayer1HpPercent = computed(() =>
  clamp(
    (displayPlayer1Hp.value / Math.max(1, displayPlayer1MaxHp.value)) * 100,
    0,
    100
  )
);

const displayPlayer2HpPercent = computed(() =>
  clamp(
    (displayPlayer2Hp.value / Math.max(1, displayPlayer2MaxHp.value)) * 100,
    0,
    100
  )
);

const displayTurnText = computed(() => {
  if (!isDisplayOnly.value || !props.sharedBattle) {
    return turnText.value;
  }

  if (displayWinner.value === 'p1') return 'PLAYER 1 WINS';
  if (displayWinner.value === 'p2') return 'PLAYER 2 WINS';

  const status = props.sharedBattle.status;

  if (status === 'waiting') return 'SCAN P1 & P2';
  if (status === 'question' || props.sharedBattle.question_active) return 'CODING CHALLENGE';
  if (status === 'finished') return 'BATTLE FINISHED';

  return displayCurrentTurn.value === 'p2'
    ? 'PLAYER 2 TURN'
    : 'PLAYER 1 TURN';
});


/* =========================================================
   ONE TIME SKILLS
========================================================= */

const player1UltimateUsed =
  ref(false);

const player2UltimateUsed =
  ref(false);

const player1HealUsed =
  ref(false);

const player2HealUsed =
  ref(false);


/* =========================================================
   DEFENSE
========================================================= */

const player1Defending =
  ref(false);

const player2Defending =
  ref(false);


/* =========================================================
   WATER SYNERGY SHIELD
========================================================= */

const player1SynergyShield =
  ref(0);

const player2SynergyShield =
  ref(0);


/* =========================================================
   ICE DEBUFF
========================================================= */

const player1AttackDebuff =
  ref(0);

const player2AttackDebuff =
  ref(0);


/* =========================================================
   SYNERGY USAGE
========================================================= */

const createSynergyState = () => ({
  grass: false,
  fire: false,
  water: false,
  electric: false,
  ice: false,
  dark: false,
});

const player1SynergyUsed =
  ref(createSynergyState());

const player2SynergyUsed =
  ref(createSynergyState());


/* =========================================================
   PROFILE EFFECTS
========================================================= */

const player1ProfileEffect =
  ref(null);

const player2ProfileEffect =
  ref(null);

const player1ProfilePopup =
  ref(null);

const player2ProfilePopup =
  ref(null);


/* =========================================================
   SKILLS
========================================================= */

const player1Hand = [
  {
    id: 'p1-basic',
    name: 'Basic Attack',
    type: 'attack',
    icon: '⚔️',
    className: 'skill-basic',
  },

  {
    id: 'p1-defense',
    name: 'Defense',
    type: 'defense',
    icon: '🛡️',
    className: 'skill-defense',
  },

  {
    id: 'p1-ultimate',
    name: 'Ultimate',
    type: 'ultimate',
    icon: '💥',
    className: 'skill-ultimate',
  },

  {
    id: 'p1-heal',
    name: 'Heal',
    type: 'heal',
    icon: '💚',
    className: 'skill-heal',
  },
];


const player2Hand = [
  {
    id: 'p2-basic',
    name: 'Basic Attack',
    type: 'attack',
    icon: '⚔️',
    className: 'skill-basic',
  },

  {
    id: 'p2-defense',
    name: 'Defense',
    type: 'defense',
    icon: '🛡️',
    className: 'skill-defense',
  },

  {
    id: 'p2-ultimate',
    name: 'Ultimate',
    type: 'ultimate',
    icon: '💥',
    className: 'skill-ultimate',
  },

  {
    id: 'p2-heal',
    name: 'Heal',
    type: 'heal',
    icon: '💚',
    className: 'skill-heal',
  },
];


/* =========================================================
   SYNERGY CONFIG
========================================================= */

const SYNERGY_CONFIG = {

  grass: {
    name: 'Nature Blessing',
    icon: '🌿',
  },

  fire: {
    name: 'Blazing Fury',
    icon: '🔥',
  },

  water: {
    name: 'Ocean Guard',
    icon: '💧',
  },

  electric: {
    name: 'Overcharge',
    icon: '⚡',
  },

  ice: {
    name: 'Frozen Curse',
    icon: '❄️',
  },

  dark: {
    name: 'Shadow Burst',
    icon: '🌑',
  },

};


/* =========================================================
   HELPERS
========================================================= */

const wait = ms =>
  new Promise(resolve =>
    setTimeout(resolve, ms)
  );


const clamp = (
  value,
  min,
  max
) =>
  Math.min(
    Math.max(value, min),
    max
  );


const normalizeElement =
  element =>
    String(element || '')
      .trim()
      .toLowerCase();


const isImageUrl = value =>
  value &&
  (
    value.startsWith('http') ||
    value.startsWith('/')
  );


/* =========================================================
   PROFILE EFFECT
========================================================= */

const setProfileEffect =
  async (
    player,
    effect,
    popup = null,
    duration = 700
  ) => {

    if (player === 'p1') {

      player1ProfileEffect.value =
        effect;

      player1ProfilePopup.value =
        popup;

    } else {

      player2ProfileEffect.value =
        effect;

      player2ProfilePopup.value =
        popup;

    }


    await wait(duration);


    if (player === 'p1') {

      player1ProfileEffect.value =
        null;

      player1ProfilePopup.value =
        null;

    } else {

      player2ProfileEffect.value =
        null;

      player2ProfilePopup.value =
        null;

    }

  };


/* =========================================================
   QUICK PROFILE MESSAGE
========================================================= */

const showProfileMessage =
  async (
    player,
    message
  ) => {

    await setProfileEffect(
      player,
      'info',
      message,
      800
    );

  };


/* =========================================================
   CREATE BATTLE CARD
========================================================= */

const createBattleCard =
  card => ({

    ...card,

    battleId:
      `${card.uid || 'card'}-${++battleCardCounter}`,

    /*
    active
    bench
    */

    zone: 'active',

    /*
    Berapa kali kartu pernah:

    Bench -> Active
    */

    benchReturnCount: 0,

    /*
    true ketika kartu sudah
    tidak boleh digunakan lagi.
    */

    exhausted: false,

  });


/* =========================================================
   FETCH CARD FROM SUPABASE
========================================================= */

const fetchCardData =
  async scannedUid => {

    const {
      data,
      error,
    } =
      await supabase
        .from('game_cards')
        .select('*')
        .eq(
          'uid',
          scannedUid
        )
        .single();


    if (
      error ||
      !data
    ) {

      console.error(
        'Card tidak ditemukan:',
        error
      );

      return null;

    }


    return data;

  };


/* =========================================================
   HP PERCENT
========================================================= */

const player1HpPercent =
  computed(() => {

    return clamp(
      (
        player1BattleHp.value /
        player1MaxHp.value
      ) * 100,
      0,
      100
    );

  });


const player2HpPercent =
  computed(() => {

    return clamp(
      (
        player2BattleHp.value /
        player2MaxHp.value
      ) * 100,
      0,
      100
    );

  });


/* =========================================================
   HEAL AVAILABILITY
========================================================= */

const player1CanHeal =
  computed(() => {

    return (
      player1BattleHp.value <=
      player1MaxHp.value * 0.5
    );

  });


const player2CanHeal =
  computed(() => {

    return (
      player2BattleHp.value <=
      player2MaxHp.value * 0.5
    );

  });


/* =========================================================
   ULTIMATE AVAILABILITY
========================================================= */

const player1CanUltimate =
  computed(() => {

    return (
      player1Skill.value >=
        MAX_SKILL &&
      !player1UltimateUsed.value
    );

  });


const player2CanUltimate =
  computed(() => {

    return (
      player2Skill.value >=
        MAX_SKILL &&
      !player2UltimateUsed.value
    );

  });


/* =========================================================
   SUMMON AVAILABILITY
========================================================= */

const player1CanSummon =
  computed(() => {

    return (
      player1ActiveCards.value
        .length <
        MAX_ACTIVE
      &&
      player1Cards.value.length <
        MAX_TOTAL_CARDS
    );

  });


const player2CanSummon =
  computed(() => {

    return (
      player2ActiveCards.value
        .length <
        MAX_ACTIVE
      &&
      player2Cards.value.length <
        MAX_TOTAL_CARDS
    );

  });


/* =========================================================
   TURN TEXT
========================================================= */

const turnText =
  computed(() => {

    if (battleState.value !== 'battle_ready') {
      const p1Ready = player1Cards.value.length > 0;
      const p2Ready = player2Cards.value.length > 0;

      if (readerProcessing.value.p1 && readerProcessing.value.p2) {
        return 'SCANNING BOTH PLAYERS';
      }
      if (readerProcessing.value.p1) {
        return 'SCANNING PLAYER 1';
      }
      if (readerProcessing.value.p2) {
        return 'SCANNING PLAYER 2';
      }
      if (!p1Ready && !p2Ready) {
        return 'SCAN P1 & P2';
      }
      return p1Ready ? 'WAITING FOR PLAYER 2' : 'WAITING FOR PLAYER 1';
    }


    if (
      winner.value === 'p1'
    ) {
      return 'PLAYER 1 WINS';
    }


    if (
      winner.value === 'p2'
    ) {
      return 'PLAYER 2 WINS';
    }


    if (summonMode.value) {

      return (
        currentTurn.value === 'p1'
          ? 'P1 — SCAN SUMMON'
          : 'P2 — SCAN SUMMON'
      );

    }


    if (swapMode.value) {

      return (
        currentTurn.value === 'p1'
          ? 'P1 — SELECT SWAP TARGET'
          : 'P2 — SELECT SWAP TARGET'
      );

    }


    return (
      currentTurn.value === 'p1'
        ? 'PLAYER 1 TURN'
        : 'PLAYER 2 TURN'
    );

  });


/* =========================================================
   SKILL GAUGE
========================================================= */

const addSkill =
  (
    player,
    amount
  ) => {

    if (
      player === 'p1'
    ) {

      player1Skill.value =
        Math.min(
          MAX_SKILL,
          player1Skill.value +
            amount
        );

    } else {

      player2Skill.value =
        Math.min(
          MAX_SKILL,
          player2Skill.value +
            amount
        );

    }

  };


/* =========================================================
   ELEMENT COUNT
========================================================= */

const getElementCount =
  (
    player,
    element
  ) => {

    const key =
      normalizeElement(
        element
      );


    if (!key) {
      return 0;
    }


    const cards =
      player === 'p1'
        ? player1ActiveCards.value
        : player2ActiveCards.value;


    return cards.filter(
      card =>
        normalizeElement(
          card.element
        ) === key
    ).length;

  };


/* =========================================================
   SYNERGY POINT
========================================================= */

const getSynergyPoint =
  (
    player,
    element
  ) => {

    const count =
      getElementCount(
        player,
        element
      );


    if (count < 2) {
      return 0;
    }


    return count;

  };


/* =========================================================
   CAN USE SYNERGY
========================================================= */

const canUseSynergy =
  (
    player,
    element
  ) => {

    const key =
      normalizeElement(
        element
      );


    if (
      !key ||
      !SYNERGY_CONFIG[key]
    ) {
      return false;
    }


    if (
      getSynergyPoint(
        player,
        key
      ) < 2
    ) {
      return false;
    }


    const state =
      player === 'p1'
        ? player1SynergyUsed.value
        : player2SynergyUsed.value;


    return !state[key];

  };


/* =========================================================
   SYNERGY VALUES
========================================================= */

const getGrassHealPercent =
  points => {

    if (points >= 4) {
      return 0.60;
    }

    if (points === 3) {
      return 0.45;
    }

    if (points === 2) {
      return 0.30;
    }

    return 0;

  };


const getFireMultiplier =
  points => {

    if (points >= 4) {
      return 2.2;
    }

    if (points === 3) {
      return 1.8;
    }

    if (points === 2) {
      return 1.5;
    }

    return 1;

  };


const getWaterReduction =
  points => {

    if (points >= 4) {
      return 0.80;
    }

    if (points === 3) {
      return 0.60;
    }

    if (points === 2) {
      return 0.40;
    }

    return 0;

  };


const getElectricCharge =
  points => {

    if (points >= 4) {
      return 100;
    }

    if (points === 3) {
      return 70;
    }

    if (points === 2) {
      return 40;
    }

    return 0;

  };


const getIceDebuff =
  points => {

    if (points >= 4) {
      return 0.60;
    }

    if (points === 3) {
      return 0.40;
    }

    if (points === 2) {
      return 0.25;
    }

    return 0;

  };


const getDarkMultiplier =
  points => {

    if (points >= 4) {
      return 2;
    }

    if (points === 3) {
      return 1.7;
    }

    if (points === 2) {
      return 1.4;
    }

    return 1;

  };


/* =========================================================
   CARD OWNERSHIP
========================================================= */

const selectedCardBelongsTo =
  player => {

    if (
      !selectedBattleCard.value
    ) {
      return false;
    }


    const cards =
      player === 'p1'
        ? player1ActiveCards.value
        : player2ActiveCards.value;


    return cards.some(
      card =>
        card.battleId ===
        selectedBattleCard
          .value
          .battleId
    );

  };


/* =========================================================
   ACTIVE CARD CLICK
========================================================= */

const handleActiveCardClick =
  (
    player,
    card
  ) => {

    if (isDisplayOnly.value) return;

    /*
    Jika sedang SWAP,
    Active Card yang diklik
    menjadi target keluar.
    */

    if (swapMode.value) {

      completeBenchSwap(
        player,
        card
      );

      return;

    }


    selectBattleCard(
      player,
      card
    );

  };


/* =========================================================
   SELECT ACTIVE CARD
========================================================= */

const selectBattleCard =
  (
    player,
    card
  ) => {

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      summonMode.value
      ||
      swapMode.value
      ||
      selectedTurnAction.value
      ||
      currentTurn.value !==
        player
      ||
      card.zone !== 'active'
      ||
      card.exhausted
    ) {
      return;
    }


    selectedBattleCard.value =
      card;

  };


/* =========================================================
   MOVE ACTIVE -> BENCH
========================================================= */

const moveToBench =
  async (
    player,
    card
  ) => {

    if (isDisplayOnly.value) return;

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      summonMode.value
      ||
      swapMode.value
      ||
      selectedTurnAction.value
      ||
      currentTurn.value !==
        player
      ||
      card.zone !== 'active'
    ) {
      return;
    }


    const activeCards =
      player === 'p1'
        ? player1ActiveCards.value
        : player2ActiveCards.value;


    const benchCards =
      player === 'p1'
        ? player1BenchCards.value
        : player2BenchCards.value;


    /*
    Minimal 1 Active Card
    harus tetap ada.
    */

    if (
      activeCards.length <= 1
    ) {

      await showProfileMessage(
        player,
        'KEEP 1 ACTIVE'
      );

      return;

    }


    if (
      benchCards.length >=
      MAX_BENCH
    ) {

      await showProfileMessage(
        player,
        'BENCH FULL'
      );

      return;

    }


    /*
    Jika kartu sebelumnya
    pernah kembali:

    Bench -> Active

    berarti ketika sekarang
    masuk Bench lagi,
    kartu EXHAUSTED permanen.
    */

    if (
      card.benchReturnCount >= 1
    ) {

      card.exhausted = true;

    }


    card.zone = 'bench';
    void playSound('bench');


    if (
      selectedBattleCard.value
        ?.battleId ===
      card.battleId
    ) {

      selectedBattleCard.value =
        null;

    }


    if (card.exhausted) {

      await showProfileMessage(
        player,
        'CARD EXHAUSTED'
      );

    }

  };


/* =========================================================
   RETURN BENCH -> ACTIVE
========================================================= */

const returnFromBench =
  async (
    player,
    card
  ) => {

    if (isDisplayOnly.value) return;

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      summonMode.value
      ||
      swapMode.value
      ||
      selectedTurnAction.value
      ||
      currentTurn.value !==
        player
      ||
      card.zone !== 'bench'
    ) {
      return;
    }


    /*
    Sudah exhausted =
    tidak bisa digunakan lagi.
    */

    if (card.exhausted) {

      await showProfileMessage(
        player,
        'CARD UNUSABLE'
      );

      return;

    }


    /*
    Return hanya 1x.
    */

    if (
      card.benchReturnCount >= 1
    ) {

      card.exhausted = true;

      await showProfileMessage(
        player,
        'RETURN ALREADY USED'
      );

      return;

    }


    const activeCards =
      player === 'p1'
        ? player1ActiveCards.value
        : player2ActiveCards.value;


    /*
    Kalau ada slot kosong,
    langsung kembali Active.
    */

    if (
      activeCards.length <
      MAX_ACTIVE
    ) {

      card.zone =
        'active';

      card.benchReturnCount += 1;
      void playSound('swap');

      selectedBattleCard.value =
        card;


      await showProfileMessage(
        player,
        'CARD RETURNED'
      );


      return;

    }


    /*
    Kalau Active penuh,
    masuk SWAP MODE.
    */

    startBenchSwap(
      player,
      card
    );

  };


/* =========================================================
   START SWAP
========================================================= */

const startBenchSwap =
  (
    player,
    benchCard
  ) => {

    if (isDisplayOnly.value) return;

    if (
      currentTurn.value !==
        player
      ||
      selectedTurnAction.value
      ||
      summonMode.value
      ||
      isActing.value
      ||
      benchCard.exhausted
      ||
      benchCard.benchReturnCount >=
        1
    ) {
      return;
    }


    selectedBattleCard.value =
      null;

    selectedBenchCard.value =
      benchCard;

    swapMode.value = true;

  };


/* =========================================================
   CANCEL SWAP
========================================================= */

const cancelSwap = () => {

  swapMode.value = false;

  selectedBenchCard.value =
    null;

};


/* =========================================================
   COMPLETE SWAP
========================================================= */

const completeBenchSwap =
  async (
    player,
    activeCard
  ) => {

    if (isDisplayOnly.value) return;

    if (
      !swapMode.value
      ||
      !selectedBenchCard.value
      ||
      currentTurn.value !==
        player
      ||
      activeCard.zone !==
        'active'
      ||
      isActing.value
      ||
      selectedTurnAction.value
    ) {
      return;
    }


    const benchCard =
      selectedBenchCard.value;


    /*
    Validasi ownership.
    */

    const playerCards =
      player === 'p1'
        ? player1Cards.value
        : player2Cards.value;


    const ownsBench =
      playerCards.some(
        card =>
          card.battleId ===
          benchCard.battleId
      );


    const ownsActive =
      playerCards.some(
        card =>
          card.battleId ===
          activeCard.battleId
      );


    if (
      !ownsBench ||
      !ownsActive
    ) {
      cancelSwap();

      return;
    }


    /*
    Bench card masuk Active
    dan menggunakan satu-satunya
    kesempatan Return.
    */

    benchCard.zone =
      'active';

    benchCard.benchReturnCount += 1;


    /*
    Active card keluar ke Bench.

    Kalau dia juga sebelumnya
    sudah pernah return,
    dia langsung EXHAUSTED.
    */

    if (
      activeCard.benchReturnCount >=
      1
    ) {

      activeCard.exhausted =
        true;

    }


    activeCard.zone =
      'bench';


    swapMode.value =
      false;

    selectedBenchCard.value =
      null;


    selectedBattleCard.value =
      benchCard;

    void playSound('swap');

    await showProfileMessage(
      player,
      activeCard.exhausted
        ? 'SWAP • OUT CARD EXHAUSTED'
        : 'CARD SWAPPED'
    );

  };


/* =========================================================
   BASIC DAMAGE
========================================================= */

const calculateBasicDamage =
  card =>
    Math.max(
      1,
      Number(
        card?.attack || 10
      )
    );


/* =========================================================
   ULTIMATE DAMAGE
========================================================= */

const calculateUltimateDamage =
  card =>
    Math.max(
      1,
      Math.round(
        Number(
          card?.attack || 10
        ) *
        ULTIMATE_MULTIPLIER
      )
    );


/* =========================================================
   HEAL
========================================================= */

const calculateHeal =
  maxHp =>
    Math.round(
      maxHp *
      HEAL_PERCENT
    );


/* =========================================================
   DEAL DAMAGE
========================================================= */

const dealDamage =
  async (
    attackerPlayer,
    initialDamage,
    ignoreNormalDefense = false
  ) => {

    const defenderPlayer =
      attackerPlayer === 'p1'
        ? 'p2'
        : 'p1';


    let damage =
      Math.max(
        1,
        Math.round(
          initialDamage
        )
      );


    /*
    ICE DEBUFF milik attacker.
    */

    if (
      attackerPlayer === 'p1'
      &&
      player1AttackDebuff.value >
        0
    ) {

      damage =
        Math.max(
          1,
          Math.round(
            damage *
            (
              1 -
              player1AttackDebuff.value
            )
          )
        );

      player1AttackDebuff.value =
        0;

    }


    if (
      attackerPlayer === 'p2'
      &&
      player2AttackDebuff.value >
        0
    ) {

      damage =
        Math.max(
          1,
          Math.round(
            damage *
            (
              1 -
              player2AttackDebuff.value
            )
          )
        );

      player2AttackDebuff.value =
        0;

    }


    /*
    NORMAL DEFENSE.
    */

    if (
      !ignoreNormalDefense
    ) {

      if (
        defenderPlayer === 'p1'
        &&
        player1Defending.value
      ) {

        damage =
          Math.max(
            1,
            Math.round(
              damage *
              DEFENSE_REDUCTION
            )
          );

        player1Defending.value =
          false;

      }


      if (
        defenderPlayer === 'p2'
        &&
        player2Defending.value
      ) {

        damage =
          Math.max(
            1,
            Math.round(
              damage *
              DEFENSE_REDUCTION
            )
          );

        player2Defending.value =
          false;

      }

    }


    /*
    WATER SYNERGY SHIELD.
    */

    if (
      defenderPlayer === 'p1'
      &&
      player1SynergyShield.value >
        0
    ) {

      damage =
        Math.max(
          1,
          Math.round(
            damage *
            (
              1 -
              player1SynergyShield.value
            )
          )
        );

      player1SynergyShield.value =
        0;

    }


    if (
      defenderPlayer === 'p2'
      &&
      player2SynergyShield.value >
        0
    ) {

      damage =
        Math.max(
          1,
          Math.round(
            damage *
            (
              1 -
              player2SynergyShield.value
            )
          )
        );

      player2SynergyShield.value =
        0;

    }


    /*
    Damage sekarang selalu
    ke PLAYER PROFILE.
    */

    void playSound('hit');

    if (
      defenderPlayer === 'p1'
    ) {

      player1BattleHp.value =
        Math.max(
          0,
          player1BattleHp.value -
            damage
        );


      await setProfileEffect(
        'p1',
        'damage',
        `💥 -${damage} HP`,
        750
      );

    } else {

      player2BattleHp.value =
        Math.max(
          0,
          player2BattleHp.value -
            damage
        );


      await setProfileEffect(
        'p2',
        'damage',
        `💥 -${damage} HP`,
        750
      );

    }


    return damage;

  };


/* =========================================================
   CAN USE SKILL
========================================================= */

const canUseSkill =
  (
    player,
    skill
  ) => {

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      summonMode.value
      ||
      swapMode.value
      ||
      selectedTurnAction.value
      ||
      currentTurn.value !==
        player
    ) {
      return false;
    }


    if (
      !selectedCardBelongsTo(
        player
      )
    ) {
      return false;
    }


    if (
      selectedBattleCard.value
        .exhausted
    ) {
      return false;
    }


    if (
      skill.type === 'attack'
    ) {
      return true;
    }


    if (
      skill.type === 'defense'
    ) {
      return true;
    }


    if (
      skill.type === 'ultimate'
    ) {

      return (
        player === 'p1'
          ? player1CanUltimate.value
          : player2CanUltimate.value
      );

    }


    if (
      skill.type === 'heal'
    ) {

      if (
        player === 'p1'
      ) {

        return (
          player1CanHeal.value
          &&
          !player1HealUsed.value
        );

      }


      return (
        player2CanHeal.value
        &&
        !player2HealUsed.value
      );

    }


    return false;

  };


/* =========================================================
   NEXT TURN
========================================================= */

const nextTurn = async () => {
  // Aksi tetap terkunci sampai pergantian giliran selesai.
  await wait(150);

  if (winner.value || battleState.value !== 'battle_ready') return;

  const finishedPlayer = currentTurn.value;
  currentTurn.value = finishedPlayer === 'p1' ? 'p2' : 'p1';

  selectedSkill.value = null;
  selectedBattleCard.value = null;
  selectedTurnAction.value = null;
  selectedBenchCard.value = null;
  swapMode.value = false;
  summonMode.value = false;

  // Satu putaran = P1 selesai + P2 selesai.
  // Karena battle selalu berurutan P1 -> P2, putaran selesai setelah aksi P2.
  if (finishedPlayer === 'p2') {
    roundCount.value += 1;

    if (roundCount.value % QUESTION_INTERVAL_ROUNDS === 0) {
      isActing.value = true;
      await startQuestionBreak();
      return;
    }
  }

  isActing.value = false;
};



/* =========================================================
   CHECK WINNER
========================================================= */

const checkWinner =
  () => {

    if (
      player1BattleHp.value <= 0
    ) {

      winner.value =
        'p2';

      void playBattleEndSounds();
      return true;

    }


    if (
      player2BattleHp.value <= 0
    ) {

      winner.value =
        'p1';

      void playBattleEndSounds();
      return true;

    }


    return false;

  };


/* =========================================================
   PLAY NORMAL SKILL
========================================================= */

const playSkill =
  async (
    player,
    skill
  ) => {

    if (isDisplayOnly.value) return;

    if (
      !canUseSkill(
        player,
        skill
      )
    ) {
      return;
    }


    selectedTurnAction.value =
      'skill';

    selectedSkill.value =
      skill;

    isActing.value =
      true;


    const card =
      selectedBattleCard.value;


    /* =====================================================
       BASIC ATTACK
    ===================================================== */

    if (
      skill.type === 'attack'
    ) {

      void playSound('attack');

      const damage =
        calculateBasicDamage(
          card
        );


      addSkill(
        player,
        BASIC_SKILL_GAIN
      );


      addSkill(
        player === 'p1'
          ? 'p2'
          : 'p1',
        HIT_SKILL_GAIN
      );


      await dealDamage(
        player,
        damage
      );

    }


    /* =====================================================
       DEFENSE
    ===================================================== */

    else if (
      skill.type === 'defense'
    ) {

      void playSound('defense');

      if (
        player === 'p1'
      ) {

        player1Defending.value =
          true;

      } else {

        player2Defending.value =
          true;

      }


      addSkill(
        player,
        DEFENSE_SKILL_GAIN
      );


      await setProfileEffect(
        player,
        'defense',
        '🛡 DEFENSE ACTIVE',
        800
      );

    }


    /* =====================================================
       ULTIMATE
    ===================================================== */

    else if (
      skill.type === 'ultimate'
    ) {

      void playSound('ultimate');

      if (
        player === 'p1'
      ) {

        player1Skill.value = 0;

        player1UltimateUsed.value =
          true;

      } else {

        player2Skill.value = 0;

        player2UltimateUsed.value =
          true;

      }


      await setProfileEffect(
        player,
        'ultimate',
        '💥 ULTIMATE!',
        500
      );


      const damage =
        calculateUltimateDamage(
          card
        );


      await dealDamage(
        player,
        damage
      );


      addSkill(
        player === 'p1'
          ? 'p2'
          : 'p1',
        20
      );

    }


    /* =====================================================
       HEAL
    ===================================================== */

    else if (
      skill.type === 'heal'
    ) {

      void playSound('heal');

      if (
        player === 'p1'
      ) {

        const amount =
          calculateHeal(
            player1MaxHp.value
          );


        const oldHp =
          player1BattleHp.value;


        player1BattleHp.value =
          Math.min(
            player1MaxHp.value,
            player1BattleHp.value +
              amount
          );


        const actualHeal =
          player1BattleHp.value -
          oldHp;


        player1HealUsed.value =
          true;


        await setProfileEffect(
          'p1',
          'heal',
          `💚 +${actualHeal} HP`,
          900
        );

      } else {

        const amount =
          calculateHeal(
            player2MaxHp.value
          );


        const oldHp =
          player2BattleHp.value;


        player2BattleHp.value =
          Math.min(
            player2MaxHp.value,
            player2BattleHp.value +
              amount
          );


        const actualHeal =
          player2BattleHp.value -
          oldHp;


        player2HealUsed.value =
          true;


        await setProfileEffect(
          'p2',
          'heal',
          `💚 +${actualHeal} HP`,
          900
        );

      }

    }


    if (
      checkWinner()
    ) {

      selectedTurnAction.value =
        null;

      selectedSkill.value =
        null;

      selectedBattleCard.value =
        null;

      isActing.value =
        false;

      return;

    }


    await nextTurn();

  };


/* =========================================================
   PLAY SYNERGY
========================================================= */

const playSynergy =
  async player => {

    if (isDisplayOnly.value) return;

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      summonMode.value
      ||
      swapMode.value
      ||
      selectedTurnAction.value
      ||
      currentTurn.value !==
        player
      ||
      !selectedCardBelongsTo(
        player
      )
    ) {
      return;
    }


    const card =
      selectedBattleCard.value;


    const element =
      normalizeElement(
        card.element
      );


    if (
      !canUseSynergy(
        player,
        element
      )
    ) {
      return;
    }


    const points =
      getSynergyPoint(
        player,
        element
      );


    const synergyUsed =
      player === 'p1'
        ? player1SynergyUsed.value
        : player2SynergyUsed.value;


    /*
    Langsung tandai used.
    */

    synergyUsed[element] =
      true;


    selectedTurnAction.value =
      'synergy';

    isActing.value =
      true;

    void playSound('synergy');


    /* =====================================================
       GRASS
    ===================================================== */

    if (
      element === 'grass'
    ) {

      const percentage =
        getGrassHealPercent(
          points
        );


      if (
        player === 'p1'
      ) {

        const oldHp =
          player1BattleHp.value;


        player1BattleHp.value =
          Math.min(
            player1MaxHp.value,
            player1BattleHp.value +
            Math.round(
              player1MaxHp.value *
              percentage
            )
          );


        const actual =
          player1BattleHp.value -
          oldHp;


        await setProfileEffect(
          'p1',
          'synergy',
          `🌿 +${actual} HP`,
          900
        );

      } else {

        const oldHp =
          player2BattleHp.value;


        player2BattleHp.value =
          Math.min(
            player2MaxHp.value,
            player2BattleHp.value +
            Math.round(
              player2MaxHp.value *
              percentage
            )
          );


        const actual =
          player2BattleHp.value -
          oldHp;


        await setProfileEffect(
          'p2',
          'synergy',
          `🌿 +${actual} HP`,
          900
        );

      }

    }


    /* =====================================================
       FIRE
    ===================================================== */

    else if (
      element === 'fire'
    ) {

      const multiplier =
        getFireMultiplier(
          points
        );


      const damage =
        Math.round(
          Number(
            card.attack || 10
          ) *
          multiplier
        );


      await setProfileEffect(
        player,
        'synergy',
        `🔥 ${points}x FIRE`,
        450
      );


      await dealDamage(
        player,
        damage
      );

    }


    /* =====================================================
       WATER
    ===================================================== */

    else if (
      element === 'water'
    ) {

      const reduction =
        getWaterReduction(
          points
        );


      if (
        player === 'p1'
      ) {

        player1SynergyShield.value =
          reduction;

      } else {

        player2SynergyShield.value =
          reduction;

      }


      await setProfileEffect(
        player,
        'synergy',
        `💧 SHIELD ${Math.round(
          reduction * 100
        )}%`,
        900
      );

    }


    /* =====================================================
       ELECTRIC
    ===================================================== */

    else if (
      element === 'electric'
    ) {

      const charge =
        getElectricCharge(
          points
        );


      addSkill(
        player,
        charge
      );


      await setProfileEffect(
        player,
        'synergy',
        `⚡ ULTIMATE +${charge}%`,
        900
      );

    }


    /* =====================================================
       ICE
    ===================================================== */

    else if (
      element === 'ice'
    ) {

      const debuff =
        getIceDebuff(
          points
        );


      if (
        player === 'p1'
      ) {

        player2AttackDebuff.value =
          debuff;

      } else {

        player1AttackDebuff.value =
          debuff;

      }


      await setProfileEffect(
        player,
        'synergy',
        `❄ ENEMY ATK -${Math.round(
          debuff * 100
        )}%`,
        900
      );

    }


    /* =====================================================
       DARK
    ===================================================== */

    else if (
      element === 'dark'
    ) {

      const multiplier =
        getDarkMultiplier(
          points
        );


      const damage =
        Math.round(
          Number(
            card.attack || 10
          ) *
          multiplier
        );


      await setProfileEffect(
        player,
        'synergy',
        `🌑 SHADOW BURST`,
        450
      );


      /*
      Dark mengabaikan
      Defense biasa.
      */

      await dealDamage(
        player,
        damage,
        true
      );

    }


    if (
      checkWinner()
    ) {

      selectedTurnAction.value =
        null;

      selectedBattleCard.value =
        null;

      isActing.value =
        false;

      return;

    }


    await nextTurn();

  };


/* =========================================================
   SYNERGY DISPLAY
========================================================= */

const selectedSynergyInfo =
  computed(() => {

    if (
      !selectedBattleCard.value
    ) {
      return null;
    }


    const element =
      normalizeElement(
        selectedBattleCard
          .value
          .element
      );


    if (
      !SYNERGY_CONFIG[element]
    ) {
      return null;
    }


    const points =
      getSynergyPoint(
        currentTurn.value,
        element
      );


    const usage =
      currentTurn.value === 'p1'
        ? player1SynergyUsed.value
        : player2SynergyUsed.value;


    return {

      element,

      points,

      used:
        !!usage[element],

      canUse:
        canUseSynergy(
          currentTurn.value,
          element
        ),

      ...SYNERGY_CONFIG[element],

    };

  });


/* =========================================================
   SUMMON MODE
========================================================= */

const chooseSummon =
  player => {

    if (isDisplayOnly.value) return;

    if (
      battleState.value !==
        'battle_ready'
      ||
      winner.value
      ||
      isActing.value
      ||
      selectedTurnAction.value
      ||
      swapMode.value
      ||
      currentTurn.value !==
        player
    ) {
      return;
    }


    const canSummon =
      player === 'p1'
        ? player1CanSummon.value
        : player2CanSummon.value;


    if (!canSummon) {
      return;
    }


    selectedBattleCard.value =
      null;

    selectedBenchCard.value =
      null;

    selectedTurnAction.value =
      'summon';

    summonMode.value =
      true;

  };


/* =========================================================
   CANCEL SUMMON
========================================================= */

const cancelSummon =
  () => {

    if (isDisplayOnly.value) return;

    if (isActing.value || readerProcessing.value[currentTurn.value]) {
      return;
    }


    summonMode.value =
      false;

    selectedTurnAction.value =
      null;

  };


/* =========================================================
   SUMMON BATTLE CARD
========================================================= */

const summonBattleCard =
  async cardData => {

    if (
      !summonMode.value
      ||
      selectedTurnAction.value !==
        'summon'
    ) {
      return;
    }


    const player =
      currentTurn.value;


    const canSummon =
      player === 'p1'
        ? player1CanSummon.value
        : player2CanSummon.value;


    if (!canSummon) {

      summonMode.value =
        false;

      selectedTurnAction.value =
        null;

      return;

    }


    isActing.value =
      true;

    void playSound('summon');

    const card =
      createBattleCard(
        cardData
      );


    const hpGain =
      Number(
        cardData.hp || 0
      );


    if (
      player === 'p1'
    ) {

      player1Cards.value.push(
        card
      );


      player1MaxHp.value +=
        hpGain;

      player1BattleHp.value +=
        hpGain;


      await setProfileEffect(
        'p1',
        'summon',
        `✨ SUMMON +${hpGain} HP`,
        900
      );

    } else {

      player2Cards.value.push(
        card
      );


      player2MaxHp.value +=
        hpGain;

      player2BattleHp.value +=
        hpGain;


      await setProfileEffect(
        'p2',
        'summon',
        `✨ SUMMON +${hpGain} HP`,
        900
      );

    }


    await nextTurn();

  };


/* =========================================================
   RFID LISTENER
========================================================= */

/*
  Dual RC522:
  - RC522-P1 -> P1; RC522-P2 -> P2.
  - Initial scan dapat berlangsung bersamaan.
  - Summon battle hanya menerima reader milik currentTurn.
  - UID hanya boleh masuk satu kali per pertandingan.
*/
const normalizeUid = (uid) => String(uid ?? '').trim().toUpperCase();

const refreshInitialBattleState = () => {
  if (winner.value || battleState.value === 'battle_ready') return;

  const p1Ready = player1Cards.value.length > 0;
  const p2Ready = player2Cards.value.length > 0;
  const p1Busy = readerProcessing.value.p1;
  const p2Busy = readerProcessing.value.p2;

  if (p1Ready && p2Ready && !p1Busy && !p2Busy) {
    currentTurn.value = 'p1';
    battleState.value = 'battle_ready';
  } else if (p1Busy && !p1Ready) {
    battleState.value = 'summoning_p1';
  } else if (p2Busy && !p2Ready) {
    battleState.value = 'summoning_p2';
  } else if (!p1Ready) {
    battleState.value = 'waiting_p1';
  } else {
    battleState.value = 'waiting_p2';
  }
};

const handleReaderScan = async (payload) => {
  const deviceId = String(payload?.new?.device_id ?? '').trim();
  const player = READER_PLAYER[deviceId];
  const uid = normalizeUid(payload?.new?.uid);

  if (!player || !uid || winner.value) return;
  if (readerProcessing.value[player]) return;

  const isInitial = battleState.value !== 'battle_ready';
  if (isInitial) {
    // P1 & P2 bebas scan awal, tetapi masing-masing hanya sekali.
    const playerCards = player === 'p1' ? player1Cards.value : player2Cards.value;
    if (playerCards.length > 0) return;
  } else {
    // Saat coding question tampil, semua scan battle dihentikan sementara.
    if (questionMode.value) {
      showReaderWarning(player, 'QUESTION IN PROGRESS');
      return;
    }

    // Reader milik pemain yang bukan currentTurn memberi warning pada player tersebut.
    if (currentTurn.value !== player) {
      showReaderWarning(
        player,
        currentTurn.value === 'p1' ? 'WAIT FOR PLAYER 1 TURN' : 'WAIT FOR PLAYER 2 TURN'
      );
      return;
    }

    // Player yang benar tetap harus menekan SUMMON sebelum melakukan scan.
    if (!summonMode.value || selectedTurnAction.value !== 'summon') {
      showReaderWarning(player, 'PRESS SUMMON FIRST');
      return;
    }

    if (isActing.value || swapMode.value) return;

    const canSummon = player === 'p1'
      ? player1CanSummon.value
      : player2CanSummon.value;

    if (!canSummon) {
      showReaderWarning(player, 'ACTIVE DECK FULL');
      return;
    }
  }

  // Cegah scan berulang dan pemakaian UID yang sama oleh dua reader.
  if (usedUids.has(uid) || pendingUids.has(uid)) {
    console.warn('UID sudah digunakan/diproses pada battle ini:', uid);
    return;
  }

  const generation = battleGeneration;
  readerProcessing.value[player] = true;
  pendingUids.add(uid);
  if (isInitial) refreshInitialBattleState();

  let committed = false;

  try {
    const cardData = await fetchCardData(uid);
    if (generation !== battleGeneration || !cardData) return;

    if (isInitial) {
      // Pastikan player yang sama belum punya kartu saat fetch selesai.
      const cards = player === 'p1' ? player1Cards : player2Cards;
      if (cards.value.length > 0 || battleState.value === 'battle_ready') return;

      const card = createBattleCard(cardData);
      const hp = Math.max(0, Number(cardData.hp) || 0);
      cards.value = [card];

      if (player === 'p1') {
        player1MaxHp.value = BASE_PLAYER_HP + hp;
        player1BattleHp.value = BASE_PLAYER_HP + hp;
      } else {
        player2MaxHp.value = BASE_PLAYER_HP + hp;
        player2BattleHp.value = BASE_PLAYER_HP + hp;
      }

      usedUids.add(uid);
      committed = true;
      void playSound('summon');
      await setProfileEffect(player, 'summon', `✨ +${hp} HP`, 700);
    } else {
      // Setelah fetch, validasi ulang agar scan yang dibatalkan tidak masuk.
      if (
        battleState.value !== 'battle_ready' ||
        currentTurn.value !== player ||
        !summonMode.value ||
        selectedTurnAction.value !== 'summon' ||
        isActing.value
      ) return;

      // Kunci kartu sebelum animasi/nextTurn agar scan ulang ditolak.
      usedUids.add(uid);
      committed = true;
      await summonBattleCard(cardData);
    }
  } catch (error) {
    console.error(`RFID ${deviceId} gagal diproses:`, error);
  } finally {
    if (generation === battleGeneration) {
      pendingUids.delete(uid);
      if (!committed) usedUids.delete(uid);
      readerProcessing.value[player] = false;
      if (isInitial) refreshInitialBattleState();
    }
  }
};

const setupBattleListener = () => {
  realtimeChannel = supabase
    .channel('arena_listener')
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'scan_events' },
      (payload) => {
        // Tidak await di sini: proses P1 dan P2 benar-benar independen.
        void handleReaderScan(payload);
      }
    )
    .subscribe((status) => {
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.error('Supabase Realtime arena:', status);
      }
    });
};


/* =========================================================
   RESET
========================================================= */

const resetArena =
  () => {

    player1Cards.value = [];
    player2Cards.value = [];


    player1BattleHp.value =
      BASE_PLAYER_HP;

    player2BattleHp.value =
      BASE_PLAYER_HP;


    player1MaxHp.value =
      BASE_PLAYER_HP;

    player2MaxHp.value =
      BASE_PLAYER_HP;


    player1Skill.value = 0;
    player2Skill.value = 0;


    player1Defending.value =
      false;

    player2Defending.value =
      false;


    player1SynergyShield.value =
      0;

    player2SynergyShield.value =
      0;


    player1AttackDebuff.value =
      0;

    player2AttackDebuff.value =
      0;


    player1UltimateUsed.value =
      false;

    player2UltimateUsed.value =
      false;


    player1HealUsed.value =
      false;

    player2HealUsed.value =
      false;


    player1SynergyUsed.value =
      createSynergyState();

    player2SynergyUsed.value =
      createSynergyState();


    currentTurn.value =
      'p1';


    selectedTurnAction.value =
      null;

    selectedBattleCard.value =
      null;

    selectedBenchCard.value =
      null;

    selectedSkill.value =
      null;


    summonMode.value =
      false;

    swapMode.value =
      false;


    isActing.value =
      false;

    roundCount.value = 0;
    questionMode.value = false;
    questionLoading.value = false;
    questionError.value = null;
    currentQuestion.value = null;
    selectedQuestionAnswer.value = null;
    questionResult.value = null;
    lastQuestionId.value = null;
    endSoundPlayed = false;

    battleGeneration += 1;
    readerProcessing.value = { p1: false, p2: false };
    pendingUids.clear();
    usedUids.clear();


    player1ProfileEffect.value =
      null;

    player2ProfileEffect.value =
      null;

    player1ProfilePopup.value =
      null;

    player2ProfilePopup.value =
      null;


    winner.value =
      null;


    battleState.value =
      'waiting_p1';

  };


/* =========================================================
   LIFECYCLE
========================================================= */

onMounted(() => {

  if (!isDisplayOnly.value) {
    setupBattleListener();
  }

  document.addEventListener(
    'fullscreenchange',
    handleFullscreenChange
  );

});


onUnmounted(() => {

  if (
    realtimeChannel
  ) {

    supabase.removeChannel(
      realtimeChannel
    );

  }

  document.removeEventListener(
    'fullscreenchange',
    handleFullscreenChange
  );

  audioCache.forEach(audio => {
    audio.pause();
    audio.src = '';
  });
  audioCache.clear();

});
</script>


<template>

  <div class="battle-game" @pointerdown.capture="unlockAudio">

    <!-- =====================================================
         HEADER
    ====================================================== -->

    <header class="battle-header">


      <!-- ===================================================
           PLAYER 1 PROFILE
      ==================================================== -->

      <section
        class="player-hud hud-blue"

        :class="[
          {
            'hud-current-blue':
              displayBattleState === 'battle_ready'
              &&
              displayCurrentTurn === 'p1'
              &&
              !displayWinner
          },

          player1ProfileEffect
            ? `profile-${player1ProfileEffect}`
            : ''
        ]"
      >

        <div
          class="player-avatar avatar-blue"
        >
          👦🏻
        </div>


        <Transition name="profile-popup">

          <div
            v-if="
              player1ProfilePopup
            "
            class="profile-effect-popup"

            :class="
              player1ProfileEffect
            "
          >
            {{ player1ProfilePopup }}
          </div>

        </Transition>


        <div class="player-status">

          <div class="player-name">

            <span>
              Player 1
            </span>

            <span class="pokemon-count">

              Active
              {{ displayPlayer1ActiveCards.length }}/4

              •

              Bench
              {{ displayPlayer1BenchCards.length }}/4

            </span>

          </div>


          <!-- HP -->

          <div class="status-line">

            <div class="hp-track">

              <div
                class="hp-fill hp-blue"

                :style="{
                  width:
                    `${displayPlayer1HpPercent}%`
                }"
              />

            </div>


            <span class="hp-value">

              HP

              {{ displayPlayer1Hp }}

              /

              {{ displayPlayer1MaxHp }}

            </span>

          </div>


          <!-- ULTIMATE -->

          <div class="skill-status">

            <div class="skill-status-label">

              <span>
                ULTIMATE
              </span>


              <span>

                {{
                  player1UltimateUsed
                    ? 'USED'
                    : `${displayPlayer1Skill}%`
                }}

              </span>

            </div>


            <div class="skill-track">

              <div
                class="skill-fill skill-blue"

                :class="{
                  'skill-ready':
                    player1CanUltimate
                }"

                :style="{
                  width:
                    `${
                      player1UltimateUsed
                        ? 0
                        : displayPlayer1Skill
                    }%`
                }"
              />

            </div>

          </div>


          <!-- STATUS -->

          <div class="status-badges">

            <span
              v-if="
                player1Defending
              "
              class="status-chip blue-chip"
            >
              🛡 Defense
            </span>


            <span
              v-if="
                player1SynergyShield >
                0
              "
              class="status-chip blue-chip"
            >

              💧 Shield

              {{
                Math.round(
                  player1SynergyShield *
                  100
                )
              }}%

            </span>


            <span
              v-if="
                player1AttackDebuff >
                0
              "
              class="status-chip debuff-chip"
            >

              ❄️ ATK -

              {{
                Math.round(
                  player1AttackDebuff *
                  100
                )
              }}%

            </span>

          </div>

        </div>

      </section>


      <!-- ===================================================
           CENTER HEADER
      ==================================================== -->

      <section class="center-header">

        <div class="game-logo">

          <span class="logo-mini">
            CARD BATTLE
          </span>

          <strong>
            NEXUS
          </strong>

          <span class="logo-bottom">
            BATTLE ARENA
          </span>

        </div>


        <div
          class="turn-indicator"

          :class="{
            blue:
              displayCurrentTurn === 'p1',

            red:
              displayCurrentTurn === 'p2'
          }"
        >

          ● {{ displayTurnText }}

        </div>

        <div class="header-game-controls">
          <button
            class="header-control-button"
            @click="toggleSound"
            :title="soundEnabled ? 'Mute sound' : 'Enable sound'"
          >
            {{ soundEnabled ? '🔊' : '🔇' }}
          </button>

          <button
            class="header-control-button fullscreen-button"
            @click="toggleFullscreen"
          >
            {{ isFullscreen ? '⛶ EXIT' : '⛶ FULL' }}
          </button>
        </div>

      </section>


      <!-- ===================================================
           PLAYER 2 PROFILE
      ==================================================== -->

      <section
        class="player-hud hud-red"

        :class="[
          {
            'hud-current-red':
              displayBattleState === 'battle_ready'
              &&
              displayCurrentTurn === 'p2'
              &&
              !displayWinner
          },

          player2ProfileEffect
            ? `profile-${player2ProfileEffect}`
            : ''
        ]"
      >

        <Transition name="profile-popup">

          <div
            v-if="
              player2ProfilePopup
            "
            class="profile-effect-popup"

            :class="
              player2ProfileEffect
            "
          >
            {{ player2ProfilePopup }}
          </div>

        </Transition>


        <div class="player-status player-status-right">

          <div class="player-name">

            <span class="pokemon-count">

              Active
              {{ displayPlayer2ActiveCards.length }}/4

              •

              Bench
              {{ displayPlayer2BenchCards.length }}/4

            </span>

            <span>
              Player 2
            </span>

          </div>


          <div class="status-line">

            <span class="hp-value">

              HP

              {{ displayPlayer2Hp }}

              /

              {{ displayPlayer2MaxHp }}

            </span>


            <div class="hp-track">

              <div
                class="hp-fill hp-red"

                :style="{
                  width:
                    `${displayPlayer2HpPercent}%`
                }"
              />

            </div>

          </div>


          <div class="skill-status">

            <div class="skill-status-label">

              <span>
                ULTIMATE
              </span>

              <span>

                {{
                  player2UltimateUsed
                    ? 'USED'
                    : `${displayPlayer2Skill}%`
                }}

              </span>

            </div>


            <div class="skill-track">

              <div
                class="skill-fill skill-red"

                :class="{
                  'skill-ready':
                    player2CanUltimate
                }"

                :style="{
                  width:
                    `${
                      player2UltimateUsed
                        ? 0
                        : displayPlayer2Skill
                    }%`
                }"
              />

            </div>

          </div>


          <div class="status-badges right">

            <span
              v-if="
                player2Defending
              "
              class="status-chip red-chip"
            >
              🛡 Defense
            </span>


            <span
              v-if="
                player2SynergyShield >
                0
              "
              class="status-chip red-chip"
            >

              💧 Shield

              {{
                Math.round(
                  player2SynergyShield *
                  100
                )
              }}%

            </span>


            <span
              v-if="
                player2AttackDebuff >
                0
              "
              class="status-chip debuff-chip"
            >

              ❄️ ATK -

              {{
                Math.round(
                  player2AttackDebuff *
                  100
                )
              }}%

            </span>

          </div>

        </div>


        <div
          class="player-avatar avatar-red"
        >
          🧑🏽‍🦱
        </div>

      </section>

    </header>


    <!-- =====================================================
         ARENA
    ====================================================== -->

    <main class="arena">

      <div class="center-line" />

      <div class="center-orb">
        ◆
      </div>


      <!-- ===================================================
           PLAYER 1 FIELD
      ==================================================== -->

      <section class="field field-blue">

        <div
          class="field-background bg-blue-arena"
        />

        <div
          class="giant-symbol giant-blue"
        />


        <div class="field-layout">


          <!-- =================================================
               P1 ACTIVE
          ================================================== -->

          <div class="field-section">

            <div class="section-title blue-title">

              ACTIVE DECK

              <span
                v-if="
                  swapMode &&
                  displayCurrentTurn === 'p1'
                "
                class="swap-help"
              >
                CLICK CARD TO SWAP
              </span>

            </div>


            <div class="pokemon-row">

              <div
                v-for="slot in 4"

                :key="
                  `p1-active-${slot}`
                "

                class="
                  pokemon-slot
                  pokemon-slot-blue
                "
              >

                <template
                  v-if="
                    displayPlayer1ActiveCards[
                      slot - 1
                    ]
                  "
                >

                  <div
                    class="pokemon-card pokemon-card-blue"

                    :class="{
                      selected:
                        selectedBattleCard?.battleId ===
                        displayPlayer1ActiveCards[
                          slot - 1
                        ].battleId,

                      'swap-target':
                        swapMode &&
                        displayCurrentTurn === 'p1'
                    }"

                    @click="
                      handleActiveCardClick(
                        'p1',

                        displayPlayer1ActiveCards[
                          slot - 1
                        ]
                      )
                    "
                  >

                    <img
                      v-if="
                        isImageUrl(
                          displayPlayer1ActiveCards[
                            slot - 1
                          ].image_url
                        )
                      "

                      :src="
                        displayPlayer1ActiveCards[
                          slot - 1
                        ].image_url
                      "
                    >


                    <div
                      class="pokemon-card-overlay"
                    />


                    <div class="pokemon-card-info">

                      <div class="card-top">

                        <span class="card-name">

                          {{
                            displayPlayer1ActiveCards[
                              slot - 1
                            ].name
                          }}

                        </span>


                        <span class="element-pill">

                          {{
                            normalizeElement(
                              displayPlayer1ActiveCards[
                                slot - 1
                              ].element
                            ) || '?'
                          }}

                        </span>

                      </div>


                      <div class="card-hp">

                        CARD HP

                        {{
                          displayPlayer1ActiveCards[
                            slot - 1
                          ].hp
                        }}

                      </div>


                      <div class="card-attack">

                        ATTACK

                        <strong>

                          {{
                            displayPlayer1ActiveCards[
                              slot - 1
                            ].attack
                          }}

                        </strong>

                      </div>


                      <button
                        v-if="
                          displayCurrentTurn === 'p1'
                          &&
                          displayBattleState === 'battle_ready'
                          &&
                          !displayWinner
                          &&
                          !selectedTurnAction
                          &&
                          !isActing
                          &&
                          !summonMode
                          &&
                          !swapMode
                        "

                        class="move-bench-button"

                        @click.stop="
                          moveToBench(
                            'p1',

                            displayPlayer1ActiveCards[
                              slot - 1
                            ]
                          )
                        "
                      >

                        ↓ MOVE TO BENCH

                      </button>

                    </div>


                    <div
                      v-if="
                        selectedBattleCard?.battleId ===
                        displayPlayer1ActiveCards[
                          slot - 1
                        ].battleId
                      "
                      class="selected-card-label"
                    >
                      SELECTED
                    </div>


                    <div
                      v-if="
                        swapMode &&
                        displayCurrentTurn === 'p1'
                      "
                      class="swap-target-label"
                    >
                      SWAP WITH THIS
                    </div>

                  </div>

                </template>


                <template v-else>

                  <div class="empty-slot">

                    <div class="pokeball-symbol">
                      ◉
                    </div>

                    Pokémon {{ slot }}

                  </div>

                </template>

              </div>

            </div>

          </div>


          <!-- =================================================
               P1 BENCH
          ================================================== -->

          <div class="field-section">

            <div class="section-title blue-title">
              BENCH
            </div>


            <div class="bench-row">

              <div
                v-for="slot in 4"

                :key="
                  `p1-bench-${slot}`
                "

                class="
                  bench-slot
                  pokemon-slot-blue
                "
              >

                <template
                  v-if="
                    displayPlayer1BenchCards[
                      slot - 1
                    ]
                  "
                >

                  <div
                    class="bench-card"

                    :class="{
                      exhausted:
                        displayPlayer1BenchCards[
                          slot - 1
                        ].exhausted,

                      'swap-selected':
                        selectedBenchCard?.battleId ===
                        displayPlayer1BenchCards[
                          slot - 1
                        ].battleId
                    }"
                  >

                    <img
                      v-if="
                        isImageUrl(
                          displayPlayer1BenchCards[
                            slot - 1
                          ].image_url
                        )
                      "

                      :src="
                        displayPlayer1BenchCards[
                          slot - 1
                        ].image_url
                      "
                    >


                    <div class="bench-overlay" />


                    <div class="bench-info">

                      <strong>

                        {{
                          displayPlayer1BenchCards[
                            slot - 1
                          ].name
                        }}

                      </strong>


                      <span>

                        {{
                          normalizeElement(
                            displayPlayer1BenchCards[
                              slot - 1
                            ].element
                          ) || '?'
                        }}

                      </span>


                      <!-- EXHAUSTED -->

                      <div
                        v-if="
                          displayPlayer1BenchCards[
                            slot - 1
                          ].exhausted
                        "
                        class="exhausted-label"
                      >

                        ☠ UNUSABLE

                      </div>


                      <!-- RETURN / SWAP -->

                      <button
                        v-else-if="
                          displayCurrentTurn === 'p1'
                          &&
                          displayBattleState === 'battle_ready'
                          &&
                          !selectedTurnAction
                          &&
                          !isActing
                          &&
                          !summonMode
                        "

                        class="return-button"

                        @click="
                          returnFromBench(
                            'p1',

                            displayPlayer1BenchCards[
                              slot - 1
                            ]
                          )
                        "
                      >

                        {{
                          displayPlayer1ActiveCards.length <
                          4
                            ? '↥ RETURN'
                            : '⇄ SWAP'
                        }}

                      </button>


                      <div
                        v-if="
                          !displayPlayer1BenchCards[
                            slot - 1
                          ].exhausted
                        "
                        class="return-counter"
                      >

                        Return:

                        {{
                          displayPlayer1BenchCards[
                            slot - 1
                          ].benchReturnCount
                        }}/1

                      </div>

                    </div>


                    <div
                      v-if="
                        displayPlayer1BenchCards[
                          slot - 1
                        ].exhausted
                      "
                      class="exhausted-overlay"
                    >

                      <div>
                        ☠
                      </div>

                      <strong>
                        EXHAUSTED
                      </strong>

                      <small>
                        Cannot return
                      </small>

                    </div>

                  </div>

                </template>


                <template v-else>

                  <div class="empty-slot">

                    <div class="small-ball">
                      ◉
                    </div>

                    Bench {{ slot }}

                  </div>

                </template>

              </div>

            </div>

          </div>

        </div>

      </section>


      <!-- ===================================================
           PLAYER 2 FIELD
      ==================================================== -->

      <section class="field field-red">

        <div
          class="field-background bg-red-arena"
        />

        <div
          class="giant-symbol giant-red"
        />


        <div class="field-layout">


          <!-- P2 ACTIVE -->

          <div class="field-section">

            <div class="section-title red-title">

              ACTIVE DECK

              <span
                v-if="
                  swapMode &&
                  displayCurrentTurn === 'p2'
                "
                class="swap-help"
              >
                CLICK CARD TO SWAP
              </span>

            </div>


            <div class="pokemon-row">

              <div
                v-for="slot in 4"

                :key="
                  `p2-active-${slot}`
                "

                class="
                  pokemon-slot
                  pokemon-slot-red
                "
              >

                <template
                  v-if="
                    displayPlayer2ActiveCards[
                      slot - 1
                    ]
                  "
                >

                  <div
                    class="pokemon-card pokemon-card-red"

                    :class="{
                      selected:
                        selectedBattleCard?.battleId ===
                        displayPlayer2ActiveCards[
                          slot - 1
                        ].battleId,

                      'swap-target':
                        swapMode &&
                        displayCurrentTurn === 'p2'
                    }"

                    @click="
                      handleActiveCardClick(
                        'p2',

                        displayPlayer2ActiveCards[
                          slot - 1
                        ]
                      )
                    "
                  >

                    <img
                      v-if="
                        isImageUrl(
                          displayPlayer2ActiveCards[
                            slot - 1
                          ].image_url
                        )
                      "

                      :src="
                        displayPlayer2ActiveCards[
                          slot - 1
                        ].image_url
                      "
                    >


                    <div class="pokemon-card-overlay" />


                    <div class="pokemon-card-info">

                      <div class="card-top">

                        <span class="card-name">

                          {{
                            displayPlayer2ActiveCards[
                              slot - 1
                            ].name
                          }}

                        </span>


                        <span class="element-pill">

                          {{
                            normalizeElement(
                              displayPlayer2ActiveCards[
                                slot - 1
                              ].element
                            ) || '?'
                          }}

                        </span>

                      </div>


                      <div class="card-hp">

                        CARD HP

                        {{
                          displayPlayer2ActiveCards[
                            slot - 1
                          ].hp
                        }}

                      </div>


                      <div class="card-attack">

                        ATTACK

                        <strong>

                          {{
                            displayPlayer2ActiveCards[
                              slot - 1
                            ].attack
                          }}

                        </strong>

                      </div>


                      <button
                        v-if="
                          displayCurrentTurn === 'p2'
                          &&
                          displayBattleState === 'battle_ready'
                          &&
                          !displayWinner
                          &&
                          !selectedTurnAction
                          &&
                          !isActing
                          &&
                          !summonMode
                          &&
                          !swapMode
                        "

                        class="move-bench-button"

                        @click.stop="
                          moveToBench(
                            'p2',

                            displayPlayer2ActiveCards[
                              slot - 1
                            ]
                          )
                        "
                      >

                        ↓ MOVE TO BENCH

                      </button>

                    </div>


                    <div
                      v-if="
                        selectedBattleCard?.battleId ===
                        displayPlayer2ActiveCards[
                          slot - 1
                        ].battleId
                      "
                      class="selected-card-label"
                    >
                      SELECTED
                    </div>


                    <div
                      v-if="
                        swapMode &&
                        displayCurrentTurn === 'p2'
                      "
                      class="swap-target-label"
                    >
                      SWAP WITH THIS
                    </div>

                  </div>

                </template>


                <template v-else>

                  <div class="empty-slot">

                    <div class="pokeball-symbol">
                      ◉
                    </div>

                    Pokémon {{ slot }}

                  </div>

                </template>

              </div>

            </div>

          </div>


          <!-- P2 BENCH -->

          <div class="field-section">

            <div class="section-title red-title">
              BENCH
            </div>


            <div class="bench-row">

              <div
                v-for="slot in 4"

                :key="
                  `p2-bench-${slot}`
                "

                class="
                  bench-slot
                  pokemon-slot-red
                "
              >

                <template
                  v-if="
                    displayPlayer2BenchCards[
                      slot - 1
                    ]
                  "
                >

                  <div
                    class="bench-card"

                    :class="{
                      exhausted:
                        displayPlayer2BenchCards[
                          slot - 1
                        ].exhausted,

                      'swap-selected':
                        selectedBenchCard?.battleId ===
                        displayPlayer2BenchCards[
                          slot - 1
                        ].battleId
                    }"
                  >

                    <img
                      v-if="
                        isImageUrl(
                          displayPlayer2BenchCards[
                            slot - 1
                          ].image_url
                        )
                      "

                      :src="
                        displayPlayer2BenchCards[
                          slot - 1
                        ].image_url
                      "
                    >


                    <div class="bench-overlay" />


                    <div class="bench-info">

                      <strong>

                        {{
                          displayPlayer2BenchCards[
                            slot - 1
                          ].name
                        }}

                      </strong>


                      <span>

                        {{
                          normalizeElement(
                            displayPlayer2BenchCards[
                              slot - 1
                            ].element
                          ) || '?'
                        }}

                      </span>


                      <div
                        v-if="
                          displayPlayer2BenchCards[
                            slot - 1
                          ].exhausted
                        "
                        class="exhausted-label"
                      >

                        ☠ UNUSABLE

                      </div>


                      <button
                        v-else-if="
                          displayCurrentTurn === 'p2'
                          &&
                          displayBattleState === 'battle_ready'
                          &&
                          !selectedTurnAction
                          &&
                          !isActing
                          &&
                          !summonMode
                        "

                        class="return-button"

                        @click="
                          returnFromBench(
                            'p2',

                            displayPlayer2BenchCards[
                              slot - 1
                            ]
                          )
                        "
                      >

                        {{
                          displayPlayer2ActiveCards.length <
                          4
                            ? '↥ RETURN'
                            : '⇄ SWAP'
                        }}

                      </button>


                      <div
                        v-if="
                          !displayPlayer2BenchCards[
                            slot - 1
                          ].exhausted
                        "
                        class="return-counter"
                      >

                        Return:

                        {{
                          displayPlayer2BenchCards[
                            slot - 1
                          ].benchReturnCount
                        }}/1

                      </div>

                    </div>


                    <div
                      v-if="
                        displayPlayer2BenchCards[
                          slot - 1
                        ].exhausted
                      "
                      class="exhausted-overlay"
                    >

                      <div>
                        ☠
                      </div>

                      <strong>
                        EXHAUSTED
                      </strong>

                      <small>
                        Cannot return
                      </small>

                    </div>

                  </div>

                </template>


                <template v-else>

                  <div class="empty-slot">

                    <div class="small-ball">
                      ◉
                    </div>

                    Bench {{ slot }}

                  </div>

                </template>

              </div>

            </div>

          </div>

        </div>

      </section>


      <!-- ===================================================
           WINNER
      ==================================================== -->

      <Transition name="displayWinner">

        <div
          v-if="displayWinner"
          class="displayWinner-overlay"
        >

          <div class="displayWinner-panel">

            <span>
              BATTLE FINISHED
            </span>

            <h2>

              {{
                displayWinner === 'p1'
                  ? 'PLAYER 1'
                  : 'PLAYER 2'
              }}

            </h2>

            <h1>
              WINS!
            </h1>

            <button
              @click="
                resetArena
              "
            >
              PLAY AGAIN
            </button>

          </div>

        </div>

      </Transition>

    </main>


    <!-- =====================================================
         FOOTER
    ====================================================== -->

    <footer v-if="!isDisplayOnly" class="battle-footer">


      <!-- ===================================================
           PLAYER 1 SKILLS
      ==================================================== -->

      <div
        class="action-side"

        :class="{
          active:
            displayCurrentTurn === 'p1'
            &&
            displayBattleState === 'battle_ready'
        }"
      >

        <div class="action-header">

          <span>
            PLAYER 1
          </span>


          <strong
            v-if="
              displayCurrentTurn === 'p1'
              &&
              !selectedBattleCard
            "
          >
            SELECT ACTIVE CARD
          </strong>


          <strong
            v-else-if="
              displayCurrentTurn === 'p1'
              &&
              selectedBattleCard
            "
          >
            {{ selectedBattleCard.name }}
          </strong>

        </div>


        <div class="skill-hand">

          <button
            v-for="
              skill in player1Hand
            "

            :key="
              skill.id
            "

            class="skill-card"

            :class="[
              skill.className,

              {
                disabled:
                  !canUseSkill(
                    'p1',
                    skill
                  ),

                selected:
                  selectedSkill?.id ===
                  skill.id,

                used:
                  (
                    skill.type ===
                      'ultimate'
                    &&
                    player1UltimateUsed
                  )
                  ||
                  (
                    skill.type ===
                      'heal'
                    &&
                    player1HealUsed
                  ),

                ready:
                  skill.type ===
                    'ultimate'
                  &&
                  player1CanUltimate
              }
            ]"

            :disabled="
              !canUseSkill(
                'p1',
                skill
              )
            "

            @click="
              playSkill(
                'p1',
                skill
              )
            "
          >

            <div class="skill-title">
              {{ skill.name }}
            </div>


            <div class="skill-icon">
              {{ skill.icon }}
            </div>


            <div class="skill-detail">


              <template
                v-if="
                  skill.type ===
                  'attack'
                "
              >

                ATK

                {{
                  selectedBattleCard
                    ?.attack || 0
                }}

                <br>

                Unlimited

              </template>


              <template
                v-else-if="
                  skill.type ===
                  'defense'
                "
              >

                Next DMG -50%

                <br>

                Unlimited

              </template>


              <template
                v-else-if="
                  skill.type ===
                  'ultimate'
                "
              >

                <span
                  v-if="
                    player1UltimateUsed
                  "
                >
                  USED
                </span>


                <span
                  v-else-if="
                    player1CanUltimate
                  "
                >

                  READY!

                  <br>

                  ATK ×2

                </span>


                <span v-else>

                  {{ displayPlayer1Skill }}/100

                </span>

              </template>


              <template v-else>

                <span
                  v-if="
                    player1HealUsed
                  "
                >
                  USED
                </span>


                <span
                  v-else-if="
                    player1CanHeal
                  "
                >

                  READY!

                  <br>

                  HEAL 35%

                </span>


                <span v-else>

                  HP ≤ 50%

                </span>

              </template>

            </div>

          </button>

        </div>


        <!-- SYNERGY -->

        <button
          class="synergy-button"

          :class="{
            ready:
              displayCurrentTurn === 'p1'
              &&
              selectedSynergyInfo?.canUse,

            used:
              displayCurrentTurn === 'p1'
              &&
              selectedSynergyInfo?.used
          }"

          :disabled="
            displayCurrentTurn !== 'p1'
            ||
            !selectedSynergyInfo?.canUse
            ||
            !!selectedTurnAction
            ||
            isActing
            ||
            swapMode
          "

          @click="
            playSynergy('p1')
          "
        >

          <template
            v-if="
              displayCurrentTurn === 'p1'
              &&
              selectedSynergyInfo
            "
          >

            <span class="synergy-icon">

              {{
                selectedSynergyInfo.icon
              }}

            </span>


            <span>

              {{
                selectedSynergyInfo.name
              }}

            </span>


            <strong>

              {{
                selectedSynergyInfo.points
              }}x

              {{
                selectedSynergyInfo.element
              }}

            </strong>


            <small>

              {{
                selectedSynergyInfo.used
                  ? 'USED'
                  : selectedSynergyInfo.canUse
                    ? 'READY'
                    : 'NEED 2 SAME ELEMENT'
              }}

            </small>

          </template>


          <template v-else>
            SYNERGY
          </template>

        </button>

      </div>


      <!-- ===================================================
           CENTER CONTROL
      ==================================================== -->

      <div class="turn-action-panel">


        <!-- INITIAL RFID -->

        <template
          v-if="
            displayBattleState !==
            'battle_ready'
          "
        >

          <div class="scanner-symbol">
            📡
          </div>

          <strong>
            SCAN RFID
          </strong>

          <small>
            {{ displayTurnText }}
          </small>

        </template>


        <!-- SWAP -->

        <template
          v-else-if="
            swapMode
            &&
            !displayWinner
          "
        >

          <div class="swap-main-icon">
            ⇄
          </div>

          <strong>
            SELECT ACTIVE CARD
          </strong>

          <small>

            {{
              selectedBenchCard?.name
            }}

            will replace it

          </small>


          <button
            class="cancel-summon"

            @click="
              cancelSwap
            "
          >
            CANCEL SWAP
          </button>

        </template>


        <!-- SUMMON -->

        <template
          v-else-if="
            summonMode
            &&
            !displayWinner
          "
        >

          <div
            class="
              scanner-symbol
              scanner-active
            "
          >
            📡
          </div>


          <strong>
            SCAN CARD NOW
          </strong>


          <small>
            Summon consumes this turn
          </small>


          <button
            class="cancel-summon"

            @click="
              cancelSummon
            "
          >
            CANCEL
          </button>

        </template>


        <!-- NORMAL TURN -->

        <template
          v-else-if="
            !displayWinner
          "
        >

          <div
            class="turn-badge"

            :class="
              displayCurrentTurn === 'p1'
                ? 'turn-blue'
                : 'turn-red'
            "
          >

            {{
              displayCurrentTurn === 'p1'
                ? 'P1'
                : 'P2'
            }}

          </div>


          <strong>
            CHOOSE 1 ACTION
          </strong>

          <div class="round-indicator">
            ROUND {{ displayRound }}
            <span>• QUESTION EVERY {{ QUESTION_INTERVAL_ROUNDS }}</span>
          </div>

          <small>
            Move / Return / Swap is free
          </small>


          <small>
            Then Skill / Synergy / Summon
          </small>


          <button
            class="summon-button"

            :class="
              displayCurrentTurn === 'p1'
                ? 'summon-blue'
                : 'summon-red'
            "

            :disabled="
              !!selectedTurnAction
              ||
              (
                displayCurrentTurn === 'p1'
                  ? !player1CanSummon
                  : !player2CanSummon
              )
            "

            @click="
              chooseSummon(
                displayCurrentTurn
              )
            "
          >

            ✨ SUMMON

            <span>

              {{
                displayCurrentTurn === 'p1'
                  ? `${displayPlayer1ActiveCards.length}/4`
                  : `${displayPlayer2ActiveCards.length}/4`
              }}

            </span>

          </button>

        </template>

      </div>


      <!-- ===================================================
           PLAYER 2 SKILLS
      ==================================================== -->

      <div
        class="action-side"

        :class="{
          active:
            displayCurrentTurn === 'p2'
            &&
            displayBattleState === 'battle_ready'
        }"
      >

        <div class="action-header">

          <span>
            PLAYER 2
          </span>


          <strong
            v-if="
              displayCurrentTurn === 'p2'
              &&
              !selectedBattleCard
            "
          >
            SELECT ACTIVE CARD
          </strong>


          <strong
            v-else-if="
              displayCurrentTurn === 'p2'
              &&
              selectedBattleCard
            "
          >
            {{ selectedBattleCard.name }}
          </strong>

        </div>


        <div class="skill-hand">

          <button
            v-for="
              skill in player2Hand
            "

            :key="
              skill.id
            "

            class="skill-card"

            :class="[
              skill.className,

              {
                disabled:
                  !canUseSkill(
                    'p2',
                    skill
                  ),

                selected:
                  selectedSkill?.id ===
                  skill.id,

                used:
                  (
                    skill.type ===
                      'ultimate'
                    &&
                    player2UltimateUsed
                  )
                  ||
                  (
                    skill.type ===
                      'heal'
                    &&
                    player2HealUsed
                  ),

                ready:
                  skill.type ===
                    'ultimate'
                  &&
                  player2CanUltimate
              }
            ]"

            :disabled="
              !canUseSkill(
                'p2',
                skill
              )
            "

            @click="
              playSkill(
                'p2',
                skill
              )
            "
          >

            <div class="skill-title">
              {{ skill.name }}
            </div>


            <div class="skill-icon">
              {{ skill.icon }}
            </div>


            <div class="skill-detail">

              <template
                v-if="
                  skill.type ===
                  'attack'
                "
              >

                ATK

                {{
                  selectedBattleCard
                    ?.attack || 0
                }}

                <br>

                Unlimited

              </template>


              <template
                v-else-if="
                  skill.type ===
                  'defense'
                "
              >

                Next DMG -50%

                <br>

                Unlimited

              </template>


              <template
                v-else-if="
                  skill.type ===
                  'ultimate'
                "
              >

                <span
                  v-if="
                    player2UltimateUsed
                  "
                >
                  USED
                </span>


                <span
                  v-else-if="
                    player2CanUltimate
                  "
                >

                  READY!

                  <br>

                  ATK ×2

                </span>


                <span v-else>

                  {{ displayPlayer2Skill }}/100

                </span>

              </template>


              <template v-else>

                <span
                  v-if="
                    player2HealUsed
                  "
                >
                  USED
                </span>


                <span
                  v-else-if="
                    player2CanHeal
                  "
                >

                  READY!

                  <br>

                  HEAL 35%

                </span>


                <span v-else>

                  HP ≤ 50%

                </span>

              </template>

            </div>

          </button>

        </div>


        <!-- P2 SYNERGY -->

        <button
          class="synergy-button"

          :class="{
            ready:
              displayCurrentTurn === 'p2'
              &&
              selectedSynergyInfo?.canUse,

            used:
              displayCurrentTurn === 'p2'
              &&
              selectedSynergyInfo?.used
          }"

          :disabled="
            displayCurrentTurn !== 'p2'
            ||
            !selectedSynergyInfo?.canUse
            ||
            !!selectedTurnAction
            ||
            isActing
            ||
            swapMode
          "

          @click="
            playSynergy('p2')
          "
        >

          <template
            v-if="
              displayCurrentTurn === 'p2'
              &&
              selectedSynergyInfo
            "
          >

            <span class="synergy-icon">

              {{
                selectedSynergyInfo.icon
              }}

            </span>


            <span>

              {{
                selectedSynergyInfo.name
              }}

            </span>


            <strong>

              {{
                selectedSynergyInfo.points
              }}x

              {{
                selectedSynergyInfo.element
              }}

            </strong>


            <small>

              {{
                selectedSynergyInfo.used
                  ? 'USED'
                  : selectedSynergyInfo.canUse
                    ? 'READY'
                    : 'NEED 2 SAME ELEMENT'
              }}

            </small>

          </template>


          <template v-else>
            SYNERGY
          </template>

        </button>

      </div>

    </footer>


    <!-- =====================================================
         CODING QUESTION BREAK
    ====================================================== -->

    <Transition name="question">
      <div
        v-if="questionMode"
        class="question-overlay"
      >
        <section class="question-panel">
          <div class="question-kicker">
            🧠 CODING CHALLENGE • ROUND {{ displayRound }}
          </div>

          <h2>QUESTION BREAK</h2>

          <div
            v-if="questionLoading"
            class="question-loading"
          >
            Loading question from database...
          </div>

          <div
            v-else-if="questionError"
            class="question-error"
          >
            <strong>Question unavailable</strong>
            <span>{{ questionError }}</span>
            <button @click="continueAfterQuestion">CONTINUE BATTLE</button>
          </div>

          <template v-else-if="currentQuestion">
            <p class="question-text">
              {{ currentQuestion.question }}
            </p>

            <div class="question-options">
              <button
                v-for="(option, index) in currentQuestion.options"
                :key="`${currentQuestion.id}-${index}`"
                class="question-option"
                :class="{
                  selected: selectedQuestionAnswer === index,
                  correct: questionResult && index === currentQuestion.correctIndex,
                  wrong: questionResult === 'wrong' && selectedQuestionAnswer === index
                }"
                :disabled="!!questionResult"
                @click="answerCodingQuestion(index)"
              >
                <span class="option-letter">{{ String.fromCharCode(65 + index) }}</span>
                <span>{{ option }}</span>
              </button>
            </div>

            <div
              v-if="questionResult"
              class="question-result"
              :class="questionResult"
            >
              <strong>
                {{ questionResult === 'correct' ? '✅ CORRECT!' : '❌ WRONG!' }}
              </strong>

              <p v-if="currentQuestion.explanation">
                {{ currentQuestion.explanation }}
              </p>

              <button @click="continueAfterQuestion">
                CONTINUE BATTLE
              </button>
            </div>
          </template>
        </section>
      </div>
    </Transition>


    <!-- =====================================================
         WINNER
    ====================================================== -->

    <Transition name="displayWinner">

      <div
        v-if="
          displayWinner
        "
        class="displayWinner-overlay"
      >

        <div class="displayWinner-panel">

          <span>
            BATTLE FINISHED
          </span>

          <h2>

            {{
              displayWinner === 'p1'
                ? 'PLAYER 1'
                : 'PLAYER 2'
            }}

          </h2>

          <h1>
            WINS!
          </h1>

          <button
            @click="
              resetArena
            "
          >
            PLAY AGAIN
          </button>

        </div>

      </div>

    </Transition>

  </div>

</template>


<style scoped>

/* =========================================================
   GENERAL
========================================================= */

* {
  box-sizing: border-box;
}

button {
  font: inherit;
}

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

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;

  background:
    #020713;

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

  background:
    linear-gradient(
      180deg,
      #071227,
      #030a18
    );

  box-shadow:
    0 10px 35px
    rgba(0,0,0,.75);

}


.player-hud {

  display: flex;

  align-items: center;

  gap: 15px;

  padding:
    13px
    25px;

  position: relative;

  overflow: visible;

}


.hud-blue {

  border-bottom:
    3px solid
    #159dff;

  background:
    linear-gradient(
      90deg,
      rgba(0,124,255,.23),
      transparent
    );

}


.hud-red {

  justify-content:
    flex-end;

  border-bottom:
    3px solid
    #ff3156;

  background:
    linear-gradient(
      270deg,
      rgba(255,23,66,.22),
      transparent
    );

}


.hud-current-blue {

  box-shadow:
    inset 0 0 35px
    rgba(0,178,255,.18);

}


.hud-current-red {

  box-shadow:
    inset 0 0 35px
    rgba(255,24,60,.18);

}


/* =========================================================
   AVATAR
========================================================= */

.player-avatar {

  width: 68px;

  height: 68px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border-radius: 50%;

  font-size: 34px;

  background:
    #101a30;

}


.avatar-blue {

  border:
    4px solid
    #20c7ff;

  box-shadow:
    0 0 22px
    rgba(0,180,255,.75);

}


.avatar-red {

  border:
    4px solid
    #ff3d60;

  box-shadow:
    0 0 22px
    rgba(255,30,70,.7);

}


/* =========================================================
   PLAYER STATUS
========================================================= */

.player-status {

  width: 100%;

  max-width: 500px;

}


.player-status-right {

  text-align: right;

}


.player-name {

  display: flex;

  justify-content:
    space-between;

  margin-bottom: 6px;

  font-size: 15px;

  font-weight: 900;

}


.pokemon-count {

  color:
    #9fb1ca;

  font-size: 8px;

  font-weight: 700;

}


.status-line {

  display: flex;

  align-items: center;

  gap: 9px;

}


.hp-track {

  flex: 1;

  height: 17px;

  padding: 3px;

  overflow: hidden;

  border-radius:
    999px;

  border:
    1px solid
    rgba(255,255,255,.17);

  background:
    #060c19;

}


.hp-fill {

  height: 100%;

  border-radius:
    inherit;

  transition:
    width .55s ease;

}


.hp-blue {

  background:
    linear-gradient(
      90deg,
      #0784ff,
      #19e3ff
    );

  box-shadow:
    0 0 12px
    #00bfff;

}


.hp-red {

  margin-left:
    auto;

  background:
    linear-gradient(
      90deg,
      #ff3655,
      #ff003d
    );

  box-shadow:
    0 0 12px
    #ff204c;

}


.hp-value {

  min-width:
    115px;

  white-space:
    nowrap;

  font-size:
    10px;

  font-weight:
    900;

}


/* =========================================================
   ULTIMATE BAR
========================================================= */

.skill-status {

  margin-top: 6px;

}


.skill-status-label {

  display: flex;

  justify-content:
    space-between;

  margin-bottom: 3px;

  color:
    #aebbd0;

  font-size:
    7px;

  font-weight:
    900;

  letter-spacing:
    .12em;

}


.skill-track {

  height: 6px;

  overflow: hidden;

  border-radius:
    999px;

  background:
    rgba(255,255,255,.12);

}


.skill-fill {

  height: 100%;

  border-radius:
    inherit;

  transition:
    width .45s ease;

}


.skill-blue {

  background:
    linear-gradient(
      90deg,
      #238aff,
      #35e2ff
    );

}


.skill-red {

  margin-left:
    auto;

  background:
    linear-gradient(
      90deg,
      #ff3654,
      #ff993c
    );

}


.skill-ready {

  background:
    linear-gradient(
      90deg,
      #ffe146,
      #ff8800
    ) !important;

  box-shadow:
    0 0 12px
    rgba(255,210,30,.9);

  animation:
    gaugePulse
    .7s alternate infinite;

}


@keyframes gaugePulse {

  from {

    filter:
      brightness(1);

  }

  to {

    filter:
      brightness(1.8);

  }

}


/* =========================================================
   STATUS CHIPS
========================================================= */

.status-badges {

  min-height:
    16px;

  margin-top:
    5px;

  display:
    flex;

  gap:
    5px;

  flex-wrap:
    wrap;

}


.status-badges.right {

  justify-content:
    flex-end;

}


.status-chip {

  padding:
    2px 6px;

  border-radius:
    999px;

  font-size:
    6px;

  font-weight:
    900;

}


.blue-chip {

  color:
    #7fe6ff;

  border:
    1px solid
    rgba(65,211,255,.5);

  background:
    rgba(0,112,170,.25);

}


.red-chip {

  color:
    #ff9eb0;

  border:
    1px solid
    rgba(255,83,112,.5);

  background:
    rgba(161,11,47,.25);

}


.debuff-chip {

  color:
    #d9eeff;

  border:
    1px solid
    rgba(184,221,255,.5);

  background:
    rgba(94,133,170,.22);

}


/* =========================================================
   PROFILE EFFECT POPUP
========================================================= */

.profile-effect-popup {

  position: absolute;

  left: 50%;

  top: 12px;

  transform:
    translateX(-50%);

  z-index: 200;

  padding:
    5px 11px;

  border-radius:
    999px;

  font-size:
    19px;

  font-weight:
    1000;

  white-space:
    nowrap;

  pointer-events:
    none;

}


.profile-effect-popup.damage {

  color:
    #ffe44d;

  text-shadow:
    0 2px 0
    #9a0000,
    0 0 15px red;

}


.profile-effect-popup.heal {

  color:
    #57ff9d;

  text-shadow:
    0 0 15px
    #00b85c;

}


.profile-effect-popup.defense {

  color:
    #71e5ff;

  text-shadow:
    0 0 15px
    #009bd2;

}


.profile-effect-popup.summon {

  color:
    #ffe75e;

  text-shadow:
    0 0 15px
    #e4a800;

}


.profile-effect-popup.ultimate {

  color:
    #ffce44;

  text-shadow:
    0 0 18px
    #ff4d00;

}


.profile-effect-popup.synergy {

  color:
    white;

  text-shadow:
    0 0 15px
    #39cfff;

}


.profile-effect-popup.info {

  color:
    white;

  text-shadow:
    0 0 14px
    #428cff;

}


/* DAMAGE */

.profile-damage {

  animation:
    profileDamage
    .55s ease;

}


@keyframes profileDamage {

  0% {

    transform:
      translateX(0);

    filter:
      brightness(1);

  }

  20% {

    transform:
      translateX(-9px);

    filter:
      brightness(2.5);

  }

  40% {

    transform:
      translateX(10px);

  }

  60% {

    transform:
      translateX(-6px);

  }

  80% {

    transform:
      translateX(4px);

  }

  100% {

    transform:
      translateX(0);

    filter:
      brightness(1);

  }

}


/* HEAL */

.profile-heal {

  animation:
    profileHeal
    .8s ease;

}


@keyframes profileHeal {

  50% {

    box-shadow:
      inset 0 0 45px
      rgba(40,255,130,.38);

    filter:
      brightness(1.5);

  }

}


/* DEFENSE */

.profile-defense {

  animation:
    profileDefense
    .8s ease;

}


@keyframes profileDefense {

  50% {

    box-shadow:
      inset 0 0 50px
      rgba(50,210,255,.45);

  }

}


/* SUMMON */

.profile-summon {

  animation:
    profileSummon
    .8s ease;

}


@keyframes profileSummon {

  40% {

    filter:
      brightness(2);

  }

}


/* ULTIMATE */

.profile-ultimate {

  animation:
    profileUltimate
    .8s ease;

}


@keyframes profileUltimate {

  40% {

    filter:
      brightness(2.3);

  }

}


/* SYNERGY */

.profile-synergy {

  animation:
    profileSynergy
    .85s ease;

}


@keyframes profileSynergy {

  50% {

    filter:
      brightness(1.8);

  }

}


.profile-popup-enter-active {

  animation:
    profilePopup
    .75s ease-out;

}


.profile-popup-leave-active {

  opacity:
    0;

}


@keyframes profilePopup {

  0% {

    opacity:
      0;

    transform:
      translate(-50%,15px)
      scale(.5);

  }

  30% {

    opacity:
      1;

    transform:
      translate(-50%,-5px)
      scale(1.25);

  }

  100% {

    opacity:
      0;

    transform:
      translate(-50%,-35px)
      scale(1);

  }

}


/* =========================================================
   CENTER HEADER
========================================================= */

.center-header {

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

}


.game-logo {

  text-align:
    center;

  line-height:
    .95;

}


.game-logo strong {

  display:
    block;

  font-size:
    27px;

  letter-spacing:
    .2em;

  background:
    linear-gradient(
      #fff,
      #9fc9ff
    );

  -webkit-background-clip:
    text;

  color:
    transparent;

}


.logo-mini {

  display:
    block;

  color:
    #ffd943;

  font-size:
    7px;

  font-weight:
    900;

  letter-spacing:
    .3em;

}


.logo-bottom {

  display:
    block;

  margin-top:
    5px;

  color:
    #92beef;

  font-size:
    8px;

  font-weight:
    800;

  letter-spacing:
    .35em;

}


.turn-indicator {

  min-width:
    200px;

  margin-top:
    11px;

  padding:
    6px 14px;

  text-align:
    center;

  border-radius:
    999px;

  border:
    1px solid
    #3a77ac;

  background:
    #071934;

  font-size:
    8px;

  font-weight:
    1000;

}


.turn-indicator.blue {

  color:
    #63ddff;

}


.turn-indicator.red {

  color:
    #ff8196;

}


/* =========================================================
   ARENA
========================================================= */

.arena {

  flex:
    1;

  min-height:
    0;

  display:
    flex;

  position:
    relative;

  overflow:
    hidden;

}


.field {

  width:
    50%;

  height:
    100%;

  position:
    relative;

  overflow:
    hidden;

}


.field-background {

  position:
    absolute;

  inset:
    0;

  background-position:
    center;

  background-size:
    cover;

}


.bg-blue-arena {

  background-image:
    linear-gradient(
      rgba(0,103,174,.24),
      rgba(0,42,88,.42)
    ),
    url('/images/arena-blue.jpg');

  background-color:
    #0877a5;

}


.bg-red-arena {

  background-image:
    linear-gradient(
      rgba(143,0,26,.2),
      rgba(73,0,14,.48)
    ),
    url('/images/arena-red.jpg');

  background-color:
    #861529;

}


/* =========================================================
   GIANT SYMBOL
========================================================= */

.giant-symbol {

  width:
    270px;

  height:
    270px;

  position:
    absolute;

  left:
    50%;

  top:
    50%;

  transform:
    translate(-50%,-50%);

  opacity:
    .12;

  border-radius:
    50%;

  border:
    24px solid
    currentColor;

}


.giant-symbol::before {

  content:
    '';

  position:
    absolute;

  left:
    -24px;

  top:
    50%;

  width:
    calc(100% + 48px);

  height:
    24px;

  transform:
    translateY(-50%);

  background:
    currentColor;

}


.giant-symbol::after {

  content:
    '';

  width:
    85px;

  height:
    85px;

  position:
    absolute;

  left:
    50%;

  top:
    50%;

  transform:
    translate(-50%,-50%);

  border-radius:
    50%;

  border:
    18px solid
    currentColor;

}


.giant-blue {

  color:
    #a8ecff;

}


.giant-red {

  color:
    #ffb2c0;

}


/* =========================================================
   CENTER LINE
========================================================= */

.center-line {

  width:
    6px;

  position:
    absolute;

  left:
    50%;

  top:
    0;

  bottom:
    0;

  z-index:
    30;

  transform:
    translateX(-50%);

  background:
    linear-gradient(
      #30c8ff,
      white,
      #ff3d60
    );

  box-shadow:
    -8px 0 20px
    #009dff,
    8px 0 20px
    #ff244d;

}


.center-orb {

  width:
    70px;

  height:
    70px;

  position:
    absolute;

  left:
    50%;

  top:
    50%;

  z-index:
    35;

  transform:
    translate(-50%,-50%);

  display:
    grid;

  place-items:
    center;

  border-radius:
    50%;

  border:
    4px solid white;

  background:
    linear-gradient(
      90deg,
      #075cb6 50%,
      #b21131 50%
    );

  font-size:
    20px;

}


/* =========================================================
   FIELD LAYOUT
========================================================= */

.field-layout {

  height:
    100%;

  position:
    relative;

  z-index:
    5;

  padding:
    17px
    28px;

  display:
    flex;

  flex-direction:
    column;

  justify-content:
    space-around;

  gap:
    10px;

}


.field-section {

  display:
    flex;

  flex-direction:
    column;

  gap:
    6px;

}


.section-title {

  display:
    flex;

  justify-content:
    space-between;

  align-items:
    center;

  min-height:
    13px;

  font-size:
    7px;

  font-weight:
    1000;

  letter-spacing:
    .15em;

}


.blue-title {

  color:
    #9ce8ff;

}


.red-title {

  color:
    #ffabb9;

}


.swap-help {

  padding:
    3px 7px;

  border-radius:
    999px;

  color:
    #101520;

  background:
    #ffe65e;

  font-size:
    5px;

}


/* =========================================================
   ROWS
========================================================= */

.pokemon-row,
.bench-row {

  display:
    grid;

  grid-template-columns:
    repeat(4,1fr);

  gap:
    11px;

}


/* =========================================================
   SLOT
========================================================= */

.pokemon-slot,
.bench-slot {

  position:
    relative;

  justify-self:
    center;

  width:
    100%;

  max-width:
    114px;

  aspect-ratio:
    .73;

  border-radius:
    8px;

  overflow:
    visible;

}


.pokemon-slot-blue {

  border:
    3px solid
    #33d2ff;

  background:
    rgba(0,44,82,.56);

  box-shadow:
    0 0 15px
    rgba(0,190,255,.35);

}


.pokemon-slot-red {

  border:
    3px solid
    #ff4967;

  background:
    rgba(77,4,20,.58);

  box-shadow:
    0 0 15px
    rgba(255,34,65,.35);

}


.bench-slot {

  max-width:
    100px;

}


.empty-slot {

  width:
    100%;

  height:
    100%;

  display:
    flex;

  flex-direction:
    column;

  justify-content:
    center;

  align-items:
    center;

  gap:
    10px;

  color:
    rgba(255,255,255,.65);

  font-size:
    8px;

}


.pokeball-symbol {

  font-size:
    36px;

  opacity:
    .3;

}


.small-ball {

  font-size:
    28px;

  opacity:
    .3;

}


/* =========================================================
   ACTIVE CARD
========================================================= */

.pokemon-card {

  position:
    absolute;

  inset:
    4px;

  overflow:
    hidden;

  border-radius:
    6px;

  background:
    #101827;

  border:
    2px solid
    #ffe14f;

  cursor:
    pointer;

  z-index:
    6;

  transition:
    .2s ease;

}


.pokemon-card:hover {

  transform:
    translateY(-3px);

}


.pokemon-card.selected {

  border-color:
    white;

  transform:
    translateY(-4px)
    scale(1.035);

  box-shadow:
    0 0 23px
    white;

}


.pokemon-card.swap-target {

  border-color:
    #ffe552;

  animation:
    swapTargetPulse
    .65s alternate infinite;

}


@keyframes swapTargetPulse {

  from {

    box-shadow:
      0 0 8px
      #ffe552;

  }

  to {

    box-shadow:
      0 0 24px
      #ffe552;

  }

}


.pokemon-card-blue {

  box-shadow:
    0 0 18px
    rgba(0,202,255,.65);

}


.pokemon-card-red {

  box-shadow:
    0 0 18px
    rgba(255,44,71,.65);

}


.pokemon-card img {

  position:
    absolute;

  inset:
    0;

  width:
    100%;

  height:
    100%;

  object-fit:
    cover;

}


.pokemon-card-overlay {

  position:
    absolute;

  inset:
    0;

  background:
    linear-gradient(
      transparent 25%,
      rgba(0,0,0,.95)
    );

}


.pokemon-card-info {

  height:
    100%;

  position:
    relative;

  z-index:
    2;

  padding:
    7px;

  display:
    flex;

  flex-direction:
    column;

}


.card-top {

  display:
    flex;

  gap:
    3px;

}


.card-name {

  flex:
    1;

  min-width:
    0;

  overflow:
    hidden;

  white-space:
    nowrap;

  text-overflow:
    ellipsis;

  font-size:
    8px;

  font-weight:
    1000;

}


.element-pill {

  padding:
    2px 4px;

  border-radius:
    999px;

  background:
    rgba(0,0,0,.55);

  font-size:
    5px;

  text-transform:
    uppercase;

}


.card-hp {

  margin-top:
    3px;

  color:
    #ffe65d;

  font-size:
    6px;

  font-weight:
    900;

}


.card-attack {

  margin-top:
    auto;

  color:
    #bbc8dd;

  font-size:
    6px;

}


.card-attack strong {

  display:
    block;

  color:
    white;

  font-size:
    13px;

}


/* =========================================================
   MOVE BENCH BUTTON
========================================================= */

.move-bench-button {

  width:
    100%;

  margin-top:
    4px;

  padding:
    4px 2px;

  border:
    1px solid
    rgba(255,255,255,.3);

  border-radius:
    4px;

  background:
    rgba(2,9,20,.83);

  color:
    white;

  cursor:
    pointer;

  font-size:
    5px;

  font-weight:
    1000;

}


.move-bench-button:hover {

  border-color:
    #70ddff;

  background:
    rgba(15,100,158,.88);

}


/* =========================================================
   SELECTED LABEL
========================================================= */

.selected-card-label,
.swap-target-label {

  position:
    absolute;

  left:
    50%;

  transform:
    translateX(-50%);

  z-index:
    20;

  padding:
    2px 6px;

  border-radius:
    999px;

  font-size:
    5px;

  font-weight:
    1000;

  white-space:
    nowrap;

}


.selected-card-label {

  top:
    -9px;

  color:
    #07101e;

  background:
    white;

}


.swap-target-label {

  bottom:
    -9px;

  color:
    #171200;

  background:
    #ffe552;

}


/* =========================================================
   BENCH CARD
========================================================= */

.bench-card {

  position:
    absolute;

  inset:
    4px;

  overflow:
    hidden;

  border-radius:
    5px;

  background:
    #101827;

  transition:
    .2s ease;

}


.bench-card.swap-selected {

  border:
    2px solid
    #ffe34d;

  box-shadow:
    0 0 20px
    #ffe34d;

}


.bench-card img {

  position:
    absolute;

  inset:
    0;

  width:
    100%;

  height:
    100%;

  object-fit:
    cover;

}


.bench-overlay {

  position:
    absolute;

  inset:
    0;

  background:
    linear-gradient(
      transparent,
      rgba(0,0,0,.96)
    );

}


.bench-info {

  position:
    relative;

  z-index:
    2;

  height:
    100%;

  padding:
    6px;

  display:
    flex;

  flex-direction:
    column;

  justify-content:
    flex-end;

}


.bench-info strong {

  overflow:
    hidden;

  white-space:
    nowrap;

  text-overflow:
    ellipsis;

  font-size:
    7px;

}


.bench-info span {

  color:
    #ffe173;

  font-size:
    5px;

  text-transform:
    uppercase;

}


.return-button {

  margin-top:
    5px;

  padding:
    4px;

  border:
    none;

  border-radius:
    4px;

  background:
    #53d2ff;

  color:
    #04121e;

  cursor:
    pointer;

  font-size:
    6px;

  font-weight:
    1000;

}


.return-counter {

  margin-top:
    3px;

  color:
    rgba(255,255,255,.55);

  font-size:
    4.5px;

}


/* =========================================================
   EXHAUSTED
========================================================= */

.bench-card.exhausted {

  filter:
    grayscale(1)
    brightness(.45);

}


.exhausted-label {

  margin-top:
    4px;

  padding:
    4px;

  text-align:
    center;

  border-radius:
    4px;

  color:
    #ff9aa9;

  background:
    rgba(100,0,20,.7);

  font-size:
    5px;

  font-weight:
    1000;

}


.exhausted-overlay {

  position:
    absolute;

  inset:
    0;

  z-index:
    20;

  display:
    flex;

  flex-direction:
    column;

  align-items:
    center;

  justify-content:
    center;

  gap:
    3px;

  background:
    rgba(8,8,12,.58);

  color:
    #ff879a;

  pointer-events:
    none;

}


.exhausted-overlay div {

  font-size:
    24px;

}


.exhausted-overlay strong {

  font-size:
    8px;

}


.exhausted-overlay small {

  font-size:
    5px;

}


/* =========================================================
   FOOTER
========================================================= */

.battle-footer {

  height:
    205px;

  flex-shrink:
    0;

  display:
    grid;

  grid-template-columns:
    minmax(390px,1fr)
    230px
    minmax(390px,1fr);

  gap:
    12px;

  align-items:
    center;

  padding:
    10px 15px;

  position:
    relative;

  z-index:
    60;

  background:
    linear-gradient(
      #061328,
      #020713
    );

  border-top:
    2px solid
    rgba(70,174,255,.32);

}


/* =========================================================
   ACTION PANEL
========================================================= */

.action-side {

  height:
    180px;

  padding:
    8px;

  border-radius:
    13px;

  border:
    1px solid
    rgba(255,255,255,.09);

  background:
    rgba(0,0,0,.15);

  opacity:
    .5;

}


.action-side.active {

  opacity:
    1;

}


.action-header {

  height:
    24px;

  display:
    flex;

  justify-content:
    space-between;

  align-items:
    center;

  color:
    #9cafc7;

  font-size:
    7px;

}


.action-header strong {

  color:
    white;

}


/* =========================================================
   SKILL CARDS
========================================================= */

.skill-hand {

  display:
    grid;

  grid-template-columns:
    repeat(4,1fr);

  gap:
    6px;

}


.skill-card {

  height:
    107px;

  min-width:
    0;

  padding:
    5px;

  position:
    relative;

  border:
    2px solid
    rgba(255,255,255,.82);

  border-radius:
    7px;

  color:
    #101318;

  cursor:
    pointer;

  box-shadow:
    0 5px 10px
    rgba(0,0,0,.4);

}


.skill-basic {

  background:
    linear-gradient(
      145deg,
      #eef3ff,
      #95aad0
    );

}


.skill-defense {

  background:
    linear-gradient(
      145deg,
      #ecfbff,
      #63cbe8
    );

}


.skill-ultimate {

  background:
    linear-gradient(
      145deg,
      #ffe9a6,
      #ff7750
    );

}


.skill-heal {

  background:
    linear-gradient(
      145deg,
      #e7ffe9,
      #68cf72
    );

}


.skill-title {

  overflow:
    hidden;

  white-space:
    nowrap;

  text-overflow:
    ellipsis;

  font-size:
    6px;

  font-weight:
    1000;

}


.skill-icon {

  height:
    47px;

  margin-top:
    2px;

  display:
    grid;

  place-items:
    center;

  border-radius:
    4px;

  background:
    rgba(255,255,255,.42);

  font-size:
    25px;

}


.skill-detail {

  margin-top:
    4px;

  font-size:
    5.5px;

  line-height:
    1.35;

  font-weight:
    800;

}


.skill-card.disabled {

  opacity:
    .3;

  filter:
    grayscale(.65);

  cursor:
    not-allowed;

}


.skill-card.used {

  opacity:
    .22;

  filter:
    grayscale(1);

}


.skill-card.used::after {

  content:
    'USED';

  position:
    absolute;

  inset:
    0;

  display:
    grid;

  place-items:
    center;

  border-radius:
    inherit;

  color:
    white;

  background:
    rgba(0,0,0,.55);

  font-size:
    13px;

  font-weight:
    1000;

}


.skill-card.ready {

  opacity:
    1;

  filter:
    none;

  animation:
    ultimateReady
    .8s alternate infinite;

}


@keyframes ultimateReady {

  from {

    box-shadow:
      0 0 7px
      rgba(255,210,50,.4);

  }

  to {

    box-shadow:
      0 0 22px
      rgba(255,205,40,.95);

  }

}


/* =========================================================
   SYNERGY
========================================================= */

.synergy-button {

  width:
    100%;

  height:
    35px;

  margin-top:
    5px;

  display:
    flex;

  align-items:
    center;

  justify-content:
    center;

  gap:
    7px;

  border:
    1px solid
    rgba(255,255,255,.18);

  border-radius:
    7px;

  color:
    #77869b;

  background:
    rgba(255,255,255,.05);

  font-size:
    6px;

  font-weight:
    900;

}


.synergy-button.ready {

  color:
    #ffe96a;

  border-color:
    rgba(255,226,70,.65);

  background:
    rgba(255,180,0,.12);

  cursor:
    pointer;

}


.synergy-button.used {

  opacity:
    .35;

}


.synergy-icon {

  font-size:
    15px;

}


/* =========================================================
   CENTER TURN PANEL
========================================================= */

.turn-action-panel {

  height:
    170px;

  display:
    flex;

  flex-direction:
    column;

  align-items:
    center;

  justify-content:
    center;

  gap:
    5px;

  padding:
    10px;

  text-align:
    center;

  border-radius:
    14px;

  border:
    2px dashed
    rgba(68,195,255,.65);

  background:
    radial-gradient(
      circle,
      rgba(0,92,150,.3),
      rgba(4,18,39,.82)
    );

}


.turn-action-panel strong {

  color:
    #8ce5ff;

  font-size:
    10px;

  font-weight:
    1000;

}


.turn-action-panel small {

  color:
    #8594ac;

  font-size:
    6px;

  text-transform:
    uppercase;

}


.turn-badge {

  width:
    39px;

  height:
    39px;

  display:
    grid;

  place-items:
    center;

  border-radius:
    50%;

  font-size:
    12px;

  font-weight:
    1000;

}


.turn-blue {

  border:
    2px solid
    #54dcff;

  background:
    #0767be;

}


.turn-red {

  border:
    2px solid
    #ff8296;

  background:
    #ad1231;

}


.scanner-symbol {

  font-size:
    27px;

}


.scanner-active {

  animation:
    scannerPulse
    .6s alternate infinite;

}


@keyframes scannerPulse {

  to {

    transform:
      scale(1.15);

  }

}


.swap-main-icon {

  font-size:
    34px;

  color:
    #ffe451;

}


/* =========================================================
   SUMMON / CANCEL
========================================================= */

.summon-button {

  width:
    135px;

  margin-top:
    5px;

  padding:
    7px 10px;

  display:
    flex;

  justify-content:
    space-between;

  border:
    none;

  border-radius:
    7px;

  color:
    white;

  cursor:
    pointer;

  font-size:
    8px;

  font-weight:
    1000;

}


.summon-blue {

  background:
    linear-gradient(
      90deg,
      #087cd4,
      #08bce0
    );

}


.summon-red {

  background:
    linear-gradient(
      90deg,
      #cc173d,
      #ff4c53
    );

}


.summon-button:disabled {

  opacity:
    .3;

  cursor:
    not-allowed;

}


.cancel-summon {

  margin-top:
    4px;

  padding:
    5px 14px;

  border:
    1px solid
    #ff6681;

  border-radius:
    5px;

  background:
    rgba(255,26,66,.12);

  color:
    #ff9aad;

  cursor:
    pointer;

  font-size:
    7px;

  font-weight:
    900;

}


/* =========================================================
   WINNER
========================================================= */

.displayWinner-overlay {

  position:
    absolute;

  inset:
    0;

  z-index:
    200;

  display:
    grid;

  place-items:
    center;

  background:
    rgba(0,0,0,.65);

  backdrop-filter:
    blur(6px);

}


.displayWinner-panel {

  min-width:
    330px;

  padding:
    34px 45px;

  text-align:
    center;

  border-radius:
    20px;

  border:
    2px solid
    #ffdf46;

  background:
    linear-gradient(
      145deg,
      #101d38,
      #040817
    );

}


.displayWinner-panel span {

  color:
    #9dacbf;

  font-size:
    8px;

  font-weight:
    900;

}


.displayWinner-panel h2 {

  margin:
    8px 0 0;

  font-size:
    32px;

}


.displayWinner-panel h1 {

  margin:
    0;

  color:
    #ffe34d;

  font-size:
    44px;

}


.displayWinner-panel button {

  margin-top:
    20px;

  padding:
    9px 25px;

  border:
    none;

  border-radius:
    7px;

  background:
    #ffe14b;

  color:
    #071020;

  cursor:
    pointer;

  font-size:
    9px;

  font-weight:
    1000;

}


/* =========================================================
   HEADER GAME CONTROLS
========================================================= */

.header-game-controls {
  display: flex;
  gap: 5px;
  margin-top: 6px;
}

.header-control-button {
  border: 1px solid rgba(120, 203, 255, .4);
  border-radius: 6px;
  padding: 4px 7px;
  color: #dff7ff;
  background: rgba(4, 20, 42, .85);
  cursor: pointer;
  font-size: 7px;
  font-weight: 900;
  transition: .2s ease;
}

.header-control-button:hover {
  border-color: #7ee7ff;
  background: rgba(17, 93, 145, .72);
  transform: translateY(-1px);
}

.fullscreen-button {
  min-width: 58px;
}

.round-indicator {
  margin: 2px 0;
  color: #ffe867;
  font-size: 7px;
  font-weight: 1000;
}

.round-indicator span {
  color: #7f92ad;
  font-size: 5px;
}


/* =========================================================
   CODING QUESTION MODAL
========================================================= */

.question-overlay {
  position: absolute;
  inset: 0;
  z-index: 500;
  display: grid;
  place-items: center;
  padding: 30px;
  background: rgba(0, 5, 16, .86);
  backdrop-filter: blur(10px);
}

.question-panel {
  width: min(760px, 88vw);
  max-height: 86vh;
  overflow-y: auto;
  padding: 28px;
  border: 2px solid rgba(77, 210, 255, .72);
  border-radius: 20px;
  background:
    radial-gradient(circle at top, rgba(18, 105, 170, .25), transparent 45%),
    linear-gradient(145deg, #0a1830, #030817);
  box-shadow: 0 0 55px rgba(0, 171, 255, .25);
}

.question-kicker {
  color: #ffe767;
  text-align: center;
  font-size: 9px;
  font-weight: 1000;
  letter-spacing: .12em;
}

.question-panel h2 {
  margin: 7px 0 20px;
  text-align: center;
  font-size: 29px;
}

.question-text {
  margin: 0 0 18px;
  text-align: center;
  color: #eef8ff;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.45;
}

.question-options {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.question-option {
  min-height: 62px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 13px;
  text-align: left;
  border: 1px solid rgba(117, 196, 255, .35);
  border-radius: 11px;
  color: #eaf7ff;
  background: rgba(12, 41, 70, .78);
  cursor: pointer;
  font-size: 12px;
  font-weight: 750;
  transition: .18s ease;
}

.question-option:hover:not(:disabled) {
  border-color: #6addff;
  transform: translateY(-2px);
  background: rgba(17, 77, 119, .9);
}

.question-option.selected {
  border-color: #ffe45f;
}

.question-option.correct {
  border-color: #55ff9c;
  background: rgba(18, 112, 67, .56);
}

.question-option.wrong {
  border-color: #ff5c76;
  background: rgba(137, 20, 45, .58);
}

.option-letter {
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #05101d;
  background: #7cddff;
  font-size: 11px;
  font-weight: 1000;
}

.question-result,
.question-error,
.question-loading {
  margin-top: 18px;
  padding: 14px;
  text-align: center;
  border-radius: 11px;
}

.question-loading {
  color: #92ddff;
  background: rgba(17, 73, 109, .38);
}

.question-error {
  display: flex;
  flex-direction: column;
  gap: 8px;
  color: #ff9cad;
  background: rgba(105, 16, 35, .45);
}

.question-result.correct {
  color: #75ffae;
  background: rgba(21, 108, 65, .38);
}

.question-result.wrong {
  color: #ff8ca0;
  background: rgba(118, 20, 43, .38);
}

.question-result p {
  margin: 7px 0 0;
  color: #d7e6f5;
  font-size: 10px;
  line-height: 1.5;
}

.question-result button,
.question-error button {
  margin-top: 10px;
  padding: 9px 18px;
  border: none;
  border-radius: 7px;
  color: #05101d;
  background: #ffe35b;
  cursor: pointer;
  font-size: 9px;
  font-weight: 1000;
}

.question-enter-active,
.question-leave-active {
  transition: opacity .25s ease;
}

.question-enter-from,
.question-leave-to {
  opacity: 0;
}

@media (max-width: 900px) {
  .question-options {
    grid-template-columns: 1fr;
  }
}


/* =========================================================
   RESPONSIVE
========================================================= */

@media (
  max-width: 1400px
) {

  .battle-header {

    grid-template-columns:
      1fr
      260px
      1fr;

  }


  .player-hud {

    padding:
      10px 14px;

  }


  .player-avatar {

    width:
      56px;

    height:
      56px;

    font-size:
      27px;

  }


  .pokemon-slot {

    max-width:
      97px;

  }


  .bench-slot {

    max-width:
      86px;

  }


  .battle-footer {

    grid-template-columns:
      minmax(330px,1fr)
      190px
      minmax(330px,1fr);

    height:
      195px;

  }


  .action-side {

    height:
      170px;

  }


  .skill-card {

    height:
      100px;

  }


  .skill-icon {

    height:
      41px;

    font-size:
      22px;

  }

}



.display-mode-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  margin-top: 5px;
  padding: 4px 9px;
  border: 1px solid rgba(70, 236, 166, .22);
  border-radius: 999px;
  color: #66ffc2;
  background: rgba(46, 223, 154, .09);
  font-size: 8px;
  font-weight: 900;
  letter-spacing: .1em;
}

</style>