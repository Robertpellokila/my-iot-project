<script setup>
import {
  ref,
  computed,
  onMounted,
} from "vue";

import {
  useRouter,
} from "vue-router";

import {
  supabase,
} from "../lib/supabase";


const router =
  useRouter();


// =========================================================
// STATE
// =========================================================

const battles =
  ref([]);


const loading =
  ref(true);


const error =
  ref(null);


const search =
  ref("");


const statusFilter =
  ref("all");


// =========================================================
// FILTERED BATTLES
// =========================================================

const filteredBattles =
  computed(
    () => {

      const keyword =
        search.value
          .trim()
          .toLowerCase();


      return battles.value.filter(
        battle => {

          // =================================================
          // STATUS
          // =================================================

          if (
            statusFilter.value !==
              "all"

            &&

            battle.status !==
              statusFilter.value
          ) {

            return false;

          }


          // =================================================
          // SEARCH
          // =================================================

          if (
            !keyword
          ) {

            return true;

          }


          const searchable =
            [
              battle.code,
              battle.player1_name,
              battle.player2_name,
              battle.status,
              battle.question_level,
            ]
              .filter(
                Boolean
              )
              .join(" ")
              .toLowerCase();


          return searchable.includes(
            keyword
          );

        }
      );

    }
  );


// =========================================================
// LOAD HISTORY
// =========================================================

const loadBattles =
  async () => {

    loading.value =
      true;


    error.value =
      null;


    try {

      const {
        data: {
          user,
        },
        error:
          userError,
      } =
        await supabase.auth
          .getUser();


      if (
        userError
      ) {

        throw userError;

      }


      if (
        !user
      ) {

        throw new Error(
          "User belum login."
        );

      }


      const {
        data,
        error:
          queryError,
      } =
        await supabase
          .from(
            "battle_sessions"
          )
          .select("*")
          .eq(
            "created_by",
            user.id
          )
          .order(
            "created_at",
            {
              ascending:
                false,
            }
          );


      if (
        queryError
      ) {

        throw queryError;

      }


      battles.value =
        data ??
        [];

    }

    catch (
      err
    ) {

      console.error(
        "Load battle history:",
        err
      );


      error.value =
        err?.message ??
        "Gagal mengambil battle history.";

    }

    finally {

      loading.value =
        false;

    }

  };


// =========================================================
// DATE FORMAT
// =========================================================

const formatDate =
  value => {

    if (
      !value
    ) {

      return "-";

    }


    return new Intl
      .DateTimeFormat(
        "id-ID",
        {
          dateStyle:
            "medium",

          timeStyle:
            "short",
        }
      )
      .format(
        new Date(
          value
        )
      );

  };


// =========================================================
// STATUS LABEL
// =========================================================

const statusLabel =
  status => {

    const labels = {

      waiting:
        "Waiting",

      ready:
        "Ready",

      battle:
        "Battle",

      question:
        "Question",

      finished:
        "Finished",

    };


    return (
      labels[
        status
      ]
      ??
      status
      ??
      "-"
    );

  };


// =========================================================
// STARTING PLAYER
// =========================================================

const startingPlayerName =
  battle => {

    if (
      battle.starting_player ===
      "p2"
    ) {

      return (
        battle.player2_name ??
        "Player 2"
      );

    }


    return (
      battle.player1_name ??
      "Player 1"
    );

  };


// =========================================================
// WINNER
// =========================================================

const winnerName =
  battle => {

    if (
      battle.winner ===
      "p1"
    ) {

      return (
        battle.player1_name ??
        "Player 1"
      );

    }


    if (
      battle.winner ===
      "p2"
    ) {

      return (
        battle.player2_name ??
        "Player 2"
      );

    }


    if (
      battle.winner ===
      "draw"
    ) {

      return "Draw";

    }


    return "-";

  };


// =========================================================
// NAVIGATION
// =========================================================

const openSetup =
  () => {

    router.push({
      name:
        "game-setup",
    });

  };


