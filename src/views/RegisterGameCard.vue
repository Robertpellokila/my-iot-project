<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "../lib/supabase"; // Sesuaikan path Supabase kamu

const router = useRouter();

// State Form Pendaftaran/Edit Kartu Game
const cardName = ref("");
const element = ref("Fire");
const hp = ref(120);
const attack = ref(45);
const defense = ref(30);
const imageUrl = ref("🔥");
const uid = ref("");
const avatarUrl = ref("");

// Mode penanda apakah kartu sudah terdaftar sebelumnya
const isExistingCard = ref(false);
const recordId = ref(null);

const loading = ref(false);
const errorMessage = ref("");
const successMessage = ref("");

const isImageUrl = (str) =>
  str && (str.startsWith("http") || str.startsWith("/"));

let realtimeChannel;

// ==========================================
// CEK APAKAH UID SUDAH TERDAFTAR DI DATABASE
// ==========================================
const checkExistingCard = async (scannedUid) => {
  try {
    const { data, error } = await supabase
      .from("game_cards")
      .select("*")
      .eq("uid", scannedUid)
      .maybeSingle();

    if (error) throw error;

    if (data) {
      // Jika data ditemukan, masuk ke Mode Edit & Muat Data Lama
      isExistingCard.value = true;
      recordId.value = data.id;
      cardName.value = data.name;
      element.value = data.element;
      hp.value = data.hp;
      attack.value = data.attack;
      defense.value = data.defense;
      imageUrl.value = data.image_url || "🔥";
      avatarUrl.value = data.avatar_url || "";

      successMessage.value = `Kartu terdeteksi! Memuat data "${data.name}" (Mode Edit).`;
    } else {
      // Jika belum ada, reset form untuk pendaftaran baru
      isExistingCard.value = false;
      recordId.value = null;
      cardName.value = "";
      successMessage.value = "Kartu baru terdeteksi! Silakan lengkapi data.";
    }
    errorMessage.value = "";
  } catch (err) {
    console.error(err);
    errorMessage.value = "Gagal memeriksa status kartu di database.";
  }
};

// ==========================================
// SUPABASE REALTIME LISTENER (AUTO-FILL & CHECK)
// ==========================================
const setupRealtimeListener = () => {
  realtimeChannel = supabase
    .channel("game_card_register_listener")
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "scan_events",
      },
      async (payload) => {
        const scannedUid = payload.new.uid;
        uid.value = scannedUid;

        // Cek ke tabel game_cards apakah UID ini sudah ada
        await checkExistingCard(scannedUid);
      },
    )
    .subscribe();
};

// ==========================================
// SIMPAN ATAU PERBARUI DATA (UPSERT / EDIT)
// ==========================================
const handleSubmit = async () => {
  errorMessage.value = "";
  successMessage.value = "";

  if (!uid.value.trim()) {
    errorMessage.value =
      "UID RFID wajib diisi (Tap kartu pada hardware RC522).";
    return;
  }

  if (!cardName.value.trim()) {
    errorMessage.value = "Nama karakter/kartu wajib diisi.";
    return;
  }

  loading.value = true;

  try {
    let error;

    if (isExistingCard.value && recordId.value) {
      // PROSES UPDATE DATA KARTU YANG SUDAH ADA
      const res = await supabase
        .from("game_cards")
        .update({
          name: cardName.value.trim(),
          element: element.value,
          hp: parseInt(hp.value),
          attack: parseInt(attack.value),
          defense: parseInt(defense.value),
          image_url: imageUrl.value.trim(),
          avatar_url: avatarUrl.value.trim(),
        })
        .eq("id", recordId.value);
      error = res.error;
    } else {
      // PROSES INSERT KARTU BARU
      const res = await supabase.from("game_cards").insert([
        {
          uid: uid.value.trim(),
          name: cardName.value.trim(),
          element: element.value,
          hp: parseInt(hp.value),
          attack: parseInt(attack.value),
          defense: parseInt(defense.value),
          image_url: imageUrl.value.trim(),
          avatar_url: avatarUrl.value.trim(),
        },
      ]);
      error = res.error;
    }

    if (error) throw error;

    successMessage.value = isExistingCard.value
      ? "Kartu TCG berhasil diperbarui!"
      : "Kartu TCG baru berhasil didaftarkan!";

    setTimeout(() => {
      router.push({ name: "battle-arena" });
    }, 1500);
  } catch (error) {
    console.error(error);
    errorMessage.value = error.message || "Gagal menyimpan data kartu.";
  } finally {
    loading.value = false;
  }
};

