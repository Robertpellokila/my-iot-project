import { test, expect } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const configText = ['.env','.env.local'].map(file => { try { return readFileSync(file,'utf8'); } catch { return ''; } }).join('\n');
const supabaseUrl = configText.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)?.[1] ?? process.env.VITE_SUPABASE_URL;
if (!supabaseUrl) throw new Error('VITE_SUPABASE_URL required for local app tests');
const project = new URL(supabaseUrl).hostname.split('.')[0];
const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'generator-test@example.invalid',app_metadata:{provider:'email'},user_metadata:{},created_at:'2026-01-01T00:00:00Z'};
const token=`${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test-signature`;

async function authenticate(page, code = 'COB-006') {
  await page.route(`${supabaseUrl}/**`, route => {
    const url=route.request().url();
    if (url.includes('/auth/v1/user')) return route.fulfill({json:user});
    if (url.includes('/rest/v1/profiles')) return route.fulfill({json:{id:user.id,full_name:'Generator test',email:user.email}});
    return route.fulfill({status:404,json:{message:'Remote services intentionally isolated in tests'}});
  });
  await page.addInitScript(({key,user,token}) => localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'test-refresh',expires_in:3600,expires_at:Math.floor(Date.now()/1000)+3600,token_type:'bearer',user})),{key:`sb-${project}-auth-token`,user,token});
  await page.goto('/admin/card-generator');
  await expect(page.locator('.cg-studio-grid')).toBeVisible();
  await page.locator('.cg-library-row > button').filter({hasText:code}).click();
  await page.evaluate(() => document.fonts.ready);
}

test('route rejects unauthenticated access',async({page})=>{
  await page.goto('/admin/card-generator'); await expect(page).toHaveURL(/\/login\?redirect=/);
  await expect(page.locator('.cg-studio-grid')).toHaveCount(0);
});

test('seven master frames and first five milestone proofs are stable',async({page})=>{
  await authenticate(page,'TOC-003');
  await expect(page.locator('.cg-preview-artboard image[data-art-layer="1"]')).toHaveAttribute('href','/images/card-generator/tochi-sprout-keeper-v1.png');
  await expect(page.locator('.cg-preview-artboard')).toHaveScreenshot('TOC-003-illustrated-template.png');
  await page.locator('.cg-card-list').evaluate(list=>{list.scrollTop=0;});
  await page.evaluate(()=>window.scrollTo({top:0,left:0,behavior:'instant'}));
  expect((await page.locator('.cg-main-header').boundingBox()).y).toBeGreaterThanOrEqual(76);
  await expect(page).toHaveScreenshot('studio-overview-proof.png',{fullPage:true});
  await page.getByRole('button',{name:'9 templates',exact:true}).click();
  await expect(page.locator('.cg-master-grid article')).toHaveCount(9);
  for (const name of ['Common','Uncommon','Rare','Epic','Legendary','Mythic','Fusion']) {
    await expect(page.locator('.cg-master-grid article').filter({has:page.getByRole('heading',{name,exact:true})})).toHaveScreenshot(`master-${name.toLowerCase()}-proof.png`);
  }
  await page.getByRole('button',{name:'Studio',exact:true}).click();
  for (const code of ['COB-003','TOC-005','COB-006','COB-008','F01']) {
    await page.locator('.cg-library-row > button').filter({hasText:code}).click();
    await expect(page.locator('.cg-preview-artboard')).toHaveScreenshot(`${code}-proof.png`);
  }
});

test('all 42 cards review, filtering, source skill and safe SVG geometry',async({page})=>{
  await authenticate(page);
  await page.getByPlaceholder('Cari ID atau nama…').fill('NUL-006');
  await expect(page.locator('.cg-library-row')).toHaveCount(1);
  await page.locator('.cg-library-row > button').click();
  await expect(page.locator('.cg-skill-input textarea').nth(1)).toHaveValue(/once-per-battle tidak di-reset/);
  await expect(page.locator('.cg-validation')).toContainText('Skill 2 melebihi ruang aman cetak');
  await page.getByRole('button',{name:'Review 42 kartu',exact:true}).click();
  await expect(page.locator('.cg-review-grid > article')).toHaveCount(42);
  const issues=await page.evaluate(async()=>{
    const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
    const {renderCardSvg}=await import('/src/lib/card-generator/cardRenderer.js');
    const {inspectSvg}=await import('/src/lib/card-generator/cardExportService.js');
    return PILOT.cards.flatMap(card=>inspectSvg(renderCardSvg(card,PILOT)).map(error=>({code:card.card_code,error})));
  });
  expect(issues.filter(issue=>issue.code!=='NUL-006')).toEqual([]);
});

