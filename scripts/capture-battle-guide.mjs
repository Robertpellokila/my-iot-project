// Capture the real battle components with local demonstration data only.
// Battle requests are mocked. Optional published artwork is fetched read-only;
// no account, scan or live battle is changed.
import {chromium} from '@playwright/test';
import {createBattleDemo,createDemoSkills} from './lib/battle-demo.mjs';
import {spawn} from 'node:child_process';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
const origin='http://127.0.0.1:5185',server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','5185'],{stdio:'ignore'});
let browser;
try{
 for(let i=0;i<80;i++){try{if((await fetch(origin)).ok)break;}catch{}await new Promise(r=>setTimeout(r,250));}
 browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage({viewport:{width:1600,height:1000},reducedMotion:'reduce'});
 const env=['.env','.env.local'].map(p=>{try{return readFileSync(p,'utf8')}catch{return ''}}).join('\n'),endpoint=env.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)[1];
 const artwork=JSON.parse(readFileSync('src/data/card-generator/starter-artwork.json','utf8'));
 const publicImages=new Map();
 try{
  const key=env.match(/^VITE_SUPABASE_ANON_KEY\s*=\s*["']?([^\s"']+)/m)?.[1];
  const response=await fetch(`${endpoint}/rest/v1/rpc/get_landing_cards`,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:'{}'});
  if(response.ok)for(const card of await response.json()){const code=String(card.card_code??'').replaceAll('_','-');if(card.image_url)publicImages.set(code,card.image_url);}
 }catch{ /* Local starter artwork also supports offline regeneration. */ }
 const {battle,cards}=createBattleDemo(publicImages,artwork);
 const skills=createDemoSkills(battle,cards[0]);
 await page.routeWebSocket('**',ws=>ws.close());
 await page.route(`${endpoint}/**`,route=>{
  const url=new URL(route.request().url()),resource=url.pathname.split('/').at(-1);
  if(url.pathname.startsWith('/storage/v1/object/public/'))return route.continue();
  if(resource==='battle_sessions')return route.fulfill({json:battle});
  if(resource==='battle_cards'){let rows=url.searchParams.has('zone')?cards:cards.filter(c=>c.zone!=='graveyard');for(const field of ['player','zone']){const value=url.searchParams.get(field);if(value?.startsWith('eq.'))rows=rows.filter(c=>c[field]===value.slice(3));}return route.fulfill({json:rows});}
  if(resource==='battle_card_skills')return route.fulfill({json:skills.filter(skill=>url.searchParams.get('battle_card_id')===`eq.${skill.battle_card_id}`)});
  if(resource==='get_player_fusions')return route.fulfill({json:[]});
  return route.fulfill({json:[]});
 });
 mkdirSync('public/images/tutorial',{recursive:true});
 const shots={};
 async function capture(name,path,ready,targets){
  await page.goto(origin+path);await page.locator(ready).first().waitFor();await page.evaluate(()=>document.fonts.ready);await page.waitForFunction(()=>Array.from(document.images).every(image=>image.complete));await page.waitForTimeout(300);
  if(name==='player-battle-guide'){
   await page.locator('.cyber-card').first().click();
   await page.waitForFunction(()=>document.querySelector('.command-primary [data-action="special"] small')?.textContent.includes('2 skill'));
  }
  await page.screenshot({path:`public/images/tutorial/${name}.jpg`,type:'jpeg',quality:85});
  const points={};for(const [key,selector,fx=.5,fy=.5] of targets){const box=await page.locator(selector).first().boundingBox();if(!box)throw new Error(`Missing guide target: ${key} (${selector})`);points[key]={x:Math.max(2,Math.min(98,(box.x+box.width*fx)/16)),y:Math.max(2,Math.min(98,(box.y+box.height*fy)/10))};}
  shots[name]={src:`/images/tutorial/${name}.jpg`,width:1600,height:1000,points};console.log(`Captured ${name}: ${Object.keys(points).length} menu markers`);
 }
 await capture('player-battle-guide','/play/GUIDEDEMO/p1?token=demo-player-one','.cyber-card',[
  ['status','.top-hud',.35,.45],['active','.cyber-card',.5,.35],['bench','.bench-side-zone',.5,.5],['graveyard','.graveyard-side-zone',.5,.5],['actions','.player-action-panel',.5,.65],['sound','.battle-sound-toggle',.5,.5],['history','.fusion-history-fab',.5,.5],
 ]);
 await capture('public-battle-guide','/battle/GUIDEDEMO?layout=stadium','.tbc-stage',[
  ['score','.tbc-hud.p1',.45,.4],['turn','.tbc-round',.5,.5],['duel','.tbc-hero.p1',.5,.5],['active','.tbc-roster.p1',.35,.3],['bench','.tbc-roster.p1',.65,.7],['log','.tbc-log-row',.5,.5],['audio','.public-sound-control',.5,.5],
 ]);
 writeFileSync('src/data/battle-guide-screens.json',JSON.stringify(shots,null,2)+'\n');
}finally{await browser?.close();server.kill('SIGTERM');}
