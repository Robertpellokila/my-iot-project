<script setup>
import { ref } from "vue";
import { RouterLink, RouterView } from "vue-router";

import AppNavbar from "../components/AppNavbar.vue";

const isSidebarOpen = ref(false);

const sections = ref({
  rfid: true,
  questions: true,
  game: true,
  system: false,
});

const closeSidebar = () => {
  isSidebarOpen.value = false;
};

const toggleSection = (section) => {
  sections.value[section] = !sections.value[section];
};
</script>

<template>
  <div class="app-shell">
    <!-- NAVBAR -->
    <AppNavbar />

    <!-- MOBILE BUTTON -->
    <button
      class="mobile-menu-button"
      @click="isSidebarOpen = !isSidebarOpen"
      aria-label="Toggle navigation"
    >
      ☰
    </button>

    <!-- MOBILE OVERLAY -->
    <div
      v-if="isSidebarOpen"
      class="sidebar-overlay"
      @click="closeSidebar"
    ></div>

    <!-- SIDEBAR -->
    <aside
      class="app-sidebar"
      :class="{
        'sidebar-open': isSidebarOpen,
      }"
    >
      <!-- MAIN MENU -->
      <div class="sidebar-group">
        <div class="sidebar-section-title">MAIN MENU</div>

        <nav class="sidebar-navigation">
          <RouterLink
            to="/dashboard"
            class="sidebar-link"
            active-class="sidebar-link-active"
            @click="closeSidebar"
          >
            <span class="sidebar-icon"> ▦ </span>

            <span> Dashboard </span>
          </RouterLink>
        </nav>
      </div>

      <!-- RFID -->
      <div class="sidebar-group">
        <button
          class="sidebar-section-toggle"
          type="button"
          @click="toggleSection('rfid')"
        >
          <span> RFID MANAGEMENT </span>

          <span
            class="section-arrow"
            :class="{
              open: sections.rfid,
            }"
          >
            ▾
          </span>
        </button>

        <Transition name="section-collapse">
          <nav v-show="sections.rfid" class="sidebar-navigation">
            <RouterLink
              to="/rfid"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ▣ </span>

              <span> All RFID </span>
            </RouterLink>

            <RouterLink
              to="/rfid/register"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ＋ </span>

              <span> Register RFID </span>
            </RouterLink>
          </nav>
        </Transition>
      </div>

      <!-- QUESTION -->
      <div class="sidebar-group">
        <button
          class="sidebar-section-toggle"
          type="button"
          @click="toggleSection('questions')"
        >
          <span> QUESTION MANAGEMENT </span>

          <span
            class="section-arrow"
            :class="{
              open: sections.questions,
            }"
          >
            ▾
          </span>
        </button>

        <Transition name="section-collapse">
          <nav v-show="sections.questions" class="sidebar-navigation">
            <RouterLink
              to="/questions"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ? </span>

              <span> All Questions </span>
            </RouterLink>

            <RouterLink
              to="/questions/add"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ＋ </span>

              <span> Add Question </span>
            </RouterLink>
          </nav>
        </Transition>
      </div>

      <!-- GAME -->
      <!-- =====================================================
     GAME