const openPublicBattle =
  battle => {

    router.push({
      name:
        "public-battle",

      params: {
        code:
          battle.code,
      },
    });

  };


const openPlayer =
  (
    battle,
    player
  ) => {

    const token =
      player === "p1"
        ? battle.player1_token
        : battle.player2_token;


    if (
      !token
    ) {

      console.error(
        `Token ${player} tidak ditemukan`,
        battle
      );

      return;
    }


    router.push({
      name:
        "player-battle",

      params: {
        code:
          battle.code,

        player,
      },

      query: {
        token,
      },
    });

  };


// =========================================================
// COPY CODE
// =========================================================

const copyCode =
  async battle => {

    try {

      await navigator
        .clipboard
        .writeText(
          battle.code
        );

    }

    catch (
      err
    ) {

      console.error(
        "Copy battle code:",
        err
      );

    }

  };


// =========================================================
// MOUNT
// =========================================================

onMounted(
  () => {

    void loadBattles();

  }
);
</script>


<template>
  <div class="history-page">

    <div class="background-glow glow-blue" />
    <div class="background-glow glow-red" />


    <main class="history-container">

      <!-- =================================================
           HEADER
      ================================================== -->

      <header class="history-header">

        <div>

          <span class="eyebrow">
            BATTLE CONTROL
          </span>

          <h1>
            Battle History
          </h1>

          <p>
            Daftar pertandingan yang pernah dibuat.
          </p>

        </div>


        <button
          type="button"
          class="new-battle-button"
          @click="openSetup"
        >
          + CREATE BATTLE
        </button>

      </header>


      <!-- =================================================
           FILTER
      ================================================== -->

      <section class="filters">

        <input
          v-model="search"
          type="search"
          placeholder="Search battle code or player..."
        />


        <select
          v-model="statusFilter"
        >

          <option value="all">
            All Status
          </option>

          <option value="waiting">
            Waiting
          </option>

          <option value="ready">
            Ready
          </option>

          <option value="battle">
            Battle
          </option>

          <option value="question">
            Question
          </option>

          <option value="finished">
            Finished
          </option>

        </select>


        <button
          type="button"
          class="refresh-button"
          @click="loadBattles"
        >
          ↻ Refresh
        </button>

      </section>


      <!-- =================================================
           ERROR
      ================================================== -->

      <div
        v-if="error"
        class="error-box"
      >
        ⚠ {{ error }}
      </div>


      <!-- =================================================
           LOADING
      ================================================== -->

      <div
        v-if="loading"
        class="state-box"
      >
        Loading battle history...
      </div>


      <!-- =================================================
           EMPTY
      ================================================== -->

      <div
        v-else-if="
          filteredBattles.length === 0
        "
        class="state-box"
      >

        <div class="empty-icon">
          ⚔️
        </div>

        <strong>
          Belum ada battle
        </strong>

        <p>
          Buat battle pertama dari Game Setup.
        </p>

      </div>


      <!-- =================================================
           TABLE
      ================================================== -->

      <div
        v-else
        class="table-wrapper"
      >

        <table>

          <thead>

            <tr>

              <th>
                Code
              </th>

              <th>
                Players
              </th>

              <th>
                Status
              </th>

              <th>
                Round
              </th>

              <th>
                Start
              </th>

              <th>
                Question
              </th>

              <th>
                Winner
              </th>

              <th>
                Created
              </th>

              <th class="action-column">
                Action
              </th>

            </tr>

          </thead>


          <tbody>

            <tr
              v-for="
                battle in filteredBattles
              "
              :key="battle.id"
            >

              <!-- CODE -->

              <td>

                <button
                  type="button"
                  class="code-button"
                  @click="
                    copyCode(
                      battle
                    )
                  "
                >
                  {{ battle.code }}
                </button>

              </td>


              <!-- PLAYERS -->

              <td>

                <div class="players">

                  <span class="player blue">
                    {{ battle.player1_name }}
                  </span>

                  <span class="vs">
                    VS
                  </span>

                  <span class="player red">
                    {{ battle.player2_name }}
                  </span>

                </div>

              </td>


              <!-- STATUS -->

              <td>

                <span
                  class="status-badge"
                  :class="
                    battle.status
                  "
                >
                  {{
                    statusLabel(
                      battle.status
                    )
                  }}
                </span>

              </td>


              <!-- ROUND -->

              <td>

                <strong>
                  {{ battle.round ?? 1 }}
                </strong>

                <span class="muted">
                  /
                  {{
                    battle.total_rounds ??
                    "-"
                  }}
                </span>

              </td>


              <!-- START -->

              <td>
                {{
                  startingPlayerName(
                    battle
                  )
                }}
              </td>


              <!-- QUESTION -->

              <td>

                <template
                  v-if="
                    battle.question_enabled
                  "
                >

                  <span class="question-level">
                    {{
                      battle.question_level
                    }}
                  </span>

                  <span class="muted block">
                    every
                    {{
                      battle.question_every_rounds
                    }}
                    rounds
                  </span>

                </template>


                <span
                  v-else
                  class="muted"
                >
                  Off
                </span>

              </td>


              <!-- WINNER -->

              <td>
                {{
                  winnerName(
                    battle
                  )
                }}
              </td>


              <!-- CREATED -->

              <td class="created-at">
                {{
                  formatDate(
                    battle.created_at
                  )
                }}
              </td>


              <!-- ACTION -->

              <td>

                <div class="actions">

                  <button
                    type="button"
                    class="action public"
                    title="Public Battle"
                    @click="
                      openPublicBattle(
                        battle
                      )
                    "
                  >
                    TV
                  </button>


                  <button
                    type="button"
                    class="action p1"
                    title="Player 1"
                    @click="
                      openPlayer(
                        battle,
                        'p1'
                      )
                    "
                  >
                    P1
                  </button>


                  <button
                    type="button"
                    class="action p2"
                    title="Player 2"
                    @click="
                      openPlayer(
                        battle,
                        'p2'
                      )
                    "
                  >
                    P2
                  </button>

                </div>

              </td>

            </tr>

          </tbody>

        </table>

      </div>

    </main>

  </div>
