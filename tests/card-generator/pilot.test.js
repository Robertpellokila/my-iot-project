import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PILOT, CARD_BY_CODE, templateFor } from '../../src/lib/card-generator/cardSchema.js';
import { validateDataset, cardReadiness, renderSignature } from '../../src/lib/card-generator/cardValidationService.js';
import { eligibleCodes, validateMaterials, materialCombinations, fusionsFor, fusionOverview } from '../../src/lib/card-generator/cardFusionResolver.js';
import { renderCardSvg, textIssues } from '../../src/lib/card-generator/cardRenderer.js';
import { RARITY_THEMES } from '../../src/lib/card-generator/cardRarityTheme.js';
import { printGeometry } from '../../src/lib/card-generator/cardLayoutTokens.js';
import { sheetPositions, checkExport } from '../../src/lib/card-generator/cardExportService.js';
import { sanitizeWorkspace } from '../../src/lib/card-generator/cardArtworkService.js';
import { compareProduction } from '../../src/lib/card-generator/cardProductionMapping.js';

const clone = () => structuredClone(PILOT);
test('audited pilot is isolated: exactly 30 base + 12 fusion, all source references valid', () => {
  assert.equal(PILOT.cards.length, 42); assert.deepEqual(validateDataset(PILOT), []);
  assert.equal(PILOT.source_sha256, '4e06c23eafc69ca4b64cb45ac18b19760afd48477958cbb221cce0fa600a46c1');
  assert.equal(PILOT.cards.filter(card => card.kind === 'base').length, 30);
});
test('Coby Arc Vanguard matches audited source and EXACT partner', () => {
  const card = CARD_BY_CODE.get('COB-006');
  assert.deepEqual(card.stats, { hp:120, attack:33, defense:11 }); assert.equal(card.type, 'Knight'); assert.equal(card.rarity, 'Rare');
  assert.equal(card.skills[0].name, 'Arc Rally'); assert.match(card.skills[0].description, /\+6.*Summon ally/);
  assert.match(card.skills[1].description, /heal 12.*ATAU \+4 DEF/); assert.equal(card.skills[1].cooldown_turns, 2);
  assert.equal(validateMaterials(PILOT.recipes[0], ['TOC-006','COB-006'], PILOT.cards), true);
  assert.equal(validateMaterials(PILOT.recipes[0], ['TOC-008','COB-006'], PILOT.cards), false);
});
test('once-per-battle Necro Recall preserves all ten guardrails and complete original text', () => {
  const card = CARD_BY_CODE.get('NUL-006'), limits = card.necro_recall;
  assert.deepEqual(limits, { once_per_battle:true, ap_cost:2, requires_caster_zone:'active', material_kind:'base', allow_fusion:false, allow_fusion_consumed:false, destination:'bench', max_hp_ratio:.4, attack_skill_locked_until_next_turn:true, reset_once_per_battle:false });
  for (const term of ['2 AP','non-Fusion','fusion_consumed','Bench','40%','turn berikutnya','tidak di-reset']) assert.ok(card.skills[1].description.includes(term));
  assert.match(renderCardSvg(card, PILOT), /once-per-battle tidak di-reset/);
});
test('ONE_OF / TAG are narrow, all legal permutations constructible, no Type substitutions', () => {
  assert.deepEqual(fusionOverview(CARD_BY_CODE.get('COB-007'),PILOT.recipes,PILOT.cards), ['F02 · FAL-007']);
  assert.ok(fusionOverview(CARD_BY_CODE.get('FOX-006'),PILOT.recipes,PILOT.cards).includes('F03 · RAB-006/RAB-007'));
  assert.ok(validateMaterials(PILOT.recipes[1], ['COB-008','FAL-007'], PILOT.cards));
  assert.ok(!validateMaterials(PILOT.recipes[1], ['COB-006','FAL-007'], PILOT.cards));
  const tag = PILOT.recipes.find(recipe => recipe.id === 'F03');
  assert.deepEqual(eligibleCodes(tag.slots[0], PILOT.cards).sort(), ['FOX-006','FOX-007']);
  assert.equal(materialCombinations(tag, PILOT.cards).length, 4);
  assert.ok(!validateMaterials(tag, ['COB-007','RAB-007'], PILOT.cards));
  assert.ok(!validateMaterials(tag, [{ card_code:'FOX-006',instance_id:'same' },{ card_code:'RAB-007',instance_id:'same' }], PILOT.cards));
  for (const recipe of PILOT.recipes) for (const materials of materialCombinations(recipe, PILOT.cards)) assert.ok(validateMaterials(recipe, [...materials].reverse(), PILOT.cards));
  assert.ok(validateMaterials(PILOT.recipes.at(-1), ['OTT-008','COB-008','TOC-008'], PILOT.cards));
});
test('validator rejects corrupted data, duplicate codes, broken recipes, missing skills and broadened tags', () => {
  for (const mutate of [data => data.cards[1].card_code = data.cards[0].card_code, data => data.cards[0].stats.hp = NaN,
    data => data.cards[0].skills.pop(), data => data.cards[0].skills[1].cooldown_turns = 99,
    data => data.cards.find(card => card.card_code === 'NUL-006').skills[1].ap_cost = 0,
    data => data.recipes[0].slots[0].eligible_codes = ['COB-999'],
    data => data.cards.find(card => card.card_code === 'FOX-006').tags = ['Thunder'],
    data => data.cards.find(card => card.card_code === 'NUL-006').necro_recall.reset_once_per_battle = true]) {
    const data = clone(); mutate(data); assert.ok(validateDataset(data).length);
  }
});
test('all frames share anchors and have distinct vector ornament designs; Fusion retains source rarity', () => {
  const card = CARD_BY_CODE.get('COB-006'), anchors = [];
  const designs = Object.keys(RARITY_THEMES).filter(t=>!['Trial Join','Winning'].includes(t)).map(template => {
    const svg = renderCardSvg(card, PILOT, {}, { template });
    anchors.push([...svg.matchAll(/data-anchor="([^"]+)"/g)].map(match => match[1]));
    assert.ok(svg.includes('viewBox="0 0 756 1056"')); return svg;
  });
  assert.equal(new Set(designs).size, 7); anchors.forEach(value => assert.deepEqual(value, anchors[0]));
  assert.equal(templateFor(CARD_BY_CODE.get('F01')), 'Fusion'); assert.equal(CARD_BY_CODE.get('F01').rarity, 'Legendary');
});
test('missing artwork cannot become ready; modified placement invalidates exact render receipt', () => {
  const card = CARD_BY_CODE.get('COB-006'); assert.equal(cardReadiness(card, PILOT).ready, false);
  assert.throws(() => checkExport(card, PILOT, {}, {}, false), /belum Ready/);
  assert.doesNotThrow(() => checkExport(card, PILOT, {}, {}, true));
  assert.notEqual(renderSignature(card, { character:{ url:'/test.webp',scale:1 } }), renderSignature(card, { character:{ url:'/test.webp',scale:1.1 } }));
});
test('long Necro Recall is flagged rather than silently shortened for print', () => {
  const flagged = PILOT.cards.filter(card => textIssues(card, PILOT).length).map(card => card.card_code);
  assert.deepEqual(flagged, ['NUL-006']);
});
test('42 briefs distinguish the generated Tochi draft from 41 missing illustrations', () => {
  const manifest = JSON.parse(readFileSync(new URL('../../src/data/card-generator/artwork-manifest.json', import.meta.url)));
  assert.equal(manifest.entries.length, 42); assert.equal(new Set(manifest.entries.map(entry => entry.artwork_prompt)).size, 42);
  for (const entry of manifest.entries) { assert.ok(CARD_BY_CODE.has(entry.card_code)); assert.notEqual(entry.approval_status, 'approved');
    if (entry.card_code === 'TOC-003') { assert.equal(entry.production_status, 'draft'); assert.equal(entry.artwork_path, 'images/card-generator/tochi-sprout-keeper-v1.png'); }
    else { assert.equal(entry.artwork_path, null); assert.equal(entry.production_status, 'artwork_required'); }
  }
});
test('300DPI export is 69×94mm with bleed; duplex cards align on mirrored axes', () => {
  const geometry = printGeometry(); assert.equal(geometry.widthMm,69); assert.equal(geometry.heightMm,94);
  assert.equal(geometry.widthPx,815); assert.equal(geometry.heightPx,1110);
  assert.throws(() => printGeometry({ width:NaN })); assert.throws(() => printGeometry({ width:63,height:90 }));
  const front=sheetPositions(8), back=sheetPositions(8,{},'long-edge',true);
  front.forEach((position,index) => { assert.ok(Math.abs(position.x + back[index].x + position.width - 210) < .001); assert.equal(position.y,back[index].y); assert.equal(position.page,back[index].page); });
});
test('production mapping is read-only and canonical ID never becomes RFID UID', () => {
  const card=CARD_BY_CODE.get('COB-006'); assert.equal(card.production_mapping.card_code,'COB_006'); assert.equal(card.production_mapping.rfid_uid,null);
  const records=[{id:'physical-1',card_code:'COB_006',name:'Old card',hp:999,attack:999,defense:999,rarity:'Epic'}];
  const original=JSON.stringify(records), report=compareProduction(PILOT,records).find(row=>row.card_code==='COB-006');
  assert.equal(JSON.stringify(records),original); assert.ok(report.differences[0].fields.includes('hp'));
});
test('workspace import strips approval receipts and unsafe artwork URLs', () => {
  const input={dataset_id:PILOT.id,artworks:{'COB-006':{character:{url:'javascript:alert(1)',sha256:'a'.repeat(64)},approval_status:'approved',asset_status:'verified',render_receipt:'forged'}}};
  const result=sanitizeWorkspace(input,PILOT.cards).artworks['COB-006']; assert.equal(result.character,null); assert.equal(result.asset_status,'unchecked'); assert.equal(result.render_receipt,null);
});

test('shared back is the exact supplied PNG for every rarity and ignores imported logos', async () => {
  const { FIXED_BACK } = await import('../../src/lib/card-generator/cardBack.js');
  const { createHash } = await import('node:crypto');
  const file = readFileSync(new URL('../../public/images/tbc-back.png',import.meta.url));
  assert.equal(createHash('sha256').update(file).digest('hex'),FIXED_BACK.sha256);
  assert.deepEqual([file.readUInt32BE(16),file.readUInt32BE(20)],[1024,1536]);
  for (const template of Object.keys(RARITY_THEMES)) {
    const svg=renderCardSvg(CARD_BY_CODE.get('COB-006'),PILOT,{back:{logo:{url:'https://example.invalid/other-logo.png'}}},{side:'back',template});
    assert.match(svg,/data-fixed-back="timedoor-academy-green-tbc-v1"/);
    assert.match(svg,/href="\/images\/tbc-back.png"/);assert.ok(!svg.includes('other-logo.png'));
  }
});

test('custom cards normalize skill metadata, validate required data, and persist independently', async () => {
  const {createDraft,normalizeDraft,validateDraft}=await import('../../src/lib/card-generator/cardDrafts.js');
  const before=JSON.stringify(PILOT), draft=createDraft('Epic');
  assert.equal(draft.rarity,'Epic');assert.ok(validateDraft(draft).length);
  const card=normalizeDraft({...draft,name:'Coby',subtitle:'Custom variant',role:'Guardian',skills:[{name:'Spark',description:'Serangan normal. CD 2.'},{name:'Heal',description:'Pulihkan 8 HP. 1 AP. Sekali/battle.'}],tags:['GUARD']});
  assert.deepEqual(validateDraft(card),[]);assert.equal(card.skills[0].cooldown_turns,2);assert.equal(card.skills[1].ap_cost,1);assert.equal(card.skills[1].once_per_battle,true);
  const incoming={dataset_id:PILOT.id,custom_cards:[card],artworks:{},back:{logo:{url:'https://example.invalid/back.png'},asset_status:'verified'}};
  const restored=sanitizeWorkspace(incoming,PILOT.cards);
  assert.deepEqual(restored.custom_cards,[card]);assert.ok(restored.artworks[card.card_code]);assert.equal(restored.back.logo,undefined);assert.equal(restored.back.asset_status,'unchecked');
  assert.doesNotThrow(()=>checkExport(card,PILOT,{},restored.back,true));
  assert.throws(()=>checkExport(draft,PILOT,{},restored.back,true),/Isi nama dan efek/);
  assert.equal(createDraft('Fusion',[card]).card_code,'DRAFT-002');
  assert.equal(createDraft('Fusion').kind,'fusion');assert.equal(JSON.stringify(PILOT),before);
  assert.throws(()=>sanitizeWorkspace({...incoming,custom_cards:[card,card]},PILOT.cards),/duplikat/);
});

test('illustrated Tochi example has real verified bytes and remains an unapproved draft', async () => {
  const {initialArtwork}=await import('../../src/lib/card-generator/cardArtworkService.js');
  const {createHash}=await import('node:crypto');
  const art=initialArtwork('TOC-003');
  const bytes=readFileSync(new URL('../../public/images/card-generator/tochi-sprout-keeper-v1.png',import.meta.url));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),art.character.sha256);
  assert.equal(art.approval_status,'not_reviewed');assert.equal(art.production_status,'draft');
  assert.equal(cardReadiness(CARD_BY_CODE.get('TOC-003'),PILOT,art).ready,false);
  const restored=sanitizeWorkspace({dataset_id:PILOT.id,artworks:{'TOC-003':{version:1,character:null}}},PILOT.cards);
  assert.equal(restored.artworks['TOC-003'].character.sha256,art.character.sha256);
  const removed=sanitizeWorkspace({dataset_id:PILOT.id,artworks:{'TOC-003':{version:2,character:null}}},PILOT.cards);
  assert.equal(removed.artworks['TOC-003'].character,null);
});

