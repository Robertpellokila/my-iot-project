import {test,expect} from '@playwright/test';
import {mockGameSetup} from '../fixtures/mockGameSetup.js';
import {battleEndpoint} from '../fixtures/mockPlayerBattle.js';
const toast=(page,type)=>page.locator(`.admin-toast[data-type="${type}"]`);
async function admin(page){
 await mockGameSetup(page);await page.routeWebSocket('**',socket=>socket.close());
 const card={id:'10000000-0000-4000-8000-000000000051',name:'Coby Toast',card_code:'COB_TOAST',element:'Knight',rarity:'common',hp:120,attack:30,defense:14,metadata:{skills:[{name:'Buddy Guard',description:'Beri Shield 8 pada diri. CD 2.'},{name:'First Step',description:'Serangan normal +3 pada aksi pertama setelah summon.'}]},featured_on_landing:false,landing_active:true,battle_enabled:true,availability_version:1};
 const rfid={id:'10000000-0000-4000-8000-000000000052',uid:'AABB1234',label:'RFID toast',card_type:'rfid_card',is_active:true,owner_id:null,created_at:new Date().toISOString()};
 const state={card,rfid,fail:false,syncFail:false,saves:[],workspace:null,entries:[],questions:[]};
 await page.route(`${battleEndpoint}/rest/v1/**`,async route=>{
  const req=route.request(),url=new URL(req.url()),resource=url.pathname.split('/').at(-1),method=req.method();
  if(resource==='profiles')return route.fallback();
  if(resource==='game_cards'){
   if(method==='PATCH'){if(state.fail)return route.fulfill({status:503,json:{message:'Koneksi terputus. Data belum disimpan.'}});Object.assign(card,req.postDataJSON());return route.fulfill({json:card});}
   return route.fulfill({json:url.searchParams.has('id')?card:[card]});
  }
  if(resource==='rfid_cards'){
   if(method==='PATCH'){state.saves.push(req.postDataJSON());Object.assign(rfid,req.postDataJSON());return route.fulfill({json:rfid});}
   return route.fulfill({json:url.searchParams.get('id')?.startsWith('neq.')?null:url.searchParams.has('id')?rfid:[rfid]});
  }
  if(resource==='coding_questions'){
   if(method==='POST'){state.saves.push(req.postDataJSON());if(state.fail)return route.fulfill({status:503,json:{message:'Soal belum tersimpan. Coba lagi.'}});state.questions.push(req.postDataJSON());return route.fulfill({json:{}});}
   return route.fulfill({json:state.questions});
  }
  if(resource==='card_generator_projects')return route.fulfill({json:state.workspace?{workspace:state.workspace,updated_at:new Date().toISOString()}:null});
  if(resource==='card_studio_entries')return route.fulfill({json:state.entries});
  if(resource==='save_card_studio'){
   const body=req.postDataJSON();state.saves.push(body);state.workspace=body.p_workspace;state.entries=body.p_entries.map(entry=>({card_key:entry.key,game_card_id:card.id}));return route.fulfill({json:{entries:state.entries,saved_at:new Date().toISOString()}});
  }
  if(resource==='sync_card_studio_battle_skills')return state.syncFail?route.fulfill({status:503,json:{message:'Sinkronisasi sementara terputus'}}):route.fulfill({json:{synced_slots:2,pending_slots:0}});
  return route.fulfill({json:[]});
 });return state;
}
const errors=new WeakMap();
test.beforeEach(({page})=>{const list=[];errors.set(page,list);page.on('pageerror',e=>list.push(e.message));});
test.afterEach(({page})=>expect(errors.get(page)).toEqual([]));

