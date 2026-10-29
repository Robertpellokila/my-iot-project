import { test, expect } from '@playwright/test';
import { mockGameSetup } from '../fixtures/mockGameSetup.js';
import { battleEndpoint } from '../fixtures/mockPlayerBattle.js';

async function historyFixture(page, count = 26) {
  await mockGameSetup(page);
  await page.routeWebSocket('**', socket => socket.close());
  let rows = Array.from({ length: count }, (_, i) => ({
    id: `50000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
    code: `PILOT${String(i).padStart(2, '0')}`, player1_name: i === 6 ? 'Nadia' : 'Alya', player2_name: 'Raka',
    status: i === 0 ? 'battle' : 'finished', is_active: i === 0, can_delete: i !== 0,
    winner: i === 0 ? null : i % 3 === 0 ? 'draw' : i % 2 ? 'p1' : 'p2',
    round: i === 0 ? 3 : 10, total_rounds: 10, active_until: '2099-01-01T00:00:00Z',
    created_at: '2026-01-04T09:00:00Z', question_enabled: true,
  }));
  const calls = [], deletions = [];
  const state = { failRead: false, rejectDelete: false, delaySearch: false };
  await page.route(`${battleEndpoint}/rest/v1/**`, async route => {
    const req = route.request(), resource = new URL(req.url()).pathname.split('/').at(-1);
    if (resource === 'profiles') return route.fallback();
    if (resource === 'admin_battle_history') {
      const body = req.postDataJSON(); calls.push(body);
      if (state.failRead) return route.fulfill({ status: 500, json: { message: 'Koneksi pengujian terputus.' } });
      const filtered = rows.filter(b => (body.p_status === 'all' || b.status === body.p_status)
        && (body.p_access === 'all' || (body.p_access === 'inactive' ? b.can_delete : !b.can_delete))
        && `${b.code} ${b.player1_name} ${b.player2_name}`.toLowerCase().includes(body.p_search.toLowerCase()));
      const p = Math.min(body.p_page, Math.max(1, Math.ceil(filtered.length / body.p_page_size)));
      const result = { rows: filtered.slice((p - 1) * body.p_page_size, p * body.p_page_size), page: p, total: filtered.length,
        page_size: body.p_page_size, summary: { total: rows.length, active: rows.filter(b => !b.can_delete).length, finished: rows.filter(b => b.status === 'finished').length, deletable: rows.filter(b => b.can_delete).length } };
      if (state.delaySearch && body.p_search === 'Alya') await new Promise(r => setTimeout(r, 900));
      return route.fulfill({ json: result });
    }
    if (resource === 'admin_battle_history_cleanup') return route.fulfill({ json: { rows: rows.filter(b => b.can_delete).slice(0, 100), total: rows.filter(b => b.can_delete).length } });
    if (resource === 'admin_delete_battle_history') {
      const body = req.postDataJSON(); deletions.push(body);
      if (state.rejectDelete) return route.fulfill({ status: 400, json: { message: 'Battle kembali aktif. Muat ulang dan pilih kembali.' } });
      const before = rows.length; rows = rows.filter(b => !body.p_ids.includes(b.id));
      return route.fulfill({ json: { deleted: before - rows.length } });
    }
    if (resource === 'battle_sessions') throw new Error('History must use bounded server pagination, not SELECT all sessions');
    return route.fulfill({ json: [] });
  });
  await page.goto('/admin/battle-history');
  return { calls, deletions, state, get rows() { return rows; } };
}

test('history paginates at the server, searches all pages and resets filters/page size', async ({ page }) => {
  const mock = await historyFixture(page);
  const table = page.locator('.history-table tbody tr');
  await expect(table).toHaveCount(10);
  await expect(page.locator('.history-pagination')).toContainText('1–10 dari 26');
  await page.getByRole('button', { name: 'Berikutnya →' }).click();
  await expect(table.first()).toHaveAttribute('data-battle-code', 'PILOT10');
  expect(mock.calls.at(-1)).toMatchObject({ p_page: 2, p_page_size: 10 });
  await page.getByLabel('Cari pertandingan', { exact: true }).fill('PILOT25');
  await expect(table).toHaveCount(1);
  await expect(table.first()).toHaveAttribute('data-battle-code', 'PILOT25');
  expect(mock.calls.at(-1)).toMatchObject({ p_search: 'PILOT25', p_page: 1 });
  await page.getByRole('button', { name: 'Reset filter' }).click();
  await expect(table).toHaveCount(10);
  await page.getByLabel('Status pertandingan', { exact: true }).selectOption('finished');
  await expect(page.locator('.history-pagination')).toContainText('dari 25');
  await page.getByLabel('Per halaman', { exact: true }).selectOption('25');
  await expect(table).toHaveCount(25);
  await expect(page.getByRole('button', { name: 'Berikutnya →' })).toBeDisabled();
  await page.getByLabel('Per halaman', { exact: true }).selectOption('10');
  await expect(table).toHaveCount(10);
  await page.getByRole('button', { name: 'Reset filter' }).click();
  await expect(table.first()).toHaveAttribute('data-battle-code', 'PILOT00');
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({ path: 'test-results/history-desktop.png', fullPage: true });
});

test('active matches cannot be selected; row and batch deletion require review and acknowledgment', async ({ page }) => {
  const mock = await historyFixture(page);
  await expect(page.getByLabel('Pilih battle PILOT00', { exact: true })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Hapus battle PILOT00', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Hapus battle PILOT01', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Hapus riwayat battle?' });
  await expect(dialog).toContainText('PILOT01');
  await expect(dialog.getByRole('button', { name: 'Hapus 1 pertandingan' })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(dialog).not.toBeVisible(); expect(mock.deletions).toHaveLength(0);
  await page.getByLabel('Pilih semua yang bisa dihapus di halaman ini').check();
  await expect(page.getByRole('button', { name: 'Hapus pilihan (9)' })).toBeVisible();
  await page.getByRole('button', { name: 'Hapus pilihan (9)' }).click();
  await expect(dialog.locator('.delete-preview li')).toHaveCount(9);
  await expect(dialog).not.toContainText('PILOT00');
  await dialog.getByRole('checkbox').check();
  await dialog.getByRole('button', { name: 'Hapus 9 pertandingan' }).click();
  await expect(dialog).not.toBeVisible();
  await expect(page.locator('.history-pagination')).toContainText('dari 17');
  expect(mock.deletions).toHaveLength(1); expect(mock.deletions[0].p_ids).toHaveLength(9);
  expect(mock.rows.some(b => b.code === 'PILOT00')).toBe(true);
});

test('cleanup previews a bounded batch, rejects stale active matches and recovers from read errors', async ({ page }) => {
  const mock = await historyFixture(page, 106);
  await page.getByRole('button', { name: 'Bersihkan riwayat' }).click();
  const dialog = page.getByRole('dialog', { name: 'Bersihkan riwayat lama' });
  await expect(dialog.locator('.delete-preview li')).toHaveCount(100);
  await expect(dialog).toContainText('Ada 105 yang memenuhi syarat');
  await expect(dialog).toContainText('Kartu di Album, UID, desain, dan aturan skill tetap tersimpan');
  await dialog.getByRole('checkbox').check();
  await dialog.getByLabel('Waktu dibuat').selectOption('all');
  await expect(dialog.getByRole('checkbox')).not.toBeChecked();
  await dialog.getByRole('checkbox').check(); mock.state.rejectDelete = true;
  await dialog.getByRole('button', { name: 'Hapus 100 pertandingan' }).click();
  await expect(dialog.getByRole('alert')).toContainText('Battle kembali aktif');
  await expect(dialog).toBeVisible(); expect(mock.rows).toHaveLength(106);
  await expect(dialog.getByRole('checkbox')).not.toBeChecked();
  await dialog.getByRole('button', { name: 'Batal', exact: true }).click();
  mock.state.failRead = true;
  await page.getByRole('button', { name: '↻ Muat ulang' }).click();
  await expect(page.locator('.history-workspace').getByRole('alert')).toContainText('Koneksi pengujian terputus');
  mock.state.failRead = false;
  await page.getByRole('button', { name: 'Coba lagi', exact: true }).click();
  await expect(page.locator('.history-workspace').getByRole('alert')).toHaveCount(0);
});

test('phone history has readable rows and cleanup confirmation without overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await historyFixture(page, 3);
  await expect(page.locator('.history-table tbody tr')).toHaveCount(3);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/history-mobile.png', fullPage: true });
  await page.getByRole('button', { name: 'Bersihkan riwayat' }).click();
  const dialog = page.getByRole('dialog', { name: 'Bersihkan riwayat lama' });
  await expect(dialog.locator('.delete-preview li')).toHaveCount(2);
  expect(await dialog.evaluate(el => el.scrollWidth <= el.clientWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/history-cleanup-mobile.png', fullPage: false });
});

test('empty history and zero search results offer the appropriate next step', async ({ page }) => {
  await historyFixture(page, 0);
  await expect(page.getByRole('heading', { name: 'Belum ada riwayat battle' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Buat battle pertama' })).toBeVisible();
  await page.getByLabel('Cari pertandingan', { exact: true }).fill('nobody');
  await expect(page.getByRole('heading', { name: 'Tidak ada pertandingan yang cocok' })).toBeVisible();
  await page.getByRole('button', { name: 'Bersihkan riwayat' }).click();
  const dialog = page.getByRole('dialog', { name: 'Bersihkan riwayat lama' });
  await expect(dialog).toContainText('Tidak ada riwayat yang memenuhi pilihan ini');
  await expect(dialog.getByRole('button', { name: 'Hapus 0 pertandingan' })).toBeDisabled();
});

test('a slower earlier search cannot replace newer results', async ({ page }) => {
  const mock = await historyFixture(page);
  await expect(page.locator('.history-table tbody tr')).toHaveCount(10);
  mock.state.delaySearch = true;
  await page.getByLabel('Cari pertandingan', { exact: true }).fill('Alya');
  await expect.poll(() => mock.calls.at(-1)?.p_search).toBe('Alya');
  await page.getByLabel('Cari pertandingan', { exact: true }).fill('Nadia');
  await expect(page.locator('.history-table tbody tr')).toHaveCount(1);
  await expect(page.locator('.history-table tbody')).toContainText('Nadia');
  await page.waitForTimeout(1000);
  await expect(page.locator('.history-table tbody tr')).toHaveCount(1);
  await expect(page.locator('.history-pagination')).toContainText('dari 1 pertandingan');
});
