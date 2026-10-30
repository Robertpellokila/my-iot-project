import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';

const env = ['.env', '.env.local'].map(path => {
  try { return readFileSync(path, 'utf8'); } catch { return ''; }
}).join('\n');
const endpoint = env.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)[1];
const base = { enabled: true, rule_kind: 'pair', type_keys: ['fire', 'thunder'], ap_cost: 2,
  primary_multiplier: 1, assist_multipliers: [.7], damage_multiplier: 1, bonus_damage: 8,
  defense_ignore_pct: .25, heal_after: 0, shield_after: 0, members: [], effect_json: {} };
const recipes = [
  { ...base, id: 1, combo_name: 'Pilot Thunder', members: [{ type: 'fire', card_code: 'COB_008_STUDIO_0123456789abcdef0123456789abcdef', tag: 'TEAM' }, { type: 'thunder', tag: 'TEAM' }], shared_tag: true, heal_after: 12, shield_after: 8, status_key: 'stun', status_target: 'enemy', effect_json: { summary: 'Serang bersama dan pulihkan HP kartu peserta.', cleanse_negative_status: true } },
  { ...base, id: 2, rule_kind: 'triple', combo_name: 'Chaos Storm', type_keys: ['dark', 'fire', 'thunder'], ap_cost: 3, assist_multipliers: [.6, .5] },
  { ...base, id: 3, rule_kind: 'formation', combo_name: 'Guardian Formation', type_keys: ['forest', 'knight', 'light', 'thunder'], ap_cost: 3, assist_multipliers: [.6, .45, .35] },
  ...Array.from({ length: 9 }, (_, i) => ({ ...base, id: i + 4, combo_name: `Resep pasangan ${i + 1}` })),
  { ...base, id: 99, enabled: false, combo_name: 'DISABLED RECIPE' },
];
const publicCards = [{ id: 'published', card_code: 'COB-008', name: 'Coby Piloting', hp: 128, attack: 35, defense: 12, element: 'Fire', rarity: 'Epic', skills: [], image_url: '/images/battle-arena/synergy-v1.webp' }];

async function mockCatalog(page) {
  const state = { rows: structuredClone(recipes), offline: false, published: true, requests: [], held: null, holdNext: false };
  await page.route(`${endpoint}/**`, async route => {
    const request = route.request();
    const url = new URL(request.url());
    state.requests.push({ resource: url.pathname.split('/').at(-1), method: request.method(), url });
    if (url.pathname.endsWith('/tcg_combo_rule_catalog')) {
      if (state.holdNext) { state.holdNext = false; state.held = route; return; }
      return route.fulfill(state.offline ? { status: 503, json: { message: 'Unavailable' } } : { json: state.rows });
    }
    if (url.pathname.endsWith('/get_landing_cards')) return route.fulfill({ json: state.published ? publicCards : [] });
    return route.fulfill({ json: [] });
  });
  return state;
}

const errors = new WeakMap();
test.beforeEach(({ page }) => { const list = []; errors.set(page, list); page.on('pageerror', error => list.push(error.message)); });
test.afterEach(({ page }) => expect(errors.get(page)).toEqual([]));

test('Home links to the public Combo catalog with actual recipes, requirements and effects', async ({ page }) => {
  const api = await mockCatalog(page);
  await page.goto('/');
  await expect(page.locator('.hero-combo-count')).toContainText('12 resep Combo');
  await expect(page.locator('.combo-compact')).toContainText('Combo punya jeda');
  await page.locator('.combo-compact').scrollIntoViewIfNeeded();
  await page.screenshot({ path: 'test-results/public-combo/home-desktop.png' });
  await page.getByRole('link', { name: 'Jelajahi Combo' }).click();
  await expect(page).toHaveURL(/\/combo$/);
  await expect(page.getByRole('navigation', { name: 'Navigasi utama' }).getByRole('link', { name: 'Combo' })).toHaveAttribute('aria-current', 'page');
  await expect(page.locator('.combo-recipe')).toHaveCount(9);
  await expect(page.locator('.combo-count')).toHaveText('12 dari 12 resep aktif');
  await expect(page.locator('.combo-illustration img')).toHaveJSProperty('complete', true);
  expect(await page.locator('.combo-illustration img').evaluate(img => img.naturalWidth)).toBeGreaterThan(100);
  const recipe = page.locator('.combo-recipe').filter({ hasText: 'Pilot Thunder' });
  await recipe.locator('summary').click();
  await expect(recipe).toContainText('COB_008 · Coby Piloting');
  await expect(recipe).not.toContainText('STUDIO_');
  await expect(recipe).toContainText('tag “TEAM”');
  await expect(recipe).toContainText('Tembus 25% DEF');
  await expect(recipe).toContainText('+12 HP tiap peserta');
  await expect(recipe).toContainText('Shield 8 untuk kartu utama');
  await expect(recipe).toContainText('Stun → target lawan');
  await expect(recipe).toContainText('bukan HP pemain');
  await expect(recipe).toContainText('ATK utama × 1 + ATK pendamping 1 × 0,7 + 8');
  await expect(page.locator('.combo-generic')).toContainText('dua kartu pilihanmu tidak cocok dengan resep khusus');
  await expect(page.locator('.combo-rhythm li')).toHaveCount(3);
  await expect(page.locator('.combo-rules')).toContainText('Kartu Fusion tidak ikut Combo');
  await expect(page.locator('.combo-catalog')).not.toContainText('DISABLED RECIPE');
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: 'test-results/public-combo/catalog-desktop.png', fullPage: true });
  expect(api.requests.filter(r => r.resource === 'tcg_combo_rule_catalog').every(r => r.method === 'GET' && r.url.searchParams.get('enabled') === 'eq.true')).toBe(true);
  expect(api.requests.some(r => ['game_cards', 'battle_sessions', 'submit_battle_action', 'save_combo_recipe'].includes(r.resource))).toBe(false);
});

