import {test,expect} from '@playwright/test';
import {battleEndpoint,mockPlayerBattle} from '../fixtures/mockPlayerBattle.js';
const types=['knight','fire','water','forest','thunder','light','dark','ice'];
const rules=[...types.map(element=>({code:`synergy_${element}`,kind:'synergy',element,name:`${element} Synergy`,icon:'✧',description:'',effect_type:'shield_percent',effect_values:{2:30,3:45,4:60},min_cards:2,enabled:true,updated_at:'2026-10-25T01:00:00Z'})),...Array.from({length:6},(_,i)=>({code:`quiz_bonus_${i}`,kind:'quiz_bonus',element:null,name:`Bonus ${i+1}`,icon:i===0?'/images/tutorial/player-battle-guide.jpg':'✦',description:'Hadiah dari kuis.',effect_type:'heal_flat',effect_values:{1:10+i},min_cards:2,enabled:true,updated_at:'2026-10-25T01:00:00Z'}))];
const bonusRules=rules.filter(rule=>rule.kind==='quiz_bonus');
async function admin(page){
 const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'qa@example.invalid',app_metadata:{provider:'email'},user_metadata:{},created_at:'2026-01-01T00:00:00Z'};
 const token=`${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test`;
 await page.addInitScript(({key,user,token})=>localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'test-refresh',expires_at:Math.floor(Date.now()/1000)+3600,user})),{key:`sb-${new URL(battleEndpoint).hostname.split('.')[0]}-auth-token`,user,token});
 const saves=[],settings=[];
 await page.route(`${battleEndpoint}/**`,async route=>{
  const resource=new URL(route.request().url()).pathname.split('/').at(-1);
  if(resource==='user')return route.fulfill({json:user});
  if(resource==='profiles')return route.fulfill({json:{...user,role:'admin'}});
  if(resource==='battle_effect_catalog')return route.fulfill({json:rules});
  if(resource==='battle_reward_settings')return route.fulfill({json:{id:1,choice_count:3,updated_at:'2026-10-25T01:00:00Z'}});
  if(resource==='save_battle_effect_rule'){const {p_rule}=route.request().postDataJSON();saves.push(p_rule);return route.fulfill({json:{...p_rule,updated_at:'2026-10-26T01:00:00Z'}});}
  if(resource==='save_battle_reward_settings'){const data=route.request().postDataJSON();settings.push(data);return route.fulfill({json:{id:1,choice_count:data.p_choice_count,updated_at:'2026-10-26T01:00:00Z'}});}
  return route.fulfill({json:[]});
 });return {saves,settings};
}
async function quiz(page,count,{winner='p1',pending=false}={}){
 const round={id:'91000000-0000-4000-8000-000000000001',question_id:'92000000-0000-4000-8000-000000000001',round_number:1,status:'active',created_at:new Date().toISOString(),started_at:new Date().toISOString(),winner_player:pending?winner:null};
 const mock=await mockPlayerBattle(page,{question_active:true,status:'question',question_enabled:true,question_bonus_enabled:true,question_time_limit_seconds:60,current_question_id:round.question_id,current_question_round_id:round.id,quiz_bonus_rules_snapshot:bonusRules,synergy_rules_snapshot:rules.filter(r=>r.kind==='synergy')});
 const choices=bonusRules.slice(0,count).map(rule=>rule.code),selections=[],uses=[];let selected=null,deny=false;
 const pendingChoice=()=>({ok:true,pending:pending&&!selected&&winner==='p1',question_round_id:round.id,choices,winner_answer:0});
 await page.route(`${battleEndpoint}/rest/v1/**`,async route=>{
  const resource=new URL(route.request().url()).pathname.split('/').at(-1);
  if(resource==='coding_questions')return route.fulfill({json:{id:round.question_id,question:'Berapa hasil 1 + 1?',question_type:'choice',option_a:'Dua',option_b:'Tiga',option_c:'Empat',option_d:'Lima',explanation:'Satu ditambah satu adalah dua.',duration_seconds:60}});
  if(resource==='battle_question_rounds')return route.fulfill({json:round});
  if(resource==='get_battle_question_bonus_choice')return route.fulfill({json:pendingChoice()});
  if(resource==='submit_battle_question_answer'){pending=true;round.winner_player=winner;round.status='won';return route.fulfill({json:{ok:true,correct:winner==='p1',already_finished:winner!=='p1',winner,reward_choices:winner==='p1'?choices:[],correct_option:'Dua'}});}
  if(resource==='choose_battle_question_bonus'){
   const body=route.request().postDataJSON();selections.push(body);await new Promise(r=>setTimeout(r,300));
   if(deny){deny=false;return route.fulfill({json:{ok:false,message:'Koneksi sedang berubah, coba lagi.'}});}
   selected=body.p_skill_type;pending=false;mock.patch({question_active:false,status:'battle'});
   return route.fulfill({json:{ok:true,skill_type:selected}});
  }
  if(resource==='battle_bonus_skills')return route.fulfill({json:selected?[{id:'93000000-0000-4000-8000-000000000001',battle_id:mock.battle.id,player:'p1',skill_type:selected,used:uses.length>0}]:[]});
  if(resource==='use_battle_bonus_skill'){uses.push(route.request().postDataJSON());return route.fulfill({json:{ok:true,skill_type:selected}});}
  if(resource==='get_public_battle_bonus_choice')return route.fulfill({json:{ok:true,pending:!selected,question_round_id:round.id,player:winner,selected_code:selected,options:bonusRules.slice(0,count)}});
  return route.fallback();
 });
 return {...mock,round,choices,selections,uses,rejectNextChoice(){deny=true;},async open(){await page.goto('/play/GUIDEDEMO/p1?token=demo-player-one');await page.locator('.question-option').first().waitFor();}};
}
test('admin edits per-type effects and creates quiz rewards with configurable choice count',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const api=await admin(page);
 await page.goto('/admin/game/catalog');await page.getByRole('button',{name:'Synergy per tipe',exact:true}).click();
 const panel=page.locator('.battle-rule-catalog');await expect(panel.locator('.rule-list-item')).toHaveCount(8);
 await panel.locator('.rule-list-item').filter({hasText:'knight Synergy'}).click();
 await panel.getByLabel('Nama kemampuan').fill('Knight Fortress');await panel.getByLabel('Minimal kartu Active').selectOption('3');
 await panel.getByLabel('URL gambar ikon').fill('/images/tutorial/player-battle-guide.jpg');await panel.getByRole('button',{name:'Simpan aturan',exact:true}).click();
 await expect.poll(()=>api.saves.length).toBe(1);expect(api.saves[0]).toMatchObject({code:'synergy_knight',name:'Knight Fortress',min_cards:3,icon:'/images/tutorial/player-battle-guide.jpg'});
 await page.getByRole('button',{name:'Bonus kuis',exact:true}).click();
 await panel.getByLabel('Jumlah pilihan bonus').selectOption('6');await panel.getByRole('button',{name:'Simpan jumlah pilihan'}).click();await expect.poll(()=>api.settings.length).toBe(1);expect(api.settings[0].p_choice_count).toBe(6);
 await panel.getByRole('button',{name:'+ Buat bonus baru'}).click();await panel.getByLabel('Nama kemampuan').fill('Quick Patch');await panel.getByLabel('Efek yang dijalankan').selectOption('heal_flat');await panel.getByLabel('Nilai efek').fill('22');
 await panel.getByRole('button',{name:'Simpan aturan',exact:true}).click();await expect.poll(()=>api.saves.length).toBe(2);expect(api.saves[1]).toMatchObject({code:'quick_patch',kind:'quiz_bonus',effect_type:'heal_flat',effect_values:{1:22}});
 await page.screenshot({path:'test-results/battle-rule-admin.png',fullPage:true});expect(errors).toEqual([]);
});
for(const count of [1,2,3,6])test(`quiz winner sees ${count} circular choices and selects exactly one`,async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const mock=await quiz(page,count);await mock.open();
 await page.locator('.question-option').first().click();const modal=page.locator('dialog.quiz-bonus-award');await expect(modal).toBeVisible();await expect(modal.locator('.award-option')).toHaveCount(count);
 expect(await modal.locator('.award-medallion').first().evaluate(el=>Math.round(el.getBoundingClientRect().width))).toBeGreaterThanOrEqual(140);
 await expect(modal.locator('.award-option img')).toHaveCount(1);await expect(modal.getByRole('heading')).toBeFocused();
 await page.keyboard.press('Escape');await expect(modal).toBeVisible();
 await page.screenshot({path:`test-results/quiz-${count}-choices.png`});
 await modal.locator('.award-option').last().click();await expect(modal.locator('.award-option:disabled')).toHaveCount(count);await expect(modal).toBeHidden();
 expect(mock.selections).toHaveLength(1);expect(mock.selections[0]).toMatchObject({p_skill_type:mock.choices.at(-1),p_question_round_id:mock.round.id});expect(mock.battle.player1_action_points).toBe(3);expect(errors).toEqual([]);
});
test('pending award survives reload and a rejected save permits retry without losing choices',async({page})=>{
 const mock=await quiz(page,6,{pending:true});await mock.open();const modal=page.locator('dialog.quiz-bonus-award');await expect(modal).toBeVisible();
 mock.rejectNextChoice();await modal.locator('.award-option').first().click();await expect(modal.locator('.award-option:enabled')).toHaveCount(6);
 await page.reload();await expect(modal).toBeVisible();await expect(modal.locator('.award-option')).toHaveCount(6);
 await modal.locator('.award-option').last().click();await expect(modal).toBeHidden();expect(mock.selections).toHaveLength(2);
});
test('quiz loser cannot see or select award options',async({page})=>{
 const mock=await quiz(page,3,{winner:'p2'});await mock.open();await page.locator('.question-option').first().click();await expect(page.locator('.question-learning-feedback')).toContainText('Pemain lain menjawab lebih dahulu');await expect(page.locator('dialog.quiz-bonus-award')).toHaveCount(0);expect(mock.selections).toEqual([]);
});
test('six choices remain readable and scroll within a mobile dialog',async({page})=>{
 await page.setViewportSize({width:390,height:844});const mock=await quiz(page,6,{pending:true});await mock.open();const modal=page.locator('dialog.quiz-bonus-award');await expect(modal).toBeVisible();
 expect(await modal.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);await modal.locator('.award-option').last().scrollIntoViewIfNeeded();await expect(modal.locator('.award-option').last()).toBeInViewport();await page.screenshot({path:'test-results/quiz-mobile-choices.png'});
});
test('public quiz shows the winner and matching read-only round bonus badges',async({page})=>{
 const mock=await quiz(page,3,{pending:true});await page.goto('/battle/GUIDEDEMO?layout=stadium');const display=page.locator('.public-quiz-display');await expect(display).toContainText('Alya menjawab benar');await expect(display.locator('.award-option')).toHaveCount(3);await expect(display.locator('.award-option:disabled')).toHaveCount(3);expect(mock.selections).toEqual([]);await page.screenshot({path:'test-results/public-quiz-badges.png'});
});
test('battle review uses configured per-type thresholds and the actual frozen effect',async({page})=>{
 const mock=await mockPlayerBattle(page,{synergy_rules_snapshot:rules.filter(r=>r.kind==='synergy')});
 const allies=mock.cards.filter(c=>c.player==='p1'&&c.zone==='active');allies[0].element='Knight';allies[1].element='Knight';
 await mock.open();await page.locator('.cyber-card').first().click();await page.locator('.player-action-panel').getByRole('button',{name:/Aksi lainnya/}).click();
 const drawer=page.getByRole('dialog',{name:'Aksi lainnya',exact:true});await expect(drawer.locator('[data-action="synergy"]')).toContainText('30%');await expect(drawer.locator('[data-action="synergy"]')).toHaveAttribute('aria-disabled','false');
 await drawer.locator('[data-action="synergy"]').click();const review=page.getByRole('dialog',{name:'Synergy?',exact:true});await expect(review).toContainText('30%');
 await review.getByRole('button',{name:/Konfirmasi/}).click();await expect.poll(()=>mock.submissions.length).toBe(1);expect(mock.submissions[0].p_action).toBe('synergy');expect(mock.submissions[0].p_card_id).toBe(mock.source.id);
});
test('chosen custom reward appears by name and icon and is used once from Bonus Skills',async({page})=>{
 const mock=await quiz(page,1,{pending:true});await mock.open();await page.locator('dialog.quiz-bonus-award .award-option').click();
 const bonus=page.locator('.bonus-panel .bonus-button');await expect(bonus).toContainText('Bonus 1');await expect(bonus.locator('img')).toHaveAttribute('src','/images/tutorial/player-battle-guide.jpg');
 await bonus.click();await expect.poll(()=>mock.uses.length).toBe(1);await expect(bonus).toBeDisabled();expect(mock.battle.player1_action_points).toBe(3);
});
