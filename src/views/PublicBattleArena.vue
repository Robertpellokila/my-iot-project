<script setup>
import {
  computed,
  onMounted,
  watch,
} from "vue";

import {
  useRoute,
} from "vue-router";

import {
  useBattleSession,
} from "../composables/battle/useBattleSession";

import BattleArena
  from "./BattleArena.vue";


// =========================================================
// ROUTE
// =========================================================

const route =
  useRoute();


// =========================================================
// SESSION
// =========================================================

const {
  battle,

  player1Active,
  player2Active,

  player1Bench,
  player2Bench,

  latestBattleEvent,

  loading,
  error,

  currentQuestion,
  currentQuestionRound,
  questionActive,
  questionLoading,
  questionError,

  loadBattle,
  resetSession,
} =
  useBattleSession();


// =========================================================
// ROUTE CODE
// =========================================================

const routeCode =
  computed(
    () =>
      String(
        route.params.code ??
        ""
      )
        .trim()
        .toUpperCase()
  );


// =========================================================
// QUESTION DISPLAY
// =========================================================

const showQuestion =
  computed(
    () => {

      if (
        !battle.value
      ) {

        return false;

      }


      return (
        questionActive.value
        ||
        battle.value.status ===
          "question"
      );

    }
  );


// =========================================================
// QUESTION WINNER
// =========================================================

const questionWinner =
  computed(
    () =>
      currentQuestionRound
        .value
        ?.winner_player
      ??
      null
  );


const questionWinnerName =
  computed(
    () => {

      if (
        questionWinner.value ===
        "p1"
      ) {

        return (
          battle.value
            ?.player1_name ??
          "Player 1"
        );

      }


      if (
        questionWinner.value ===
        "p2"
      ) {

        return (
          battle.value
            ?.player2_name ??
          "Player 2"
        );

      }


      return "";

    }
  );


// =========================================================
// LOAD
// =========================================================

const loadCurrentBattle =
  async () => {

    if (
      !routeCode.value
    ) {

      return;

    }


    await loadBattle(
      routeCode.value
    );

  };


// =========================================================
// ROUTE CHANGE
// =========================================================

watch(
  routeCode,

  async (
    newCode,
    oldCode
  ) => {

    if (
      !newCode
      ||
      newCode ===
        oldCode
    ) {

      return;

    }


    await loadBattle(
      newCode
    );

  }
);


// =========================================================
// MOUNT
// =========================================================

onMounted(
  () => {

    void loadCurrentBattle();

  }
);

</script>


