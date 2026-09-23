<script setup>
import {
  onMounted,
  ref,
} from "vue";

import { useRouter } from "vue-router";

import {
  getCurrentProfile,
  signOut,
} from "../services/authService";


const router = useRouter();

const isProfileOpen =
  ref(false);

const profile =
  ref(null);

const loading =
  ref(true);


const loadProfile = async () => {
  try {
    profile.value =
      await getCurrentProfile();

  } catch (error) {
    console.error(error);
  } finally {
    loading.value = false;
  }
};


const handleLogout = async () => {
  try {
    await signOut();

    await router.replace({
      name: "login",
    });

  } catch (error) {
    console.error(error);
  }
};


onMounted(loadProfile);
</script>


<template>
  <header class="app-navbar">

    <div class="navbar-left">

      <div class="brand-mark">
        R
      </div>

      <div class="brand-content">

        <h1>
          RFID System
        </h1>

        <p>
          Registration Platform
        </p>

      </div>

    </div>


    <div class="navbar-right">

      <div class="connection-status">

        <span class="status-dot"></span>

        <span>
          System Online
        </span>

      </div>


      <button
        class="profile-button"
        @click="
          isProfileOpen =
            !isProfileOpen
        "
      >

        <div class="avatar">
          {{
            profile?.full_name
              ?.charAt(0)
              ?.toUpperCase() || "A"
          }}
        </div>


        <div class="profile-info">

          <strong>
            {{
              loading
                ? "Loading..."
                : profile?.full_name ||
                  "Administrator"
            }}
          </strong>

          <span>
            {{
              profile?.role ||
              "admin"
            }}
          </span>

        </div>


        <span class="profile-arrow">
          ⌄
        </span>

      </button>


      <div
        v-if="isProfileOpen"
        class="profile-dropdown"
      >

        <div class="dropdown-item">

          <span>
            Role
          </span>

          <span class="dropdown-muted">
            {{
              profile?.role ||
              "admin"
            }}
          </span>

        </div>


        <button
          class="dropdown-item dropdown-logout"
          @click="handleLogout"
        >
          <span>
            Sign out
          </span>

          <span>
            ↪
          </span>
        </button>

      </div>

    </div>

  </header>
</template>