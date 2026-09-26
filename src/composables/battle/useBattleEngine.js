import {
  ref,
  computed,
} from "vue";

import {
  useBattleCards,
} from "./useBattleCards";

import {
  useBattleBench,
} from "./useBattleBench";

import {
  useBattleEffects,
} from "./useBattleEffects";

import {
  useBattleQuestions,
} from "./useBattleQuestions";

import {
  useBattleSkills,
} from "./useBattleSkills";

import {
  useBattleSynergy,
} from "./useBattleSynergy";


export const useBattleEngine = ({
  supabase,

  playSound = null,

  playBattleEndSounds = null,

  isDisplayOnly = null,

  isReaderBusy =
    () => false,

  basePlayerHp = 200,

  maxActive = 4,

  maxBench = 4,

  maxTotalCards = 8,

  maxSkill = 100,

  basicSkillGain = 25,

  defenseSkillGain = 10,

  hitSkillGain = 15,

  defenseReduction = 0.5,

  ultimateMultiplier = 2,

  healPercent = 0.35,

  questionIntervalRounds = 5,

  questionTable =
    "coding_questions",
} = {}) => {


  // =========================================================
  // GENERAL STATE
  // =========================================================

  const battleState =
    ref(
      "waiting_p1"
    );


  const currentTurn =
    ref(
      "p1"
    );


  const winner =
    ref(null);


  const isActing =
    ref(false);


  const selectedTurnAction =
    ref(null);


  const selectedBattleCard =
    ref(null);


  const selectedSkill =
    ref(null);


  const summonMode =
    ref(false);


  // =========================================================
  // ROUND
  // =========================================================

  const roundCount =
    ref(0);


  // =========================================================
  // PLAYER HP
  // =========================================================

  const player1BattleHp =
    ref(
      basePlayerHp
    );


  const player2BattleHp =
    ref(
      basePlayerHp
    );


  const player1MaxHp =
    ref(
      basePlayerHp
    );


  const player2MaxHp =
    ref(
      basePlayerHp
    );


  // =========================================================
  // ULTIMATE GAUGE
  // =========================================================

  const player1Skill =
    ref(0);


  const player2Skill =
    ref(0);


  // =========================================================
  // DEFENSE
  // =========================================================

  const player1Defending =
    ref(false);


  const player2Defending =
    ref(false);


  // =========================================================
  // WATER SYNERGY SHIELD
  // =========================================================

  const player1SynergyShield =
    ref(0);


  const player2SynergyShield =
    ref(0);


  // =========================================================
  // ICE ATTACK DEBUFF
  // =========================================================

  const player1AttackDebuff =
    ref(0);


  const player2AttackDebuff =
    ref(0);


  // =========================================================
  // CARDS
  // =========================================================

  const cards =
    useBattleCards({
      maxActive,

      maxBench,

      maxTotalCards,
    });


  // =========================================================
  // EFFECTS
  // =========================================================

  const effects =
    useBattleEffects({
      playSound,
    });


  // =========================================================
  // QUESTIONS
  // =========================================================

  const questions =
    useBattleQuestions({
      supabase,

      questionTable,

      playSound,
    });


  // =========================================================
  // HELPERS
  // =========================================================

  const wait =
    ms =>
      new Promise(
        resolve =>
          setTimeout(
            resolve,
            ms
          )
      );


  const displayOnly =
    () =>
      Boolean(
        isDisplayOnly?.value ??
        isDisplayOnly
      );


  // =========================================================
  // CHECK WINNER
  // =========================================================

  const checkWinner =
    () => {

      if (
        player1BattleHp.value <=
        0
      ) {

        winner.value =
          "p2";


        if (
          typeof playBattleEndSounds ===
          "function"
        ) {

          void playBattleEndSounds();

        }


        return true;

      }


      if (
        player2BattleHp.value <=
        0
      ) {

        winner.value =
          "p1";


        if (
          typeof playBattleEndSounds ===
          "function"
        ) {

          void playBattleEndSounds();

        }


        return true;

      }


      return false;

    };


  // =========================================================
  // FORWARD DECLARATIONS
  // =========================================================

  let bench =
    null;


  let skills =
    null;


  let synergy =
    null;


  // =========================================================
  // NEXT TURN
  // =========================================================

  const nextTurn =
    async () => {

      /*
       * Sedikit delay kecil seperti source asli.
       */

      await wait(
        150
      );


      if (
        winner.value
        ||
        battleState.value !==
          "battle_ready"
      ) {

        return;

      }


      const finishedPlayer =
        currentTurn.value;


      // =====================================================
      // SWITCH PLAYER
      // =====================================================

      currentTurn.value =
        finishedPlayer ===
          "p1"
          ? "p2"
          : "p1";


      // =====================================================
      // RESET SELECTION
      // =====================================================

      selectedSkill.value =
        null;


      selectedBattleCard.value =
        null;


      selectedTurnAction.value =
        null;


      if (
        bench
      ) {

        bench.selectedBenchCard
          .value =
            null;


        bench.swapMode.value =
          false;

      }


      summonMode.value =
        false;


      // =====================================================
      // FULL ROUND
      //
      // P1 -> P2
      //
      // Round bertambah setelah P2 selesai.
      // =====================================================

      if (
        finishedPlayer ===
        "p2"
      ) {

        roundCount.value +=
          1;


        // ===================================================
        // CODING QUESTION EVERY 5 FULL ROUNDS
        // ===================================================

        if (
          roundCount.value %
            questionIntervalRounds ===
          0
        ) {

          isActing.value =
            true;


          await questions
            .startQuestionBreak();


          return;

        }

      }


      isActing.value =
        false;

    };


  // =========================================================
  // BENCH ENGINE
  // =========================================================

  bench =
    useBattleBench({
      cards,

      battleState,

      currentTurn,

      winner,

      isActing,

      summonMode,

      selectedTurnAction,

      selectedBattleCard,

      isDisplayOnly,

      maxActive,

      maxBench,

      playSound,

      showProfileMessage:
        effects.showProfileMessage,
    });


  // =========================================================
  // SKILL ENGINE
  // =========================================================

  skills =
    useBattleSkills({
      battleState,

      currentTurn,

      winner,

      isActing,

      summonMode,

      swapMode:
        bench.swapMode,

      selectedTurnAction,

      selectedBattleCard,

      selectedSkill,

      cards,

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

      nextTurn,

      checkWinner,

      setProfileEffect:
        effects.setProfileEffect,

      playSound,

      maxSkill,

      basicSkillGain,

      defenseSkillGain,

      hitSkillGain,

      defenseReduction,

      ultimateMultiplier,

      healPercent,

      isDisplayOnly,
    });


  // =========================================================
  // SYNERGY ENGINE
  // =========================================================

  synergy =
    useBattleSynergy({
      cards,

      battleState,

      currentTurn,

      winner,

      isActing,

      summonMode,

      swapMode:
        bench.swapMode,

      selectedTurnAction,

      selectedBattleCard,

      player1BattleHp,

      player2BattleHp,

      player1MaxHp,

      player2MaxHp,

      player1Skill,

      player2Skill,

      player1SynergyShield,

      player2SynergyShield,

      player1AttackDebuff,

      player2AttackDebuff,

      dealDamage:
        skills.dealDamage,

      nextTurn,

      checkWinner,

      addSkill:
        skills.addSkill,

      setProfileEffect:
        effects.setProfileEffect,

      playSound,

      isDisplayOnly,
    });


  // =========================================================
  // CHOOSE SUMMON
  // =========================================================

  const chooseSummon =
    player => {

      if (
        displayOnly()
      ) {

        return false;

      }


      if (
        battleState.value !==
          "battle_ready"
        ||
        winner.value
        ||
        isActing.value
        ||
        selectedTurnAction.value
        ||
        bench.swapMode.value
        ||
        currentTurn.value !==
          player
      ) {

        return false;

      }


      if (
        !cards.canSummon(
          player
        )
      ) {

        return false;

      }


      selectedBattleCard.value =
        null;


      bench.selectedBenchCard
        .value =
          null;


      selectedTurnAction.value =
        "summon";


      summonMode.value =
        true;


      return true;

    };


  // =========================================================
  // CANCEL SUMMON
  // =========================================================

  const cancelSummon =
    () => {

      if (
        displayOnly()
      ) {

        return false;

      }


      /*
       * Jangan cancel ketika scan RFID
       * sedang diproses.
       */

      if (
        isActing.value
        ||
        isReaderBusy(
          currentTurn.value
        )
      ) {

        return false;

      }


      summonMode.value =
        false;


      selectedTurnAction.value =
        null;


      return true;

    };


  // =========================================================
  // SUMMON BATTLE CARD
  // =========================================================

  const summonBattleCard =
    async (
      cardData,
      uid = null
    ) => {

      if (
        !summonMode.value
        ||
        selectedTurnAction.value !==
          "summon"
      ) {

        return false;

      }


      const player =
        currentTurn.value;


      if (
        !cards.canSummon(
          player
        )
      ) {

        summonMode.value =
          false;


        selectedTurnAction.value =
          null;


        return false;

      }


      isActing.value =
        true;


      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "summon"
        );

      }


      // =====================================================
      // CREATE CARD
      // =====================================================

      const card =
        cards.addCard(
          player,

          cardData,

          uid,

          {
            zone:
              "active",
          }
        );


      if (
        !card
      ) {

        isActing.value =
          false;


        summonMode.value =
          false;


        selectedTurnAction.value =
          null;


        return false;

      }


      // =====================================================
      // HP GAIN
      // =====================================================

      const hpGain =
        Math.max(
          0,

          Number(
            cardData?.hp
          ) || 0
        );


      if (
        player ===
        "p1"
      ) {

        player1MaxHp.value +=
          hpGain;


        player1BattleHp.value +=
          hpGain;


        effects.showSummon(
          "p1",
          hpGain
        );

      }

      else {

        player2MaxHp.value +=
          hpGain;


        player2BattleHp.value +=
          hpGain;


        effects.showSummon(
          "p2",
          hpGain
        );

      }


      // =====================================================
      // NEXT TURN
      // =====================================================

      await nextTurn();


      return true;

    };


  // =========================================================
  // QUESTION CONTINUE
  // =========================================================

  const continueAfterQuestion =
    () => {

      questions
        .continueAfterQuestion();


      isActing.value =
        false;

    };


  // =========================================================
  // PLAYER HAND
  // =========================================================

  const player1Hand = [

    {
      id:
        "p1-basic",

      name:
        "Basic Attack",

      type:
        "attack",

      icon:
        "⚔️",

      className:
        "skill-basic",
    },

    {
      id:
        "p1-defense",

      name:
        "Defense",

      type:
        "defense",

      icon:
        "🛡️",

      className:
        "skill-defense",
    },

    {
      id:
        "p1-ultimate",

      name:
        "Ultimate",

      type:
        "ultimate",

      icon:
        "💥",

      className:
        "skill-ultimate",
    },

    {
      id:
        "p1-heal",

      name:
        "Heal",

      type:
        "heal",

      icon:
        "💚",

      className:
        "skill-heal",
    },

  ];


  const player2Hand = [

    {
      id:
        "p2-basic",

      name:
        "Basic Attack",

      type:
        "attack",

      icon:
        "⚔️",

      className:
        "skill-basic",
    },

    {
      id:
        "p2-defense",

      name:
        "Defense",

      type:
        "defense",

      icon:
        "🛡️",

      className:
        "skill-defense",
    },

    {
      id:
        "p2-ultimate",

      name:
        "Ultimate",

      type:
        "ultimate",

      icon:
        "💥",

      className:
        "skill-ultimate",
    },

    {
      id:
        "p2-heal",

      name:
        "Heal",

      type:
        "heal",

      icon:
        "💚",

      className:
        "skill-heal",
    },

  ];


  // =========================================================
  // TURN TEXT
  // =========================================================

  const turnText =
    computed(() => {

      // =====================================================
      // QUESTION
      // =====================================================

      if (
        questions.questionMode
          .value
      ) {

        return "CODING CHALLENGE";

      }


      // =====================================================
      // WAITING RFID
      // =====================================================

      if (
        battleState.value !==
          "battle_ready"
      ) {

        const p1Ready =
          cards.player1Cards.value
            .length >
          0;


        const p2Ready =
          cards.player2Cards.value
            .length >
          0;


        if (
          !p1Ready
          &&
          !p2Ready
        ) {

          return "SCAN P1 & P2";

        }


        if (
          p1Ready
          &&
          !p2Ready
        ) {

          return "WAITING FOR PLAYER 2";

        }


        if (
          !p1Ready
          &&
          p2Ready
        ) {

          return "WAITING FOR PLAYER 1";

        }

      }


      // =====================================================
      // WINNER
      // =====================================================

      if (
        winner.value ===
        "p1"
      ) {

        return "PLAYER 1 WINS";

      }


      if (
        winner.value ===
        "p2"
      ) {

        return "PLAYER 2 WINS";

      }


      // =====================================================
      // SWAP
      // =====================================================

      if (
        bench.swapMode.value
      ) {

        return "SELECT ACTIVE CARD TO SWAP";

      }


      // =====================================================
      // SUMMON
      // =====================================================

      if (
        summonMode.value
      ) {

        return (
          currentTurn.value ===
            "p1"

            ? "PLAYER 1 • SCAN SUMMON"

            : "PLAYER 2 • SCAN SUMMON"
        );

      }


      // =====================================================
      // NORMAL TURN
      // =====================================================

      return (
        currentTurn.value ===
          "p1"

          ? "PLAYER 1 TURN"

          : "PLAYER 2 TURN"
      );

    });


  // =========================================================
  // ROUND DISPLAY
  // =========================================================

  const displayRound =
    computed(() => {

      return (
        roundCount.value +
        1
      );

    });


  // =========================================================
  // HP PERCENT
  // =========================================================

  const player1HpPercent =
    computed(() => {

      return Math.min(
        100,

        Math.max(
          0,

          (
            player1BattleHp.value /
            Math.max(
              1,
              player1MaxHp.value
            )
          ) *
          100
        )
      );

    });


  const player2HpPercent =
    computed(() => {

      return Math.min(
        100,

        Math.max(
          0,

          (
            player2BattleHp.value /
            Math.max(
              1,
              player2MaxHp.value
            )
          ) *
          100
        )
      );

    });


  // =========================================================
  // CAN HEAL
  // =========================================================

  const player1CanHeal =
    computed(() => {

      return skills
        .player1CanHeal
        .value;

    });


  const player2CanHeal =
    computed(() => {

      return skills
        .player2CanHeal
        .value;

    });


  // =========================================================
  // CAN ULTIMATE
  // =========================================================

  const player1CanUltimate =
    computed(() => {

      return skills
        .player1CanUltimate
        .value;

    });


  const player2CanUltimate =
    computed(() => {

      return skills
        .player2CanUltimate
        .value;

    });


  // =========================================================
  // CAN SUMMON
  // =========================================================

  const player1CanSummon =
    computed(() => {

      return cards.canSummon(
        "p1"
      );

    });


  const player2CanSummon =
    computed(() => {

      return cards.canSummon(
        "p2"
      );

    });


  // =========================================================
  // RESET ARENA
  // =========================================================

  const resetArena =
    () => {

      // =====================================================
      // CARDS
      // =====================================================

      cards.resetCards();


      // =====================================================
      // HP
      // =====================================================

      player1BattleHp.value =
        basePlayerHp;


      player2BattleHp.value =
        basePlayerHp;


      player1MaxHp.value =
        basePlayerHp;


      player2MaxHp.value =
        basePlayerHp;


      // =====================================================
      // GAUGE
      // =====================================================

      player1Skill.value =
        0;


      player2Skill.value =
        0;


      // =====================================================
      // DEFENSE
      // =====================================================

      player1Defending.value =
        false;


      player2Defending.value =
        false;


      // =====================================================
      // WATER SHIELD
      // =====================================================

      player1SynergyShield.value =
        0;


      player2SynergyShield.value =
        0;


      // =====================================================
      // ICE DEBUFF
      // =====================================================

      player1AttackDebuff.value =
        0;


      player2AttackDebuff.value =
        0;


      // =====================================================
      // ONE TIME SKILLS
      // =====================================================

      skills.resetSkills();


      // =====================================================
      // SYNERGY
      // =====================================================

      synergy.resetSynergy();


      // =====================================================
      // TURN
      // =====================================================

      currentTurn.value =
        "p1";


      // =====================================================
      // SELECTION
      // =====================================================

      selectedTurnAction.value =
        null;


      selectedBattleCard.value =
        null;


      selectedSkill.value =
        null;


      // =====================================================
      // MODES
      // =====================================================

      summonMode.value =
        false;


      bench.resetBench();


      isActing.value =
        false;


      // =====================================================
      // ROUND
      // =====================================================

      roundCount.value =
        0;


      // =====================================================
      // QUESTION
      // =====================================================

      questions.resetQuestions();


      // =====================================================
      // EFFECT
      // =====================================================

      effects.resetEffects();


      // =====================================================
      // WINNER
      // =====================================================

      winner.value =
        null;


      // =====================================================
      // STATE
      // =====================================================

      battleState.value =
        "waiting_p1";

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // GENERAL
    // =======================================================

    battleState,

    currentTurn,

    winner,

    isActing,


    // =======================================================
    // ROUND
    // =======================================================

    roundCount,

    displayRound,


    // =======================================================
    // SELECTION
    // =======================================================

    selectedTurnAction,

    selectedBattleCard,

    selectedSkill,


    // =======================================================
    // SUMMON
    // =======================================================

    summonMode,


    // =======================================================
    // HP
    // =======================================================

    player1BattleHp,

    player2BattleHp,

    player1MaxHp,

    player2MaxHp,

    player1HpPercent,

    player2HpPercent,


    // =======================================================
    // GAUGE
    // =======================================================

    player1Skill,

    player2Skill,


    // =======================================================
    // DEFENSE
    // =======================================================

    player1Defending,

    player2Defending,


    // =======================================================
    // SYNERGY STATUS
    // =======================================================

    player1SynergyShield,

    player2SynergyShield,

    player1AttackDebuff,

    player2AttackDebuff,


    // =======================================================
    // HAND
    // =======================================================

    player1Hand,

    player2Hand,


    // =======================================================
    // CAN STATES
    // =======================================================

    player1CanHeal,

    player2CanHeal,

    player1CanUltimate,

    player2CanUltimate,

    player1CanSummon,

    player2CanSummon,


    // =======================================================
    // SUB ENGINES
    // =======================================================

    cards,

    bench,

    skills,

    synergy,

    effects,

    questions,


    // =======================================================
    // DISPLAY
    // =======================================================

    turnText,


    // =======================================================
    // BATTLE FUNCTIONS
    // =======================================================

    checkWinner,

    nextTurn,


    // =======================================================
    // SUMMON FUNCTIONS
    // =======================================================

    chooseSummon,

    cancelSummon,

    summonBattleCard,


    // =======================================================
    // QUESTION FUNCTIONS
    // =======================================================

    continueAfterQuestion,


    // =======================================================
    // RESET
    // =======================================================

    resetArena,


    // =======================================================
    // CONFIG
    // =======================================================

    constants: {

      basePlayerHp,

      maxActive,

      maxBench,

      maxTotalCards,

      maxSkill,

      basicSkillGain,

      defenseSkillGain,

      hitSkillGain,

      defenseReduction,

      ultimateMultiplier,

      healPercent,

      questionIntervalRounds,

    },

  };

};