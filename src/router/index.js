import {
  createRouter,
  createWebHistory,
} from "vue-router";

import {
  supabase,
} from "../lib/supabase";


// =========================================================
// LAYOUT
// =========================================================

import DashboardLayout
  from "../layouts/DashboardLayout.vue";


// =========================================================
// AUTH
// =========================================================

import LoginView
  from "../views/LoginView.vue";


// =========================================================
// DASHBOARD
// =========================================================

import DashboardView
  from "../views/DashboardView.vue";


// =========================================================
// RFID
// =========================================================

import RfidListView
  from "../views/RfidListView.vue";

import RfidRegisterView
  from "../views/RfidRegisterView.vue";

import RfidEditView
  from "../views/RfidEditView.vue";


// =========================================================
// GAME
// =========================================================

import BattleArena
  from "../views/BattleArena.vue";

import GameSetup
  from "../views/GameSetup.vue";

import BattleHistory
  from "../views/BattleHistory.vue";

import RegisterGameCard
  from "../views/RegisterGameCard.vue";


// =========================================================
// QUESTIONS
// =========================================================

import AddQuestion
  from "../views/AddQuestion.vue";

import AllQuestions
  from "../views/AllQuestions.vue";

import EditQuestion
  from "../views/EditQuestion.vue";


// =========================================================
// PUBLIC BATTLE
// =========================================================

import PublicBattleArena
  from "../views/PublicBattleArena.vue";

import PlayerBattle
  from "../views/PlayerBattle.vue";
import CardCollection from "../views/CardCollection.vue";


// =========================================================
// ROUTER
// =========================================================

const router =
  createRouter({

    history:
      createWebHistory(),

    routes: [

      // =====================================================
      // PUBLIC BATTLE
      //
      // Tidak memakai DashboardLayout.
      // Cocok untuk TV / monitor battle.
      // =====================================================

      {
        path:
          "/battle/:code",

        name:
          "public-battle",

        component:
          PublicBattleArena,

        props:
          true,
      },


      // =====================================================
      // PLAYER BATTLE
      //
      // Tidak memakai DashboardLayout.
      //
      // Contoh:
      // /play/ABC123/p1
      // /play/ABC123/p2
      // =====================================================

      {
        path:
          "/play/:code/:player",

        name:
          "player-battle",

        component:
          PlayerBattle,

        props:
          true,

        beforeEnter:
          to => {

            const player =
              String(
                to.params.player ??
                ""
              )
                .trim()
                .toLowerCase();


            if (
              player !==
                "p1"

              &&

              player !==
                "p2"
            ) {

              return {
                name:
                  "login",
              };

            }


            return true;

          },
      },


      // =====================================================
      // LOGIN
      // =====================================================

      {
        path:
          "/login",

        name:
          "login",

        component:
          LoginView,

        meta: {
          guestOnly:
            true,
        },
      },


      // =====================================================
      // DASHBOARD LAYOUT
      //
      // Semua children di sini wajib login
      // karena parent requiresAuth.
      // =====================================================

      {
        path:
          "/",

        component:
          DashboardLayout,

        meta: {
          requiresAuth:
            true,
        },

        children: [

          // =================================================
          // DEFAULT
          // =================================================

          {
            path:
              "",

            redirect:
              "/dashboard",
          },


          // =================================================
          // DASHBOARD
          // =================================================

          {
            path:
              "dashboard",

            name:
              "dashboard",

            component:
              DashboardView,
          },


          // =================================================
          // QUESTIONS
          // =================================================

          {
            path:
              "questions",

            name:
              "questions",

            component:
              AllQuestions,
          },


          {
            path:
              "questions/add",

            name:
              "question-add",

            component:
              AddQuestion,
          },


          {
            path:
              "questions/:id/edit",

            name:
              "question-edit",

            component:
              EditQuestion,

            props:
              true,
          },


          // =================================================
          // OLD QUESTION URL
          //
          // Supaya route lama tetap bekerja.
          // =================================================

          {
            path:
              "question",

            redirect:
              "/questions/add",
          },


          // =================================================
          // GAME SETUP
          // =================================================

          {
            path:
              "setup",

            name:
              "game-setup",

            component:
              GameSetup,
          },


          // =================================================
          // BATTLE HISTORY
          // =================================================

          {
            path:
              "battle-history",

            name:
              "battle-history",

            component:
              BattleHistory,
          },


          // =================================================
          // LOCAL BATTLE ARENA
          // =================================================

          {
            path:
              "arena",

            name:
              "battle-arena",

            component:
              BattleArena,
          },


          // =================================================
          // GAME CARD
          // =================================================

          {
            path:
              "game/register",

            name:
              "register-card",

            component:
              RegisterGameCard,
          },
          {
            path:
              "game/album-card",

            name:
              "album-card",

            component:
              CardCollection,
          },


          // =================================================
          // RFID
          // =================================================

          {
            path:
              "rfid",

            name:
              "rfid-list",

            component:
              RfidListView,
          },


          {
            path:
              "rfid/register",

            name:
              "rfid-register",

            component:
              RfidRegisterView,
          },


          {
            path:
              "rfid/:id/edit",

            name:
              "rfid-edit",

            component:
              RfidEditView,

            props:
              true,
          },

        ],
      },


      // =====================================================
      // 404
      // =====================================================

      {
        path:
          "/:pathMatch(.*)*",

        redirect:
          "/dashboard",
      },

    ],


    // =======================================================
    // SCROLL
    // =======================================================

    scrollBehavior() {

      return {
        top:
          0,
      };

    },

  });


// =========================================================
// ROUTER GUARD
// =========================================================

router.beforeEach(
  async to => {

    try {

      const {
        data: {
          session,
        },
      } =
        await supabase.auth
          .getSession();


      // =====================================================
      // REQUIRES LOGIN
      // =====================================================

      const requiresAuth =
        to.matched.some(
          route =>
            route.meta
              .requiresAuth
        );


      if (
        requiresAuth
        &&
        !session
      ) {

        return {

          name:
            "login",

          query: {

            /*
             * Setelah berhasil login,
             * LoginView nantinya bisa redirect
             * kembali ke halaman yang diminta.
             */

            redirect:
              to.fullPath,

          },

        };

      }


      // =====================================================
      // GUEST ONLY
      // =====================================================

      if (
        to.meta.guestOnly
        &&
        session
      ) {

        return {
          name:
            "dashboard",
        };

      }


      return true;

    }

    catch (
      error
    ) {

      console.error(
        "Router auth guard:",
        error
      );


      /*
       * Kalau proses session gagal
       * dan halaman membutuhkan login,
       * lempar ke login.
       */

      const requiresAuth =
        to.matched.some(
          route =>
            route.meta
              .requiresAuth
        );


      if (
        requiresAuth
      ) {

        return {

          name:
            "login",

          query: {
            redirect:
              to.fullPath,
          },

        };

      }


      return true;

    }

  }
);


export default router;