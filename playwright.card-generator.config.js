import { defineConfig } from "@playwright/test";
const production = process.env.TBC_PHOTO_PRODUCTION === "1";
const baseURL = production ? "http://127.0.0.1:5186" : "http://127.0.0.1:5181";
export default defineConfig({
  testDir: "./tests/visual",
  testMatch: [
    "admin-toasts.spec.js",
    "battle-access-controls.spec.js",
    "battle-history.spec.js",
    "card-generator.spec.js",
    "studio-workflow.spec.js",
    "album-flow.spec.js",
    "public-catalog.spec.js",
    "public-combo.spec.js",
    "landing-guide.spec.js",
    "question-seed.spec.js",
    "player-action-panel.spec.js",
    "combo-rules.spec.js",
    "player-arena.spec.js",
    "public-arena.spec.js",
    "battle-rule-catalog.spec.js",
    "player-photo-inspect.spec.js",
    "player-photo-tools.spec.js",
  ],
  fullyParallel: false,
  timeout: 60000,
  expect: { timeout: 10000, toHaveScreenshot: { maxDiffPixelRatio: 0.0005 } },
  use: {
    baseURL,
    viewport: { width: 1540, height: 1100 },
    channel: "chrome",
    reducedMotion: "reduce",
    locale: "id-ID",
  },
  webServer: {
    command: production
      ? "npm run preview -- --host 127.0.0.1 --port 5186"
      : "npm run dev -- --host 127.0.0.1 --port 5181",
    url: baseURL,
    reuseExistingServer: !production && !process.env.CI,
  },
  outputDir: production
    ? "test-results/photo-production"
    : "test-results/card-generator",
  reporter: "list",
});
