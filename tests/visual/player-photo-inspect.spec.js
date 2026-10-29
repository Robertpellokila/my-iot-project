import {test,expect} from '@playwright/test';
import {battleEndpoint,mockPlayerBattle} from '../fixtures/mockPlayerBattle.js';
const photo='/images/tutorial/player-battle-guide.jpg';
const avatarRequests=[];
test.beforeEach(()=>{avatarRequests.length=0;});
for(const side of ['p1','p2'])test(`first entry and reload use ${side} setup photo without an avatar prompt`,async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const mock=await mockPlayerBattle(page,{player1_setup_photo_url:photo,player2_setup_photo_url:photo,player1_avatar_url:'🐻',player2_avatar_url:'🐼'});
 await page.route(`${battleEndpoint}/rest/v1/rpc/set_battle_player_avatar`,route=>{avatarRequests.push(route.request().postDataJSON());return route.fulfill({json:{ok:true,avatar:'🐻'}});});
 await page.goto(`/play/GUIDEDEMO/${side}?token=${side==='p1'?'demo-player-one':'demo-player-two'}`);
 const identity=page.locator('.player-avatar');await expect(identity.locator('img')).toHaveAttribute('src',photo);await expect(page.locator('.avatar-picker-overlay')).toHaveCount(0);
 await identity.click();await expect(page.locator('.avatar-picker-overlay')).toHaveCount(0);expect(avatarRequests).toEqual([]);
 await page.reload();await expect(identity.locator('img')).toHaveAttribute('src',photo);await expect(page.locator('.avatar-picker-overlay')).toHaveCount(0);
 mock.patch({player1_avatar_url:'🐱',player2_avatar_url:'🐰'});await expect(identity.locator('img')).toHaveAttribute('src',photo);expect(errors).toEqual([]);
});
test('legacy setup photo works and broken images fall back to initials without forcing an emoji',async({page})=>{
 await page.route('**/missing-player-photo.webp',route=>route.fulfill({status:404,body:''}));const mock=await mockPlayerBattle(page,{player1_avatar_url:'/missing-player-photo.webp'});await mock.open();
 await expect(page.locator('.player-avatar')).toHaveText('A');await expect(page.locator('.avatar-picker-overlay')).toHaveCount(0);await expect(page.locator('.player-avatar')).not.toContainText('missing-player');
});
test('emoji selection remains available when setup has no photo',async({page})=>{
 const mock=await mockPlayerBattle(page,{player1_avatar_url:null});await page.route(`${battleEndpoint}/rest/v1/rpc/set_battle_player_avatar`,route=>{const body=route.request().postDataJSON();avatarRequests.push(body);mock.patch({player1_avatar_url:body.p_avatar});return route.fulfill({json:{ok:true,avatar:body.p_avatar}});});
 await page.goto('/play/GUIDEDEMO/p1?token=demo-player-one');await expect(page.locator('.avatar-picker-overlay')).toBeVisible();await page.getByRole('radio',{name:'Pilih avatar 🐼'}).click();await page.getByRole('button',{name:'Pakai avatar ini'}).click();await expect(page.locator('.avatar-picker-overlay')).toHaveCount(0);await expect(page.locator('.player-avatar')).toHaveText('🐼');expect(avatarRequests).toHaveLength(1);
});
test('public and player share the setup photo even if an emoji was previously selected',async({page})=>{
 await mockPlayerBattle(page,{player1_setup_photo_url:photo,player2_setup_photo_url:photo,player1_avatar_url:'🐻',player2_avatar_url:'🐼'});await page.goto('/battle/GUIDEDEMO?layout=stadium');await expect(page.locator('.tbc-hud.p1 .tbc-custom-portrait,.tbc-hud.p2 .tbc-custom-portrait')).toHaveCount(2);
 for(const image of await page.locator('.tbc-custom-portrait').all())await expect(image).toHaveAttribute('src',photo);
});
async function inspection(page,{slow=false,fail=false}={}){
 const mock=await mockPlayerBattle(page,{player2_owner_turn:2});const extra=mock.cards.find(card=>card.player==='p2'&&card.zone==='bench');if(extra){extra.zone='active';extra.slot=2;}let reject=fail;const requests=[];
 await page.route(`${battleEndpoint}/rest/v1/battle_card_skills**`,async route=>{
  const url=new URL(route.request().url());const id=url.searchParams.get('battle_card_id')?.slice(3),target=mock.cards.find(card=>card.id===id&&card.player==='p2');
  if(!target)return route.fallback();requests.push(url);
  if(slow&&id===mock.target.id)await new Promise(r=>setTimeout(r,700));
  if(reject){reject=false;return route.fulfill({status:400,json:{message:'temporarily unavailable'}});}
  return route.fulfill({json:[{id:`s1-${id}`,battle_id:mock.battle.id,battle_card_id:id,player:'p2',name:`${target.name} Guard`,description:'Beri Shield 10 pada diri. CD 2.',icon:photo,limits:{action_points:2,cooldown_turns:2},cooldown_until_owner_turn:3,priority:1},{id:`s2-${id}`,battle_id:mock.battle.id,battle_card_id:id,player:'p2',name:`${target.name} Strike`,description:'Serang kartu Active lawan.',icon:'⚔',limits:{action_points:1,cooldown_turns:0},priority:2}]});
 });return {...mock,skillRequests:requests};
}
test('opponent inspection shows live stats and both skills for only Active enemy cards without sending actions',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const mock=await inspection(page);await mock.open();await page.locator('.cyber-card').first().click();
 const source=await page.locator('.command-card strong').innerText();await page.getByRole('button',{name:/Lihat kartu lawan/}).click();const dialog=page.getByRole('dialog',{name:'Kartu Active lawan'});await expect(dialog).toBeVisible();await expect(dialog.locator('.inspection-card-title h3')).toHaveText(mock.target.name);
 await expect(dialog.locator('.inspection-skill')).toHaveCount(2);await expect(dialog.locator('.inspection-skill').first()).toContainText('2 AP');await expect(dialog.locator('.inspection-skill').first()).toContainText('2 giliran pemilik');await expect(dialog.locator('.inspection-skill img')).toHaveAttribute('src',photo);
 const other=mock.cards.find(c=>c.player==='p2'&&c.zone==='active'&&c.id!==mock.target.id);await dialog.locator('.inspection-roster button').filter({hasText:other.name}).click();await expect(dialog.locator('.inspection-card-title h3')).toHaveText(other.name);await expect(dialog.locator('.inspection-skills')).toContainText(`${other.name} Guard`);
 other.current_hp=17;other.attack=0;other.defense=8;mock.refreshCards();await expect(dialog.locator('.inspection-stats')).toContainText('17');await expect(dialog.locator('.inspection-stats')).toContainText('ATK0');
 await page.screenshot({path:'test-results/opponent-inspection-desktop.png'});await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);await expect(page.getByRole('button',{name:/Lihat kartu lawan/})).toBeFocused();await expect(page.locator('.command-card strong')).toHaveText(source);
 expect(mock.submissions).toEqual([]);expect(mock.battle.player1_action_points).toBe(3);expect(mock.skillRequests.every(url=>url.searchParams.get('player')==='eq.p2'&&url.searchParams.get('battle_id')===`eq.${mock.battle.id}`)).toBe(true);expect(errors).toEqual([]);
});
test('inspection handles retries and updates when all enemy cards move out of Active',async({page})=>{
 const mock=await inspection(page,{fail:true});await mock.open();await page.getByRole('button',{name:/Lihat kartu lawan/}).click();const dialog=page.getByRole('dialog',{name:'Kartu Active lawan'});await expect(dialog.getByRole('alert')).toContainText('belum dapat dimuat');await dialog.getByRole('button',{name:'Coba lagi'}).click();await expect(dialog.locator('.inspection-skill')).toHaveCount(2);
 for(const card of mock.cards.filter(c=>c.player==='p2'))card.zone='bench';mock.refreshCards();await expect(dialog).toContainText('Lawan belum memiliki kartu Active');await expect(dialog.locator('.inspection-skill')).toHaveCount(0);expect(mock.submissions).toEqual([]);
});
test('rapid card switching ignores stale skill responses and quiz interrupts inspection',async({page})=>{
 const mock=await inspection(page,{slow:true});await mock.open();const stale=page.waitForResponse(r=>r.url().includes('battle_card_skills')&&r.url().includes(mock.target.id));await page.getByRole('button',{name:/Lihat kartu lawan/}).click();const dialog=page.getByRole('dialog',{name:'Kartu Active lawan'});const last=mock.cards.filter(c=>c.player==='p2'&&c.zone==='active').at(-1);await dialog.locator('.inspection-roster button').filter({hasText:last.name}).click();await expect(dialog.locator('.inspection-skills')).toContainText(`${last.name} Guard`);await stale;await expect(dialog.locator('.inspection-skills')).not.toContainText(`${mock.target.name} Guard`);
 mock.patch({question_active:true,status:'question'});await expect(dialog).toHaveCount(0);expect(mock.submissions).toEqual([]);
});
test('inspection is usable on the opponent turn and mobile without overflow',async({page})=>{
 await page.setViewportSize({width:390,height:844});const mock=await inspection(page);mock.battle.current_turn='p2';mock.battle.player1_action_points=0;await mock.open();await page.getByRole('button',{name:/Lihat kartu lawan/}).click();const dialog=page.getByRole('dialog',{name:'Kartu Active lawan'});await expect(dialog.locator('.inspection-skill')).toHaveCount(2);expect(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);
 await dialog.getByRole('button',{name:'Kembali ke battle'}).scrollIntoViewIfNeeded();await expect(dialog.getByRole('button',{name:'Kembali ke battle'})).toBeInViewport();await page.screenshot({path:'test-results/opponent-inspection-mobile.png'});await dialog.getByRole('button',{name:'Kembali ke battle'}).click();expect(mock.submissions).toEqual([]);expect(mock.battle.player1_action_points).toBe(0);
});

