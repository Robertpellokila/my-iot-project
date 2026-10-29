<script setup>
import {useAdminFeedback} from '../composables/useAdminToast.js';
import SearchableSelect from "../components/SearchableSelect.vue";
import { ref, computed } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "../lib/supabase";
import QRCode from "qrcode";
import PublicLayoutPicker from "../components/battle/PublicLayoutPicker.vue";
import PlayerPhotoUpload from "../components/battle/PlayerPhotoUpload.vue";
import { usePlayerSetupPhotos } from "../composables/battle/usePlayerSetupPhotos.js";
import { PUBLIC_BATTLE_LAYOUTS, normalizePublicBattleLayout } from "../utils/publicBattleLayouts.js";

// =========================================================
// ROUTER
// =========================================================

const router = useRouter();

// =========================================================
// PLAYER
// =========================================================

const player1Name = ref("Player 1");
const player2Name = ref("Player 2");
const { photos, processingPhotos, selectPhoto, clearPhoto, clearPhotos, uploadPhotos, setRemoveBackground, retryBackground } = usePlayerSetupPhotos();

// =========================================================
// GAME RULES
// =========================================================

const totalRounds = ref(10);
const startingPlayer = ref("random");
const turnDurationSeconds = ref(45);
const publicLayout = ref('center_duel');
const selectedLayout = computed(() => PUBLIC_BATTLE_LAYOUTS.find(layout => layout.id === publicLayout.value));

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
const tripleComboEnabled = ref(false);
const genericComboEnabled = ref(false);
const formationEnabled = ref(false);
const statusEffectsEnabled = ref(true);
const actionPointsPerTurn = ref(3);
const maxAttacksPerCard = ref(1);
const actionCosts = ref({
  attack: 1,
  summon: 1,
  switch: 1,
  special_skill: 1,
  combo_attack: 2,
  triple_combo: 3,
  fusion: 2,
  ultimate_combo: 3,
  ultimate: 2,
  heal: 1,
  synergy: 1,
});

// =========================================================
// QUESTION
// =========================================================

const questionEnabled = ref(true);
const questionLevel = ref("medium");
const questionEveryRounds = ref(5);
const questionTopics = ref([]);
const questionTimeLimitSeconds = ref(30);
const questionBonusEnabled = ref(true);
const questionLearningEnabled = ref(true);
const questionTopicOptions = [
  { value: "scratch", label: "Scratch" },
  { value: "block_coding", label: "Block coding" },
  { value: "programming_basics", label: "Dasar coding" },
  { value: "javascript", label: "JavaScript" },
  { value: "html", label: "HTML" },
  { value: "algorithm", label: "Algoritma" },
  { value: "database", label: "Database" },
  { value: "general", label: "Umum" },
];

// =========================================================
// STATE
// =========================================================

const loading = ref(false);
const error = ref(null);
const createdBattle = ref(null);
const createdLayoutName = computed(() => PUBLIC_BATTLE_LAYOUTS.find(
  layout => layout.id === normalizePublicBattleLayout(createdBattle.value?.public_layout),
)?.name);

// =========================================================
// PLAYER QR CODE
// =========================================================

const player1QrDataUrl = ref("");
const player2QrDataUrl = ref("");
const qrError = ref(null);
const enlargedQr = ref(null);

const enlargePlayerQr = (player) => {
  const image = player === "p1" ? player1QrDataUrl.value : player2QrDataUrl.value;
  if (!image) return;
  enlargedQr.value = {
    player,
    name: player === "p1" ? createdBattle.value?.player1_name : createdBattle.value?.player2_name,
    image,
  };
};

// =========================================================
// CREATED URLS
// =========================================================

const publicUrl = computed(() => {
  if (!createdBattle.value?.code) {
    return "";
  }

  return `${window.location.origin}/battle/${createdBattle.value.code}?layout=${normalizePublicBattleLayout(createdBattle.value.public_layout)}`;
});

