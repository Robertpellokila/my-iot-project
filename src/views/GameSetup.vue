<script setup>
import { ref, computed } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "../lib/supabase";
import QRCode from "qrcode";

// =========================================================
// ROUTER
// =========================================================

const router = useRouter();

// =========================================================
// PLAYER
// =========================================================

const player1Name = ref("Player 1");
const player2Name = ref("Player 2");

// =========================================================
// GAME RULES
// =========================================================

const totalRounds = ref(10);
const startingPlayer = ref("random");

// =========================================================
// TCG V1
// =========================================================

const ruleset = ref("tcg_v1");

const playerStartingHp = ref(200);

// =========================================================
// PHYSICAL DECK
// =========================================================

const deckSize = ref(20);
const initialCardsRequired = ref(3);
const maxActive = ref(4);
const maxBench = ref(4);

// =========================================================
// TCG COMBAT
// =========================================================

const targetCardEnabled = ref(true);
const directAttackEnabled = ref(true);

const destructionDamageEnabled = ref(true);

// Untuk TCG V1 awal:
//
// final_damage_percent
// overflow_percent
//
// Fixed damage belum digunakan karena schema sekarang
// memakai destruction_damage_percent 0.00 - 1.00.
const destructionDamageMode = ref("final_damage_percent");

const destructionDamagePercent = ref(30);

// =========================================================
// ADVANCED TCG
// =========================================================

const specialCardSkillsEnabled = ref(true);
const comboEnabled = ref(true);
const fusionEnabled = ref(true);

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
// PLAYER QR CODE
// =========================================================

const player1QrDataUrl = ref("");
const player2QrDataUrl = ref("");
const qrError = ref(null);

// =========================================================
// CREATED URLS
// =========================================================

const publicUrl = computed(() => {
  if (!createdBattle.value?.code) {
    return "";
  }

  return `${window.location.origin}/battle/${createdBattle.value.code}`;
});

const player1Url = computed(() => {
  if (
    !createdBattle.value?.code ||
    !createdBattle.value?.player1_token
  ) {
    return "";
  }

  return (
    `${window.location.origin}` +
    `/play/${createdBattle.value.code}/p1` +
    `?token=${encodeURIComponent(
      createdBattle.value.player1_token,
    )}`
  );
});

const player2Url = computed(() => {
  if (
    !createdBattle.value?.code ||
    !createdBattle.value?.player2_token
  ) {
    return "";
  }

  return (
    `${window.location.origin}` +
    `/play/${createdBattle.value.code}/p2` +
    `?token=${encodeURIComponent(
      createdBattle.value.player2_token,
    )}`
  );
});

// =========================================================
// GENERATE PLAYER QR CODE LOCALLY
//
// QR dibuat di browser agar URL player yang berisi token
// tidak dikirim ke layanan QR pihak ketiga.
// =========================================================

const generatePlayerQrs = async () => {
  qrError.value = null;
  player1QrDataUrl.value = "";
  player2QrDataUrl.value = "";

  if (!player1Url.value || !player2Url.value) {
    return;
  }

  try {
    const qrOptions = {
      width: 320,
      margin: 1,
      errorCorrectionLevel: "M",
      color: {
        dark: "#07111f",
        light: "#ffffff",
      },
    };

    const [p1Qr, p2Qr] = await Promise.all([
      QRCode.toDataURL(player1Url.value, qrOptions),
      QRCode.toDataURL(player2Url.value, qrOptions),
    ]);

    player1QrDataUrl.value = p1Qr;
    player2QrDataUrl.value = p2Qr;
  } catch (err) {
    console.error("Generate Player QR gagal:", err);

    qrError.value =
      err?.message ??
      "QR Code player gagal dibuat.";
  }
};

// =========================================================
// DISPLAY
// =========================================================

const destructionDamageDisplay = computed(() => {
  if (!destructionDamageEnabled.value) {
    return "OFF";
  }

  return `${Number(destructionDamagePercent.value)}%`;
});