test('Game Setup uploads two photos and saves dedicated photo URLs with the battle',async({page})=>{
 const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'photo-qa@example.invalid',app_metadata:{provider:'email'},user_metadata:{},created_at:'2026-01-01T00:00:00Z'};
 const token=`${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test`;
 await page.addInitScript(({key,user,token})=>localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'test',expires_at:Math.floor(Date.now()/1000)+3600,user})),{key:`sb-${new URL(battleEndpoint).hostname.split('.')[0]}-auth-token`,user,token});
 const saved=[],uploads=[];
 await page.route(`${battleEndpoint}/**`,route=>{
  const request=route.request(),url=new URL(request.url()),resource=url.pathname.split('/').at(-1);
  if(resource==='user')return route.fulfill({json:user});if(resource==='profiles')return route.fulfill({json:{...user,role:'admin'}});
  if(url.pathname.startsWith('/storage/v1/object/card-images/')){uploads.push(url.pathname);return route.fulfill({json:{Key:url.pathname.split('/object/')[1]}});}
  if(resource==='coding_questions')return route.fulfill({json:[],headers:{'content-range':'0-0/10','access-control-expose-headers':'content-range'}});
  if(resource==='battle_sessions'&&request.method()==='POST'){const body=request.postDataJSON();saved.push(body);return route.fulfill({json:{...body,id:'10000000-0000-4000-8000-000000000044',player1_token:'qa-one',player2_token:'qa-two'}});}
  if(resource==='bind_battle_readers')return route.fulfill({json:{ok:true}});
  return route.fulfill({json:[]});
 });
 await page.goto('/admin/setup');await page.getByLabel('Hapus background otomatis Player 1',{exact:true}).uncheck();await page.getByLabel('Hapus background otomatis Player 2',{exact:true}).uncheck();await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles('public/images/tutorial/player-battle-guide.jpg');await page.getByLabel('Upload foto Player 2',{exact:true}).setInputFiles('public/images/tutorial/public-battle-guide.jpg');
 await expect(page.locator('.setup-player-photo.p1')).toHaveAttribute('aria-busy','false');await expect(page.locator('.setup-player-photo.p2')).toHaveAttribute('aria-busy','false');
 await page.locator('button.create-button').click();await expect.poll(()=>saved.length).toBe(1);expect(uploads).toHaveLength(2);
 expect(saved[0].player1_setup_photo_url).toMatch(/card-images\/player-avatars\//);expect(saved[0].player2_setup_photo_url).toMatch(/card-images\/player-avatars\//);
 expect(saved[0].player1_avatar_url).toBe(saved[0].player1_setup_photo_url);expect(saved[0].player2_avatar_url).toBe(saved[0].player2_setup_photo_url);expect(saved[0].player1_setup_photo_url).not.toBe(saved[0].player2_setup_photo_url);
 await expect(page.getByRole('heading',{name:'Ready to Battle'})).toBeVisible();
});

test('the full battle query keeps Bench and Graveyard out of the opponent Active roster',async({page})=>{
 const mock=await inspection(page);mock.cards.push({...mock.target,id:'20000000-0000-4000-8000-000000000099',name:'Enemy Graveyard',zone:'graveyard',current_hp:0});
 await page.route(`${battleEndpoint}/rest/v1/battle_cards**`,route=>{const url=new URL(route.request().url());if(url.searchParams.has('zone'))return route.fallback();return route.fulfill({json:mock.cards});});
 await mock.open();await page.getByRole('button',{name:/Lihat kartu lawan/}).click();const dialog=page.getByRole('dialog',{name:'Kartu Active lawan'});await expect(dialog.locator('.inspection-roster button')).toHaveCount(2);await expect(dialog).not.toContainText('Enemy Graveyard');expect(mock.submissions).toEqual([]);
});
