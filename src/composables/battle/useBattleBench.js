import {
  ref,
} from "vue";

export const useBattleBench = ({
  cards,

  battleState,
  currentTurn,
  winner,

  isActing,
  summonMode,

  selectedTurnAction,
  selectedBattleCard,

  isDisplayOnly,

  maxActive = 4,
  maxBench = 4,

  playSound = null,

  showProfileMessage = null,
} = {}) => {

  // =========================================================
  // STATE
  // =========================================================

  const swapMode =
    ref(false);

  const selectedBenchCard =
    ref(null);


  // =========================================================
  // DISPLAY ONLY CHECK
  // =========================================================

  const displayOnly =
    () =>
      Boolean(
        isDisplayOnly?.value ??
        isDisplayOnly
      );


  // =========================================================
  // CAN MANAGE BENCH
  // =========================================================

  const canManageBench =
    player => {

      if (
        displayOnly()
      ) {
        return false;
      }

      return (
        battleState.value ===
          "battle_ready"
        &&
        !winner.value
        &&
        !isActing.value
        &&
        !summonMode.value
        &&
        !selectedTurnAction.value
        &&
        currentTurn.value ===
          player
      );

    };


  // =========================================================
  // SELECT ACTIVE CARD
  // =========================================================

  const selectBattleCard =
    (
      player,
      card
    ) => {

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
        summonMode.value
        ||
        swapMode.value
        ||
        selectedTurnAction.value
        ||
        currentTurn.value !==
          player
        ||
        card?.zone !==
          "active"
        ||
        card?.exhausted
      ) {

        return false;

      }


      selectedBattleCard.value =
        card;


      return true;

    };


  // =========================================================
  // MOVE ACTIVE -> BENCH
  // =========================================================

  const moveToBench =
    async (
      player,
      card
    ) => {

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
        summonMode.value
        ||
        swapMode.value
        ||
        selectedTurnAction.value
        ||
        currentTurn.value !==
          player
        ||
        card?.zone !==
          "active"
      ) {

        return false;

      }


      const activeCards =
        cards.getActiveCards(
          player
        );


      const benchCards =
        cards.getBenchCards(
          player
        );


      // =====================================================
      // MINIMAL 1 ACTIVE CARD
      // =====================================================

      if (
        activeCards.length <=
        1
      ) {

        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "KEEP 1 ACTIVE"
          );

        }


        return false;

      }


      // =====================================================
      // BENCH FULL
      // =====================================================

      if (
        benchCards.length >=
        maxBench
      ) {

        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "BENCH FULL"
          );

        }


        return false;

      }


      // =====================================================
      // CARD YANG SUDAH PERNAH RETURN
      // MASUK BENCH LAGI -> EXHAUSTED
      // =====================================================

      if (
        Number(
          card.benchReturnCount ||
          0
        ) >=
        1
      ) {

        card.exhausted =
          true;

      }


      // =====================================================
      // MOVE TO BENCH
      // =====================================================

      card.zone =
        "bench";


      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "bench"
        );

      }


      // =====================================================
      // CLEAR SELECTED CARD
      // JIKA CARD YANG DIPINDAH SEDANG DIPILIH
      // =====================================================

      if (
        selectedBattleCard.value
          ?.battleId ===
        card.battleId
      ) {

        selectedBattleCard.value =
          null;

      }


      // =====================================================
      // EXHAUSTED MESSAGE
      // =====================================================

      if (
        card.exhausted
      ) {

        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "CARD EXHAUSTED"
          );

        }

      }


      return true;

    };


  // =========================================================
  // START BENCH SWAP
  // =========================================================

  const startBenchSwap =
    (
      player,
      benchCard
    ) => {

      if (
        displayOnly()
      ) {
        return false;
      }


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
        benchCard?.exhausted
        ||
        Number(
          benchCard?.benchReturnCount ||
          0
        ) >=
        1
      ) {

        return false;

      }


      selectedBattleCard.value =
        null;


      selectedBenchCard.value =
        benchCard;


      swapMode.value =
        true;


      return true;

    };


  // =========================================================
  // CANCEL SWAP
  // =========================================================

  const cancelSwap =
    () => {

      swapMode.value =
        false;


      selectedBenchCard.value =
        null;

    };


  // =========================================================
  // COMPLETE SWAP
  //
  // Bench Card -> Active
  // Active Card -> Bench
  // =========================================================

  const completeBenchSwap =
    async (
      player,
      activeCard
    ) => {

      if (
        displayOnly()
      ) {
        return false;
      }


      if (
        !swapMode.value
        ||
        !selectedBenchCard.value
        ||
        currentTurn.value !==
          player
        ||
        activeCard?.zone !==
          "active"
        ||
        isActing.value
        ||
        selectedTurnAction.value
      ) {

        return false;

      }


      const benchCard =
        selectedBenchCard.value;


      // =====================================================
      // OWNERSHIP VALIDATION
      // =====================================================

      const playerCards =
        cards.getCardsRef(
          player
        ).value;


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
        !ownsBench
        ||
        !ownsActive
      ) {

        cancelSwap();


        return false;

      }


      // =====================================================
      // VALIDATE BENCH CARD
      // =====================================================

      if (
        benchCard.zone !==
          "bench"
        ||
        benchCard.exhausted
        ||
        Number(
          benchCard.benchReturnCount ||
          0
        ) >=
        1
      ) {

        cancelSwap();


        return false;

      }


      // =====================================================
      // BENCH -> ACTIVE
      //
      // Return chance terpakai.
      // =====================================================

      benchCard.zone =
        "active";


      benchCard.benchReturnCount =
        Number(
          benchCard.benchReturnCount ||
          0
        ) + 1;


      // =====================================================
      // ACTIVE -> BENCH
      //
      // Jika active card sebelumnya sudah pernah
      // return dari bench, maka exhausted.
      // =====================================================

      if (
        Number(
          activeCard.benchReturnCount ||
          0
        ) >=
        1
      ) {

        activeCard.exhausted =
          true;

      }


      activeCard.zone =
        "bench";


      // =====================================================
      // RESET SWAP STATE
      // =====================================================

      swapMode.value =
        false;


      selectedBenchCard.value =
        null;


      // =====================================================
      // SELECT CARD YANG BARU MASUK ACTIVE
      // =====================================================

      selectedBattleCard.value =
        benchCard;


      // =====================================================
      // SOUND
      // =====================================================

      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "swap"
        );

      }


      // =====================================================
      // MESSAGE
      // =====================================================

      if (
        typeof showProfileMessage ===
        "function"
      ) {

        await showProfileMessage(
          player,

          activeCard.exhausted
            ? "SWAP • OUT CARD EXHAUSTED"
            : "CARD SWAPPED"
        );

      }


      return true;

    };


  // =========================================================
  // RETURN BENCH -> ACTIVE
  // =========================================================

  const returnFromBench =
    async (
      player,
      card
    ) => {

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
        summonMode.value
        ||
        swapMode.value
        ||
        selectedTurnAction.value
        ||
        currentTurn.value !==
          player
        ||
        card?.zone !==
          "bench"
      ) {

        return false;

      }


      // =====================================================
      // CARD EXHAUSTED
      // =====================================================

      if (
        card.exhausted
      ) {

        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "CARD UNUSABLE"
          );

        }


        return false;

      }


      // =====================================================
      // RETURN HANYA 1x
      // =====================================================

      if (
        Number(
          card.benchReturnCount ||
          0
        ) >=
        1
      ) {

        card.exhausted =
          true;


        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "RETURN ALREADY USED"
          );

        }


        return false;

      }


      const activeCards =
        cards.getActiveCards(
          player
        );


      // =====================================================
      // MASIH ADA ACTIVE SLOT
      //
      // Langsung kembali active.
      // =====================================================

      if (
        activeCards.length <
        maxActive
      ) {

        card.zone =
          "active";


        card.benchReturnCount =
          Number(
            card.benchReturnCount ||
            0
          ) + 1;


        selectedBattleCard.value =
          card;


        selectedBenchCard.value =
          null;


        swapMode.value =
          false;


        if (
          typeof playSound ===
          "function"
        ) {

          void playSound(
            "swap"
          );

        }


        if (
          typeof showProfileMessage ===
          "function"
        ) {

          await showProfileMessage(
            player,
            "CARD RETURNED"
          );

        }


        return true;

      }


      // =====================================================
      // ACTIVE FULL
      //
      // Masuk swap mode.
      // =====================================================

      return startBenchSwap(
        player,
        card
      );

    };


  // =========================================================
  // ACTIVE CARD CLICK
  // =========================================================

  const handleActiveCardClick =
    (
      player,
      card
    ) => {

      if (
        displayOnly()
      ) {
        return false;
      }


      // =====================================================
      // SWAP MODE
      //
      // Active card yang diklik menjadi card yang keluar.
      // =====================================================

      if (
        swapMode.value
      ) {

        void completeBenchSwap(
          player,
          card
        );


        return true;

      }


      // =====================================================
      // NORMAL CARD SELECTION
      // =====================================================

      return selectBattleCard(
        player,
        card
      );

    };


  // =========================================================
  // RESET
  // =========================================================

  const resetBench =
    () => {

      selectedBenchCard.value =
        null;


      swapMode.value =
        false;

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    selectedBenchCard,

    swapMode,


    canManageBench,


    selectBattleCard,

    handleActiveCardClick,


    moveToBench,

    returnFromBench,


    startBenchSwap,

    completeBenchSwap,

    cancelSwap,


    resetBench,

  };

};