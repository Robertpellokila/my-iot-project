import {
  createRouter,
  createWebHistory,
} from "vue-router";

import DashboardLayout from "../layouts/DashboardLayout.vue";

import DashboardView from "../views/DashboardView.vue";
import RfidListView from "../views/RfidListView.vue";
import RfidRegisterView from "../views/RfidRegisterView.vue";

const router = createRouter({
  history: createWebHistory(),

  routes: [
    {
      path: "/",
      component: DashboardLayout,

      children: [
        {
          path: "",
          redirect: "/dashboard",
        },

        {
          path: "/dashboard",
          name: "dashboard",
          component: DashboardView,
        },

        {
          path: "/rfid",
          name: "rfid-list",
          component: RfidListView,
        },

        {
          path: "/rfid/register",
          name: "rfid-register",
          component: RfidRegisterView,
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

export default router;