import test from 'node:test';
import assert from 'node:assert/strict';
import { PILOT } from '../../src/lib/card-generator/cardSchema.js';
import { editableStudioCard,studioLibrary,recordToStudioCard,studioSaveEntries } from '../../src/lib/card-generator/cardCatalogBridge.js';
import { sanitizeWorkspace,emptyArtwork,emptyBack } from '../../src/lib/card-generator/cardArtworkService.js';
import { normalizeDraft } from '../../src/lib/card-generator/cardDrafts.js';
test('pilot edits survive reload without altering or duplicating audited source',()=>{
 const original=structuredClone(PILOT.cards[0]),edit=editableStudioCard(original);edit.stats.hp=155;edit.name='Edited';
 const workspace={dataset_id:PILOT.id,custom_cards:[edit],artworks:{[edit.card_code]:emptyArtwork()},back:emptyBack()};
 const restored=sanitizeWorkspace(JSON.parse(JSON.stringify(workspace)),PILOT.cards,PILOT.id),library=studioLibrary(restored);
 assert.equal(library.length,42);assert.equal(library[0].stats.hp,155);assert.equal(library[0].name,'Edited');assert.notEqual(PILOT.cards[0].stats.hp,155);
 assert.deepEqual(original,PILOT.cards[0]);assert.equal(studioSaveEntries([library[0]],restored)[0].card.source_pilot_code,original.card_code);
});
test('registered data imports stats, both skills and stable source identity',()=>{
 const id='00000000-0000-4000-8000-000000000123';
 const record={id,name:'Coby — Vanguard',card_code:'COB_006',element:'Electric',rarity:'rare',hp:132,attack:38,defense:12,metadata:{skills:[{name:'First',description:'one'},{name:'Second',description:'two'}]}};
 const card=recordToStudioCard(record);
 assert.equal(card.source_game_card_id,id);assert.equal(card.type,'Thunder');assert.equal(card.rarity,'Rare');assert.equal(card.name,'Coby');assert.equal(card.subtitle,'Vanguard');assert.equal(card.stats.hp,132);assert.equal(card.skills[1].name,'Second');assert.equal(normalizeDraft(card).card_code,card.card_code);
});
test('catalog edits retain special template and skill text but refresh live core stats',()=>{
 const saved={...editableStudioCard(PILOT.cards[0]),design_template:'Winning',serial_number:'CH-001'};
 const card=recordToStudioCard({id:'00000000-0000-4000-8000-000000000111',name:'Champion',card_code:'CH_001',element:'Light',rarity:'mythic',hp:175,attack:52,defense:24,metadata:{studio_card:saved}});
 assert.equal(card.design_template,'Winning');assert.equal(card.serial_number,'CH-001');assert.equal(card.stats.attack,52);assert.equal(card.type,'Light');assert.equal(card.skills[0].name,saved.skills[0].name);
});
test('RFID copies with inherited Studio metadata receive independent editor identities',()=>{
 const master=editableStudioCard(PILOT.cards[0]);
 const record={id:'00000000-0000-4000-8000-000000000122',name:'Physical Coby',card_code:'COB_003',hp:108,attack:30,defense:9,metadata:{studio_card:master,catalog_source_id:'master'}};
 const copy=recordToStudioCard(record);assert.notEqual(copy.card_code,master.card_code);assert.equal(copy.source_game_card_id,record.id);assert.equal(copy.source_pilot_code,undefined);
});
