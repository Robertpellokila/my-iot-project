import {test,expect} from '@playwright/test';
import {mockPlayerBattle,battleEndpoint} from '../fixtures/mockPlayerBattle.js';
const artwork='/images/card-generator/tochi-sprout-keeper-v1.png';
async function illustratedBattle(page){
 const mock=await mockPlayerBattle(page);
 for(const card of mock.cards)card.image_url=artwork;
 mock.cards.push({...mock.source,id:'20000000-0000-4000-8000-000000000040',name:'Pico',element:'Light',slot:3});
 const enemyBench=mock.cards.find(c=>c.player==='p2'&&c.zone==='bench');enemyBench.zone='active';enemyBench.slot=2;
 for(let n=3;n<=4;n++)mock.cards.push({...mock.target,id:`20000000-0000-4000-8000-00000000004${n}`,slot:n,name:`Lawan ${n}`});
 return mock;
}
async function loadedImages(locator){
 await expect.poll(()=>locator.evaluateAll(images=>images.every(img=>img.complete&&img.naturalWidth>0))).toBe(true);
}

test('Studio print codes stay readable while battle actions retain the original card identity',async({page})=>{
 const mock=await mockPlayerBattle(page);
 const internal='F12_STUDIO_CB980ECC9F2C40F087243DFEA99E4471';
 Object.assign(mock.source,{name:'ACADEMY NEXUS',card_code:internal,card_kind:'fusion',level:1,image_url:artwork});
 Object.assign(mock.target,{card_code:'F01_STUDIO_0123456789ABCDEF0123456789ABCDEF',metadata:{studio_card:{display_code:'F01'}}});
 await mock.open();
 const card=page.locator('.active-panel .cyber-card').first();
 await expect(card.locator('.face-code')).toHaveText('F12');
 await expect(card.locator('.face-code')).toHaveAttribute('title','F12');
 await expect(card.locator('.face-traits')).toHaveText('🧬 Fusion');
 await page.getByRole('button',{name:/Lihat kartu lawan/}).click();
 await expect(page.locator('.inspection-roster .face-code').first()).toHaveText('F01');
 await page.keyboard.press('Escape');
 // Honour an explicit print label when a snapshot supplies Studio metadata.
 mock.source.metadata={studio_card:{display_code:'NEX-12'}};mock.refreshCards();
 await expect(card.locator('.face-code')).toHaveText('NEX-12');
 await card.click();await page.locator('.player-action-panel [data-action="attack"]').click();
 const dialog=page.getByRole('dialog',{name:'Pilih kartu lawan'});
 await dialog.locator('.target-card').first().click();
 await dialog.getByRole('button',{name:'Konfirmasi serangan'}).click();
 await expect.poll(()=>mock.submissions.length).toBe(1);
 expect(mock.submissions[0]).toMatchObject({p_action:'attack',p_card_id:mock.source.id,p_payload:{target_card_id:mock.target.id}});
 expect(mock.source.card_code).toBe(internal);
});

