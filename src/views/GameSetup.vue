<script setup>
import { ref, computed } from "vue";

import { useRouter } from "vue-router";

import { supabase } from "../lib/supabase";

// =========================================================
// ROUTER
// =========================================================

const router = useRouter();

// =========================================================
// FORM
// =========================================================

const player1Name = ref("Player 1");

const player2Name = ref("Player 2");

const totalRounds = ref(10);

const startingPlayer = ref("random");

const deckSize = ref(8);

const initialCardsRequired = ref(1);

const maxActive = ref(4);

const maxBench = ref(4);

// =========================================================
// QUESTION
// =========================================================

const questionEnabled = ref(true);

const questionLevel = ref("medium");

const questionEveryRounds = ref(5);

// =========================================================
// STATE
// =========================================================

const loading = ref(false);

const error = ref(null);

const createdBattle = ref(null);

// =========================================================
// CREATED URLS
// =========================================================

const publicUrl = computed(() => {
  if (!createdBattle.value?.code) {
    return "";
  }

  return `${window.location.origin}` + `/battle/${createdBattle.value.code}`;
});

const player1Url = computed(() => {
  if (!createdBattle.value?.code || !createdBattle.value?.player1_token) {
    return "";
  }

  return (
    `${window.location.origin}` +
    `/play/${createdBattle.value.code}/p1` +
    `?token=${encodeURIComponent(createdBattle.value.player1_token)}`
  );
});

const player2Url = computed(() => {
  if (!createdBattle.value?.code || !createdBattle.value?.player2_token) {
    return "";
  }

  return (
    `${window.location.origin}` +
    `/play/${createdBattle.value.code}/p2` +
    `?token=${encodeURIComponent(createdBattle.value.player2_token)}`
  );
});

// =========================================================
// GENERATE CODE
// =========================================================

const generateBattleCode = () => {
  /*
   * Menghindari:
   *
   * O dan 0
   * I dan 1
   */

  const characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  let result = "";

  for (let i = 0; i < 6; i++) {
    result += characters[Math.floor(Math.random() * characters.length)];
  }

  return result;
};

// =========================================================
// RESOLVE STARTING PLAYER
// =========================================================

const resolveStartingPlayer = () => {
  if (startingPlayer.value === "p1") {
    return "p1";
  }

  if (startingPlayer.value === "p2") {
    return "p2";
  }

  return Math.random() < 0.5 ? "p1" : "p2";
};

// =========================================================
// VALIDATION
// =========================================================

const validateForm = () => {
  if (!player1Name.value.trim()) {
    return "Nama Player 1 wajib diisi.";
  }

  if (!player2Name.value.trim()) {
    return "Nama Player 2 wajib diisi.";
  }

  if (Number(totalRounds.value) < 1) {
    return "Jumlah round minimal 1.";
  }

  if (Number(deckSize.value) < 1) {
    return "Deck Size minimal 1.";
  }

  if (Number(initialCardsRequired.value) < 1) {
    return "Initial Cards minimal 1.";
  }

  if (Number(maxActive.value) < 1) {
    return "Max Active minimal 1.";
  }

  if (Number(maxBench.value) < 0) {
    return "Max Bench tidak valid.";
  }

  if (Number(initialCardsRequired.value) > Number(maxActive.value)) {
    return "Initial Cards tidak boleh " + "lebih besar dari Max Active.";
  }

  if (Number(maxActive.value) > Number(deckSize.value)) {
    return "Max Active tidak boleh " + "lebih besar dari Deck Size.";
  }

  if (
    Number(maxActive.value) + Number(maxBench.value) >
    Number(deckSize.value)
  ) {
    return "Max Active + Max Bench " + "tidak boleh melebihi Deck Size.";
  }

  if (questionEnabled.value && Number(questionEveryRounds.value) < 1) {
    return "Question Every minimal 1 round.";
  }

  if (
    questionEnabled.value &&
    Number(questionEveryRounds.value) > Number(totalRounds.value)
  ) {
    return "Question Every tidak boleh " + "lebih besar dari Total Rounds.";
  }

  return null;
};

// =========================================================
// CREATE BATTLE
// =========================================================

