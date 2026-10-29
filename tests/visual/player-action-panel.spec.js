import { test, expect } from '@playwright/test';
import { mockPlayerBattle } from '../fixtures/mockPlayerBattle.js';

const pageErrors=new WeakMap();
test.beforeEach(({page})=>{const errors=[];pageErrors.set(page,errors);page.on('pageerror',error=>errors.push(error.message));});
test.afterEach(({page})=>expect(pageErrors.get(page)).toEqual([]));

const panel = page => page.locator('.player-action-panel');
const primary = (page, action) => panel(page).locator(`[data-action="${action}"]`);
const selectSource = async page => { await page.locator('.cyber-card').first().click(); await expect(panel(page).locator('.command-card strong')).toHaveText('Coby'); };

test('pilot commitment disables retreat and offense while utility remains usable', async ({ page }) => {
  const mock = await mockPlayerBattle(page, { player1_skill: 100 });
  mock.source.battle_metadata = { pilot_offense_owner_turn: mock.battle.player1_owner_turn, pilot_attack_owner_turn: mock.battle.player1_owner_turn };
  await mock.open(); await selectSource(page);
  const retreat = page.locator('.active-panel .cyber-card').first().locator('.card-zone-action');
  await expect(retreat).toBeDisabled();await expect(retreat).toContainText('Tunggu giliranmu berikutnya');
  await expect(primary(page, 'attack')).toBeDisabled();
  await expect(primary(page, 'special')).toBeEnabled();
  await panel(page).getByRole('button', { name: /Aksi lainnya/ }).click();
  const drawer = page.getByRole('dialog', { name: 'Aksi lainnya', exact: true });
  await expect(drawer.locator('[data-action="ultimate"]')).toBeDisabled();
  await expect(drawer.locator('[data-action="ultimate"]')).toContainText('berbagi 1 kesempatan');
  await drawer.locator('summary').click();
  await expect(drawer.locator('.command-pilot-rules')).toContainText('Semua peserta Combo memakai jatahnya');
  await page.keyboard.press('Escape');
  mock.battle.player1_owner_turn++;mock.battle.turn_index += 2;mock.source.attack_turn_index = mock.battle.turn_index - 2;
  mock.patch({ current_turn: 'p1' });mock.refreshCards();
  await expect(retreat).toBeEnabled();await expect(primary(page, 'attack')).toBeEnabled();
  expect(mock.submissions).toHaveLength(0);
});

test('new Fusion exposes its wait rule and still offers a healing skill', async ({ page }) => {
  const mock = await mockPlayerBattle(page, { player1_skill: 100 });
  mock.source.card_kind = 'fusion';mock.source.battle_metadata = { pilot_fusion_owner_turn: mock.battle.player1_owner_turn };
  await mock.open();await selectSource(page);
  await expect(primary(page, 'attack')).toBeDisabled();
  await panel(page).getByRole('button', { name: 'Mengapa Serang belum tersedia?' }).click();
  await expect(page.getByRole('dialog', { name: 'Serang', exact: true })).toContainText('Fusion baru');
  await page.keyboard.press('Escape');
  await primary(page, 'special').click();
  const dialog = page.getByRole('dialog', { name: 'Coby', exact: true });
  await expect(dialog.locator('.special-skill-tab').first()).toContainText('Fusion baru');
  await dialog.locator('.special-skill-tab').nth(1).click();
  await dialog.locator('.special-target-card').first().click();
  await expect(dialog.getByRole('button', { name: 'Gunakan Team Spirit' })).toBeEnabled();
  expect(mock.submissions).toHaveLength(0);
});

test('Bench explains the Fusion cap and consumed materials never advertise Necro readiness', async ({ page }) => {
  const mock = await mockPlayerBattle(page);
  mock.source.card_kind = 'fusion';
  const bench = mock.cards.find(c => c.zone === 'bench' && c.player === 'p1');
  bench.card_kind = 'fusion';bench.bench_return_count = 2;
  const dead = mock.cards.find(c => c.zone === 'graveyard' && c.player === 'p1');
  dead.fusion_consumed = true;dead.field_fusion_used = true;
  await mock.open();
  await page.locator('.bench-side-zone').click();
  await expect(page.locator('.pile-viewer-panel .bench-action-button')).toBeDisabled();
  await expect(page.locator('.pile-viewer-panel')).toContainText('Maksimal 1 kartu Fusion');
  await expect(page.locator('.pile-viewer-panel')).not.toContainText('RETURN 2 / 1');
  await page.keyboard.press('Escape');await page.locator('.graveyard-side-zone').click();
  await expect(page.locator('.pile-viewer-panel')).toContainText('Bahan Fusion • tidak bisa dibangkitkan');
  await expect(page.locator('.pile-viewer-panel')).not.toContainText('NECRO READY');
});