test('success, danger and info report actual Album results; native modal toasts remain clickable and keep input focus',async({page})=>{
 const state=await admin(page);await page.goto('/admin/game/album-card');await page.locator('.publish-toggle').click();await expect(toast(page,'success')).toContainText('Pengaturan tampilan Coby Toast tersimpan');
 expect(state.card.featured_on_landing).toBe(true);await toast(page,'success').getByRole('button',{name:'Tutup notifikasi Berhasil'}).click();
 await page.locator('.album-open').click();const dialog=page.getByRole('dialog');await dialog.getByLabel('Kelompok',{exact:true}).fill('Starter');state.fail=true;await dialog.getByRole('button',{name:'Simpan pengaturan tampilan'}).click();await expect(toast(page,'danger')).toContainText('Data belum disimpan');
 expect(state.card.landing_group).toBeUndefined();expect(await page.locator('.admin-toast-host').evaluate(host=>host.parentElement.tagName)).toBe('DIALOG');
 await dialog.getByLabel('Kelompok',{exact:true}).focus();await dialog.getByLabel('Kelompok',{exact:true}).pressSequentially(' team');await expect(dialog.getByLabel('Kelompok',{exact:true})).toBeFocused();await dialog.getByRole('button',{name:'Refresh data'}).evaluate(button=>button.click());await expect(toast(page,'info')).toBeVisible();await expect(dialog.getByLabel('Kelompok',{exact:true})).toBeFocused();
 await toast(page,'danger').getByRole('button',{name:'Tutup notifikasi Gagal'}).click();await expect(toast(page,'danger')).toHaveCount(0);
 state.fail=false;await dialog.getByRole('button',{name:'Simpan pengaturan tampilan'}).click();await expect(dialog).not.toBeVisible();await expect(toast(page,'success')).toContainText('tersimpan');expect(await page.locator('.admin-toast-host').evaluate(host=>host.parentElement.tagName)).toBe('BODY');
 await page.getByRole('button',{name:'↻ Refresh'}).click();await expect(toast(page,'info')).toContainText('Koleksi kartu dimuat ulang.');await page.screenshot({path:'test-results/admin-toasts-album.png'});
});

test('question validation warns without saving; successful and failed saves use different toast types',async({page})=>{
 const state=await admin(page);await page.goto('/admin/questions/add');await page.getByRole('button',{name:'Buka preview interaktif'}).click();await expect(toast(page,'warning')).toContainText('Tulis pertanyaannya');expect(state.saves).toHaveLength(0);
 await page.getByPlaceholder('Apa yang terjadi setelah bendera hijau diklik?').fill('Berapa hasil 2 + 2?');for(const [letter,value]of [['A','4'],['B','5'],['C','6'],['D','7']])await page.getByPlaceholder('Jawaban '+letter).fill(value);
 state.fail=true;await page.getByRole('button',{name:'Simpan soal',exact:true}).click();await expect(toast(page,'danger')).toContainText('Soal belum tersimpan');expect(state.questions).toHaveLength(0);
 state.fail=false;await page.getByRole('button',{name:'Simpan soal',exact:true}).click();await expect(toast(page,'success')).toContainText('Soal berhasil ditambahkan');expect(state.questions).toHaveLength(1);
});

test('RFID edit success survives redirect instead of disappearing with the form',async({page})=>{
 const state=await admin(page);await page.goto(`/admin/rfid/${state.rfid.id}/edit`);await page.getByPlaceholder('RFID label').fill('New label');await page.locator('button[type="submit"]').click();await expect(page).toHaveURL(/\/admin\/rfid$/);await expect(toast(page,'success')).toContainText('Perubahan RFID berhasil disimpan.');expect(state.rfid.label).toBe('New label');
});

test('partial Studio sync shows warning for already saved data and never reports a false save failure',async({page})=>{
 const state=await admin(page);state.syncFail=true;await page.goto(`/admin/card-generator?catalog=${state.card.id}`);await expect(page.getByLabel('Nama karakter / Fusion',{exact:true})).toHaveValue('Coby Toast');await page.getByLabel('Nama karakter / Fusion',{exact:true}).fill('Coby Saved');await page.getByRole('button',{name:'Simpan kartu',exact:true}).click();await expect(toast(page,'warning')).toContainText('kartu tersimpan, tetapi sinkronisasi skill battle belum selesai');await expect(toast(page,'danger')).toHaveCount(0);expect(state.saves).toHaveLength(1);expect(state.entries).toHaveLength(1);
});

test('success expires after pointer leaves, pauses while read, and cannot overflow mobile',async({page})=>{
 await page.setViewportSize({width:390,height:844});await admin(page);await page.goto('/admin/game/album-card');await page.locator('.publish-toggle').click();const item=toast(page,'success');await item.hover();await page.waitForTimeout(4700);await expect(item).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);const box=await item.boundingBox();expect(box.x).toBeGreaterThanOrEqual(0);expect(box.x+box.width).toBeLessThanOrEqual(391);await page.mouse.move(5,820);await expect(item).toHaveCount(0,{timeout:6000});
});

test('logout clears earlier admin notices and its confirmation survives the login redirect',async({page})=>{
 await admin(page);await page.goto('/admin/game/album-card');await page.locator('.publish-toggle').click();await expect(toast(page,'success')).toHaveCount(1);await page.locator('.profile-button').click();await page.locator('.dropdown-logout').click();await expect(page).toHaveURL(/\/login$/);await expect(toast(page,'success')).toContainText('Kamu berhasil keluar');await expect(page.locator('.admin-toast')).toHaveCount(1);
});