const createBattle = async () => {
  error.value = null;

  const validationError = validateForm();

  if (validationError) {
    error.value = validationError;

    return;
  }

  loading.value = true;

  createdBattle.value = null;

  try {
    // =====================================================
    // USER
    // =====================================================

    const {
      data: { user },

      error: userError,
    } = await supabase.auth.getUser();

    if (userError) {
      throw userError;
    }

    if (!user) {
      throw new Error("Session login tidak ditemukan.");
    }

    // =====================================================
    // STARTING PLAYER
    // =====================================================

    const resolvedStartingPlayer = resolveStartingPlayer();

    // =====================================================
    // RETRY CODE
    // =====================================================

    let created = null;

    let lastError = null;

    for (let attempt = 0; attempt < 5; attempt++) {
      const code = generateBattleCode();

      // ===================================================
      // PAYLOAD
      // ===================================================

      const payload = {
        // =================================================
        // OWNER
        // =================================================

        created_by: user.id,

        // =================================================
        // CODE
        // =================================================

        code,

        // =================================================
        // PLAYER
        // =================================================

        player1_name: player1Name.value.trim(),

        player2_name: player2Name.value.trim(),

        // =================================================
        // GAME RULES
        // =================================================

        total_rounds: Number(totalRounds.value),

        starting_player: resolvedStartingPlayer,

        current_turn: resolvedStartingPlayer,

        // =================================================
        // DECK
        // =================================================

        deck_size: Number(deckSize.value),

        initial_cards_required: Number(initialCardsRequired.value),

        max_active: Number(maxActive.value),

        max_bench: Number(maxBench.value),

        // =================================================
        // QUESTION
        // =================================================

        question_enabled: Boolean(questionEnabled.value),

        question_level: questionLevel.value,

        question_every_rounds: Number(questionEveryRounds.value),

        question_active: false,

        current_question_id: null,

        current_question_round_id: null,

        // =================================================
        // GAME STATE
        // =================================================

        round: 1,

        status: "waiting",

        winner: null,

        // =================================================
        // HP
        // =================================================

        player1_hp: 200,

        player1_max_hp: 200,

        player2_hp: 200,

        player2_max_hp: 200,

        // =================================================
        // SKILL
        // =================================================

        player1_skill: 0,

        player2_skill: 0,

        // =================================================
        // DEFENSE
        // =================================================

        player1_defending: false,

        player2_defending: false,

        // =================================================
        // SYNERGY
        // =================================================

        player1_synergy_shield: 0,

        player2_synergy_shield: 0,

        player1_attack_debuff: 0,

        player2_attack_debuff: 0,

        // =================================================
        // DATE
        // =================================================

        started_at: null,

        finished_at: null,
      };

      // ===================================================
      // INSERT
      // ===================================================

      const { data, error: insertError } = await supabase
        .from("battle_sessions")
        .insert(payload)
        .select("*")
        .single();

      // ===================================================
      // SUCCESS
      // ===================================================

      if (!insertError) {
        created = data;

        break;
      }

      lastError = insertError;

      // ===================================================
      // UNIQUE CODE COLLISION
      // ===================================================

      if (insertError.code !== "23505") {
        throw insertError;
      }
    }

    // =====================================================
    // FAILED AFTER RETRY
    // =====================================================

    if (!created) {
      throw lastError ?? new Error("Gagal membuat Battle Code.");
    }

    // =====================================================
    // BIND PHYSICAL RFID READERS
    // =====================================================

    const {
      data: bindResult,

      error: bindError,
    } = await supabase.rpc(
      "bind_battle_readers",

      {
        p_code: created.code,
      },
    );

    if (bindError) {
      console.error("RFID binding gagal:", bindError);

      throw bindError;
    }

    if (bindResult?.ok === false) {
      throw new Error(
        bindResult.message ?? "Gagal menghubungkan RFID readers.",
      );
    }

    createdBattle.value = created;
  } catch (err) {
    console.error("Create Battle:", err);

    error.value = err?.message ?? "Gagal membuat battle.";
  } finally {
    loading.value = false;
  }
};

// =========================================================
// COPY
// =========================================================

const copyText = async (text) => {
  if (!text) {
    return;
  }

  try {
    await navigator.clipboard.writeText(text);
  } catch (err) {
    console.error("Copy gagal:", err);
  }
};

// =========================================================
// NAVIGATION
// =========================================================

const openBattleHistory = () => {
  router.push({
    name: "battle-history",
  });
};