test('reference frame assets match supplied files and choose Rare frame by element', async () => {
  const {referenceFrameFor}=await import('../../src/lib/card-generator/cardReferenceFrames.js');
  const frames=JSON.parse(readFileSync(new URL('../../src/data/card-generator/reference-frames.json',import.meta.url)));
  const {createHash}=await import('node:crypto');
  for (const frame of Object.values(frames)) {
    const bytes=readFileSync(new URL(`../../public${frame.url}`,import.meta.url));
    assert.equal(createHash('sha256').update(bytes).digest('hex'),frame.sha256);
    assert.equal(frame.trim_height,1464);assert.equal(bytes.readUInt32BE(16),1024);
  }
  assert.equal(referenceFrameFor(CARD_BY_CODE.get('COB-006')).url,frames['rare-knight'].url);
  assert.equal(referenceFrameFor({...CARD_BY_CODE.get('TOC-003'),rarity:'Rare'}).url,frames['rare-forest'].url);
  assert.equal(referenceFrameFor({...CARD_BY_CODE.get('COB-008'),rarity:'Rare'}).url,frames['rare-thunder'].url);
  const epic=renderCardSvg(CARD_BY_CODE.get('COB-008'),PILOT);
  assert.match(epic,/data-reference-frame="Epic"/);assert.match(epic,/reference-frame/);
});

