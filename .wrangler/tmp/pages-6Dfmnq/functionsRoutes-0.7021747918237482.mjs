import { onRequestOptions as __api_rfid_scan_js_onRequestOptions } from "/Users/admin/Documents/rfid-registration-system/functions/api/rfid/scan.js"
import { onRequestPost as __api_rfid_scan_js_onRequestPost } from "/Users/admin/Documents/rfid-registration-system/functions/api/rfid/scan.js"

export const routes = [
    {
      routePath: "/api/rfid/scan",
      mountPath: "/api/rfid",
      method: "OPTIONS",
      middlewares: [],
      modules: [__api_rfid_scan_js_onRequestOptions],
    },
  {
      routePath: "/api/rfid/scan",
      mountPath: "/api/rfid",
      method: "POST",
      middlewares: [],
      modules: [__api_rfid_scan_js_onRequestPost],
    },
  ]