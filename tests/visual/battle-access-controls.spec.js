import {test,expect} from '@playwright/test';
import {mockPlayerBattle,battleEndpoint} from '../fixtures/mockPlayerBattle.js';

test('RLS-hidden quiz round offers retry and recovers the original countdown instead of inventing a new timer',async({page})=>{
 const q='10000000-0000-4000-8000-000000000091',r='10000000-0000-4000-8000-000000000092';
 const mock=await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:q,current_question_round_id:r,question_time_limit_seconds:120});
 const start=Date.now()-20000;let visible=false;
 await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:visible?{id:r,battle_id:mock.battle.id,question_id:q,status:'active',created_at:new Date(start).toISOString(),round_number:2}:null}));
 await page.route(`${battleEndpoint}/rest/v1/coding_questions*`,route=>route.fulfill({json:{id:q,question:'Berapa hasil 1 + 1?',question_type:'choice',option_a:'2',option_b:'1',option_c:'3',option_d:'4',duration_seconds:null}}));
 await page.goto('/play/GUIDEDEMO/p1');
 const timer=page.getByRole('timer',{name:'Waktu quiz'});
 await expect(page.getByText('Waktu kuis belum dapat dimuat. Coba muat ulang soal.',{exact:true})).toBeVisible();
 await expect(timer).toContainText('Timer belum tersedia');await expect(page.locator('.question-option')).toHaveCount(0);expect(mock.submissions).toHaveLength(0);
 visible=true;await page.getByRole('button',{name:'Coba muat ulang soal'}).click();
 await expect(page.locator('.question-option')).toHaveCount(4);await expect(timer).toContainText(/\d+ detik/);
 const seconds=async()=>Number((await timer.locator('strong').textContent()).match(/\d+/)?.[0]);
 const before=await seconds();expect(before).toBeGreaterThan(70);expect(before).toBeLessThanOrEqual(100);
 await expect.poll(seconds).toBeLessThan(before);
 await page.reload();await expect(timer).toContainText(/\d+ detik/);expect(await seconds()).toBeLessThanOrEqual(before);
 await page.screenshot({path:'test-results/quiz-clock-player.png'});
 await page.goto('/battle/GUIDEDEMO?layout=stadium');await expect(timer).toContainText(/\d+ detik/);expect(await seconds()).toBeLessThanOrEqual(before);
 await page.screenshot({path:'test-results/quiz-clock-public.png'});
});

test('public quiz reports a missing round clock rather than staying on preparing forever',async({page})=>{
 await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:'10000000-0000-4000-8000-000000000091',current_question_round_id:'10000000-0000-4000-8000-000000000092'});
 await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:null}));
 await page.goto('/battle/GUIDEDEMO?layout=stadium');
 await expect(page.getByRole('timer',{name:'Waktu quiz'})).toContainText('Timer belum tersedia');
 await expect(page.locator('.public-quiz-display')).toContainText('Waktu kuis belum dapat dimuat');
});

test('phone player can retry a failed question load without losing the shared quiz timer',async({page})=>{
 await page.setViewportSize({width:390,height:844});
 const q='10000000-0000-4000-8000-000000000097',r='10000000-0000-4000-8000-000000000096';
 await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:q,current_question_round_id:r,question_time_limit_seconds:120});
 let fail=true;
 await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:{id:r,question_id:q,status:'active',created_at:new Date().toISOString(),round_number:6}}));
 await page.route(`${battleEndpoint}/rest/v1/coding_questions*`,route=>{
  const select=new URL(route.request().url()).searchParams.get('select');expect(select).toContain('block_config');expect(select).not.toContain('correct_answer');
  return fail?route.fulfill({status:403,json:{code:'42501',message:'permission denied for table coding_questions'}}):route.fulfill({json:{id:q,question:'Berapa hasil repeat 3 dengan move 10?',question_type:'choice',option_a:'30',option_b:'10',option_c:'13',option_d:'3',duration_seconds:120}});
 });
 await page.goto('/play/GUIDEDEMO/p1');await expect(page.getByRole('button',{name:'Coba muat ulang soal'})).toBeVisible();
 fail=false;await page.getByRole('button',{name:'Coba muat ulang soal'}).click();await expect(page.locator('.question-option')).toHaveCount(4);
 await expect(page.getByRole('timer',{name:'Waktu quiz'})).not.toContainText('Menyiapkan');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});