====================================================== -->

      <div class="sidebar-group">
        <button
          class="sidebar-section-toggle"
          type="button"
          @click="toggleSection('game')"
        >
          <span> GAME </span>

          <span
            class="section-arrow"
            :class="{
              open: sections.game,
            }"
          >
            ▾
          </span>
        </button>

        <Transition name="section-collapse">
          <nav v-show="sections.game" class="sidebar-navigation">
            <!-- ===============================================
           GAME SETUP
      ================================================ -->

            <RouterLink
              to="/setup"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ⚙ </span>

              <span> Game Setup </span>
            </RouterLink>

            <!-- ===============================================
           BATTLE HISTORY
      ================================================ -->

            <RouterLink
              to="/battle-history"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ◷ </span>

              <span> Battle History </span>
            </RouterLink>

            <!-- ===============================================
           LOCAL BATTLE ARENA
      ================================================ -->

            <RouterLink
              to="/arena"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> ⚔ </span>

              <span> Battle Arena </span>
            </RouterLink>

            <!-- ===============================================
           REGISTER CARD
      ================================================ -->

            <RouterLink
              to="/game/register"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> 🎴 </span>

              <span> Register Card </span>
            </RouterLink>
            <RouterLink
              to="/game/album-card"
              class="sidebar-link"
              active-class="sidebar-link-active"
              @click="closeSidebar"
            >
              <span class="sidebar-icon"> 📕 </span>

              <span> Album Card </span>
            </RouterLink>
          </nav>
        </Transition>
      </div>

      <!-- SYSTEM -->
      <div class="sidebar-group">
        <button
          class="sidebar-section-toggle"
          type="button"
          @click="toggleSection('system')"
        >
          <span> SYSTEM </span>

          <span
            class="section-arrow"
            :class="{
              open: sections.system,
            }"
          >
            ▾
          </span>
        </button>

        <Transition name="section-collapse">
          <nav v-show="sections.system" class="sidebar-navigation">
            <button class="sidebar-link sidebar-link-disabled" disabled>
              <span class="sidebar-icon"> ◉ </span>

              <span> Device Management </span>

              <span class="coming-soon"> Soon </span>
            </button>

            <button class="sidebar-link sidebar-link-disabled" disabled>
              <span class="sidebar-icon"> ◷ </span>

              <span> Scan History </span>

              <span class="coming-soon"> Soon </span>
            </button>
          </nav>
        </Transition>
      </div>

      <!-- FOOTER -->
      <div class="sidebar-footer">
        <div class="sidebar-footer-icon">⌁</div>

        <div>
          <strong> RFID Core </strong>

          <p>v0.1.0 • Development</p>
        </div>
      </div>
    </aside>

    <!-- CONTENT -->
    <main class="main-content">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
/* =====================================================
   ROOT
===================================================== */

.app-shell {
  width: 100%;

  min-height: 100vh;

  height: auto;

  position: relative;

  background: #050a16;

  /*
    PENTING:
    jangan overflow hidden.
  */
  overflow: visible;
}

/* =====================================================
   SIDEBAR
===================================================== */

.app-sidebar {
  width: 256px;

  position: fixed;

  top: 76px;
  bottom: 0;
  left: 0;

  z-index: 50;

  padding: 18px 16px 16px;

  background: #080e1c;

  border-right: 1px solid rgba(255, 255, 255, 0.06);

  display: flex;
  flex-direction: column;

  overflow-y: auto;
  overflow-x: hidden;
}

.app-sidebar::-webkit-scrollbar {
  width: 5px;
}

.app-sidebar::-webkit-scrollbar-track {
  background: transparent;
}

.app-sidebar::-webkit-scrollbar-thumb {
  border-radius: 999px;

  background: rgba(114, 150, 190, 0.22);
}

/* =====================================================
   SIDEBAR GROUP
===================================================== */

.sidebar-group {
  /*
    sebelumnya terlalu jauh.
  */
  margin-bottom: 12px;
}

/* =====================================================
   MAIN MENU TITLE
===================================================== */

.sidebar-section-title {
  padding: 7px 11px 8px;

  color: #62738d;

  font-size: 9px;

  font-weight: 900;

  letter-spacing: 0.16em;
}

/* =====================================================
   COLLAPSIBLE TITLE
===================================================== */

.sidebar-section-toggle {
  width: 100%;

  height: 34px;

  padding: 0 10px;

  display: flex;

  align-items: center;

  justify-content: space-between;

  border: none;

  border-radius: 8px;

  cursor: pointer;

  color: #667993;

  background: transparent;

  font-size: 9px;

  font-weight: 900;

  letter-spacing: 0.14em;

  text-align: left;

  transition:
    background 0.18s ease,
    color 0.18s ease;
}

.sidebar-section-toggle:hover {
  color: #a7bbd4;

  background: rgba(255, 255, 255, 0.025);
}

.section-arrow {
  display: inline-block;

  color: #60738d;

  font-size: 11px;

  transition: transform 0.2s ease;
}

.section-arrow.open {
  transform: rotate(180deg);
}

/* =====================================================
   NAVIGATION
===================================================== */

.sidebar-navigation {
  display: flex;

  flex-direction: column;

  gap: 3px;

  margin-top: 4px;
}

/* =====================================================
   SIDEBAR LINK
===================================================== */