<template>
  <main class="public-battle-page">

    <!-- ===================================================
         LOADING
    ==================================================== -->

    <div
      v-if="loading"
      class="public-state"
    >

      <div class="state-spinner" />


      <strong>
        Loading Battle
      </strong>


      <span>
        Connecting to battle session...
      </span>

    </div>


    <!-- ===================================================
         ERROR
    ==================================================== -->

    <div
      v-else-if="error"
      class="
        public-state
        error
      "
    >

      <div class="state-icon">
        ⚠
      </div>


      <strong>
        Battle unavailable
      </strong>


      <span>
        {{ error }}
      </span>

    </div>


    <!-- ===================================================
         NOT FOUND
    ==================================================== -->

    <div
      v-else-if="
        !battle
      "
      class="
        public-state
        error
      "
    >

      <strong>
        Battle not found
      </strong>

    </div>


    <!-- ===================================================
         BATTLE
    ==================================================== -->

    <template v-else>

      <BattleArena
        :display-only="true"

        :shared-battle="
          battle
        "

        :shared-player1-active="
          player1Active
        "

        :shared-player2-active="
          player2Active
        "

        :shared-player1-bench="
          player1Bench
        "

        :shared-player2-bench="
          player2Bench
        "

        :latest-battle-event="
          latestBattleEvent
        "
      />


      <!-- =================================================
           PUBLIC CODING QUESTION

           TV hanya menampilkan soal.
           Jawaban dilakukan di PlayerBattle.
      ================================================== -->

      <Transition name="question-overlay">

        <div
          v-if="
            showQuestion
          "
          class="public-question-overlay"
        >

          <div class="question-backdrop" />


          <section class="question-card">

            <!-- ===========================================
                 TOP
            ============================================ -->

            <header class="question-header">

              <div>

                <div class="question-eyebrow">
                  CODING CHALLENGE
                </div>


                <h2>
                  Fastest Correct Answer Wins
                </h2>

              </div>


              <div class="question-meta">

                <span>
                  ROUND
                  {{
                    battle.round ??
                    1
                  }}
                </span>


                <span
                  v-if="
                    currentQuestion
                      ?.level
                  "
                  class="question-level"
                >
                  {{
                    currentQuestion.level
                      .toUpperCase()
                  }}
                </span>

              </div>

            </header>


            <!-- ===========================================
                 LOADING QUESTION
            ============================================ -->

            <div
              v-if="
                questionLoading
              "
              class="question-state"
            >

              <div class="small-spinner" />

              Loading question...

            </div>


            <!-- ===========================================
                 QUESTION ERROR
            ============================================ -->

            <div
              v-else-if="
                questionError
              "
              class="
                question-state
                question-error
              "
            >

              {{ questionError }}

            </div>


            <!-- ===========================================
                 QUESTION
            ============================================ -->

            <template
              v-else-if="
                currentQuestion
              "
            >

              <div class="question-content">

                <div class="question-number">
                  QUESTION
                </div>


                <div class="question-text">
                  {{
                    currentQuestion.question
                  }}
                </div>


                <!-- CODE -->

                <pre
                  v-if="
                    currentQuestion.code
                  "
                  class="question-code"
                ><code>{{ currentQuestion.code }}</code></pre>


                <!-- OPTIONS -->

                <div
                  v-if="
                    currentQuestion.options
                      ?.length
                  "
                  class="question-options"
                >

                  <div
                    v-for="
                      (
                        option,
                        index
                      ) in
                        currentQuestion.options
                    "
                    :key="
                      `${index}-${option}`
                    "
                    class="question-option"
                  >

                    <span class="option-letter">
                      {{
                        String.fromCharCode(
                          65 + index
                        )
                      }}
                    </span>


                    <span>
                      {{ option }}
                    </span>

                  </div>

                </div>

              </div>


              <!-- =========================================
                   PLAYER STATUS
              ========================================== -->

              <div class="question-player-status">

                <div
                  class="
                    question-player
                    blue
                  "
                  :class="{
                    winner:
                      questionWinner ===
                      'p1',
                  }"
                >

                  <span class="player-label">
                    PLAYER 1
                  </span>


                  <strong>
                    {{
                      battle.player1_name ??
                      "Player 1"
                    }}
                  </strong>


                  <span
                    v-if="
                      questionWinner ===
                      'p1'
                    "
                    class="winner-text"
                  >
                    ✓ FIRST CORRECT
                  </span>


                  <span
                    v-else-if="
                      questionWinner
                    "
                    class="waiting-text"
                  >
                    Challenge Finished
                  </span>


                  <span
                    v-else
                    class="waiting-text"
                  >
                    Waiting for answer...
                  </span>

                </div>


                <div class="question-vs">
                  VS
                </div>


                <div
                  class="
                    question-player
                    red
                  "
                  :class="{
                    winner:
                      questionWinner ===
                      'p2',
                  }"
                >

                  <span class="player-label">
                    PLAYER 2
                  </span>


                  <strong>
                    {{
                      battle.player2_name ??
                      "Player 2"
                    }}
                  </strong>


                  <span
                    v-if="
                      questionWinner ===
                      'p2'
                    "
                    class="winner-text"
                  >
                    ✓ FIRST CORRECT
                  </span>


                  <span
                    v-else-if="
                      questionWinner
                    "
                    class="waiting-text"
                  >
                    Challenge Finished
                  </span>


                  <span
                    v-else
                    class="waiting-text"
                  >
                    Waiting for answer...
                  </span>

                </div>

              </div>


              <!-- =========================================
                   WINNER
              ========================================== -->

              <div
                v-if="
                  questionWinner
                "
                class="question-winner-banner"
              >

                🏆

                <strong>
                  {{ questionWinnerName }}
                </strong>

                answered correctly first!

              </div>


              <div
                v-else
                class="answer-on-device"
              >
                Answer from each player's device
              </div>

            </template>


            <!-- ===========================================
                 NO QUESTION YET
            ============================================ -->

            <div
              v-else
              class="question-state"
            >
              Preparing coding challenge...
            </div>

          </section>

        </div>

      </Transition>

    </template>

  </main>
</template>


<style scoped>

/* =========================================================
   PAGE
========================================================= */

.public-battle-page {
  width:
    100%;

  min-height:
    100vh;

  margin:
    0;

  padding:
    0;

  position:
    relative;

  overflow:
    hidden;

  background:
    #020611;
}


/* =========================================================
   GENERAL STATE
========================================================= */

.public-state {
  min-height:
    100vh;

  display:
    flex;

  flex-direction:
    column;

  align-items:
    center;

  justify-content:
    center;

  gap:
    9px;

  color:
    #93a8c3;

  background:
    radial-gradient(
      circle at center,
      rgba(
        32,
        109,
        173,
        .15
      ),
      transparent
      40%
    ),
    #020611;

  font-family:
    Inter,
    system-ui,
    sans-serif;
}


.public-state strong {
  color:
    white;

  font-size:
    17px;
}