test('QR player entry validates short codes locally and accepts six characters with pasted separators',async({page})=>{
 await mockPlayerBattle(page);
 await page.addInitScript(()=>sessionStorage.removeItem('tbc:player:GUIDEDEMO:p1'));
 const requests=[];page.on('request',request=>{if(request.url().endsWith('/redeem_battle_player_code'))requests.push(request.postDataJSON());});
 await page.goto('/play/GUIDEDEMO/p1');
 const input=page.getByLabel('Kode pribadi pemain');
 await expect(input).toHaveAttribute('placeholder','K7M4Q9');
 await input.fill('K7M4Q');await page.getByRole('button',{name:'Masuk sebagai Player 1'}).click();
 await expect(page.getByRole('alert')).toContainText('6 karakter');expect(requests).toHaveLength(0);
 await input.fill('k7m-4q9');await page.getByRole('button',{name:'Masuk sebagai Player 1'}).click();
 await expect(page.locator('.player-action-panel')).toBeVisible();
 expect(requests).toEqual([{p_access_code:'K7M4Q9',p_code:'GUIDEDEMO',p_player:'p1'}]);
});

test('copied player URL and URL token do not authorize a new tab; private code is side-bound',async({page})=>{
 const mock=await mockPlayerBattle(page);
 await page.addInitScript(()=>{if(!sessionStorage.getItem('tbc:test:logged-out:p1')){sessionStorage.removeItem('tbc:player:GUIDEDEMO:p1');sessionStorage.setItem('tbc:test:logged-out:p1','1');}});
 await page.goto('/play/GUIDEDEMO/p1?token=demo-player-one');
 await expect(page.getByRole('heading',{name:'Masuk ke battle-mu.'})).toBeVisible();
 await expect(page).toHaveURL(/\/play\/GUIDEDEMO\/p1$/);
 await expect(page.locator('.player-action-panel')).toHaveCount(0);
 await page.getByLabel('Kode pribadi pemain').fill('444455556666');await page.getByRole('button',{name:'Masuk sebagai Player 1'}).click();
 await expect(page.getByRole('alert')).toContainText('Kode pribadi tidak valid');
 await page.getByLabel('Kode pribadi pemain').fill('111122223333');await page.getByRole('button',{name:'Masuk sebagai Player 1'}).click();
 await expect(page.locator('.player-action-panel')).toBeVisible();
 expect(mock.submissions).toHaveLength(0);
 await page.reload();await expect(page.locator('.player-action-panel')).toBeVisible();
 await page.goto('/battle/GUIDEDEMO?layout=stadium');await expect(page.locator('.public-battle-page')).toBeVisible();
 expect(await page.evaluate(()=>location.search.includes('token'))).toBe(false);
});

test('teacher pause blocks actions and freezes countdown; resume retains remaining time; revoked device must reenter code',async({page})=>{
 const mock=await mockPlayerBattle(page);await mock.open();
 const left=30;mock.patch({teacher_paused:true,teacher_paused_at:new Date().toISOString(),turn_deadline_at:new Date(Date.now()+left*1000).toISOString(),teacher_pause_reason:'Mengganti pembaca kartu'});
 await expect(page.getByRole('status').filter({hasText:/Pertandingan dijeda (Host|guru)/})).toBeVisible();
 await expect(page.locator('.player-action-panel')).toContainText('Pertandingan dijeda guru');
 const clock=page.locator('.turn-countdown b');
 const text=await clock.textContent();await page.waitForTimeout(1200);await expect(clock).toHaveText(text);
 expect(mock.submissions).toHaveLength(0);
 mock.patch({teacher_paused:false,teacher_paused_at:null,turn_deadline_at:new Date(Date.now()+left*1000).toISOString()});
 await expect(page.locator('.battle-pause-notice')).toHaveCount(0);
 mock.patch({player1_token:'replacement-token'});
 await expect(page.getByRole('heading',{name:'Masuk ke battle-mu.'})).toBeVisible({timeout:16000});
 expect(await page.evaluate(()=>sessionStorage.getItem('tbc:player:GUIDEDEMO:p1'))).toBeNull();
});

