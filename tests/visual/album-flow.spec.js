import {test,expect} from '@playwright/test';
import {readFileSync} from 'node:fs';
import {compileStudioSkill} from '../../src/lib/card-generator/cardSkillBattleRules.js';
const env=['.env','.env.local'].map(p=>{try{return readFileSync(p,'utf8');}catch{return '';}}).join('\n');
const endpoint=env.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)[1];
const project=new URL(endpoint).hostname.split('.')[0];
const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'studio@example.invalid',app_metadata:{provider:'email'},user_metadata:{}};
const token=`${Buffer.from(JSON.stringify({alg:'HS256'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test`;
async function mock(page){
 const state={workspace:null,entries:[],saved:[],skills:[],skillLinks:[],linked:[],recipes:[],materials:[],recipeSaves:[],fail:false,cards:Array.from({length:10},(_,i)=>({id:`00000000-0000-4000-8000-${String(100+i).padStart(12,'0')}`,name:`Coby ${String(i+1).padStart(2,'0')}`,card_code:`COB_${i+1}`,element:'Knight',rarity:'common',hp:120,attack:30,defense:14,battle_enabled:true,archived_at:null,availability_version:1,metadata:{skills:[{name:'Guard',description:'Shield 8'},{name:'Step',description:'Attack 3'}]},uid:i===1?'RFID-123':null,physical_scan_enabled:i===1,fusion_only:false,featured_on_landing:false,landing_active:true,landing_display_order:0,landing_group:''}))};
 await page.addInitScript(({key,user,token})=>localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'fake',expires_at:Math.floor(Date.now()/1000)+3600,user})),{key:`sb-${project}-auth-token`,user,token});
 await page.route(`${endpoint}/**`,async r=>{
  const q=r.request(),url=new URL(q.url()),resource=url.pathname.split('/').at(-1);
  if(resource==='user')return r.fulfill({json:user});
  if(resource==='profiles')return r.fulfill({json:{...user,role:'admin'}});
  if(resource==='card_generator_projects')return r.fulfill({json:state.workspace?{workspace:state.workspace,updated_at:new Date().toISOString()}:null});
  if(resource==='card_studio_entries')return r.fulfill({json:state.entries});
  if(resource==='fusion_recipes'){const id=url.searchParams.get('result_game_card_id')?.replace('eq.','');return r.fulfill({json:state.recipes.filter(row=>!id||row.result_game_card_id===id)});}
  if(resource==='fusion_recipe_materials'){const id=url.searchParams.get('recipe_id')?.replace('eq.','');return r.fulfill({json:state.materials.filter(row=>!id||row.recipe_id===id)});}
  if(resource==='save_studio_fusion_recipe'){
   if(state.fail)return r.fulfill({status:503,json:{message:'Resep belum tersimpan: koneksi terputus'}});
   const body=q.postDataJSON();state.recipeSaves.push(body);const recipe={...body.p_recipe,result_game_card_id:body.p_result_game_card_id,updated_at:new Date().toISOString()};
   state.recipes=state.recipes.filter(row=>row.id!==recipe.id);state.recipes.push(recipe);state.materials=state.materials.filter(row=>row.recipe_id!==recipe.id);const materials=body.p_materials.map(row=>({...row,id:crypto.randomUUID(),recipe_id:recipe.id}));state.materials.push(...materials);return r.fulfill({json:{recipe,materials}});
  }
  if(resource==='special_skills'){
   if(q.method()==='PATCH'){const id=url.searchParams.get('id')?.replace('eq.','');Object.assign(state.skills.find(skill=>skill.id===id),q.postDataJSON());return r.fulfill({json:null});}
   return r.fulfill({json:state.skills});
  }
  if(resource==='game_card_special_skills'){
   if(q.method()==='PATCH'){const card=url.searchParams.get('game_card_id')?.replace('eq.',''),skill=url.searchParams.get('special_skill_id')?.replace('eq.','');for(const link of state.skillLinks.filter(l=>l.game_card_id===card&&l.special_skill_id===skill))Object.assign(link,q.postDataJSON());return r.fulfill({json:null});}
   const id=url.searchParams.get('game_card_id')?.replace('eq.','');
   return r.fulfill({json:state.skillLinks.filter(link=>!id||link.game_card_id===id).map(link=>({...link,special_skills:state.skills.find(skill=>skill.id===link.special_skill_id)}))});
  }
  if(resource==='sync_card_studio_battle_skills')return r.fulfill({json:{synced_slots:2,pending_slots:0}});
  if(resource==='link_studio_card_rfid'){
   if(state.fail)return r.fulfill({status:503,json:{message:'Koneksi sedang terputus'}});
   const body=q.postDataJSON(),source=state.cards.find(card=>card.id===body.p_game_card_id),uid=body.p_uid,existing=state.cards.find(card=>card.uid===uid);
   if(existing&&existing.id!==source.id&&existing.metadata?.catalog_source_id!==source.id)return r.fulfill({json:{conflict:true,uid,previous_card:{id:existing.id,name:existing.name,card_code:existing.card_code},target_name:source.name}});
   const record=existing??{...structuredClone(source),id:crypto.randomUUID(),uid,physical_scan_enabled:true,featured_on_landing:false,metadata:{...source.metadata,catalog_source_id:source.id}};
   if(!existing)state.cards.push(record);state.linked.push(body);return r.fulfill({json:{id:record.id,uid,name:record.name,already_linked:!!existing}});
  }
  if(resource==='reassign_studio_card_rfid'){
   if(state.fail)return r.fulfill({status:503,json:{message:'Pemindahan gagal; UID masih pada kartu lama.'}});
   const body=q.postDataJSON(),old=state.cards.find(c=>c.uid===body.p_uid),source=state.cards.find(c=>c.id===body.p_game_card_id);
   if(old?.id!==body.p_previous_card_id)return r.fulfill({status:409,json:{code:'40001',message:'Hubungan UID sudah berubah. Periksa ulang.'}});
   const previous={id:old.id,name:old.name};old.uid=null;old.physical_scan_enabled=false;
   const copy={...structuredClone(source),id:crypto.randomUUID(),uid:body.p_uid,physical_scan_enabled:true,metadata:{...source.metadata,catalog_source_id:source.id}};state.cards.push(copy);
   return r.fulfill({json:{id:copy.id,uid:copy.uid,name:copy.name,transferred:true,previous_card:previous}});
  }
  if(resource==='save_card_studio'){
   if(state.fail)return r.fulfill({status:503,json:{message:'Koneksi sedang terputus'}});
   const body=q.postDataJSON();state.saved.push(body);state.workspace=body.p_workspace;
   const rows=body.p_entries.map(e=>{
    let mapping=state.entries.find(x=>x.card_key===e.key);
    if(!mapping){mapping={card_key:e.key,game_card_id:e.card.source_game_card_id??`00000000-0000-4000-8000-${String(200+state.entries.length).padStart(12,'0')}`};state.entries.push(mapping);}
    const card={id:mapping.game_card_id,name:e.card.name+(e.card.subtitle?' — '+e.card.subtitle:''),card_code:e.card.display_code.replaceAll('-','_'),element:e.card.type,rarity:e.card.rarity.toLowerCase(),...e.card.stats,metadata:{studio_card:e.card,studio_artwork:e.artwork,skills:e.card.skills},featured_on_landing:false,landing_active:true,fusion_only:e.card.kind==='fusion'};
    const index=state.cards.findIndex(c=>c.id===card.id);if(index<0)state.cards.push(card);else Object.assign(state.cards[index],card);
    e.card.skills.forEach((skill,i)=>{if(state.skillLinks.some(link=>link.game_card_id===card.id&&link.sort_order===i+1))return;const definition={...skill,...compileStudioSkill(skill),id:crypto.randomUUID(),code:`studio_${card.id}_${i}`,is_active:true,catalog_status:'active',skill_type:'active',metadata:{studio_generated:true,slot:i+1,studio_rule:compileStudioSkill(skill)}};state.skills.push(definition);state.skillLinks.push({game_card_id:card.id,special_skill_id:definition.id,sort_order:i+1,enabled:true});});return mapping;
   });return r.fulfill({json:{entries:rows,saved_at:new Date().toISOString()}});
  }
  if(resource==='manage_game_card'){
   const body=q.postDataJSON();(state.lifecycleRequests??=[]).push(body);
   if(state.fail)return r.fulfill({status:503,json:{message:'Status kartu belum tersimpan'}});
   if(state.lifecycleDelay)await new Promise(resolve=>setTimeout(resolve,state.lifecycleDelay));
   const card=state.cards.find(c=>c.id===body.p_game_card_id);
   if(body.p_expected_version!==(card.availability_version??1))return r.fulfill({status:409,json:{message:'Status kartu sudah berubah. Refresh Album lalu coba lagi.',code:'40001'}});
   Object.assign(card,{availability_version:(card.availability_version??1)+1});
   if(body.p_action==='archive')Object.assign(card,{archived_at:new Date().toISOString(),battle_enabled:false,featured_on_landing:false,landing_active:false});
   else if(body.p_action==='restore')Object.assign(card,{archived_at:null,battle_enabled:false,featured_on_landing:false,landing_active:false});
   else card.battle_enabled=body.p_action==='enable';
   return r.fulfill({json:{ok:true,card}});
  }
  if(resource==='game_cards'){
   const id=url.searchParams.get('id')?.replace('eq.','');
   if(q.method()==='PATCH'){
    if(state.fail)return r.fulfill({status:503,json:{message:'Publikasi belum tersimpan'}});
    const card=state.cards.find(c=>c.id===id);Object.assign(card,q.postDataJSON());return r.fulfill({json:card});
   }
   return r.fulfill({json:id?state.cards.find(c=>c.id===id):state.cards});
  }
  return r.fulfill({json:[]});
 });return state;
}
test('edit pilot, save to account, reload cloud and reuse the card for RFID',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const state=await mock(page);await page.goto('/admin/card-generator');
 await page.getByLabel('Nama karakter / Fusion',{exact:true}).fill('Tochi Saved');await page.locator('[data-stat="hp"] input').fill('151');
 await page.getByRole('button',{name:'Simpan kartu',exact:true}).click();await expect(page.locator('.cg-message')).toContainText('1 kartu tersimpan');
 expect(state.saved[0].p_entries[0].card.stats.hp).toBe(151);expect(state.saved[0].p_entries[0].card.name).toBe('Tochi Saved');
 await page.evaluate(()=>Object.keys(localStorage).filter(k=>k.startsWith('tbc:card-generator:')).forEach(k=>localStorage.removeItem(k)));await page.reload();
 await expect(page.getByLabel('Nama karakter / Fusion',{exact:true})).toHaveValue('Tochi Saved');
 await page.getByRole('link',{name:'Buka Album ↗'}).click();await page.getByPlaceholder('Nama, kode kartu, atau RFID…').fill('Tochi Saved');await expect(page.locator('.album-open .cg-card-render > svg')).toHaveCount(1);await expect(page.locator('.album-open')).toContainText('151');
 await page.locator('.album-open').click();await expect(page.getByRole('dialog')).toContainText('2 skill terhubung ke battle');await page.getByRole('link',{name:'Edit di Studio',exact:true}).click();await expect(page.getByLabel('Nama karakter / Fusion',{exact:true})).toHaveValue('Tochi Saved');
 const saves=state.saved.length;await page.getByRole('button',{name:'Hubungkan RFID',exact:true}).click();await expect(page).toHaveURL(/card-generator/);
 const dialog=page.getByRole('dialog');await expect(dialog).toContainText('Tochi Saved');await dialog.screenshot({path:'test-results/unified-rfid-desktop.png'});
 await page.evaluate(async()=>{const {supabase}=await import('/src/lib/supabase.js');const channel=supabase.getChannels().find(c=>c.topic.includes('studio-rfid:'));channel.bindings.postgres_changes[0].callback({new:{uid:'QA-NEW-UID'}});});
 await expect(page.getByLabel('UID RFID',{exact:true})).toHaveValue('QA-NEW-UID');await page.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();await expect(dialog).toContainText('RFID berhasil dihubungkan');
 expect(state.saved.length).toBe(saves);expect(state.cards.filter(c=>c.name.startsWith('Tochi Saved'))).toHaveLength(2);expect(state.cards.find(c=>c.uid==='QA-NEW-UID').hp).toBe(151);expect(errors).toEqual([]);
 await page.getByRole('button',{name:'Selesai',exact:true}).click();expect(await page.evaluate(async()=>{const {supabase}=await import('/src/lib/supabase.js');return supabase.getChannels().some(c=>c.topic.includes('studio-rfid:'));})).toBe(false);
});
test('account save reports actual failure and keeps edits',async({page})=>{
 const state=await mock(page);state.fail=true;await page.goto('/admin/card-generator');await page.getByLabel('Nama karakter / Fusion',{exact:true}).fill('Unsaved name');await page.getByRole('button',{name:'Simpan kartu',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Koneksi sedang terputus');await expect(page.getByLabel('Nama karakter / Fusion',{exact:true})).toHaveValue('Unsaved name');
});
test('Fusion designs remain editable and exportable without an RFID action',async({page})=>{
 await mock(page);await page.goto('/admin/card-generator');await page.locator('.cg-library-row > button').filter({hasText:'F01'}).first().click();
 await expect(page.getByRole('button',{name:'Hubungkan RFID',exact:true})).toBeDisabled();await expect(page.locator('.cg-catalog-actions')).toContainText('Fusion memakai resep');
 await page.getByRole('button',{name:/Export \/ Cetak/}).click();await expect(page.locator('.cg-export-dialog')).toBeVisible();
});
test('Studio Fusion recipes save EXACT, ONE OF and ONE TAG, survive reload and preserve edits on failure',async({page})=>{
 const state=await mock(page),errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/admin/card-generator');await page.locator('.cg-library-row > button').filter({hasText:'F01'}).first().click();await page.getByRole('button',{name:'Atur resep Fusion',exact:true}).click();
 const editor=page.locator('.studio-fusion-editor');await expect(editor.getByRole('heading',{name:'Resep Fusion',exact:true})).toBeVisible();
 await editor.getByLabel('Nama resep',{exact:true}).fill('Forest combination');
 await editor.getByRole('combobox',{name:'Kartu EXACT 1'}).click();await page.getByRole('option',{name:'Coby 01 · COB_1',exact:true}).click();
 await editor.getByLabel('Mode material 2',{exact:true}).selectOption('one_of');await editor.getByRole('combobox',{name:'Alternatif ONE OF 2'}).click();await page.getByRole('option',{name:'Coby 02 · COB_2',exact:true}).click();await page.getByRole('option',{name:'Coby 03 · COB_3',exact:true}).click();await page.keyboard.press('Escape');
 await editor.getByRole('button',{name:'+ Tambah material'}).click();await editor.getByLabel('Mode material 3',{exact:true}).selectOption('tag');await editor.getByLabel('Tag ONE TAG 3',{exact:true}).fill('fusion:VINE');
 await editor.getByRole('button',{name:'Simpan resep Fusion',exact:true}).click();await expect(editor.getByRole('status')).toContainText('Resep Fusion tersimpan');
 expect(state.recipeSaves[0].p_materials.map(m=>m.material_type)).toEqual(['exact_card','one_of','tag']);expect(state.recipeSaves[0].p_materials[1].card_codes).toEqual(['COB_2','COB_3']);expect(state.recipeSaves[0].p_materials[2].tag).toBe('fusion:vine');
 await page.getByRole('button',{name:'Data & desain',exact:true}).click();await page.getByRole('button',{name:'Atur resep Fusion',exact:true}).click();await expect(editor.getByLabel('Nama resep',{exact:true})).toHaveValue('Forest combination');
 await page.reload();await page.getByRole('button',{name:'Atur resep Fusion',exact:true}).click();await expect(editor.getByLabel('Nama resep',{exact:true})).toHaveValue('Forest combination');await expect(editor.getByLabel('Tag ONE TAG 3',{exact:true})).toHaveValue('fusion:vine');
 const saved=JSON.stringify(state.materials);state.fail=true;await editor.getByLabel('Nama resep',{exact:true}).fill('Unsaved recipe');await editor.getByRole('button',{name:'Simpan resep Fusion',exact:true}).click();await expect(editor.getByRole('alert')).toContainText('koneksi terputus');await expect(editor.getByLabel('Nama resep',{exact:true})).toHaveValue('Unsaved recipe');expect(JSON.stringify(state.materials)).toBe(saved);
 state.fail=false;await editor.getByLabel('Tag ONE TAG 3',{exact:true}).fill('');await editor.getByRole('button',{name:'Simpan resep Fusion',exact:true}).click();await expect(editor.getByRole('alert')).toContainText('isi tag');expect(state.recipeSaves).toHaveLength(1);
 await editor.getByLabel('Tag ONE TAG 3',{exact:true}).fill('fusion:vine');await editor.getByLabel('Nama resep',{exact:true}).fill('Forest combination');await editor.getByRole('button',{name:'Simpan resep Fusion',exact:true}).click();await expect(editor.getByRole('status')).toContainText('Resep Fusion tersimpan');expect(state.recipes).toHaveLength(1);expect(state.materials).toHaveLength(3);
 await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:'test-results/studio-fusion-recipes.png',fullPage:true});await page.setViewportSize({width:390,height:844});expect(await editor.evaluate(el=>el.scrollWidth<=el.clientWidth)).toBe(true);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);expect(errors).toEqual([]);
});
test('legacy registration link opens the same Studio and custom rule edits update its preview and account',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const state=await mock(page);
 const source=state.cards[0],image='https://images.example.test/icon.png';
 const png=Buffer.from(await page.evaluate(()=>{const canvas=document.createElement('canvas');canvas.width=canvas.height=64;const ctx=canvas.getContext('2d');ctx.fillStyle='#159b49';ctx.fillRect(0,0,64,64);return canvas.toDataURL('image/png').split(',')[1];}),'base64');
 await page.route('https://images.example.test/**',r=>r.fulfill({contentType:'image/png',body:png}));
 const printed=[{name:'Tide Bump',description:'Serangan normal +3 jika HP diri di atas 50%.'},{name:'Shell Brace',description:'+6 DEF pada diri sampai menerima 1 hit. CD 2.'}];
 source.name='CACHE TURTLE — Tidal Defender';source.metadata={studio_card:{skills:printed},skills:printed};
 state.skills=printed.map((skill,i)=>({...skill,...compileStudioSkill(skill),id:crypto.randomUUID(),code:`studio_turtle_${i}`,is_active:true,catalog_status:'active',icon:image,skill_type:'active',metadata:{studio_generated:true,slot:i+1,studio_rule:compileStudioSkill(skill)}}));
 state.skillLinks=state.skills.map((skill,i)=>({game_card_id:source.id,special_skill_id:skill.id,sort_order:i+1,enabled:true}));
 await page.goto(`/admin/game/register?source=${source.id}`);
 await expect(page).toHaveURL(/card-generator.*rfid=1/);await expect(page.getByRole('dialog')).toBeVisible();await page.getByRole('button',{name:'Tutup panel RFID'}).click();
 await page.getByRole('button',{name:'Aturan skill',exact:true}).click();
 const editor=page.locator('.skill-catalog-embedded');await expect(editor.getByLabel('Nama skill',{exact:true})).toHaveValue('Tide Bump');await expect(editor.locator('.skill-item-icon img')).toHaveCount(2);
 await expect(editor.locator('.skill-item-copy').first()).not.toContainText('https://');
 await editor.getByLabel('Nama skill',{exact:true}).fill('Tide Bump Custom');
 await editor.getByLabel('Biaya poin giliran',{exact:false}).selectOption('2');await editor.getByLabel('Jeda pemakaian',{exact:false}).fill('4');
 await editor.getByRole('button',{name:'Simpan skill · versi berikutnya'}).click();
 await expect.poll(()=>state.skills[0].limits?.cooldown_turns).toBe(4);
 await expect.poll(()=>state.saved.at(-1)?.p_entries[0].card.skills[0].name).toBe('Tide Bump Custom');
 expect(state.skills[0].metadata.studio_customized).toBe(true);expect(state.skills[0].effects).toEqual(compileStudioSkill(printed[0]).effects);
 await expect(editor.getByRole('button',{name:'Simpan skill · versi berikutnya'})).toBeEnabled();await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:'test-results/unified-studio-skills.png',fullPage:true});
 await page.getByRole('button',{name:'Data & desain',exact:true}).click();await expect(page.getByLabel('Nama skill',{exact:true}).first()).toHaveValue('Tide Bump Custom');
 expect(errors).toEqual([]);
});
test('RFID collision and offline errors keep the same design and allow another UID on mobile',async({page})=>{
 const state=await mock(page);await page.setViewportSize({width:390,height:844});await page.goto(`/admin/card-generator?catalog=${state.cards[0].id}&rfid=1`);
 const dialog=page.getByRole('dialog');await expect(dialog).toBeVisible();
 await page.getByLabel('UID RFID',{exact:true}).fill('RFID-123');await page.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();await expect(dialog.getByRole('region',{name:'Konfirmasi pemindahan UID'})).toContainText('UID ini sudah terhubung');
 state.fail=true;await page.getByLabel('UID RFID',{exact:true}).fill('RFID-NEW');await page.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();await expect(dialog.getByRole('alert')).toContainText('Koneksi sedang terputus');
 state.fail=false;await page.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();await expect(dialog).toContainText('RFID berhasil dihubungkan');await page.getByRole('button',{name:'Hubungkan UID lain'}).click();await page.getByLabel('UID RFID',{exact:true}).fill('RFID-NEW');await page.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();await expect(dialog).toContainText('RFID sudah terhubung');
 expect(state.cards.filter(c=>c.uid==='RFID-NEW')).toHaveLength(1);expect(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth)).toBe(true);
 await dialog.screenshot({path:'test-results/unified-rfid-mobile.png'});await page.getByRole('button',{name:'Selesai',exact:true}).click();await expect(dialog).not.toBeVisible();
});
test('album is light, publishes safely, flips pages and edits the selected catalog card',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const state=await mock(page);await page.emulateMedia({reducedMotion:'no-preference'});await page.goto('/admin/game/album-card');
 await expect(page.locator('.album-open')).toHaveCount(8);
 await page.locator('.publish-toggle').first().click();expect(state.cards[0].featured_on_landing).toBe(true);await expect(page.locator('.publish-toggle').first()).toHaveAttribute('aria-pressed','true');
 state.fail=true;await page.locator('.publish-toggle').first().click();await expect(page.getByRole('alert')).toContainText('Publikasi belum tersimpan');await expect(page.locator('.publish-toggle').first()).toHaveAttribute('aria-pressed','true');state.fail=false;
 await page.getByRole('button',{name:'Berikutnya →'}).click();await expect(page.locator('.flip-next')).toBeVisible();await expect(page.locator('.album-pagination')).toContainText('Lembar 2 dari 2');await expect(page.locator('.album-leaf')).toHaveCount(0);
 await page.getByRole('button',{name:'← Sebelumnya'}).click();await expect(page.locator('.flip-previous')).toBeVisible();await expect(page.locator('.album-leaf')).toHaveCount(0);
 await page.locator('.album-open').first().click();const dialog=page.getByRole('dialog');await expect(dialog).toBeVisible();expect(await dialog.evaluate(el=>getComputedStyle(el).backgroundColor)).toBe('rgb(255, 254, 249)');await expect(dialog).toContainText('Guard');await expect(dialog).toContainText('ATK');
 await page.screenshot({path:'test-results/album-detail-light.png',fullPage:true});await page.getByRole('button',{name:'Tutup detail kartu'}).click();await page.screenshot({path:'test-results/album-light.png',fullPage:true});
 await page.locator('.album-open').first().click();await page.getByRole('link',{name:'Edit di Studio',exact:true}).click();await expect(page.getByLabel('Nama karakter / Fusion',{exact:true})).toHaveValue('Coby 01');await expect(page.locator('[data-stat="hp"] input')).toHaveValue('120');expect(errors).toEqual([]);
});
test('album reduced motion and narrow screen stay readable',async({page})=>{
 await mock(page);await page.setViewportSize({width:390,height:844});await page.goto('/admin/game/album-card');await page.getByRole('button',{name:'Berikutnya →'}).click();await expect(page.locator('.album-leaf')).toHaveCount(0);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.locator('.album-open').first().click();await expect(page.getByRole('dialog')).toBeVisible();expect(await page.getByRole('dialog').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBe(true);await page.keyboard.press('Escape');await expect(page.getByRole('dialog')).not.toBeVisible();
});

test('Album separates battle availability from public visibility and keeps both after reload',async({page})=>{
 const state=await mock(page);await page.goto('/admin/game/album-card');
 await page.locator('.battle-toggle').first().click();await expect(page.locator('.card-statuses').first()).toContainText('Nonaktif di battle');
 expect(state.cards[0].battle_enabled).toBe(false);expect(state.cards[0].featured_on_landing).toBe(false);
 await page.locator('.publish-toggle').first().click();expect(state.cards[0].featured_on_landing).toBe(true);expect(state.cards[0].battle_enabled).toBe(false);
 await page.reload();await expect(page.locator('.battle-toggle').first()).toHaveText('Aktifkan battle');await expect(page.locator('.publish-toggle').first()).toHaveText('✓ Tampil di publik');
 await page.getByLabel('Daftar kartu',{exact:true}).selectOption('disabled');await expect(page.locator('.album-open')).toHaveCount(1);
 await page.locator('.battle-toggle').first().click();await expect(page.locator('.album-open')).toHaveCount(0);expect(state.cards[0].battle_enabled).toBe(true);expect(state.cards[0].featured_on_landing).toBe(true);
});
test('delete confirmation moves only the selected card to Trash and restore retains data without republishing',async({page})=>{
 const state=await mock(page);state.cards[0].featured_on_landing=true;const snapshot=structuredClone(state.cards[0]);await page.goto('/admin/game/album-card');
 await page.locator('.album-open').first().click();const dialog=page.getByRole('dialog');await dialog.getByRole('button',{name:'Hapus kartu…'}).click();await dialog.getByRole('button',{name:'Batal',exact:true}).click();expect(state.lifecycleRequests??[]).toHaveLength(0);
 await dialog.getByRole('button',{name:'Hapus kartu…'}).click();await dialog.getByRole('button',{name:'Ya, pindahkan ke Sampah'}).click();await expect(dialog).not.toBeVisible();
 expect(state.cards).toHaveLength(10);expect(state.cards[0].archived_at).toBeTruthy();expect(state.cards[0].featured_on_landing).toBe(false);expect(state.cards[0].battle_enabled).toBe(false);expect(state.cards[0].metadata).toEqual(snapshot.metadata);
 await page.getByLabel('Daftar kartu',{exact:true}).selectOption('trash');await expect(page.locator('.album-open')).toHaveCount(1);await page.locator('.album-open').click();await expect(dialog).toContainText('Data, skill, resep, dan UID tetap tersimpan');await expect(dialog.getByRole('link',{name:'Edit di Studio'})).toHaveCount(0);
 await dialog.getByRole('button',{name:'Pulihkan kartu',exact:true}).click();await expect(dialog).not.toBeVisible();await expect(page.locator('.album-open')).toHaveCount(0);
 expect(state.cards[0].archived_at).toBeNull();expect(state.cards[0].battle_enabled).toBe(false);expect(state.cards[0].featured_on_landing).toBe(false);expect(state.cards[0].hp).toBe(snapshot.hp);
});
test('inactive source blocks a copy and links directly to the source controls',async({page})=>{
 const state=await mock(page);state.cards[0].battle_enabled=false;state.cards[1].metadata.catalog_source_id=state.cards[0].id;await page.goto('/admin/game/album-card');await page.getByLabel('Daftar kartu',{exact:true}).selectOption('rfid');
 await expect(page.locator('.card-statuses').first()).toContainText('Sumber nonaktif');await expect(page.locator('.battle-toggle').first()).toBeEnabled();await page.locator('.battle-toggle').first().click();await expect(page.locator('.card-statuses').first()).toContainText('Nonaktif di battle');await expect(page.locator('.battle-toggle').first()).toBeDisabled();await page.locator('.album-open').click();const dialog=page.getByRole('dialog');await dialog.getByRole('button',{name:'Buka kartu sumber →'}).click();await expect(dialog.getByRole('heading',{name:'Coby 01',exact:true})).toBeVisible();await dialog.getByRole('button',{name:'Aktifkan untuk battle',exact:true}).click();await expect(dialog.locator('.battle-availability')).toContainText('Aktif di battle');await dialog.getByRole('button',{name:'Tutup detail kartu'}).click();await expect(page.locator('.card-statuses').first()).toContainText('Nonaktif di battle');await page.locator('.battle-toggle').first().click();await expect(page.locator('.card-statuses').first()).toContainText('Aktif di battle');
});
test('battle controls preserve state on errors, reject stale edits, and avoid duplicate requests',async({page})=>{
 const state=await mock(page);await page.goto('/admin/game/album-card');await page.locator('.album-open').first().click();const dialog=page.getByRole('dialog');state.fail=true;await dialog.getByRole('button',{name:'Nonaktifkan untuk battle'}).click();await expect(dialog.getByRole('alert')).toContainText('Status kartu belum tersimpan');expect(state.cards[0].battle_enabled).toBe(true);
 state.fail=false;state.cards[0].availability_version=2;await dialog.getByRole('button',{name:'Nonaktifkan untuk battle'}).click();await expect(dialog.getByRole('alert')).toContainText('Status kartu sudah berubah');await dialog.getByRole('button',{name:'Refresh data'}).click();await expect(dialog.getByRole('button',{name:'Nonaktifkan untuk battle'})).toBeEnabled();
 state.lifecycleDelay=500;const count=state.lifecycleRequests.length;await dialog.getByRole('button',{name:'Nonaktifkan untuk battle'}).evaluate(button=>{button.click();button.click();});await expect(dialog.locator('.battle-availability')).toContainText('Nonaktif di battle');expect(state.lifecycleRequests.length-count).toBe(1);
});
test('mobile Album management keeps controls and delete confirmation within the modal',async({page})=>{
 await mock(page);await page.setViewportSize({width:390,height:844});await page.goto('/admin/game/album-card');await page.locator('.album-open').first().click();const dialog=page.getByRole('dialog');await dialog.getByRole('button',{name:'Hapus kartu…'}).click();await expect(dialog.getByRole('group',{name:'Konfirmasi hapus kartu'})).toBeVisible();expect(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth)).toBe(true);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:'test-results/album-card-management-mobile.png'});
});


