import {
  ref,
  computed,
  onUnmounted,
} from "vue";

import {
  getBattleByCode,
  getBattleCards,
  subscribeBattle,
} from "../../services/battleService";

import {
  supabase,
} from "../../lib/supabase";


export const useBattleSession =
  () => {

    // =======================================================
    // STATE
    // =======================================================

    const battle =
      ref(null);


    const cards =
      ref([]);


    const loading =
      ref(false);


    const error =
      ref(null);


    const latestBattleEvent =
      ref(null);


    // =======================================================
    // QUESTION
    // =======================================================

    const currentQuestion =
      ref(null);


    const currentQuestionRound =
      ref(null);


    const questionLoading =
      ref(false);


    const questionError =
      ref(null);


    // =======================================================
    // REALTIME
    // =======================================================

    let channel =
      null;


    let questionChannel =
      null;


    // =======================================================
    // NORMALIZERS
    // =======================================================

    const normalizePlayer =
      value => {

        const player =
          String(
            value ??
            ""
          )
            .trim()
            .toLowerCase();


        return (
          player === "p2"
            ? "p2"
            : "p1"
        );

      };


    const normalizeZone =
      value => {

        return (
          String(
            value ??
            ""
          )
            .trim()
            .toLowerCase() ===
          "bench"

            ? "bench"

            : "active"
        );

      };


    // =======================================================
    // NORMALIZE CARD
    // =======================================================

    const normalizeBattleCard =
      card => {

        if (
          !card
        ) {

          return null;

        }


        /*
         * PENTING:
         *
         * battle_id = ID session.
         *
         * Jadi jangan memakai battle_id sebagai
         * identity setiap card.
         *
         * battleId dipakai oleh component battle
         * sebagai identity card.
         */

        const cardIdentity =
          card.battleId ??
          card.battle_card_id ??
          card.id ??
          card.card_id ??
          card.game_card_id ??
          `${card.player ?? "p1"}-${card.uid ?? Math.random()}`;


        return {

          ...card,


          // =================================================
          // CARD IDENTITY
          // =================================================

          battleId:
            cardIdentity,


          // =================================================
          // SESSION
          // =================================================

          battleSessionId:
            card.battleSessionId ??
            card.battle_id ??
            null,


          // =================================================
          // ORIGINAL GAME CARD
          // =================================================

          gameCardId:
            card.gameCardId ??
            card.game_card_id ??
            card.card_id ??
            null,


          // =================================================
          // PLAYER
          // =================================================

          player:
            normalizePlayer(
              card.player ??
              card.owner ??
              card.player_id
            ),


          // =================================================
          // CARD DATA
          // =================================================

          uid:
            String(
              card.uid ??
              ""
            )
              .trim()
              .toUpperCase(),


          name:
            card.name ??
            card.nama ??
            card.card_name ??
            "Unknown Card",


          hp:
            Math.max(
              0,
              Number(
                card.hp
              ) || 0
            ),


          attack:
            Math.max(
              0,
              Number(
                card.attack
              ) || 0
            ),


          element:
            String(
              card.element ??
              ""
            )
              .trim()
              .toLowerCase(),


          image_url:
            card.image_url ??
            card.image ??
            card.imageUrl ??
            null,


          // =================================================
          // ZONE
          // =================================================

          zone:
            normalizeZone(
              card.zone
            ),


          benchReturnCount:
            Math.max(
              0,
              Number(
                card.benchReturnCount ??
                card.bench_return_count ??
                0
              ) || 0
            ),


          exhausted:
            Boolean(
              card.exhausted
            ),

        };

      };


    // =======================================================
    // NORMALIZE QUESTION OPTIONS
    // =======================================================

    const normalizeQuestionOptions =
      row => {

        if (
          !row
        ) {

          return [];

        }


        // Array format
        if (
          Array.isArray(
            row.options
          )
        ) {

          return row.options;

        }


        // JSON object format
        if (
          row.options
          &&
          typeof row.options ===
            "object"
        ) {

          return Object.values(
            row.options
          );

        }


        // option_a ... option_d
        return [

          row.option_a,
          row.option_b,
          row.option_c,
          row.option_d,

        ].filter(
          option =>
            option !==
              undefined
            &&
            option !==
              null
            &&
            String(option)
              .trim() !==
              ""
        );

      };


    // =======================================================
    // NORMALIZE QUESTION
    // =======================================================

    const normalizeQuestion =
      row => {

        if (
          !row
        ) {

          return null;

        }


        return {

          id:
            row.id,


          question:
            row.question ??
            row.question_text ??
            row.text ??
            row.title ??
            "",


          code:
            row.code ??
            row.code_snippet ??
            row.snippet ??
            "",


          options:
            normalizeQuestionOptions(
              row
            ),


          level:
            row.level ??
            "medium",


          /*
           * Jangan expose correct answer
           * sebagai kebutuhan UI public.
           *
           * Kalau row dari DB mengandung field tersebut,
           * kita sengaja tidak menggunakannya.
           */

        };

      };


    // =======================================================
    // PLAYER CARDS
    // =======================================================

    const player1Cards =
      computed(
        () =>
          cards.value.filter(
            card =>
              card.player ===
              "p1"
          )
      );


    const player2Cards =
      computed(
        () =>
          cards.value.filter(
            card =>
              card.player ===
              "p2"
          )
      );


    // =======================================================
    // ACTIVE CARDS
    // =======================================================

    const player1Active =
      computed(
        () =>
          player1Cards.value.filter(
            card =>
              card.zone ===
                "active"
              &&
              !card.exhausted
          )
      );


    const player2Active =
      computed(
        () =>
          player2Cards.value.filter(
            card =>
              card.zone ===
                "active"
              &&
              !card.exhausted
          )
      );


    // =======================================================
    // BENCH
    // =======================================================

    const player1Bench =
      computed(
        () =>
          player1Cards.value.filter(
            card =>
              card.zone ===
              "bench"
          )
      );


    const player2Bench =
      computed(
        () =>
          player2Cards.value.filter(
            card =>
              card.zone ===
              "bench"
          )
      );


    // =======================================================
    // SESSION CONFIG
    // =======================================================

    const battleCode =
      computed(
        () =>
          battle.value?.code ??
          ""
      );


    const battleStatus =
      computed(
        () =>
          battle.value?.status ??
          "waiting"
      );


    const round =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value?.round ??
              1
            )
          )
      );


    const totalRounds =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value?.total_rounds ??
              1
            )
          )
      );


    const currentTurn =
      computed(
        () =>
          normalizePlayer(
            battle.value
              ?.current_turn
          )
      );


    const startingPlayer =
      computed(
        () =>
          normalizePlayer(
            battle.value
              ?.starting_player
          )
      );


    // =======================================================
    // PLAYERS
    // =======================================================

    const player1Name =
      computed(
        () =>
          battle.value
            ?.player1_name ??
          "Player 1"
      );


    const player2Name =
      computed(
        () =>
          battle.value
            ?.player2_name ??
          "Player 2"
      );


    // =======================================================
    // QUESTION CONFIG
    // =======================================================

    const questionEnabled =
      computed(
        () =>
          Boolean(
            battle.value
              ?.question_enabled
          )
      );


    const questionActive =
      computed(
        () =>
          Boolean(
            battle.value
              ?.question_active
          )
          ||
          battle.value?.status ===
            "question"
      );


    const questionLevel =
      computed(
        () =>
          battle.value
            ?.question_level ??
          "medium"
      );


    const questionEveryRounds =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value
                ?.question_every_rounds ??
              5
            )
          )
      );


    // =======================================================
    // DECK CONFIG
    // =======================================================

    const deckSize =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value
                ?.deck_size ??
              8
            )
          )
      );


    const initialCardsRequired =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value
                ?.initial_cards_required ??
              1
            )
          )
      );


    const maxActive =
      computed(
        () =>
          Math.max(
            1,
            Number(
              battle.value
                ?.max_active ??
              4
            )
          )
      );


    const maxBench =
      computed(
        () =>
          Math.max(
            0,
            Number(
              battle.value
                ?.max_bench ??
              4
            )
          )
      );


    // =======================================================
    // STOP QUESTION REALTIME
    // =======================================================

    const stopQuestionRealtime =
      async () => {

        if (
          !questionChannel
        ) {

          return;

        }


        try {

          await supabase
            .removeChannel(
              questionChannel
            );

        }

        catch (
          err
        ) {

          console.warn(
            "Gagal melepas question channel:",
            err
          );

        }

        finally {

          questionChannel =
            null;

        }

      };


    // =======================================================
    // STOP MAIN REALTIME
    // =======================================================

    const stopRealtime =
      async () => {

        if (
          channel
        ) {

          try {

            await supabase
              .removeChannel(
                channel
              );

          }

          catch (
            err
          ) {

            console.warn(
              "Gagal melepas battle channel:",
              err
            );

          }

          finally {

            channel =
              null;

          }

        }


        await stopQuestionRealtime();

      };


    // =======================================================
    // RELOAD CARDS
    // =======================================================

    const reloadCards =
      async () => {

        if (
          !battle.value?.id
        ) {

          cards.value =
            [];


          return [];

        }


        try {

          const data =
            await getBattleCards(
              battle.value.id
            );


          cards.value =
            (
              data ??
              []
            )
              .map(
                normalizeBattleCard
              )
              .filter(
                Boolean
              );


          return cards.value;

        }

        catch (
          err
        ) {

          console.error(
            "Gagal reload battle cards:",
            err
          );


          throw err;

        }

      };


    // =======================================================
    // FETCH QUESTION BY ID
    // =======================================================

    const fetchQuestionById =
      async questionId => {

        if (
          !questionId
        ) {

          currentQuestion.value =
            null;


          return null;

        }


        questionLoading.value =
          true;


        questionError.value =
          null;


        try {

          /*
           * Kita select * karena schema question project-mu
           * sebelumnya sudah memiliki beberapa variasi field.
           *
           * normalizeQuestion() hanya mengekspos field
           * yang dibutuhkan public UI.
           */

          const {
            data,
            error:
              fetchError,
          } =
            await supabase
              .from(
                "coding_questions"
              )
              .select("*")
              .eq(
                "id",
                questionId
              )
              .maybeSingle();


          if (
            fetchError
          ) {

            throw fetchError;

          }


          currentQuestion.value =
            normalizeQuestion(
              data
            );


          return currentQuestion.value;

        }

        catch (
          err
        ) {

          console.error(
            "Gagal mengambil coding question:",
            err
          );


          questionError.value =
            err?.message ??
            "Pertanyaan gagal dimuat.";


          currentQuestion.value =
            null;


          return null;

        }

        finally {

          questionLoading.value =
            false;

        }

      };


    // =======================================================
    // LOAD QUESTION ROUND
    // =======================================================

    const loadQuestionRound =
      async () => {

        if (
          !battle.value?.id
        ) {

          currentQuestionRound.value =
            null;

          currentQuestion.value =
            null;


          return null;

        }


        /*
         * Kalau question tidak sedang aktif,
         * bersihkan UI question.
         */

        if (
          !questionActive.value
        ) {

          currentQuestionRound.value =
            null;

          currentQuestion.value =
            null;

          questionError.value =
            null;


          return null;

        }


        try {

          let questionRound =
            null;


          // =================================================
          // BY CURRENT QUESTION ROUND ID
          // =================================================

          if (
            battle.value
              ?.current_question_round_id
          ) {

            const {
              data,
              error:
                roundError,
            } =
              await supabase
                .from(
                  "battle_question_rounds"
                )
                .select("*")
                .eq(
                  "id",
                  battle.value
                    .current_question_round_id
                )
                .maybeSingle();


            if (
              roundError
            ) {

              throw roundError;

            }


            questionRound =
              data;

          }


          // =================================================
          // FALLBACK: ACTIVE QUESTION FOR BATTLE
          // =================================================

          if (
            !questionRound
          ) {

            const {
              data,
              error:
                activeError,
            } =
              await supabase
                .from(
                  "battle_question_rounds"
                )
                .select("*")
                .eq(
                  "battle_id",
                  battle.value.id
                )
                .eq(
                  "status",
                  "active"
                )
                .order(
                  "created_at",
                  {
                    ascending:
                      false,
                  }
                )
                .limit(1)
                .maybeSingle();


            if (
              activeError
            ) {

              throw activeError;

            }


            questionRound =
              data;

          }


          currentQuestionRound.value =
            questionRound;


          const questionId =
            questionRound
              ?.question_id
            ??
            battle.value
              ?.current_question_id
            ??
            null;


          if (
            questionId
          ) {

            await fetchQuestionById(
              questionId
            );

          }

          else {

            currentQuestion.value =
              null;

          }


          return questionRound;

        }

        catch (
          err
        ) {

          console.error(
            "Gagal load question round:",
            err
          );


          questionError.value =
            err?.message ??
            "Coding challenge gagal dimuat.";


          return null;

        }

      };


    // =======================================================
    // QUESTION REALTIME
    // =======================================================

    const startQuestionRealtime =
      async battleId => {

        if (
          !battleId
        ) {

          return;

        }


        await stopQuestionRealtime();


        questionChannel =
          supabase
            .channel(
              `battle_question_${battleId}_${Date.now()}`
            )

            // ===============================================
            // QUESTION ROUND
            // ===============================================

            .on(
              "postgres_changes",

              {
                event:
                  "*",

                schema:
                  "public",

                table:
                  "battle_question_rounds",

                filter:
                  `battle_id=eq.${battleId}`,
              },

              payload => {

                const row =
                  payload.new ??
                  payload.old ??
                  null;


                if (
                  row
                ) {

                  currentQuestionRound.value =
                    row;

                }


                /*
                 * Fetch ulang agar question_id/winner/status
                 * selalu sinkron.
                 */

                void loadQuestionRound();

              }
            )

            // ===============================================
            // ANSWERS
            //
            // Public TV tidak butuh isi answer,
            // tetapi perubahan answer dapat mengubah
            // winner question.
            // ===============================================

            .on(
              "postgres_changes",

              {
                event:
                  "INSERT",

                schema:
                  "public",

                table:
                  "battle_question_answers",
              },

              payload => {

                /*
                 * Filter manual karena FK ada pada
                 * battle_question_id, bukan battle_id.
                 */

                if (
                  payload.new
                    ?.battle_question_id
                  &&
                  currentQuestionRound
                    .value
                    ?.id ===
                    payload.new
                      .battle_question_id
                ) {

                  void loadQuestionRound();

                }

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
                    "Question realtime:",
                    status
                  );

                }

              }
            );

      };


    // =======================================================
    // HANDLE BATTLE UPDATE
    // =======================================================

    const handleBattleUpdate =
      async newBattle => {

        if (
          !newBattle
        ) {

          return;

        }


        const previousQuestionActive =
          questionActive.value;


        const previousQuestionId =
          battle.value
            ?.current_question_id;


        const previousRoundId =
          battle.value
            ?.current_question_round_id;


        battle.value =
          newBattle;


        /*
         * Kalau question berubah atau baru dimulai,
         * load question baru.
         */

        const questionChanged =
          previousQuestionId !==
            newBattle
              .current_question_id

          ||

          previousRoundId !==
            newBattle
              .current_question_round_id

          ||

          previousQuestionActive !==
            questionActive.value;


        if (
          questionChanged
        ) {

          await loadQuestionRound();

        }

      };


    // =======================================================
    // HANDLE CARD UPDATE
    // =======================================================

    const handleCardsUpdate =
      async () => {

        try {

          await reloadCards();

        }

        catch (
          err
        ) {

          console.error(
            "Realtime card reload gagal:",
            err
          );

        }

      };


    // =======================================================
    // HANDLE EVENT
    // =======================================================

    const handleBattleEvent =
      event => {

        if (
          !event
        ) {

          return;

        }


        /*
         * Buat object baru supaya watcher BattleArena
         * selalu menerima reference baru.
         */

        latestBattleEvent.value = {
          ...event,
        };

      };


    // =======================================================
    // START REALTIME
    // =======================================================

    const startRealtime =
      async battleId => {

        if (
          !battleId
        ) {

          return;

        }


        await stopRealtime();


        /*
         * subscribeBattle menjadi SATU-SATUNYA
         * main battle realtime subscription.
         *
         * PublicBattleArena tidak perlu membuat
         * battleEventService subscription lagi.
         */

        channel =
          subscribeBattle(

            battleId,


            // ===============================================
            // BATTLE UPDATE
            // ===============================================

            newBattle => {

              void handleBattleUpdate(
                newBattle
              );

            },


            // ===============================================
            // CARD UPDATE
            // ===============================================

            () => {

              void handleCardsUpdate();

            },


            // ===============================================
            // BATTLE EVENT
            // ===============================================

            event => {

              handleBattleEvent(
                event
              );

            }

          );


        await startQuestionRealtime(
          battleId
        );

      };


    // =======================================================
    // LOAD BATTLE
    // =======================================================

    const loadBattle =
      async code => {

        const battleCodeValue =
          String(
            code ??
            ""
          )
            .trim()
            .toUpperCase();


        if (
          !battleCodeValue
        ) {

          error.value =
            "Kode battle tidak valid.";


          battle.value =
            null;


          cards.value =
            [];


          return null;

        }


        loading.value =
          true;


        error.value =
          null;


        questionError.value =
          null;


        latestBattleEvent.value =
          null;


        currentQuestion.value =
          null;


        currentQuestionRound.value =
          null;


        try {

          // ===============================================
          // STOP OLD SESSION
          // ===============================================

          await stopRealtime();


          // ===============================================
          // BATTLE
          // ===============================================

          const result =
            await getBattleByCode(
              battleCodeValue
            );


          if (
            !result
          ) {

            throw new Error(
              "Battle tidak ditemukan."
            );

          }


          battle.value =
            result;


          // ===============================================
          // CARDS
          // ===============================================

          await reloadCards();


          // ===============================================
          // QUESTION
          // ===============================================

          await loadQuestionRound();


          // ===============================================
          // REALTIME
          // ===============================================

          await startRealtime(
            battle.value.id
          );


          return battle.value;

        }

        catch (
          err
        ) {

          console.error(
            "Load battle gagal:",
            err
          );


          error.value =
            err?.message ??
            "Battle tidak ditemukan.";


          battle.value =
            null;


          cards.value =
            [];


          currentQuestion.value =
            null;


          currentQuestionRound.value =
            null;


          await stopRealtime();


          return null;

        }

        finally {

          loading.value =
            false;

        }

      };


    // =======================================================
    // REFRESH BATTLE
    // =======================================================

    const refreshBattle =
      async () => {

        if (
          !battle.value?.code
        ) {

          return null;

        }


        try {

          const result =
            await getBattleByCode(
              battle.value.code
            );


          if (
            result
          ) {

            battle.value =
              result;


            await Promise.all([
              reloadCards(),
              loadQuestionRound(),
            ]);

          }


          return battle.value;

        }

        catch (
          err
        ) {

          console.error(
            "Refresh battle gagal:",
            err
          );


          return null;

        }

      };


    // =======================================================
    // RESET
    // =======================================================

    const resetSession =
      async () => {

        await stopRealtime();


        battle.value =
          null;


        cards.value =
          [];


        error.value =
          null;


        loading.value =
          false;


        latestBattleEvent.value =
          null;


        currentQuestion.value =
          null;


        currentQuestionRound.value =
          null;


        questionLoading.value =
          false;


        questionError.value =
          null;

      };


    // =======================================================
    // CLEANUP
    // =======================================================

    onUnmounted(
      () => {

        void stopRealtime();

      }
    );


    // =======================================================
    // RETURN
    // =======================================================

    return {

      // =====================================================
      // SESSION
      // =====================================================

      battle,

      cards,


      // =====================================================
      // SESSION INFO
      // =====================================================

      battleCode,

      battleStatus,

      round,

      totalRounds,

      currentTurn,

      startingPlayer,


      // =====================================================
      // PLAYER INFO
      // =====================================================

      player1Name,

      player2Name,


      // =====================================================
      // PLAYER CARDS
      // =====================================================

      player1Cards,

      player2Cards,


      // =====================================================
      // ACTIVE
      // =====================================================

      player1Active,

      player2Active,


      // =====================================================
      // BENCH
      // =====================================================

      player1Bench,

      player2Bench,


      // =====================================================
      // DECK CONFIG
      // =====================================================

      deckSize,

      initialCardsRequired,

      maxActive,

      maxBench,


      // =====================================================
      // QUESTION CONFIG
      // =====================================================

      questionEnabled,

      questionActive,

      questionLevel,

      questionEveryRounds,


      // =====================================================
      // QUESTION STATE
      // =====================================================

      currentQuestion,

      currentQuestionRound,

      questionLoading,

      questionError,


      // =====================================================
      // EVENT
      // =====================================================

      latestBattleEvent,


      // =====================================================
      // GENERAL STATE
      // =====================================================

      loading,

      error,


      // =====================================================
      // NORMALIZERS
      // =====================================================

      normalizeBattleCard,

      normalizeQuestion,


      // =====================================================
      // FUNCTIONS
      // =====================================================

      loadBattle,

      refreshBattle,

      reloadCards,

      loadQuestionRound,

      fetchQuestionById,

      startRealtime,

      stopRealtime,

      resetSession,

    };

  };