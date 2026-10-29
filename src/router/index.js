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

import PlayerBattleEntry
  from "../views/PlayerBattleEntry.vue";
import CardCollection from "../views/CardCollection.vue";
import GameLanding from "../views/GameLanding.vue";
import SkillCatalog from "../views/SkillCatalog.vue";


// =========================================================
// ROUTER
// =========================================================

const router =
  createRouter({

    history:
      createWebHistory(),

    routes: [

      { path: "/", name: "game-landing", component: GameLanding },
      { path: "/cards", name: "public-cards", component: GameLanding },
      { path: "/fusion", name: "public-fusion", component: GameLanding },
      { path: "/skills", name: "public-skills", component: GameLanding },
      { path: "/play", name: "public-game-play", component: GameLanding },

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
          PlayerBattleEntry,

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
          "/admin",

        component:
          DashboardLayout,

        meta: {
          requiresAuth:
            true,
        },

        children: [
          {
            path: 'cards',
            redirect: { name: 'card-generator' },
          },
          {
            path: 'card-generator',
            name: 'card-generator',
            component: () => import('../views/CardGeneratorView.vue'),
          },

          // =================================================
          // DEFAULT
          // =================================================

          {
            path:
              "",

            redirect:
              "/admin/dashboard",
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
              "/admin/questions/add",
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

            redirect: to => ({name:'card-generator',query:to.query.source ? {catalog:to.query.source,rfid:'1'} : {}}),
          },
          {
            path:
              "game/album-card",

            name:
              "album-card",

            component:
              CardCollection,
          },
          {
            path:
              "game/catalog",

            name:
              "skill-catalog",

            component:
              SkillCatalog,
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

      ...[
        ["/dashboard", "/admin/dashboard"], ["/questions", "/admin/questions"],
        ["/questions/add", "/admin/questions/add"], ["/question", "/admin/questions/add"],
        ["/setup", "/admin/setup"], ["/battle-history", "/admin/battle-history"],
        ["/arena", "/admin/arena"], ["/game/register", "/admin/game/register"],
        ["/game/album-card", "/admin/game/album-card"], ["/rfid", "/admin/rfid"],
        ["/game/catalog", "/admin/game/catalog"],
        ["/rfid/register", "/admin/rfid/register"],
      ].map(([path, redirect]) => ({ path, redirect })),
      { path: "/rfid/:id/edit", redirect: (to) => `/admin/rfid/${to.params.id}/edit` },


      // =====================================================
      // 404
      // =====================================================

      {
        path:
          "/:pathMatch(.*)*",

        redirect:
          "/admin/dashboard",
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