const openPublicBattle = () => {
  if (!createdBattle.value?.code) {
    return;
  }

  router.push({
    name: "public-battle",

    params: {
      code: createdBattle.value.code,
    },
  });
};

const openPlayer = (playerValue) => {
  if (!createdBattle.value?.code) {
    return;
  }

  const playerToken =
    playerValue === "p1"
      ? createdBattle.value.player1_token
      : createdBattle.value.player2_token;

  router.push({
    name: "player-battle",

    params: {
      code: createdBattle.value.code,

      player: playerValue,
    },

    query: {
      token: playerToken,
    },
  });
};

// =========================================================
// CREATE ANOTHER
// =========================================================

const createAnother = () => {
  createdBattle.value = null;

  error.value = null;
};
</script>

<template>
  <div class="setup-page">
    <!-- ===================================================
         BACKGROUND
    ==================================================== -->

    <div class="setup-background">
      <div class="bg-orb orb-blue" />

      <div class="bg-orb orb-red" />
    </div>

    <!-- ===================================================
         SETUP FORM
    ==================================================== -->

    <main v-if="!createdBattle" class="setup-container">
      <!-- =================================================
           HEADER
      ================================================== -->

      <header class="setup-header">
        <div class="setup-header-main">
          <div class="setup-logo">⚔️</div>

          <div>
            <div class="setup-eyebrow">BATTLE CONTROL</div>

            <h1>Create Battle</h1>

            <p>
              Atur pemain, deck, round, dan coding challenge sebelum
              pertandingan dimulai.
            </p>
          </div>
        </div>

        <button type="button" class="history-button" @click="openBattleHistory">
          ◷ BATTLE HISTORY
        </button>
      </header>

      <!-- =================================================
           FORM
      ================================================== -->

      <form class="setup-form" @submit.prevent="createBattle">
        <!-- ===============================================
             PLAYERS
        ================================================ -->

        <section class="setup-card">
          <div class="section-heading">
            <div class="section-icon">👥</div>

            <div>
              <h2>Players</h2>

              <p>Tentukan nama kedua pemain.</p>
            </div>
          </div>

          <div class="form-grid two">
            <label class="field">
              <span> Player 1 </span>

              <input
                v-model="player1Name"
                type="text"
                maxlength="40"
                placeholder="Player 1"
              />
            </label>

            <label class="field">
              <span> Player 2 </span>

              <input
                v-model="player2Name"
                type="text"
                maxlength="40"
                placeholder="Player 2"
              />
            </label>
          </div>
        </section>

        <!-- ===============================================
             GAME RULES
        ================================================ -->

        <section class="setup-card">
          <div class="section-heading">
            <div class="section-icon">🎮</div>

            <div>
              <h2>Game Rules</h2>

              <p>Tentukan jumlah round dan player yang memulai.</p>
            </div>
          </div>

          <div class="form-grid two">
            <!-- TOTAL ROUND -->

            <label class="field">
              <span> Total Rounds </span>

              <input
                v-model.number="totalRounds"
                type="number"
                min="1"
                max="100"
              />

              <small>
                Battle berakhir jika HP 0 atau round mencapai batas.
              </small>
            </label>

            <!-- STARTING PLAYER -->

            <label class="field">
              <span> Starting Player </span>

              <select v-model="startingPlayer">
                <option value="random">🎲 Random</option>

                <option value="p1">Player 1</option>

                <option value="p2">Player 2</option>
              </select>

              <small>
                Jika Random, player awal dipilih saat battle dibuat.
              </small>
            </label>
          </div>
        </section>

        <!-- ===============================================
             DECK
        ================================================ -->

        <section class="setup-card">
          <div class="section-heading">
            <div class="section-icon">🎴</div>

            <div>
              <h2>Deck Configuration</h2>

              <p>Tentukan aturan deck masing-masing player.</p>
            </div>
          </div>

          <div class="form-grid four">
            <!-- DECK SIZE -->

            <label class="field">
              <span> Deck Size </span>

              <input v-model.number="deckSize" type="number" min="1" max="20" />

              <small> Maksimal total kartu. </small>
            </label>

            <!-- INITIAL -->

            <label class="field">
              <span> Initial Cards </span>

              <input
                v-model.number="initialCardsRequired"
                type="number"
                min="1"
                :max="maxActive"
              />

              <small> Kartu yang dibutuhkan sebelum battle. </small>
            </label>

            <!-- ACTIVE -->

            <label class="field">
              <span> Max Active </span>

              <input
                v-model.number="maxActive"
                type="number"
                min="1"
                :max="deckSize"
              />

              <small> Maksimal kartu aktif. </small>
            </label>

            <!-- BENCH -->

            <label class="field">
              <span> Max Bench </span>

              <input
                v-model.number="maxBench"
                type="number"
                min="0"
                :max="deckSize"
              />

              <small> Maksimal kartu Bench. </small>
            </label>
          </div>

          <!-- SUMMARY -->

          <div class="deck-summary">
            <span>
              Deck
              <strong>
                {{ deckSize }}
              </strong>
            </span>

            <span>
              Initial
              <strong>
                {{ initialCardsRequired }}
              </strong>
            </span>

            <span>
              Active
              <strong>
                {{ maxActive }}
              </strong>
            </span>

            <span>
              Bench
              <strong>
                {{ maxBench }}
              </strong>
            </span>
          </div>
        </section>

        <!-- ===============================================
             QUESTION
        ================================================ -->

        <section class="setup-card">
          <div class="section-heading question-heading">
            <div class="heading-left">
              <div class="section-icon">💻</div>

              <div>
                <h2>Coding Challenge</h2>

                <p>
                  Player tercepat yang menjawab benar mendapatkan random bonus
                  skill.
                </p>
              </div>
            </div>

            <label class="toggle">
              <input v-model="questionEnabled" type="checkbox" />

              <span class="toggle-track">
                <span class="toggle-dot" />
              </span>
            </label>
          </div>

          <div
            class="form-grid two"
            :class="{
              disabled: !questionEnabled,
            }"
          >
            <!-- LEVEL -->

            <label class="field">
              <span> Question Level </span>

              <select v-model="questionLevel" :disabled="!questionEnabled">
                <option value="easy">Easy</option>

                <option value="medium">Medium</option>

                <option value="hard">Hard</option>

                <option value="mixed">Mixed</option>
              </select>

              <small> Level question pada battle ini. </small>
            </label>

            <!-- QUESTION EVERY -->

            <label class="field">
              <span> Question Every </span>

              <div class="input-suffix">
                <input
                  v-model.number="questionEveryRounds"
                  type="number"
                  min="1"
                  :max="totalRounds"
                  :disabled="!questionEnabled"
                />

                <span> rounds </span>
              </div>

              <small>
                Contoh: 5 berarti challenge setelah setiap 5 round.
              </small>
            </label>
          </div>
        </section>

        <!-- ===============================================
             ERROR
        ================================================ -->

        <div v-if="error" class="error-box">
          ⚠️

          {{ error }}
        </div>

        <!-- ===============================================
             ACTION
        ================================================ -->

        <div class="form-actions">
          <button type="submit" class="create-button" :disabled="loading">
            <template v-if="loading">
              <span class="spinner" />

              CREATING BATTLE...
            </template>

            <template v-else> ⚔️ CREATE BATTLE </template>
          </button>
        </div>
      </form>
    </main>

    <!-- ===================================================
         BATTLE CREATED
    ==================================================== -->

    <main v-else class="created-container">
      <!-- SUCCESS -->

      <div class="success-icon">✓</div>

      <div class="created-label">BATTLE CREATED</div>

      <h1>Ready to Battle</h1>

      <p class="created-description">
        Battle berhasil dibuat. Gunakan link berikut untuk membuka Public Arena
        dan Player Battle.
      </p>

      <!-- =================================================
           CODE
      ================================================== -->

      <div class="battle-code-card">
        <span> BATTLE CODE </span>

        <strong>
          {{ createdBattle.code }}
        </strong>

        <button type="button" @click="copyText(createdBattle.code)">
          COPY CODE
        </button>
      </div>

      <!-- =================================================
           INFO
      ================================================== -->

      <div class="battle-info">
        <div>
          <span> Starting Player </span>

          <strong>
            {{
              createdBattle.starting_player === "p1"
                ? createdBattle.player1_name
                : createdBattle.player2_name
            }}
          </strong>
        </div>

        <div>
          <span> Rounds </span>

          <strong>
            {{ createdBattle.total_rounds }}
          </strong>
        </div>

        <div>
          <span> Question </span>

          <strong>
            {{
              createdBattle.question_enabled
                ? createdBattle.question_level
                : "Off"
            }}
          </strong>
        </div>

        <div>
          <span> Deck </span>

          <strong>
            {{ createdBattle.deck_size }}
          </strong>
        </div>
      </div>

      <!-- =================================================
           PRIMARY ACTION
      ================================================== -->

      <div class="primary-battle-actions">
        <button
          type="button"
          class="open-public-button"
          @click="openPublicBattle"
        >
          🖥️ OPEN PUBLIC BATTLE
        </button>

        <button
          type="button"
          class="history-secondary-button"
          @click="openBattleHistory"
        >
          ◷ BATTLE HISTORY
        </button>
      </div>

      <!-- =================================================
           LINKS
      ================================================== -->

      <div class="battle-links">
        <!-- ===============================================
             PUBLIC
        ================================================ -->

        <div class="battle-link-card public">
          <div class="link-icon">🖥️</div>

          <div class="link-content">
            <span class="link-label"> PUBLIC BATTLE </span>

            <strong> Main Arena / TV </strong>

            <div class="link-url">
              {{ publicUrl }}
            </div>
          </div>

          <div class="link-actions">
            <button type="button" @click="copyText(publicUrl)">COPY</button>

            <button type="button" class="primary" @click="openPublicBattle">
              OPEN
            </button>
          </div>
        </div>

        <!-- ===============================================
             P1
        ================================================ -->

        <div class="battle-link-card blue">
          <div class="link-icon">👦🏻</div>

          <div class="link-content">
            <span class="link-label"> PLAYER 1 </span>

            <strong>
              {{ createdBattle.player1_name }}
            </strong>

            <div class="link-url">
              {{ player1Url }}
            </div>
          </div>

          <div class="link-actions">
            <button type="button" @click="copyText(player1Url)">COPY</button>

            <button
              type="button"
              class="primary blue"
              @click="openPlayer('p1')"
            >
              OPEN
            </button>
          </div>
        </div>

        <!-- ===============================================
             P2
        ================================================ -->

        <div class="battle-link-card red">
          <div class="link-icon">🧑🏽‍🦱</div>

          <div class="link-content">
            <span class="link-label"> PLAYER 2 </span>

            <strong>
              {{ createdBattle.player2_name }}
            </strong>

            <div class="link-url">
              {{ player2Url }}
            </div>
          </div>

          <div class="link-actions">
            <button type="button" @click="copyText(player2Url)">COPY</button>

            <button type="button" class="primary red" @click="openPlayer('p2')">
              OPEN
            </button>
          </div>
        </div>
      </div>

      <!-- =================================================
           CREATE ANOTHER
      ================================================== -->

      <button type="button" class="another-button" @click="createAnother">
        + CREATE ANOTHER BATTLE
      </button>
    </main>
  </div>
