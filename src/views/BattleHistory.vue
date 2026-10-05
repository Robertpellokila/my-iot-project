<script setup>
import SearchableSelect from "../components/SearchableSelect.vue";
import AdminTable from "../components/AdminTable.vue";
import QRCode from "qrcode";
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

const activeFilter = ref("all");
const selectedBattle = ref(null);
const detailQrs = ref({ p1: "", p2: "" });
const zoomedQr = ref(null);
const updatingBattleIds = ref([]);


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

          if (activeFilter.value !== "all") {
            const shouldBeActive = activeFilter.value === "active";
            if (isBattleActive(battle) !== shouldBeActive) return false;
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

const isBattleActive = (battle) => {
  if (battle?.is_active !== undefined && battle?.is_active !== null) {
    return Boolean(battle.is_active);
  }
  const createdAt = battle?.created_at ? new Date(battle.created_at).getTime() : 0;
  return !battle?.winner && createdAt > Date.now() - 24 * 60 * 60 * 1000;
};

const hasWinner = (battle) => Boolean(String(battle?.winner ?? "").trim());

const playerUrl = (battle, player) => {
  const token = player === "p1" ? battle?.player1_token : battle?.player2_token;
  if (!battle?.code || !token) return "";
  return `${window.location.origin}/play/${encodeURIComponent(battle.code)}/${player}?token=${encodeURIComponent(token)}`;
};

const setBattleActive = async (battle, active) => {
  if (updatingBattleIds.value.includes(battle.id) || (active && hasWinner(battle))) return;
  updatingBattleIds.value = [...updatingBattleIds.value, battle.id];
  try {
    const { data, error: updateError } = await supabase
      .from("battle_sessions")
      .update({ is_active: active })
      .eq("id", battle.id)
      .select("*")
      .single();
    if (updateError) throw updateError;
    battles.value = battles.value.map((item) => item.id === battle.id ? data : item);
    if (selectedBattle.value?.id === battle.id) selectedBattle.value = data;
  } catch (err) {
    console.error("Update battle active state:", err);
    error.value = err?.message ?? "Status battle gagal diperbarui.";
  } finally {
    updatingBattleIds.value = updatingBattleIds.value.filter((id) => id !== battle.id);
  }
};

const showBattleDetails = async (battle) => {
  selectedBattle.value = battle;
  detailQrs.value = { p1: "", p2: "" };
  const p1Url = playerUrl(battle, "p1");
  const p2Url = playerUrl(battle, "p2");
  try {
    const [p1, p2] = await Promise.all([
      p1Url ? QRCode.toDataURL(p1Url, { width: 360, margin: 1, errorCorrectionLevel: "M" }) : "",
      p2Url ? QRCode.toDataURL(p2Url, { width: 360, margin: 1, errorCorrectionLevel: "M" }) : "",
    ]);
    if (selectedBattle.value?.id === battle.id) detailQrs.value = { p1, p2 };
  } catch (err) {
    console.error("Generate battle detail QR:", err);
  }
};

const closeBattleDetails = () => {
  selectedBattle.value = null;
  zoomedQr.value = null;
};

const openZoomedQr = (player) => {
  const image = detailQrs.value[player];
  if (!image) return;
  zoomedQr.value = {
    player,
    name: player === "p1" ? selectedBattle.value?.player1_name : selectedBattle.value?.player2_name,
    image,
  };
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


        <SearchableSelect
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

        </SearchableSelect>

        <SearchableSelect v-model="activeFilter">
          <option value="all">Semua status aktif</option>
          <option value="active">Aktif</option>
          <option value="inactive">Tidak aktif</option>
        </SearchableSelect>


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

        <AdminTable>
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

              <th>Aktif</th>

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

              <!-- ACTIVATION -->

              <td>
                <div class="active-control">
                  <span class="active-state" :class="{ on: isBattleActive(battle) }">
                    {{ isBattleActive(battle) ? "Aktif" : "Tidak aktif" }}
                  </span>
                  <button
                    type="button"
                    role="switch"
                    class="active-toggle"
                    :class="{ on: isBattleActive(battle) }"
                    :aria-checked="isBattleActive(battle)"
                    :aria-label="`Ubah status aktif battle ${battle.code}`"
                    :disabled="hasWinner(battle) || updatingBattleIds.includes(battle.id)"
                    :title="hasWinner(battle) ? 'Battle dengan pemenang selalu nonaktif' : 'Ubah status aktif battle'"
                    @click="setBattleActive(battle, !isBattleActive(battle))"
                  ><span /></button>
                  <small v-if="hasWinner(battle)">Pemenang ditetapkan</small>
                  <small v-else-if="battle.active_until && isBattleActive(battle)">Sampai {{ formatDate(battle.active_until) }}</small>
                </div>
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
                    class="action detail"
                    title="Detail battle dan QR player"
                    @click="showBattleDetails(battle)"
                  >
                    Detail
                  </button>

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
          </AdminTable>

      </div>

    </main>

    <div v-if="selectedBattle" class="modal-backdrop" @click.self="closeBattleDetails" @keydown.esc="closeBattleDetails">
      <section class="battle-modal" role="dialog" aria-modal="true" :aria-label="`Detail battle ${selectedBattle.code}`">
        <header class="modal-header">
          <div>
            <span class="eyebrow">DETAIL BATTLE</span>
            <h2>{{ selectedBattle.code }}</h2>
          </div>
          <button type="button" class="modal-close" aria-label="Tutup detail" @click="closeBattleDetails">×</button>
        </header>

        <div class="modal-summary">
          <div><span>Status</span><strong>{{ statusLabel(selectedBattle.status) }}</strong></div>
          <div><span>Ronde</span><strong>{{ selectedBattle.round ?? 1 }} / {{ selectedBattle.total_rounds ?? "-" }}</strong></div>
          <div><span>Pemenang</span><strong>{{ winnerName(selectedBattle) }}</strong></div>
          <div><span>Dibuat</span><strong>{{ formatDate(selectedBattle.created_at) }}</strong></div>
          <div><span>Status akses</span><strong>{{ isBattleActive(selectedBattle) ? "Aktif" : "Tidak aktif" }}</strong></div>
          <div><span>Berakhir</span><strong>{{ selectedBattle.active_until ? formatDate(selectedBattle.active_until) : (hasWinner(selectedBattle) ? "Pemenang ditetapkan" : "Belum ditentukan") }}</strong></div>
          <div><span>Giliran pertama</span><strong>{{ startingPlayerName(selectedBattle) }}</strong></div>
          <div><span>Kuis</span><strong>{{ selectedBattle.question_enabled ? `${selectedBattle.question_level || "medium"} · tiap ${selectedBattle.question_every_rounds || "-"} ronde` : "Nonaktif" }}</strong></div>
          <div><span>Batas waktu giliran</span><strong>{{ selectedBattle.turn_duration_seconds ? `${selectedBattle.turn_duration_seconds} detik` : "-" }}</strong></div>
        </div>

        <div class="detail-players">
          <article class="detail-player">
            <div class="detail-player-copy"><span>PLAYER 1</span><strong>{{ selectedBattle.player1_name || "Player 1" }}</strong><code>{{ selectedBattle.player1_access_code || "Kode tidak tersedia" }}</code></div>
            <button v-if="detailQrs.p1" type="button" class="qr-preview" aria-label="Perbesar QR Player 1" @click="openZoomedQr('p1')"><img :src="detailQrs.p1" alt="QR Player 1" /><span>Klik untuk perbesar</span></button>
            <p v-else class="qr-unavailable">QR tidak tersedia karena token player tidak ada.</p>
            <button type="button" class="modal-action" :disabled="!selectedBattle.player1_token" @click="openPlayer(selectedBattle, 'p1')">Buka halaman Player 1</button>
          </article>

          <article class="detail-player">
            <div class="detail-player-copy"><span>PLAYER 2</span><strong>{{ selectedBattle.player2_name || "Player 2" }}</strong><code>{{ selectedBattle.player2_access_code || "Kode tidak tersedia" }}</code></div>
            <button v-if="detailQrs.p2" type="button" class="qr-preview" aria-label="Perbesar QR Player 2" @click="openZoomedQr('p2')"><img :src="detailQrs.p2" alt="QR Player 2" /><span>Klik untuk perbesar</span></button>
            <p v-else class="qr-unavailable">QR tidak tersedia karena token player tidak ada.</p>
            <button type="button" class="modal-action" :disabled="!selectedBattle.player2_token" @click="openPlayer(selectedBattle, 'p2')">Buka halaman Player 2</button>
          </article>
        </div>
      </section>
    </div>

    <div v-if="zoomedQr" class="qr-zoom-backdrop" @click.self="zoomedQr = null" @keydown.esc="zoomedQr = null">
      <section class="qr-zoom-modal" role="dialog" aria-modal="true" :aria-label="`QR ${zoomedQr.player}`">
        <button type="button" class="modal-close" aria-label="Tutup QR" @click="zoomedQr = null">×</button>
        <span class="eyebrow">{{ zoomedQr.player === "p1" ? "PLAYER 1" : "PLAYER 2" }}</span>
        <h2>{{ zoomedQr.name || "Player" }}</h2>
        <img :src="zoomedQr.image" :alt="`QR ${zoomedQr.name || zoomedQr.player}`" />
        <p>Scan QR ini untuk membuka halaman player.</p>
      </section>
    </div>

  </div>
</template>


<style scoped>
* { box-sizing: border-box; }
.history-page { min-height: 100vh; position: relative; overflow-x: hidden; padding: 42px 24px; color: #173b23; background: #f2f8f1; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
.background-glow { display: none; }
.history-container { width: min(100%, 1500px); margin: auto; position: relative; z-index: 2; }
.history-header { display: flex; justify-content: space-between; align-items: flex-end; gap: 20px; margin-bottom: 24px; }
.eyebrow { display: block; margin-bottom: 7px; color: #149b32; font-size: 10px; font-weight: 900; letter-spacing: .18em; }
.history-header h1 { margin: 0; color: #183d24; font-size: clamp(28px, 4vw, 38px); }
.history-header p { margin: 7px 0 0; color: #718574; font-size: 14px; }
.new-battle-button,.refresh-button,.modal-action { min-height: 42px; padding: 0 16px; border: 1px solid #0ba92c; border-radius: 10px; color: #fff; background: #0dad30; cursor: pointer; font-size: 12px; font-weight: 850; transition: background .16s ease, transform .16s ease; }
.new-battle-button:hover,.refresh-button:hover,.modal-action:hover { background: #078e27; transform: translateY(-1px); }
.filters { display: grid; grid-template-columns: minmax(220px,1fr) minmax(155px,190px) minmax(155px,210px) auto; gap: 10px; margin-bottom: 16px; position: relative; z-index: 5; }
.filters input,.filters select { width: 100%; min-height: 44px; padding: 0 14px; border: 1px solid #d5e5d3; border-radius: 10px; outline: none; color: #284a31; background: #fff; }
.filters input:focus { border-color: #21ae3f; box-shadow: 0 0 0 3px #19aa3418; }
.refresh-button { min-width: 100px; }
.table-wrapper { overflow: visible; border-radius: 15px; background: transparent; }
.table-wrapper :deep(.admin-table) { border-color: #dce9dc; box-shadow: 0 8px 24px #1645230b; }
.table-wrapper :deep(table) { min-width: 1220px; }
.table-wrapper :deep(th) { padding: 13px 12px; }
.table-wrapper :deep(td) { padding: 12px; }
.code-button { border: 0; border-radius: 8px; padding: 9px 11px; color: #fff; background: #0dad30; cursor: pointer; font-weight: 900; letter-spacing: .05em; }
.players { display: flex; align-items: center; gap: 7px; white-space: nowrap; }
.player { font-weight: 800; }
.player.blue { color: #1682a0; }
.player.red { color: #b4475a; }
.vs { color: #8b9b8c; font-size: 9px; font-weight: 900; }
.status-badge { display: inline-flex; padding: 5px 8px; border-radius: 999px; color: #387c46; background: #e9f6e8; font-size: 9px; font-weight: 900; text-transform: uppercase; }
.status-badge.waiting { color: #93680a; background: #fff5d7; }
.status-badge.question { color: #7052a2; background: #f0eaff; }
.status-badge.finished { color: #397348; background: #e6f4e8; }
.active-control { min-width: 94px; display: grid; grid-template-columns: 1fr 36px; align-items: center; gap: 3px 7px; }
.active-state { color: #7c8980; font-size: 11px; font-weight: 800; }
.active-state.on { color: #148b2d; }
.active-control small { grid-column: 1 / -1; color: #849386; font-size: 9px; white-space: nowrap; }
.active-toggle { width: 36px; height: 21px; padding: 2px; border: 0; border-radius: 999px; background: #c7d1c7; cursor: pointer; transition: background .18s ease; }
.active-toggle span { width: 17px; height: 17px; display: block; border-radius: 50%; background: white; box-shadow: 0 1px 3px #1234; transition: transform .18s ease; }
.active-toggle.on { background: #0bad31; }
.active-toggle.on span { transform: translateX(15px); }
.active-toggle:disabled { opacity: .45; cursor: not-allowed; }
.question-level { color: #7454a7; font-weight: 900; text-transform: capitalize; }
.muted { color: #829184; }
.block { display: block; margin-top: 3px; font-size: 10px; }
.created-at { color: #6f8071; white-space: nowrap; }
.actions { display: flex; gap: 5px; align-items: center; }
.action { min-width: 34px; min-height: 31px; padding: 0 8px; border: 1px solid #cfe4ce; border-radius: 8px; color: #167e2c; background: #f4faf3; cursor: pointer; font-size: 10px; font-weight: 900; }
.action:hover { border-color: #21ad3d; background: #e9f7e8; }
.action.detail { color: #fff; border-color: #0daa30; background: #0daa30; }
.action.public { color: #765c09; border-color: #eee0ae; background: #fff9e8; }
.action.p1 { color: #087d9c; border-color: #c2e7f1; background: #f0fbfe; }
.action.p2 { color: #a64256; border-color: #f1d1d6; background: #fff6f7; }
.error-box,.state-box { padding: 28px; border: 1px solid #dce9dc; border-radius: 13px; text-align: center; color: #657967; background: #fff; }
.error-box { color: #a73f3f; border-color: #f1cccc; }
.empty-icon { margin-bottom: 12px; font-size: 32px; }
.state-box strong { display: block; color: #254b2f; }
.state-box p { margin-bottom: 0; font-size: 12px; }
.modal-backdrop,.qr-zoom-backdrop { position: fixed; inset: 0; z-index: 1000; display: grid; place-items: center; padding: 20px; background: #12321ecc; backdrop-filter: blur(7px); }
.battle-modal,.qr-zoom-modal { width: min(920px,100%); max-height: min(90vh,900px); overflow: auto; padding: 24px; border: 1px solid #dcebd9; border-radius: 20px; color: #21452b; background: #fff; box-shadow: 0 28px 90px #09210e40; }
.modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; }
.modal-header h2,.qr-zoom-modal h2 { margin: 0; color: #173b23; font-size: 28px; }
.modal-close { width: 38px; height: 38px; border: 1px solid #dce9dc; border-radius: 50%; color: #385d40; background: #f5faf4; cursor: pointer; font-size: 25px; line-height: 1; }
.modal-summary { display: grid; grid-template-columns: repeat(3,minmax(0,1fr)); gap: 10px; margin: 20px 0; }
.modal-summary div { min-height: 66px; display: flex; flex-direction: column; justify-content: center; gap: 5px; padding: 11px 13px; border-radius: 11px; background: #f1f8f0; }
.modal-summary span,.detail-player-copy>span { color: #778a79; font-size: 10px; font-weight: 850; letter-spacing: .08em; text-transform: uppercase; }
.modal-summary strong { color: #23462c; font-size: 13px; }
.detail-players { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 14px; }
.detail-player { min-width: 0; display: flex; align-items: center; gap: 14px; padding: 16px; border: 1px solid #e0ecde; border-radius: 14px; background: #fbfdfb; }
.detail-player-copy { min-width: 0; display: flex; flex: 1; flex-direction: column; gap: 7px; }
.detail-player-copy strong { color: #22472d; font-size: 16px; }
.detail-player-copy code { width: fit-content; max-width: 100%; overflow-wrap: anywhere; padding: 5px 8px; border-radius: 6px; color: #16802d; background: #eaf6e9; font-size: 11px; }
.qr-preview { width: 126px; flex: 0 0 126px; display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 8px; border: 1px solid #dce9dc; border-radius: 10px; color: #5d765f; background: white; cursor: zoom-in; font-size: 9px; }
.qr-preview img { width: 100%; aspect-ratio: 1; object-fit: contain; image-rendering: pixelated; }
.qr-unavailable { color: #8a968a; font-size: 11px; }
.modal-action { min-height: 36px; padding: 0 10px; font-size: 10px; white-space: nowrap; }
.modal-action:disabled { border-color: #dae5d9; color: #859285; background: #edf2ec; cursor: not-allowed; }
.qr-zoom-modal { width: min(460px,100%); position: relative; display: flex; flex-direction: column; align-items: center; padding: 30px; text-align: center; }
.qr-zoom-modal .modal-close { position: absolute; top: 14px; right: 14px; }
.qr-zoom-modal .eyebrow { margin-top: 6px; }
.qr-zoom-modal h2 { margin-bottom: 20px; font-size: 23px; }
.qr-zoom-modal img { width: min(100%,360px); padding: 10px; border: 1px solid #e1ebe0; border-radius: 14px; background: white; image-rendering: pixelated; }
.qr-zoom-modal p { margin: 14px 0 0; color: #758776; font-size: 13px; }
@media (max-width: 900px) { .filters { grid-template-columns: minmax(0,1fr) minmax(150px,1fr); } .detail-players { grid-template-columns: 1fr; } }
@media (max-width: 600px) { .history-page { padding: 28px 13px; } .history-header { align-items: flex-start; flex-direction: column; } .filters { grid-template-columns: 1fr; } .modal-backdrop,.qr-zoom-backdrop { padding: 10px; } .battle-modal { padding: 18px; } .modal-summary { grid-template-columns: repeat(2,minmax(0,1fr)); } .detail-player { align-items: stretch; flex-direction: column; } .qr-preview { width: 150px; flex-basis: auto; align-self: center; } .modal-action { width: 100%; } }
</style>
