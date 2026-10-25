import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';

const config = ['.env', '.env.local'].map(path => {
  try { return readFileSync(path, 'utf8'); } catch { return ''; }
}).join('\n');
const endpoint = config.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)[1];

async function mockCatalog(page, cards = []) {
  const requests = [];
  await page.route(`${endpoint}/**`, route => {
    const url = new URL(route.request().url());
    requests.push(url.pathname);
    return route.fulfill({ json: url.pathname.endsWith('/get_landing_cards') ? cards : [] });
  });
  return requests;
}

test('Home caps all catalog groups at eight and keeps the complete paginated catalog', async ({ page }) => {
  const cards = Array.from({ length: 25 }, (_, index) => ({
    id: `public-${index}`, card_code: `GUIDE-${index}`, name: `Kartu pilihan ${index + 1}`,
    landing_group: index < 5 ? 'Tim pertama' : index < 12 ? 'Tim kedua' : 'Tim ketiga',
    element: 'Forest', rarity: 'Common', hp: 110, attack: 29, defense: 10, skills: [],
  }));
  const requests = await mockCatalog(page, cards);
  await page.goto('/');
  await expect(page.locator('.featured-card')).toHaveCount(8);
  await expect(page.locator('.featured-group')).toHaveCount(2);
  await expect(page.locator('.featured-limit-note')).toContainText('8 kartu pilihan');
  await expect(page.locator('.featured-section')).not.toContainText('Kartu pilihan 9');
  await page.getByRole('link', { name: 'Jelajahi katalog' }).click();
  await expect(page.locator('.unit-card')).toHaveCount(12);
  const pagination = page.locator('.catalog-pagination');
  await expect(pagination).toContainText('Halaman 1 dari 3');
  await pagination.getByRole('button', { name: /Berikutnya/ }).click();
  await expect(pagination).toContainText('Halaman 2 dari 3');
  await pagination.getByRole('button', { name: /Berikutnya/ }).click();
  await expect(page.locator('.unit-card')).toHaveCount(1);
  expect(requests.some(path => path.endsWith('/game_cards'))).toBe(false);
});

test('interactive Player/Public guide, action explanations and AP example work without battle writes', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const requests = await mockCatalog(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Panduan bermain' }).click();
  const guide = page.locator('#panduan');
  await expect(guide.getByRole('heading', { name: /Kenali layar/ })).toBeInViewport();
  await expect(guide.locator('.guide-pin')).toHaveCount(7);
  await expect(guide.locator('.guide-explanation h3')).toHaveText('HP pemain, giliran, AP, dan timer');
  await expect(guide.locator('.guide-step-buttons button').first()).toBeDisabled();
  await guide.locator('.guide-pin').nth(2).click();
  await expect(guide.locator('.guide-explanation h3')).toContainText('Bench');
  await guide.locator('.guide-step-buttons button').last().click();
  await expect(guide.locator('.guide-explanation h3')).toContainText('Graveyard');
  await guide.locator('.guide-menu-list button').last().click();
  await expect(guide.locator('.guide-step-buttons button').last()).toBeDisabled();
  await expect(guide.locator('.guide-image img')).toHaveJSProperty('naturalWidth', 1600);
  await guide.locator('.guide-tour-tabs').scrollIntoViewIfNeeded();
  await page.screenshot({ path: 'test-results/home-guide-desktop.png', fullPage: false });

  const publicTab = guide.getByRole('tab', { name: /Public Battle/ });
  await publicTab.click();
  await expect(publicTab).toHaveAttribute('aria-selected', 'true');
  await expect(guide.locator('.guide-image img')).toHaveAttribute('src', '/images/tutorial/public-battle-guide.jpg');
  await guide.locator('.guide-pin').nth(4).click();
  await expect(guide.locator('.guide-explanation h3')).toBeVisible();
  await expect(guide.locator('.guide-explanation h3')).toContainText('Bench, deck, dan Graveyard');
  await expect(guide.locator('.guide-image img')).toHaveJSProperty('naturalWidth', 1600);
  await guide.locator('.guide-tour-tabs').scrollIntoViewIfNeeded();
  await page.screenshot({ path: 'test-results/home-public-guide.png', fullPage: false });
  await publicTab.focus();
  await page.keyboard.press('ArrowLeft');
  const playerTab = guide.getByRole('tab', { name: /Player Battle/ });
  await expect(playerTab).toBeFocused();
  await expect(playerTab).toHaveAttribute('aria-selected', 'true');
  await page.keyboard.press('End');
  await expect(publicTab).toBeFocused();
  await page.keyboard.press('Home');
  await expect(playerTab).toBeFocused();

  await guide.locator('.guide-action-list').getByRole('button', { name: 'Fusion', exact: true }).click();
  await expect(guide.locator('.guide-action-detail')).toContainText('ONE OF');
  await expect(guide.locator('.guide-action-detail')).toContainText('Material dikonsumsi');
  await guide.locator('.guide-action-list').getByRole('button', { name: 'Skill kartu', exact: true }).click();
  await expect(guide.locator('.guide-action-detail')).toContainText('dua giliranmu berikutnya');
  await guide.locator('.guide-action-list').getByRole('button', { name: 'Akhiri giliran', exact: true }).click();
  await expect(guide.locator('.guide-action-detail')).toContainText('Sisa AP tidak disimpan');
  await guide.locator('.guide-example-steps').getByRole('button', { name: /Ke Bench/ }).click();
  await expect(guide.locator('.guide-ap-readout strong')).toHaveText('0');
  await guide.locator('.guide-example-steps').getByRole('button', { name: /Mulai/ }).click();
  await expect(guide.locator('.guide-ap-readout strong')).toHaveText('3');
  const rules = guide.locator('.guide-rules details').first();
  await rules.locator('summary').click();
  await expect(rules).toHaveAttribute('open', '');
  await expect(rules.locator('p')).toContainText('HP pemain lawan sampai 0');
  await expect(guide).not.toContainText('Slot GIF');
  expect(new URL(page.url()).pathname).toBe('/');
  expect(requests.some(path => /submit_battle|battle_sessions|battle_cards/.test(path))).toBe(false);
  expect(errors).toEqual([]);
});

test('mobile guide keeps every menu available without horizontal overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockCatalog(page);
  await page.goto('/');
  await page.getByRole('button', { name: 'Panduan bermain' }).click();
  const guide = page.locator('#panduan');
  await guide.getByRole('tab', { name: /Public Battle/ }).click();
  await guide.locator('.guide-menu-list button').nth(4).click();
  await expect(guide.locator('.guide-explanation h3')).toContainText('Bench');
  await expect(guide.locator('.guide-explanation h3')).toBeInViewport();
  await expect(guide.locator('.guide-menu-list button')).toHaveCount(7);
  await expect(guide.locator('.guide-image img')).toHaveJSProperty('naturalWidth', 1600);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  const offscreenButtons = await guide.locator('button').evaluateAll(buttons => buttons.filter(button => {
    const rect = button.getBoundingClientRect();
    return rect.width > 0 && (rect.left < 0 || rect.right > window.innerWidth);
  }).length);
  expect(offscreenButtons).toBe(0);
  await guide.locator('.guide-tour-tabs').scrollIntoViewIfNeeded();
  await page.screenshot({ path: 'test-results/home-guide-mobile.png', fullPage: false });
});