</template>

<style scoped>
/* =========================================================
   GENERAL
========================================================= */

* {
  box-sizing: border-box;
}

button,
input,
select {
  font: inherit;
}

/* =========================================================
   PAGE
========================================================= */

.setup-page {
  min-height: calc(100vh - 76px);

  position: relative;

  overflow-x: hidden;

  padding: 45px 30px 60px;

  color: #f5f8ff;

  background: #050a16;

  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}

/* =========================================================
   BACKGROUND
========================================================= */

.setup-background {
  position: fixed;

  inset: 76px 0 0 256px;

  pointer-events: none;

  overflow: hidden;
}

.bg-orb {
  width: 500px;

  height: 500px;

  position: absolute;

  border-radius: 50%;

  filter: blur(140px);

  opacity: 0.13;
}

.orb-blue {
  top: -220px;

  left: -120px;

  background: #009dff;
}

.orb-red {
  right: -180px;

  bottom: -220px;

  background: #ff284f;
}

/* =========================================================
   CONTAINER
========================================================= */

.setup-container,
.created-container {
  width: min(100%, 1050px);

  margin: 0 auto;

  position: relative;

  z-index: 2;
}

/* =========================================================
   HEADER
========================================================= */

.setup-header {
  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 20px;

  margin-bottom: 30px;
}

