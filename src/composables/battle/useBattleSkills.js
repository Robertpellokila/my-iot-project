import {
  ref,
  computed,
} from "vue";


export const useBattleSkills = ({
  // =========================================================
  // BATTLE STATE
  // =========================================================

  battleState,
  currentTurn,
  winner,

  isActing,
  summonMode,
  swapMode,

  selectedTurnAction,
  selectedBattleCard,
  selectedSkill,


  // =========================================================
  // CARDS
  // =========================================================

  cards,


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
  // DEFENSE
  // =========================================================

  player1Defending,
  player2Defending,


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

  nextTurn,
  checkWinner,


  // =========================================================
  // EFFECT
  // =========================================================

  setProfileEffect,


  // =========================================================
  // AUDIO
  // =========================================================

  playSound = null,


  // =========================================================
  // CONFIG
  // =========================================================

  maxSkill = 100,

  basicSkillGain = 25,

  defenseSkillGain = 10,

  hitSkillGain = 15,

  defenseReduction = 0.5,

  ultimateMultiplier = 2,

  healPercent = 0.35,


  // =========================================================
  // DISPLAY MODE
  // =========================================================

  isDisplayOnly = null,
} = {}) => {


  // =========================================================
  // ONE-TIME SKILL STATE
  // =========================================================

  const player1UltimateUsed =
    ref(false);


  const player2UltimateUsed =
    ref(false);


  const player1HealUsed =
    ref(false);


  const player2HealUsed =
    ref(false);


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
  // SKILL GAUGE REF
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
  // DEFENSE REF
  // =========================================================

  const defendingRef =
    player => {

      return (
        player === "p1"
          ? player1Defending
          : player2Defending
      );

    };


  // =========================================================
  // SYNERGY SHIELD REF
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
  // ATTACK DEBUFF REF
  // =========================================================

  const attackDebuffRef =
    player => {

      return (
        player === "p1"
          ? player1AttackDebuff
          : player2AttackDebuff
      );

    };


  // =========================================================
  // ULTIMATE USED REF
  // =========================================================

  const ultimateUsedRef =
    player => {

      return (
        player === "p1"
          ? player1UltimateUsed
          : player2UltimateUsed
      );

    };


  // =========================================================
  // HEAL USED REF
  // =========================================================

  const healUsedRef =
    player => {

      return (
        player === "p1"
          ? player1HealUsed
          : player2HealUsed
      );

    };


  // =========================================================
  // CAN HEAL
  // =========================================================

  const player1CanHeal =
    computed(
      () => {

        return (
          player1BattleHp.value <=
          player1MaxHp.value *
            0.5
        );

      }
    );


  const player2CanHeal =
    computed(
      () => {

        return (
          player2BattleHp.value <=
          player2MaxHp.value *
            0.5
        );

      }
    );


  // =========================================================
  // CAN ULTIMATE
  // =========================================================

  const player1CanUltimate =
    computed(
      () => {

        return (
          player1Skill.value >=
            maxSkill

          &&

          !player1UltimateUsed.value
        );

      }
    );


  const player2CanUltimate =
    computed(
      () => {

        return (
          player2Skill.value >=
            maxSkill

          &&

          !player2UltimateUsed.value
        );

      }
    );


  // =========================================================
  // ADD SKILL GAUGE
  // =========================================================

  const addSkill =
    (
      player,
      amount
    ) => {

      const gauge =
        skillRef(
          player
        );


      gauge.value =
        Math.min(
          maxSkill,

          Math.max(
            0,

            gauge.value +
            Number(
              amount ||
              0
            )
          )
        );

    };


  // =========================================================
  // BACKWARD COMPATIBILITY
  //
  // Kalau ada component lama masih memakai addGauge(),
  // tetap aman.
  // =========================================================

  const addGauge =
    addSkill;


  // =========================================================
  // BASIC DAMAGE
  // =========================================================

  const calculateBasicDamage =
    card => {

      return Math.max(
        1,

        Number(
          card?.attack ||
          10
        )
      );

    };


  // =========================================================
  // ULTIMATE DAMAGE
  // =========================================================

  const calculateUltimateDamage =
    card => {

      return Math.max(
        1,

        Math.round(
          Number(
            card?.attack ||
            10
          ) *
          ultimateMultiplier
        )
      );

    };


  // =========================================================
  // HEAL AMOUNT
  // =========================================================

  const calculateHeal =
    maxHp => {

      return Math.round(
        maxHp *
        healPercent
      );

    };


  // =========================================================
  // DEAL DAMAGE
  //
  // Urutan modifier:
  //
  // 1. Ice attack debuff pada attacker
  // 2. Normal defense
  // 3. Water synergy shield
  // 4. Apply ke HP
  //
  // Dark synergy dapat melewati normal defense
  // dengan ignoreNormalDefense = true,
  // tetapi WATER SHIELD tetap berlaku.
  // =========================================================

  const dealDamage =
    async (
      attackerPlayer,
      initialDamage,
      ignoreNormalDefense = false
    ) => {

      const defenderPlayer =
        otherPlayer(
          attackerPlayer
        );


      let damage =
        Math.max(
          1,

          Math.round(
            Number(
              initialDamage
            ) || 0
          )
        );


      // =====================================================
      // ICE ATTACK DEBUFF
      //
      // Debuff berada pada attacker.
      // Hanya berlaku untuk next attack.
      // =====================================================

      const attackerDebuff =
        attackDebuffRef(
          attackerPlayer
        );


      if (
        attackerDebuff.value >
        0
      ) {

        damage =
          Math.max(
            1,

            Math.round(
              damage *
              (
                1 -
                attackerDebuff.value
              )
            )
          );


        attackerDebuff.value =
          0;

      }


      // =====================================================
      // NORMAL DEFENSE
      // =====================================================

      const defenderDefense =
        defendingRef(
          defenderPlayer
        );


      if (
        !ignoreNormalDefense
        &&
        defenderDefense.value
      ) {

        damage =
          Math.max(
            1,

            Math.round(
              damage *
              defenseReduction
            )
          );


        /*
         * Defense hanya berlaku
         * pada next incoming damage.
         */

        defenderDefense.value =
          false;

      }


      // =====================================================
      // WATER SYNERGY SHIELD
      // =====================================================

      const defenderShield =
        shieldRef(
          defenderPlayer
        );


      if (
        defenderShield.value >
        0
      ) {

        damage =
          Math.max(
            1,

            Math.round(
              damage *
              (
                1 -
                defenderShield.value
              )
            )
          );


        /*
         * Shield hanya berlaku
         * pada next incoming damage.
         */

        defenderShield.value =
          0;

      }


      // =====================================================
      // APPLY DAMAGE
      // =====================================================

      const defenderHp =
        hpRef(
          defenderPlayer
        );


      defenderHp.value =
        Math.max(
          0,

          defenderHp.value -
          damage
        );


      // =====================================================
      // HIT SOUND
      // =====================================================

      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "hit"
        );

      }


      // =====================================================
      // VISUAL EFFECT
      //
      // setProfileEffect versi terbaru non-blocking.
      // =====================================================

      if (
        typeof setProfileEffect ===
        "function"
      ) {

        setProfileEffect(
          defenderPlayer,

          "damage",

          `💥 -${damage} HP`,

          750
        );

      }


      return damage;

    };


  // =========================================================
  // SELECTED CARD BELONGS TO PLAYER
  // =========================================================

  const selectedCardBelongsTo =
    player => {

      if (
        !selectedBattleCard.value
      ) {

        return false;

      }


      return cards
        .selectedCardBelongsTo(
          player,
          selectedBattleCard.value
        );

    };


  // =========================================================
  // CAN USE SKILL
  // =========================================================

  const canUseSkill =
    (
      player,
      skill
    ) => {

      // =====================================================
      // DISPLAY ONLY
      // =====================================================

      if (
        displayOnly()
      ) {

        return false;

      }


      // =====================================================
      // INVALID SKILL
      // =====================================================

      if (
        !skill
      ) {

        return false;

      }


      // =====================================================
      // GENERAL BATTLE VALIDATION
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
        !selectedCardBelongsTo(
          player
        )
      ) {

        return false;

      }


      // =====================================================
      // EXHAUSTED CARD CANNOT ATTACK
      // =====================================================

      if (
        selectedBattleCard.value
          ?.exhausted
      ) {

        return false;

      }


      // =====================================================
      // BASIC ATTACK
      // =====================================================

      if (
        skill.type ===
          "attack"
      ) {

        return true;

      }


      // =====================================================
      // DEFENSE
      // =====================================================

      if (
        skill.type ===
          "defense"
      ) {

        return true;

      }


      // =====================================================
      // ULTIMATE
      // =====================================================

      if (
        skill.type ===
          "ultimate"
      ) {

        return (
          player === "p1"
            ? player1CanUltimate.value
            : player2CanUltimate.value
        );

      }


      // =====================================================
      // HEAL
      // =====================================================

      if (
        skill.type ===
          "heal"
      ) {

        if (
          player === "p1"
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


  // =========================================================
  // PLAY SKILL
  // =========================================================

  const playSkill =
    async (
      player,
      skill
    ) => {

      if (
        displayOnly()
      ) {

        return false;

      }


      if (
        !canUseSkill(
          player,
          skill
        )
      ) {

        return false;

      }


      const card =
        selectedBattleCard.value;


      // =====================================================
      // LOCK ACTION
      // =====================================================

      selectedTurnAction.value =
        "skill";


      selectedSkill.value =
        skill;


      isActing.value =
        true;


      // =====================================================
      // BASIC ATTACK
      // =====================================================

      if (
        skill.type ===
          "attack"
      ) {

        if (
          typeof playSound ===
          "function"
        ) {

          void playSound(
            "attack"
          );

        }


        const damage =
          calculateBasicDamage(
            card
          );


        // ===================================================
        // ATTACKER +25 GAUGE
        // ===================================================

        addSkill(
          player,
          basicSkillGain
        );


        // ===================================================
        // DEFENDER +15 GAUGE
        // ===================================================

        addSkill(
          otherPlayer(
            player
          ),

          hitSkillGain
        );


        await dealDamage(
          player,
          damage
        );

      }


      // =====================================================
      // DEFENSE
      // =====================================================

      else if (
        skill.type ===
          "defense"
      ) {

        if (
          typeof playSound ===
          "function"
        ) {

          void playSound(
            "defense"
          );

        }


        defendingRef(
          player
        ).value =
          true;


        addSkill(
          player,
          defenseSkillGain
        );


        if (
          typeof setProfileEffect ===
          "function"
        ) {

          setProfileEffect(
            player,

            "defense",

            "🛡 DEFENSE ACTIVE",

            800
          );

        }

      }


      // =====================================================
      // ULTIMATE
      // =====================================================

      else if (
        skill.type ===
          "ultimate"
      ) {

        if (
          typeof playSound ===
          "function"
        ) {

          void playSound(
            "ultimate"
          );

        }


        // ===================================================
        // ULTIMATE ONLY ONCE
        // ===================================================

        ultimateUsedRef(
          player
        ).value =
          true;


        // ===================================================
        // RESET GAUGE
        // ===================================================

        skillRef(
          player
        ).value =
          0;


        // ===================================================
        // ULTIMATE EFFECT
        // ===================================================

        if (
          typeof setProfileEffect ===
          "function"
        ) {

          setProfileEffect(
            player,

            "ultimate",

            "💥 ULTIMATE!",

            500
          );

        }


        // ===================================================
        // DAMAGE
        // ===================================================

        const damage =
          calculateUltimateDamage(
            card
          );


        await dealDamage(
          player,
          damage
        );


        // ===================================================
        // DEFENDER +20 GAUGE
        // ===================================================

        addSkill(
          otherPlayer(
            player
          ),

          20
        );

      }


      // =====================================================
      // HEAL
      // =====================================================

      else if (
        skill.type ===
          "heal"
      ) {

        if (
          typeof playSound ===
          "function"
        ) {

          void playSound(
            "heal"
          );

        }


        // ===================================================
        // ONLY ONCE
        // ===================================================

        healUsedRef(
          player
        ).value =
          true;


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


        const healAmount =
          calculateHeal(
            maxHp.value
          );


        hp.value =
          Math.min(
            maxHp.value,

            hp.value +
            healAmount
          );


        const actualHeal =
          hp.value -
          oldHp;


        if (
          typeof setProfileEffect ===
          "function"
        ) {

          setProfileEffect(
            player,

            "heal",

            `💚 +${actualHeal} HP`,

            900
          );

        }

      }


      // =====================================================
      // CHECK WINNER
      // =====================================================

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


        return true;

      }


      // =====================================================
      // NEXT TURN
      // =====================================================

      await nextTurn();


      return true;

    };


  // =========================================================
  // RESET SKILLS
  // =========================================================

  const resetSkills =
    () => {

      player1UltimateUsed.value =
        false;


      player2UltimateUsed.value =
        false;


      player1HealUsed.value =
        false;


      player2HealUsed.value =
        false;

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // USED STATE
    // =======================================================

    player1UltimateUsed,

    player2UltimateUsed,

    player1HealUsed,

    player2HealUsed,


    // =======================================================
    // AVAILABILITY
    // =======================================================

    player1CanHeal,

    player2CanHeal,

    player1CanUltimate,

    player2CanUltimate,


    // =======================================================
    // GAUGE
    // =======================================================

    addSkill,

    // compatibility
    addGauge,


    // =======================================================
    // CALCULATIONS
    // =======================================================

    calculateBasicDamage,

    calculateUltimateDamage,

    calculateHeal,


    // =======================================================
    // DAMAGE
    // =======================================================

    dealDamage,


    // =======================================================
    // SKILLS
    // =======================================================

    canUseSkill,

    playSkill,


    // =======================================================
    // RESET
    // =======================================================

    resetSkills,

  };

};