test('illustrated arena keeps card images, HUD values, piles and framed action dialogs usable',async({page})=>{
 await page.setViewportSize({width:1672,height:941});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const mock=await illustratedBattle(page);await mock.open();
 await expect(page.locator('.arena-background')).toHaveCSS('background-image',/stadium-v1/);
 await expect(page.locator('.arena-hud-own')).toContainText('170 / 200');
 await expect(page.locator('.arena-hud-enemy')).toContainText('150 / 200');
 await loadedImages(page.locator('.active-panel .face-art img,.player-action-panel .battle-action-artwork img'));
 const actionBox=await page.locator('.player-action-panel').boundingBox();
 for(const card of await page.locator('.active-panel .cyber-card:not(.empty-card)').all()){
  const box=await card.boundingBox();expect(box.y+box.height).toBeLessThan(actionBox.y+2);
 }
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:'test-results/player-arena-desktop.png'});
 await page.locator('.active-panel .cyber-card').first().click();
 await page.locator('.player-action-panel [data-action="special"]').click();
 await expect(page.locator('.special-skill-modal')).toHaveClass(/arena-frame/);
 await page.screenshot({path:'test-results/player-arena-skills.png'});await page.keyboard.press('Escape');
 await page.getByRole('button',{name:/Aksi lainnya/}).click();
 const actions=page.getByRole('dialog',{name:'Aksi lainnya',exact:true});
 await expect(actions).toHaveCSS('border-image-source',/panel-frame/);
 await loadedImages(actions.locator('.battle-action-artwork img'));
 await page.screenshot({path:'test-results/player-arena-more.png'});await page.keyboard.press('Escape');
 await page.getByRole('button',{name:/Lihat kartu lawan/}).click();
 const inspector=page.getByRole('dialog',{name:'Kartu Active lawan'});
 await expect(inspector.locator('.inspection-roster .arena-card-face')).toHaveCount(4);
 await loadedImages(inspector.locator('.face-art img'));
 await page.screenshot({path:'test-results/player-arena-opponent.png'});await page.keyboard.press('Escape');
 await page.locator('.bench-side-zone').click();
 await expect(page.locator('.pile-viewer-panel')).toBeVisible();
 await expect(page.locator('.pile-viewer-panel')).toHaveClass(/arena-frame/);
 await page.keyboard.press('Escape');
 await page.locator('.graveyard-side-zone').click();await expect(page.locator('.pile-viewer-panel')).toBeVisible();
 expect(mock.submissions).toEqual([]);expect(errors).toEqual([]);
});

test('four active cards fit a short desktop, and phone panels scroll without horizontal overflow',async({page})=>{
 const mock=await illustratedBattle(page);mock.cards.push({...mock.source,id:'20000000-0000-4000-8000-000000000050',name:'Kartu keempat',slot:4});
 await page.setViewportSize({width:1280,height:720});await mock.open();
 const actionBox=await page.locator('.player-action-panel').boundingBox();
 for(const card of await page.locator('.active-panel .cyber-card:not(.empty-card)').all()){
  const box=await card.boundingBox();expect(box.y+box.height).toBeLessThan(actionBox.y+2);
 }
 await page.screenshot({path:'test-results/player-arena-short-desktop.png'});
 await page.setViewportSize({width:390,height:844});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.getByRole('button',{name:/Aksi lainnya/}).click();
 const actions=page.getByRole('dialog',{name:'Aksi lainnya',exact:true});
 expect(await actions.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);
 await page.screenshot({path:'test-results/player-arena-more-mobile.png'});await page.keyboard.press('Escape');
 await page.locator('.bench-side-zone').scrollIntoViewIfNeeded();await expect(page.locator('.bench-side-zone')).toBeInViewport();
 await page.screenshot({path:'test-results/player-arena-piles-mobile.png'});
});

test('quiz shares the arena frame and still submits the selected answer once',async({page})=>{
 const q='10000000-0000-4000-8000-000000000099',round='10000000-0000-4000-8000-000000000098',answers=[];
 const mock=await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:q,current_question_round_id:round,question_time_limit_seconds:60});
 await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:{id:round,battle_id:mock.battle.id,question_id:q,round_number:3,status:'active',created_at:new Date().toISOString()}}));
 await page.route(`${battleEndpoint}/rest/v1/coding_questions*`,route=>route.fulfill({json:{id:q,question:'Apa hasil 2 + 2?',question_type:'choice',option_a:'4',option_b:'5',option_c:'6',option_d:'7',duration_seconds:60}}));
 await page.route(`${battleEndpoint}/rest/v1/rpc/submit_battle_question_answer`,async route=>{answers.push(route.request().postDataJSON());await new Promise(resolve=>setTimeout(resolve,300));return route.fulfill({json:{ok:true,is_correct:true,correct_index:0}});});
 await page.goto('/play/GUIDEDEMO/p1');
 const quiz=page.locator('.question-card');await expect(quiz).toBeVisible();await expect(quiz).toHaveCSS('border-image-source',/panel-frame/);
 await expect(page.locator('.question-option')).toHaveCount(4);
 await page.screenshot({path:'test-results/player-arena-quiz.png'});
 await page.locator('.question-option').first().evaluate(button=>{button.click();button.click()});
 await expect.poll(()=>answers.length).toBe(1);expect(answers[0]).toMatchObject({p_player:'p1',p_answer_index:0,p_question_round_id:round});
});