.setup-header-main {
  display: flex;

  align-items: center;

  gap: 19px;
}

.setup-logo {
  width: 68px;

  height: 68px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border: 1px solid rgba(70, 193, 255, 0.3);

  border-radius: 18px;

  font-size: 29px;

  background: linear-gradient(
    135deg,
    rgba(0, 161, 255, 0.17),
    rgba(30, 80, 160, 0.04)
  );

  box-shadow: 0 0 30px rgba(0, 165, 255, 0.08);
}

.setup-eyebrow,
.created-label {
  margin-bottom: 5px;

  color: #43cfff;

  font-size: 9px;

  font-weight: 950;

  letter-spacing: 0.23em;
}

.setup-header h1,
.created-container h1 {
  margin: 0;

  font-size: 31px;

  line-height: 1.05;
}

.setup-header p,
.created-description {
  margin: 8px 0 0;

  color: #8192aa;

  font-size: 12px;
}

/* =========================================================
   HISTORY BUTTON
========================================================= */

.history-button {
  min-height: 41px;

  padding: 0 15px;

  flex-shrink: 0;

  border: 1px solid rgba(116, 174, 226, 0.18);

  border-radius: 9px;

  color: #9eb4cc;

  background: rgba(255, 255, 255, 0.025);

  cursor: pointer;

  font-size: 9px;

  font-weight: 900;

  letter-spacing: 0.06em;

  transition: 0.2s ease;
}

