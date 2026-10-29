<script setup>
import {useAdminFeedback} from '../../composables/useAdminToast.js';
import {computed,onMounted,ref,watch} from 'vue';
import {supabase} from '../../lib/supabase';
import SkillIcon from './SkillIcon.vue';
import {splitSkillIcon,skillMediaValue} from '../../lib/battle/skillPresentation.js';
import {EFFECTS,SYNERGY_TYPES,effectSummary,ruleCode} from '../../lib/battle/battleRuleCatalog.js';
const props=defineProps({kind:{type:String,required:true}});
const rows=ref([]),settings=ref(null),draft=ref(null),loading=ref(true),saving=ref(false),settingsSaving=ref(false),error=ref(''),notice=ref(''),choiceCount=ref(3);
const savedDrafts=new Map();
const copy=value=>JSON.parse(JSON.stringify(value));
const visible=computed(()=>rows.value.filter(row=>row.kind===props.kind));
const activeBonuses=computed(()=>rows.value.filter(row=>row.kind==='quiz_bonus'&&row.enabled).length);
const effectOptions=computed(()=>Object.entries(EFFECTS).filter(([,effect])=>props.kind==='synergy'||!effect.synergyOnly));
const spec=computed(()=>EFFECTS[draft.value?.effect_type]??EFFECTS.heal_percent);
const tiers=computed(()=>props.kind==='synergy'?[2,3,4]:[1]);
function edit(row){const media=splitSkillIcon(row.icon);draft.value={...copy(row),image_url:media.imageUrl||'',symbol:media.symbol||'✦'};}
function create(){draft.value={code:'',kind:props.kind,element:props.kind==='synergy'?'knight':null,name:'',description:'',symbol:'✦',image_url:'',effect_type:'heal_percent',effect_values:props.kind==='synergy'?{2:20,3:30,4:40}:{1:25},min_cards:2,enabled:true};}
async function load(){loading.value=true;error.value='';try{
 const [rules,result]=await Promise.all([supabase.from('battle_effect_catalog').select('*').order('kind').order('element').order('name'),supabase.from('battle_reward_settings').select('*').eq('id',1).single()]);
 if(rules.error||result.error)throw rules.error||result.error;rows.value=rules.data??[];settings.value=result.data;choiceCount.value=result.data.choice_count;
 const preferred=rows.value.find(row=>row.code===draft.value?.code&&row.kind===props.kind)??visible.value[0];if(preferred)edit(preferred);else create();
 }catch(err){error.value='Aturan battle belum dapat dimuat. '+(err.message??'');}finally{loading.value=false;}}
function changeEffect(){for(const tier of tiers.value)draft.value.effect_values[tier]=spec.value.fixed??Math.max(spec.value.min??0,Math.min(spec.value.max,Number(draft.value.effect_values[tier]??0)));}
function fillCode(){if(!draft.value.updated_at&&!draft.value.code)draft.value.code=props.kind==='synergy'?`synergy_${draft.value.element}`:ruleCode(draft.value.name);}
async function save(){if(saving.value)return;error.value='';notice.value='';saving.value=true;try{
 fillCode();const row={...draft.value,icon:skillMediaValue(draft.value.image_url,draft.value.symbol)};
 const {data,error:saveError}=await supabase.rpc('save_battle_effect_rule',{p_rule:row});if(saveError)throw saveError;
 rows.value=[...rows.value.filter(item=>item.code!==data.code),data];edit(data);notice.value='Aturan disimpan. Match baru akan menggunakan versi ini; match yang sedang berjalan tetap memakai aturan awal.';
 }catch(err){error.value=err.code==='23505'?'Kode atau tipe sudah memiliki aturan. Pilih aturan yang ada untuk mengeditnya.':err.message||'Aturan gagal disimpan.';}finally{saving.value=false;}}
async function saveSettings(){if(settingsSaving.value)return;settingsSaving.value=true;error.value='';notice.value='';try{
 const {data,error:saveError}=await supabase.rpc('save_battle_reward_settings',{p_choice_count:choiceCount.value,p_updated_at:settings.value.updated_at});if(saveError)throw saveError;settings.value=data;notice.value='Jumlah pilihan disimpan untuk match baru.';
 }catch(err){error.value=err.message||'Pengaturan gagal disimpan.';}finally{settingsSaving.value=false;}}
