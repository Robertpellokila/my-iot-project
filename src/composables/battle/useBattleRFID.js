import {
  ref,
  onUnmounted,
} from "vue";


export const useBattleRFID = ({
  supabase,

  cards,

  battleState,
  currentTurn,
  winner,

  selectedTurnAction,

  summonMode,
  swapMode,

  isActing,

  questionMode = null,

  player1BattleHp,
  player2BattleHp,

  player1MaxHp,
  player2MaxHp,

  basePlayerHp = 200,

  fetchCardData,

  summonBattleCard,

  playSound = null,

  setProfileEffect = null,

  showProfileMessage = null,

  enabled = true,

  readerMap = {
    "RC522-P1": "p1",
    "RC522-P2": "p2",
  },
} = {}) => {


  // =========================================================
  // READER PROCESSING STATE
  // =========================================================

  const readerProcessing =
    ref({
      p1: false,
      p2: false,
    });


  // =========================================================
  // UID TRACKING
  // =========================================================

  /*
   * UID yang sedang diproses.
   *
   * Mencegah dua reader memproses
   * UID yang sama secara bersamaan.
   */
  const pendingUids =
    new Set();


  /*
   * UID yang sudah berhasil digunakan
   * dalam battle saat ini.
   */
  const usedUids =
    new Set();


  // =========================================================
  // BATTLE GENERATION
  // =========================================================

  /*
   * Digunakan agar request RFID lama
   * tidak ikut masuk setelah RESET.
   */
  let battleGeneration =
    0;


  // =========================================================
  // REALTIME CHANNEL
  // =========================================================

  let realtimeChannel =
    null;


  // =========================================================
  // ENABLED CHECK
  // =========================================================

  const isEnabled =
    () => {

      return Boolean(
        enabled?.value ??
        enabled
      );

    };


  // =========================================================
  // QUESTION CHECK
  // =========================================================

  const isQuestionActive =
    () => {

      return Boolean(
        questionMode?.value ??
        questionMode
      );

    };


  // =========================================================
  // NORMALIZE UID
  // =========================================================

  const normalizeUid =
    uid => {

      return String(
        uid ??
        ""
      )
        .trim()
        .toUpperCase();

    };


  // =========================================================
  // GET PLAYER CARDS
  // =========================================================

  const getPlayerCards =
    player => {

      return cards
        .getCardsRef(
          player
        )
        .value;

    };


  // =========================================================
  // GET HP REF
  // =========================================================

  const getHpRef =
    player => {

      return (
        player === "p1"
          ? player1BattleHp
          : player2BattleHp
      );

    };


  // =========================================================
  // GET MAX HP REF
  // =========================================================

  const getMaxHpRef =
    player => {

      return (
        player === "p1"
          ? player1MaxHp
          : player2MaxHp
      );

    };


  // =========================================================
  // IS READER BUSY
  //
  // Digunakan useBattleEngine untuk
  // mencegah CANCEL SUMMON saat RFID
  // sedang diproses.
  // =========================================================

  const isReaderBusy =
    player => {

      return Boolean(
        readerProcessing
          .value[
            player
          ]
      );

    };


  // =========================================================
  // SHOW WARNING
  // =========================================================

  const showReaderWarning =
    (
      player,
      message
    ) => {

      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "warning"
        );

      }


      if (
        typeof showProfileMessage ===
        "function"
      ) {

        showProfileMessage(
          player,
          `⚠ ${message}`
        );

      }

    };


  // =========================================================
  // REFRESH INITIAL BATTLE STATE
  // =========================================================

  const refreshInitialBattleState =
    () => {

      /*
       * Kalau battle sudah berjalan
       * jangan ubah state initial lagi.
       */
      if (
        winner.value
        ||
        battleState.value ===
          "battle_ready"
      ) {

        return;

      }


      const p1Ready =
        cards
          .player1Cards
          .value
          .length >
        0;


      const p2Ready =
        cards
          .player2Cards
          .value
          .length >
        0;


      const p1Busy =
        readerProcessing
          .value
          .p1;


      const p2Busy =
        readerProcessing
          .value
          .p2;


      // =====================================================
      // BOTH PLAYERS READY
      // =====================================================

      if (
        p1Ready
        &&
        p2Ready
        &&
        !p1Busy
        &&
        !p2Busy
      ) {

        currentTurn.value =
          "p1";


        battleState.value =
          "battle_ready";


        return;

      }


      // =====================================================
      // PLAYER 1 PROCESSING
      // =====================================================

      if (
        p1Busy
        &&
        !p1Ready
      ) {

        battleState.value =
          "summoning_p1";


        return;

      }


      // =====================================================
      // PLAYER 2 PROCESSING
      // =====================================================

      if (
        p2Busy
        &&
        !p2Ready
      ) {

        battleState.value =
          "summoning_p2";


        return;

      }


      // =====================================================
      // WAIT PLAYER 1
      // =====================================================

      if (
        !p1Ready
      ) {

        battleState.value =
          "waiting_p1";


        return;

      }


      // =====================================================
      // WAIT PLAYER 2
      // =====================================================

      battleState.value =
        "waiting_p2";

    };


  // =========================================================
  // PROCESS INITIAL CARD
  // =========================================================

  const processInitialCard =
    async (
      player,
      cardData,
      uid
    ) => {

      // =====================================================
      // PLAYER ALREADY HAS INITIAL CARD
      // =====================================================

      if (
        getPlayerCards(
          player
        ).length >
        0
      ) {

        return false;

      }


      // =====================================================
      // HP FROM CARD
      // =====================================================

      const hpGain =
        Math.max(
          0,

          Number(
            cardData?.hp
          ) || 0
        );


      // =====================================================
      // ADD INITIAL CARD
      // =====================================================

      const card =
        cards.addCard(
          player,

          cardData,

          uid,

          {
            zone: "active",
          }
        );


      if (
        !card
      ) {

        return false;

      }


      // =====================================================
      // INITIAL HP
      //
      // BASE HP + CARD HP
      // =====================================================

      getMaxHpRef(
        player
      ).value =
        basePlayerHp +
        hpGain;


      getHpRef(
        player
      ).value =
        basePlayerHp +
        hpGain;


      // =====================================================
      // MARK UID USED
      // =====================================================

      usedUids.add(
        uid
      );


      // =====================================================
      // SUMMON SOUND
      // =====================================================

      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "summon"
        );

      }


      // =====================================================
      // SUMMON EFFECT
      //
      // Initial scan source menggunakan
      // effect summon.
      // =====================================================

      if (
        typeof setProfileEffect ===
        "function"
      ) {

        setProfileEffect(
          player,

          "summon",

          `✨ +${hpGain} HP`,

          700
        );

      }


      return true;

    };


  // =========================================================
  // HANDLE RFID SCAN
  // =========================================================

  const handleReaderScan =
    async payload => {

      // =====================================================
      // DISABLED
      // =====================================================

      if (
        !isEnabled()
      ) {

        return;

      }


      // =====================================================
      // EVENT DATA
      // =====================================================

      const event =
        payload?.new ??
        payload;


      const deviceId =
        String(
          event?.device_id ??
          ""
        ).trim();


      const player =
        readerMap[
          deviceId
        ];


      const uid =
        normalizeUid(
          event?.uid
        );


      // =====================================================
      // INVALID EVENT
      // =====================================================

      if (
        !player
        ||
        !uid
        ||
        winner.value
      ) {

        return;

      }


      // =====================================================
      // SAME READER BUSY
      // =====================================================

      if (
        readerProcessing
          .value[
            player
          ]
      ) {

        return;

      }


      const isInitial =
        battleState.value !==
        "battle_ready";


      // =====================================================
      // INITIAL SCAN
      // =====================================================

      if (
        isInitial
      ) {

        /*
         * Player hanya boleh mempunyai
         * satu initial card.
         */
        if (
          getPlayerCards(
            player
          ).length >
          0
        ) {

          return;

        }

      }


      // =====================================================
      // BATTLE SCAN
      // =====================================================

      else {

        // ===================================================
        // CODING QUESTION ACTIVE
        // ===================================================

        if (
          isQuestionActive()
        ) {

          showReaderWarning(
            player,
            "QUESTION IN PROGRESS"
          );


          return;

        }


        // ===================================================
        // WRONG PLAYER
        // ===================================================

        if (
          currentTurn.value !==
          player
        ) {

          showReaderWarning(
            player,

            currentTurn.value ===
              "p1"

              ? "WAIT FOR PLAYER 1 TURN"

              : "WAIT FOR PLAYER 2 TURN"
          );


          return;

        }


        // ===================================================
        // SUMMON BUTTON NOT PRESSED
        // ===================================================

        if (
          !summonMode.value
          ||
          selectedTurnAction.value !==
            "summon"
        ) {

          showReaderWarning(
            player,
            "PRESS SUMMON FIRST"
          );


          return;

        }


        // ===================================================
        // BATTLE BUSY
        // ===================================================

        if (
          isActing.value
          ||
          swapMode.value
        ) {

          return;

        }


        // ===================================================
        // CANNOT SUMMON
        // ===================================================

        if (
          !cards.canSummon(
            player
          )
        ) {

          showReaderWarning(
            player,
            "ACTIVE DECK FULL"
          );


          return;

        }

      }


      // =====================================================
      // DUPLICATE UID
      // =====================================================

      if (
        usedUids.has(
          uid
        )
        ||
        pendingUids.has(
          uid
        )
      ) {

        console.warn(
          "RFID UID sudah digunakan:",
          uid
        );


        return;

      }


      // =====================================================
      // SAVE GENERATION
      // =====================================================

      const generation =
        battleGeneration;


      // =====================================================
      // LOCK READER
      // =====================================================

      readerProcessing
        .value[
          player
        ] =
          true;


      pendingUids.add(
        uid
      );


      // =====================================================
      // UPDATE INITIAL DISPLAY
      // =====================================================

      if (
        isInitial
      ) {

        refreshInitialBattleState();

      }


      let committed =
        false;


      try {

        // ===================================================
        // FETCH CARD DATA
        // ===================================================

        const cardData =
          await fetchCardData(
            uid
          );


        // ===================================================
        // RESET HAPPENED WHILE FETCHING
        // ===================================================

        if (
          generation !==
            battleGeneration
        ) {

          return;

        }


        // ===================================================
        // CARD NOT FOUND
        // ===================================================

        if (
          !cardData
        ) {

          showReaderWarning(
            player,
            "CARD NOT FOUND"
          );


          return;

        }


        // ===================================================
        // INITIAL CARD
        // ===================================================

        if (
          isInitial
        ) {

          /*
           * Validasi ulang karena selama
           * fetch Supabase state dapat berubah.
           */

          if (
            battleState.value ===
              "battle_ready"
            ||
            getPlayerCards(
              player
            ).length >
              0
          ) {

            return;

          }


          committed =
            await processInitialCard(
              player,
              cardData,
              uid
            );

        }


        // ===================================================
        // BATTLE SUMMON
        // ===================================================

        else {

          /*
           * Validasi ulang setelah fetch.
           *
           * Penting karena user bisa:
           * - cancel summon
           * - turn berubah
           * - question muncul
           * selama query sedang berjalan.
           */
          if (
            battleState.value !==
              "battle_ready"
            ||
            currentTurn.value !==
              player
            ||
            !summonMode.value
            ||
            selectedTurnAction.value !==
              "summon"
            ||
            isActing.value
            ||
            isQuestionActive()
          ) {

            return;

          }


          // =================================================
          // SUMMON THROUGH BATTLE ENGINE
          // =================================================

          const result =
            await summonBattleCard(
              cardData,
              uid
            );


          committed =
            result !==
              false;


          // =================================================
          // ONLY MARK UID USED WHEN SUMMON SUCCESS
          // =================================================

          if (
            committed
          ) {

            usedUids.add(
              uid
            );

          }

        }

      }


      catch (
        error
      ) {

        console.error(
          `RFID ${deviceId} gagal diproses:`,
          error
        );


        showReaderWarning(
          player,
          "RFID ERROR"
        );

      }


      finally {

        /*
         * Kalau RESET sudah dilakukan,
         * jangan ubah state battle baru.
         */
        if (
          generation ===
            battleGeneration
        ) {

          // =================================================
          // REMOVE PENDING UID
          // =================================================

          pendingUids.delete(
            uid
          );


          // =================================================
          // REMOVE USED IF FAILED
          // =================================================

          if (
            !committed
          ) {

            usedUids.delete(
              uid
            );

          }


          // =================================================
          // UNLOCK READER
          // =================================================

          readerProcessing
            .value[
              player
            ] =
              false;


          // =================================================
          // REFRESH INITIAL STATE
          // =================================================

          if (
            isInitial
          ) {

            refreshInitialBattleState();

          }

        }

      }

    };


  // =========================================================
  // SETUP REALTIME LISTENER
  // =========================================================

  const setupBattleListener =
    () => {

      // =====================================================
      // PUBLIC TV / DISABLED
      // =====================================================

      if (
        !isEnabled()
      ) {

        return;

      }


      // =====================================================
      // ALREADY SUBSCRIBED
      // =====================================================

      if (
        realtimeChannel
      ) {

        return;

      }


      realtimeChannel =
        supabase
          .channel(
            "arena_listener"
          )
          .on(
            "postgres_changes",

            {
              event:
                "INSERT",

              schema:
                "public",

              table:
                "scan_events",
            },

            payload => {

              void handleReaderScan(
                payload
              );

            }
          )
          .subscribe(
            status => {

              if (
                status ===
                  "CHANNEL_ERROR"

                ||

                status ===
                  "TIMED_OUT"
              ) {

                console.error(
                  "Supabase Realtime arena:",
                  status
                );

              }

            }
          );

    };


  // =========================================================
  // STOP REALTIME LISTENER
  // =========================================================

  const stopBattleListener =
    async () => {

      if (
        !realtimeChannel
      ) {

        return;

      }


      await supabase
        .removeChannel(
          realtimeChannel
        );


      realtimeChannel =
        null;

    };


  // =========================================================
  // RESET RFID
  // =========================================================

  const resetRFID =
    () => {

      /*
       * Membatalkan semua async request
       * dari battle sebelumnya.
       */
      battleGeneration +=
        1;


      // =====================================================
      // RESET READER STATE
      // =====================================================

      readerProcessing.value =
        {
          p1: false,
          p2: false,
        };


      // =====================================================
      // RESET UID
      // =====================================================

      pendingUids.clear();


      usedUids.clear();

    };


  // =========================================================
  // CLEANUP
  // =========================================================

  onUnmounted(
    () => {

      void stopBattleListener();

    }
  );


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // STATE
    // =======================================================

    readerProcessing,

    pendingUids,

    usedUids,


    // =======================================================
    // HELPERS
    // =======================================================

    normalizeUid,

    isReaderBusy,

    showReaderWarning,

    refreshInitialBattleState,


    // =======================================================
    // RFID HANDLER
    // =======================================================

    handleReaderScan,


    // =======================================================
    // REALTIME
    // =======================================================

    setupBattleListener,

    stopBattleListener,


    // =======================================================
    // RESET
    // =======================================================

    resetRFID,

  };

};