import { test, expect } from '@playwright/test';
import { mockPlayerBattle, battleEndpoint } from '../fixtures/mockPlayerBattle.js';

const artwork='/images/card-generator/tochi-sprout-keeper-v1.png';
async function arena(page) {
  const mock=await mockPlayerBattle(page);
  for(const card of mock.cards) card.image_url=artwork;
  const other={...mock.target,id:'20000000-0000-4000-8000-000000000072',slot:2,name:'Pico',image_url:artwork};
  mock.cards.push(other);
  return {...mock,other};
}
async function allImagesLoaded(page) {
  await expect.poll(()=>page.locator('.tbc-featured-card img').evaluateAll(imgs=>imgs.length>0&&imgs.every(img=>img.complete&&img.naturalWidth>0))).toBe(true);
}
for(const layout of ['center_duel','top_bottom','side_panel','stadium','cinematic']) test(`${layout} preserves readable HUD, live cards and spectator controls`,async({page})=>{
  await page.setViewportSize({width:1672,height:980});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const mock=await arena(page);await page.goto(`/battle/GUIDEDEMO?layout=${layout}`);
  await expect(page.locator(`.tbc-layout-${layout}`)).toBeVisible();
  await expect(page.locator('.tbc-stadium-backdrop')).toHaveCSS('background-image',/stadium-v1/);
  await expect(page.locator('.tbc-hud.p1')).toContainText('170 / 200');
  await expect(page.locator('.tbc-hud.p2')).toContainText('150 / 200');
  await expect(page.locator('.tbc-hud.p1 .tbc-ap')).toContainText('3 / 3');
  await expect(page.locator('.tbc-hud.p1 .tbc-ultimate')).toContainText('40%');
  await expect(page.locator('.tbc-hud.is-turn')).toHaveCount(1);
  await expect(page.locator('.tbc-round')).toHaveText('ROUND 3 / 10');
  await expect(page.locator('.tbc-hero.p1 .face-skill')).toHaveCount(2);
  await allImagesLoaded(page);
  for(const side of ['p1','p2']) {
    const hero=await page.locator(`.tbc-hero.${side}`).boundingBox(), hud=await page.locator(`.tbc-hud.${side}`).boundingBox();
    expect(hero.y+hero.height<hud.y || hero.y>hud.y+hud.height).toBe(true);
    if(layout!=='cinematic') {
      await expect(page.locator(`.tbc-roster.${side} .tbc-zone`)).toHaveCount(3);
      const zones=await page.locator(`.tbc-roster.${side} .tbc-zone`).evaluateAll(nodes=>nodes.map(el=>({width:el.clientWidth,scroll:el.scrollWidth})));
      for(const zone of zones)expect(zone.scroll).toBeLessThanOrEqual(zone.width+1);
    }
  }
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:`test-results/public-arena-${layout}.png`});
  // Changing a local camera does not submit a battle action.
  await page.getByLabel('Layout penonton',{exact:true}).selectOption(layout==='cinematic'?'center_duel':'cinematic');
  await expect(page.locator(`.tbc-layout-${layout==='cinematic'?'center_duel':'cinematic'}`)).toBeVisible();
  expect(mock.submissions).toEqual([]);expect(errors).toEqual([]);
});

test('current-turn source, target and live piles switch immediately and reject off-turn/stale selections',async({page})=>{
  const mock=await arena(page);await page.goto('/battle/GUIDEDEMO');
  await expect(page.locator('.tbc-stage')).toBeVisible();
  const second=mock.cards.find(c=>c.player==='p1'&&c.zone==='active'&&c.id!==mock.source.id);
  let at=Date.now();
  const record=(cardId,turn=5)=>({cardId,turn,at:++at});
  mock.publishUi('p1',{focus:{selected:record(second.id),target:record(mock.other.id)},updatedAt:++at});
  await expect(page.locator('.tbc-hero.p1 [data-featured]')).toHaveAttribute('data-card-id',second.id);
  await expect(page.locator('.tbc-hero.p2 [data-featured]')).toHaveAttribute('data-card-id',mock.other.id);
  mock.publishUi('p2',{focus:{selected:record(mock.target.id),target:record(mock.source.id)},updatedAt:++at});
  await expect(page.locator('.tbc-hero.p2 [data-featured]')).toHaveAttribute('data-card-id',mock.other.id);
  mock.patch({current_turn:'p2',turn_index:6,player1_action_points:0,player2_action_points:3});
  await expect(page.locator('.tbc-hud.p2')).toHaveClass(/is-turn/);
  await expect(page.locator('.tbc-hero.p2 [data-featured]')).toHaveAttribute('data-card-id',mock.target.id);
  mock.publishUi('p2',{focus:{selected:record(mock.other.id,6),target:record(second.id,6)},updatedAt:++at});
  await expect(page.locator('.tbc-hero.p2 [data-featured]')).toHaveAttribute('data-card-id',mock.other.id);
  mock.publishUi('p1',{viewerZone:'graveyard',viewerTurn:6,viewerIndex:0,updatedAt:++at});
  await expect(page.locator('.public-live-viewer')).toHaveCount(0);
  mock.publishUi('p2',{viewerZone:'bench',viewerTurn:6,viewerIndex:0,updatedAt:++at});
  await expect(page.locator('.public-live-viewer')).toContainText('Raka');
  await expect(page.locator('.public-live-viewer')).toHaveCSS('border-image-source',/panel-frame/);
  await page.screenshot({path:'test-results/public-arena-live-viewer.png'});
  mock.patch({current_turn:'p1',turn_index:7});await expect(page.locator('.public-live-viewer')).toHaveCount(0);
});

