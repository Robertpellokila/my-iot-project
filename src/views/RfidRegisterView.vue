<script setup>
import { onMounted, onUnmounted, ref } from "vue";
import { useRouter } from "vue-router";
import { createRfid, getProfiles } from "../services/rfidService";

// IMPORT SUPABASE CLIENT KAMU DI SINI
// Sesuaikan path-nya jika berbeda (misal: "../supabase/index.js")
import { supabase } from "../lib/supabase"; 

const router = useRouter();

const ownerId = ref("");
const cardType = ref("RFID Card");
const label = ref("");
const uid = ref("");

const profiles = ref([]);
const loading = ref(false);
const loadingProfiles = ref(false);
const errorMessage = ref("");
const successMessage = ref("");

let realtimeChannel;

const loadProfiles = async () => {
  loadingProfiles.value = true;
  try {
    profiles.value = await getProfiles();
  } catch (error) {
    console.error(error);
    errorMessage.value = error.message || "Failed to load profiles.";
  } finally {
    loadingProfiles.value = false;
  }
};

// ==========================================
// FASE 3.4: SETUP SUPABASE REALTIME
// ==========================================
const setupRealtime = () => {
  realtimeChannel = supabase
    .channel('scan_events_listener')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'scan_events'
      },
      (payload) => {
        console.log('Kartu baru terdeteksi:', payload.new);
        
        // Otomatis isi field UID di form!
        uid.value = payload.new.uid;
        
        // Berikan feedback visual ke user
        successMessage.value = "Kartu terdeteksi! UID telah diisi otomatis.";
        errorMessage.value = "";
        
        // Hapus pesan sukses setelah 3 detik
        setTimeout(() => {
          if (successMessage.value === "Kartu terdeteksi! UID telah diisi otomatis.") {
            successMessage.value = "";
          }
        }, 3000);
      }
    )
    .subscribe();
};

const handleSubmit = async () => {
  errorMessage.value = "";
  successMessage.value = "";

  if (!uid.value.trim()) {
    errorMessage.value = "UID RFID wajib diisi.";
    return;
  }

  loading.value = true;

  try {
    await createRfid({
      uid: uid.value,
      ownerId: ownerId.value || null,
      cardType: cardType.value,
      label: label.value,
      isActive: true,
    });

    successMessage.value = "RFID berhasil didaftarkan.";

    setTimeout(() => {
      router.push({ name: "rfid-list" });
    }, 700);
  } catch (error) {
    console.error(error);
    errorMessage.value = error.message || "Gagal mendaftarkan RFID.";
  } finally {
    loading.value = false;
  }
};

const resetForm = () => {
  ownerId.value = "";
  cardType.value = "RFID Card";
  label.value = "";
  uid.value = "";
  errorMessage.value = "";
  successMessage.value = "";
};

// ==========================================
// LIFECYCLE HOOKS
// ==========================================
onMounted(() => {
  loadProfiles();
  setupRealtime(); // Aktifkan listener saat halaman dibuka
});

onUnmounted(() => {
  if (realtimeChannel) {
    supabase.removeChannel(realtimeChannel); // Matikan listener saat pindah halaman
  }
});
</script>


<template>
  <section class="page-container">

    <div class="page-heading">

      <div>

        <span class="eyebrow">
          REGISTRATION
        </span>

        <h2>
          Register RFID
        </h2>

        <p>
          Register a new RFID card
          or tag into the system.
        </p>

      </div>


      <button
        class="secondary-button"
        @click="
          router.push({
            name: 'rfid-list'
          })
        "
      >
        ← Back to RFID
      </button>

    </div>


    <div
      v-if="errorMessage"
      class="form-message message-error"
      style="margin-bottom: 20px"
    >
      {{ errorMessage }}
    </div>


    <div
      v-if="successMessage"
      class="form-message message-info"
      style="margin-bottom: 20px"
    >
      {{ successMessage }}
    </div>


    <div class="registration-layout">

      <div class="panel">

        <div class="panel-header">

          <div>

            <h3>
              RFID Information
            </h3>

            <p>
              Enter the RFID registration
              information.
            </p>

          </div>

        </div>


        <form
          class="registration-form"
          @submit.prevent="
            handleSubmit
          "
        >

          <div class="form-group">

            <label for="owner">
              Owner
            </label>

            <select
              id="owner"
              v-model="ownerId"
              class="form-input"
              :disabled="
                loadingProfiles
              "
            >

              <option value="">
                Unassigned
              </option>

              <option
                v-for="profile in profiles"
                :key="profile.id"
                :value="profile.id"
              >
                {{ profile.full_name }}
              </option>

            </select>

          </div>


          <div class="form-group">

            <label for="cardType">
              RFID Type
            </label>

            <select
              id="cardType"
              v-model="cardType"
              class="form-input"
            >

              <option value="RFID Card">
                RFID Card
              </option>

              <option value="RFID Tag">
                RFID Tag
              </option>

              <option value="e-KTP">
                e-KTP
              </option>

              <option value="Other">
                Other
              </option>

            </select>

          </div>


          <div class="form-group">

            <label for="label">
              Label
            </label>

            <input
              id="label"
              v-model="label"
              type="text"
              class="form-input"
              placeholder="e.g. Main Access Card"
            />

          </div>


          <div class="form-group">

            <label for="uid">
              UID
            </label>

            <input
              id="uid"
              v-model="uid"
              type="text"
              class="form-input"
              placeholder="e.g. A1B2C3D4"
              autocomplete="off"
            />

            <span class="form-help">
              Saat ini UID dimasukkan
              secara manual. Pada tahap
              hardware, field ini akan
              diisi otomatis oleh ESP32
              + RC522.
            </span>

          </div>


          <div class="form-actions">

            <button
              type="button"
              class="secondary-button"
              @click="resetForm"
            >
              Reset
            </button>


            <button
              type="submit"
              class="primary-button"
              :disabled="loading"
            >
              {{
                loading
                  ? "Saving..."
                  : "Register RFID"
              }}
            </button>

          </div>

        </form>

      </div>


      <div class="panel">

        <div class="panel-header">

          <div>

            <h3>
              Registration Preview
            </h3>

            <p>
              Current RFID data.
            </p>

          </div>

        </div>


        <div class="scan-preview">

          <div class="scan-circle">
            ⌁
          </div>

          <h4>
            {{
              uid
                ? "UID Ready"
                : "Waiting for UID"
            }}
          </h4>

          <p>
            Pada tahap berikutnya,
            RC522 akan mengirim UID
            secara otomatis.
          </p>


          <div class="preview-uid">

            <span>
              UID
            </span>

            <strong>
              {{
                uid ||
                "— — — —"
              }}
            </strong>

          </div>

        </div>

      </div>

    </div>

  </section>
</template>