watch(()=>props.kind,(next,previous)=>{if(draft.value)savedDrafts.set(previous,copy(draft.value));error.value='';notice.value='';const saved=savedDrafts.get(next);if(saved)draft.value=saved;else if(visible.value[0])edit(visible.value[0]);else create();});
onMounted(load);
const adminToast=useAdminFeedback({error,success:notice,scope:'battle/BattleRuleCatalog'});
</script>
<template>
 <section class="battle-rule-catalog" aria-label="Pengaturan Synergy dan bonus kuis">
  <header class="rule-heading"><div><h2>{{ kind==='synergy'?'Synergy per tipe':'Bonus dari jawaban kuis' }}</h2><p>Perubahan berlaku untuk match baru. Aturan pada pertandingan yang sedang berjalan tetap sama.</p></div><button type="button" @click="load" :disabled="loading||saving">Muat ulang aturan</button></header>
  <p v-if="error" class="rule-error" role="alert">{{ error }}</p><p v-if="notice" class="rule-success" role="status">{{ notice }}</p>
  <p v-if="loading" role="status">Memuat aturan battle…</p>
  <template v-else-if="settings">
   <form v-if="kind==='quiz_bonus'" class="reward-settings" @submit.prevent="saveSettings"><label>Jumlah pilihan bonus<select v-model.number="choiceCount" aria-label="Jumlah pilihan bonus"><option v-for="count in 6" :key="count" :value="count">{{ count }} pilihan</option></select></label><div><strong>{{ activeBonuses }} bonus aktif</strong><p>Pemenang memilih satu bonus. Jika pool lebih kecil, semua bonus yang tersedia ditawarkan.</p></div><button type="submit" :disabled="settingsSaving">{{ settingsSaving?'Menyimpan…':'Simpan jumlah pilihan' }}</button></form>
   <div class="rule-workspace">
    <aside class="rule-list"><button v-if="kind==='quiz_bonus'" class="rule-add" type="button" @click="create">+ Buat bonus baru</button><button v-for="row in visible" :key="row.code" type="button" class="rule-list-item" :class="{selected:row.code===draft?.code}" @click="edit(row)"><span class="rule-icon"><SkillIcon :icon="row.icon" :name="row.name"/></span><span><strong>{{ row.name }}</strong><small>{{ row.element==='ice'?'Ice (legacy)':row.element||row.code }} · {{ row.enabled?'Aktif':'Nonaktif' }}</small></span></button></aside>
    <form v-if="draft" class="rule-editor" @submit.prevent="save">
     <header><h3>{{ draft.updated_at?'Edit aturan':'Buat bonus' }}</h3><label class="rule-enabled"><input v-model="draft.enabled" type="checkbox"> Aktif</label></header>
     <div class="rule-form-grid">
      <label>Nama kemampuan<input v-model="draft.name" required maxlength="100" @blur="fillCode" placeholder="Nama bonus / Synergy"></label>
      <label>Kode aturan<input v-model="draft.code" required pattern="[a-z][a-z0-9_]{1,63}" :readonly="!!draft.updated_at" placeholder="contoh: quick_patch"></label>
      <label v-if="kind==='synergy'">Tipe kartu<select v-model="draft.element" :disabled="!!draft.updated_at"><option v-for="element in SYNERGY_TYPES" :key="element" :value="element">{{ element==='ice'?'Ice (legacy)':element }}</option></select></label>
      <label v-if="kind==='synergy'">Minimal kartu Active<select v-model.number="draft.min_cards"><option v-for="count in [2,3,4]" :key="count" :value="count">{{ count }} kartu bertipe sama</option></select></label>
      <label class="rule-wide">URL gambar ikon<input v-model="draft.image_url" type="text" inputmode="url" placeholder="https://…/ikon.webp"></label>
      <label>Simbol pengganti<input v-model="draft.symbol" maxlength="32" placeholder="✦"></label>
      <label>Efek yang dijalankan<select v-model="draft.effect_type" @change="changeEffect"><option v-for="[key,effect] in effectOptions" :key="key" :value="key">{{ effect.label }}</option></select></label>
      <label v-for="tier in tiers" :key="tier">{{ kind==='synergy'?`${tier===4?'4+':tier} kartu`: 'Nilai efek' }} · {{ spec.unit||'otomatis' }}<input v-model.number="draft.effect_values[tier]" type="number" :min="spec.min??0" :max="spec.max" step="1" :readonly="spec.fixed!==undefined" required></label>
      <label class="rule-wide">Catatan / penjelasan tambahan<textarea v-model="draft.description" rows="2" maxlength="2000" placeholder="Opsional; nilai yang dijalankan mengikuti aturan efek di atas."></textarea></label>
     </div>
     <section class="rule-preview" aria-label="Pratinjau aturan"><span class="rule-icon"><SkillIcon :icon="draft.image_url||draft.symbol" :name="draft.name"/></span><div><h4>{{ draft.name||'Nama kemampuan' }}</h4><p v-for="tier in tiers" :key="tier"><b v-if="kind==='synergy'">{{ tier===4?'4+':tier }} kartu: </b>{{ effectSummary(draft,tier) }}</p><small>{{ kind==='synergy'?'Sekali per tipe dalam satu match. Biaya AP mengikuti Game Setup.':'Bonus dipilih dari kuis, dipakai sekali saat giliran pemilik, dan tidak memakai AP.' }}</small></div></section>
     <button class="rule-save" type="submit" :disabled="saving">{{ saving?'Menyimpan…':'Simpan aturan' }}</button>
    </form>
   </div>
  </template>
 </section>
