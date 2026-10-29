<script setup>
import {useAdminFeedback} from '../../composables/useAdminToast.js';
import {computed,onMounted,ref,watch} from 'vue';
import {supabase} from '../../lib/supabase.js';
import SearchableSelect from '../SearchableSelect.vue';
import {MATERIAL_MODES,STAT_MODES,materialDraft,recipeDraft,normalizeRecipeMaterials,materialSummary} from '../../lib/card-generator/fusionRecipeForm.js';
import {PILOT} from '../../lib/card-generator/cardSchema.js';
const props=defineProps({card:{type:Object,required:true}}),emit=defineEmits(['saving','saved']);
const recipes=ref([]),cards=ref([]),draft=ref(null),materials=ref([]),loading=ref(true),saving=ref(false),error=ref(''),notice=ref(''),selected=ref('');
const options=computed(()=>[...new Map(cards.value.filter(c=>c.id!==props.card.id).map(c=>[c.card_code,c])).values()]);
const tags=computed(()=>[...new Set(options.value.flatMap(card=>card.tags??[]))].sort());
const pilot=computed(()=>PILOT.recipes.find(r=>r.result_code===props.card.metadata?.studio_card?.source_pilot_code||r.result_code===props.card.metadata?.studio_card?.display_code||r.result_code===props.card.card_code));
const summary=computed(()=>materials.value.map(materialSummary).join(' + '));
watch(saving,value=>emit('saving',value));
function fresh(){selected.value='';draft.value=recipeDraft(props.card);materials.value=[materialDraft(),materialDraft()];error.value='';notice.value='';}
async function selectRecipe(id){
 if(!id){fresh();return;}error.value='';loading.value=true;
 try{const recipe=recipes.value.find(item=>item.id===id);const {data,error:e}=await supabase.from('fusion_recipe_materials').select('*').eq('recipe_id',id).order('sort_order');if(e)throw e;draft.value=recipeDraft(props.card,recipe);materials.value=(data??[]).map(materialDraft);selected.value=id;}
 catch(e){error.value=e.message;}finally{loading.value=false;}
}
async function load(id=selected.value){
 loading.value=true;error.value='';
 try{
  const [r,c]=await Promise.all([supabase.from('fusion_recipes').select('*').eq('result_game_card_id',props.card.id).order('priority'),supabase.from('game_cards').select('id,name,card_code,tags,fusion_only,metadata').order('name')]);
  if(r.error)throw r.error;if(c.error)throw c.error;recipes.value=r.data??[];cards.value=c.data??[];
  if(recipes.value.length)await selectRecipe(recipes.value.some(r=>r.id===id)?id:recipes.value[0].id);else fresh();
 }catch(e){error.value=e.message;}finally{loading.value=false;}
}
function usePilot(){
 if(!pilot.value)return;
 const resolve=code=>options.value.find(c=>c.metadata?.studio_card?.display_code===code||c.card_code.replaceAll('_','-')===code)?.card_code??code;
 materials.value=pilot.value.slots.map(slot=>materialDraft({material_type:slot.mode==='ONE_OF'?'one_of':slot.mode==='TAG'?'tag':'exact_card',card_code:resolve(slot.eligible_codes[0]),card_codes:slot.eligible_codes.map(resolve),tag:slot.tag??''}));
 notice.value='Pola pilot dimuat sebagai draft untuk kartu ini. Periksa material, lalu simpan resep.';
}
async function save(){
 if(saving.value||loading.value||!draft.value)return false;saving.value=true;error.value='';notice.value='';
 try{
  if(!draft.value.name.trim())throw new Error('Isi nama resep Fusion.');
  const normalized=normalizeRecipeMaterials(materials.value);
  const {data,error:e}=await supabase.rpc('save_studio_fusion_recipe',{p_result_game_card_id:props.card.id,p_recipe:JSON.parse(JSON.stringify(draft.value)),p_materials:JSON.parse(JSON.stringify(normalized))});
  if(e)throw e;if(!data?.recipe?.id)throw new Error('Resep belum tersimpan. Coba lagi.');
  const savedId=data.recipe.id;await load(savedId);notice.value=`Resep Fusion tersimpan · ${data.recipe.is_active?'Aktif di battle':'Nonaktif'}.`;emit('saved',{...data,summary:summary.value});return true;
 }catch(e){error.value=e.message||'Resep belum dapat disimpan.';return false;}finally{saving.value=false;}
}
defineExpose({save});onMounted(()=>load());
const adminToast=useAdminFeedback({error,info:()=>notice.value.startsWith('Resep Fusion tersimpan')?'':notice.value,scope:'card-generator/FusionRecipeEditor'});
</script>
<template>
 <section class="studio-fusion-editor" aria-labelledby="fusion-editor-heading">
  <header><p>FUSION WORKSHOP</p><h2 id="fusion-editor-heading">Resep Fusion</h2><span>{{ card.name }}</span></header>
  <p class="fusion-explainer">Tentukan kartu yang harus dikonsumsi untuk memanggil kartu ini. Setiap baris adalah syarat yang wajib dipenuhi oleh kartu berbeda.</p>
  <p v-if="loading" role="status">Memuat resep…</p><p v-if="error" class="fusion-error" role="alert">{{ error }}</p><p v-if="notice" class="fusion-notice" role="status">{{ notice }}</p>
  <template v-if="draft && !loading">
   <div class="fusion-recipe-picker"><label>Resep kartu ini<select :value="selected" :disabled="saving" @change="selectRecipe($event.target.value)"><option value="">+ Resep baru</option><option v-for="item in recipes" :key="item.id" :value="item.id">{{ item.name }}{{ item.is_active?' · Aktif':' · Nonaktif' }}</option></select></label><button v-if="pilot" type="button" :disabled="saving" @click="usePilot">Pakai pola {{ pilot.id }}</button></div>
   <form @submit.prevent="save"><fieldset :disabled="saving">
    <label>Nama resep<input v-model="draft.name" maxlength="150" required/></label>
    <label>Penjelasan resep<textarea v-model="draft.description" rows="2" maxlength="3000" placeholder="Contoh: gabungkan satu penjaga dan satu kartu hutan."/></label>
    <label class="fusion-check"><input v-model="draft.is_active" type="checkbox"/> Aktifkan resep di battle</label>
    <section class="fusion-materials"><h3>Material yang dibutuhkan</h3>
     <article v-for="(row,index) in materials" :key="row.key" class="fusion-material"><header><strong>Material {{ index+1 }}</strong><button type="button" :disabled="materials.length===1" :aria-label="`Hapus material ${index+1}`" @click="materials.splice(index,1)">Hapus</button></header>
      <label>Mode material<select v-model="row.material_type" :aria-label="`Mode material ${index+1}`"><option v-for="[value,label] in MATERIAL_MODES" :key="value" :value="value">{{ label }}</option></select></label>
      <label v-if="row.material_type==='exact_card'">Kartu EXACT<SearchableSelect v-model="row.card_code" :aria-label="`Kartu EXACT ${index+1}`"><option value="">Pilih kartu tertentu…</option><option v-for="item in options" :key="item.card_code" :value="item.card_code">{{ item.name }} · {{ item.card_code }}</option><option v-if="row.card_code && !options.some(c=>c.card_code===row.card_code)" :value="row.card_code">{{ row.card_code }} · kode tersimpan</option></SearchableSelect></label>
      <label v-else-if="row.material_type==='one_of'">Alternatif ONE OF<SearchableSelect v-model="row.card_codes" multiple :aria-label="`Alternatif ONE OF ${index+1}`"><option v-for="item in options" :key="item.card_code" :value="item.card_code">{{ item.name }} · {{ item.card_code }}</option><option v-for="code in row.card_codes.filter(code=>!options.some(c=>c.card_code===code))" :key="code" :value="code">{{ code }} · kode tersimpan</option></SearchableSelect><small>Satu kartu dari pilihan ini memenuhi satu slot.</small></label>
      <label v-else>Tag ONE TAG<input v-model="row.tag" :aria-label="`Tag ONE TAG ${index+1}`" list="studio-fusion-tags" placeholder="Contoh: fusion:AGILE_CODE"/><small>Kartu dengan tag yang sama dapat dipilih sebagai material.</small></label>
      <label>Jumlah kartu<input v-model.number="row.quantity" :aria-label="`Jumlah material ${index+1}`" type="number" min="1" max="20" required/></label>
      <div class="fusion-zone-options"><span>Zona material</span><label class="fusion-check"><input v-model="row.allowed_zones" type="checkbox" value="active" :aria-label="`Material ${index+1} dari Active`"/> Active</label><label class="fusion-check"><input v-model="row.allowed_zones" type="checkbox" value="bench" :aria-label="`Material ${index+1} dari Bench`"/> Bench</label></div>
     </article><button type="button" :disabled="materials.length>=20" @click="materials.push(materialDraft())">+ Tambah material</button>
    </section>
    <section class="fusion-stat-settings"><h3>Statistik hasil Fusion</h3><p>Gunakan nilai tetap atau hitung dari material yang dikonsumsi.</p><div v-for="[key,label] in [['hp','HP'],['attack','ATK'],['defense','DEF']]" :key="key" class="fusion-stat-row"><label>{{ label }} hasil<select v-model="draft.result_stat_spec[key].mode"><option v-for="[value,name] in STAT_MODES" :key="value" :value="value">{{ name }}</option></select></label><label>Nilai {{ label }}<input v-model.number="draft.result_stat_spec[key].value" type="number" :min="key==='hp'&&draft.result_stat_spec[key].mode==='fixed'?1:0" :step="draft.result_stat_spec[key].mode==='fixed'?1:0.01" required/></label><small v-if="draft.result_stat_spec[key].mode!=='fixed'">0.8 = 80% dari {{ draft.result_stat_spec[key].mode==='material_sum_percent'?'total':'nilai tertinggi' }} material.</small></div></section>
    <section class="fusion-limits"><h3>Batas penggunaan</h3><label class="fusion-check"><input v-model="draft.limits.once_per_battle" type="checkbox"/> Sekali per battle</label><label>Batas pemakaian<input v-model.number="draft.limits.max_uses" type="number" min="0" max="100"/><small>0 berarti tanpa batas tambahan.</small></label><label class="fusion-check"><input v-model="draft.consumes_turn" type="checkbox"/> Akhiri giliran setelah Fusion</label></section>
    <div class="fusion-recipe-summary"><strong>Ringkasan material</strong><p>{{ summary }}</p><span>Hasil: {{ card.name }} · {{ draft.result_zone==='bench'?'Bench':'Active' }}</span></div>
    <button class="fusion-save" type="submit">{{ saving?'Menyimpan…':'Simpan resep Fusion' }}</button>
   </fieldset></form>
   <datalist id="studio-fusion-tags"><option v-for="tag in tags" :key="tag" :value="tag"/></datalist>
  </template>
 </section>