const resetForm = () => {
  uid.value = "";
  cardName.value = "";
  element.value = "Fire";
  hp.value = 120;
  attack.value = 45;
  defense.value = 30;
  imageUrl.value = "🔥";
  avatarUrl.value = "";
  isExistingCard.value = false;
  recordId.value = null;
  errorMessage.value = "";
  successMessage.value = "";
};

onMounted(() => {
  setupRealtimeListener();
});

onUnmounted(() => {
  if (realtimeChannel) {
    supabase.removeChannel(realtimeChannel);
  }
});
</script>

<template>
  <div class="register-container">
    <div class="header-section">
      <span class="eyebrow">TCG SYSTEM</span>
      <h2>
        {{
          isExistingCard
            ? "Edit Game Card (Terdaftar)"
            : "Register Game Card Baru"
        }}
      </h2>
      <p>
        Tap kartu RFID pada modul fisik. Jika kartu sudah terdaftar, data lama
        akan otomatis ditarik untuk diedit.
      </p>
    </div>

    <!-- Pesan Error / Sukses -->
    <div v-if="errorMessage" class="alert error">{{ errorMessage }}</div>
    <div v-if="successMessage" class="alert success">{{ successMessage }}</div>

    <div class="form-grid-layout">
      <!-- FORM INPUT -->
      <div class="panel-card">
        <form @submit.prevent="handleSubmit">
          <div class="input-group">
            <label for="uid">UID RFID (Otomatis dari ESP32)</label>
            <input
              id="uid"
              v-model="uid"
              type="text"
              placeholder="Tempelkan kartu ke reader..."
              readonly
              class="input-highlight"
            />
            <span class="help-text">
              Status:
              <strong
                :style="{ color: isExistingCard ? '#38bdf8' : '#4ade80' }"
              >
                {{
                  isExistingCard
                    ? "Kartu Dikenali (Mode Edit)"
                    : "Kartu Baru (Mode Pendaftaran)"
                }}
              </strong>
            </span>
          </div>

          <div class="input-group">
            <label for="name">Nama Karakter / Monster</label>
            <input
              id="name"
              v-model="cardName"
              type="text"
              placeholder="e.g. Thunder Beast"
              required
            />
          </div>

          <div class="input-row">
            <div class="input-group">
              <label for="element">Elemen</label>
              <select id="element" v-model="element">
                <option value="Fire">Fire (Api)</option>
                <option value="Water">Water (Air)</option>
                <option value="Grass">Grass (Tanaman)</option>
                <option value="Electric">Electric (Listrik)</option>
              </select>
            </div>

            <div class="input-group">
              <label for="hp">Stat HP (Darah)</label>
              <input
                id="hp"
                v-model.number="hp"
                type="number"
                min="10"
                max="999"
                required
              />
            </div>
          </div>

          <div class="input-row">
            <div class="input-group">
              <label for="attack">Stat Attack (Serangan)</label>
              <input
                id="attack"
                v-model.number="attack"
                type="number"
                min="1"
                max="999"
                required
              />
            </div>

            <div class="input-group">
              <label for="defense">Stat Defense (Pertahanan)</label>
              <input
                id="defense"
                v-model.number="defense"
                type="number"
                min="0"
                max="999"
                required
              />
            </div>
          </div>

          <div class="input-group">
            <label for="image">Asset Gambar (Emoji atau URL Link)</label>
            <input
              id="image"
              v-model="imageUrl"
              type="text"
              placeholder="e.g. ⚡ atau https://.../image.png"
              required
            />
          </div>
          <div class="input-group">
            <label for="avatarUrl"> Avatar URL </label>

            <input
              id="avatarUrl"
              v-model="avatarUrl"
              type="text"
              placeholder="URL PNG transparan untuk animasi attack..."
            />

            <small>
              Gunakan PNG/WebP transparan. Dipakai hanya untuk battle animation.
            </small>
          </div>

          <div class="button-actions">
            <button type="button" class="btn-secondary" @click="resetForm">
              Reset
            </button>
            <button type="submit" class="btn-primary" :disabled="loading">
              {{
                loading
                  ? "Menyimpan..."
                  : isExistingCard
                    ? "Perbarui Kartu"
                    : "Simpan Kartu Baru"
              }}
            </button>
          </div>
        </form>
      </div>

      <!-- LIVE PREVIEW KARTU -->
      <!-- LIVE PREVIEW KARTU -->
      <div class="panel-card preview-panel">
        <h3>Preview Kartu</h3>
        <p class="preview-desc">
          Tampilan kartu saat nanti dipanggil di Arena.
        </p>

        <div class="preview-card-box" :class="element.toLowerCase()">
          <div class="preview-header">
            <span class="p-name">{{ cardName || "Nama Karakter" }}</span>
            <span class="p-hp">HP {{ hp }}</span>
          </div>

          <!-- ARTBOX PREVIEW DIPERBAIKI -->
          <div class="preview-artbox">
            <img
              v-if="isImageUrl(imageUrl)"
              :src="imageUrl"
              class="preview-img-asset"
            />
            <span v-else>{{ imageUrl }}</span>
          </div>

          <div class="preview-footer">
            <div class="p-stat">
              ATK: <strong>{{ attack }}</strong>
            </div>
            <div class="p-stat">
              DEF: <strong>{{ defense }}</strong>
            </div>
          </div>
          <div class="preview-uid-tag">UID: {{ uid || "— — — —" }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.register-container {
  padding: 30px;
  color: white;
  background-color: #0b132b;
  min-height: 85vh;
  border-radius: 12px;
  border: 1px solid #1e293b;
  font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
}
.header-section {
  margin-bottom: 25px;
}
.eyebrow {
  font-size: 10px;
  font-weight: bold;
  color: #38bdf8;
  letter-spacing: 2px;
  text-transform: uppercase;
}
.header-section h2 {
  font-size: 24px;
  font-weight: 900;
  margin: 4px 0;
}
.header-section p {
  font-size: 13px;
  color: #94a3b8;
}

.alert {
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 20px;
  font-size: 13px;
  font-weight: bold;
}
.alert.error {
  background-color: rgba(239, 68, 68, 0.2);
  border: 1px solid #ef4444;
  color: #fca5a5;
}
.alert.success {
  background-color: rgba(34, 197, 94, 0.2);
  border: 1px solid #22c55e;
  color: #86efac;
}

.form-grid-layout {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  gap: 30px;
}
.panel-card {
  background: #0f172a;
  border: 1px solid #1e293b;
  padding: 25px;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 15px;
}
.input-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 15px;
}