</template>
<style scoped>
.battle-rule-catalog .rule-enabled input{width:16px;height:16px;flex:none}
.battle-rule-catalog{color:#204431}.rule-heading,.rule-editor>header{display:flex;align-items:start;justify-content:space-between;gap:20px;margin-bottom:20px}.rule-heading h2{font-size:25px;letter-spacing:-.6px;margin:0 0 9px}.rule-heading p,.reward-settings p{font-size:12px;line-height:1.8;color:#69826e;margin:0}.battle-rule-catalog button{font:650 12px Inter,sans-serif;cursor:pointer;border:1px solid #cbdcc8;border-radius:8px;padding:11px 14px;background:white;color:#315f3c}.battle-rule-catalog button:disabled{opacity:.55;cursor:wait}.rule-workspace{display:grid;grid-template-columns:260px minmax(0,1fr);gap:20px}.rule-list,.rule-editor{min-width:0;border:1px solid #dce7d8;background:#fff;border-radius:14px;padding:17px}.rule-list{align-self:start;display:grid;gap:9px}.rule-list-item{display:flex;align-items:center;gap:10px;text-align:left;width:100%}.rule-list-item>span:first-child{width:33px;height:33px;flex:none;font-size:25px}.rule-list-item>span:last-child{display:grid;gap:5px;min-width:0}.rule-list-item strong{font-size:12px;overflow-wrap:anywhere}.rule-list-item small{font-size:10px;color:#718873;text-transform:capitalize}.rule-list-item.selected{border-color:#599765;background:#edf6e6}.rule-add{background:#e8f5df!important;color:#26713c!important}.rule-editor h3{margin:0;font-size:21px}.rule-enabled{display:flex;align-items:center;gap:8px;font-size:12px}.rule-enabled input{width:auto}.rule-form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.rule-form-grid label,.reward-settings label{display:flex;flex-direction:column;gap:7px;font-size:11px;font-weight:700;color:#53735a}.rule-wide{grid-column:1/-1}.battle-rule-catalog input,.battle-rule-catalog textarea,.battle-rule-catalog select{min-width:0;width:100%;border:1px solid #d4e1d0;border-radius:8px;background:#fff;padding:11px 12px;color:#294e33;font:500 13px/1.5 Inter,sans-serif}.battle-rule-catalog input[readonly]{background:#f2f6ee;color:#6a7e69}.rule-preview{display:flex;gap:16px;align-items:start;padding:20px;background:#f0f7e8;border:1px solid #d6e6c9;border-radius:12px;margin:22px 0}.rule-preview>span{width:55px;height:55px;flex:none;font-size:35px}.rule-preview h4{margin:0 0 10px;font-size:18px}.rule-preview p{font-size:12px;line-height:1.8;margin:8px 0;color:#456a4a}.rule-preview small{font-size:11px;line-height:1.8;color:#75846c}.rule-save,.reward-settings>button{background:#196f41!important;color:white!important;border-color:#196f41!important}.reward-settings{display:flex;align-items:center;gap:22px;padding:20px;background:#eef6e6;border:1px solid #d8e7cd;border-radius:12px;margin-bottom:22px}.reward-settings label{width:170px;flex:none}.reward-settings>div{flex:1}.reward-settings strong{font-size:13px}.rule-error,.rule-success{padding:15px;border:1px solid #edcfb9;background:#fff5e8;color:#98602f;border-radius:9px;font-size:12px;line-height:1.8}.rule-success{border-color:#bedcbb;background:#eff8e9;color:#327343}.battle-rule-catalog :is(button,input,textarea,select):focus-visible{outline:3px solid #3d8c9a;outline-offset:3px}@media(max-width:900px){.rule-workspace{grid-template-columns:1fr}.rule-list{grid-template-columns:repeat(2,minmax(0,1fr))}.reward-settings{flex-wrap:wrap}.rule-heading{flex-wrap:wrap}}@media(max-width:520px){.rule-form-grid{grid-template-columns:1fr}.rule-list{grid-template-columns:1fr}.rule-editor,.rule-list{padding:14px}.reward-settings{padding:16px;gap:14px}.reward-settings>div{flex-basis:100%}.rule-preview{padding:15px;gap:10px}.rule-preview>span{width:38px;height:38px;font-size:30px}}
</style>
