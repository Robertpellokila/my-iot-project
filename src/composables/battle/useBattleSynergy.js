import {
  ref,
  computed,
} from "vue";


export const useBattleSynergy = ({
  // =========================================================
  // CARDS
  // =========================================================

  cards,


  // =========================================================
  // BATTLE STATE
  // =========================================================

  currentTurn,

  battleState,

  winner,

  selectedBattleCard,

  selectedTurnAction,

  isActing,

  summonMode,

  swapMode,


  // =========================================================
  // HP
  // =========================================================

  player1BattleHp,

  player2BattleHp,

  player1MaxHp,

  player2MaxHp,


  // =========================================================
  // SKILL GAUGE
  // =========================================================

  player1Skill,

  player2Skill,


  // =========================================================
  // SYNERGY STATUS
  // =========================================================

  player1SynergyShield,

  player2SynergyShield,

  player1AttackDebuff,

  player2AttackDebuff,


  // =========================================================
  // BATTLE FUNCTIONS
  // =========================================================

  dealDamage,

  nextTurn,

  checkWinner,

  addSkill,


  // =========================================================
  // EFFECT
  // =========================================================

  setProfileEffect,


  // =========================================================
  // AUDIO
  // =========================================================

  playSound = null,


  // =========================================================
  // DISPLAY MODE
  // =========================================================

  isDisplayOnly = null,


  // =========================================================
  // CONFIG
  // =========================================================

  maxSkill = 100,
} = {}) => {


  // =========================================================
  // ELEMENT CONFIG
  // =========================================================

  const SYNERGY_CONFIG = {

    grass: {
      name:
        "NATURE RESTORE",

      icon:
        "🌿",
    },


    fire: {
      name:
        "BLAZE BURST",

      icon:
        "🔥",
    },


    water: {
      name:
        "AQUA SHIELD",

      icon:
        "💧",
    },


    electric: {
      name:
        "VOLT CHARGE",

      icon:
        "⚡",
    },


    ice: {
      name:
        "FROST CURSE",

      icon:
        "❄️",
    },


    dark: {
      name:
        "SHADOW BURST",

      icon:
        "🌑",
    },

  };


  // =========================================================
  // ELEMENT LIST
  // =========================================================

  const elements =
    Object.keys(
      SYNERGY_CONFIG
    );


  // =========================================================
  // CREATE USED STATE
  // =========================================================

  const createSynergyState =
    () => {

      return Object.fromEntries(
        elements.map(
          element => [
            element,
            false,
          ]
        )
      );

    };


  // =========================================================
  // SYNERGY USED
  // =========================================================

  const player1SynergyUsed =
    ref(
      createSynergyState()
    );


  const player2SynergyUsed =
    ref(
      createSynergyState()
    );


  // =========================================================
  // DISPLAY ONLY
  // =========================================================

  const displayOnly =
    () => {

      return Boolean(
        isDisplayOnly?.value ??
        isDisplayOnly
      );

    };


  // =========================================================
  // NORMALIZE ELEMENT
  // =========================================================

  const normalizeElement =
    element => {

      return String(
        element ||
        ""
      )
        .trim()
        .toLowerCase();

    };


  // =========================================================
  // OTHER PLAYER
  // =========================================================

  const otherPlayer =
    player => {

      return (
        player === "p1"
          ? "p2"
          : "p1"
      );

    };


  // =========================================================
  // HP REF
  // =========================================================

  const hpRef =
    player => {

      return (
        player === "p1"
          ? player1BattleHp
          : player2BattleHp
      );

    };


  // =========================================================
  // MAX HP REF
  // =========================================================

  const maxHpRef =
    player => {

      return (
        player === "p1"
          ? player1MaxHp
          : player2MaxHp
      );

    };


  // =========================================================
  // SKILL REF
  // =========================================================

  const skillRef =
    player => {

      return (
        player === "p1"
          ? player1Skill
          : player2Skill
      );

    };


  // =========================================================
  // SHIELD REF
  // =========================================================

  const shieldRef =
    player => {

      return (
        player === "p1"
          ? player1SynergyShield
          : player2SynergyShield
      );

    };


  // =========================================================
  // DEBUFF REF
  // =========================================================

  const debuffRef =
    player => {

      return (
        player === "p1"
          ? player1AttackDebuff
          : player2AttackDebuff
      );

    };


  // =========================================================
  // USED REF
  // =========================================================

  const synergyUsedRef =
    player => {

      return (
        player === "p1"
          ? player1SynergyUsed
          : player2SynergyUsed
      );

    };


  // =========================================================
  // GET ELEMENT COUNT
  // =========================================================

  const getElementCount =
    (
      player,
      element
    ) => {

      const key =
        normalizeElement(
          element
        );


      if (
        !key
      ) {

        return 0;

      }


      return cards
        .getActiveCards(
          player
        )
        .filter(
          card =>

            normalizeElement(
              card?.element
            ) ===
            key
        )
        .length;

    };


  // =========================================================
  // GET SYNERGY POINT
  //
  // Synergy aktif mulai 2 card elemen sama.
  // Maksimum point yang dipakai = 4.
  // =========================================================

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


      if (
        count <
        2
      ) {

        return 0;

      }


      return Math.min(
        count,
        4
      );

    };


  // =========================================================
  // GRASS
  // =========================================================

  const getGrassHealPercent =
    points => {

      if (
        points >=
        4
      ) {

        return 0.6;

      }


      if (
        points ===
        3
      ) {

        return 0.45;

      }


      if (
        points ===
        2
      ) {

        return 0.3;

      }


      return 0;

    };


  // =========================================================
  // FIRE
  // =========================================================

  const getFireMultiplier =
    points => {

      if (
        points >=
        4
      ) {

        return 2.2;

      }


      if (
        points ===
        3
      ) {

        return 1.8;

      }


      if (
        points ===
        2
      ) {

        return 1.5;

      }


      return 1;

    };


  // =========================================================
  // WATER
  // =========================================================

  const getWaterReduction =
    points => {

      if (
        points >=
        4
      ) {

        return 0.8;

      }


      if (
        points ===
        3
      ) {

        return 0.6;

      }


      if (
        points ===
        2
      ) {

        return 0.4;

      }


      return 0;

    };


  // =========================================================
  // ELECTRIC
  // =========================================================

  const getElectricCharge =
    points => {

      if (
        points >=
        4
      ) {

        return 100;

      }


      if (
        points ===
        3
      ) {

        return 70;

      }


      if (
        points ===
        2
      ) {

        return 40;

      }


      return 0;

    };


  // =========================================================
  // ICE
  // =========================================================

  const getIceDebuff =
    points => {

      if (
        points >=
        4
      ) {

        return 0.6;

      }


      if (
        points ===
        3
      ) {

        return 0.4;

      }


      if (
        points ===
        2
      ) {

        return 0.25;

      }


      return 0;

    };


  // =========================================================
  // DARK
  // =========================================================

  const getDarkMultiplier =
    points => {

      if (
        points >=
        4
      ) {

        return 2;

      }


      if (
        points ===
        3
      ) {

        return 1.7;

      }


      if (
        points ===
        2
      ) {

        return 1.4;

      }


      return 1;

    };


  // =========================================================
  // CAN USE SYNERGY
  // =========================================================

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
        !SYNERGY_CONFIG[
          key
        ]
      ) {

        return false;

      }


      const points =
        getSynergyPoint(
          player,
          key
        );


      if (
        points <
        2
      ) {

        return false;

      }


      const used =
        synergyUsedRef(
          player
        );


      return (
        !used.value[
          key
        ]
      );

    };


  // =========================================================
  // GET SELECTED SYNERGY INFO
  // =========================================================

  const getSelectedSynergyInfo =
    player => {

      const card =
        selectedBattleCard.value;


      if (
        !card
      ) {

        return null;

      }


      if (
        !cards
          .selectedCardBelongsTo(
            player,
            card
          )
      ) {

        return null;

      }


      const element =
        normalizeElement(
          card.element
        );


      if (
        !SYNERGY_CONFIG[
          element
        ]
      ) {

        return null;

      }


      const points =
        getSynergyPoint(
          player,
          element
        );


      const used =
        Boolean(
          synergyUsedRef(
            player
          ).value[
            element
          ]
        );


      return {

        element,

        points,

        used,

        canUse:
          canUseSynergy(
            player,
            element
          ),

        icon:
          SYNERGY_CONFIG[
            element
          ].icon,

        name:
          SYNERGY_CONFIG[
            element
          ].name,

      };

    };


  // =========================================================
  // PLAYER SELECTED SYNERGY INFO
  // =========================================================

  const player1SelectedSynergyInfo =
    computed(
      () => {

        return getSelectedSynergyInfo(
          "p1"
        );

      }
    );


  const player2SelectedSynergyInfo =
    computed(
      () => {

        return getSelectedSynergyInfo(
          "p2"
        );

      }
    );


  // =========================================================
  // CURRENT TURN SYNERGY INFO
  //
  // Digunakan BattleFooter / PlayerActions.
  // =========================================================

  const selectedSynergyInfo =
    computed(
      () => {

        return getSelectedSynergyInfo(
          currentTurn.value
        );

      }
    );


  // =========================================================
  // CAN USE COMPUTED
  // =========================================================

  const player1CanUseSynergy =
    computed(
      () => {

        return Boolean(
          player1SelectedSynergyInfo
            .value
            ?.canUse
        );

      }
    );


  const player2CanUseSynergy =
    computed(
      () => {

        return Boolean(
          player2SelectedSynergyInfo
            .value
            ?.canUse
        );

      }
    );


  // =========================================================
  // SET SYNERGY EFFECT
  // =========================================================

  const showSynergyEffect =
    (
      player,
      text,
      duration = 900
    ) => {

      if (
        typeof setProfileEffect ===
        "function"
      ) {

        setProfileEffect(
          player,

          "synergy",

          text,

          duration
        );

      }

    };


  // =========================================================
  // PLAY SYNERGY
  // =========================================================

  const playSynergy =
    async player => {

      // =====================================================
      // PUBLIC / DISPLAY ONLY
      // =====================================================

      if (
        displayOnly()
      ) {

        return false;

      }


      // =====================================================
      // GENERAL VALIDATION
      // =====================================================

      if (
        battleState.value !==
          "battle_ready"

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


      // =====================================================
      // ACTIVE CARD REQUIRED
      // =====================================================

      if (
        !cards
          .selectedCardBelongsTo(
            player,
            selectedBattleCard.value
          )
      ) {

        return false;

      }


      const card =
        selectedBattleCard.value;


      if (
        card?.exhausted
      ) {

        return false;

      }


      // =====================================================
      // ELEMENT
      // =====================================================

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

        return false;

      }


      // =====================================================
      // POINT
      // =====================================================

      const points =
        getSynergyPoint(
          player,
          element
        );


      // =====================================================
      // MARK USED
      // =====================================================

      synergyUsedRef(
        player
      ).value[
        element
      ] =
        true;


      // =====================================================
      // LOCK ACTION
      // =====================================================

      selectedTurnAction.value =
        "synergy";


      isActing.value =
        true;


      // =====================================================
      // SOUND
      // =====================================================

      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "synergy"
        );

      }


      // =====================================================
      // GRASS
      // =====================================================

      if (
        element ===
        "grass"
      ) {

        const percentage =
          getGrassHealPercent(
            points
          );


        const hp =
          hpRef(
            player
          );


        const maxHp =
          maxHpRef(
            player
          );


        const oldHp =
          hp.value;


        hp.value =
          Math.min(
            maxHp.value,

            hp.value +
            Math.round(
              maxHp.value *
              percentage
            )
          );


        const actualHeal =
          hp.value -
          oldHp;


        showSynergyEffect(
          player,

          `🌿 +${actualHeal} HP`
        );

      }


      // =====================================================
      // FIRE
      // =====================================================

      else if (
        element ===
        "fire"
      ) {

        const multiplier =
          getFireMultiplier(
            points
          );


        const damage =
          Math.max(
            1,

            Math.round(
              Number(
                card.attack ||
                10
              ) *
              multiplier
            )
          );


        showSynergyEffect(
          player,

          `🔥 ${points}x FIRE`,

          500
        );


        await dealDamage(
          player,

          damage
        );

      }


      // =====================================================
      // WATER
      // =====================================================

      else if (
        element ===
        "water"
      ) {

        const reduction =
          getWaterReduction(
            points
          );


        shieldRef(
          player
        ).value =
          reduction;


        showSynergyEffect(
          player,

          `💧 SHIELD ${Math.round(
            reduction *
            100
          )}%`
        );

      }


      // =====================================================
      // ELECTRIC
      // =====================================================

      else if (
        element ===
        "electric"
      ) {

        const charge =
          getElectricCharge(
            points
          );


        /*
         * Utamakan addSkill dari
         * useBattleSkills supaya aturan
         * max gauge konsisten.
         */

        if (
          typeof addSkill ===
          "function"
        ) {

          addSkill(
            player,
            charge
          );

        }

        else {

          const gauge =
            skillRef(
              player
            );


          gauge.value =
            Math.min(
              maxSkill,

              gauge.value +
              charge
            );

        }


        showSynergyEffect(
          player,

          `⚡ ULTIMATE +${charge}%`
        );

      }


      // =====================================================
      // ICE
      // =====================================================

      else if (
        element ===
        "ice"
      ) {

        const debuff =
          getIceDebuff(
            points
          );


        debuffRef(
          otherPlayer(
            player
          )
        ).value =
          debuff;


        showSynergyEffect(
          player,

          `❄ ENEMY ATK -${Math.round(
            debuff *
            100
          )}%`
        );

      }


      // =====================================================
      // DARK
      //
      // Ignore NORMAL DEFENSE.
      //
      // Water Shield tetap berlaku karena
      // dealDamage hanya melewati
      // normal defense.
      // =====================================================

      else if (
        element ===
        "dark"
      ) {

        const multiplier =
          getDarkMultiplier(
            points
          );


        const damage =
          Math.max(
            1,

            Math.round(
              Number(
                card.attack ||
                10
              ) *
              multiplier
            )
          );


        showSynergyEffect(
          player,

          "🌑 SHADOW BURST",

          500
        );


        await dealDamage(
          player,

          damage,

          true
        );

      }


      // =====================================================
      // CHECK WINNER
      // =====================================================

      if (
        typeof checkWinner ===
          "function"

        &&

        checkWinner()
      ) {

        selectedTurnAction.value =
          null;


        selectedBattleCard.value =
          null;


        isActing.value =
          false;


        return true;

      }


      // =====================================================
      // NEXT TURN
      // =====================================================

      await nextTurn();


      return true;

    };


  // =========================================================
  // RESET SYNERGY
  // =========================================================

  const resetSynergy =
    () => {

      player1SynergyUsed.value =
        createSynergyState();


      player2SynergyUsed.value =
        createSynergyState();

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // CONFIG
    // =======================================================

    SYNERGY_CONFIG,

    elements,


    // =======================================================
    // USED STATE
    // =======================================================

    player1SynergyUsed,

    player2SynergyUsed,


    // =======================================================
    // HELPERS
    // =======================================================

    normalizeElement,

    getElementCount,

    getSynergyPoint,

    canUseSynergy,


    // =======================================================
    // VALUES
    // =======================================================

    getGrassHealPercent,

    getFireMultiplier,

    getWaterReduction,

    getElectricCharge,

    getIceDebuff,

    getDarkMultiplier,


    // =======================================================
    // INFO
    // =======================================================

    getSelectedSynergyInfo,

    selectedSynergyInfo,

    player1SelectedSynergyInfo,

    player2SelectedSynergyInfo,

    player1CanUseSynergy,

    player2CanUseSynergy,


    // =======================================================
    // ACTION
    // =======================================================

    playSynergy,


    // =======================================================
    // RESET
    // =======================================================

    resetSynergy,

  };

};