</template>


<style scoped>
* {
  box-sizing: border-box;
}


.history-page {
  min-height: 100vh;
  position: relative;
  overflow-x: hidden;
  padding: 50px 25px;
  color: #eef7ff;
  background: #020713;
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}


.background-glow {
  width: 500px;
  height: 500px;
  position: fixed;
  border-radius: 50%;
  filter: blur(150px);
  opacity: .12;
  pointer-events: none;
}


.glow-blue {
  top: -220px;
  left: -170px;
  background: #009cff;
}


.glow-red {
  right: -180px;
  bottom: -220px;
  background: #ff3156;
}


.history-container {
  width: min(100%, 1350px);
  margin: auto;
  position: relative;
  z-index: 2;
}


.history-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 20px;
  margin-bottom: 28px;
}


.eyebrow {
  display: block;
  margin-bottom: 6px;
  color: #47d1ff;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: .22em;
}


.history-header h1 {
  margin: 0;
  font-size: 32px;
}


.history-header p {
  margin: 6px 0 0;
  color: #71859d;
  font-size: 12px;
}


.new-battle-button {
  min-height: 42px;
  padding: 0 17px;
  border: 1px solid rgba(67,200,255,.36);
  border-radius: 9px;
  color: #7ce3ff;
  background: rgba(17,145,205,.1);
  cursor: pointer;
  font-size: 9px;
  font-weight: 950;
  letter-spacing: .08em;
}


.filters {
  display: grid;
  grid-template-columns: 1fr 180px auto;
  gap: 10px;
  margin-bottom: 16px;
}