test('mode filters, published card search and pagination reset correctly', async ({ page }) => {
  await mockCatalog(page);
  await page.goto('/combo');
  const pagination = page.getByRole('navigation', { name: 'Halaman resep Combo' });
  await expect(pagination).toContainText('Halaman 1 dari 2');
  await pagination.getByRole('button', { name: /Berikutnya/ }).click();
  await expect(page.locator('.combo-recipe')).toHaveCount(3);
  await page.getByRole('button', { name: 'Triple · 3 kartu', exact: true }).click();
  await expect(page.locator('.combo-recipe')).toHaveCount(1);
  await expect(page.locator('.combo-recipe')).toContainText('Chaos Storm');
  await expect(pagination).toHaveCount(0);
  await page.getByRole('button', { name: 'Formation · 4 kartu', exact: true }).click();
  await expect(page.locator('.combo-recipe')).toContainText('Guardian Formation');
  await expect(page.locator('.combo-partner')).toHaveCount(4);
  await page.getByRole('button', { name: 'Semua resep', exact: true }).click();
  await page.getByRole('searchbox', { name: 'Cari resep' }).fill('Coby Piloting');
  await expect(page.locator('.combo-recipe')).toHaveCount(1);
  await expect(page.locator('.combo-recipe')).toContainText('Pilot Thunder');
  await page.getByRole('searchbox').fill('TEAM');
  await expect(page.locator('.combo-recipe')).toHaveCount(1);
  await page.getByRole('searchbox').fill('COB-008');
  await expect(page.locator('.combo-recipe')).toHaveCount(1);
  await page.getByRole('searchbox').fill('Tidak ada resep ini');
  await expect(page.locator('.combo-recipe')).toHaveCount(0);
  await page.getByRole('button', { name: 'Tampilkan semua resep' }).click();
  await expect(pagination).toContainText('Halaman 1 dari 2');
});

test('failed refresh clears stale recipes; retry and revocation keep unpublished cards private', async ({ page }) => {
  const api = await mockCatalog(page);
  await page.goto('/combo');
  await expect(page.locator('.combo-recipe')).toHaveCount(9);
  api.offline = true;
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.getByRole('alert')).toContainText('Resep Combo belum dapat dimuat');
  await expect(page.locator('.combo-recipe')).toHaveCount(0);
  api.offline = false;
  await page.getByRole('button', { name: 'Muat ulang Combo' }).click();
  await expect(page.locator('.combo-recipe')).toHaveCount(9);
  api.published = false;
  api.rows = [recipes[0]];
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.locator('.combo-recipe')).toHaveCount(1);
  await page.locator('.combo-recipe summary').click();
  await expect(page.locator('.combo-recipe')).not.toContainText('Coby Piloting');
  await expect(page.locator('.combo-partner img')).toHaveCount(0);
  api.rows = [];
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.getByText('Resep sedang disiapkan.')).toBeVisible();
  await expect(page.locator('.combo-recipe')).toHaveCount(0);
  await expect(page.locator('.combo-generic')).toBeVisible();
  expect(api.requests.some(r => r.resource === 'game_cards')).toBe(false);
});

test('late refresh cannot restore recipes after a newer revocation', async ({ page }) => {
  const api = await mockCatalog(page);
  await page.goto('/combo');
  await expect(page.locator('.combo-recipe')).toHaveCount(9);
  api.holdNext = true;
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect.poll(() => Boolean(api.held)).toBe(true);
  api.rows = [];
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(page.getByText('Resep sedang disiapkan.')).toBeVisible();
  await api.held.fulfill({ json: recipes });
  await page.waitForLoadState('networkidle');
  await expect(page.locator('.combo-recipe')).toHaveCount(0);
});

test('mobile navigation, Formation requirements and keyboard details remain usable', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockCatalog(page);
  await page.goto('/');
  const nav = page.getByRole('navigation', { name: 'Navigasi utama' });
  await expect(nav.getByRole('link')).toHaveCount(5);
  for (const link of await nav.getByRole('link').all()) await expect(link).toBeInViewport();
  await expect(page.locator('.hero-combo-count')).toContainText('12 resep Combo');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  const counts = await page.locator('.hero-counts').boundingBox();
  const scene = await page.locator('.hero-scene').boundingBox();
  expect(scene.y).toBeGreaterThan(counts.y + counts.height);
  await page.screenshot({ path: 'test-results/public-combo/home-mobile.png' });
  await nav.getByRole('link', { name: 'Combo', exact: true }).click();
  await page.getByRole('button', { name: 'Formation · 4 kartu', exact: true }).click();
  const summary = page.locator('.combo-recipe summary');
  await summary.focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('.combo-recipe details')).toHaveAttribute('open', '');
  await expect(page.locator('.combo-recipe-detail ol li')).toHaveCount(4);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  const offscreen = await page.locator('.combo-catalog :is(button,input,summary)').evaluateAll(items => items.filter(item => {
    const rect = item.getBoundingClientRect();
    return rect.width > 0 && (rect.left < 0 || rect.right > innerWidth);
  }).length);
  expect(offscreen).toBe(0);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: 'test-results/public-combo/catalog-mobile.png', fullPage: true });
});