</template>
<style scoped>
.studio-fusion-editor{padding:20px;color:#214b37;background:#fff;font-family:Inter,Arial,sans-serif}.studio-fusion-editor>header>p{font-size:9px;letter-spacing:.16em;color:#3a8550;font-weight:800;margin:0 0 8px}.studio-fusion-editor h2{font-size:24px;margin:0 0 6px}.studio-fusion-editor>header>span{font-size:12px;color:#657d6a}.studio-fusion-editor h3{font-size:14px;margin:0 0 14px}.fusion-explainer,.fusion-stat-settings>p{font-size:12px;line-height:1.7;color:#637c69}.studio-fusion-editor fieldset{min-width:0;border:0;margin:0;padding:0;display:grid;gap:17px}.studio-fusion-editor label{display:flex;flex-direction:column;gap:7px;min-width:0;font-size:12px;color:#47664f;font-weight:650}.studio-fusion-editor :is(input:not([type=checkbox]),select,textarea){box-sizing:border-box;width:100%;min-width:0;border:1px solid #cddfca;border-radius:8px;background:white;color:#214b37;font:12px/1.5 Inter,Arial,sans-serif;padding:10px}.studio-fusion-editor small{font-size:10px;font-weight:400;line-height:1.6;color:#718474}.studio-fusion-editor button{padding:10px 12px;font-size:11px;cursor:pointer}.fusion-recipe-picker{display:grid;gap:10px;margin:18px 0 22px}.fusion-materials{display:grid;gap:13px;border-top:1px solid #dce8d8;padding-top:20px}.fusion-material{display:grid;gap:14px;padding:15px;border:1px solid #cadfc5;border-radius:12px;background:#f7faf3}.fusion-material>header{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:12px}.fusion-material>header button{padding:5px 9px;background:white}.studio-fusion-editor .fusion-check{flex-direction:row;align-items:center;gap:8px;font-size:11px;line-height:1.6}.fusion-check input{accent-color:#216c3e;width:16px;height:16px;margin:0;flex:none}.fusion-zone-options{display:flex;gap:13px;flex-wrap:wrap;align-items:center}.fusion-zone-options>span{width:100%;font-size:10px;color:#6a806b}.fusion-stat-settings,.fusion-limits{display:grid;gap:14px;padding-top:20px;border-top:1px solid #dce8d8}.fusion-stat-row{display:grid;gap:10px}.fusion-stat-row>small{margin-top:-5px}.fusion-recipe-summary{padding:14px;border-radius:10px;background:#eaf4e4;border:1px solid #cfe1c5}.fusion-recipe-summary strong{font-size:11px}.fusion-recipe-summary p{font-size:12px;line-height:1.7;overflow-wrap:anywhere;margin:7px 0}.fusion-recipe-summary span{font-size:10px;color:#5c7660}.studio-fusion-editor .fusion-save{position:sticky;bottom:0;z-index:2;padding:13px;background:#246443;border-color:#246443;color:#fff;font-size:12px}.fusion-error,.fusion-notice{font-size:12px;line-height:1.6;padding:12px;border:1px solid #e8c6ae;border-radius:9px;background:#fff3e9;color:#884a2d}.fusion-notice{background:#edf7e7;border-color:#c7dfba;color:#34633e}
</style>
