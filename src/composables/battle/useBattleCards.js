import {
  ref,
  computed,
} from "vue";


export const useBattleCards = ({
  maxActive = 4,
  maxBench = 4,
  maxTotalCards = 8,
} = {}) => {


  // =========================================================
  // PLAYER CARDS
  // =========================================================

  const player1Cards =
    ref([]);


  const player2Cards =
    ref([]);


  let battleCardCounter =
    0;


  // =========================================================
  // GET PLAYER CARDS REF
  // =========================================================

  const getCardsRef =
    player => {

      return (
        player === "p1"
          ? player1Cards
          : player2Cards
      );

    };


  // =========================================================
  // NORMALIZE ZONE
  // =========================================================

  const normalizeZone =
    card => {

      return (
        card?.zone ===
          "bench"
          ? "bench"
          : "active"
      );

    };


  // =========================================================
  // NORMALIZE SHARED CARD
  //
  // Dipakai ketika Public TV menerima battle_cards
  // langsung dari Supabase.
  // =========================================================

  const normalizeSharedCard =
    card => {

      if (!card) {
        return null;
      }


      return {

        ...card,


        // =====================================================
        // LOCAL BATTLE ID
        // =====================================================

        battleId:
          card?.battleId ??
          card?.battle_id ??
          card?.id,


        // =====================================================
        // NAME
        // =====================================================

        name:
          card?.name ??
          card?.nama ??
          "Unknown Card",


        // =====================================================
        // HP
        // =====================================================

        hp:
          Math.max(
            0,

            Number(
              card?.hp
            ) || 0
          ),


        // =====================================================
        // ATTACK
        // =====================================================

        attack:
          Math.max(
            0,

            Number(
              card?.attack
            ) || 0
          ),


        // =====================================================
        // IMAGE
        // =====================================================

        image_url:
          card?.image_url ??
          card?.image ??
          null,


        // =====================================================
        // ELEMENT
        // =====================================================

        element:
          card?.element ??
          "",


        // =====================================================
        // ZONE
        // =====================================================

        zone:
          normalizeZone(
            card
          ),


        // =====================================================
        // BENCH RETURN COUNT
        //
        // Local:
        // benchReturnCount
        //
        // Database:
        // bench_return_count
        // =====================================================

        benchReturnCount:
          Number(
            card
              ?.benchReturnCount ??
            card
              ?.bench_return_count ??
            0
          ),


        // =====================================================
        // EXHAUSTED
        // =====================================================

        exhausted:
          Boolean(
            card?.exhausted
          ),

      };

    };


  // =========================================================
  // CREATE BATTLE CARD
  // =========================================================

  const createBattleCard =
    (
      cardData,
      uid = null
    ) => {

      battleCardCounter +=
        1;


      /*
       * Battle card lokal harus memiliki ID unik,
       * walaupun card yang sama berasal dari game_cards.
       *
       * Source BattleArena lama menggunakan
       * UID + counter.
       */

      const cardUid =
        uid ??
        cardData?.uid ??
        null;


      return {

        ...cardData,


        // =====================================================
        // BATTLE ID
        // =====================================================

        battleId:

          cardData?.battleId ??

          cardData?.battle_id ??

          (
            cardUid
              ? `${cardUid}-${battleCardCounter}`
              : `battle-card-${battleCardCounter}`
          ),


        // =====================================================
        // DATABASE CARD ID
        // =====================================================

        id:
          cardData?.id ??
          null,


        // =====================================================
        // RFID UID
        // =====================================================

        uid:
          cardUid,


        // =====================================================
        // NAME
        // =====================================================

        name:
          cardData?.name ??
          cardData?.nama ??
          "Unknown Card",


        // =====================================================
        // HP
        // =====================================================

        hp:
          Math.max(
            0,

            Number(
              cardData?.hp
            ) || 0
          ),


        // =====================================================
        // ATTACK
        // =====================================================

        attack:
          Math.max(
            0,

            Number(
              cardData?.attack
            ) || 0
          ),


        // =====================================================
        // ELEMENT
        // =====================================================

        element:
          cardData?.element ??
          "",


        // =====================================================
        // IMAGE
        // =====================================================

        image_url:
          cardData?.image_url ??
          cardData?.image ??
          null,


        // =====================================================
        // ZONE
        // =====================================================

        zone:
          normalizeZone(
            cardData
          ),


        // =====================================================
        // BENCH RETURN
        // =====================================================

        benchReturnCount:
          Number(
            cardData
              ?.benchReturnCount ??

            cardData
              ?.bench_return_count ??

            0
          ),


        // =====================================================
        // EXHAUSTED
        // =====================================================

        exhausted:
          Boolean(
            cardData
              ?.exhausted
          ),

      };

    };


  // =========================================================
  // ACTIVE CARDS
  // =========================================================

  const activeCards =
    player => {

      return getCardsRef(
        player
      ).value.filter(
        card =>

          card.zone ===
            "active"

          &&

          !card.exhausted
      );

    };


  // =========================================================
  // COMPATIBILITY ALIAS
  //
  // Digunakan composable baru.
  // =========================================================

  const getActiveCards =
    player => {

      return activeCards(
        player
      );

    };


  // =========================================================
  // BENCH CARDS
  // =========================================================

  const benchCards =
    player => {

      return getCardsRef(
        player
      ).value.filter(
        card =>
          card.zone ===
          "bench"
      );

    };


  // =========================================================
  // COMPATIBILITY ALIAS
  // =========================================================

  const getBenchCards =
    player => {

      return benchCards(
        player
      );

    };


  // =========================================================
  // COMPUTED ACTIVE
  // =========================================================

  const player1ActiveCards =
    computed(
      () =>
        activeCards(
          "p1"
        )
    );


  const player2ActiveCards =
    computed(
      () =>
        activeCards(
          "p2"
        )
    );


  // =========================================================
  // COMPUTED BENCH
  // =========================================================

  const player1BenchCards =
    computed(
      () =>
        benchCards(
          "p1"
        )
    );


  const player2BenchCards =
    computed(
      () =>
        benchCards(
          "p2"
        )
    );


  // =========================================================
  // TOTAL CARDS
  // =========================================================

  const totalCards =
    player => {

      return getCardsRef(
        player
      ).value.length;

    };


  // =========================================================
  // CAN SUMMON
  // =========================================================

  const canSummon =
    player => {

      return (

        totalCards(
          player
        ) <
        maxTotalCards

        &&

        activeCards(
          player
        ).length <
        maxActive

      );

    };


  // =========================================================
  // PLAYER CAN SUMMON COMPUTED
  //
  // Dibutuhkan BattleArena / BattleFooter / RFID.
  // =========================================================

  const player1CanSummon =
    computed(
      () =>
        canSummon(
          "p1"
        )
    );


  const player2CanSummon =
    computed(
      () =>
        canSummon(
          "p2"
        )
    );


  // =========================================================
  // CAN ADD TO BENCH
  // =========================================================

  const canAddToBench =
    player => {

      return (

        benchCards(
          player
        ).length <
        maxBench

      );

    };


  // =========================================================
  // ADD CARD
  // =========================================================

  const addCard =
    (
      player,
      cardData,
      uid = null,
      {
        zone = "active",
      } = {}
    ) => {

      const list =
        getCardsRef(
          player
        );


      // =====================================================
      // MAX TOTAL CARDS
      // =====================================================

      if (
        list.value.length >=
        maxTotalCards
      ) {

        return null;

      }


      // =====================================================
      // VALIDATE ACTIVE CAPACITY
      // =====================================================

      if (
        zone ===
          "active"

        &&

        activeCards(
          player
        ).length >=
          maxActive
      ) {

        return null;

      }


      // =====================================================
      // VALIDATE BENCH CAPACITY
      // =====================================================

      if (
        zone ===
          "bench"

        &&

        benchCards(
          player
        ).length >=
          maxBench
      ) {

        return null;

      }


      const card =
        createBattleCard(
          {
            ...cardData,

            zone,
          },

          uid
        );


      list.value.push(
        card
      );


      return card;

    };


  // =========================================================
  // REPLACE PLAYER CARDS
  // =========================================================

  const replaceCards =
    (
      player,
      incomingCards
    ) => {

      const list =
        getCardsRef(
          player
        );


      list.value =
        (
          incomingCards ||
          []
        )
          .slice(
            0,
            maxTotalCards
          )
          .map(
            card =>

              createBattleCard(
                card,
                card?.uid
              )

          );

    };


  // =========================================================
  // GET CARD ID
  // =========================================================

  const getCardIdentity =
    card => {

      return (

        card?.battleId ??

        card?.battle_id ??

        card?.id ??

        card?.uid ??

        null

      );

    };


  // =========================================================
  // FIND CARD
  // =========================================================

  const findCard =
    (
      player,
      targetCard
    ) => {

      if (
        !targetCard
      ) {

        return null;

      }


      const targetId =
        getCardIdentity(
          targetCard
        );


      if (
        targetId ===
        null
      ) {

        return null;

      }


      return (

        getCardsRef(
          player
        ).value.find(
          card =>

            getCardIdentity(
              card
            ) ===
            targetId
        )

        ??

        null

      );

    };


  // =========================================================
  // REMOVE CARD
  // =========================================================

  const removeCard =
    (
      player,
      targetCard
    ) => {

      const list =
        getCardsRef(
          player
        );


      const targetId =
        getCardIdentity(
          targetCard
        );


      if (
        targetId ===
        null
      ) {

        return false;

      }


      const before =
        list.value.length;


      list.value =
        list.value.filter(
          card =>

            getCardIdentity(
              card
            ) !==
            targetId
        );


      return (
        list.value.length <
        before
      );

    };


  // =========================================================
  // OWNS CARD
  // =========================================================

  const ownsCard =
    (
      player,
      card
    ) => {

      return Boolean(
        findCard(
          player,
          card
        )
      );

    };


  // =========================================================
  // OWNS ACTIVE CARD
  // =========================================================

  const ownsActiveCard =
    (
      player,
      card
    ) => {

      if (
        !card
      ) {

        return false;

      }


      const targetId =
        getCardIdentity(
          card
        );


      return activeCards(
        player
      ).some(
        item =>

          getCardIdentity(
            item
          ) ===
          targetId
      );

    };


  // =========================================================
  // SELECTED CARD BELONGS TO PLAYER
  //
  // API yang digunakan useBattleSkills
  // dan useBattleSynergy.
  // =========================================================

  const selectedCardBelongsTo =
    (
      player,
      card
    ) => {

      return ownsActiveCard(
        player,
        card
      );

    };


  // =========================================================
  // RESET
  // =========================================================

  const resetCards =
    () => {

      player1Cards.value =
        [];


      player2Cards.value =
        [];


      battleCardCounter =
        0;

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // RAW CARDS
    // =======================================================

    player1Cards,

    player2Cards,


    // =======================================================
    // ACTIVE COMPUTED
    // =======================================================

    player1ActiveCards,

    player2ActiveCards,


    // =======================================================
    // BENCH COMPUTED
    // =======================================================

    player1BenchCards,

    player2BenchCards,


    // =======================================================
    // SUMMON COMPUTED
    // =======================================================

    player1CanSummon,

    player2CanSummon,


    // =======================================================
    // REFERENCES
    // =======================================================

    getCardsRef,


    // =======================================================
    // ACTIVE / BENCH
    // =======================================================

    activeCards,

    benchCards,

    getActiveCards,

    getBenchCards,


    // =======================================================
    // CARD HELPERS
    // =======================================================

    totalCards,

    createBattleCard,

    normalizeSharedCard,

    addCard,

    replaceCards,

    removeCard,

    findCard,

    getCardIdentity,


    // =======================================================
    // OWNERSHIP
    // =======================================================

    ownsCard,

    ownsActiveCard,

    selectedCardBelongsTo,


    // =======================================================
    // CAPACITY
    // =======================================================

    canSummon,

    canAddToBench,


    // =======================================================
    // CONFIG
    // =======================================================

    maxActive,

    maxBench,

    maxTotalCards,


    // =======================================================
    // RESET
    // =======================================================

    resetCards,

  };

};