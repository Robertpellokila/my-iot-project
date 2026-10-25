import { defineConfig } from '@playwright/test';
export default defineConfig({ testDir:'./tests/visual', testMatch:['card-generator.spec.js','studio-workflow.spec.js','album-flow.spec.js','public-catalog.spec.js','landing-guide.spec.js','player-action-panel.spec.js','battle-rule-catalog.spec.js'], fullyParallel:false,
  timeout:60000, expect:{ timeout:10000, toHaveScreenshot:{ maxDiffPixelRatio:.0005 } },
  use:{ baseURL:'http://127.0.0.1:5181', viewport:{width:1540,height:1100}, channel:'chrome', reducedMotion:'reduce', locale:'id-ID' },
  webServer:{ command:'npm run dev -- --host 127.0.0.1 --port 5181', url:'http://127.0.0.1:5181', reuseExistingServer:!process.env.CI },
  outputDir:'test-results/card-generator', reporter:'list' });