test('actual PNG, PDF and ZIP exports have correct dimensions and production gate',async({page})=>{
  await authenticate(page);
  await page.locator('.cg-header-actions .cg-primary').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('checkbox',{name:/Proof berwatermark/}).uncheck();
  await page.getByRole('button',{name:'Download export',exact:true}).click();
  await expect(page.locator('.cg-export-dialog .cg-error')).toContainText('belum Ready for Print');
  await page.getByRole('checkbox',{name:/Proof berwatermark/}).check();
  const downloading=page.waitForEvent('download');
  await page.getByRole('button',{name:'Download export',exact:true}).click();
  expect((await downloading).suggestedFilename()).toBe('PROOF-COB-006-front.png');
  await page.getByRole('button',{name:'Tutup ekspor',exact:true}).click();
  const result=await page.evaluate(async()=>{
    const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
    const {exportCards}=await import('/src/lib/card-generator/cardExportService.js');
    const {emptyArtwork,emptyBack}=await import('/src/lib/card-generator/cardArtworkService.js');
    const workspace={artworks:Object.fromEntries(PILOT.cards.map(card=>[card.card_code,emptyArtwork()])),back:emptyBack()};
    const options={format:'png',side:'front',proof:true,print:{width:63,height:88,bleed:3,dpi:300,guides:true}};
    const png=await exportCards([PILOT.cards[0]],PILOT,workspace,options);
    const pngBitmap=await createImageBitmap(png.blob);const dimensions=[pngBitmap.width,pngBitmap.height];pngBitmap.close();
    const pngBytes=new Uint8Array(await png.blob.arrayBuffer());let density=null;
    for(let offset=8;offset<pngBytes.length;){const view=new DataView(pngBytes.buffer);const size=view.getUint32(offset);const type=String.fromCharCode(...pngBytes.subarray(offset+4,offset+8));if(type==='pHYs')density=view.getUint32(offset+8);offset+=size+12;}
    const pdf=await exportCards([PILOT.cards[0]],PILOT,workspace,{...options,format:'pdf',side:'both'});
    const pdfText=await pdf.blob.text(); const mediaBox=pdfText.match(/\/MediaBox\s*\[([^\]]+)\]/)?.[1];
    const sheet=await exportCards(PILOT.cards.slice(0,5),PILOT,workspace,{...options,format:'sheet',side:'both'});
    const sheetPages=((await sheet.blob.text()).match(/\/Type \/Page\b/g)||[]).length;
    const zip=await exportCards(PILOT.cards.slice(0,2),PILOT,workspace,{...options,format:'svg',side:'both'});
    const JSZip=(await import('/node_modules/.vite/deps/jszip.js')).default;const archive=await JSZip.loadAsync(zip.blob);
    let blocked=false;try{await exportCards([PILOT.cards[0]],PILOT,workspace,{...options,proof:false});}catch{blocked=true;}
    return {dimensions,density,sheetPages,mediaBox,pages:(pdfText.match(/\/Type \/Page\b/g)||[]).length,zipFiles:Object.keys(archive.files),blocked};
  });
  expect(result.dimensions).toEqual([815,1110]); expect(result.density).toBe(11811);expect(result.sheetPages).toBe(4);expect(result.pages).toBe(2);
  const box=result.mediaBox.split(/\s+/).map(Number);expect(box[2]).toBeCloseTo(69/25.4*72,2);expect(box[3]).toBeCloseTo(94/25.4*72,2);
  expect(result.zipFiles).toHaveLength(5);expect(result.blocked).toBeTruthy();
});