.sidebar-link {
  width: 100%;

  min-height: 42px;

  padding: 0 12px;

  display: flex;

  align-items: center;

  gap: 11px;

  position: relative;

  border: 1px solid transparent;

  border-radius: 9px;

  color: #8c9db6;

  background: transparent;

  text-decoration: none;

  font-size: 12px;

  font-weight: 600;

  transition:
    color 0.18s ease,
    background 0.18s ease,
    border 0.18s ease;
}

.sidebar-link:hover {
  color: #e5efff;

  background: rgba(255, 255, 255, 0.035);
}

.sidebar-link-active {
  color: #dceaff;

  border-color: rgba(87, 117, 255, 0.22);

  background: linear-gradient(
    90deg,
    rgba(66, 89, 188, 0.19),
    rgba(72, 87, 151, 0.12)
  );
}

/* =====================================================
   ICON
===================================================== */

.sidebar-icon {
  width: 21px;

  flex-shrink: 0;

  display: inline-flex;

  justify-content: center;

  align-items: center;

  color: #8296b4;

  font-size: 15px;
}

.sidebar-link-active .sidebar-icon {
  color: #a9c9ff;
}

/* =====================================================
   DISABLED
===================================================== */

.sidebar-link-disabled {
  border: none;

  opacity: 0.45;

  cursor: not-allowed;

  text-align: left;
}

.coming-soon {
  margin-left: auto;

  padding: 3px 6px;

  border-radius: 999px;

  color: #6f8098;

  background: rgba(255, 255, 255, 0.045);

  font-size: 7px;

  font-weight: 900;
}

/* =====================================================
   FOOTER
===================================================== */

.sidebar-footer {
  margin-top: auto;

  width: 100%;

  padding: 14px 11px;

  display: flex;

  align-items: center;

  gap: 10px;

  border-top: 1px solid rgba(255, 255, 255, 0.06);

  background: #080e1c;
}

.sidebar-footer-icon {
  width: 32px;
  height: 32px;

  display: grid;

  place-items: center;

  border-radius: 9px;

  color: #8ca9d5;

  background: rgba(70, 100, 180, 0.12);
}

.sidebar-footer strong {
  color: #aab8cc;

  font-size: 10px;
}

.sidebar-footer p {
  margin: 2px 0 0;

  color: #576980;

  font-size: 8px;
}

/* =====================================================
   MAIN CONTENT
===================================================== */

.main-content {
  width: calc(100% - 256px);

  min-width: 0;

  min-height: calc(100vh - 76px);

  margin-left: 256px;

  /*
    PENTING:
    jangan height: 100vh;
    jangan overflow hidden;
  */
  height: auto;

  overflow: visible;
}

/* =====================================================
   MOBILE BUTTON
===================================================== */

.mobile-menu-button {
  display: none;

  position: fixed;

  top: 85px;
  left: 12px;

  z-index: 70;

  width: 39px;
  height: 39px;

  border: 1px solid rgba(255, 255, 255, 0.1);

  border-radius: 9px;

  color: white;

  background: #0b1324;

  cursor: pointer;
}

/* =====================================================
   OVERLAY
===================================================== */

.sidebar-overlay {
  display: none;
}

/* =====================================================
   COLLAPSE
===================================================== */

.section-collapse-enter-active,
.section-collapse-leave-active {
  transition:
    opacity 0.18s ease,
    transform 0.18s ease;
}

.section-collapse-enter-from,
.section-collapse-leave-to {
  opacity: 0;

  transform: translateY(-4px);
}

/* =====================================================
   RESPONSIVE
===================================================== */

@media (max-width: 900px) {
  .app-sidebar {
    transform: translateX(-100%);

    transition: transform 0.25s ease;
  }

  .app-sidebar.sidebar-open {
    transform: translateX(0);
  }

  .main-content {
    width: 100%;

    margin-left: 0;
  }

  .mobile-menu-button {
    display: grid;

    place-items: center;
  }

  .sidebar-overlay {
    display: block;

    position: fixed;

    inset: 76px 0 0;

    z-index: 40;

    background: rgba(0, 0, 0, 0.55);

    backdrop-filter: blur(2px);
  }
}
</style>
