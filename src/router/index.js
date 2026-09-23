import {
  createRouter,
  createWebHistory,
} from "vue-router";

import { supabase } from "../lib/supabase";

import DashboardLayout from "../layouts/DashboardLayout.vue";

import LoginView from "../views/LoginView.vue";
import DashboardView from "../views/DashboardView.vue";
import RfidListView from "../views/RfidListView.vue";
import RfidRegisterView from "../views/RfidRegisterView.vue";
import RfidEditView from "../views/RfidEditView.vue";


const router = createRouter({
  history: createWebHistory(),

  routes: [
    {
      path: "/login",
      name: "login",
      component: LoginView,

      meta: {
        guestOnly: true,
      },
    },

    {
      path: "/",
      component: DashboardLayout,

      meta: {
        requiresAuth: true,
      },

      children: [
        {
          path: "",
          redirect: "/dashboard",
        },

        {
          path: "dashboard",
          name: "dashboard",
          component: DashboardView,
        },

        {
          path: "rfid",
          name: "rfid-list",
          component: RfidListView,
        },

        {
          path: "rfid/register",
          name: "rfid-register",
          component: RfidRegisterView,
        },

        {
          path: "rfid/:id/edit",
          name: "rfid-edit",
          component: RfidEditView,
        },
      ],
    },
  ],

  scrollBehavior() {
    return {
      top: 0,
    };
  },
});


router.beforeEach(
  async (to) => {
    const {
      data: {
        session,
      },
    } = await supabase.auth.getSession();

    if (
      to.meta.requiresAuth &&
      !session
    ) {
      return {
        name: "login",
      };
    }

    if (
      to.meta.guestOnly &&
      session
    ) {
      return {
        name: "dashboard",
      };
    }

    return true;
  }
);


export default router;