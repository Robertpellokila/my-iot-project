<script setup>
import {
  computed,
  onMounted,
  ref,
} from "vue";

import {
  RouterLink,
  useRouter,
} from "vue-router";

import {
  deleteRfid,
  formatCardType,
  getRfidCards,
} from "../services/rfidService";


const router = useRouter();

const rfids = ref([]);

const loading = ref(true);

const errorMessage =
  ref("");

const successMessage =
  ref("");

const searchQuery =
  ref("");

const selectedType =
  ref("all");


const loadRfids =
  async () => {
    loading.value = true;

    errorMessage.value = "";

    try {
      rfids.value =
        await getRfidCards();

    } catch (error) {
      console.error(error);

      errorMessage.value =
        error.message ||
        "Failed to load RFID.";
    } finally {
      loading.value = false;
    }
  };


const filteredRfids =
  computed(() => {
    const query =
      searchQuery.value
        .toLowerCase()
        .trim();

    return rfids.value.filter(
      (rfid) => {
        const owner =
          rfid.profiles
            ?.full_name || "";

        const matchesQuery =
          !query ||
          rfid.uid
            .toLowerCase()
            .includes(query) ||
          owner
            .toLowerCase()
            .includes(query) ||
          (
            rfid.label || ""
          )
            .toLowerCase()
            .includes(query);

        const matchesType =
          selectedType.value ===
            "all" ||
          rfid.card_type ===
            selectedType.value;

        return (
          matchesQuery &&
          matchesType
        );
      }
    );
  });


const handleDelete =
  async (rfid) => {
    const confirmed =
      window.confirm(
        `Delete RFID ${rfid.uid}?`
      );

    if (!confirmed) {
      return;
    }

    try {
      await deleteRfid(
        rfid.id
      );

      rfids.value =
        rfids.value.filter(
          (item) =>
            item.id !== rfid.id
        );

      successMessage.value =
        "RFID berhasil dihapus.";

      setTimeout(() => {
        successMessage.value = "";
      }, 3000);

    } catch (error) {
      console.error(error);

      errorMessage.value =
        error.message ||
        "Failed to delete RFID.";
    }
  };


const editRfid =
  (id) => {
    router.push({
      name: "rfid-edit",
      params: {
        id,
      },
    });
  };


onMounted(loadRfids);
</script>


<template>
  <section class="page-container">

    <div class="page-heading">

      <div>

        <span class="eyebrow">
          MANAGEMENT
        </span>

        <h2>
          RFID Management
        </h2>

        <p>
          Manage all registered RFID
          cards and tags.
        </p>

      </div>


      <RouterLink
        to="/rfid/register"
        class="primary-button"
      >
        ＋ Register RFID
      </RouterLink>

    </div>


    <div
      v-if="errorMessage"
      class="form-message message-error"
      style="margin-bottom: 15px"
    >
      {{ errorMessage }}
    </div>


    <div
      v-if="successMessage"
      class="form-message message-info"
      style="margin-bottom: 15px"
    >
      {{ successMessage }}
    </div>


    <div class="panel">

      <div class="panel-header">

        <div>

          <h3>
            Registered RFID
          </h3>

          <p>
            {{
              filteredRfids.length
            }}
            records displayed.
          </p>

        </div>

      </div>


      <div class="filter-bar">

        <div
          class="search-wrapper filter-search"
        >

          <span class="search-icon">
            ⌕
          </span>

          <input
            v-model="searchQuery"
            type="search"
            placeholder="Search UID, owner, or label..."
            class="search-input"
          />

        </div>


        <select
          v-model="selectedType"
          class="filter-select"
        >

          <option value="all">
            All Types
          </option>

          <option value="rfid_card">
            RFID Card
          </option>

          <option value="rfid_tag">
            RFID Tag
          </option>

          <option value="e_ktp">
            e-KTP
          </option>

          <option value="other">
            Other
          </option>

        </select>

      </div>


      <div class="table-wrapper">

        <table class="data-table">

          <thead>

            <tr>

              <th>
                UID
              </th>

              <th>
                Owner
              </th>

              <th>
                Type
              </th>

              <th>
                Label
              </th>

              <th>
                Status
              </th>

              <th>
                Registered
              </th>

              <th>
                Action
              </th>

            </tr>

          </thead>


          <tbody>

            <tr v-if="loading">

              <td
                colspan="7"
                class="empty-table"
              >
                Loading RFID...
              </td>

            </tr>


            <tr
              v-for="rfid in filteredRfids"
              :key="rfid.id"
            >

              <td>

                <code class="uid-code">
                  {{ rfid.uid }}
                </code>

              </td>


              <td>
                {{
                  rfid.profiles
                    ?.full_name ||
                  "Unassigned"
                }}
              </td>


              <td>
                {{
                  formatCardType(
                    rfid.card_type
                  )
                }}
              </td>


              <td>
                {{
                  rfid.label ||
                  "—"
                }}
              </td>


              <td>

                <span
                  class="status-badge"
                  :class="
                    rfid.is_active
                      ? 'status-active'
                      : 'status-inactive'
                  "
                >
                  {{
                    rfid.is_active
                      ? "Active"
                      : "Inactive"
                  }}
                </span>

              </td>


              <td>
                {{
                  new Date(
                    rfid.created_at
                  ).toLocaleDateString(
                    "en-GB"
                  )
                }}
              </td>


              <td>

                <div class="table-actions">

                  <button
                    class="table-action-button"
                    @click="
                      editRfid(rfid.id)
                    "
                  >
                    Edit
                  </button>


                  <button
                    class="table-action-button table-action-danger"
                    @click="
                      handleDelete(rfid)
                    "
                  >
                    Delete
                  </button>

                </div>

              </td>

            </tr>


            <tr
              v-if="
                !loading &&
                filteredRfids.length === 0
              "
            >

              <td
                colspan="7"
                class="empty-table"
              >
                No RFID records found.
              </td>

            </tr>

          </tbody>

        </table>

      </div>

    </div>

  </section>
</template>