test('main commands show selected card, AP and explanations instead of a wall of buttons', async ({ page }) => {
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  const mock=await mockPlayerBattle(page);await mock.open();
  await expect(panel(page).locator('.command-primary .command-button')).toHaveCount(4);
  await expect(panel(page).locator('.command-card strong')).toHaveText('Pilih kartu Active');
  await expect(primary(page,'attack')).toBeDisabled();await panel(page).getByRole('button',{name:'Mengapa Serang belum tersedia?'}).click();
  await expect(page.getByRole('dialog',{name:'Serang',exact:true})).toContainText('Pilih kartu Active terlebih dahulu');
  await page.keyboard.press('Escape');
  await selectSource(page);
  await expect(panel(page).locator('.command-ap')).toContainText('3 / 3 AP');
  await expect(primary(page,'special')).toContainText('2 skill');
  await expect(page.locator('.skill-info-panel,.skill-ready-balloons,.selected-card-chip')).toHaveCount(0);
  expect(mock.submissions).toHaveLength(0);expect(errors).toEqual([]);
});

test('targeted attack previews configured AP, cancels without sending, and sends only one confirmed request', async ({ page }) => {
  const mock=await mockPlayerBattle(page,{action_costs:{attack:2}});await mock.open();await selectSource(page);
  await primary(page,'attack').click();
  const dialog=page.getByRole('dialog',{name:'Pilih kartu lawan'});
  await expect(dialog.getByRole('button',{name:'Konfirmasi serangan'})).toBeDisabled();
  await dialog.locator('.target-card').first().click();
  await expect(dialog.locator('.battle-action-receipt')).toContainText('Biaya 2 AP · sisa 1 AP');
  await dialog.getByRole('button',{name:'Batal',exact:true}).click();expect(mock.submissions).toHaveLength(0);
  await primary(page,'attack').click();await dialog.locator('.target-card').first().click();
  mock.setDelay(450);
  await dialog.getByRole('button',{name:'Konfirmasi serangan'}).evaluate(button=>{button.click();button.click();});
  await expect.poll(()=>mock.submissions.length).toBe(1);
  expect(mock.submissions[0]).toMatchObject({p_action:'attack',p_card_id:mock.source.id,p_payload:{target_card_id:mock.target.id}});
  await expect(dialog).toHaveCount(0);
  await expect(panel(page).locator('.command-ap')).toContainText('1 / 3 AP');
});

test('both named skills show images, independent cooldown and AP with target review', async ({ page }) => {
  const mock=await mockPlayerBattle(page);mock.skills[0].cooldown_until_owner_turn=4;
  await mock.open();await selectSource(page);await expect(primary(page,'special')).toContainText('2 skill');await primary(page,'special').click();
  const dialog=page.getByRole('dialog',{name:'Coby',exact:true});
  await expect(dialog.locator('.special-skill-tab')).toHaveCount(2);
  await expect(dialog.locator('.special-skill-tab').first()).toContainText('Tersedia setelah 2 giliranmu');
  await expect(dialog.locator('.special-skill-tab img')).toHaveAttribute('src','/images/tutorial/player-battle-guide.jpg');
  await dialog.locator('.special-skill-tab').first().click();
  await expect(dialog.getByRole('button',{name:'Gunakan Arc Rally'})).toBeDisabled();
  await dialog.locator('.special-skill-tab').nth(1).click();
  await expect(dialog.getByRole('button',{name:'Gunakan Team Spirit'})).toBeDisabled();
  await dialog.locator('.special-target-card').first().click();
  await expect(dialog.locator('.battle-action-receipt')).toContainText('Biaya 2 AP · sisa 1 AP');
  await dialog.getByRole('button',{name:'Gunakan Team Spirit'}).click();
  await expect.poll(()=>mock.submissions.length).toBe(1);
  expect(mock.submissions[0]).toMatchObject({p_action:'special_skill',p_card_id:mock.source.id,p_payload:{skill_id:mock.skills[1].id,target_card_id:mock.source.id}});
  expect(mock.submissions[0].p_payload.action_id).toBeTruthy();
  await expect(dialog).toHaveCount(0);await expect(panel(page).locator('.command-ap')).toContainText('1 / 3 AP');
});

