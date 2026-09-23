<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";

import {
  signIn,
} from "../services/authService";


const router = useRouter();

const email = ref("");

const password = ref("");

const loading = ref(false);

const errorMessage = ref("");


const handleLogin = async () => {
  errorMessage.value = "";

  if (!email.value.trim()) {
    errorMessage.value =
      "Email wajib diisi.";

    return;
  }

  if (!password.value) {
    errorMessage.value =
      "Password wajib diisi.";

    return;
  }

  loading.value = true;

  try {
    await signIn(
      email.value.trim(),
      password.value
    );

    await router.replace({
      name: "dashboard",
    });

  } catch (error) {
    console.error(error);

    errorMessage.value =
      "Email atau password tidak valid.";
  } finally {
    loading.value = false;
  }
};
</script>


<template>
  <main class="login-page">

    <div class="login-background"></div>

    <section class="login-card">

      <div class="login-brand">

        <div class="login-brand-icon">
          R
        </div>

        <div>
          <strong>
            RFID System
          </strong>

          <span>
            Registration Platform
          </span>
        </div>

      </div>


      <div class="login-heading">

        <span class="eyebrow">
          ADMIN ACCESS
        </span>

        <h1>
          Welcome back
        </h1>

        <p>
          Sign in to manage your RFID
          registration system.
        </p>

      </div>


      <form
        class="login-form"
        @submit.prevent="handleLogin"
      >

        <div class="form-group">

          <label for="email">
            Email
          </label>

          <input
            id="email"
            v-model="email"
            class="form-input"
            type="email"
            autocomplete="email"
            placeholder="admin@example.com"
          />

        </div>


        <div class="form-group">

          <label for="password">
            Password
          </label>

          <input
            id="password"
            v-model="password"
            class="form-input"
            type="password"
            autocomplete="current-password"
            placeholder="Enter your password"
          />

        </div>


        <div
          v-if="errorMessage"
          class="form-message message-error"
        >
          {{ errorMessage }}
        </div>


        <button
          class="primary-button login-button"
          type="submit"
          :disabled="loading"
        >
          {{
            loading
              ? "Signing in..."
              : "Sign in"
          }}
        </button>

      </form>


      <p class="login-footer">
        RFID Registration System
        <span>•</span>
        Development
      </p>

    </section>

  </main>
</template>