.filters input,
.filters select {
  min-height: 42px;
  padding: 0 13px;
  border: 1px solid rgba(130,170,220,.13);
  border-radius: 9px;
  outline: none;
  color: #dbeaff;
  background: #071225;
}


.refresh-button {
  border: 1px solid rgba(255,255,255,.09);
  border-radius: 9px;
  color: #8da2ba;
  background: rgba(255,255,255,.03);
  cursor: pointer;
}


.table-wrapper {
  overflow-x: auto;
  border: 1px solid rgba(128,168,215,.1);
  border-radius: 15px;
  background: rgba(5,14,31,.92);
  box-shadow: 0 20px 50px rgba(0,0,0,.2);
}


table {
  width: 100%;
  min-width: 1050px;
  border-collapse: collapse;
}


th {
  padding: 13px;
  border-bottom: 1px solid rgba(255,255,255,.07);
  color: #657c97;
  text-align: left;
  font-size: 8px;
  letter-spacing: .09em;
  text-transform: uppercase;
}


td {
  padding: 14px 13px;
  border-bottom: 1px solid rgba(255,255,255,.045);
  color: #bdcadb;
  font-size: 10px;
}


tbody tr:hover {
  background: rgba(255,255,255,.018);
}


tbody tr:last-child td {
  border-bottom: 0;
}


.code-button {
  border: 0;
  color: #66d9ff;
  background: transparent;
  cursor: pointer;
  font-weight: 950;
  letter-spacing: .08em;
}


.players {
  display: flex;
  align-items: center;
  gap: 7px;
}


.player {
  font-weight: 800;
}


.player.blue {
  color: #5fd5ff;
}


.player.red {
  color: #ff738d;
}


.vs {
  color: #53677f;
  font-size: 7px;
  font-weight: 900;
}


.status-badge {
  padding: 5px 8px;
  border-radius: 999px;
  font-size: 7px;
  font-weight: 950;
  text-transform: uppercase;
}


.status-badge.waiting {
  color: #ffd778;
  background: rgba(255,190,45,.09);
}


.status-badge.ready,
.status-badge.battle {
  color: #63e0ff;
  background: rgba(36,183,230,.09);
}


.status-badge.question {
  color: #c999ff;
  background: rgba(152,75,255,.1);
}


.status-badge.finished {
  color: #72e7aa;
  background: rgba(41,202,119,.1);
}


.question-level {
  color: #d2b5ff;
  font-weight: 900;
  text-transform: capitalize;
}


.muted {
  color: #596d85;
}


.block {
  display: block;
  margin-top: 3px;
  font-size: 8px;
}


.created-at {
  color: #64798f;
  white-space: nowrap;
}


.actions {
  display: flex;
  gap: 5px;
}


.action {
  min-width: 32px;
  height: 29px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 8px;
  font-weight: 950;
}


.action.public {
  border: 1px solid rgba(255,220,104,.2);
  color: #ffe189;
  background: rgba(255,192,35,.06);
}


.action.p1 {
  border: 1px solid rgba(50,193,255,.2);
  color: #66d8ff;
  background: rgba(20,161,220,.06);
}


.action.p2 {
  border: 1px solid rgba(255,71,105,.2);
  color: #ff7c94;
  background: rgba(223,42,77,.06);
}


.error-box,
.state-box {
  padding: 30px;
  border: 1px solid rgba(255,255,255,.07);
  border-radius: 13px;
  text-align: center;
  color: #8296ad;
  background: rgba(5,15,32,.85);
}


.error-box {
  color: #ff8097;
}


.empty-icon {
  margin-bottom: 12px;
  font-size: 32px;
}


.state-box strong {
  display: block;
  color: #dceaff;
}


.state-box p {
  margin-bottom: 0;
  font-size: 10px;
}


@media (max-width: 750px) {

  .history-page {
    padding: 30px 13px;
  }


  .history-header {
    align-items: flex-start;
    flex-direction: column;
  }


  .filters {
    grid-template-columns: 1fr;
  }

}
</style>