test('two per-card skill icons round-trip, render independently and invalidate print receipts', async () => {
  const {emptyArtwork,setArtworkAsset}=await import('../../src/lib/card-generator/cardArtworkService.js');
  const art=emptyArtwork(),card=CARD_BY_CODE.get('COB-006');
  const asset={url:'/skill-one.webp',sha256:'a'.repeat(64),width:512,height:512,x:0,y:0,scale:1,fit:'cover'};
  const initial=renderSignature(card,art);
  setArtworkAsset(art,'skill-1-icon',asset);setArtworkAsset(art,'skill-2-icon',{...asset,url:'/skill-two.webp',sha256:'b'.repeat(64),fit:'contain'});
  assert.notEqual(renderSignature(card,art),initial);
  const svg=renderCardSvg(card,PILOT,art);
  assert.match(svg,/data-skill-icon-image="1"/);assert.match(svg,/data-skill-icon-image="2"/);
  assert.match(svg,/href="\/skill-one.webp"/);assert.match(svg,/href="\/skill-two.webp"/);
  const restored=sanitizeWorkspace({dataset_id:PILOT.id,artworks:{'COB-006':art}},PILOT.cards);
  assert.equal(restored.artworks['COB-006'].skill_icons[0].sha256,asset.sha256);
  assert.equal(restored.artworks['COB-006'].skill_icons[1].fit,'contain');
  assert.deepEqual(restored.artworks['F01'].skill_icons,[null,null]);
  const approved={...art,approval_status:'approved',asset_status:'verified',render_receipt:renderSignature(card,art)};
  const changed=structuredClone(approved);changed.skill_icons[1].fit='cover';
  assert.notEqual(renderSignature(card,changed),approved.render_receipt);
  changed.skill_icons[0].width=64;
  assert.ok(cardReadiness(card,PILOT,changed).errors.some(error=>error.includes('Ikon Skill 1')));
  setArtworkAsset(art,'skill-1-icon',null);
  assert.ok(!renderCardSvg(card,PILOT,art).includes('data-skill-icon-image="1"'));
  assert.ok(renderCardSvg(card,PILOT,art).includes('data-skill-icon-image="2"'));
  assert.throws(()=>setArtworkAsset(art,'unknown',asset));
});