test('extra actions explain locks; Combo and Fusion reuse their existing preview pickers', async ({ page }) => {
  const mock=await mockPlayerBattle(page);await mock.open();await selectSource(page);
  await panel(page).getByRole('button',{name:/Aksi lainnya/}).click();
  const drawer=page.getByRole('dialog',{name:'Aksi lainnya',exact:true});
  await expect(drawer.locator('[data-action="ultimate"]')).toContainText('Gauge Ultimate 40%; perlu 100%.');
  await expect(drawer.locator('[data-action="ultimate"]')).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(panel(page).getByRole('button',{name:/Aksi lainnya/})).toBeFocused();
  await panel(page).getByRole('button',{name:/Aksi lainnya/}).click();await drawer.locator('[data-action="combo"]').click();
  await expect(page.getByRole('dialog',{name:'Pilih kartu Active untuk Combo'})).toBeVisible();
  await expect(page.locator('.combo-attack-modal .battle-action-receipt')).toContainText('Biaya 2 AP');
  await page.keyboard.press('Escape');
  await panel(page).getByRole('button',{name:/Aksi lainnya/}).click();await expect(drawer.locator('[data-action="fusion"]')).toBeDisabled();
  await expect(drawer.locator('[data-action="fusion"]')).toContainText('Material Fusion belum lengkap');
  await page.keyboard.press('Escape');expect(mock.submissions).toHaveLength(0);
});

test('end turn requires confirmation and stale dialogs close on a realtime turn change', async ({ page }) => {
  const mock=await mockPlayerBattle(page);await mock.open();
  await primary(page,'end_turn').click();
  const dialog=page.getByRole('dialog',{name:'Akhiri giliranmu?'});
  await expect(dialog).toContainText('Masih ada 3 AP');
  await dialog.getByRole('button',{name:'Batal',exact:true}).click();expect(mock.submissions).toHaveLength(0);
  await primary(page,'end_turn').click();
  mock.patch({current_turn:'p2',turn_index:6});
  await expect(dialog).not.toBeVisible();
  await expect(panel(page)).toContainText('Giliran lawan');
  expect(mock.submissions).toHaveLength(0);
  mock.patch({current_turn:'p1',turn_index:7});
  await expect(primary(page,'end_turn')).toHaveAttribute('aria-disabled','false');
  await primary(page,'end_turn').click();await dialog.getByRole('button',{name:'Ya, akhiri giliran'}).click();
  await expect.poll(()=>mock.submissions.length).toBe(1);expect(mock.submissions[0].p_action).toBe('end_turn');
  await expect(panel(page)).toContainText('Giliran lawan');
});

test('RFID scanning, insufficient AP and quiz interruptions cannot send another action', async ({ page }) => {
  const mock=await mockPlayerBattle(page,{player1_action_points:1});await mock.open();await selectSource(page);
  await panel(page).getByRole('button',{name:/Aksi lainnya/}).click();
  await expect(page.getByRole('dialog',{name:'Aksi lainnya'}).locator('[data-action="combo"]')).toContainText('Butuh 2 AP');
  await page.keyboard.press('Escape');
  await primary(page,'summon').click();
  await expect(panel(page).locator('.command-scan')).toContainText('Tempelkan kartu');
  await expect(panel(page).locator('.command-primary')).toHaveCount(0);
  expect(mock.submissions).toHaveLength(1);
  mock.patch({pending_action:null,pending_action_player:null,player1_action_points:3});
  await expect(primary(page,'end_turn')).toBeVisible();await primary(page,'end_turn').click();
  mock.patch({status:'question',question_active:true});
  await expect(page.locator('.command-review-dialog')).toHaveCount(0);
  await expect(panel(page)).toHaveCount(0);expect(mock.submissions).toHaveLength(1);
});