const player1Url = computed(() => createdBattle.value?.code ? `${window.location.origin}/play/${encodeURIComponent(createdBattle.value.code)}/p1` : '');
const player2Url = computed(() => createdBattle.value?.code ? `${window.location.origin}/play/${encodeURIComponent(createdBattle.value.code)}/p2` : '');
// QR contains only the page address. Each player enters their private code.
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

  if (Number(maxActive.value) < 1 || Number(maxActive.value) > Number(deckSize.value)) {
    return "Jumlah Active harus antara 1 dan ukuran physical deck.";
  }

  if (Number(maxBench.value) < 0 || Number(maxBench.value) > Number(deckSize.value)) {
    return "Jumlah Bench harus antara 0 dan ukuran physical deck.";
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

  if (!Number.isInteger(Number(actionPointsPerTurn.value)) || Number(actionPointsPerTurn.value) < 1 || Number(actionPointsPerTurn.value) > 10) {
    return "Poin Giliran per giliran harus antara 1 dan 10.";
  }

  if (!Number.isInteger(Number(maxAttacksPerCard.value)) || Number(maxAttacksPerCard.value) < 1 || Number(maxAttacksPerCard.value) > 5) {
    return "Kesempatan serang per kartu harus antara 1 dan 5.";
  }

  for (const [action, cost] of Object.entries(actionCosts.value)) {
    if (!Number.isInteger(Number(cost)) || Number(cost) < 0 || Number(cost) > Number(actionPointsPerTurn.value)) {
      return `Biaya poin giliran untuk ${action} harus antara 0 dan jumlah poin per giliran.`;
    }
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
  if (loading.value || processingPhotos.value) return;
  error.value = null;

  const validationError =
    validateForm();

  if (validationError) {
    error.value =
      validationError;

    return;
  }

  loading.value = true;
  const selectedPublicLayout = normalizePublicBattleLayout(publicLayout.value);
  createdBattle.value = null;

  try {
    if (questionEnabled.value) {
      let questionPool = supabase
        .from("coding_questions")
        .select("id", { count: "exact", head: true })
        .eq("is_active", true);
      if (questionLevel.value !== "mixed") {
        questionPool = questionPool.eq("difficulty", questionLevel.value);
      }
      if (questionTopics.value.length) {
        questionPool = questionPool.in("category", questionTopics.value);
      }
      const { count, error: questionPoolError } = await questionPool;
      if (questionPoolError) {
        error.value = `Bank soal tidak dapat diperiksa: ${questionPoolError.message}`;
        return;
      }
      if (!count) {
        error.value = "Belum ada soal aktif untuk kombinasi topik dan level ini. Pilih topik lain atau aktifkan level Mixed.";
        return;
      }
    }

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

    const avatarFields = await uploadPhotos(user.id);

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
        public_layout: selectedPublicLayout,

        // =================================================
        // PLAYER
        // =================================================

        player1_name:
          player1Name.value.trim(),

        player2_name:
          player2Name.value.trim(),
        ...avatarFields,

        // =================================================
        // RULESET
        // =================================================

        ruleset:
          ruleset.value,

        action_points_enabled: true,
        action_points_per_turn: Number(actionPointsPerTurn.value),
        action_costs: Object.fromEntries(
          Object.entries(actionCosts.value).map(([key, value]) => [key, Number(value)]),
        ),
        max_attacks_per_card: ruleset.value === 'tcg_v1' ? 1 : Number(maxAttacksPerCard.value),
        player1_action_points: resolvedStartingPlayer === "p1" ? Number(actionPointsPerTurn.value) : 0,
        player2_action_points: resolvedStartingPlayer === "p2" ? Number(actionPointsPerTurn.value) : 0,
        turn_index: 1,

        // =================================================
        // GAME RULES
        // =================================================

        total_rounds:
          Number(
            totalRounds.value,
          ),

        starting_player:
          resolvedStartingPlayer,

        turn_duration_seconds:
          Number(turnDurationSeconds.value),

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

        triple_combo_enabled:
          Boolean(tripleComboEnabled.value),

        generic_combo_enabled:
          Boolean(genericComboEnabled.value),

        formation_enabled:
          Boolean(formationEnabled.value),

        status_effects_enabled:
          Boolean(statusEffectsEnabled.value),

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

        question_topics:
          [...questionTopics.value],

        question_time_limit_seconds:
          Number(questionTimeLimitSeconds.value),

        question_bonus_enabled:
          Boolean(questionBonusEnabled.value),

        question_learning_enabled:
          Boolean(questionLearningEnabled.value),

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

      let insertResult = await supabase.from("battle_sessions").insert(payload).select("*").single();
      // Older installations still preserve the layout in the shareable public URL.
      // Only a missing layout column permits this retry; other errors remain visible.
      if (['PGRST204', '42703'].includes(insertResult.error?.code) &&
          String(insertResult.error?.message ?? '').includes('public_layout')) {
        const legacyPayload = { ...payload };
        delete legacyPayload.public_layout;
        insertResult = await supabase.from("battle_sessions").insert(legacyPayload).select("*").single();
      }
      const { data, error: insertError } = insertResult;
      if (['PGRST204', '42703'].includes(insertError?.code) &&
          /player[12]_(avatar|setup_photo)_url/.test(String(insertError?.message ?? ''))) {
        throw new Error("Penyimpanan foto pemain belum tersedia pada server ini. Minta administrator memperbarui server, lalu coba lagi.");
      }

      // ===================================================
      // SUCCESS
      // ===================================================

      if (!insertError) {
        created = { ...data, public_layout: selectedPublicLayout };

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

    createdBattle.value=created;
    const {data:privateCodes,error:accessError}=await supabase.rpc('admin_battle_access',{p_code:created.code});
    if(accessError)throw new Error('Battle dibuat, tetapi kode pribadi belum dapat dimuat. Buka Riwayat Battle untuk mencoba kembali.');
    createdBattle.value={...created,...privateCodes};

    await generatePlayerQrs();
    adminToast.success('Battle berhasil dibuat. Bagikan kode pribadi kepada masing-masing pemain.');
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
    adminToast.success('Kode atau link berhasil disalin.');
  } catch (err) {
    console.error(
      "Copy gagal:",
      err,
    );
    adminToast.danger('Belum dapat menyalin. Izinkan akses clipboard atau salin secara manual.');
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
    query: { layout: normalizePublicBattleLayout(createdBattle.value.public_layout) },

    params: {
      code:
        createdBattle.value
          .code,
    },
  });
};

const openPlayer = player => {
 if(createdBattle.value?.code)router.push({name:'player-battle',params:{code:createdBattle.value.code,player}});
};

// =========================================================
// CREATE ANOTHER
// =========================================================

const createAnother = () => {
  adminToast.info('Pengaturan siap untuk membuat battle berikutnya.');
  clearPhotos();
  createdBattle.value =
    null;

  player1QrDataUrl.value = "";
  player2QrDataUrl.value = "";
  qrError.value = null;
  enlargedQr.value = null;

  error.value = null;
};
const adminToast=useAdminFeedback({error,warning:qrError,scope:'GameSetup'});
</script>

<template>
  <div class="setup-page ide-setup-workspace">
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

      <div class="setup-workspace-grid">
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
                Tentukan nama dan foto kedua pemain.
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
                :disabled="loading"
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
                :disabled="loading"
                maxlength="40"
                placeholder="Player 2"
              />
            </label>
          </div>

          <div class="form-grid two setup-player-photos">
            <PlayerPhotoUpload
              v-for="side in ['p1', 'p2']" :key="side"
              :player="side"
              :name="side === 'p1' ? player1Name : player2Name"
              :preview="photos[side].preview"
              :processing="photos[side].processing"
              :error="photos[side].error"
              :warning="photos[side].warning" :stage="photos[side].stage" :remove-background="photos[side].removeBackground" :background-removed="photos[side].backgroundRemoved"
              @background="enabled=>setRemoveBackground(side,enabled)" @retry-background="retryBackground(side)"
              :disabled="loading"
              @select="file => selectPhoto(side, file)"
              @remove="clearPhoto(side)"
            />
          </div>

          <div class="question-extra-grid" :class="{ disabled: !questionEnabled }">
            <fieldset class="question-topic-field" :disabled="!questionEnabled">
              <legend>Topik soal <small>(kosongkan untuk semua topik)</small></legend>
              <div class="question-topic-options">
                <label v-for="topic in questionTopicOptions" :key="topic.value" class="question-topic-chip">
                  <input v-model="questionTopics" type="checkbox" :value="topic.value" />
                  <span>{{ topic.label }}</span>
                </label>
              </div>
            </fieldset>

            <label class="field">
              <span>Waktu menjawab</span>
              <SearchableSelect v-model.number="questionTimeLimitSeconds" :disabled="!questionEnabled">
                <option :value="0">Tanpa batas waktu</option>
                <option :value="20">20 detik</option>
                <option :value="30">30 detik</option>
                <option :value="45">45 detik</option>
                <option :value="60">60 detik</option>
              </SearchableSelect>
              <small>Timer dihitung sejak soal muncul dan divalidasi oleh server.</small>
            </label>

            <label class="question-setting-toggle">
              <input v-model="questionLearningEnabled" type="checkbox" :disabled="!questionEnabled" />
              <span><strong>Mode belajar</strong><small>Petunjuk bertahap, pembahasan, dan saran materi.</small></span>
            </label>

            <label class="question-setting-toggle">
              <input v-model="questionBonusEnabled" type="checkbox" :disabled="!questionEnabled" />
              <span><strong>Bonus untuk jawaban benar</strong><small>Pemenang memilih satu bonus dari pilihan yang diatur di admin.</small></span>
            </label>
          </div>
        </section>

        <section class="setup-card">
          <PublicLayoutPicker v-model="publicLayout" :disabled="loading" />
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

              <SearchableSelect
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
              </SearchableSelect>

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

            <label class="field">
              <span>Batas waktu giliran</span>
              <SearchableSelect v-model.number="turnDurationSeconds">
                <option :value="30">30 detik</option>
                <option :value="45">45 detik</option>
                <option :value="60">60 detik</option>
              </SearchableSelect>
              <small>Giliran otomatis berpindah saat waktu habis. Player mendapat satu jeda sambung ulang 10 detik per battle.</small>
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
                Kartu Awal di Active
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
                Jumlah kartu awal yang harus di-scan sebelum battle dimulai. Kartu ini masuk ke Active, bukan ke hand digital.
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
                Batas kartu yang boleh berada di Active. Kartu hasil scan hanya masuk ke Active.
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
                Batas kartu yang dapat dipindahkan dari Active ke Bench.
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
              Active Awal

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

          <div class="info-note">
            <strong>GILIRAN TCG</strong>
            Setiap giliran mendapat {{ actionPointsPerTurn }} poin giliran untuk melakukan aksi. Poin diisi kembali saat giliran pemain dimulai. Kartu dimainkan dari hand fisik dengan scan RFID dan selalu masuk ke Active. Jika Active penuh, pindahkan kartu ke Bench sebelum summon berikutnya. Kartu yang berada di Bench tidak dapat menyerang atau ikut Combo.
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

              <SearchableSelect
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
              </SearchableSelect>

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

          <div class="form-grid two tcg-config-fields">
            <label class="field">
              <span>Poin per Giliran</span>
              <input v-model.number="actionPointsPerTurn" type="number" min="1" max="10" />
              <small>Poin yang tersedia saat giliran pemain dimulai.</small>
            </label>
            <label class="field">
              <span>Serangan per Active Card</span>
              <input v-model.number="maxAttacksPerCard" type="number" min="1" max="5" :disabled="ruleset === 'tcg_v1'" />
              <small>Aturan pilot: 1 kesempatan per kartu, dibagi antara Attack, skill damage, Combo, Ultimate, dan Synergy damage. Setelah aksi ofensif, kartu tetap di Active hingga giliran pemiliknya berikutnya.</small>
            </label>
          </div>

          <div class="form-grid three tcg-config-fields">
            <label class="field" v-for="(cost, action) in actionCosts" :key="action">
              <span>Biaya poin · {{ action.replaceAll('_', ' ') }}</span>
              <input v-model.number="actionCosts[action]" type="number" min="0" :max="actionPointsPerTurn" />
              <small>Atur 0 untuk aksi gratis.</small>
            </label>
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

          <div class="combat-rule-list secondary-rule-list">
            <label class="rule-option">
              <div><strong>⚡ Status Effects</strong><small>Mengaktifkan Burn, Freeze, Stun, Poison, Shield, dan efek status lain.</small></div>
              <span class="toggle"><input v-model="statusEffectsEnabled" type="checkbox" /><span class="toggle-track"><span class="toggle-dot" /></span></span>
            </label>
            <label class="rule-option">
              <div><strong>🔺 Triple Combo</strong><small>Mengizinkan tiga kartu Active jika ada aturan kombinasi khusus dan poin giliran cukup.</small></div>
              <span class="toggle"><input v-model="tripleComboEnabled" type="checkbox" :disabled="!comboEnabled" /><span class="toggle-track"><span class="toggle-dot" /></span></span>
            </label>
            <label class="rule-option">
              <div><strong>✨ Generic Combo</strong><small>Mengizinkan Combined Strike saat tidak ada synergy tipe khusus.</small></div>
              <span class="toggle"><input v-model="genericComboEnabled" type="checkbox" :disabled="!comboEnabled" /><span class="toggle-track"><span class="toggle-dot" /></span></span>
            </label>
            <label class="rule-option">
              <div><strong>🛡 Formation</strong><small>Menyiapkan bonus susunan Active; default nonaktif hingga formasi didaftarkan.</small></div>
              <span class="toggle"><input v-model="formationEnabled" type="checkbox" /><span class="toggle-track"><span class="toggle-dot" /></span></span>
            </label>
          </div>

          <div
            class="future-note"
          >
            Aturan ini disimpan pada battle session dan diperiksa oleh server. Combo menggunakan kartu Active saja; tipe lama Electric, Grass, dan Wind tetap dikenali oleh resolver tipe.
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
                  Pemain yang menjawab benar lebih dulu mendapat pilihan badge bonus sesuai pengaturan admin (1–6 pilihan).
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

              <SearchableSelect
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
              </SearchableSelect>

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
              loading || processingPhotos
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

            <template v-else-if="processingPhotos">
              MENYIAPKAN FOTO…
            </template>
            <template v-else>
              ⚔️ CREATE TCG BATTLE
            </template>
          </button>
        </div>
      </form>

      <aside class="setup-live-panel" aria-label="Ringkasan konfigurasi battle">
        <div class="setup-live-panel-head">
          <span class="setup-live-kicker">BATTLE PREVIEW</span>
          <span class="setup-live-indicator"><i></i> LIVE CONFIG</span>
        </div>

        <h2>{{ player1Name || "Player 1" }} <span>vs</span> {{ player2Name || "Player 2" }}</h2>
        <p class="setup-live-intro">Ringkasan ini mengikuti pilihan setup yang sedang kamu ubah.</p>

        <div class="setup-preview-arena">
          <div class="setup-preview-player blue">
            <img v-if="photos.p1.preview" class="setup-preview-photo" :src="photos.p1.preview" :alt="`Foto ${player1Name}`" />
            <span>P1</span>
            <strong>{{ player1Name || "Player 1" }}</strong>
            <small>{{ playerStartingHp }} HP</small>
          </div>
          <div class="setup-preview-vs">VS</div>
          <div class="setup-preview-player red">
            <img v-if="photos.p2.preview" class="setup-preview-photo" :src="photos.p2.preview" :alt="`Foto ${player2Name}`" />
            <span>P2</span>
            <strong>{{ player2Name || "Player 2" }}</strong>
            <small>{{ playerStartingHp }} HP</small>
          </div>
        </div>

        <section class="setup-preview-block">
          <div class="setup-preview-block-title"><strong>Physical deck</strong><span>{{ deckSize }} kartu / pemain</span></div>
          <div class="setup-deck-meter" aria-hidden="true"><i :style="{ width: `${Math.min(100, Math.max(0, Number(deckSize) * 5))}%` }"></i></div>
          <div class="setup-preview-stats">
            <div><small>Kartu awal discan</small><strong>{{ initialCardsRequired }}</strong></div>
            <div><small>Sisa deck</small><strong>{{ deckAfterInitial }}</strong></div>
            <div><small>Slot Active</small><strong>{{ maxActive }}</strong></div>
            <div><small>Slot Bench</small><strong>{{ maxBench }}</strong></div>
          </div>
          <p class="setup-preview-note">Deck fisik tetap dicatat sesuai jumlah ini. Pengelolaan kartu di tangan dilakukan langsung di meja permainan.</p>
        </section>

        <section class="setup-preview-block combat-preview-block">
          <div class="setup-preview-block-title"><strong>Battle rules</strong><span>{{ totalRounds }} ronde</span></div>
          <div class="setup-rule-chips">
            <span>{{ turnDurationSeconds }} dtk / giliran</span>
            <span>{{ actionPointsPerTurn }} poin / giliran</span>
            <span>{{ comboEnabled ? "Combo aktif" : "Combo nonaktif" }}</span>
            <span>{{ fusionEnabled ? "Fusion aktif" : "Fusion nonaktif" }}</span>
          </div>
        </section>

        <section class="setup-preview-block question-preview-block">
          <div class="setup-preview-block-title"><strong>Quiz challenge</strong><span>{{ questionEnabled ? "AKTIF" : "NONAKTIF" }}</span></div>
          <template v-if="questionEnabled">
            <div class="setup-question-summary">
              <b>{{ questionLevel === "mixed" ? "Campuran" : questionLevel }}</b>
              <span>setiap {{ questionEveryRounds }} ronde</span>
            </div>
            <small class="setup-topic-summary">
              {{ questionTopics.length ? questionTopics.map((topic) => questionTopicOptions.find((item) => item.value === topic)?.label || topic).join(" · ") : "Semua topik" }}
            </small>
          </template>
          <p v-else class="setup-preview-note">Battle berjalan tanpa ronde quiz.</p>
        </section>

        <div class="setup-preview-footer">
          <span>Public layout</span>
          <strong>{{ selectedLayout.name }}</strong>
        </div>
        <div class="setup-preview-footer">
          <span>Starting player</span>
          <strong>{{ startingPlayer === "random" ? "Dipilih acak" : startingPlayer === "p1" ? player1Name : player2Name }}</strong>
        </div>
      </aside>
      </div>
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

      <div class="created-rule-summary created-layout-summary">
        <div><span>PUBLIC LAYOUT</span><strong>{{ createdLayoutName }}</strong></div>
      </div>

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
            <div class="player-access-code"><span>KODE PRIBADI · SCAN QR LALU MASUKKAN KODE</span><code>{{ createdBattle.player1_access_code }}</code><button type="button" @click="copyText(createdBattle.player1_access_code)">SALIN</button></div>
          </div>

          <div
            v-if="player1QrDataUrl"
            class="player-qr-panel blue"
          >
            <button type="button" class="qr-frame" aria-label="Perbesar QR Player 1" @click="enlargePlayerQr('p1')">
              <img
                :src="player1QrDataUrl"
                :alt="`QR Player 1 - ${createdBattle.player1_name}`"
              />
            </button>

            <span>
              KLIK QR UNTUK PERBESAR
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
            <div class="player-access-code"><span>KODE PRIBADI · SCAN QR LALU MASUKKAN KODE</span><code>{{ createdBattle.player2_access_code }}</code><button type="button" @click="copyText(createdBattle.player2_access_code)">SALIN</button></div>
          </div>

          <div
            v-if="player2QrDataUrl"
            class="player-qr-panel red"
          >
            <button type="button" class="qr-frame" aria-label="Perbesar QR Player 2" @click="enlargePlayerQr('p2')">
              <img
                :src="player2QrDataUrl"
                :alt="`QR Player 2 - ${createdBattle.player2_name}`"
              />
            </button>

            <span>
              KLIK QR UNTUK PERBESAR
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

      <div v-if="enlargedQr" class="qr-enlarged-backdrop" @click.self="enlargedQr = null" @keydown.esc="enlargedQr = null">
        <section class="qr-enlarged-modal" role="dialog" aria-modal="true" :aria-label="`QR ${enlargedQr.player}`">
          <button type="button" class="qr-enlarged-close" aria-label="Tutup QR" @click="enlargedQr = null">×</button>
          <span class="qr-enlarged-eyebrow">{{ enlargedQr.player === "p1" ? "PLAYER 1" : "PLAYER 2" }}</span>
          <h2>{{ enlargedQr.name || "Player" }}</h2>
          <img :src="enlargedQr.image" :alt="`QR ${enlargedQr.name || enlargedQr.player}`" />
          <p>Scan QR ini untuk membuka halaman battle player.</p>
        </section>
      </div>
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
  position: relative;
  width: 44px;
  height: 24px;
  display: inline-flex;
  flex: none;
  align-items: center;
  vertical-align: middle;
  cursor: pointer;
}