.history-button:hover {
  color: #d8e7fa;

  border-color: rgba(126, 193, 255, 0.3);

  background: rgba(255, 255, 255, 0.045);
}

/* =========================================================
   FORM
========================================================= */

.setup-form {
  display: flex;

  flex-direction: column;

  gap: 17px;
}

/* =========================================================
   CARD
========================================================= */

.setup-card {
  padding: 23px;

  border: 1px solid rgba(139, 177, 222, 0.1);

  border-radius: 16px;

  background: linear-gradient(
    145deg,
    rgba(10, 25, 52, 0.94),
    rgba(4, 12, 29, 0.94)
  );

  box-shadow: 0 15px 45px rgba(0, 0, 0, 0.22);
}

/* =========================================================
   HEADING
========================================================= */

.section-heading {
  display: flex;

  align-items: center;

  gap: 12px;

  margin-bottom: 20px;
}

.question-heading {
  justify-content: space-between;
}

.heading-left {
  display: flex;

  align-items: center;

  gap: 12px;
}

.section-icon {
  width: 40px;

  height: 40px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border-radius: 10px;

  background: rgba(255, 255, 255, 0.045);
}

.section-heading h2 {
  margin: 0;

  font-size: 15px;
}

.section-heading p {
  margin: 4px 0 0;

  color: #74879f;

  font-size: 10px;
}

/* =========================================================
   GRID
========================================================= */

.form-grid {
  display: grid;

  gap: 15px;
}