test('direct attacks and Classic attacks are reviewed, not immediately executed', async ({ page }) => {
  const mock=await mockPlayerBattle(page);mock.cards.splice(mock.cards.indexOf(mock.target),1);
  await mock.open();await selectSource(page);await primary(page,'attack').click();
  const dialog=page.getByRole('dialog',{name:'Serangan langsung?'});
  await expect(dialog).toContainText('mengenai HP pemain');expect(mock.submissions).toHaveLength(0);
  await dialog.getByRole('button',{name:'Batal',exact:true}).click();
  mock.patch({ruleset:'classic',action_points_enabled:false});
  await expect(panel(page).locator('.command-ap')).toHaveCount(0);await expect(primary(page,'end_turn')).toHaveCount(0);
  await primary(page,'attack').click();await expect(page.getByRole('dialog',{name:'Serang?',exact:true})).toBeVisible();
  await page.getByRole('dialog',{name:'Serang?',exact:true}).getByRole('button',{name:'Konfirmasi aksi'}).click();
  await expect.poll(()=>mock.submissions.length).toBe(1);expect(mock.submissions[0].p_action).toBe('attack');
});

test('rejected attacks retain the chosen target for a deliberate retry', async ({ page }) => {
  const mock=await mockPlayerBattle(page);await mock.open();await selectSource(page);await primary(page,'attack').click();
  const dialog=page.getByRole('dialog',{name:'Pilih kartu lawan'});
  await dialog.locator('.target-card').first().click();mock.rejectNext();
  await dialog.getByRole('button',{name:'Konfirmasi serangan'}).click();
  await expect(page.getByText('Kondisi kartu berubah. Periksa target dan coba lagi.',{exact:true})).toBeVisible();
  await expect(dialog).toBeVisible();expect(mock.battle.player1_action_points).toBe(3);
  await dialog.getByRole('button',{name:'Konfirmasi serangan'}).click();
  await expect(dialog).toHaveCount(0);expect(mock.submissions).toHaveLength(2);
});

test('mobile commands stay compact with readable skill choices and keyboard dismissal', async ({ page }) => {
  await page.setViewportSize({width:390,height:844});
  const mock=await mockPlayerBattle(page);await mock.open();await selectSource(page);
  await expect(primary(page,'special')).toContainText('2 skill');
  expect((await panel(page).boundingBox()).height).toBeLessThan(245);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({path:'test-results/player-actions-mobile.png'});
  await primary(page,'special').click();
  const dialog=page.getByRole('dialog',{name:'Coby',exact:true});
  await expect(dialog.locator('.special-skill-tab').first()).toBeInViewport();
  expect(await dialog.evaluate(node=>node.scrollWidth <= node.clientWidth+1)).toBe(true);
  await page.screenshot({path:'test-results/player-skills-mobile.png'});
  await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);
  await expect(primary(page,'special')).toBeFocused();
});

test('both cooling-down skills remain inspectable with independent reasons and no execution', async ({ page }) => {
  const mock=await mockPlayerBattle(page,{player1_action_points:0});
  mock.skills[0].cooldown_until_owner_turn=4;mock.skills[1].cooldown_until_owner_turn=3;
  await mock.open();await selectSource(page);
  await expect(primary(page,'special')).toBeDisabled();await panel(page).getByRole('button',{name:'Lihat informasi skill'}).click();
  const dialog=page.getByRole('dialog',{name:'Coby',exact:true});
  await expect(dialog.locator('.special-skill-tab').first()).toContainText('Tersedia setelah 2 giliranmu');
  await expect(dialog.locator('.special-skill-tab').nth(1)).toContainText('Tersedia setelah 1 giliranmu');
  await dialog.locator('.special-skill-tab').nth(1).click();await expect(dialog.getByRole('button',{name:'Gunakan Team Spirit'})).toBeDisabled();
  await dialog.focus();await page.keyboard.press('Shift+Tab');await expect(dialog.locator('button:not(:disabled)').last()).toBeFocused();
  await page.keyboard.press('Tab');await expect(dialog.locator('button').first()).toBeFocused();
  expect(mock.submissions).toHaveLength(0);
});