.toggle input {
  position: absolute;
  z-index: 1;
  inset: 0;
  width: 100%;
  height: 100%;
  margin: 0;
  opacity: 0;
  cursor: pointer;
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
.created-layout-summary { grid-template-columns:1fr; }

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

.player-access-code {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 8px;
  color: #8fa9bd;
  font-size: 8px;
}
.player-access-code code { color: #d8f2ff; font-size: 10px; font-weight: 900; letter-spacing: .1em; }
.player-access-code button { border: 1px solid rgba(114, 194, 238, .25); border-radius: 5px; background: rgba(69, 158, 205, .1); color: #8bd3f4; padding: 4px 6px; font-size: 7px; font-weight: 900; cursor: pointer; }

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

  border: 0;

  cursor: zoom-in;

  appearance: none;

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

.qr-frame:focus-visible {
  outline: 3px solid #18aa35;
  outline-offset: 3px;
}

.qr-enlarged-backdrop {
  position: fixed;
  inset: 0;
  z-index: 10000;
  display: grid;
  place-items: center;
  padding: 18px;
  background: rgba(12, 35, 18, .76);
  backdrop-filter: blur(7px);
}

.qr-enlarged-modal {
  width: min(440px, 100%);
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 30px 24px 25px;
  border: 1px solid #dcebd9;
  border-radius: 20px;
  color: #21452b;
  background: #fff;
  box-shadow: 0 28px 90px rgba(0, 0, 0, .35);
  text-align: center;
}

.qr-enlarged-close {
  width: 38px;
  height: 38px;
  position: absolute;
  top: 12px;
  right: 12px;
  border: 1px solid #dce9dc;
  border-radius: 50%;
  color: #385d40;
  background: #f5faf4;
  cursor: pointer;
  font-size: 24px;
}

.qr-enlarged-eyebrow {
  margin-top: 5px;
  color: #149b32;
  font-size: 10px;
  font-weight: 900;
  letter-spacing: .16em;
}

.qr-enlarged-modal h2 {
  margin: 8px 0 18px;
  color: #183d24;
  font-size: 22px;
}

.qr-enlarged-modal img {
  width: min(100%, 340px);
  padding: 10px;
  border: 1px solid #e1ebe0;
  border-radius: 14px;
  background: white;
  image-rendering: pixelated;
}

.qr-enlarged-modal p {
  margin: 14px 0 0;
  color: #758776;
  font-size: 13px;
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

.question-extra-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  margin-top: 18px;
}
.question-extra-grid.disabled { opacity: .55; }
.question-topic-field {
  min-width: 0;
  grid-column: 1 / -1;
  margin: 0;
  padding: 14px;
  border: 1px solid #dbe9dc;
  border-radius: 15px;
  background: #fbfefb;
}
.question-topic-field legend {
  padding: 0 7px;
  color: #174b2c;
  font-size: 12px;
  font-weight: 800;
}
.question-topic-field legend small { margin-left: 5px; color: #6b8571; font-weight: 500; }
.question-topic-options { display: flex; flex-wrap: wrap; gap: 9px; }
.question-topic-chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 36px;
  padding: 7px 11px;
  border: 1px solid #d6e7d8;
  border-radius: 999px;
  color: #305d3d;
  background: #fff;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
}
.question-topic-chip:has(input:checked) { border-color: #179b3c; color: #08742c; background: #e9f8eb; }
.question-topic-chip input { accent-color: #11a33a; }
.question-setting-toggle {
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 13px;
  border: 1px solid #dbe9dc;
  border-radius: 14px;
  color: #18482b;
  background: #fbfefb;
  cursor: pointer;
}
.question-setting-toggle input { margin-top: 3px; accent-color: #12a33b; }
.question-setting-toggle span { display: grid; gap: 4px; }
.question-setting-toggle strong { font-size: 12px; }
.question-setting-toggle small { color: #698271; font-size: 10px; line-height: 1.45; }

/* Timedoor battle builder: a focused rule editor with a live session snapshot. */
.setup-page.ide-setup-workspace {
  --setup-green:#0ca52c; --setup-green-dark:#087b27; --setup-ink:#173c25; --setup-muted:#708675; --setup-border:#dcebdd;
  height:calc(100dvh - 76px); min-height:0; display:flex; flex-direction:column;
  padding:12px 18px 14px; overflow:clip; color:var(--setup-ink);
  background:#f0f8f0; font-family:Inter,ui-sans-serif,system-ui,sans-serif;
}
.ide-setup-workspace .setup-background { display:none; }
.ide-setup-workspace .setup-container { position:relative; display:flex; flex:1 1 auto; flex-direction:column; width:min(100%,1580px); max-width:none; min-height:0; margin:0 auto; }
.ide-setup-workspace .setup-header { position:relative; top:auto; z-index:30; display:flex; flex:0 0 auto; align-items:center; justify-content:space-between; gap:20px; margin:0 0 12px; padding:12px 15px; border:1px solid var(--setup-border); border-radius:15px; background:rgba(255,255,255,.97); box-shadow:0 6px 20px rgba(20,70,35,.06); backdrop-filter:blur(12px); }
.ide-setup-workspace .setup-header-main { align-items:center; gap:12px; }
.ide-setup-workspace .setup-logo { display:grid; width:40px; height:40px; place-items:center; border:0; border-radius:12px; color:#fff; background:var(--setup-green); box-shadow:none; }
.ide-setup-workspace .setup-eyebrow { color:#438b4d; }
.ide-setup-workspace .setup-header h1 { margin:1px 0 2px; color:var(--setup-ink); font-size:20px; letter-spacing:-.03em; }
.ide-setup-workspace .setup-header p { max-width:580px; margin:0; color:var(--setup-muted); font-size:11px; line-height:1.45; }
.ide-setup-workspace .history-button { min-height:38px; padding:0 13px; border:1px solid #cce2cd; border-radius:9px; color:#327c3e; background:#f4faf3; font-size:10px; font-weight:900; }
.ide-setup-workspace .history-button:hover { color:#176d2a; border-color:#9ccc9f; background:#eaf7e9; }
.ide-setup-workspace .setup-workspace-grid { display:grid; flex:1 1 auto; grid-template-columns:minmax(0,1fr) minmax(300px,370px); align-items:stretch; gap:15px; min-height:0; }
.ide-setup-workspace .setup-form { min-width:0; min-height:0; height:100%; max-height:none; padding:1px 7px 12px 1px; overflow-y:auto; overscroll-behavior:contain; scrollbar-color:#bed8bf transparent; }
.ide-setup-workspace .setup-form::-webkit-scrollbar { width:7px; }
.ide-setup-workspace .setup-form::-webkit-scrollbar-thumb { border-radius:9px; background:#c7dec8; }
.ide-setup-workspace .setup-card { padding:19px; border:1px solid var(--setup-border); border-radius:15px; background:#fff; box-shadow:0 5px 17px rgba(20,70,35,.035); }
.ide-setup-workspace .tcg-card { border-color:#d7e8d4; }
.ide-setup-workspace .section-heading h2 { color:#20462a; font-size:16px; letter-spacing:-.02em; }
.ide-setup-workspace .section-heading p,.ide-setup-workspace .setup-card p { color:#718675; }
.ide-setup-workspace .section-icon { border-color:#d9ecd9; color:#318141; background:#f1f9f0; box-shadow:none; }
.ide-setup-workspace .field > span,.ide-setup-workspace .rule-option strong { color:#31543a; }
.ide-setup-workspace .field input,.ide-setup-workspace .field select,.ide-setup-workspace .setup-card input:not([type="checkbox"]):not([type="radio"]),.ide-setup-workspace .setup-card select,.ide-setup-workspace .setup-card textarea { border:1px solid #d6e7d6; border-radius:8px; color:#23492c; background:#fbfdfb; box-shadow:none; }
.ide-setup-workspace .field input:focus,.ide-setup-workspace .field select:focus,.ide-setup-workspace .setup-card input:focus,.ide-setup-workspace .setup-card select:focus,.ide-setup-workspace .setup-card textarea:focus { border-color:#56b665; outline:3px solid rgba(29,161,53,.12); }
.ide-setup-workspace .field input:disabled,.ide-setup-workspace .field select:disabled { color:#8a9b8c; background:#f3f7f2; }
.ide-setup-workspace .field small,.ide-setup-workspace .rule-option small { color:#748a77; }
.ide-setup-workspace .rule-option { border-color:#e2ede1; background:#fbfdfb; }
.ide-setup-workspace .rule-option:hover { border-color:#bfddc1; background:#f5fbf4; }
.ide-setup-workspace .toggle-track { background:#d8e5d8; }
.ide-setup-workspace .toggle input:checked + .toggle-track { background:var(--setup-green); }
.ide-setup-workspace .input-suffix { border-color:#d6e7d6; background:#fbfdfb; }
.ide-setup-workspace .input-suffix input { background:transparent; }
.ide-setup-workspace .input-suffix > span { color:#738875; }
.ide-setup-workspace .deck-summary span { border-color:#dcebdd; color:#607a64; background:#f6faf5; }
.ide-setup-workspace .deck-summary strong { color:#244a2d; }
.ide-setup-workspace .info-note,.ide-setup-workspace .future-note { border-color:#dcebdd; color:#607a64; background:#f5faf4; }
.ide-setup-workspace .info-note strong,.ide-setup-workspace .future-note span { color:#348246; }
.ide-setup-workspace .ruleset-banner { border-color:#efe1bb; background:linear-gradient(135deg,#fff9e9,#fff); }
.ide-setup-workspace .ruleset-banner span { color:#8c8063; }
.ide-setup-workspace .ruleset-banner strong { color:#80611c; }
.ide-setup-workspace .ruleset-banner small { color:#7c806f; }
.ide-setup-workspace .combat-preview,.ide-setup-workspace .future-note { border-color:#dcebdd; color:#607a64; background:#f5faf4; }
.ide-setup-workspace .combat-preview > span { color:#b04c5d; }
.ide-setup-workspace .combat-preview strong { color:#31543a; }
.ide-setup-workspace .combat-preview p { color:#718675; }
.ide-setup-workspace .create-button { min-height:46px; border:0; border-radius:10px; color:#fff; background:var(--setup-green); box-shadow:0 8px 18px rgba(12,165,44,.16); }
.ide-setup-workspace .create-button:hover:not(:disabled) { background:var(--setup-green-dark); }
.ide-setup-workspace .create-button:disabled { color:#f4fff4; background:#88c994; }
.ide-setup-workspace .error-box { border-color:#f0bdb8; color:#973e35; background:#fff2f0; }
.ide-setup-workspace .question-setting-toggle { border-color:#dbe9dc; color:#31543a; background:#fbfdfb; }
.ide-setup-workspace .question-setting-toggle small { color:#748a77; }
.ide-setup-workspace .setup-live-panel { position:relative; top:auto; display:grid; align-content:start; gap:14px; min-height:0; height:100%; max-height:none; padding:19px; overflow-y:auto; border:1px solid var(--setup-border); border-radius:16px; background:#fff; box-shadow:0 12px 32px rgba(20,70,35,.065); scrollbar-color:#bed8bf transparent; }
.ide-setup-workspace .setup-live-panel-head { display:flex; align-items:center; justify-content:space-between; gap:10px; }
.ide-setup-workspace .setup-live-kicker { color:#438b4d; font-size:9px; font-weight:950; letter-spacing:.15em; }
.ide-setup-workspace .setup-live-indicator { display:inline-flex; align-items:center; gap:6px; color:#648069; font-size:8px; font-weight:900; letter-spacing:.07em; }
.ide-setup-workspace .setup-live-indicator i { width:7px; height:7px; border-radius:50%; background:#22a83b; box-shadow:0 0 0 4px #e8f7e8; }
.ide-setup-workspace .setup-live-panel > h2 { margin:0; color:#21472b; font-size:21px; line-height:1.22; letter-spacing:-.04em; overflow-wrap:anywhere; }
.ide-setup-workspace .setup-live-panel > h2 span { color:#8ba28d; font-size:12px; }
.ide-setup-workspace .setup-live-intro { margin:-9px 0 0; color:#758a78; font-size:10px; line-height:1.5; }
.ide-setup-workspace .setup-preview-arena { display:grid; grid-template-columns:minmax(0,1fr) 26px minmax(0,1fr); align-items:center; gap:5px; padding:12px; border:1px solid #e1ede0; border-radius:13px; background:#f8fcf7; }
.ide-setup-workspace .setup-preview-player { display:grid; gap:5px; min-width:0; padding:10px; border:1px solid #dbeadd; border-radius:10px; background:#fff; }
.ide-setup-workspace .setup-preview-player > span { color:#3d8d4b; font-size:8px; font-weight:950; letter-spacing:.08em; }
.ide-setup-workspace .setup-preview-player strong { overflow:hidden; color:#274a2f; font-size:11px; text-overflow:ellipsis; white-space:nowrap; }
.ide-setup-workspace .setup-preview-player small { color:#728574; font-size:9px; font-weight:800; }
.ide-setup-workspace .setup-preview-player.red > span { color:#bb5670; }
.ide-setup-workspace .setup-player-photos { margin-top:16px; }
.ide-setup-workspace .setup-preview-photo { width:44px; height:44px; object-fit:cover; object-position:center 25%; border-radius:10px; border:1px solid #c5daca; }
.ide-setup-workspace .setup-preview-vs { color:#9aab9a; font-size:8px; font-weight:950; text-align:center; }
.ide-setup-workspace .setup-preview-block { display:grid; gap:10px; padding:13px; border:1px solid #e1ede0; border-radius:12px; background:#fff; }
.ide-setup-workspace .setup-preview-block-title { display:flex; align-items:center; justify-content:space-between; gap:8px; }
.ide-setup-workspace .setup-preview-block-title strong { color:#31543a; font-size:11px; }
.ide-setup-workspace .setup-preview-block-title > span { color:#398649; font-size:9px; font-weight:900; text-align:right; }
.ide-setup-workspace .setup-deck-meter { height:6px; overflow:hidden; border-radius:999px; background:#e9f0e8; }
.ide-setup-workspace .setup-deck-meter i { display:block; height:100%; border-radius:inherit; background:linear-gradient(90deg,#21b743,#73d085); transition:width .2s ease; }
.ide-setup-workspace .setup-preview-stats { display:grid; grid-template-columns:1fr 1fr; gap:9px; }
.ide-setup-workspace .setup-preview-stats > div { display:grid; gap:3px; padding:8px; border-radius:9px; background:#f5faf4; }
.ide-setup-workspace .setup-preview-stats small { color:#7b8d7d; font-size:8px; }
.ide-setup-workspace .setup-preview-stats strong { color:#244a2d; font-size:16px; }
.ide-setup-workspace .setup-preview-note { margin:0; color:#718675; font-size:9px; line-height:1.5; }
.ide-setup-workspace .setup-rule-chips { display:flex; flex-wrap:wrap; gap:6px; }
.ide-setup-workspace .setup-rule-chips span { padding:6px 8px; border:1px solid #d9ead8; border-radius:999px; color:#4f7255; background:#f4faf3; font-size:8px; font-weight:850; }
.ide-setup-workspace .setup-question-summary { display:flex; align-items:center; justify-content:space-between; gap:10px; color:#31543a; font-size:10px; }
.ide-setup-workspace .setup-question-summary b { text-transform:capitalize; }
.ide-setup-workspace .setup-question-summary span,.ide-setup-workspace .setup-topic-summary { color:#728574; font-size:9px; }
.ide-setup-workspace .setup-topic-summary { line-height:1.5; }
.ide-setup-workspace .setup-preview-footer { display:flex; justify-content:space-between; gap:10px; padding-top:9px; border-top:1px solid #e6efe5; color:#758a78; font-size:9px; }
.ide-setup-workspace .setup-preview-footer strong { color:#31543a; text-align:right; }
/* The created-battle confirmation uses the same light Timedoor surface. */
.ide-setup-workspace > .created-container { width:min(100%,1180px); max-width:none; max-height:100%; margin:auto; padding:24px; overflow-y:auto; border:1px solid var(--setup-border); border-radius:18px; background:#fff; box-shadow:0 12px 34px rgba(20,70,35,.06); }
.ide-setup-workspace .success-icon { border-color:#bce3c0; color:#168534; background:#eff9ef; box-shadow:none; }
.ide-setup-workspace .created-label { color:#438b4d; }
.ide-setup-workspace .created-container h1 { color:#173c25; }
.ide-setup-workspace .created-description { color:#708675; }
.ide-setup-workspace .battle-code-card { border-color:#cfe5d0; background:linear-gradient(135deg,#f5fbf4,#eaf6e9); }
.ide-setup-workspace .battle-code-card > span { color:#718675; }
.ide-setup-workspace .battle-code-card > strong { color:#148333; }
.ide-setup-workspace .battle-code-card button { border-color:#cce5cd; color:#28773a; background:#fff; }
.ide-setup-workspace .battle-info > div,.ide-setup-workspace .created-rule-summary > div { border-color:#e0ece0; background:#f8fbf7; }
.ide-setup-workspace .battle-info span,.ide-setup-workspace .created-rule-summary span { color:#758a78; }
.ide-setup-workspace .battle-info strong,.ide-setup-workspace .created-rule-summary strong { color:#294d31; }
.ide-setup-workspace .open-public-button { border:0; color:#fff; background:var(--setup-green); }
.ide-setup-workspace .history-secondary-button,.ide-setup-workspace .another-button { border:1px solid #d5e6d5; color:#3f6847; background:#f7fbf6; }
.ide-setup-workspace .battle-link-card { border-color:#dcebdd; background:#fbfdfb; }
.ide-setup-workspace .battle-link-card.blue { border-color:#cfe2ed; }
.ide-setup-workspace .battle-link-card.red { border-color:#eed5dc; }
.ide-setup-workspace .link-icon { background:#f0f7ef; }
.ide-setup-workspace .link-label { color:#718675; }
.ide-setup-workspace .link-content strong { color:#294d31; }
.ide-setup-workspace .link-url { color:#718675; }
.ide-setup-workspace .player-access-code { color:#718675; }
.ide-setup-workspace .player-access-code code { color:#31543a; }
.ide-setup-workspace .player-access-code button,.ide-setup-workspace .link-actions button { border-color:#d6e7d6; color:#416b49; background:#fff; }
.ide-setup-workspace .link-actions button.primary { border-color:#0ca52c; color:#fff; background:#0ca52c; }
.ide-setup-workspace .link-actions button.primary.red { border-color:#ca4960; color:#fff; background:#ca4960; }
.ide-setup-workspace .player-qr-panel { border-color:#dcebdd; background:#f7fbf6; }
.ide-setup-workspace .player-qr-panel.red { border-color:#eed5dc; }
.ide-setup-workspace .player-qr-panel > span { color:#438b4d; }
.ide-setup-workspace .player-qr-panel.red > span { color:#a65166; }
.ide-setup-workspace .qr-error-box { border-color:#f0bdb8; color:#973e35; background:#fff2f0; }
@media (max-width:1080px) { .ide-setup-workspace .setup-workspace-grid { grid-template-columns:minmax(0,1fr) 300px; } .ide-setup-workspace .setup-live-panel { padding:14px; } }
@media (max-width:820px) { .setup-page.ide-setup-workspace { height:auto; min-height:calc(100dvh - 76px); padding:12px; overflow:visible; } .ide-setup-workspace .setup-container { flex:none; } .ide-setup-workspace .setup-header { position:relative; align-items:flex-start; padding:12px; } .ide-setup-workspace .setup-header p { display:none; } .ide-setup-workspace .setup-workspace-grid { flex:none; grid-template-columns:1fr; } .ide-setup-workspace .setup-form { height:auto; max-height:none; padding:0 0 10px; overflow:visible; } .ide-setup-workspace .setup-live-panel { position:relative; top:auto; order:-1; height:auto; max-height:none; } }
@media (max-width:520px) { .ide-setup-workspace .setup-header { flex-direction:column; gap:10px; } .ide-setup-workspace .history-button { width:100%; } .ide-setup-workspace .setup-header h1 { font-size:18px; } .ide-setup-workspace .setup-card { padding:15px; } }
@media (max-width: 700px) {
  .question-extra-grid { grid-template-columns: 1fr; }
  .question-topic-field { grid-column: auto; }
}
</style>