test('Host pause freezes turn clock; live HP/AP and skill images survive repeated snapshots',async({page})=>{
  const now=Date.now();const mock=await arena(page);
  mock.patch({turn_deadline_at:new Date(now+10000).toISOString(),teacher_paused:true,teacher_paused_at:new Date(now).toISOString()});
  await page.goto('/battle/GUIDEDEMO');
  const timer=page.getByRole('timer',{name:'Waktu giliran'});
  await expect(timer).toContainText('10s');await page.waitForTimeout(1200);await expect(timer).toContainText('10s');
  await expect(page.locator('.battle-pause-notice')).toBeVisible();
  await allImagesLoaded(page);
  await page.locator('.tbc-hero.p1 .face-art img').evaluate(el=>window.artNode=el);
  for(let hp=119;hp>=117;hp--){mock.source.current_hp=hp;mock.refreshCards();await expect(page.locator('.tbc-hero.p1 .face-hp')).toContainText(`${hp} / 120`);}
  expect(await page.locator('.tbc-hero.p1 .face-art img').evaluate(el=>el===window.artNode)).toBe(true);
  mock.patch({player1_hp:130,player1_action_points:1});await expect(page.locator('.tbc-hud.p1')).toContainText('130 / 200');await expect(page.locator('.tbc-hud.p1 .tbc-ap')).toContainText('1 / 3');
  mock.patch({teacher_paused:false,turn_deadline_at:new Date(Date.now()+30000).toISOString()});
  await expect(timer).not.toContainText('10s');
});

test('verified skill choice follows the active player and clears at a turn change',async({page})=>{
  const mock=await arena(page);await page.goto('/battle/GUIDEDEMO');await expect(page.locator('.tbc-stage')).toBeVisible();
  const skillIntent={id:'pick-public',cardId:mock.source.id,phase:'choosing',turn:5,at:Date.now()};
  mock.publishUi('p1',{skillIntent,updatedAt:Date.now()});
  await expect(page.getByRole('region',{name:'Aksi skill langsung'})).toContainText('Alya');
  await expect(page.locator('.cinema-skill')).toHaveCount(2);
  await page.screenshot({path:'test-results/public-arena-skill.png'});
  mock.patch({current_turn:'p2',turn_index:6});await expect(page.locator('.skill-cinema')).toHaveCount(0);
});

test('spectator media, history and responsive layout remain usable',async({page})=>{
  const mock=await arena(page);await page.goto('/battle/GUIDEDEMO');await expect(page.locator('.tbc-stage')).toBeVisible();
  await page.locator('.fusion-history-trigger').click();await expect(page.getByRole('dialog',{name:'Fusion Timeline'})).toContainText('Belum ada Fusion');
  await page.getByRole('button',{name:'Tutup Fusion Timeline'}).click();
  await page.locator('.public-music summary').click();await expect(page.locator('.music-panel')).toBeVisible();await page.locator('.public-music summary').click();
  await page.locator('.public-sound-control').click();await expect(page.locator('.public-sound-control')).toContainText(/SOUND (ON|OFF)/);
  await page.getByRole('button',{name:'Tampilkan fullscreen TV'}).click();
  await expect(page.getByRole('button',{name:'Keluar dari fullscreen'})).toBeVisible();
  await page.getByRole('button',{name:'Keluar dari fullscreen'}).click();
  for(const size of [{width:1024,height:768},{width:844,height:390},{width:390,height:844}]) {
    await page.setViewportSize(size);await expect(page.locator('.tbc-stage')).toBeInViewport();
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
    await page.getByLabel('Layout penonton',{exact:true}).selectOption('side_panel');
    await page.screenshot({path:`test-results/public-arena-${size.width}.png`});
  }
  expect(mock.submissions).toEqual([]);
});