test('direct attack confirmation submits once and validates the chosen source', async ({ page }) => {
  const mock=await mockPlayerBattle(page);mock.cards.splice(mock.cards.indexOf(mock.target),1);
  await mock.open();await selectSource(page);await primary(page,'attack').click();
  const dialog=page.getByRole('dialog',{name:'Serangan langsung?'});
  mock.setDelay(350);await dialog.getByRole('button',{name:'Konfirmasi aksi'}).evaluate(button=>{button.click();button.click();});
  await expect(dialog).not.toBeVisible();
  expect(mock.submissions).toHaveLength(1);expect(mock.submissions[0]).toMatchObject({p_action:'attack',p_card_id:mock.source.id,p_payload:{}});
  await expect(panel(page).locator('.command-ap')).toContainText('2 / 3 AP');
});

test('an expired timer blocks an open attack picker before a late click can submit', async ({ page }) => {
  const mock=await mockPlayerBattle(page);await mock.open();await selectSource(page);await primary(page,'attack').click();
  const dialog=page.getByRole('dialog',{name:'Pilih kartu lawan'});await dialog.locator('.target-card').first().click();
  mock.patch({turn_deadline_at:new Date(Date.now()-1000).toISOString()});
  await expect(dialog.getByRole('button',{name:'Konfirmasi serangan'})).toBeDisabled();
  expect(mock.submissions).toHaveLength(0);
  await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);
});

for(const cost of [0,2,3]) test(`pending Summon can cancel once and refund its exact ${cost} AP debit`,async({page})=>{
  if(cost===3)await page.setViewportSize({width:390,height:844});
  const mock=await mockPlayerBattle(page,{action_costs:{summon:cost}});await mock.open();
  const beforeCards=mock.cards.length,deadline=mock.battle.turn_deadline_at;
  await primary(page,'summon').click();
  const cancel=panel(page).getByRole('button',{name:'Batal Summon',exact:true});await expect(cancel).toBeEnabled();
  await expect(cancel).toBeInViewport();
  if(cost===3){expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:'test-results/summon-cancel-mobile.png'});}
  const request=mock.battle.pending_summon_request_id;
  await expect(panel(page).locator('.command-ap')).toContainText(`${3-cost} / 3 AP`);
  mock.setDelay(350);await cancel.evaluate(button=>{button.click();button.click();});
  await expect(cancel).toHaveCount(0);await expect(primary(page,'summon')).toBeVisible();
  await expect(panel(page).locator('.command-ap')).toContainText('3 / 3 AP');
  expect(mock.cancellations).toHaveLength(1);expect(mock.cancellations[0]).toMatchObject({p_code:'GUIDEDEMO',p_player:'p1',p_token:'demo-player-one',p_request_id:request});
  expect(mock.cards).toHaveLength(beforeCards);expect(mock.battle.turn_deadline_at).toBe(deadline);expect(mock.battle.turn_index).toBe(5);
});

test('a winning RFID scan rejects cancellation and retains the card without an AP refund',async({page})=>{
  const mock=await mockPlayerBattle(page);await mock.open();await primary(page,'summon').click();
  const cancel=panel(page).getByRole('button',{name:'Batal Summon',exact:true});await expect(cancel).toBeEnabled();
  mock.setDelay(500);await cancel.click();await expect.poll(()=>mock.cancellations.length).toBe(1);
  mock.cards.push({...mock.source,id:'42000000-0000-4000-8000-000000000010',name:'Kartu baru',slot:3});
  mock.patch({pending_action:null,pending_action_player:null,pending_summon_request_id:null});mock.refreshCards();
  await expect(page.getByText('Tidak ada Summon yang menunggu. Kartu mungkin sudah terbaca.',{exact:true})).toBeVisible();
  await expect(page.locator('.cyber-card').filter({hasText:'Kartu baru'})).toHaveCount(1);await expect(panel(page).locator('.command-ap')).toContainText('2 / 3 AP');
  expect(mock.battle.player1_action_points).toBe(2);await expect(cancel).toHaveCount(0);
});