.form-grid.two {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.form-grid.four {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.form-grid.disabled {
  opacity: 0.4;
}

/* =========================================================
   FIELDS
========================================================= */

.field {
  display: flex;

  flex-direction: column;

  gap: 7px;
}

.field > span {
  color: #b6c6dc;

  font-size: 9px;

  font-weight: 850;

  letter-spacing: 0.08em;

  text-transform: uppercase;
}

.field input,
.field select {
  width: 100%;

  min-height: 44px;

  padding: 0 13px;

  border: 1px solid rgba(121, 166, 220, 0.16);

  border-radius: 9px;

  outline: none;

  color: #eef7ff;

  background: #071224;

  font-size: 12px;

  transition: 0.2s ease;
}

.field input:focus,
.field select:focus {
  border-color: rgba(45, 192, 255, 0.6);

  box-shadow: 0 0 0 3px rgba(25, 156, 255, 0.08);
}

.field input:disabled,
.field select:disabled {
  cursor: not-allowed;
}

.field small {
  min-height: 14px;

  color: #61758f;

  font-size: 8px;

  line-height: 1.4;
}

/* =========================================================
   INPUT SUFFIX
========================================================= */

.input-suffix {
  display: flex;

  align-items: center;

  overflow: hidden;

  border: 1px solid rgba(121, 166, 220, 0.16);

  border-radius: 9px;

  background: #071224;
}

.input-suffix input {
  border: 0;

  border-radius: 0;
}

.input-suffix span {
  padding-right: 13px;

  color: #647994;

  font-size: 10px;
}

/* =========================================================
   DECK SUMMARY
========================================================= */

.deck-summary {
  display: flex;

  flex-wrap: wrap;

  gap: 9px;

  margin-top: 17px;
}

.deck-summary span {
  display: flex;

  align-items: center;

  gap: 7px;

  padding: 7px 10px;

  border: 1px solid rgba(255, 255, 255, 0.06);

  border-radius: 8px;

  color: #71849d;

  background: rgba(255, 255, 255, 0.02);

  font-size: 8px;
}

.deck-summary strong {
  color: #e4f4ff;
}

/* =========================================================
   TOGGLE
========================================================= */

.toggle {
  cursor: pointer;
}

.toggle input {
  position: absolute;

  opacity: 0;
}

.toggle-track {
  width: 44px;

  height: 24px;

  display: flex;

  align-items: center;

  padding: 3px;

  border-radius: 999px;

  background: #263348;

  transition: 0.2s ease;
}

.toggle-dot {
  width: 18px;

  height: 18px;

  display: block;

  border-radius: 50%;

  background: white;

  transition: 0.2s ease;
}

.toggle input:checked + .toggle-track {
  background: #129bd5;
}

.toggle input:checked + .toggle-track .toggle-dot {
  transform: translateX(20px);
}

/* =========================================================
   ERROR
========================================================= */

.error-box {
  padding: 13px 15px;

  border: 1px solid rgba(255, 71, 99, 0.3);

  border-radius: 10px;

  color: #ff93a6;

  background: rgba(255, 43, 78, 0.08);

  font-size: 11px;
}

/* =========================================================
   CREATE
========================================================= */

.form-actions {
  display: flex;

  justify-content: flex-end;

  padding: 8px 0;
}

.create-button {
  min-width: 235px;

  min-height: 49px;

  border: 1px solid rgba(79, 210, 255, 0.5);

  border-radius: 11px;

  color: #e9fbff;

  background: linear-gradient(135deg, #0779ba, #084a8a);

  cursor: pointer;

  font-size: 10px;

  font-weight: 950;

  letter-spacing: 0.1em;

  box-shadow: 0 12px 30px rgba(0, 120, 210, 0.2);
}

.create-button:disabled {
  opacity: 0.55;

  cursor: wait;
}

/* =========================================================
   SPINNER
========================================================= */

.spinner {
  width: 13px;

  height: 13px;

  display: inline-block;

  margin-right: 8px;

  border: 2px solid rgba(255, 255, 255, 0.25);

  border-top-color: white;

  border-radius: 50%;

  vertical-align: middle;

  animation: spin 0.7s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* =========================================================
   CREATED
========================================================= */

.created-container {
  max-width: 850px;

  text-align: center;
}

.success-icon {
  width: 65px;

  height: 65px;

  margin: 0 auto 18px;

  display: grid;

  place-items: center;

  border: 1px solid rgba(56, 231, 149, 0.35);

  border-radius: 50%;

  color: #6dffbd;

  background: rgba(33, 195, 120, 0.1);

  font-size: 27px;

  font-weight: 950;

  box-shadow: 0 0 35px rgba(42, 221, 142, 0.11);
}

.created-description {
  max-width: 530px;

  margin: 10px auto 27px;
}

/* =========================================================
   BATTLE CODE
========================================================= */

.battle-code-card {
  width: min(100%, 520px);

  margin: 0 auto 24px;

  padding: 18px;

  border: 1px solid rgba(44, 195, 255, 0.22);

  border-radius: 16px;

  background: linear-gradient(
    135deg,
    rgba(12, 66, 112, 0.3),
    rgba(4, 18, 39, 0.8)
  );
}

.battle-code-card span {
  display: block;

  margin-bottom: 7px;

  color: #7892ad;

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.2em;
}

.battle-code-card strong {
  display: block;

  color: white;

  font-size: 38px;

  letter-spacing: 0.17em;
}

.battle-code-card button {
  margin-top: 11px;

  padding: 7px 13px;

  border: 1px solid rgba(74, 202, 255, 0.25);

  border-radius: 7px;

  color: #6bd7ff;

  background: rgba(18, 152, 205, 0.08);

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;
}

/* =========================================================
   INFO
========================================================= */

.battle-info {
  display: grid;

  grid-template-columns: repeat(4, 1fr);

  gap: 9px;

  margin-bottom: 22px;
}

.battle-info > div {
  padding: 13px;

  border: 1px solid rgba(255, 255, 255, 0.06);

  border-radius: 10px;

  background: rgba(255, 255, 255, 0.025);
}

.battle-info span {
  display: block;

  margin-bottom: 5px;

  color: #6c819b;

  font-size: 7px;

  font-weight: 850;

  text-transform: uppercase;
}

.battle-info strong {
  font-size: 11px;

  text-transform: capitalize;
}

/* =========================================================
   PRIMARY ACTIONS
========================================================= */

.primary-battle-actions {
  display: flex;

  justify-content: center;

  gap: 10px;

  margin-bottom: 23px;
}

.open-public-button {
  min-height: 48px;

  padding: 0 24px;

  border: 1px solid rgba(70, 210, 255, 0.45);

  border-radius: 10px;

  color: #eaffff;

  background: linear-gradient(135deg, #087eba, #07518f);

  cursor: pointer;

  font-size: 9px;

  font-weight: 950;

  letter-spacing: 0.08em;

  box-shadow: 0 10px 30px rgba(0, 145, 220, 0.18);
}

.history-secondary-button {
  min-height: 48px;

  padding: 0 18px;

  border: 1px solid rgba(255, 255, 255, 0.1);

  border-radius: 10px;

  color: #8ea5bd;

  background: rgba(255, 255, 255, 0.025);

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;
}

/* =========================================================
   LINKS
========================================================= */

.battle-links {
  display: flex;

  flex-direction: column;

  gap: 10px;
}

.battle-link-card {
  display: grid;

  grid-template-columns:
    48px
    1fr
    auto;

  gap: 13px;

  align-items: center;

  padding: 15px;

  border: 1px solid rgba(255, 255, 255, 0.07);

  border-radius: 13px;

  text-align: left;

  background: rgba(8, 19, 39, 0.85);
}

.battle-link-card.blue {
  border-color: rgba(45, 183, 255, 0.18);
}

.battle-link-card.red {
  border-color: rgba(255, 62, 98, 0.18);
}

.link-icon {
  width: 42px;

  height: 42px;

  display: grid;

  place-items: center;

  border-radius: 10px;

  background: rgba(255, 255, 255, 0.04);

  font-size: 20px;
}

.link-label {
  display: block;

  margin-bottom: 3px;

  color: #687d97;

  font-size: 7px;

  font-weight: 900;

  letter-spacing: 0.12em;
}

.link-content strong {
  font-size: 11px;
}

.link-url {
  margin-top: 4px;

  overflow: hidden;

  color: #536a84;

  font-size: 8px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.link-actions {
  display: flex;

  gap: 7px;
}

.link-actions button {
  padding: 8px 11px;

  border: 1px solid rgba(255, 255, 255, 0.1);

  border-radius: 7px;

  color: #a5b5c9;

  background: rgba(255, 255, 255, 0.035);

  cursor: pointer;

  font-size: 7px;

  font-weight: 900;
}

.link-actions button.primary {
  color: #7bdfff;

  border-color: rgba(58, 195, 255, 0.25);
}

.link-actions button.primary.red {
  color: #ff849a;

  border-color: rgba(255, 68, 101, 0.25);
}

/* =========================================================
   ANOTHER
========================================================= */

.another-button {
  margin-top: 21px;

  padding: 10px 15px;

  border: 0;

  color: #7087a2;

  background: transparent;

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;
}

/* =========================================================
   RESPONSIVE
========================================================= */

@media (max-width: 900px) {
  .setup-background {
    left: 0;
  }
}

@media (max-width: 750px) {
  .setup-page {
    padding: 30px 14px 45px;
  }

  .setup-header {
    align-items: flex-start;

    flex-direction: column;
  }

  .setup-header-main {
    align-items: flex-start;
  }

  .setup-logo {
    width: 55px;

    height: 55px;
  }

  .setup-header h1 {
    font-size: 27px;
  }

  .form-grid.two,
  .form-grid.four {
    grid-template-columns: 1fr;
  }

  .battle-info {
    grid-template-columns: repeat(2, 1fr);
  }

  .primary-battle-actions {
    flex-direction: column;
  }

  .battle-link-card {
    grid-template-columns:
      42px
      1fr;
  }

  .link-actions {
    grid-column: 1 / -1;

    justify-content: flex-end;
  }

  .battle-code-card strong {
    font-size: 30px;
  }
}
</style>