test('artwork upload and placement update draft, reload strips print receipt, mobile usable',async({page})=>{
  await authenticate(page);
  const file=await page.evaluate(async()=>{
    const canvas=document.createElement('canvas');canvas.width=1400;canvas.height=1000;const context=canvas.getContext('2d');
    context.fillStyle='#dfe9e3';context.fillRect(0,0,1400,1000);context.fillStyle='#19714a';context.fillRect(240,180,800,620);context.fillStyle='white';context.font='60px Arial';context.fillText('TEST FIXTURE - NOT CARD ART',230,500);
    return Array.from(new Uint8Array(await(await new Promise(resolve=>canvas.toBlob(resolve,'image/png'))).arrayBuffer()));
  });
  const bytes=Buffer.from(file);let storageBytes=null;
  await page.route(`${supabaseUrl}/storage/v1/object/**`,async route=>{
    if(route.request().method()==='POST'){
      const body=route.request().postDataBuffer();const start=body.indexOf(Buffer.from('RIFF'));
      storageBytes=start>=0?body.subarray(start,start+body.readUInt32LE(start+4)+8):body;
      return route.fulfill({json:{Key:'test-fixture'}});
    }
    return route.fulfill({contentType:'image/webp',body:storageBytes});
  });
  await page.locator('.cg-artwork-editor input[type=file]').first().setInputFiles({name:'test-fixture.png',mimeType:'image/png',buffer:bytes});
  await expect(page.locator('.cg-preview-artboard image[data-art-layer="1"]')).toHaveCount(1);
  await expect(page.locator('.cg-upload-surface img')).toHaveJSProperty('naturalWidth',1400);
  await expect(page.locator('.cg-preview-heading')).toContainText('Artwork Draft');
  const range=page.locator('.cg-artwork-editor input[type=range]').first();
  await range.fill('40');await range.dispatchEvent('input');
  await expect(page.locator('.cg-preview-artboard image[data-art-layer="1"]')).toHaveAttribute('transform',/translate\(418 /);
  await page.getByLabel('Karakter, pose unik, keterbacaan, dan referensi maskot sudah ditinjau.').check();
  await page.getByRole('button',{name:'Approve artwork',exact:true}).click();
  await expect(page.locator('.cg-preview-heading')).toContainText('Artwork Approved');
  await page.getByRole('button',{name:'Periksa artwork & render',exact:true}).click();
  await expect(page.locator('.cg-message')).toContainText('Batas teks dan asset lolos');
  await page.locator('.cg-back-settings summary').click();
  await expect(page.locator('.cg-fixed-back-preview')).toHaveJSProperty('naturalWidth',1024);
  await expect(page.locator('.cg-back-settings input[type=file]')).toHaveCount(0);
  await expect(page.locator('.cg-preview-heading')).toContainText('Ready for Print');
  const productionSvg=await page.evaluate(async()=>{
    const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
    const {exportCards}=await import('/src/lib/card-generator/cardExportService.js');
    const key=Object.keys(localStorage).find(key=>key.startsWith('tbc:card-generator:'));
    const workspace=JSON.parse(localStorage.getItem(key));
    const result=await exportCards([PILOT.cards.find(card=>card.card_code==='COB-006')],PILOT,workspace,{format:'svg',side:'both',proof:false});
    const JSZip=(await import('/node_modules/.vite/deps/jszip.js')).default;const zip=await JSZip.loadAsync(result.blob);
    return {front:await zip.file('COB-006-front.svg').async('string'),back:await zip.file('COB-006-back.svg').async('string')};
  });
  expect(productionSvg.front).toContain('data:image/webp;base64,');expect(productionSvg.back).toContain('data:image/png;base64,');
  expect(productionSvg.front).not.toContain('PROOF · NOT FOR PRINT');
  await range.fill('50');await range.dispatchEvent('input');
  await expect(page.locator('.cg-preview-heading')).toContainText('Artwork Draft');
  await page.reload();await expect(page.locator('.cg-studio-grid')).toBeVisible();
  await page.locator('.cg-library-row > button').filter({hasText:'COB-006'}).click();
  await expect(page.locator('.cg-preview-heading')).toContainText('Artwork Draft');
  await expect(page.locator('.cg-validation')).toContainText('Pemeriksaan render diperlukan');
  await page.setViewportSize({width:390,height:844});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});

test('choose rarity, enter all card data, switch templates, export and restore a custom draft',async({page})=>{
  await authenticate(page);
  await page.getByRole('button',{name:'＋ Buat kartu',exact:true}).click();
  await expect(page.locator('.cg-template-grid > button')).toHaveCount(9);
  await page.locator('.cg-template-grid > button').filter({has:page.getByText('Epic',{exact:true})}).click();
  const form=page.locator('.cg-data-form');
  await expect(form).toBeVisible();
  await form.getByLabel('Kode cetak',{exact:true}).fill('#TEST01');
  await form.getByLabel('Nama karakter / Fusion',{exact:true}).fill('Coby');
  await form.getByLabel('Nama varian',{exact:true}).fill('Circuit Buddy');
  await form.getByLabel('Role',{exact:true}).fill('Guardian');
  await form.getByLabel('Type',{exact:true}).selectOption('Knight');
  await form.getByLabel('ATK',{exact:true}).fill('30');
  await form.getByLabel('HP',{exact:true}).fill('108');
  await form.getByLabel('DEF',{exact:true}).fill('9');
  await form.getByLabel('Nama skill',{exact:true}).nth(0).fill('Spark Link');
  await form.getByLabel('Efek skill',{exact:true}).nth(0).fill('Serangan normal. +3 damage jika ada ally di Bench.');
  await form.getByLabel('Nama skill',{exact:true}).nth(1).fill('Banner Cover');
  await form.getByLabel('Efek skill',{exact:true}).nth(1).fill('Beri Shield 8 ke 1 ally. CD 2.');
  await form.getByLabel('Fusion Data',{exact:true}).fill('COB-006 + TOC-006');
  await form.getByLabel('TAG',{exact:true}).fill('VINE, GUARD');
  await form.getByLabel('TAG',{exact:true}).blur();
  await expect(page.locator('.cg-validation > div strong')).toHaveText('Data Verified');
  for(const rarity of ['Common','Uncommon','Rare','Epic','Legendary','Mythic','Fusion']) {
    await form.getByRole('button',{name:rarity,exact:true}).click();
    await expect(form.getByRole('button',{name:rarity,exact:true})).toHaveAttribute('aria-pressed','true');
    await expect(page.locator('.cg-preview-artboard [data-anchor="attack"]')).toContainText('30');
    await page.getByRole('button',{name:'Belakang',exact:true}).click();
    await expect(page.locator('.cg-preview-artboard image[data-fixed-back]')).toHaveAttribute('href','/images/tbc-back.png');
    await page.getByRole('button',{name:'Depan',exact:true}).click();
  }
  await form.getByRole('button',{name:'Rare',exact:true}).click();
  await expect(page.locator('.cg-preview-artboard [data-anchor="name"]')).toContainText('CIRCUIT BUDDY');
  await expect(page.locator('.cg-preview-artboard')).toHaveScreenshot('custom-card-template.png');
  const result=await page.evaluate(async()=>{
    const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
    const {exportCards,inspectSvg}=await import('/src/lib/card-generator/cardExportService.js');
    const key=Object.keys(localStorage).find(key=>key.startsWith('tbc:card-generator:'));
    const workspace=JSON.parse(localStorage.getItem(key)), card=workspace.custom_cards[0];
    const output=await exportCards([card],PILOT,workspace,{format:'svg',side:'both',proof:true});
    const JSZip=(await import('/node_modules/.vite/deps/jszip.js')).default, zip=await JSZip.loadAsync(output.blob);
    const front=await zip.file(`${'PROOF-'}${card.card_code}-front.svg`).async('string');
    const back=await zip.file(`${'PROOF-'}${card.card_code}-back.svg`).async('string');
    const data=back.match(/href="data:image\/png;base64,([^"]+)"/)[1];
    const bytes=Uint8Array.from(atob(data),c=>c.charCodeAt(0));
    const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
    return {front,hash,issues:inspectSvg(front),pilotAttack:PILOT.cards.find(c=>c.card_code==='COB-006').stats.attack};
  });
  expect(result.hash).toBe('bbb872f65117aa57bef346a4953d351c0762cb1ee6d425f16a55ac24a70fd79e');
  expect(result.issues).toEqual([]);expect(result.front).toContain('Spark Link');expect(result.pilotAttack).toBe(33);
  await page.reload();
  await page.locator('.cg-library-row > button').filter({hasText:'#TEST01'}).click();
  await expect(page.locator('.cg-data-form').getByLabel('Nama varian',{exact:true})).toHaveValue('Circuit Buddy');
  await expect(page.locator('.cg-data-form').getByLabel('ATK',{exact:true})).toHaveValue('30');
  await expect(page.locator('.cg-data-form').getByRole('button',{name:'Rare',exact:true})).toHaveAttribute('aria-pressed','true');
  await page.setViewportSize({width:390,height:844});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});

