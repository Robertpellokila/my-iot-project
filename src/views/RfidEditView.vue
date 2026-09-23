<script setup>
import {
  onMounted,
  ref,
} from "vue";

import {
  useRoute,
  useRouter,
} from "vue-router";

import {
  getProfiles,
  getRfidById,
  updateRfid,
  formatCardType,
} from "../services/rfidService";


const route = useRoute();

const router = useRouter();


const id =
  route.params.id;


const ownerId =
  ref("");

const cardType =
  ref("RFID Card");

const label =
  ref("");

const uid =
  ref("");

const isActive =
  ref(true);


const profiles =
  ref([]);

const loading =
  ref(true);

const saving =
  ref(false);

const errorMessage =
  ref("");


const loadData =
  async () => {
    loading.value = true;

    try {

      const [
        rfid,
        profileData,
      ] = await Promise.all([
        getRfidById(id),
        getProfiles(),
      ]);


      uid.value =
        rfid.uid;

      label.value =
        rfid.label || "";

      isActive.value =
        rfid.is_active;

      ownerId.value =
        rfid.owner_id || "";

      cardType.value =
        formatCardType(
          rfid.card_type
        );

      profiles.value =
        profileData;

    } catch (error) {
      console.error(error);

      errorMessage.value =
        error.message ||
        "Failed to load RFID.";
    } finally {
      loading.value = false;
    }
  };


const handleUpdate =
  async () => {
    errorMessage.value = "";

    if (!uid.value.trim()) {
      errorMessage.value =
        "UID wajib diisi.";

      return;
    }

    saving.value = true;

    try {

      await updateRfid(
        id,
        {
          uid: uid.value,
          ownerId:
            ownerId.value || null,
          cardType:
            cardType.value,
          label:
            label.value,
          isActive:
            isActive.value,
        }
      );


      await router.push({
        name: "rfid-list",
      });

    } catch (error) {
      console.error(error);

      errorMessage.value =
        error.message ||
        "Failed to update RFID.";
    } finally {
      saving.value = false;
    }
  };


onMounted(loadData);
</script>


<template>
  <section class="page-container">

    <div class="page-heading">

      <div>

        <span class="eyebrow">
          MANAGEMENT
        </span>

        <h2>
          Edit RFID
        </h2>

        <p>
          Update registered RFID
          information.
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
        ← Back
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
      v-if="loading"
      class="panel"
    >
      <div class="empty-table">
        Loading RFID...
      </div>
    </div>


    <div
      v-else
      class="registration-layout"
    >

      <div class="panel">

        <div class="panel-header">

          <div>

            <h3>
              RFID Information
            </h3>

            <p>
              Edit RFID information.
            </p>

          </div>

        </div>


        <form
          class="registration-form"
          @submit.prevent="
            handleUpdate
          "
        >

          <div class="form-group">

            <label>
              Owner
            </label>

            <select
              v-model="ownerId"
              class="form-input"
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

            <label>
              RFID Type
            </label>

            <select
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

            <label>
              Label
            </label>

            <input
              v-model="label"
              type="text"
              class="form-input"
              placeholder="RFID label"
            />

          </div>


          <div class="form-group">

            <label>
              UID
            </label>

            <input
              v-model="uid"
              type="text"
              class="form-input"
              autocomplete="off"
            />

          </div>


          <div class="form-group">

            <label>
              Status
            </label>

            <select
              v-model="isActive"
              class="form-input"
            >

              <option :value="true">
                Active
              </option>

              <option :value="false">
                Inactive
              </option>

            </select>

          </div>


          <div class="form-actions">

            <button
              type="button"
              class="secondary-button"
              @click="
                router.push({
                  name: 'rfid-list'
                })
              "
            >
              Cancel
            </button>


            <button
              type="submit"
              class="primary-button"
              :disabled="saving"
            >
              {{
                saving
                  ? "Updating..."
                  : "Save Changes"
              }}
            </button>

          </div>

        </form>

      </div>


      <div class="panel">

        <div class="panel-header">

          <div>

            <h3>
              RFID Preview
            </h3>

            <p>
              Current card identity.
            </p>

          </div>

        </div>


        <div class="scan-preview">

          <div class="scan-circle">
            ⌁
          </div>

          <h4>
            {{ uid }}
          </h4>

          <p>
            {{
              label ||
              "No label assigned"
            }}
          </p>


          <span
            class="status-badge"
            :class="
              isActive
                ? 'status-active'
                : 'status-inactive'
            "
          >
            {{
              isActive
                ? "Active"
                : "Inactive"
            }}
          </span>

        </div>

      </div>

    </div>

  </section>
</template>