test('failed artwork falls back to the saved card face while live combat stats remain visible',async({page})=>{
 const mock=await mockPlayerBattle(page);
 mock.source.image_url='/missing-battle-art.png';mock.source.physical_card_image_url=artwork;mock.source.current_attack=0;mock.source.current_defense=7;
 let missingImageRequests=0;
 await page.route('**/missing-battle-art.png',route=>{missingImageRequests++;return route.fulfill({status:404,body:''});});
 await mock.open();
 const card=page.locator('.active-panel .cyber-card').first();
 await expect(card.locator('.face-printed-image')).toHaveAttribute('src',artwork);await loadedImages(card.locator('.face-printed-image'));
 await expect(card.locator('.face-printed-stats')).toContainText('ATK 0');await expect(card.locator('.face-printed-stats')).toContainText('DEF 7');
 mock.source.current_attack=12;mock.source.current_hp=17;mock.refreshCards();
 await expect(card.locator('.face-printed-stats')).toContainText('ATK 12');await expect(card.locator('.face-hp')).toContainText('17 / 120');
 expect(missingImageRequests).toBe(1);
 expect(mock.submissions).toEqual([]);
});

for (const viewport of [{width:1672,height:941},{width:390,height:844}]) {
 test(`zero, one and two skills preserve artwork and icon size at ${viewport.width}px`,async({page})=>{
  await page.setViewportSize(viewport);
  const mock=await mockPlayerBattle(page);
  const one=mock.source,zero=mock.cards.find(card=>card.player==='p1'&&card.zone==='active'&&card.id!==one.id);
  const two={...one,id:'20000000-0000-4000-8000-000000000061',slot:3,name:'Dua Skill',image_url:artwork};
  Object.assign(one,{name:'Inferno Dragon',card_code:'INFERNO_DRAGON',card_kind:'fusion',origin_type:'fusion',level:1,image_url:artwork});
  Object.assign(zero,{name:'Thunder Beast',card_code:'THUNDER_BEAST',card_kind:'fusion',level:1,image_url:artwork});
  Object.assign(two,{card_kind:'fusion',level:1});mock.cards.push(two);
  const original=mock.skills.map(skill=>({...skill}));
  mock.skills.splice(0,mock.skills.length,{...original[0],name:'Dead Strok',icon:'✨'},...original.map((skill,i)=>({...skill,id:`skill-two-${i}`,battle_card_id:two.id,name:i?'A very long second skill name that must stay within the card':'Team Spirit'})));
  await mock.open();
  await expect(page.locator('.active-panel .face-skills').nth(0).locator('.face-skill-icon')).toHaveCount(1);
  await expect(page.locator('.active-panel .face-skills').nth(1).locator('.face-skill-icon')).toHaveCount(0);
  await expect(page.locator('.active-panel .face-skills').nth(2).locator('.face-skill-icon')).toHaveCount(2);
  // Remove presentation transforms only for measuring intrinsic layout, not sizing.
  await page.addStyleTag({content:'.active-panel .cyber-card {transform:none!important;animation:none!important}'});
  const metrics=await page.locator('.active-panel .arena-card-face').evaluateAll(cards=>cards.map(card=>{
   const bounds=el=>{const r=el.getBoundingClientRect();return {width:r.width,height:r.height,bottom:r.bottom,top:r.top}};
   return {card:bounds(card),art:bounds(card.querySelector('.face-art')),skills:bounds(card.querySelector('.face-skills')),hp:bounds(card.querySelector('.face-hp')),icons:[...card.querySelectorAll('.face-skill-icon')].map(bounds)};
  }));
  expect(Math.abs(metrics[0].icons[0].width-metrics[2].icons[0].width)).toBeLessThan(1);
  for(const result of metrics){
   expect(Math.abs(result.art.height-metrics[0].art.height)).toBeLessThan(1);
   expect(result.art.height/result.card.height).toBeGreaterThan(.38);
   expect(result.hp.bottom).toBeLessThanOrEqual(result.card.bottom);
   for(const icon of result.icons){expect(icon.width/result.card.width).toBeLessThan(.26);expect(icon.bottom).toBeLessThan(result.hp.top);}
  }
  await page.screenshot({path:`test-results/player-arena-skill-count-${viewport.width}.png`});
  const card=page.locator('.active-panel .cyber-card').first();await card.click();
  await expect(page.locator('.player-action-panel [data-action="special"]')).toContainText('1 skill');
  await page.locator('.player-action-panel [data-action="special"]').click();
  await expect(page.locator('.special-skill-tab')).toHaveCount(1);await expect(page.locator('.special-skill-tab')).toContainText('Dead Strok');
  await page.keyboard.press('Escape');
  mock.source.current_attack=0;mock.source.current_defense=19;mock.source.current_hp=36;mock.refreshCards();
  await expect(card.locator('.face-atk')).toContainText('0');await expect(card.locator('.face-def')).toContainText('19');await expect(card.locator('.face-hp')).toContainText('36 / 120');
  expect(mock.submissions).toEqual([]);
 });
}