.public-state span {
  font-size:
    10px;
}


.public-state.error strong {
  color:
    #ff7894;
}


.state-icon {
  margin-bottom:
    4px;

  color:
    #ff6785;

  font-size:
    27px;
}


/* =========================================================
   SPINNER
========================================================= */

.state-spinner {
  width:
    32px;

  height:
    32px;

  margin-bottom:
    10px;

  border:
    3px solid
    rgba(
      255,
      255,
      255,
      .08
    );

  border-top-color:
    #58d8ff;

  border-radius:
    50%;

  animation:
    spin
    .7s
    linear
    infinite;
}


.small-spinner {
  width:
    21px;

  height:
    21px;

  border:
    2px solid
    rgba(
      255,
      255,
      255,
      .09
    );

  border-top-color:
    #5cdcff;

  border-radius:
    50%;

  animation:
    spin
    .7s
    linear
    infinite;
}


@keyframes spin {

  to {
    transform:
      rotate(
        360deg
      );
  }

}


/* =========================================================
   QUESTION OVERLAY
========================================================= */

.public-question-overlay {
  position:
    fixed;

  inset:
    0;

  z-index:
    1000;

  display:
    grid;

  place-items:
    center;

  padding:
    35px;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}


.question-backdrop {
  position:
    absolute;

  inset:
    0;

  background:
    rgba(
      0,
      5,
      16,
      .88
    );

  backdrop-filter:
    blur(
      8px
    );
}


/* =========================================================
   QUESTION CARD
========================================================= */

.question-card {
  width:
    min(
      100%,
      940px
    );

  max-height:
    calc(
      100vh -
      70px
    );

  position:
    relative;

  z-index:
    2;

  overflow-y:
    auto;

  padding:
    29px;

  border:
    1px solid
    rgba(
      88,
      202,
      255,
      .2
    );

  border-radius:
    20px;

  color:
    white;

  background:
    linear-gradient(
      145deg,
      rgba(
        8,
        27,
        58,
        .98
      ),
      rgba(
        3,
        11,
        27,
        .99
      )
    );

  box-shadow:
    0 30px 100px
    rgba(
      0,
      0,
      0,
      .65
    );
}


/* =========================================================
   QUESTION HEADER
========================================================= */

.question-header {
  display:
    flex;

  justify-content:
    space-between;

  align-items:
    flex-start;

  gap:
    20px;

  padding-bottom:
    19px;

  border-bottom:
    1px solid
    rgba(
      255,
      255,
      255,
      .07
    );
}


.question-eyebrow {
  margin-bottom:
    6px;

  color:
    #5cdbff;

  font-size:
    9px;

  font-weight:
    950;

  letter-spacing:
    .2em;
}


.question-header h2 {
  margin:
    0;

  font-size:
    22px;
}


.question-meta {
  display:
    flex;

  gap:
    7px;
}


.question-meta span {
  padding:
    7px
    10px;

  border:
    1px solid
    rgba(
      255,
      255,
      255,
      .08
    );

  border-radius:
    8px;

  color:
    #8da2bd;

  background:
    rgba(
      255,
      255,
      255,
      .025
    );

  font-size:
    8px;

  font-weight:
    900;
}


.question-meta
.question-level {
  color:
    #cfadff;

  border-color:
    rgba(
      168,
      100,
      255,
      .2
    );

  background:
    rgba(
      144,
      67,
      255,
      .07
    );
}


/* =========================================================
   QUESTION CONTENT
========================================================= */

.question-content {
  padding:
    24px
    0;
}


.question-number {
  margin-bottom:
    8px;

  color:
    #697f9c;

  font-size:
    8px;

  font-weight:
    950;

  letter-spacing:
    .15em;
}


.question-text {
  color:
    #edf7ff;

  font-size:
    20px;

  font-weight:
    800;

  line-height:
    1.45;
}


/* =========================================================
   CODE
========================================================= */

.question-code {
  margin:
    19px
    0
    0;

  padding:
    17px;

  overflow-x:
    auto;

  border:
    1px solid
    rgba(
      117,
      162,
      218,
      .1
    );

  border-radius:
    11px;

  color:
    #bfeaff;

  background:
    #020817;

  font-family:
    "SFMono-Regular",
    Consolas,
    "Liberation Mono",
    monospace;

  font-size:
    12px;

  line-height:
    1.6;

  white-space:
    pre-wrap;
}


/* =========================================================
   OPTIONS
========================================================= */

.question-options {
  display:
    grid;

  grid-template-columns:
    repeat(
      2,
      minmax(
        0,
        1fr
      )
    );

  gap:
    10px;

  margin-top:
    18px;
}