test('fallback skill emblems have no scribble overlay in any print template', () => {
 for (const rarity of ['Common','Rare','Epic','Legendary','Mythic']) {
  const card={...CARD_BY_CODE.get('TOC-003'),rarity};
  for (const bleed of [false,true]) {
   const svg=renderCardSvg(card,PILOT,{}, {template:rarity,bleed});
   assert.ok(!svg.includes('M-40 13-13-27'));
   assert.ok(!svg.includes('M-36 12-7-26'));
   assert.match(svg,/data-skill-icon="forest"/);
   assert.match(svg,/data-skill-icon="support"/);
  }
 }
});


test('Trial Join and Winning preserve editable data, icons, rarity and shared back',async()=>{
 const {createDraft,normalizeDraft}=await import('../../src/lib/card-generator/cardDrafts.js');
 for(const template of ['Trial Join','Winning']){
  const draft=createDraft(template);const card=normalizeDraft({...draft,name:'Coby',subtitle:'First Spark',role:'Guardian',type:'Knight',skills:[{name:'Buddy Guard',description:'Beri Shield 8 pada diri. CD 2.'},{name:'First Step',description:'Serangan normal +3 pada aksi pertama setelah summon.'}]});
  assert.equal(templateFor(card),template);assert.equal(card.rarity,template==='Winning'?'Mythic':'Common');
  const svg=renderCardSvg(card,PILOT,{skill_icons:[{url:'/icon.png'},null]});
  assert.ok(svg.includes(`data-edition-template="${template}"`));assert.match(svg,/Buddy Guard/);assert.match(svg,/data-skill-upload="1"/);assert.match(svg,/data-panel-bounds=/);
  assert.ok(svg.includes(`data-edition-frame="${template}"`));assert.match(svg,/viewBox="0 0 704 1056"/);
  assert.ok(!textIssues(card,PILOT).length);
  assert.equal(renderCardSvg(card,PILOT,{}, {side:'back'}).match(/data-fixed-back="[^"]+"/)[0],renderCardSvg(CARD_BY_CODE.get('TOC-003'),PILOT,{}, {side:'back'}).match(/data-fixed-back="[^"]+"/)[0]);
 }
});

test('all templates share stat symbols and follow the selected type, including Fusion and editions',async()=>{
 const {TYPE_BADGES,RARITY_THEMES}=await import('../../src/lib/card-generator/cardRarityTheme.js');
 const expected={};
 for(const template of Object.keys(RARITY_THEMES))for(const type of Object.keys(TYPE_BADGES)){
  const card={...CARD_BY_CODE.get('TOC-003'),type,design_template:template};
  for(const bleed of [false,true]){
   const svg=renderCardSvg(card,PILOT,{}, {bleed});
   assert.equal((svg.match(/data-type-icon=/g)||[]).length,1,`${template}/${type}`);
   assert.ok(svg.includes(`data-type-icon="${type}"`));
   for(const kind of ['attack','hp','defense']){
    assert.equal((svg.match(new RegExp(`data-stat-icon="${kind}"`,'g'))||[]).length,1);
    const path=svg.match(new RegExp(`data-stat-icon="${kind}"[^>]*><path d="([^"]+)"`))[1];
    expected[kind]??=path;assert.equal(path,expected[kind]);
   }
   assert.ok(svg.includes(`d="${TYPE_BADGES[type].path}"`));
   assert.ok(!svg.includes('undefined'));
  }
 }
});