async function trackSkillImages(page,selector){
 await loadedImages(page.locator(`${selector} img`));
 await page.evaluate(selector=>{
  const root=document.querySelector(selector);
  window.skillImageWatch={images:[...root.querySelectorAll('img')],removed:0};
  const originals=new Set(window.skillImageWatch.images);
  window.skillImageObserver=new MutationObserver(records=>{
   for(const record of records)for(const node of record.removedNodes){
    for(const img of originals)if(node===img||node.contains?.(img))window.skillImageWatch.removed++;
   }
  });
  window.skillImageObserver.observe(root,{childList:true,subtree:true});
 },selector);
}
async function expectStableSkillImages(page){
 expect(await page.evaluate(()=>({removed:window.skillImageWatch.removed,connected:window.skillImageWatch.images.every(img=>img.isConnected)}))).toEqual({removed:0,connected:true});
}

test('battle snapshot polling keeps skill images mounted even during slow and failed preview refreshes',async({page})=>{
 const mock=await mockPlayerBattle(page);let fail=false;
 await page.route(`${battleEndpoint}/rest/v1/battle_card_skills**`,async route=>{
  const id=new URL(route.request().url()).searchParams.get('battle_card_id')?.slice(3);
  const rows=structuredClone(mock.skills.filter(s=>s.battle_card_id===id));
  await new Promise(resolve=>setTimeout(resolve,250));
  return route.fulfill(fail?{status:503,json:{message:'Temporary failure'}}:{json:rows});
 });
 await mock.open();await expect(page.locator('.active-panel .face-skill-icon img')).toHaveCount(1);
 await trackSkillImages(page,'.active-panel');
 for(const hp of [169,168,167]){
  fail=hp===168;mock.source.current_hp=hp-100;mock.refreshCards();mock.patch({player1_hp:hp});
  await expect(page.locator('.arena-hud-own .hp-title')).toContainText(String(hp));
  await expect(page.locator('.active-panel .face-hp').first()).toContainText(`${hp-100} / 120`);
  await page.waitForTimeout(350);
  await expectStableSkillImages(page);
 }
 // Membership updates add new previews without clearing already visible ones.
 const added={...mock.source,id:'20000000-0000-4000-8000-000000000071',slot:3,name:'New card'};mock.cards.push(added);
 mock.skills.push({...mock.skills[0],id:'new-preview-skill',battle_card_id:added.id});mock.refreshCards();
 await expect(page.locator('.active-panel .face-skill-icon img')).toHaveCount(2);
 await expectStableSkillImages(page);expect(mock.submissions).toEqual([]);
 // A successful empty response still removes deleted skills.
 mock.skills.splice(0,mock.skills.length);mock.patch({player1_hp:166});
 await expect(page.locator('.active-panel .face-skill-icon')).toHaveCount(0);
});