const deckAfterInitial = computed(() => {
  return Math.max(
    0,
    Number(deckSize.value) -
      Number(initialCardsRequired.value),
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

  const characters =
    "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

  let result = "";

  for (let i = 0; i < 6; i++) {
    result +=
      characters[
        Math.floor(
          Math.random() *
            characters.length,
        )
      ];
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

  return Math.random() < 0.5
    ? "p1"
    : "p2";
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

  // =======================================================
  // ROUND
  // =======================================================

  if (Number(totalRounds.value) < 1) {
    return "Jumlah round minimal 1.";
  }

  if (Number(totalRounds.value) > 100) {
    return "Jumlah round maksimal 100.";
  }

  // =======================================================
  // PLAYER HP
  // =======================================================

  if (
    !Number.isFinite(
      Number(playerStartingHp.value),
    ) ||
    Number(playerStartingHp.value) < 1
  ) {
    return "Player Starting HP minimal 1.";
  }

  if (
    Number(playerStartingHp.value) >
    99999
  ) {
    return "Player Starting HP terlalu besar.";
  }

  // =======================================================
  // DECK
  // =======================================================

  if (
    !Number.isFinite(
      Number(deckSize.value),
    ) ||
    Number(deckSize.value) < 1
  ) {
    return "Deck Size minimal 1.";
  }

  if (Number(deckSize.value) > 100) {
    return "Deck Size maksimal 100 kartu.";
  }

  if (
    Number(initialCardsRequired.value) <
    1
  ) {
    return "Initial Cards minimal 1.";
  }

  if (Number(maxActive.value) < 1) {
    return "Max Active minimal 1.";
  }

  if (Number(maxBench.value) < 0) {
    return "Max Bench tidak valid.";
  }

  if (
    Number(initialCardsRequired.value) >
    Number(maxActive.value)
  ) {
    return (
      "Initial Cards tidak boleh " +
      "lebih besar dari Max Active."
    );
  }

  if (
    Number(
      initialCardsRequired.value,
    ) > Number(deckSize.value)
  ) {
    return (
      "Initial Cards tidak boleh " +
      "lebih besar dari Deck Size."
    );
  }

  if (
    Number(maxActive.value) >
    Number(deckSize.value)
  ) {
    return (
      "Max Active tidak boleh " +
      "lebih besar dari Deck Size."
    );
  }

  if (
    Number(maxActive.value) +
      Number(maxBench.value) >
    Number(deckSize.value)
  ) {
    return (
      "Max Active + Max Bench " +
      "tidak boleh melebihi Deck Size."
    );
  }

  // =======================================================
  // DESTRUCTION DAMAGE
  // =======================================================

  if (
    destructionDamageEnabled.value
  ) {
    if (
      Number(
        destructionDamagePercent.value,
      ) < 0 ||
      Number(
        destructionDamagePercent.value,
      ) > 100
    ) {
      return (
        "Destruction Damage harus " +
        "antara 0% sampai 100%."
      );
    }

    if (
      ![
        "final_damage_percent",
        "overflow_percent",
      ].includes(
        destructionDamageMode.value,
      )
    ) {
      return (
        "Destruction Damage Mode " +
        "tidak valid."
      );
    }
  }

  // =======================================================
  // QUESTION
  // =======================================================

  if (
    questionEnabled.value &&
    Number(
      questionEveryRounds.value,
    ) < 1
  ) {
    return (
      "Question Every minimal " +
      "1 round."
    );
  }

  if (
    questionEnabled.value &&
    Number(
      questionEveryRounds.value,
    ) > Number(totalRounds.value)
  ) {
    return (
      "Question Every tidak boleh " +
      "lebih besar dari Total Rounds."
    );
  }

  return null;
};

// =========================================================
// CREATE BATTLE
// =========================================================

const createBattle = async () => {
  error.value = null;

  const validationError =
    validateForm();

  if (validationError) {
    error.value =
      validationError;

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
    } =
      await supabase.auth.getUser();

    if (userError) {
      throw userError;
    }

    if (!user) {
      throw new Error(
        "Session login tidak ditemukan.",
      );
    }

    // =====================================================
    // STARTING PLAYER
    // =====================================================

    const resolvedStartingPlayer =
      resolveStartingPlayer();

    // =====================================================
    // RETRY CODE
    // =====================================================

    let created = null;
    let lastError = null;

    for (
      let attempt = 0;
      attempt < 5;
      attempt++
    ) {
      const code =
        generateBattleCode();

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

        player1_name:
          player1Name.value.trim(),

        player2_name:
          player2Name.value.trim(),

        // =================================================
        // RULESET
        // =================================================

        ruleset:
          ruleset.value,

        // =================================================
        // GAME RULES
        // =================================================

        total_rounds:
          Number(
            totalRounds.value,
          ),

        starting_player:
          resolvedStartingPlayer,

        current_turn:
          resolvedStartingPlayer,

        // =================================================
        // PLAYER HP
        // =================================================

        player_starting_hp:
          Number(
            playerStartingHp.value,
          ),

        player1_hp:
          Number(
            playerStartingHp.value,
          ),

        player1_max_hp:
          Number(
            playerStartingHp.value,
          ),

        player2_hp:
          Number(
            playerStartingHp.value,
          ),

        player2_max_hp:
          Number(
            playerStartingHp.value,
          ),

        // =================================================
        // PHYSICAL DECK
        // =================================================

        deck_size:
          Number(
            deckSize.value,
          ),

        player1_starting_deck:
          Number(
            deckSize.value,
          ),

        player2_starting_deck:
          Number(
            deckSize.value,
          ),

        player1_deck_remaining:
          Number(
            deckSize.value,
          ),

        player2_deck_remaining:
          Number(
            deckSize.value,
          ),

        initial_cards_required:
          Number(
            initialCardsRequired.value,
          ),

        max_active:
          Number(
            maxActive.value,
          ),

        max_bench:
          Number(
            maxBench.value,
          ),

        // =================================================
        // TCG COMBAT
        // =================================================

        target_card_enabled:
          Boolean(
            targetCardEnabled.value,
          ),

        direct_attack_enabled:
          Boolean(
            directAttackEnabled.value,
          ),

        destruction_damage_enabled:
          Boolean(
            destructionDamageEnabled.value,
          ),

        destruction_damage_mode:
          destructionDamageMode.value,

        destruction_damage_percent:
          Number(
            destructionDamagePercent.value,
          ) / 100,

        // =================================================
        // ADVANCED TCG
        // =================================================

        special_card_skills_enabled:
          Boolean(
            specialCardSkillsEnabled.value,
          ),

        combo_enabled:
          Boolean(
            comboEnabled.value,
          ),

        fusion_enabled:
          Boolean(
            fusionEnabled.value,
          ),

        // =================================================
        // QUESTION
        // =================================================

        question_enabled:
          Boolean(
            questionEnabled.value,
          ),

        question_level:
          questionLevel.value,

        question_every_rounds:
          Number(
            questionEveryRounds.value,
          ),

        question_active:
          false,

        current_question_id:
          null,

        current_question_round_id:
          null,

        // =================================================
        // GAME STATE
        // =================================================

        round: 1,

        status: "waiting",

        winner: null,

        // =================================================
        // SKILL
        // =================================================

        player1_skill: 0,

        player2_skill: 0,

        // =================================================
        // DEFENSE
        // =================================================

        player1_defending:
          false,

        player2_defending:
          false,

        // =================================================
        // SYNERGY
        // =================================================

        player1_synergy_shield:
          0,

        player2_synergy_shield:
          0,

        player1_attack_debuff:
          0,

        player2_attack_debuff:
          0,

        // =================================================
        // DATE
        // =================================================

        started_at: null,

        finished_at: null,
      };

      // ===================================================
      // INSERT
      // ===================================================

      const {
        data,
        error: insertError,
      } = await supabase
        .from(
          "battle_sessions",
        )
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

      lastError =
        insertError;

      // ===================================================
      // UNIQUE CODE COLLISION
      // ===================================================

      if (
        insertError.code !==
        "23505"
      ) {
        throw insertError;
      }
    }

    // =====================================================
    // FAILED AFTER RETRY
    // =====================================================

    if (!created) {
      throw (
        lastError ??
        new Error(
          "Gagal membuat Battle Code.",
        )
      );
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
      console.error(
        "RFID binding gagal:",
        bindError,
      );

      throw bindError;
    }

    if (
      bindResult?.ok ===
      false
    ) {
      throw new Error(
        bindResult.message ??
          "Gagal menghubungkan RFID readers.",
      );
    }

    createdBattle.value =
      created;

    await generatePlayerQrs();
  } catch (err) {
    console.error(
      "Create Battle:",
      err,
    );

    error.value =
      err?.message ??
      "Gagal membuat battle.";
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
    await navigator.clipboard.writeText(
      text,
    );
  } catch (err) {
    console.error(
      "Copy gagal:",
      err,
    );
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
  if (
    !createdBattle.value?.code
  ) {
    return;
  }

  router.push({
    name: "public-battle",

    params: {
      code:
        createdBattle.value
          .code,
    },
  });
};

const openPlayer = (
  playerValue,
) => {
  if (
    !createdBattle.value?.code
  ) {
    return;
  }

  const playerToken =
    playerValue === "p1"
      ? createdBattle.value
          .player1_token
      : createdBattle.value
          .player2_token;

  router.push({
    name: "player-battle",

    params: {
      code:
        createdBattle.value
          .code,

      player:
        playerValue,
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
  createdBattle.value =
    null;

  player1QrDataUrl.value = "";
  player2QrDataUrl.value = "";
  qrError.value = null;

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

    <main
      v-if="!createdBattle"
      class="setup-container"
    >
      <!-- =================================================
           HEADER
      ================================================== -->

      <header class="setup-header">
        <div
          class="setup-header-main"
        >
          <div
            class="setup-logo"
          >
            ⚔️
          </div>

          <div>
            <div
              class="setup-eyebrow"
            >
              BATTLE CONTROL
            </div>

            <h1>
              Create Battle
            </h1>

            <p>
              Atur pemain,
              physical deck,
              TCG rules,
              round, dan coding
              challenge sebelum
              pertandingan dimulai.
            </p>
          </div>
        </div>

        <button
          type="button"
          class="history-button"
          @click="
            openBattleHistory
          "
        >
          ◷ BATTLE HISTORY
        </button>
      </header>

      <!-- =================================================
           FORM
      ================================================== -->

      <form
        class="setup-form"
        @submit.prevent="
          createBattle
        "
      >
        <!-- ===============================================
             PLAYERS
        ================================================ -->

        <section
          class="setup-card"
        >
          <div
            class="section-heading"
          >
            <div
              class="section-icon"
            >
              👥
            </div>

            <div>
              <h2>
                Players
              </h2>

              <p>
                Tentukan nama
                kedua pemain.
              </p>
            </div>
          </div>

          <div
            class="form-grid two"
          >
            <label
              class="field"
            >
              <span>
                Player 1
              </span>

              <input
                v-model="
                  player1Name
                "
                type="text"
                maxlength="40"
                placeholder="Player 1"
              />
            </label>

            <label
              class="field"
            >
              <span>
                Player 2
              </span>

              <input
                v-model="
                  player2Name
                "
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

        <section
          class="setup-card"
        >
          <div
            class="section-heading"
          >
            <div
              class="section-icon"
            >
              🎮
            </div>

            <div>
              <h2>
                Game Rules
              </h2>

              <p>
                Rule utama battle
                untuk TCG V1.
              </p>
            </div>
          </div>

          <div
            class="ruleset-banner compact"
          >
            <div>
              <span>
                ACTIVE RULESET
              </span>

              <strong>
                TCG V1
              </strong>
            </div>

            <small>
              Card HP • Graveyard
              • Physical Deck
            </small>
          </div>

          <div
            class="form-grid three"
          >
            <!-- TOTAL ROUND -->

            <label
              class="field"
            >
              <span>
                Total Rounds
              </span>

              <input
                v-model.number="
                  totalRounds
                "
                type="number"
                min="1"
                max="100"
              />

              <small>
                Battle berakhir
                jika HP Player 0
                atau round mencapai
                batas.
              </small>
            </label>

            <!-- STARTING PLAYER -->

            <label
              class="field"
            >
              <span>
                Starting Player
              </span>

              <select
                v-model="
                  startingPlayer
                "
              >
                <option
                  value="random"
                >
                  🎲 Random
                </option>

                <option
                  value="p1"
                >
                  Player 1
                </option>

                <option
                  value="p2"
                >
                  Player 2
                </option>
              </select>

              <small>
                Jika Random,
                player awal dipilih
                saat battle dibuat.
              </small>
            </label>

            <!-- PLAYER HP -->

            <label
              class="field"
            >
              <span>
                Player Starting HP
              </span>

              <input
                v-model.number="
                  playerStartingHp
                "
                type="number"
                min="1"
                max="99999"
              />

              <small>
                HP utama Player.
                Card HP tidak lagi
                ditambahkan ke
                Player HP pada
                TCG V1.
              </small>
            </label>
          </div>
        </section>

        <!-- ===============================================
             PHYSICAL DECK
        ================================================ -->

        <section
          class="setup-card"
        >
          <div
            class="section-heading"
          >
            <div
              class="section-icon"
            >
              🎴
            </div>

            <div>
              <h2>
                Physical Deck
              </h2>

              <p>
                Tentukan jumlah
                physical card yang
                digunakan masing-masing
                player.
              </p>
            </div>
          </div>

          <div
            class="form-grid four"
          >
            <!-- DECK SIZE -->

            <label
              class="field"
            >
              <span>
                Deck Size
              </span>

              <input
                v-model.number="
                  deckSize
                "
                type="number"
                min="1"
                max="100"
              />

              <small>
                Jumlah physical card
                yang diambil oleh
                masing-masing player.
              </small>
            </label>

            <!-- INITIAL -->

            <label
              class="field"
            >
              <span>
                Initial Cards
              </span>

              <input
                v-model.number="
                  initialCardsRequired
                "
                type="number"
                min="1"
                :max="
                  maxActive
                "
              />

              <small>
                Card yang harus
                discan sebelum
                battle dimulai.
              </small>
            </label>

            <!-- ACTIVE -->

            <label
              class="field"
            >
              <span>
                Max Active
              </span>

              <input
                v-model.number="
                  maxActive
                "
                type="number"
                min="1"
                :max="
                  deckSize
                "
              />

              <small>
                Maksimal card
                aktif di arena.
              </small>
            </label>

            <!-- BENCH -->

            <label
              class="field"
            >
              <span>
                Max Bench
              </span>

              <input
                v-model.number="
                  maxBench
                "
                type="number"
                min="0"
                :max="
                  deckSize
                "
              />

              <small>
                Maksimal card
                yang berada
                di Bench.
              </small>
            </label>
          </div>

          <!-- SUMMARY -->

          <div
            class="deck-summary"
          >
            <span>
              Physical Deck

              <strong>
                {{ deckSize }}
              </strong>
            </span>

            <span>
              Initial

              <strong>
                {{
                  initialCardsRequired
                }}
              </strong>
            </span>

            <span>
              Remaining
              After Initial

              <strong>
                {{
                  deckAfterInitial
                }}
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

          <div
            class="info-note"
          >
            <strong>
              PHYSICAL DECK
            </strong>

            Kartu tidak perlu
            didaftarkan ke Battle
            sebelum pertandingan.
            Server hanya menghitung
            berapa kartu dari jatah
            physical deck yang sudah
            dimainkan.
          </div>
        </section>

        <!-- ===============================================
             TCG COMBAT
        ================================================ -->

        <section
          class="setup-card tcg-card"
        >
          <div
            class="section-heading"
          >
            <div
              class="section-icon"
            >
              ⚔️
            </div>

            <div>
              <h2>
                TCG Combat Rules
              </h2>

              <p>
                Konfigurasi mekanik
                pertarungan kartu.
              </p>
            </div>
          </div>

          <div
            class="ruleset-banner"
          >
            <div>
              <span>
                ACTIVE RULESET
              </span>

              <strong>
                TCG V1
              </strong>
            </div>

            <small>
              Target Card •
              Destruction Damage •
              Graveyard •
              Direct Attack
            </small>
          </div>

          <div
            class="combat-rule-list"
          >
            <!-- TARGET CARD -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  🎯 Target Card
                  Attack
                </strong>

                <small>
                  Player memilih
                  Active Card lawan
                  yang ingin diserang.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    targetCardEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>

            <!-- DIRECT ATTACK -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  💥 Direct Attack
                </strong>

                <small>
                  Mengizinkan damage
                  langsung ke Player
                  jika kondisi direct
                  attack terpenuhi.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    directAttackEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>

            <!-- DESTRUCTION -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  🔥 Destruction
                  Damage
                </strong>

                <small>
                  Saat sebuah Card
                  dihancurkan, owner
                  Card menerima damage
                  tambahan.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    destructionDamageEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>
          </div>

          <!-- DESTRUCTION CONFIG -->

          <div
            class="form-grid two destruction-settings"
            :class="{
              disabled:
                !destructionDamageEnabled,
            }"
          >
            <label
              class="field"
            >
              <span>
                Destruction Mode
              </span>

              <select
                v-model="
                  destructionDamageMode
                "
                :disabled="
                  !destructionDamageEnabled
                "
              >
                <option
                  value="final_damage_percent"
                >
                  Final Damage %
                </option>

                <option
                  value="overflow_percent"
                >
                  Overflow Damage %
                </option>
              </select>

              <small
                v-if="
                  destructionDamageMode ===
                  'final_damage_percent'
                "
              >
                Player menerima
                persentase dari
                final damage
                penghancur Card.
              </small>

              <small
                v-else
              >
                Player hanya menerima
                persentase damage
                yang melewati sisa
                HP Card.
              </small>
            </label>

            <label
              class="field"
            >
              <span>
                Destruction Damage
              </span>

              <div
                class="input-suffix"
              >
                <input
                  v-model.number="
                    destructionDamagePercent
                  "
                  type="number"
                  min="0"
                  max="100"
                  :disabled="
                    !destructionDamageEnabled
                  "
                />

                <span>
                  %
                </span>
              </div>

              <small>
                Default TCG V1:
                30%.
              </small>
            </label>
          </div>

          <div
            class="combat-preview"
          >
            <span>
              DESTRUCTION
            </span>

            <strong>
              {{
                destructionDamageDisplay
              }}
            </strong>

            <p
              v-if="
                destructionDamageMode ===
                'final_damage_percent'
              "
            >
              Jika final damage
              penghancur Card = 60
              dan setting 30%,
              Player menerima
              18 damage.
            </p>

            <p v-else>
              Jika Card tersisa
              40 HP menerima
              60 damage, overflow
              adalah 20. Dengan
              30%, Player menerima
              6 damage.
            </p>
          </div>
        </section>

        <!-- ===============================================
             ADVANCED TCG
        ================================================ -->

        <section
          class="setup-card"
        >
          <div
            class="section-heading"
          >
            <div
              class="section-icon"
            >
              ✨
            </div>

            <div>
              <h2>
                Advanced TCG
              </h2>

              <p>
                Feature flag untuk
                mekanik Card lanjutan.
              </p>
            </div>
          </div>

          <div
            class="combat-rule-list"
          >
            <!-- SKILL -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  🪄 Special
                  Card Skills
                </strong>

                <small>
                  Mengaktifkan skill
                  khusus yang dimiliki
                  Card tertentu.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    specialCardSkillsEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>

            <!-- COMBO -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  🔗 Card
                  Combination
                </strong>

                <small>
                  Kombinasi Card
                  tertentu di luar
                  Element Synergy.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    comboEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>

            <!-- FUSION -->

            <label
              class="rule-option"
            >
              <div>
                <strong>
                  🌟 Fusion
                </strong>

                <small>
                  Mengizinkan beberapa
                  Card digabung menjadi
                  Fusion Card.
                </small>
              </div>

              <span
                class="toggle"
              >
                <input
                  v-model="
                    fusionEnabled
                  "
                  type="checkbox"
                />

                <span
                  class="toggle-track"
                >
                  <span
                    class="toggle-dot"
                  />
                </span>
              </span>
            </label>
          </div>

          <div
            class="future-note"
          >
            <span>
              PLANNED
            </span>

            Special Skill,
            Combination, dan Fusion
            sudah disimpan dalam
            battle rules. Engine-nya
            akan kita aktifkan pada
            fase berikutnya.
          </div>
        </section>

        <!-- ===============================================
             CODING QUESTION
        ================================================ -->

        <section
          class="setup-card"
        >
          <div
            class="section-heading question-heading"
          >
            <div
              class="heading-left"
            >
              <div
                class="section-icon"
              >
                💻
              </div>

              <div>
                <h2>
                  Coding Challenge
                </h2>

                <p>
                  Player tercepat
                  yang menjawab benar
                  mendapatkan random
                  bonus skill.
                </p>
              </div>
            </div>

            <label
              class="toggle"
            >
              <input
                v-model="
                  questionEnabled
                "
                type="checkbox"
              />

              <span
                class="toggle-track"
              >
                <span
                  class="toggle-dot"
                />
              </span>
            </label>
          </div>

          <div
            class="form-grid two"
            :class="{
              disabled:
                !questionEnabled,
            }"
          >
            <!-- LEVEL -->

            <label
              class="field"
            >
              <span>
                Question Level
              </span>

              <select
                v-model="
                  questionLevel
                "
                :disabled="
                  !questionEnabled
                "
              >
                <option
                  value="easy"
                >
                  Easy
                </option>

                <option
                  value="medium"
                >
                  Medium
                </option>

                <option
                  value="hard"
                >
                  Hard
                </option>

                <option
                  value="mixed"
                >
                  Mixed
                </option>
              </select>

              <small>
                Difficulty question
                pada battle ini.
              </small>
            </label>

            <!-- QUESTION EVERY -->

            <label
              class="field"
            >
              <span>
                Question Every
              </span>

              <div
                class="input-suffix"
              >
                <input
                  v-model.number="
                    questionEveryRounds
                  "
                  type="number"
                  min="1"
                  :max="
                    totalRounds
                  "
                  :disabled="
                    !questionEnabled
                  "
                />

                <span>
                  rounds
                </span>
              </div>

              <small>
                Contoh: 5 berarti
                challenge setelah
                setiap 5 round.
              </small>
            </label>
          </div>
        </section>

        <!-- ===============================================
             ERROR
        ================================================ -->

        <div
          v-if="error"
          class="error-box"
        >
          ⚠️ {{ error }}
        </div>

        <!-- ===============================================
             ACTION
        ================================================ -->

        <div
          class="form-actions"
        >
          <button
            type="submit"
            class="create-button"
            :disabled="
              loading
            "
          >
            <template
              v-if="
                loading
              "
            >
              <span
                class="spinner"
              />

              CREATING BATTLE...
            </template>

            <template v-else>
              ⚔️ CREATE TCG BATTLE
            </template>
          </button>
        </div>
      </form>
    </main>

    <!-- ===================================================
         CREATED
    ==================================================== -->

    <main
      v-else
      class="created-container"
    >
      <div
        class="success-icon"
      >
        ✓
      </div>

      <div
        class="created-label"
      >
        BATTLE CREATED
      </div>

      <h1>
        Ready to Battle
      </h1>

      <p
        class="created-description"
      >
        Battle TCG V1 berhasil
        dibuat. Gunakan link berikut
        untuk membuka Public Arena
        dan Player Battle.
      </p>

      <!-- CODE -->

      <div
        class="battle-code-card"
      >
        <span>
          BATTLE CODE
        </span>

        <strong>
          {{
            createdBattle.code
          }}
        </strong>

        <button
          type="button"
          @click="
            copyText(
              createdBattle.code,
            )
          "
        >
          COPY CODE
        </button>
      </div>

      <!-- INFO -->

      <div
        class="battle-info"
      >
        <div>
          <span>
            Ruleset
          </span>

          <strong>
            {{
              createdBattle.ruleset
                ?.toUpperCase()
            }}
          </strong>
        </div>

        <div>
          <span>
            Starting Player
          </span>

          <strong>
            {{
              createdBattle
                .starting_player ===
              "p1"
                ? createdBattle
                    .player1_name
                : createdBattle
                    .player2_name
            }}
          </strong>
        </div>

        <div>
          <span>
            Player HP
          </span>

          <strong>
            {{
              createdBattle
                .player_starting_hp
            }}
          </strong>
        </div>

        <div>
          <span>
            Rounds
          </span>

          <strong>
            {{
              createdBattle
                .total_rounds
            }}
          </strong>
        </div>

        <div>
          <span>
            Physical Deck
          </span>

          <strong>
            {{
              createdBattle
                .deck_size
            }}
          </strong>
        </div>

        <div>
          <span>
            Initial Cards
          </span>

          <strong>
            {{
              createdBattle
                .initial_cards_required
            }}
          </strong>
        </div>

        <div>
          <span>
            Destruction
          </span>

          <strong>
            {{
              createdBattle
                .destruction_damage_enabled
                ? `${Math.round(
                    Number(
                      createdBattle
                        .destruction_damage_percent,
                    ) * 100,
                  )}%`
                : "Off"
            }}
          </strong>
        </div>

        <div>
          <span>
            Question
          </span>

          <strong>
            {{
              createdBattle
                .question_enabled
                ? createdBattle
                    .question_level
                : "Off"
            }}
          </strong>
        </div>
      </div>

      <!-- DECK READY -->

      <div
        class="created-rule-summary"
      >
        <div>
          <span>
            P1 DECK
          </span>

          <strong>
            {{
              createdBattle
                .player1_deck_remaining
            }}
            /
            {{
              createdBattle
                .player1_starting_deck
            }}
          </strong>
        </div>

        <div>
          <span>
            P2 DECK
          </span>

          <strong>
            {{
              createdBattle
                .player2_deck_remaining
            }}
            /
            {{
              createdBattle
                .player2_starting_deck
            }}
          </strong>
        </div>

        <div>
          <span>
            TARGET ATTACK
          </span>

          <strong>
            {{
              createdBattle
                .target_card_enabled
                ? "ON"
                : "OFF"
            }}
          </strong>
        </div>

        <div>
          <span>
            DIRECT ATTACK
          </span>

          <strong>
            {{
              createdBattle
                .direct_attack_enabled
                ? "ON"
                : "OFF"
            }}
          </strong>
        </div>
      </div>

      <!-- PRIMARY -->

      <div
        class="primary-battle-actions"
      >
        <button
          type="button"
          class="open-public-button"
          @click="
            openPublicBattle
          "
        >
          🖥️ OPEN PUBLIC BATTLE
        </button>

        <button
          type="button"
          class="history-secondary-button"
          @click="
            openBattleHistory
          "
        >
          ◷ BATTLE HISTORY
        </button>
      </div>

      <!-- LINKS -->

      <div
        class="battle-links"
      >
        <!-- PUBLIC -->

        <div
          class="battle-link-card public"
        >
          <div
            class="link-icon"
          >
            🖥️
          </div>

          <div
            class="link-content"
          >
            <span
              class="link-label"
            >
              PUBLIC BATTLE
            </span>

            <strong>
              Main Arena / TV
            </strong>

            <div
              class="link-url"
            >
              {{ publicUrl }}
            </div>
          </div>

          <div
            class="link-actions"
          >
            <button
              type="button"
              @click="
                copyText(
                  publicUrl,
                )
              "
            >
              COPY
            </button>

            <button
              type="button"
              class="primary"
              @click="
                openPublicBattle
              "
            >
              OPEN
            </button>
          </div>
        </div>

        <!-- P1 -->

        <div
          class="battle-link-card blue with-qr"
        >
          <div
            class="link-icon"
          >
            👦🏻
          </div>

          <div
            class="link-content"
          >
            <span
              class="link-label"
            >
              PLAYER 1
            </span>

            <strong>
              {{
                createdBattle
                  .player1_name
              }}
            </strong>

            <div
              class="link-url"
            >
              {{ player1Url }}
            </div>
          </div>

          <div
            v-if="player1QrDataUrl"
            class="player-qr-panel blue"
          >
            <div class="qr-frame">
              <img
                :src="player1QrDataUrl"
                :alt="`QR Player 1 - ${createdBattle.player1_name}`"
              />
            </div>

            <span>
              SCAN TO JOIN
            </span>
          </div>

          <div
            class="link-actions"
          >
            <button
              type="button"
              @click="
                copyText(
                  player1Url,
                )
              "
            >
              COPY
            </button>

            <button
              type="button"
              class="primary blue"
              @click="
                openPlayer('p1')
              "
            >
              OPEN
            </button>
          </div>
        </div>

        <!-- P2 -->

        <div
          class="battle-link-card red with-qr"
        >
          <div
            class="link-icon"
          >
            🧑🏽‍🦱
          </div>

          <div
            class="link-content"
          >
            <span
              class="link-label"
            >
              PLAYER 2
            </span>

            <strong>
              {{
                createdBattle
                  .player2_name
              }}
            </strong>

            <div
              class="link-url"
            >
              {{ player2Url }}
            </div>
          </div>

          <div
            v-if="player2QrDataUrl"
            class="player-qr-panel red"
          >
            <div class="qr-frame">
              <img
                :src="player2QrDataUrl"
                :alt="`QR Player 2 - ${createdBattle.player2_name}`"
              />
            </div>

            <span>
              SCAN TO JOIN
            </span>
          </div>

          <div
            class="link-actions"
          >
            <button
              type="button"
              @click="
                copyText(
                  player2Url,
                )
              "
            >
              COPY
            </button>

            <button
              type="button"
              class="primary red"
              @click="
                openPlayer('p2')
              "
            >
              OPEN
            </button>
          </div>
        </div>

        <div
          v-if="qrError"
          class="qr-error-box"
        >
          ⚠️ {{ qrError }}
        </div>
      </div>

      <button
        type="button"
        class="another-button"
        @click="
          createAnother
        "
      >
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

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
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

  border: 1px solid
    rgba(70, 193, 255, 0.3);

  border-radius: 18px;

  font-size: 29px;

  background: linear-gradient(
    135deg,
    rgba(0, 161, 255, 0.17),
    rgba(30, 80, 160, 0.04)
  );

  box-shadow:
    0 0 30px
    rgba(0, 165, 255, 0.08);
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

  line-height: 1.6;
}

/* =========================================================
   HISTORY BUTTON
========================================================= */

.history-button {
  min-height: 41px;

  padding: 0 15px;

  flex-shrink: 0;

  border: 1px solid
    rgba(116, 174, 226, 0.18);

  border-radius: 9px;

  color: #9eb4cc;

  background:
    rgba(255, 255, 255, 0.025);

  cursor: pointer;

  font-size: 9px;

  font-weight: 900;

  letter-spacing: 0.06em;

  transition: 0.2s ease;
}

.history-button:hover {
  color: #d8e7fa;

  border-color:
    rgba(126, 193, 255, 0.3);

  background:
    rgba(255, 255, 255, 0.045);
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

  border: 1px solid
    rgba(139, 177, 222, 0.1);

  border-radius: 16px;

  background: linear-gradient(
    145deg,
    rgba(10, 25, 52, 0.94),
    rgba(4, 12, 29, 0.94)
  );

  box-shadow:
    0 15px 45px
    rgba(0, 0, 0, 0.22);
}

.tcg-card {
  border-color:
    rgba(250, 184, 66, 0.17);
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

  background:
    rgba(255, 255, 255, 0.045);
}

.section-heading h2 {
  margin: 0;

  font-size: 15px;
}

.section-heading p {
  margin: 4px 0 0;

  color: #74879f;

  font-size: 10px;

  line-height: 1.5;
}

/* =========================================================
   GRID
========================================================= */

.form-grid {
  display: grid;

  gap: 15px;
}

.form-grid.two {
  grid-template-columns:
    repeat(
      2,
      minmax(0, 1fr)
    );
}

.form-grid.three {
  grid-template-columns:
    repeat(
      3,
      minmax(0, 1fr)
    );
}

.form-grid.four {
  grid-template-columns:
    repeat(
      4,
      minmax(0, 1fr)
    );
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

  border: 1px solid
    rgba(121, 166, 220, 0.16);

  border-radius: 9px;

  outline: none;

  color: #eef7ff;

  background: #071224;

  font-size: 12px;

  transition: 0.2s ease;
}

.field input:focus,
.field select:focus {
  border-color:
    rgba(45, 192, 255, 0.6);

  box-shadow:
    0 0 0 3px
    rgba(25, 156, 255, 0.08);
}

.field input:disabled,
.field select:disabled {
  cursor: not-allowed;

  opacity: 0.65;
}

.field small {
  min-height: 14px;

  color: #61758f;

  font-size: 8px;

  line-height: 1.5;
}

/* =========================================================
   INPUT SUFFIX
========================================================= */

.input-suffix {
  display: flex;

  align-items: center;

  overflow: hidden;

  border: 1px solid
    rgba(121, 166, 220, 0.16);

  border-radius: 9px;

  background: #071224;
}

.input-suffix input {
  border: 0;

  border-radius: 0;
}

.input-suffix > span {
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

  border: 1px solid
    rgba(255, 255, 255, 0.06);

  border-radius: 8px;

  color: #71849d;

  background:
    rgba(255, 255, 255, 0.02);

  font-size: 8px;
}

.deck-summary strong {
  color: #e4f4ff;
}

/* =========================================================
   INFO NOTE
========================================================= */

.info-note,
.future-note {
  margin-top: 16px;

  padding: 12px 14px;

  border: 1px solid
    rgba(62, 182, 255, 0.13);

  border-radius: 9px;

  color: #7189a4;

  background:
    rgba(15, 126, 198, 0.05);

  font-size: 9px;

  line-height: 1.6;
}

.info-note strong,
.future-note span {
  margin-right: 8px;

  color: #42cfff;

  font-weight: 950;

  letter-spacing: 0.08em;
}

/* =========================================================
   RULESET
========================================================= */

.ruleset-banner {
  min-height: 70px;

  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 18px;

  margin-bottom: 18px;

  padding: 14px 16px;

  border: 1px solid
    rgba(255, 194, 77, 0.16);

  border-radius: 11px;

  background: linear-gradient(
    135deg,
    rgba(255, 172, 44, 0.08),
    rgba(255, 255, 255, 0.015)
  );
}

.ruleset-banner.compact {
  min-height: 58px;
}

.ruleset-banner > div {
  display: flex;

  flex-direction: column;

  gap: 4px;
}

.ruleset-banner span {
  color: #8e9db1;

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.12em;
}

.ruleset-banner strong {
  color: #ffd57c;

  font-size: 17px;

  letter-spacing: 0.08em;
}

.ruleset-banner small {
  color: #71849d;

  font-size: 9px;

  text-align: right;
}

/* =========================================================
   RULE OPTIONS
========================================================= */

.combat-rule-list {
  display: grid;

  grid-template-columns:
    repeat(
      3,
      minmax(0, 1fr)
    );

  gap: 12px;
}

.rule-option {
  min-height: 105px;

  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 14px;

  padding: 14px;

  border: 1px solid
    rgba(121, 166, 220, 0.11);

  border-radius: 11px;

  background:
    rgba(255, 255, 255, 0.018);
}

.rule-option > div {
  display: flex;

  flex-direction: column;

  gap: 5px;
}

.rule-option strong {
  color: #d8e9fa;

  font-size: 10px;

  line-height: 1.4;
}

.rule-option small {
  color: #61758f;

  font-size: 8px;

  line-height: 1.5;
}

.rule-option .toggle {
  flex-shrink: 0;
}

.destruction-settings {
  margin-top: 15px;
}

/* =========================================================
   COMBAT PREVIEW
========================================================= */

.combat-preview {
  margin-top: 15px;

  padding: 13px 15px;

  border: 1px solid
    rgba(255, 93, 112, 0.13);

  border-radius: 10px;

  background:
    rgba(255, 51, 77, 0.035);
}

.combat-preview > span {
  color: #ff7d91;

  font-size: 8px;

  font-weight: 950;

  letter-spacing: 0.1em;
}

.combat-preview strong {
  margin-left: 8px;

  color: #ffd6dd;

  font-size: 13px;
}

.combat-preview p {
  margin: 7px 0 0;

  color: #74869b;

  font-size: 9px;

  line-height: 1.55;
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

.toggle
  input:checked
  + .toggle-track {
  background: #129bd5;
}

.toggle
  input:checked
  + .toggle-track
  .toggle-dot {
  transform:
    translateX(20px);
}

/* =========================================================
   ERROR
========================================================= */

.error-box {
  padding: 13px 15px;

  border: 1px solid
    rgba(255, 71, 99, 0.3);

  border-radius: 10px;

  color: #ff93a6;

  background:
    rgba(255, 43, 78, 0.08);

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
  min-width: 260px;

  min-height: 49px;

  border: 1px solid
    rgba(79, 210, 255, 0.5);

  border-radius: 11px;

  color: #e9fbff;

  background:
    linear-gradient(
      135deg,
      #0779ba,
      #084a8a
    );

  cursor: pointer;

  font-size: 10px;

  font-weight: 950;

  letter-spacing: 0.1em;

  box-shadow:
    0 12px 30px
    rgba(0, 120, 210, 0.2);
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

  border: 2px solid
    rgba(255, 255, 255, 0.25);

  border-top-color: white;

  border-radius: 50%;

  vertical-align: middle;

  animation:
    spin 0.7s linear infinite;
}

@keyframes spin {
  to {
    transform:
      rotate(360deg);
  }
}

/* =========================================================
   CREATED
========================================================= */

.created-container {
  max-width: 900px;

  text-align: center;
}

.success-icon {
  width: 65px;

  height: 65px;

  margin: 0 auto 18px;

  display: grid;

  place-items: center;

  border: 1px solid
    rgba(56, 231, 149, 0.35);

  border-radius: 50%;

  color: #6dffbd;

  background:
    rgba(33, 195, 120, 0.1);

  font-size: 27px;

  font-weight: 950;

  box-shadow:
    0 0 35px
    rgba(42, 221, 142, 0.11);
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

  border: 1px solid
    rgba(44, 195, 255, 0.22);

  border-radius: 16px;

  background: linear-gradient(
    135deg,
    rgba(12, 66, 112, 0.3),
    rgba(4, 18, 39, 0.8)
  );
}

.battle-code-card > span {
  display: block;

  margin-bottom: 7px;

  color: #6d829b;

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.16em;
}

.battle-code-card > strong {
  display: block;

  margin-bottom: 13px;

  color: #55d8ff;

  font-size: 35px;

  letter-spacing: 0.16em;
}

.battle-code-card button {
  min-height: 35px;

  padding: 0 14px;

  border: 1px solid
    rgba(63, 200, 255, 0.23);

  border-radius: 8px;

  color: #9de7ff;

  background:
    rgba(31, 156, 216, 0.08);

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;
}

/* =========================================================
   BATTLE INFO
========================================================= */

.battle-info,
.created-rule-summary {
  display: grid;

  grid-template-columns:
    repeat(
      4,
      minmax(0, 1fr)
    );

  gap: 10px;

  margin-bottom: 20px;
}

.battle-info > div,
.created-rule-summary > div {
  min-height: 75px;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 5px;

  padding: 10px;

  border: 1px solid
    rgba(121, 166, 220, 0.1);

  border-radius: 10px;

  background:
    rgba(255, 255, 255, 0.018);
}

.battle-info span,
.created-rule-summary span {
  color: #6a7d95;

  font-size: 7px;

  font-weight: 900;

  letter-spacing: 0.08em;

  text-transform: uppercase;
}

.battle-info strong,
.created-rule-summary strong {
  color: #daeaff;

  font-size: 11px;
}

.created-rule-summary {
  margin-top: -7px;
}

/* =========================================================
   PRIMARY ACTIONS
========================================================= */

.primary-battle-actions {
  display: flex;

  justify-content: center;

  gap: 10px;

  margin: 23px 0;
}

.open-public-button,
.history-secondary-button {
  min-height: 44px;

  padding: 0 19px;

  border-radius: 10px;

  cursor: pointer;

  font-size: 9px;

  font-weight: 950;

  letter-spacing: 0.05em;
}

.open-public-button {
  border: 1px solid
    rgba(63, 207, 255, 0.4);

  color: #e8fbff;

  background:
    linear-gradient(
      135deg,
      #0678b9,
      #08518e
    );
}

.history-secondary-button {
  border: 1px solid
    rgba(151, 178, 211, 0.16);

  color: #9db0c5;

  background:
    rgba(255, 255, 255, 0.025);
}

/* =========================================================
   LINKS
========================================================= */

.battle-links {
  display: flex;

  flex-direction: column;

  gap: 10px;

  margin-top: 22px;
}

.battle-link-card {
  display: grid;

  grid-template-columns:
    auto minmax(0, 1fr) auto;

  align-items: center;

  gap: 14px;

  padding: 15px;

  border: 1px solid
    rgba(121, 166, 220, 0.1);

  border-radius: 12px;

  text-align: left;

  background:
    rgba(255, 255, 255, 0.018);
}

.battle-link-card.blue {
  border-color:
    rgba(52, 178, 255, 0.14);
}

.battle-link-card.red {
  border-color:
    rgba(255, 72, 101, 0.14);
}

.link-icon {
  width: 43px;

  height: 43px;

  display: grid;

  place-items: center;

  border-radius: 10px;

  background:
    rgba(255, 255, 255, 0.035);

  font-size: 18px;
}

.link-content {
  min-width: 0;
}

.link-label {
  display: block;

  margin-bottom: 4px;

  color: #668098;

  font-size: 7px;

  font-weight: 900;

  letter-spacing: 0.1em;
}

.link-content strong {
  display: block;

  margin-bottom: 5px;

  color: #dceafa;

  font-size: 11px;
}

.link-url {
  overflow: hidden;

  color: #62758b;

  font-size: 8px;

  text-overflow: ellipsis;

  white-space: nowrap;
}

.battle-link-card.with-qr {
  grid-template-columns:
    auto minmax(0, 1fr) 124px auto;
}

.player-qr-panel {
  width: 116px;

  padding: 7px;

  display: flex;

  flex-direction: column;

  align-items: center;

  gap: 5px;

  border: 1px solid
    rgba(79, 180, 239, 0.16);

  border-radius: 11px;

  background:
    rgba(255, 255, 255, 0.025);
}

.player-qr-panel.red {
  border-color:
    rgba(255, 80, 112, 0.17);
}

.qr-frame {
  width: 102px;
  height: 102px;

  padding: 5px;

  display: grid;

  place-items: center;

  overflow: hidden;

  border-radius: 8px;

  background: #ffffff;

  box-shadow:
    0 8px 20px
    rgba(0, 0, 0, 0.22);
}

.qr-frame img {
  width: 100%;
  height: 100%;

  display: block;

  object-fit: contain;

  image-rendering: pixelated;
}

.player-qr-panel > span {
  color: #74d8ff;

  font-size: 6px;

  font-weight: 950;

  letter-spacing: 0.12em;

  text-align: center;
}

.player-qr-panel.red > span {
  color: #ff9bad;
}

.qr-error-box {
  padding: 11px 13px;

  border: 1px solid
    rgba(255, 101, 125, 0.18);

  border-radius: 9px;

  color: #ff9bad;

  background:
    rgba(255, 49, 82, 0.055);

  font-size: 8px;

  font-weight: 800;
}

.link-actions {
  display: flex;

  gap: 6px;
}

.link-actions button {
  min-height: 34px;

  padding: 0 12px;

  border: 1px solid
    rgba(126, 166, 209, 0.14);

  border-radius: 8px;

  color: #8fa4bb;

  background:
    rgba(255, 255, 255, 0.025);

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;
}

.link-actions button.primary {
  color: #aeeeff;

  border-color:
    rgba(49, 195, 255, 0.25);

  background:
    rgba(23, 139, 201, 0.1);
}

.link-actions button.primary.red {
  color: #ffc0ca;

  border-color:
    rgba(255, 76, 108, 0.25);

  background:
    rgba(210, 36, 68, 0.09);
}

/* =========================================================
   ANOTHER
========================================================= */

.another-button {
  margin-top: 25px;

  min-height: 40px;

  padding: 0 16px;

  border: 1px solid
    rgba(133, 167, 207, 0.15);

  border-radius: 9px;

  color: #879ab0;

  background:
    rgba(255, 255, 255, 0.02);

  cursor: pointer;

  font-size: 8px;

  font-weight: 900;

  letter-spacing: 0.05em;
}

/* =========================================================
   RESPONSIVE
========================================================= */

@media (
  max-width: 1100px
) {
  .form-grid.four {
    grid-template-columns:
      repeat(
        2,
        minmax(0, 1fr)
      );
  }

  .combat-rule-list {
    grid-template-columns:
      1fr;
  }
}

@media (
  max-width: 850px
) {
  .setup-page {
    padding:
      30px 18px 50px;
  }

  .setup-background {
    inset:
      76px 0 0 0;
  }

  .setup-header {
    align-items:
      flex-start;

    flex-direction:
      column;
  }

  .form-grid.two,
  .form-grid.three,
  .form-grid.four {
    grid-template-columns:
      1fr;
  }

  .battle-info,
  .created-rule-summary {
    grid-template-columns:
      repeat(
        2,
        minmax(0, 1fr)
      );
  }

  .ruleset-banner {
    align-items:
      flex-start;

    flex-direction:
      column;
  }

  .ruleset-banner small {
    text-align: left;
  }
}

@media (
  max-width: 620px
) {
  .setup-page {
    padding:
      24px 13px 45px;
  }

  .setup-header-main {
    align-items:
      flex-start;
  }

  .setup-logo {
    width: 54px;

    height: 54px;

    border-radius: 14px;

    font-size: 24px;
  }

  .setup-header h1,
  .created-container h1 {
    font-size: 25px;
  }

  .setup-card {
    padding: 17px;
  }

  .battle-info,
  .created-rule-summary {
    grid-template-columns:
      1fr 1fr;
  }

  .primary-battle-actions {
    flex-direction:
      column;
  }

  .battle-link-card,
  .battle-link-card.with-qr {
    grid-template-columns:
      auto minmax(0, 1fr);
  }

  .player-qr-panel {
    grid-column:
      1 / -1;

    width: 100%;

    flex-direction: row;

    justify-content: flex-start;

    gap: 12px;
  }

  .qr-frame {
    width: 112px;
    height: 112px;

    flex: 0 0 auto;
  }

  .player-qr-panel > span {
    font-size: 7px;
  }

  .link-actions {
    grid-column:
      1 / -1;

    justify-content:
      flex-end;
  }

  .battle-code-card
    > strong {
    font-size: 27px;
  }

  .create-button {
    width: 100%;

    min-width: 0;
  }
}
</style>