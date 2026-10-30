import {test,expect} from '@playwright/test';
import {mockGameSetup} from '../fixtures/mockGameSetup.js';
import {mockPlayerBattle,battleEndpoint} from '../fixtures/mockPlayerBattle.js';
const policy={version:1,base_only:true,cooldown_owner_turns:1,max_per_turn:1};
const rules=[{id:1,rule_kind:'triple',type_keys:['dark','fire','thunder'],combo_name:'Chaos Storm',primary_multiplier:1,assist_multipliers:[.6,.5],bonus_damage:12,effect_json:{summary:'Serangan tiga elemen.'},members:[]},
 {id:2,rule_kind:'formation',type_keys:['forest','knight','light','thunder'],combo_name:'Guardian Formation',primary_multiplier:1,assist_multipliers:[.6,.45,.35],bonus_damage:6,effect_json:{summary:'Serangan empat elemen.'},members:[]}];
const errors=new WeakMap();test.beforeEach(({page})=>{const list=[];errors.set(page,list);page.on('pageerror',e=>list.push(e.message));});test.afterEach(({page})=>expect(errors.get(page)).toEqual([]));
async function setup(page,types=['fire','fire'],extra={}){
 const mock=await mockPlayerBattle(page,{combo_policy:policy,combo_rules_snapshot:rules,triple_combo_enabled:true,formation_enabled:true,generic_combo_enabled:true,...extra});
 const own=mock.cards.filter(c=>c.player==='p1'&&c.zone==='active');
 for(const c of own.slice(types.length))mock.cards.splice(mock.cards.indexOf(c),1);
 while(own.length<types.length){const c={...mock.source,id:crypto.randomUUID(),slot:own.length+1,name:`Ally ${own.length+1}`};own.push(c);mock.cards.push(c);}
 types.forEach((type,i)=>{own[i].element=type;own[i].tags=['team'];});
 await mock.open();await page.locator('.cyber-card').first().click();
 return mock;
}
async function picker(page){await page.locator('.player-action-panel').getByRole('button',{name:/Aksi lainnya/}).click();await page.getByRole('dialog',{name:'Aksi lainnya',exact:true}).locator('[data-action="combo"]').click();return page.getByRole('dialog',{name:'Pilih kartu Active untuk Combo'});}
test('new battle enables all modes and master switch saves disabled children',async({page})=>{
 const api=await mockGameSetup(page);await page.goto('/admin/setup');
 for(const name of ['Triple Combo','Generic Combo','Formation'])await expect(page.getByRole('checkbox',{name:new RegExp(name)})).toBeChecked();
 await page.locator('button.create-button').click();await expect.poll(()=>api.saved.length).toBe(1);expect(api.saved[0]).toMatchObject({combo_enabled:true,triple_combo_enabled:true,generic_combo_enabled:true,formation_enabled:true});
 await page.goto('/admin/setup');await page.getByRole('checkbox',{name:/Card Combination/}).uncheck();
 for(const name of ['Triple Combo','Generic Combo','Formation'])await expect(page.getByRole('checkbox',{name:new RegExp(name)})).toBeDisabled();
 await page.locator('button.create-button').click();await expect.poll(()=>api.saved.length).toBe(2);expect(api.saved[1]).toMatchObject({combo_enabled:false,triple_combo_enabled:false,generic_combo_enabled:false,formation_enabled:false});
});
for(const [name,types,cost] of [['Combined Strike',['fire','fire'],2],['Chaos Storm',['dark','fire','thunder'],3],['Guardian Formation',['forest','knight','light','thunder'],3]])test(`${name} previews and sends all selected participants once`,async({page})=>{
 const mock=await setup(page,types);const dialog=await picker(page);
 for(let i=2;i<types.length;i++)await dialog.locator('.combo-card-option-wrap .combo-card-option').nth(i).click();
 await expect(dialog.locator('.combo-synergy-preview')).toContainText(name);await expect(dialog.locator('.battle-action-receipt')).toContainText(`Biaya ${cost} AP`);await expect(dialog).toContainText('Kartu Base saja');
 await dialog.locator('.combo-submit').evaluate(button=>{button.click();button.click();});await expect.poll(()=>mock.submissions.length).toBe(1);
 expect(mock.submissions[0].p_payload.participant_card_ids).toHaveLength(types.length);expect(mock.submissions[0].p_payload.target_card_id).toBe(mock.target.id);
 await expect(dialog).toBeHidden();expect(mock.battle.player1_action_points).toBe(3-cost);
  await expect(page.getByText(new RegExp(`${types.length} kartu Active memakai kesempatan serangnya`))).toBeVisible();
});
test('missing recipe and insufficient AP block Triple without spending resources',async({page})=>{
 const mock=await setup(page,['fire','fire','fire']);const dialog=await picker(page);await dialog.locator('.combo-card-option-wrap .combo-card-option').nth(2).click();
 await expect(dialog.locator('.combo-synergy-preview')).toContainText('belum cocok');await expect(dialog.locator('.combo-submit')).toBeDisabled();
 mock.cards.filter(c=>c.player==='p1'&&c.zone==='active').forEach((c,i)=>c.element=['dark','fire','thunder'][i]);mock.refreshCards();mock.patch({player1_action_points:2});
 await expect(dialog.locator('.combo-synergy-preview')).toContainText('Chaos Storm');await expect(dialog.locator('.combo-submit')).toBeDisabled();expect(mock.submissions).toEqual([]);
});
test('affordable Triple remains reachable when pair Combo costs more',async({page})=>{
 const mock=await setup(page,['dark','fire','thunder'],{action_points_per_turn:4,action_costs:{combo_attack:4,triple_combo:3}});const dialog=await picker(page);
 await expect(dialog.locator('.combo-submit')).toBeDisabled();await dialog.locator('.combo-card-option-wrap .combo-card-option').nth(2).click();await expect(dialog.locator('.combo-submit')).toBeEnabled();await expect(dialog.locator('.battle-action-receipt')).toContainText('Biaya 3 AP');expect(mock.submissions).toEqual([]);
});
test('cooldown survives reload and unlocks only after skipping one own turn',async({page})=>{
 const mock=await setup(page,['fire','fire'],{player1_combo_last_owner_turn:2,player1_owner_turn:3});
 await page.locator('.player-action-panel').getByRole('button',{name:/Aksi lainnya/}).click();const drawer=page.getByRole('dialog',{name:'Aksi lainnya',exact:true});
 await expect(drawer.locator('[data-action="combo"]')).toBeDisabled();await expect(drawer.locator('[data-action="combo"]')).toContainText('giliranmu berikutnya');
 await page.reload();await page.locator('.player-action-panel').getByRole('button',{name:/Aksi lainnya/}).click();await expect(drawer.locator('[data-action="combo"]')).toBeDisabled();
 mock.patch({player1_owner_turn:4,turn_index:7});await page.keyboard.press('Escape');await page.locator('.player-action-panel').getByRole('button',{name:/Aksi lainnya/}).click();await expect(drawer.locator('[data-action="combo"]')).toBeEnabled();expect(mock.submissions).toEqual([]);
});
test('legacy recipe load failure has retry and never silently enables Generic',async({page})=>{
 await setup(page,['fire','fire'],{combo_policy:null,combo_rules_snapshot:null});let fail=true;
 await page.route(`${battleEndpoint}/rest/v1/tcg_combo_rule_catalog*`,route=>fail?route.fulfill({status:503,json:{message:'unavailable'}}):route.fulfill({json:[]}));
 const dialog=await picker(page);await expect(dialog.locator('.combo-submit')).toBeDisabled();await expect(dialog).toContainText('Resep Combo belum dapat dimuat');
 fail=false;await dialog.getByRole('button',{name:'COBA MUAT RESEP LAGI'}).click();await expect(dialog.locator('.combo-synergy-preview')).toContainText('Combined Strike');await expect(dialog.locator('.combo-submit')).toBeEnabled();
});
test('admin saves a four-card recipe with exact codes and tags and handles stale edits',async({page})=>{
 await mockGameSetup(page);let fail=false;const saves=[];
 await page.route(`${battleEndpoint}/rest/v1/tcg_combo_rule_catalog*`,route=>route.fulfill({json:[]}));
 await page.route(`${battleEndpoint}/rest/v1/rpc/save_combo_recipe`,route=>{const row=route.request().postDataJSON().p_rule;saves.push(row);return fail?route.fulfill({status:400,json:{message:'Resep sudah berubah. Muat ulang sebelum menyimpan.'}}):route.fulfill({json:{...row,id:44,updated_at:'2026-10-30T00:00:00Z'}});});
 await page.goto('/admin/game/catalog?tab=combo');const editor=page.locator('.combo-catalog');await editor.getByLabel('Nama resep').fill('Pilot Formation');await editor.getByLabel('Jenis Combo').selectOption('4');
 await expect(editor.locator('.combo-member')).toHaveCount(4);await editor.getByLabel('Kartu tertentu').first().fill('COB-008');await editor.getByLabel('Tag wajib').nth(1).fill('TEAM');await editor.getByLabel('Semua peserta juga').check();
 await editor.getByRole('button',{name:'Simpan resep Combo'}).click();await expect.poll(()=>saves.length).toBe(1);expect(saves[0]).toMatchObject({rule_kind:'formation',shared_tag:true});expect(saves[0].members[0].card_code).toBe('COB-008');expect(saves[0].members[1].tag).toBe('TEAM');
 fail=true;await editor.getByRole('button',{name:'Simpan resep Combo'}).click();await expect(editor.getByRole('alert')).toContainText('sudah berubah');await expect(editor.getByLabel('Nama resep')).toHaveValue('Pilot Formation');
 await page.setViewportSize({width:390,height:844});expect(await editor.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);await page.screenshot({path:'test-results/combo-rules/admin-mobile.png',fullPage:true});
});