test('public battle code only opens spectator; player code opens assigned player without URL credential',async({page})=>{
 await mockPlayerBattle(page);await page.goto('/play');
 await page.getByRole('button',{name:'Tonton battle',exact:true}).click();
 await page.locator('input[required]').fill('GUIDEDEMO');await page.getByRole('button',{name:'Tonton pertandingan →'}).click();
 await expect(page).toHaveURL(/\/battle\/GUIDEDEMO$/);
 await page.goto('/play');await page.getByRole('button',{name:'Kode pribadi pemain',exact:true}).click();
 await expect(page.locator('input[required]')).toHaveAttribute('placeholder','6 karakter · contoh K7M4Q9');
 await page.locator('input[required]').fill('d6m 8r9');await page.getByRole('button',{name:'Masuk ke game →'}).click();
 await expect(page).toHaveURL(/\/play\/GUIDEDEMO\/p2$/);
 await expect(page.locator('.player-action-panel')).toBeVisible();
});

test('teacher can pause/resume, reset private access, export history and confirm result from Battle History',async({page})=>{
 const {mockGameSetup}=await import('../fixtures/mockGameSetup.js');const {battleEndpoint}=await import('../fixtures/mockPlayerBattle.js');await mockGameSetup(page);
 await page.routeWebSocket('**',socket=>socket.close());
 const battle={id:'10000000-0000-4000-8000-000000000045',code:'TEACHERQA',status:'battle',round:1,total_rounds:10,player1_name:'Alya',player2_name:'Raka',is_active:true,created_at:new Date().toISOString(),active_until:'2099-01-01T00:00:00Z'};
 const calls=[],events=[{id:1,type:'attack',source_player:'p1',created_at:new Date().toISOString(),payload:{message:'Coby menyerang Tochi'}}];
 await page.route(`${battleEndpoint}/rest/v1/**`,async route=>{
 const req=route.request(),resource=new URL(req.url()).pathname.split('/').at(-1);
 if(resource==='profiles'){await route.fallback();return;}
 if(resource==='battle_sessions')return route.fulfill({json:[battle]});
 if(resource==='admin_battle_history')return route.fulfill({json:{rows:[{...battle,can_delete:battle.status==='finished'}],total:1,page:1,page_size:10,summary:{total:1,active:battle.status==='finished'?0:1,finished:battle.status==='finished'?1:0,deletable:battle.status==='finished'?1:0}}});
 if(resource==='admin_battle_access')return route.fulfill({json:{player1_access_code:'111122223333',player2_access_code:'444455556666'}});
 if(resource==='battle_events'){expect(new URL(req.url()).searchParams.get('select')).toContain('source_player');return route.fulfill({json:events});}
 if(resource==='teacher_reset_battle_access'){calls.push(req.postDataJSON());return route.fulfill({json:{ok:true,player1_access_code:'K7M4Q9',player2_access_code:'444455556666'}});}
 if(resource==='teacher_control_battle'){const body=req.postDataJSON();calls.push(body);Object.assign(battle,body.p_action==='pause'?{teacher_paused:true}:body.p_action==='resume'?{teacher_paused:false}:{status:'finished',winner:body.p_winner});return route.fulfill({json:{ok:true,battle}});}
 return route.fulfill({json:[]});
 });
 await page.goto('/admin/battle-history');await page.getByRole('button',{name:'Detail',exact:true}).first().click();
 const panel=page.getByRole('region',{name:'Kontrol guru'});await expect(panel).toBeVisible();
 await panel.getByRole('button',{name:'Ⅱ Jeda battle'}).click();await expect(panel.getByRole('button',{name:'▶ Lanjutkan battle'})).toBeVisible();
 await panel.getByRole('button',{name:'▶ Lanjutkan battle'}).click();
 await panel.getByText('Bantu pemain tersambung kembali / ganti perangkat',{exact:true}).click();await panel.getByRole('button',{name:'Perbarui akses Player 1'}).click();
 await panel.getByRole('button',{name:'Ya, buat kode baru'}).click();await expect(page.locator('.detail-player-copy code').first()).toHaveText('K7M4Q9');
 await panel.getByText('Riwayat aksi · 1 terbaru',{exact:true}).click();await expect(panel).toContainText('Coby menyerang Tochi');
 const download=page.waitForEvent('download');await panel.getByRole('button',{name:'Unduh CSV'}).click();expect((await download).suggestedFilename()).toBe('battle-TEACHERQA-riwayat.csv');
 await panel.getByRole('button',{name:'Akhiri pertandingan…'}).click();await expect(panel.getByRole('button',{name:'Konfirmasi akhiri battle'})).toBeDisabled();
 await panel.getByLabel('Catatan guru').fill('Pilot dihentikan guru');await panel.getByRole('button',{name:'Konfirmasi akhiri battle'}).click();await expect(panel.getByRole('heading',{name:'Kelola pertandingan'})).toBeVisible();await expect(panel.locator('header>b')).toHaveText('Selesai');
 expect(calls.map(c=>c.p_action??c.p_player)).toEqual(['pause','resume','p1','finish']);expect(calls.at(-1).p_winner).toBe('draw');
});

