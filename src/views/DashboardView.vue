<script setup>
import {
  computed,
  onMounted,
  ref,
} from "vue";

import { RouterLink } from "vue-router";

import {
  getRfidCards,
  getRfidStats,
  formatCardType,
} from "../services/rfidService";


const loading = ref(true);

const errorMessage =
  ref("");

const searchQuery =
  ref("");

const stats = ref({
  total: 0,
  active: 0,
  inactive: 0,
  scans: 0,
});

const recentRfids =
  ref([]);


const filteredRfids =
  computed(() => {
    const query =
      searchQuery.value
        .toLowerCase()
        .trim();

    if (!query) {
      return recentRfids.value;
    }

    return recentRfids.value.filter(
      (rfid) => {
        const owner =
          rfid.profiles
            ?.full_name || "";

        return (
          rfid.uid
            .toLowerCase()
            .includes(query) ||
          owner
            .toLowerCase()
            .includes(query)
        );
      }
    );
  });


const loadDashboard =
  async () => {
    loading.value = true;

    errorMessage.value = "";

    try {
      const [
        statsData,
        rfidData,
      ] = await Promise.all([
        getRfidStats(),
        getRfidCards(),
      ]);

      stats.value =
        statsData;

      recentRfids.value =
        rfidData.slice(0, 5);

    } catch (error) {
      console.error(error);

      errorMessage.value =
        error.message ||
        "Failed to load dashboard.";

    } finally {
      loading.value = false;
    }
  };


onMounted(loadDashboard);
</script>


<template>
  <section class="page-container">

    <div class="page-heading">

      <div>

        <span class="eyebrow">
          OVERVIEW
        </span>

        <h2>
          Dashboard
        </h2>

        <p>
          Monitor your RFID
          registration system.
        </p>

      </div>


      <RouterLink
        to="/rfid/register"
        class="primary-button"
      >
        <span>＋</span>
        Register RFID
      </RouterLink>

    </div>


    <div
      v-if="errorMessage"
      class="form-message message-error"
      style="margin-bottom: 20px"
    >
      {{ errorMessage }}
    </div>


    <div class="stats-grid">

      <div class="stat-card">

        <div class="stat-card-top">

          <span class="stat-label">
            Total RFID
          </span>

          <div class="stat-icon stat-blue">
            ▣
          </div>

        </div>

        <div class="stat-value">
          {{
            loading
              ? "—"
              : stats.total
          }}
        </div>

        <div class="stat-detail">
          Registered RFID
        </div>

      </div>


      <div class="stat-card">

        <div class="stat-card-top">

          <span class="stat-label">
            Active RFID
          </span>

          <div class="stat-icon stat-green">
            ✓
          </div>

        </div>

        <div class="stat-value">
          {{
            loading
              ? "—"
              : stats.active
          }}
        </div>

        <div class="stat-detail">
          Currently active
        </div>

      </div>


      <div class="stat-card">

        <div class="stat-card-top">

          <span class="stat-label">
            Inactive RFID
          </span>

          <div class="stat-icon stat-orange">
            ◌
          </div>

        </div>

        <div class="stat-value">
          {{
            loading
              ? "—"
              : stats.inactive
          }}
        </div>

        <div class="stat-detail">
          Currently inactive
        </div>

      </div>


      <div class="stat-card">

        <div class="stat-card-top">

          <span class="stat-label">
            Total Scans
          </span>

          <div class="stat-icon stat-purple">
            ⌁
          </div>

        </div>

        <div class="stat-value">
          {{
            loading
              ? "—"
              : stats.scans
          }}
        </div>

        <div class="stat-detail">
          Scan events
        </div>

      </div>

    </div>


    <div class="content-grid">

      <div class="panel panel-wide">

        <div class="panel-header">

          <div>

            <h3>
              Recent RFID
            </h3>

            <p>
              Latest registered RFID.
            </p>

          </div>


          <RouterLink
            to="/rfid"
            class="text-link"
          >
            View all →
          </RouterLink>

        </div>


        <div class="search-wrapper">

          <span class="search-icon">
            ⌕
          </span>

          <input
            v-model="searchQuery"
            type="search"
            placeholder="Search UID or owner..."
            class="search-input"
          />

        </div>


        <div class="table-wrapper">

          <table class="data-table">

            <thead>

              <tr>
                <th>UID</th>
                <th>Owner</th>
                <th>Type</th>
                <th>Status</th>
                <th>Date</th>
              </tr>

            </thead>


            <tbody>

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

              </tr>


              <tr
                v-if="
                  !loading &&
                  filteredRfids.length === 0
                "
              >

                <td
                  colspan="5"
                  class="empty-table"
                >
                  No RFID records found.
                </td>

              </tr>


              <tr v-if="loading">

                <td
                  colspan="5"
                  class="empty-table"
                >
                  Loading RFID...
                </td>

              </tr>

            </tbody>

          </table>

        </div>

      </div>


      <div class="panel">

        <div class="panel-header">

          <div>

            <h3>
              Device Status
            </h3>

            <p>
              Hardware connection.
            </p>

          </div>

          <span class="status-dot"></span>

        </div>


        <div class="device-status-card">

          <div class="device-illustration">
            ⌁
          </div>

          <h4>
            ESP32 RFID Reader
          </h4>

          <span
            class="status-badge status-inactive"
          >
            Not Connected
          </span>

          <p>
            ESP32 + RC522 integration
            will be implemented next.
          </p>

        </div>


        <div class="device-info-list">

          <div class="device-info-row">
            <span>
              Device ID
            </span>

            <strong>
              Not configured
            </strong>
          </div>


          <div class="device-info-row">
            <span>
              Reader
            </span>

            <strong>
              RC522
            </strong>
          </div>


          <div class="device-info-row">
            <span>
              Connection
            </span>

            <strong>
              Pending
            </strong>
          </div>

        </div>

      </div>

    </div>

  </section>
</template>