test('guided skill editor activates shortened Necro, preserves mechanics on copy edits and audits bindings',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const state=await mock(page);
 const source=state.cards[0],description='Bangkitkan Base ke Bench dengan 40% HP. 2 AP, sekali per battle.';
 source.metadata={studio_card:{skills:[{name:'Void Claw',description:'Serangan normal.'},{name:'Necro Recall',description}]} };
 state.skills=[{id:'necro-editor',code:'necro_test',name:'Necro Recall',description,skill_type:'active',activation_timing:'main_phase',target_spec:{},cost_spec:{type:'none'},limits:{},effects:[],is_active:false,catalog_status:'draft',skill_version:2,metadata:{studio_generated:true,slot:2}}];
 state.skillLinks=[{game_card_id:source.id,special_skill_id:'necro-editor',sort_order:2,enabled:false}];
 await page.goto('/admin/game/catalog?skill=necro-editor');
 const editor=page.locator('.rule-editor');await expect(editor.getByRole('button',{name:'Simpan & aktifkan'})).toBeDisabled();
 await expect(page.locator('.editor-heading .status-chip')).toHaveText('Draft');
 await editor.getByRole('button',{name:'Gunakan pola ini'}).click();
 await expect(editor.getByLabel('Deskripsi kartu',{exact:true})).toHaveValue(description);
 await expect(editor.getByLabel('Biaya poin giliran',{exact:false})).toHaveValue('2');
 await expect(editor.getByLabel('Hanya sekali per battle')).toBeChecked();
 await expect(editor.getByRole('button',{name:'Simpan & aktifkan'})).toBeEnabled();
 await expect(page.locator('.editor-heading .status-chip')).toHaveText('Draft');
 await editor.getByRole('button',{name:'Simpan & aktifkan'}).click();
 await expect.poll(()=>state.skills[0].is_active).toBe(true);await expect.poll(()=>state.skillLinks[0].enabled).toBe(true);
 expect(state.skills[0].metadata.studio_customized).toBe(true);expect(state.skills[0].effects[0].program.operations).toEqual([{type:'revive',amount:.4}]);
 const before=structuredClone(state.skills[0].effects);await expect(page.locator('.editor-heading .status-chip')).toHaveText('Aktif');
 await editor.getByLabel('Deskripsi kartu',{exact:true}).fill('Revive 40% HP.');await editor.getByRole('button',{name:'Simpan skill · versi berikutnya'}).click();
 await expect.poll(()=>state.skills[0].description).toBe('Revive 40% HP.');expect(state.skills[0].effects).toEqual(before);
 await page.screenshot({path:'test-results/skill-editor-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});await editor.getByText('Ganti pola efek',{exact:true}).click();
 await editor.getByRole('combobox',{name:'Pola skill',exact:true}).click();
 await expect(page.getByRole('listbox')).toBeVisible();await page.keyboard.press('Escape');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await editor.screenshot({path:'test-results/skill-editor-mobile.png'});
 await page.getByRole('button',{name:'Pemeriksaan katalog'}).click();await expect(page.locator('.audit-view')).toContainText('BUKTI UJI BATTLE');
 expect(errors).toEqual([]);
});

test('RFID reassignment previews both cards, preserves the old card and handles retry safely',async({page})=>{
 const state=await mock(page);const old=state.cards[1],before=structuredClone(old);
 await page.goto(`/admin/card-generator?catalog=${state.cards[0].id}&rfid=1`);const dialog=page.getByRole('dialog');
 await dialog.getByLabel('UID RFID',{exact:true}).fill('RFID-123');await dialog.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();
 const transfer=dialog.getByRole('region',{name:'Konfirmasi pemindahan UID'});await expect(transfer).toContainText(old.name);await expect(transfer).toContainText(state.cards[0].name);
 expect(old).toEqual(before);await transfer.getByRole('button',{name:'Batal',exact:true}).click();expect(old).toEqual(before);
 await dialog.getByLabel('UID RFID',{exact:true}).fill('RFID-123');await dialog.getByRole('button',{name:'Hubungkan kartu',exact:true}).click();
 state.fail=true;await transfer.getByRole('button',{name:'Pindahkan UID ke kartu ini'}).click();await expect(dialog.getByRole('alert')).toContainText('Pemindahan gagal');expect(old).toEqual(before);
 state.fail=false;await transfer.getByRole('button',{name:'Pindahkan UID ke kartu ini'}).click();await expect(dialog).toContainText('UID berhasil dipindahkan');
 expect(old).toEqual({...before,uid:null,physical_scan_enabled:false});expect(state.cards.filter(c=>c.uid==='RFID-123')).toHaveLength(1);
 await expect(dialog).toContainText('tetap tersimpan tanpa UID');await page.setViewportSize({width:390,height:844});expect(await dialog.evaluate(e=>e.scrollWidth<=e.clientWidth)).toBe(true);
 await dialog.screenshot({path:'test-results/rfid-transfer-mobile.png'});
});