.question-option {
  min-height:
    55px;

  display:
    flex;

  align-items:
    center;

  gap:
    11px;

  padding:
    10px
    13px;

  border:
    1px solid
    rgba(
      115,
      157,
      207,
      .1
    );

  border-radius:
    10px;

  color:
    #acbfd5;

  background:
    rgba(
      255,
      255,
      255,
      .022
    );

  font-size:
    11px;
}


.option-letter {
  width:
    30px;

  height:
    30px;

  flex-shrink:
    0;

  display:
    grid;

  place-items:
    center;

  border:
    1px solid
    rgba(
      85,
      202,
      255,
      .2
    );

  border-radius:
    8px;

  color:
    #63d9ff;

  background:
    rgba(
      48,
      172,
      225,
      .07
    );

  font-size:
    10px;

  font-weight:
    950;
}


/* =========================================================
   QUESTION PLAYER STATUS
========================================================= */

.question-player-status {
  display:
    grid;

  grid-template-columns:
    1fr
    auto
    1fr;

  align-items:
    center;

  gap:
    15px;

  padding-top:
    20px;

  border-top:
    1px solid
    rgba(
      255,
      255,
      255,
      .07
    );
}


.question-player {
  min-height:
    84px;

  display:
    flex;

  flex-direction:
    column;

  justify-content:
    center;

  gap:
    4px;

  padding:
    13px
    16px;

  border-radius:
    11px;

  background:
    rgba(
      255,
      255,
      255,
      .025
    );
}


.question-player.blue {
  border:
    1px solid
    rgba(
      57,
      194,
      255,
      .14
    );
}


.question-player.red {
  border:
    1px solid
    rgba(
      255,
      67,
      100,
      .14
    );

  text-align:
    right;
}


.player-label {
  color:
    #647a95;

  font-size:
    7px;

  font-weight:
    950;

  letter-spacing:
    .12em;
}


.question-player strong {
  font-size:
    13px;
}


.waiting-text {
  color:
    #647b96;

  font-size:
    8px;
}


.question-player.winner {
  box-shadow:
    inset 0 0 30px
    rgba(
      60,
      231,
      152,
      .07
    );
}


.question-player.winner.blue,
.question-player.winner.red {
  border-color:
    rgba(
      62,
      231,
      153,
      .35
    );
}


.winner-text {
  color:
    #69e9ad;

  font-size:
    8px;

  font-weight:
    950;
}


.question-vs {
  color:
    #53677f;

  font-size:
    9px;

  font-weight:
    950;
}


/* =========================================================
   WINNER
========================================================= */

.question-winner-banner {
  margin-top:
    17px;

  padding:
    13px;

  border:
    1px solid
    rgba(
      66,
      228,
      154,
      .2
    );

  border-radius:
    10px;

  color:
    #82edba;

  text-align:
    center;

  background:
    rgba(
      38,
      186,
      114,
      .06
    );

  font-size:
    10px;
}


.question-winner-banner strong {
  color:
    white;
}


/* =========================================================
   ANSWER INFO
========================================================= */

.answer-on-device {
  margin-top:
    15px;

  color:
    #627792;

  text-align:
    center;

  font-size:
    8px;

  font-weight:
    850;

  letter-spacing:
    .08em;

  text-transform:
    uppercase;
}


/* =========================================================
   QUESTION STATE
========================================================= */

.question-state {
  min-height:
    230px;

  display:
    flex;

  align-items:
    center;

  justify-content:
    center;

  gap:
    10px;

  color:
    #7189a5;

  font-size:
    11px;
}


.question-error {
  color:
    #ff8097;
}


/* =========================================================
   TRANSITION
========================================================= */

.question-overlay-enter-active,
.question-overlay-leave-active {
  transition:
    opacity
    .2s
    ease;
}


.question-overlay-enter-active
.question-card,
.question-overlay-leave-active
.question-card {
  transition:
    transform
    .2s
    ease,
    opacity
    .2s
    ease;
}


.question-overlay-enter-from,
.question-overlay-leave-to {
  opacity:
    0;
}


.question-overlay-enter-from
.question-card,
.question-overlay-leave-to
.question-card {
  opacity:
    0;

  transform:
    translateY(
      12px
    )
    scale(
      .985
    );
}


/* =========================================================
   RESPONSIVE
========================================================= */

@media (
  max-width:
  750px
) {

  .public-question-overlay {
    padding:
      14px;
  }


  .question-card {
    max-height:
      calc(
        100vh -
        28px
      );

    padding:
      20px;
  }


  .question-header {
    flex-direction:
      column;
  }


  .question-options {
    grid-template-columns:
      1fr;
  }


  .question-player-status {
    grid-template-columns:
      1fr;
  }


  .question-vs {
    text-align:
      center;
  }


  .question-player.red {
    text-align:
      left;
  }

}

</style>