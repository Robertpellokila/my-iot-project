<script setup>
import {computed,nextTick,onMounted,onBeforeUnmount,ref,watch} from 'vue';
import {supabase} from '../../lib/supabase';
import {battleCardId} from '../../utils/publicBattleActivity.js';
import {publicCardStats} from '../../utils/publicCardStats.js';
import {formatTcgType} from '../../utils/tcgTypes.js';
import {skillApCost,skillCooldown} from '../../lib/battle/skillState.js';
import SkillIcon from './SkillIcon.vue';
import ArenaCardFace from './ArenaCardFace.vue';
const props=defineProps({battle:{type:Object,required:true},cards:{type:Array,default:()=>[]},enemySide:{type:String,required:true},enemyName:String,revision:[String,Number],statuses:{type:Array,default:()=>[]}});
const emit=defineEmits(['close']);
const dialog=ref(null),selectedId=ref(null),skills=ref([]),loading=ref(false),error=ref(''),previewSkills=ref({});
const selected=computed(()=>props.cards.find(card=>String(battleCardId(card))===selectedId.value)??props.cards[0]??null);
const selectedKey=computed(()=>String(battleCardId(selected.value)??''));
const stats=computed(()=>publicCardStats(selected.value));
const statuses=computed(()=>props.statuses.filter(effect=>String(effect.target_card_id)===selectedKey.value));
const fallbackAp=()=>Number(props.battle.action_costs?.special_skill??1);
const skillClock=skill=>skillCooldown(skill,props.battle,props.enemySide);
const skillState=skill=>skill.disabled?'Tidak aktif':skillClock(skill).remaining?`Cooldown · ${skillClock(skill).remaining} ${skillClock(skill).unit==='giliranmu'?'giliran pemilik':skillClock(skill).unit}`:skill.limits?.once_per_battle&&skill.uses_count>0?'Sudah dipakai pada match ini':Number(skill.limits?.max_uses)>0&&Number(skill.uses_count)>=Number(skill.limits.max_uses)?'Batas penggunaan tercapai':'Cooldown siap';
let version=0,poll,previousFocus,disposed=false;
let selectedPending=null;
async function loadSkills(){
 const id=selectedKey.value,session=props.battle.id,side=props.enemySide;
 const key=JSON.stringify([session,side,id]);
 if(selectedPending?.key===key)return;
 const pending={key};selectedPending=pending;
 const request=++version;
 if(!id){skills.value=[];loading.value=false;selectedPending=null;return;}
 loading.value=true;error.value='';
 try{
  const result=await supabase.from('battle_card_skills').select('*').eq('battle_id',session).eq('player',side).eq('battle_card_id',id).order('priority');
  if(disposed||request!==version)return;
  if(result.error)throw result.error;
  skills.value=(result.data??[]).filter(skill=>String(skill.battle_card_id)===id&&skill.battle_id===session&&skill.player===side);
  previewSkills.value={...previewSkills.value,[id]:skills.value};
 }catch{if(!disposed&&request===version){error.value='Skill lawan belum dapat dimuat. Stats kartu tetap dapat diperiksa.';}}
 finally{if(selectedPending===pending)selectedPending=null;if(!disposed&&request===version)loading.value=false;}
}
watch([()=>props.battle.id,()=>props.enemySide,selectedKey],()=>{skills.value=[];void loadSkills();},{immediate:true});
watch(()=>props.revision,()=>{void loadSkills();});
// Card faces preview only public, Active enemy cards. The selected card retains
// its existing live loader, error handling and cooldown polling.
let previewVersion=0;
let previewScope='';
let previewPending=null;
watch(()=>[props.battle.id,props.enemySide,props.cards.map(battleCardId).join(',')],async()=>{
 const session=props.battle.id,side=props.enemySide;
 const scope=JSON.stringify([session,side]);
 const key=JSON.stringify([scope,props.cards.map(battleCardId),selectedKey.value]);
 if(previewPending?.key===key)return;
 const pending={key};previewPending=pending;
 const request=++previewVersion;
 if(scope!==previewScope){previewSkills.value={};previewScope=scope;}
 const activeIds=new Set(props.cards.map(card=>String(battleCardId(card))));
 previewSkills.value=Object.fromEntries(Object.entries(previewSkills.value).filter(([id])=>activeIds.has(id)));
 const rows=await Promise.all(props.cards.filter(card=>String(battleCardId(card))!==selectedKey.value).map(async card=>{
  const id=String(battleCardId(card));
  try{
   const result=await supabase.from('battle_card_skills').select('*').eq('battle_id',session).eq('player',side).eq('battle_card_id',id).order('priority');
   return [id,result.error?null:(result.data??[]).filter(skill=>String(skill.battle_card_id)===id&&skill.battle_id===session&&skill.player===side)];
  }catch{return [id,null];}
 }));
 if(!disposed&&request===previewVersion)previewSkills.value={...previewSkills.value,...Object.fromEntries(rows.filter(([,skills])=>skills!==null))};
 if(previewPending===pending)previewPending=null;
},{immediate:true});
onMounted(async()=>{previousFocus=document.activeElement;await nextTick();dialog.value?.showModal();dialog.value?.querySelector('h2')?.focus();poll=setInterval(()=>{if(document.visibilityState==='visible')void loadSkills();},3000);});
onBeforeUnmount(()=>{disposed=true;version++;clearInterval(poll);dialog.value?.close();if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});});
function select(card){selectedId.value=String(battleCardId(card));}
</script>
<template>
 <dialog ref="dialog" class="opponent-inspector arena-frame" aria-labelledby="opponent-inspector-title" @cancel.prevent="emit('close')" @click="event=>{if(event.target===dialog)emit('close');}">
  <header class="inspection-heading"><div><span>PANEL SPECTATE · {{ enemyName }}</span><h2 id="opponent-inspector-title" tabindex="-1">Kartu Active lawan</h2><p>Lihat kartu lawan yang terbuka untuk menyusun strategi. Pilih kartu untuk memeriksa skill dan statusnya.</p></div><button type="button" class="inspection-close" aria-label="Tutup inspeksi kartu lawan" @click="emit('close')">✕</button></header>
  <p v-if="!cards.length" class="inspection-empty" role="status">Lawan belum memiliki kartu Active. Kartu akan muncul di sini saat masuk ke lapangan.</p>
  <div v-else class="inspection-workspace">
   <nav class="inspection-roster" aria-label="Pilih kartu Active lawan">
    <button v-for="(card,index) in cards" :key="battleCardId(card)" type="button" :aria-pressed="selectedKey===String(battleCardId(card))" @click="select(card)">
     <span class="inspection-slot">{{selectedKey===String(battleCardId(card))?'◉ Active':'Lawan '+(index+1)}}</span>
     <ArenaCardFace :card="card" :skills="selectedKey===String(battleCardId(card))?skills:previewSkills[String(battleCardId(card))]??[]" />
    </button>
   </nav>
   <section v-if="selected" class="inspection-card" aria-live="polite">
    <div class="inspection-info"><div class="inspection-summary"><div class="inspection-card-title"><span>{{ formatTcgType(selected.element) }} · Active {{ selected.slot??cards.indexOf(selected)+1 }}</span><h3>{{ selected.name }}</h3><p v-if="selected.exhausted" class="inspection-warning">Exhausted · kartu belum dapat bertindak.</p></div>
     <dl class="inspection-stats"><div><dt>HP</dt><dd>{{ stats.hp??'—' }} <small>/ {{ stats.maxHp??'—' }}</small></dd></div><div><dt>ATK</dt><dd>{{ stats.attack??'—' }}</dd></div><div><dt>DEF</dt><dd>{{ stats.defense??'—' }}</dd></div></dl>
     <div class="inspection-statuses" aria-label="Status kartu"><span v-for="effect in statuses" :key="effect.id??effect.status_key">{{ effect.metadata?.label||effect.status_key }}<small v-if="effect.remaining_turns!=null"> · {{ effect.remaining_turns }} giliran</small></span><span v-if="!statuses.length" class="inspection-no-status">Tidak ada efek status tercatat.</span></div>
     </div>
     <section class="inspection-skills" aria-label="Skill kartu lawan"><h4>Skill kartu</h4><p v-if="loading&&!skills.length" role="status">Memuat skill…</p><p v-else-if="error" class="inspection-error" role="alert">{{ error }} <button type="button" @click="loadSkills">Coba lagi</button></p><p v-else-if="!skills.length">Tidak ada skill battle yang terpasang pada kartu ini.</p>
      <article v-for="(skill,index) in skills" :key="skill.id" class="inspection-skill"><span class="inspection-skill-icon"><SkillIcon :icon="skill.icon" :name="skill.name"/></span><div><span class="inspection-skill-number">SKILL {{ index+1 }} · {{ props.battle.action_points_enabled?`${skillApCost(skill,fallbackAp())} AP`:'Satu aksi' }}</span><h5>{{ skill.name }}</h5><p>{{ skill.description||'Penjelasan skill belum tersedia.' }}</p><small>{{ skillState(skill) }}</small></div></article>
     </section>
    </div>
   </section>
  </div>
  <footer class="inspection-footer"><p>Timer giliran tetap berjalan. Menutup inspeksi tidak mengganti kartu pilihanmu. Untuk menyerang, pilih kartumu → Serang → pilih target → konfirmasi.</p><button type="button" @click="emit('close')">Kembali ke battle</button></footer>
 </dialog>
