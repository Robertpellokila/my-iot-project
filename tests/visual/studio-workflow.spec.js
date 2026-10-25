import { test, expect } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const configText = ['.env','.env.local'].map(file => { try { return readFileSync(file,'utf8'); } catch { return ''; } }).join('\n');
const supabaseUrl = configText.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)?.[1] ?? process.env.VITE_SUPABASE_URL;
if (!supabaseUrl) throw new Error('VITE_SUPABASE_URL required for local app tests');
const project = new URL(supabaseUrl).hostname.split('.')[0];
const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'generator-test@example.invalid',app_metadata:{provider:'email'},user_metadata:{},created_at:'2026-01-01T00:00:00Z'};
const token=`${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test-signature`;

async function admin(page) {
 await page.route(`${supabaseUrl}/**`,route=>route.fulfill({json:route.request().url().includes('/auth/v1/user')?user:route.request().url().includes('/profiles')?{...user,role:'admin'}:[]}));
 await page.addInitScript(({key,user,token})=>localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'test-refresh',expires_at:Math.floor(Date.now()/1000)+3600,user})),{key:`sb-${project}-auth-token`,user,token});
}
test('Studio battle choices, Bench switch and multi-target selections send exact player intent',async({page})=>{
 const errors=[];page.on('pageerror',error=>errors.push(error.message));await admin(page);
 const battle={id:'10000000-0000-4000-8000-000000000001',code:'SKILLTEST',ruleset:'tcg_v1',status:'battle',current_turn:'p1',round:1,turn_index:1,player1_token:'qa1',player2_token:'qa2',player1_name:'Tari',player2_name:'Obe',player1_hp:200,player2_hp:200,player1_max_hp:200,player2_max_hp:200,player1_owner_turn:1,player2_owner_turn:0,player1_action_points:3,player2_action_points:0,action_points_per_turn:3,action_points_enabled:true,special_card_skills_enabled:true,question_active:false,question_enabled:false,is_active:true,active_until:'2099-01-01T00:00:00Z',turn_deadline_at:'2099-01-01T00:00:00Z',max_active:4,max_bench:4};
 const id=i=>`20000000-0000-4000-8000-${String(i).padStart(12,'0')}`;
 const cards=[{id:id(1),player:'p1',zone:'active',slot:1,name:'Coby',current_hp:100,base_hp:120,attack:33,defense:11,element:'Knight'},{id:id(2),player:'p1',zone:'bench',name:'Tochi Bench',current_hp:80,base_hp:110,attack:29,defense:10,element:'Forest'},{id:id(3),player:'p2',zone:'active',slot:1,name:'Enemy One',current_hp:100,base_hp:100,attack:30,defense:10,element:'Fire'},{id:id(4),player:'p2',zone:'active',slot:2,name:'Enemy Two',current_hp:100,base_hp:100,attack:30,defense:10,element:'Water'}].map(card=>({...card,battle_id:battle.id,uid:card.id,hp:card.base_hp}));
 const {compileStudioSkill}=await import('../../src/lib/card-generator/cardSkillBattleRules.js');
 const skills=[{name:'Team Spirit',description:'Pilih: heal 12 pada 1 ally ATAU +4 DEF sampai 1 hit. CD 2.'},{name:'Wind Relay',description:'Switch 1 ally sebagai aksi; tidak menarik kartu. CD 2.'},{name:'Thunder Chain',description:'Serang maks. 2 target, masing-masing 0.65× ATK. CD 3.'}].map((skill,i)=>({...skill,...compileStudioSkill(skill),id:`30000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,skill_code:`qa_skill_${i}`,battle_id:battle.id,battle_card_id:id(1),player:'p1',disabled:false}));
 const actions=[];
 await page.route(`${supabaseUrl}/rest/v1/**`,async route=>{
  const request=route.request(),url=new URL(request.url()),resource=url.pathname.split('/').at(-1);
  if(resource==='battle_sessions')return route.fulfill({json:battle});
  if(resource==='battle_cards')return route.fulfill({json:url.searchParams.get('zone')==='eq.graveyard'?[]:cards});
  if(resource==='battle_card_skills')return route.fulfill({json:skills});
  if(resource==='submit_battle_action'){actions.push(request.postDataJSON());return route.fulfill({json:{ok:true,damage:0,heal:12,action_points:2}});}
  return route.fulfill({json:resource==='profiles'?{...user,role:'admin'}:[]});
 });
 battle.player1_avatar_url='🐻';
 await page.goto('/play/SKILLTEST/p1?token=qa1');
 await expect(page.locator('.cyber-card').first()).toBeVisible();
 await page.locator('.cyber-card').filter({hasText:'Coby'}).first().click();
 await page.locator('.player-action-panel [data-action="special"]').click();
 await page.locator('.special-skill-tab').filter({hasText:'Team Spirit'}).click();
 await page.getByLabel('Pilih efek skill').selectOption('defense');
 await page.locator('.special-target-card').filter({hasText:'Tochi Bench'}).click();
 await page.getByRole('button',{name:/Gunakan/}).click();
 await expect.poll(()=>actions.length).toBe(1);expect(actions[0].p_payload.skill_option).toBe('defense');expect(actions[0].p_payload.target_card_id).toBe(id(2));
 await page.locator('.cyber-card').filter({hasText:'Coby'}).first().click();await page.locator('.player-action-panel [data-action="special"]').click();
 await page.locator('.special-skill-tab').filter({hasText:'Wind Relay'}).click();await page.getByLabel('Kartu Bench untuk Switch').selectOption(id(2));
 await page.locator('.special-target-card').filter({hasText:'Coby'}).click();await page.getByRole('button',{name:/Gunakan/}).click();
 await expect.poll(()=>actions.length).toBe(2);expect(actions[1].p_payload.bench_card_id).toBe(id(2));expect(actions[1].p_payload.target_card_id).toBe(id(1));
 await page.locator('.cyber-card').filter({hasText:'Coby'}).first().click();await page.locator('.player-action-panel [data-action="special"]').click();
 await page.locator('.special-skill-tab').filter({hasText:'Thunder Chain'}).click();await page.locator('.special-target-card').filter({hasText:'Enemy One'}).click();await page.locator('.special-target-card').filter({hasText:'Enemy Two'}).click();
 await expect(page.locator('.special-target-card.selected')).toHaveCount(2);await page.getByRole('button',{name:/Gunakan/}).click();
 await expect.poll(()=>actions.length).toBe(3);expect(actions[2].p_payload.target_card_ids).toEqual([id(3),id(4)]);
 expect(errors).toEqual([]);
});
test('structured workspace nests blocks, persists inputs and checks preview',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await admin(page);await page.goto('/admin/questions/add');
 await page.getByText('Scratch workspace',{exact:true}).click();
 await expect(page.locator('.blocklySvg').first()).toBeVisible();
 await page.getByPlaceholder('Apa yang terjadi setelah bendera hijau diklik?').fill('Susun repeat 3 dengan move 10');
 const serialized=await page.evaluate(async()=>{
  const m=await import('/node_modules/.vite/deps/blockly_core.js');const B=m.default??m;const w=document.querySelector('.block-workspace').__vueParentComponent.exposed.getWorkspace();
  const create=type=>{const b=w.newBlock(type);b.initSvg();b.render();return b;};
  const flag=create('tbc_flag'),repeat=create('tbc_repeat'),move=create('tbc_move'),number=create('tbc_number');number.setFieldValue(3,'NUM');
  flag.nextConnection.connect(repeat.previousConnection);repeat.getInput('DO').connection.connect(move.previousConnection);repeat.getInput('TIMES').connection.connect(number.outputConnection);
  return B.serialization.workspaces.save(w);
 });
 expect(serialized.blocks.blocks[0].next.block.inputs.DO.block.type).toBe('tbc_move');
 await page.getByRole('button',{name:'Workspace awal pemain',exact:true}).click();
 await page.getByRole('button',{name:'Kunci jawaban',exact:true}).click();
 await expect(page.locator('.blocklyText').filter({hasText:'repeat'}).last()).toBeVisible();
 await page.getByRole('button',{name:'Buka preview interaktif'}).click();
 await expect(page.locator('.quiz-preview .blocklySvg').first()).toBeVisible();
 await page.screenshot({path:'test-results/structured-workspace.png',fullPage:true});
 expect(errors).toEqual([]);
});

test('Trial Join and Winning render print-safe panels and keep their template after editing',async({page})=>{
 await admin(page);await page.goto('/admin/card-generator');
 await page.getByRole('button',{name:'9 templates',exact:true}).click();
 const errors=await page.evaluate(async()=>{
  const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
  const {renderCardSvg}=await import('/src/lib/card-generator/cardRenderer.js');
  const {inspectSvg}=await import('/src/lib/card-generator/cardExportService.js');
  return ['Trial Join','Winning'].flatMap(template=>inspectSvg(renderCardSvg({...PILOT.cards[0],design_template:template},PILOT)).map(e=>template+': '+e));
 });
 expect(errors).toEqual([]);
 for(const name of ['Trial Join','Winning']) await page.locator('.cg-master-grid article').filter({has:page.getByRole('heading',{name,exact:true})}).screenshot({path:`test-results/${name.replace(' ','-')}-template.png`});
});

test('type icons follow all inputs in every template and stay inside export panels',async({page})=>{
 await admin(page);await page.goto('/admin/card-generator');
 const issues=await page.evaluate(async()=>{
  const {PILOT,TYPES}=await import('/src/lib/card-generator/cardSchema.js');
  const {TEMPLATES}=await import('/src/lib/card-generator/cardDrafts.js');
  const {renderCardSvg}=await import('/src/lib/card-generator/cardRenderer.js');
  const {inspectSvg}=await import('/src/lib/card-generator/cardExportService.js');
  return TEMPLATES.flatMap(template=>TYPES.flatMap(type=>inspectSvg(renderCardSvg({...PILOT.cards[0],type,design_template:template},PILOT)).map(issue=>`${template}/${type}: ${issue}`)));
 });
 expect(issues).toEqual([]);
 await page.getByRole('button',{name:'9 templates',exact:true}).click();
 const previews=page.locator('.cg-master-grid');
 for(const name of ['Trial Join','Winning']){
  const tile=previews.locator('article').filter({has:page.getByRole('heading',{name,exact:true})});
  await expect(tile.locator('[data-type-icon="Forest"]')).toHaveCount(1);
  for(const kind of ['attack','hp','defense'])await expect(tile.locator(`[data-stat-icon="${kind}"]`)).toHaveCount(1);
  await tile.screenshot({path:`test-results/${name.replace(' ','-')}-shared-icons.png`});
 }
});

test('landing showcase renders Base and Fusion, opens skills, and handles empty and retry',async({page})=>{
 await admin(page);
 let state='cards';
 const cards=[{id:'fusion',name:'Forest Guardian',fusion_only:true,rarity:'Epic',element:'Forest',hp:150,attack:40,defense:14,landing_group:'Starter team',skills:[{id:'s',name:'Guardian shield',description:'Beri Shield 8.'}]},{id:'base',name:'Coby',rarity:'Common',element:'Knight',hp:120,attack:30,defense:14,landing_group:'Starter team',skills:[]}];
 await page.route(`${supabaseUrl}/rest/v1/rpc/get_landing_cards`,r=>r.fulfill(state==='error'?{status:503,json:{message:'Offline'}}:{json:state==='empty'?[]:cards}));
 await page.goto('/');await expect(page.locator('.featured-card')).toHaveCount(2);
 await expect(page.locator('.featured-card').first()).toContainText('FUSION');
 await page.getByRole('button').filter({hasText:'Forest Guardian'}).click();await expect(page.getByRole('dialog')).toContainText('Guardian shield');
 state='empty';await page.reload();await expect(page.locator('.featured-section')).toContainText('Koleksi pilihan sedang disiapkan');
 state='error';await page.reload();await expect(page.getByRole('button',{name:'Coba lagi',exact:true})).toBeVisible();
 state='cards';await page.getByRole('button',{name:'Coba lagi',exact:true}).click();await expect(page.locator('.featured-card')).toHaveCount(2);
});

test('edition frames export embedded PNG and mixed-size PDF with editable stats and skill images',async({page})=>{
 await admin(page);await page.goto('/admin/card-generator');
 const result=await page.evaluate(async()=>{
  const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');const {createDraft,normalizeDraft}=await import('/src/lib/card-generator/cardDrafts.js');
  const {svgForExport,rasterizeSvg,inspectSvg,exportCards}=await import('/src/lib/card-generator/cardExportService.js');const {emptyArtwork,emptyBack}=await import('/src/lib/card-generator/cardArtworkService.js');
  const {cardPrintSettings}=await import('/src/lib/card-generator/cardLayoutTokens.js');const out=[];
  const cards=['Trial Join','Winning'].map((template,i)=>normalizeDraft({...createDraft(template),card_code:`DRAFT-EDITION-${i}`,display_code:template==='Winning'?'CH-006':'TR-001',name:'Coby',subtitle:i?'Timedoor Supreme':'First Spark',serial_number:'CH006-S1-014',type:i?'Light':'Knight',role:'Guardian',stats:{attack:i?52:30,hp:i?175:120,defense:i?24:14},skills:i?[{name:'Supreme Legacy',description:"Inspire your team with the power of time. Draw 2 cards and boost all allies’ ATK by 10 until the end of your next turn."},{name:'Academy Blessing',description:'Restore 30 HP to all allies. Gain a Light Shield (reduces next damage by 20).'}]:[{name:'Buddy Guard',description:'Beri Shield 8 pada diri. CD 2.'},{name:'First Step',description:'Serangan normal +3 pada aksi pertama setelah summon.'}]}));
  const artworks=Object.fromEntries(cards.map(card=>[card.card_code,emptyArtwork()]));
  for(const card of cards){const svg=await svgForExport(card,PILOT,artworks[card.card_code],emptyBack(),{proof:true});
   const errors=inspectSvg(svg);const png=await rasterizeSvg(svg,cardPrintSettings(card));out.push({template:card.design_template,errors,width:png.width,height:png.height,bytes:png.blob.size,embedded:svg.includes('data:image/png;base64,')});
  }
  const pdf=await exportCards(cards,PILOT,{artworks,back:emptyBack()},{proof:true,format:'pdf',side:'both'});
  const sheet=await exportCards(cards,PILOT,{artworks,back:emptyBack()},{proof:true,format:'sheet',side:'both'});
  return {out,pdf:pdf.blob.size,sheet:sheet.blob.size};
 });
 for(const item of result.out){expect(item.errors,item.template).toEqual([]);expect(item.width).toBe(815);expect(item.height).toBe(1187);expect(item.embedded).toBe(true);expect(item.bytes).toBeGreaterThan(100000);}
 expect(result.pdf).toBeGreaterThan(100000);expect(result.sheet).toBeGreaterThan(100000);
});

test('cinematic overlay preserves all four public layouts at TV sizes',async({page})=>{
 test.setTimeout(120000);await admin(page);
 const skills=[{id:'s1',name:'Leaf Swipe',description:'Serangan dan Burn.',icon:'✦',activation_timing:'main_phase',limits:{cooldown_turns:2},effects:[{type:'damage_card'}]},{id:'s2',name:'Camo Guard',description:'Beri Shield ke ally.',icon:'⬡',activation_timing:'main_phase',limits:{cooldown_turns:2},cooldown_until_owner_turn:3,effects:[{type:'apply_status',status_key:'shield'}]}];
 await page.route(`${supabaseUrl}/rest/v1/battle_card_skills**`,r=>r.fulfill({json:skills}));
 for(const viewport of [{width:1920,height:1080},{width:1366,height:768}])for(const layout of ['center_duel','top_bottom','side_hud','stadium']){
  await page.setViewportSize(viewport);await page.goto('/');
  await page.evaluate(async layout=>{
   const {createApp,h,reactive}=await import('/node_modules/.vite/deps/vue.js');
   const Field=(await import('/src/components/battle/PublicActiveField.vue')).default,Cinema=(await import('/src/components/battle/PublicSkillCinematic.vue')).default;
   document.querySelector('#app').replaceChildren();const root=document.createElement('div');root.style='position:fixed;inset:0;background:#071526;overflow:hidden';document.body.append(root);
   const battle=reactive({id:'battle',current_turn:'p1',turn_index:1,round:1,status:'battle',player1_name:'Tari',player2_name:'Obe',player1_hp:200,player1_max_hp:200,player2_hp:200,player2_max_hp:200,player1_owner_turn:1,action_points_enabled:true,max_active:4,max_bench:4});
   const cards=[{id:'c1',player:'p1',zone:'active',name:'Tochi',element:'Forest',current_hp:110,base_hp:110,attack:29,defense:10,image_url:'/images/card-generator/tochi-sprout-keeper-v1.png'},{id:'c2',player:'p2',zone:'active',name:'Coby',element:'Knight',current_hp:120,base_hp:120,attack:30,defense:14}];
   const state=reactive({liveUi:{},event:null,battle});window.cinematicFixture=state;
   createApp({render:()=>h('div',{class:'tbc-public-frame',style:'position:absolute;inset:0'},[h(Field,{layout,battle,player1Active:[cards[0]],player2Active:[cards[1]]}),h(Cinema,{battle,cards,liveUi:state.liveUi,event:state.event,timings:{intro:100,selected:100,centering:100,activating:100,resolving:850,outro:100}})])}).mount(root);
  },layout);
  const cards=page.locator('[data-featured="true"]');await expect(cards).toHaveCount(2);const rects=()=>cards.evaluateAll(nodes=>nodes.map(n=>{const r=n.getBoundingClientRect();return [r.x,r.y,r.width,r.height];}));const before=await rects();
  await page.evaluate(()=>window.cinematicFixture.liveUi={p1:{skillIntent:{id:'pick',cardId:'c1',phase:'choosing',turn:1,at:Date.now()}}});
  await expect(page.locator('.cinema-skill')).toHaveCount(2);await expect(page.locator('.cinema-skill').nth(1)).toContainText('CD 3');expect(await rects()).toEqual(before);
  await page.evaluate(()=>window.cinematicFixture.liveUi.p1.skillIntent={...window.cinematicFixture.liveUi.p1.skillIntent,phase:'selected',skillId:'s1',at:Date.now()});
  await expect(page.locator('.cinema-skill.chosen')).toContainText('Leaf Swipe');await expect(page.locator('.cinema-resolution')).toHaveCount(0);
  await page.evaluate(()=>window.cinematicFixture.event={id:42,battle_id:'battle',type:'special_skill',source_player:'p1',payload:{source_card_id:'c1',battle_card_skill_id:'s1',skill_name:'Leaf Swipe',target_card_id:'c2',effect_result:{results:[{ok:true,type:'damage_card',result:{target_card_id:'c2',actual_damage:7,hp_after:113}},{ok:true,type:'apply_status',result:{target_card_id:'c2',status_key:'burn',value:{amount:1}}}]}}});
  await expect(page.locator('.cinema-resolution')).toContainText('Damage −7');await expect(page.locator('.cinema-skill')).toHaveCount(1);await expect(page.locator('.skill-target-impact')).toBeVisible();
  if(viewport.width===1366&&layout==='stadium')await page.screenshot({path:'test-results/cinematic-stadium.png'});
  await expect(page.locator('.cinema-resolution')).toContainText('Burn');await expect(page.locator('.skill-cinema')).toHaveCount(0);
  await page.evaluate(()=>window.cinematicFixture.event={...window.cinematicFixture.event});await expect(page.locator('.skill-cinema')).toHaveCount(0);
  await page.evaluate(()=>{window.cinematicFixture.liveUi={p1:{skillIntent:{id:'cancel',cardId:'c1',phase:'choosing',turn:1,at:Date.now()}}};});await expect(page.locator('.cinema-skill')).toHaveCount(2);
  await page.evaluate(()=>window.cinematicFixture.battle.current_turn='p2');await expect(page.locator('.skill-cinema')).toHaveCount(0);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 }
});