test('illustrated reference keeps stacked footer rows, type icons, and a full-size review artifact',async({page})=>{
  await authenticate(page,'TOC-003');
  const frame=page.locator('.cg-preview-artboard');
  await expect(frame.locator('[data-frame-material]')).toHaveAttribute('data-frame-material','Common');
  await expect(frame.locator('[data-skill-icon="forest"]')).toHaveCount(1);
  const positions=await frame.evaluate(el=>{
    const box=selector=>{const b=el.querySelector(selector).getBBox();return {x:b.x,y:b.y,w:b.width,h:b.height};};
    return {fusion:box('[data-anchor="fusion"]'),tags:box('[data-anchor="tags"]'),skill:box('[data-anchor="skill-2"]')};
  });
  expect(positions.fusion.y).toBeGreaterThan(positions.skill.y+positions.skill.h);
  expect(positions.tags.y).toBeGreaterThan(positions.fusion.y);
  expect(positions.tags.x).toBe(positions.fusion.x);
  expect(Math.abs(positions.tags.w-positions.fusion.w)).toBeLessThan(1);
  const preview=await page.context().newPage();
  try {
    await preview.setViewportSize({width:756,height:1056});
    await preview.goto('/');
    await preview.evaluate(async()=>{
      const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
      const {renderCardSvg}=await import('/src/lib/card-generator/cardRenderer.js');
      const {initialArtwork}=await import('/src/lib/card-generator/cardArtworkService.js');
      const card=PILOT.cards.find(card=>card.card_code==='TOC-003');
      document.body.innerHTML=`<main id="reference-design">${renderCardSvg(card,PILOT,initialArtwork(card.card_code))}</main>`;
      const style=document.createElement('style');style.textContent='html,body{margin:0!important;padding:0!important;background:#e7e9e5}#reference-design{width:756px;height:1056px}#reference-design>svg{display:block;width:100%;height:100%}';document.head.append(style);
      await document.fonts.ready;
      await Promise.all([...document.querySelectorAll('image')].map(el=>new Promise((resolve,reject)=>{const image=new Image();image.onload=resolve;image.onerror=reject;image.src=el.getAttribute('href');})));
    });
    mkdirSync('docs/card-generator/previews',{recursive:true});
    await preview.locator('#reference-design').screenshot({path:'docs/card-generator/previews/tochi-common-v5.png'});
  } finally {await preview.close();}
});

