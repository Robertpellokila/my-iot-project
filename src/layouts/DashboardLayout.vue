<script setup>
import { ref } from "vue";
import { RouterLink, RouterView } from "vue-router";

import AppNavbar from "../components/AppNavbar.vue";

const isSidebarOpen = ref(false);

const closeSidebar = () => {
  isSidebarOpen.value = false;
};
</script>

<template>
  <div class="app-shell">
    <AppNavbar />

    <button
      class="mobile-menu-button"
      @click="isSidebarOpen = !isSidebarOpen"
      aria-label="Toggle navigation"
    >
      ☰
    </button>

    <div
      v-if="isSidebarOpen"
      class="sidebar-overlay"
      @click="closeSidebar"
    ></div>

    <aside
      class="app-sidebar"
      :class="{ 'sidebar-open': isSidebarOpen }"
    >
      <div class="sidebar-header">
        <span class="sidebar-label">MAIN MENU</span>
      </div>

      <nav class="sidebar-navigation">
        <RouterLink
          to="/dashboard"
          class="sidebar-link"
          active-class="sidebar-link-active"
          @click="closeSidebar"
        >
          <span class="sidebar-icon">▦</span>
          <span>Dashboard</span>
        </RouterLink>

        <RouterLink
          to="/rfid"
          class="sidebar-link"
          active-class="sidebar-link-active"
          @click="closeSidebar"
        >
          <span class="sidebar-icon">▣</span>
          <span>RFID Management</span>
        </RouterLink>

        <RouterLink
          to="/rfid/register"
          class="sidebar-link"
          active-class="sidebar-link-active"
          @click="closeSidebar"
        >
          <span class="sidebar-icon">＋</span>
          <span>Register RFID</span>
        </RouterLink>
      </nav>

      <div class="sidebar-divider"></div>

      <div class="sidebar-header">
        <span class="sidebar-label">SYSTEM</span>
      </div>

      <nav class="sidebar-navigation">
        <button
          class="sidebar-link sidebar-link-disabled"
          disabled
        >
          <span class="sidebar-icon">◉</span>
          <span>Device Management</span>
          <span class="coming-soon">Soon</span>
        </button>

        <button
          class="sidebar-link sidebar-link-disabled"
          disabled
        >
          <span class="sidebar-icon">◷</span>
          <span>Scan History</span>
          <span class="coming-soon">Soon</span>
        </button>
      </nav>

      <div class="sidebar-footer">
        <div class="sidebar-footer-icon">⌁</div>

        <div>
          <strong>RFID Core</strong>
          <p>v0.1.0 • Development</p>
        </div>
      </div>
    </aside>

    <main class="main-content">
      <RouterView />
    </main>
  </div>
</template>