test('same-card skill refresh preserves the open popup and selection while cooldown data updates',async({page})=>{
 const mock=await mockPlayerBattle(page);let fail=false;
 await page.route(`${battleEndpoint}/rest/v1/battle_card_skills**`,async route=>{
  const id=new URL(route.request().url()).searchParams.get('battle_card_id')?.slice(3);
  const rows=structuredClone(mock.skills.filter(s=>s.battle_card_id===id));
  await new Promise(resolve=>setTimeout(resolve,350));return route.fulfill(fail?{status:503,json:{message:'Temporary failure'}}:{json:rows});
 });
 await mock.open();await page.locator('.active-panel .cyber-card').first().click();
 await page.locator('.player-action-panel [data-action="special"]').click();
 const dialog=page.locator('.special-skill-modal');await dialog.locator('.special-skill-tab').first().click();
 await expect(dialog.locator('.special-skill-tab').first()).toHaveAttribute('aria-pressed','true');
 await trackSkillImages(page,'.special-skill-modal');
 mock.skills[0].cooldown_until_owner_turn=8;mock.patch({round:4});
 await expect(dialog.locator('.special-skill-tab').first()).toContainText('Tersedia setelah');
 await expect(dialog.locator('.special-skill-tab').first()).toHaveAttribute('aria-pressed','true');
 await expectStableSkillImages(page);
 await expect(dialog.getByRole('button',{name:'Gunakan Arc Rally'})).toBeDisabled();
 fail=true;mock.patch({round:5});
 await expect(dialog.getByRole('alert')).toContainText('belum berhasil diperbarui');
 await expect(dialog.getByRole('button',{name:'Gunakan Arc Rally'})).toBeDisabled();
 await expectStableSkillImages(page);
 fail=false;await dialog.getByRole('button',{name:'Muat ulang skill'}).click();
 await expect(dialog.getByRole('alert')).toHaveCount(0);
 await expect(dialog.locator('.special-skill-tab').first()).toContainText('Tersedia setelah');
 await expectStableSkillImages(page);expect(mock.submissions).toEqual([]);
});

test('opponent gallery keeps all skill icons through live snapshots and polling failures',async({page})=>{
 const mock=await mockPlayerBattle(page);let fail=false;
 const extra=mock.cards.find(c=>c.player==='p2'&&c.zone==='bench');extra.zone='active';extra.slot=2;
 for(const card of [mock.target,extra])mock.skills.push({...mock.skills[0],id:`enemy-${card.id}`,player:'p2',battle_card_id:card.id,name:`${card.name} Guard`});
 await page.route(`${battleEndpoint}/rest/v1/battle_card_skills**`,async route=>{
  const id=new URL(route.request().url()).searchParams.get('battle_card_id')?.slice(3);
  const rows=structuredClone(mock.skills.filter(s=>s.battle_card_id===id));
  await new Promise(resolve=>setTimeout(resolve,200));return route.fulfill(fail?{status:503,json:{message:'Temporary failure'}}:{json:rows});
 });
 await mock.open();await page.getByRole('button',{name:/Lihat kartu lawan/}).click();
 const gallery=page.locator('.inspection-roster');await expect(gallery.locator('.face-skill-icon img')).toHaveCount(2);
 await trackSkillImages(page,'.inspection-roster');
 for(const hp of [149,148]){
  mock.patch({player2_hp:hp});extra.current_hp=hp-100;mock.refreshCards();
  await expect(gallery.locator('.face-hp').last()).toContainText(`${hp-100} / 130`);
  await page.waitForTimeout(300);await expectStableSkillImages(page);
 }
 fail=true;
 await expect(page.locator('.inspection-error')).toBeVisible({timeout:20000});
 await expectStableSkillImages(page);
 fail=false;await page.getByRole('button',{name:'Coba lagi',exact:true}).click();
 await expect(page.locator('.inspection-error')).toHaveCount(0);
 await expectStableSkillImages(page);expect(mock.submissions).toEqual([]);
});