test('public live viewer follows verified player rows and ignores forged broadcasts',async({page})=>{
 const mock=await mockPlayerBattle(page);await page.goto('/battle/GUIDEDEMO?layout=stadium');await expect(page.locator('.tbc-stage')).toBeVisible();
 const state={viewerZone:'bench',viewerIndex:0,viewerTurn:mock.battle.turn_index,updatedAt:Date.now()};
 mock.spoofBroadcast('p1',state);await page.waitForTimeout(400);await expect(page.locator('.public-live-viewer')).toHaveCount(0);
 mock.publishUi('p1',state);await expect(page.getByRole('region',{name:'Aktivitas pemain secara live'})).toContainText('Membuka Bench');
 mock.patch({teacher_paused:true,teacher_paused_at:new Date().toISOString()});await expect(page.locator('.public-live-viewer')).toHaveCount(0);await expect(page.locator('.battle-pause-notice')).toBeVisible();
});
for(const mode of ['player','public'])test(`paused quiz clock and answer lock are visible on ${mode} screen`,async({page})=>{
 const q='10000000-0000-4000-8000-000000000099',r='10000000-0000-4000-8000-000000000098';const start=Date.now()-10000,paused=new Date().toISOString();
 await mockPlayerBattle(page,{status:'question',question_active:true,current_question_id:q,current_question_round_id:r,question_time_limit_seconds:60,teacher_paused:true,teacher_paused_at:paused});
 await page.route(`${battleEndpoint}/rest/v1/battle_question_rounds*`,route=>route.fulfill({json:{id:r,battle_id:'10000000-0000-4000-8000-000000000001',question_id:q,round_number:3,status:'active',created_at:new Date(start).toISOString(),timer_paused_at:paused}}));
 await page.route(`${battleEndpoint}/rest/v1/coding_questions*`,route=>route.fulfill({json:{id:q,question:'Apa hasil 2 + 2?',question_type:'choice',option_a:'4',option_b:'5',option_c:'6',option_d:'7',duration_seconds:60}}));
 await page.goto(mode==='player'?'/play/GUIDEDEMO/p1':'/battle/GUIDEDEMO?layout=stadium');
 const timer=page.getByRole('timer',{name:'Waktu quiz'});await expect(timer).toContainText('Dijeda · 50 detik');await page.waitForTimeout(1200);await expect(timer).toContainText('Dijeda · 50 detik');
 if(mode==='player'){await expect(page.locator('.question-option')).toHaveCount(4);for(const button of await page.locator('.question-option').all())await expect(button).toBeDisabled();}
});
