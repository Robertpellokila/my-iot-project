import test from 'node:test';import assert from 'node:assert/strict';
import {materialDraft,normalizeRecipeMaterials,recipeDraft} from '../../src/lib/card-generator/fusionRecipeForm.js';
test('Fusion form separates EXACT, ONE TAG and ONE OF into real engine fields',()=>{
 const rows=normalizeRecipeMaterials([materialDraft({card_code:'cob_006',quantity:2}),materialDraft({material_type:'one_tag',tag:' Fusion:VINE '}),materialDraft({material_type:'one_of',card_codes:['TOC_006','toc_006','FOX_007']})]);
 assert.equal(rows[0].card_code,'COB_006');assert.equal(rows[0].quantity,2);assert.equal(rows[1].material_type,'tag');assert.equal(rows[1].tag,'fusion:vine');assert.deepEqual(rows[2].card_codes,['TOC_006','FOX_007']);assert.deepEqual(rows[0].allowed_zones,['active','bench']);
});
test('Fusion form rejects missing choices, invalid quantities and zones',()=>{
 for(const row of [{card_code:''},{material_type:'one_of',card_codes:[]},{material_type:'tag',tag:''},{card_code:'A',quantity:1.5},{card_code:'A',allowed_zones:[]},{card_code:'A',allowed_zones:['graveyard']}])assert.throws(()=>normalizeRecipeMaterials([materialDraft(row)]));
});
test('new Fusion recipes default to actual result stats; editing preserves metadata and custom limits',()=>{
 const card={id:'10000000-0000-4000-8000-000000000001',name:'Result',hp:160,attack:45,defense:18};
 const first=recipeDraft(card);assert.deepEqual(first.result_stat_spec.hp,{mode:'fixed',value:160});assert.notEqual(first.id,recipeDraft(card).id);
 const source={id:first.id,code:'existing',metadata:{legacy:true},limits:{once_per_battle:false,max_uses:5},result_stat_spec:{hp:{mode:'material_sum_percent',value:.8}}};
 const edit=recipeDraft(card,source);assert.equal(edit.limits.max_uses,5);edit.result_stat_spec.hp.value=.9;assert.equal(source.result_stat_spec.hp.value,.8);assert.equal(edit.metadata.legacy,true);
});