</template>
<style scoped>
.opponent-inspector{position:fixed;inset:0;margin:auto;width:min(1140px,calc(100% - 36px));max-height:92dvh;overflow:auto;padding:25px 30px;font-family:Inter,Arial,sans-serif;overscroll-behavior:contain;box-sizing:border-box}
.opponent-inspector:not([open]){display:none}.opponent-inspector *{box-sizing:border-box}.opponent-inspector::backdrop{background:#092c5680;backdrop-filter:blur(5px)}
.inspection-heading{display:flex;align-items:start;justify-content:space-between;gap:20px;padding-bottom:22px}.inspection-heading span,.inspection-card-title>span{font-size:10px;font-weight:800;letter-spacing:.12em;color:#1c78af}.inspection-heading h2{margin:8px 0;font:850 30px/1.2 'Space Grotesk',Inter,Arial,sans-serif;letter-spacing:-.8px}.inspection-heading h2:focus{outline:none}.inspection-heading p,.inspection-footer p{margin:0;color:#526d8c;font-size:12px;line-height:1.7}
.opponent-inspector button{font-family:inherit;cursor:pointer}.inspection-close{flex:none;width:42px;height:42px;font-size:19px}
.inspection-roster{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px;margin:0 0 25px;align-items:start}
.inspection-roster button{display:flex;flex-direction:column;gap:6px;min-width:0;padding:0;border:0;background:none;text-align:left;color:#193f71;transition:transform .18s}
.inspection-roster button:hover{transform:translateY(-4px)}.inspection-roster button[aria-pressed=true] :deep(.arena-card-face){box-shadow:0 0 0 2px #fff7aa,0 0 0 4px #edce43,0 0 22px #ffe748ad}
.inspection-slot{display:block;align-self:center;text-align:center;min-width:75%;border-radius:10px 10px 0 0;padding:6px 9px;background:#e0effc;border:1px solid #cce3f6;color:#4c7097;font-size:11px;font-weight:800;line-height:1.1}.inspection-roster button[aria-pressed=true] .inspection-slot{background:#0675d5;color:#fff;border-color:#328ce0}
.inspection-info{display:grid;grid-template-columns:minmax(0,.8fr) minmax(0,1.2fr);gap:24px;min-width:0;padding:20px;border:1px solid #d3e5f5;border-radius:16px;background:#f8fcff}
.inspection-card-title h3{font-size:22px;margin:7px 0 12px;letter-spacing:-.5px;overflow-wrap:anywhere}.inspection-stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:0 0 12px}.inspection-stats>div{padding:10px;background:#eaf4fd;border:1px solid #d2e4f6;border-radius:9px}.inspection-stats>div:nth-child(2){background:#fff0ef;border-color:#f8d7d4}.inspection-stats dt{font-size:9px;letter-spacing:.09em;color:#47739d;font-weight:800}.inspection-stats dd{margin:5px 0 0;font-size:21px;font-weight:800}.inspection-stats small{font-size:11px;font-weight:500;color:#55799c}
.inspection-statuses{display:flex;flex-wrap:wrap;gap:6px}.inspection-statuses>span{padding:6px 8px;background:#fff6df;border:1px solid #ebdca9;border-radius:6px;font-size:10px;overflow-wrap:anywhere}.inspection-statuses>.inspection-no-status{border:none;background:none;padding:0;color:#5c7692}
.inspection-skills{min-width:0}.inspection-skills h4{font-size:13px;margin:0 0 10px}.inspection-skills>p{font-size:12px;line-height:1.8;color:#526d8c}.inspection-skill{display:flex;gap:12px;border:1px solid #d6dff3;border-radius:12px;padding:12px;background:linear-gradient(120deg,#f6f0ff,#fff);margin-top:8px;min-width:0}.inspection-skill-icon{display:grid;place-items:center;width:42px;height:42px;font-size:25px;flex:none;border:2px solid #dfc770;border-radius:50%;background:#e8e3fa;overflow:hidden}.inspection-skill>div{min-width:0}.inspection-skill-number{font-size:9px;letter-spacing:.07em;color:#6c5a9c}.inspection-skill h5{font-size:14px;margin:4px 0;overflow-wrap:anywhere}.inspection-skill p{font-size:11px;line-height:1.6;color:#536b8a;overflow-wrap:anywhere;margin:0 0 6px}.inspection-skill small{font-size:10px;font-weight:700;color:#327455}
.inspection-warning,.inspection-error{color:#986226!important}.inspection-footer{display:flex;justify-content:space-between;align-items:center;gap:20px;border-top:1px solid #d6e6f5;margin-top:20px;padding-top:16px}.inspection-footer p{max-width:680px;font-size:10px}.inspection-footer button{background:#0878c9;border:1px solid #0069ad;color:#fff;border-radius:10px;padding:12px 17px;font-weight:750;font-size:12px;flex:none}.inspection-empty{padding:48px 20px;text-align:center;font-size:14px;line-height:1.8;color:#526d8c}.opponent-inspector button:focus-visible{outline:3px solid #168cc1;outline-offset:5px}
@media(max-width:760px){.opponent-inspector{padding:18px 14px;width:calc(100% - 16px)}.inspection-heading h2{font-size:24px}.inspection-heading p{font-size:11px}.inspection-heading{gap:10px}.inspection-roster{grid-template-columns:repeat(2,minmax(0,1fr));gap:15px 12px}.inspection-info{grid-template-columns:1fr;padding:13px;gap:18px}.inspection-footer{flex-direction:column;align-items:stretch;gap:12px}.inspection-slot{font-size:10px}.inspection-close{width:35px;height:35px}.inspection-card-title h3{font-size:20px}}
@media(prefers-reduced-motion:reduce){.inspection-roster button{transition:none}.inspection-roster button:hover{transform:none}}
</style>