label {
  font-size: 11px;
  font-weight: bold;
  color: #cbd5e1;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
input,
select {
  background: #1e293b;
  border: 1px solid #334155;
  padding: 10px 14px;
  border-radius: 6px;
  color: white;
  font-size: 14px;
  outline: none;
  transition: border-color 0.2s;
}
input:focus,
select:focus {
  border-color: #38bdf8;
}
.input-highlight {
  background-color: rgba(56, 189, 248, 0.1);
  border-color: #38bdf8;
  color: #7dd3fc;
  font-weight: bold;
  cursor: not-allowed;
}
.help-text {
  font-size: 10px;
  color: #64748b;
  margin-top: 2px;
}

.button-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 25px;
}
.btn-secondary {
  background: #334155;
  color: #cbd5e1;
  border: none;
  padding: 10px 20px;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
}
.btn-primary {
  background: #2563eb;
  color: white;
  border: none;
  padding: 10px 24px;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-primary:hover {
  background: #1d4ed8;
}
.btn-primary:disabled {
  background: #475569;
  cursor: not-allowed;
}

/* PREVIEW KARTU */
.preview-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}
.preview-desc {
  font-size: 12px;
  color: #94a3b8;
  margin-bottom: 20px;
}

.preview-card-box {
  width: 220px;
  height: 310px;
  background: #fcd34d;
  border-radius: 14px;
  padding: 10px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.5);
  position: relative;
}
.preview-card-box.fire {
  background: linear-gradient(135deg, #f87171, #991b1b);
}
.preview-card-box.water {
  background: linear-gradient(135deg, #60a5fa, #1e3a8a);
}
.preview-card-box.grass {
  background: linear-gradient(135deg, #4ade80, #14532d);
}
.preview-card-box.electric {
  background: linear-gradient(135deg, #fde047, #854d0e);
}

.preview-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: white;
  font-weight: bold;
  font-size: 12px;
  margin-bottom: 6px;
}
.preview-artbox {
  width: 100%;
  height: 140px;
  background: #1e293b;
  border: 3px solid #cbd5e1;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 50px;
  box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.8);
  overflow: hidden;
}
.preview-footer {
  display: flex;
  justify-content: space-around;
  background: rgba(0, 0, 0, 0.4);
  border-radius: 6px;
  padding: 6px;
  margin-top: auto;
  font-size: 11px;
  color: white;
}
.preview-uid-tag {
  font-size: 9px;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 6px;
  font-family: monospace;
}

.preview-artbox {
  width: 100%;
  height: 140px;
  background: #1e293b;
  border: 3px solid #cbd5e1;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 50px;
  box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.8);
  overflow: hidden;
  position: relative;
}

.preview-img-asset {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