test('all Type badges and three-digit stats stay inside their own panels in preview and export',async({page})=>{
  await authenticate(page,'COB-008');
  const result=await page.evaluate(async()=>{
    const {PILOT,TYPES}=await import('/src/lib/card-generator/cardSchema.js');
    const {TEMPLATES}=await import('/src/lib/card-generator/cardDrafts.js');
    const {renderCardSvg}=await import('/src/lib/card-generator/cardRenderer.js');
    const {inspectSvg,svgForExport}=await import('/src/lib/card-generator/cardExportService.js');
    const {emptyArtwork,emptyBack}=await import('/src/lib/card-generator/cardArtworkService.js');
    const source=PILOT.cards.find(card=>card.card_code==='COB-008');
    const issues=[];
    for(const template of TEMPLATES)for(const type of TYPES){
      const card={...source,type,stats:{attack:999,hp:999,defense:999}};
      issues.push(...inspectSvg(renderCardSvg(card,PILOT,{}, {template})).map(error=>({template,type,error})));
    }
    const exported=await svgForExport(source,PILOT,emptyArtwork(),emptyBack(),{proof:true});
    const broken=renderCardSvg(source,PILOT).replace('data-text-box="type"','transform="translate(150 0)" data-text-box="type"');
    const host=document.createElement('div');host.innerHTML=broken;document.body.append(host);
    // getBBox uses local coordinates, so move the text's actual x/tspan positions.
    const type=host.querySelector('[data-text-box="type"]');type.removeAttribute('transform');
    type.setAttribute('x','814.5');type.querySelector('tspan').setAttribute('x','814.5');
    const {validateRenderedSvg}=await import('/src/lib/card-generator/cardValidationService.js');
    const catchesOverflow=validateRenderedSvg(host.querySelector('svg')).some(error=>error.startsWith('type:'));
    host.remove();
    return {issues,exportIssues:inspectSvg(exported),catchesOverflow,exportedType:exported.includes('THUNDER'),frameEmbedded:exported.includes('data:image/png;base64,')};
  });
  expect(result.issues).toEqual([]);
  expect(result.exportIssues).toEqual([]);
  expect(result.catchesOverflow).toBeTruthy();
  expect(result.exportedType && result.frameEmbedded).toBeTruthy();
  await expect(page.locator('.cg-preview-artboard')).toHaveScreenshot('thunder-epic-safe-panels.png');
});