test('accepted attacks still animate between live cards and display authoritative damage',async({page})=>{
  const mock=await arena(page);await page.goto('/battle/GUIDEDEMO');await expect(page.locator('.tbc-stage')).toBeVisible();
  mock.publishEvent({id:301,type:'attack',source_player:'p1',target_player:'p2',card_id:mock.source.id,payload:{attack_mode:'targeted_card',attacker_card_id:mock.source.id,target_card_id:mock.other.id,damage:17,final_damage:17,target_hp_before:85,target_hp_after:68,base_attack:33,target_defense:8}});
  await expect(page.locator('.combat-overlay')).toBeVisible();
  await expect(page.locator('.tbc-hero.p2 [data-featured]')).toHaveAttribute('data-card-id',mock.other.id);
  await expect(page.locator('.tbc-action-toast')).toContainText('17 damage');
  // The impact must follow the promoted duel card, not its old roster thumbnail.
  await expect.poll(async()=>{
    const target=await page.locator('.tbc-hero.p2 [data-featured]').boundingBox();
    const center=await page.locator('.flying-attack-card').evaluate(el=>({x:parseFloat(el.style.getPropertyValue('--target-left'))+parseFloat(el.style.getPropertyValue('--card-width'))/2,y:parseFloat(el.style.getPropertyValue('--target-top'))+parseFloat(el.style.getPropertyValue('--card-height'))/2}));
    return Math.abs(center.x-target.x-target.width/2)<2 && Math.abs(center.y-target.y-target.height/2)<2;
  }).toBe(true);
  await expect(page.locator('.combat-overlay')).toHaveCount(0,{timeout:15000});
  expect(mock.submissions).toEqual([]);
});

test('full rosters keep all three zones readable and paginate larger graveyards',async({page})=>{
  await page.setViewportSize({width:1366,height:768});
  const mock=await arena(page);
  for(const side of ['p1','p2'])for(const zone of ['active','bench','graveyard']){
    let count=mock.cards.filter(c=>c.player===side&&c.zone===zone).length;
    for(;count<(zone==='graveyard'?8:4);count++) mock.cards.push({...mock.source,id:`${side}-${zone}-${count}`,name:`${zone} ${count+1}`,player:side,zone,slot:count+1,current_hp:zone==='graveyard'?0:100});
  }
  await page.goto('/battle/GUIDEDEMO?layout=stadium');await expect(page.locator('.tbc-stage')).toBeVisible();
  const grave=page.locator('.tbc-roster.p1 .zone-graveyard');
  await expect(grave.locator('.tbc-zone-heading')).toContainText('8');
  await grave.getByRole('button',{name:'Kartu berikutnya'}).click();await expect(grave.locator('.tbc-zone-pager')).toContainText('2 / 2');
  await expect(grave.getByRole('button',{name:'Kartu berikutnya'})).toBeDisabled();
  for(const zone of await page.locator('.tbc-zone').all())expect(await zone.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);
  await page.screenshot({path:'test-results/public-arena-full-stadium.png'});
  await page.getByLabel('Layout penonton',{exact:true}).selectOption('center_duel');
  await page.screenshot({path:'test-results/public-arena-full-center.png'});
});

test('public quiz keeps the shared frame, question and paused timer at desktop and phone sizes',async({page})=>{
  const now=Date.now(),q='10000000-0000-4000-8000-000000000099',r='10000000-0000-4000-8000-000000000098';
  const mock=await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:q,current_question_round_id:r,question_time_limit_seconds:60,teacher_paused:true,teacher_paused_at:new Date(now).toISOString()});
  await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:{id:r,battle_id:mock.battle.id,question_id:q,round_number:3,status:'active',created_at:new Date(now-10000).toISOString(),timer_paused_at:new Date(now).toISOString()}}));
  await page.route(`${battleEndpoint}/rest/v1/coding_questions*`,route=>route.fulfill({json:{id:q,question:'Apa hasil 2 + 2?',question_type:'choice',option_a:'4',option_b:'5',option_c:'6',option_d:'7',duration_seconds:60}}));
  await page.goto('/battle/GUIDEDEMO');
  const quiz=page.getByRole('region',{name:'Quiz live untuk penonton'});
  await expect(quiz).toHaveCSS('border-image-source',/panel-frame/);
  await expect(quiz.locator('.quiz-option')).toHaveCount(4);await expect(quiz.getByRole('timer')).toContainText('Dijeda · 50 detik');
  await page.screenshot({path:'test-results/public-arena-quiz.png'});
  await page.setViewportSize({width:390,height:844});
  await expect(quiz).toBeInViewport();expect(await quiz.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);
  await page.screenshot({path:'test-results/public-arena-quiz-phone.png'});
});