test('cancel failures preserve the pending request and allow retry after refresh',async({page})=>{
  const mock=await mockPlayerBattle(page);await mock.open();await primary(page,'summon').click();
  const cancel=panel(page).getByRole('button',{name:'Batal Summon',exact:true});await expect(cancel).toBeEnabled();
  const pattern='**/rest/v1/rpc/cancel_battle_summon';await page.route(pattern,route=>route.fulfill({status:503,json:{message:'Offline'}}));
  await cancel.click();await expect(page.getByText('PEMBATALAN GAGAL',{exact:true})).toBeVisible();await expect(cancel).toBeEnabled();
  expect(mock.battle.pending_action).toBe('summon');expect(mock.battle.player1_action_points).toBe(2);
  await page.unroute(pattern);await cancel.click();await expect(cancel).toHaveCount(0);await expect(panel(page).locator('.command-ap')).toContainText('3 / 3 AP');
});

test('pending cancellation survives page reload; unupgraded servers cannot pretend to cancel locally',async({page})=>{
  const mock=await mockPlayerBattle(page);await mock.open();await primary(page,'summon').click();
  const cancel=panel(page).getByRole('button',{name:'Batal Summon',exact:true});await expect(cancel).toBeEnabled();
  await page.reload();await expect(cancel).toBeEnabled();await cancel.click();await expect(cancel).toHaveCount(0);
  mock.battle.pending_action='summon';mock.battle.pending_action_player='p1';mock.battle.player1_action_points=2;delete mock.battle.pending_summon_request_id;
  await page.reload();await expect(cancel).toBeDisabled();await expect(panel(page)).toContainText('Pembatalan belum tersedia pada server');
  expect(mock.cancellations).toHaveLength(1);expect(mock.battle.player1_action_points).toBe(2);
});


test('ready actions use colors and a skill balloon; paused, opponent and zero AP states stay disabled',async({page})=>{
 const mock=await mockPlayerBattle(page);await mock.open();await selectSource(page);
 await expect(primary(page,'summon')).toContainText('Summon');await expect(primary(page,'summon').locator('.battle-action-artwork img')).toHaveAttribute('src','/images/battle-arena/action-atlas-v1.webp');
 await expect(primary(page,'special')).toHaveClass(/available/);await expect(panel(page).locator('.command-ready-bubble')).toContainText('skill siap!');
 await expect(primary(page,'attack').locator('.battle-action-artwork img')).toBeVisible();
 await expect(primary(page,'special').locator('.command-icon')).toHaveCSS('color','rgb(112, 70, 188)');
 await expect(primary(page,'special').locator('.command-status')).toHaveText('Siap');
 await page.screenshot({path:'test-results/player-actions-ready-desktop.png'});
 mock.patch({teacher_paused:true,teacher_paused_at:new Date().toISOString()});
 await expect(primary(page,'special')).toBeDisabled();await expect(primary(page,'summon')).toBeDisabled();await expect(primary(page,'end_turn')).toBeDisabled();await expect(panel(page).locator('.command-ready-bubble')).toHaveCount(0);
 await expect(panel(page).locator('.command-status')).toHaveCount(0);
 await expect(primary(page,'special')).toContainText('Dijeda guru');
 await expect(primary(page,'special').locator('.command-icon')).toHaveCSS('color','rgb(112, 70, 188)');
 await panel(page).screenshot({path:'test-results/player-actions-paused-colors.png'});
 await panel(page).getByRole('button',{name:'Lihat informasi skill'}).click();const dialog=page.getByRole('dialog',{name:'Coby',exact:true});await dialog.locator('.special-skill-tab').first().click();await expect(dialog.getByRole('button',{name:'Gunakan Arc Rally'})).toBeDisabled();await expect(dialog).toContainText('Pertandingan dijeda guru');await page.keyboard.press('Escape');
 mock.patch({teacher_paused:false,current_turn:'p2'});await expect(primary(page,'special')).toBeDisabled();await expect(panel(page).locator('.command-ready-bubble')).toHaveCount(0);
 mock.patch({current_turn:'p1',player1_action_points:0,turn_index:9});await expect(primary(page,'special')).toBeDisabled();await expect(primary(page,'attack')).toBeDisabled();await expect(primary(page,'end_turn')).toBeEnabled();expect(mock.submissions).toHaveLength(0);
});