test('Card Studio groups design and registration and restores the selected design',async({page})=>{
  await authenticate(page,'COB-008');
  await expect(page.locator('.app-sidebar').getByRole('link',{name:'Card Studio',exact:true})).toHaveCount(1);
  await expect(page.locator('.app-sidebar').getByRole('link',{name:/^(Card Generator|Register Card)$/})).toHaveCount(0);
  const workflow=page.getByRole('navigation',{name:'Alur Card Studio'});
  await expect(workflow.getByRole('link',{name:'Desain & cetak'})).toHaveAttribute('aria-current','page');
  await page.route(`${supabaseUrl}/rest/v1/**`,route=>route.fulfill({json:route.request().url().includes('/profiles')?{id:user.id,full_name:'Generator test'}:[]}));
  await page.routeWebSocket(/\/realtime\/v1\//,socket=>socket.close());
  await workflow.getByRole('link',{name:'Registrasi kartu',exact:true}).click();
  await expect(page).toHaveURL(/\/admin\/game\/register$/);
  await expect(page.getByRole('heading',{name:'Registrasi kartu',exact:true})).toBeVisible();
  await page.getByLabel('Nama Karakter / Monster',{exact:true}).fill('Draft registrasi Thunder');
  const activeReader = () => page.evaluate(async()=>{
    const {supabase}=await import('/src/lib/supabase.js');
    return supabase.getChannels().filter(channel=>channel.topic.includes('game_card_register_listener')).length;
  });
  await expect.poll(activeReader).toBe(1);
  await expect(workflow.getByRole('link',{name:'Registrasi kartu',exact:true})).toHaveAttribute('aria-current','page');
  await expect(page.locator('.app-sidebar').getByRole('link',{name:'Card Studio',exact:true})).toHaveClass(/sidebar-link-active/);
  await workflow.getByRole('link',{name:'Desain & cetak'}).click();
  await expect(page.locator('.cg-preview-heading')).toContainText('COB-008');
  await expect.poll(activeReader).toBe(0);
  await workflow.getByRole('link',{name:'Registrasi kartu',exact:true}).click();
  await expect(page.getByLabel('Nama Karakter / Monster',{exact:true})).toHaveValue('Draft registrasi Thunder');
  await expect.poll(activeReader).toBe(1);
  await page.goto('/admin/cards');
  await expect(page).toHaveURL(/\/admin\/card-generator$/);
  await expect(page.locator('.cg-preview-heading')).toContainText('COB-008');
});

test('independent skill icon uploads persist, export as embedded images and reset review on change',async({page})=>{
  await authenticate(page);
  const fixture=async(color,width=512,height=512)=>Buffer.from(await page.evaluate(async({color,width,height})=>{
    const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
    const context=canvas.getContext('2d');context.fillStyle=color;context.fillRect(0,0,width,height);
    context.fillStyle='white';context.fillRect(width*.38,height*.2,width*.24,height*.6);
    return [...new Uint8Array(await(await new Promise(resolve=>canvas.toBlob(resolve,'image/png'))).arrayBuffer())];
  },{color,width,height}));
  const stored=new Map();
  await page.route(`${supabaseUrl}/storage/v1/object/**`,async route=>{
    const key=route.request().url().replace('/object/public/','/object/');
    if(route.request().method()==='POST'){
      const body=route.request().postDataBuffer(),start=body.indexOf(Buffer.from('RIFF'));
      const bytes=body.subarray(start,start+body.readUInt32LE(start+4)+8);stored.set(key,bytes);
      return route.fulfill({json:{Key:'test-icon-fixture'}});
    }
    const bytes=stored.get(key);return bytes?route.fulfill({contentType:'image/webp',body:bytes}):route.fulfill({status:404});
  });
  const character=await fixture('#285f78',1400,1000),one=await fixture('#ff680b'),two=await fixture('#057ad9');
  await page.locator('.cg-artwork-editor input[type=file]').first().setInputFiles({name:'character-fixture.png',mimeType:'image/png',buffer:character});
  await expect(page.locator('.cg-preview-artboard image[data-art-layer="1"]')).toHaveCount(1);
  for(const [index,bytes] of [[1,one],[2,two]]){
    await page.getByLabel(`Upload ikon Skill ${index}`,{exact:true}).setInputFiles({name:`skill-${index}.png`,mimeType:'image/png',buffer:bytes});
    await expect(page.locator(`.cg-preview-artboard image[data-skill-icon-image="${index}"]`)).toHaveCount(1);
    await expect(page.getByRole('img',{name:`Ikon Skill ${index}`,exact:true})).toHaveJSProperty('naturalWidth',512);
  }
  await page.getByLabel('Karakter, pose unik, keterbacaan, dan referensi maskot sudah ditinjau.').check();
  await page.getByRole('button',{name:'Approve artwork',exact:true}).click();
  await page.getByRole('button',{name:'Periksa artwork & render',exact:true}).click();
  await expect(page.locator('.cg-preview-heading')).toContainText('Ready for Print');
  const result=await page.evaluate(async()=>{
    const {PILOT}=await import('/src/lib/card-generator/cardSchema.js');
    const {exportCards}=await import('/src/lib/card-generator/cardExportService.js');
    const key=Object.keys(localStorage).find(key=>key.startsWith('tbc:card-generator:'));
    const workspace=JSON.parse(localStorage.getItem(key));
    const result=await exportCards([PILOT.cards.find(c=>c.card_code==='COB-006')],PILOT,workspace,{format:'svg',side:'both',proof:false});
    const JSZip=(await import('/node_modules/.vite/deps/jszip.js')).default,zip=await JSZip.loadAsync(result.blob);
    const xml=new DOMParser().parseFromString(await zip.file('COB-006-front.svg').async('string'),'image/svg+xml');
    return {icons:[...xml.querySelectorAll('[data-skill-icon-image]')].map(el=>el.getAttribute('href')),frame:xml.querySelector('[data-reference-frame]').getAttribute('href'),card:PILOT.cards.find(c=>c.card_code==='COB-006').skills[0].name};
  });
  expect(result.icons).toHaveLength(2);expect(result.icons.every(url=>url.startsWith('data:image/webp;base64,'))).toBeTruthy();
  expect(result.icons[0]).not.toBe(result.icons[1]);expect(result.frame).toMatch(/^data:image\/png;base64,/);expect(result.card).toBe('Arc Rally');
  await page.reload();await page.locator('.cg-library-row > button').filter({hasText:'COB-006'}).click();
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image]')).toHaveCount(2);
  await page.getByLabel('Tampilan ikon Skill 2',{exact:true}).selectOption('contain');
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image="2"]')).toHaveAttribute('preserveAspectRatio','xMidYMid meet');
  await expect(page.locator('.cg-preview-heading')).toContainText('Artwork Draft');
  await page.getByRole('button',{name:'Hapus ikon Skill 1',exact:true}).click();
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image="1"]')).toHaveCount(0);
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image="2"]')).toHaveCount(1);
  await page.locator('.cg-library-row > button').filter({hasText:'TOC-003'}).click();
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image]')).toHaveCount(0);
  await page.getByRole('button',{name:'＋ Buat kartu',exact:true}).click();
  await page.locator('.cg-template-grid > button').filter({has:page.getByText('Rare',{exact:true})}).click();
  await expect(page.locator('.cg-data-form .cg-skill-icon-upload')).toHaveCount(2);
  await page.getByLabel('Upload ikon Skill 1',{exact:true}).setInputFiles({name:'custom-skill.png',mimeType:'image/png',buffer:one});
  await expect(page.locator('.cg-preview-artboard image[data-skill-icon-image="1"]')).toHaveCount(1);
});
