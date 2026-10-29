<script setup>
import { computed,nextTick,onUnmounted,ref,watch } from 'vue';
import { supabase } from '../../lib/supabase';
import { spotlightTurn } from '../../utils/battleSpotlight.js';
import { skillCooldown,skillApCost } from '../../lib/battle/skillState.js';
import { createSkillCinematic,cinematicEffects,EFFECT_VISUALS } from '../../lib/battle/skillCinematic.js';
import SkillIcon from './SkillIcon.vue';
const props=defineProps({battle:Object,liveUi:Object,event:Object,cards:{type:Array,default:()=>[]},paused:Boolean,timings:Object});
const state=ref({phase:'idle'}),loadError=ref(false),overlay=ref(null),targetBox=ref(null);
watch(()=>state.value.effect,async effect=>{
 targetBox.value=null;await nextTick();if(!effect||!overlay.value)return;
 const frame=overlay.value.parentElement,root=overlay.value.getBoundingClientRect();
 const candidates=[...frame.querySelectorAll('[data-card-id]')].filter(el=>String(el.dataset.cardId)===String(effect.targetCardId));
 const target=candidates.find(el=>el.dataset.featured==='true')??candidates[0];
 if(!target)return;const rect=target.getBoundingClientRect();
 targetBox.value={left:rect.left-root.left,top:rect.top-root.top,width:rect.width,height:rect.height};
});
const impactStyle=computed(()=>targetBox.value?Object.fromEntries(Object.entries(targetBox.value).map(([key,value])=>[key,`${value}px`])):{});
const travelStyle=computed(()=>{if(!targetBox.value||!overlay.value)return {};const r=overlay.value.getBoundingClientRect(),x=targetBox.value.left+targetBox.value.width/2-r.width/2,y=targetBox.value.top+targetBox.value.height/2-r.height/2;return {'--travel-x':`${x}px`,'--travel-y':`${y}px`};});
const controller=createSkillCinematic({onChange:value=>state.value=value,timings:props.timings,reducedMotion:typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches});
let requestVersion=0,acceptedVersion=0,alive=true;
const intent=computed(()=>{
 const b=props.battle,player=b?.current_turn,value=props.liveUi?.[player]?.skillIntent;
 if(!b||props.paused||['finished','cancelled','completed'].includes(b.status)||!value||value.turn!==spotlightTurn(b)||Date.now()-value.at>45000)return null;
 const card=props.cards.find(c=>String(c.id)===value.cardId&&c.player===player&&c.zone==='active');
 return card?{intent:value,player,card}:null;
});
const fetchSkills=async(cardId,player)=>{
 const {data,error}=await supabase.from('battle_card_skills').select('*').eq('battle_id',props.battle.id).eq('battle_card_id',cardId).eq('player',player).order('priority').order('skill_code');
 if(error)throw error;
 return (data??[]).filter(s=>s.activation_timing==='main_phase');
};
watch(intent,async value=>{
 const version=++requestVersion;loadError.value=false;
 if(!value){controller.cancel();return;}
 if(controller.state.authoritative)return;
 try{
  let skills=state.value.intent?.id===value.intent.id?state.value.skills:null;
  if(!skills)skills=await fetchSkills(value.intent.cardId,value.player);
  if(!alive||version!==requestVersion||controller.state.authoritative)return;
  if(!skills.length){controller.cancel();return;}
  controller.intent({...value,skills,selectedId:skills.some(s=>s.id===value.intent.skillId)?value.intent.skillId:null});
 }catch{if(version===requestVersion){loadError.value=true;controller.cancel();}}
},{deep:true,immediate:true});
watch(()=>props.event,async event=>{
 if(!event?.id||event.type!=='special_skill'||String(event.battle_id)!==String(props.battle?.id))return;
 const battleId=props.battle.id,version=acceptedVersion,payload=event.payload??{},cardId=payload.source_card_id??event.card_id;
 const card=props.cards.find(c=>String(c.id)===String(cardId)),player=event.source_player;
 ++requestVersion;
 let skills=state.value.card?.id===cardId?state.value.skills:null;
 try{if(!skills)skills=await fetchSkills(cardId,player);}catch{skills=[];}
 if(!alive||props.battle?.id!==battleId||version!==acceptedVersion)return;
 const selectedId=payload.battle_card_skill_id;
 if(!skills.some(s=>s.id===selectedId))skills=[...skills,{id:selectedId,name:payload.skill_name||'Skill',icon:'✦',description:'Aksi telah diterima.',limits:{}}];
 controller.accepted({eventId:event.id,player,card,skills,selectedId,effects:cinematicEffects(event)});
});
watch(()=>props.battle?.id,()=>{requestVersion++;acceptedVersion++;controller.reset();});
watch(()=>props.paused,value=>{if(value)controller.cancel();});
onUnmounted(()=>{alive=false;requestVersion++;acceptedVersion++;controller.dispose();});
const playerName=player=>props.battle?.[player==='p2'?'player2_name':'player1_name']||(player==='p2'?'Player 2':'Player 1');
const heading=computed(()=>state.value.authoritative?(state.value.phase==='resolving'?'SKILL AKTIF':'SKILL DIPILIH'):'PILIH SKILL');
const focused=computed(()=>['centering','activating','resolving','outro'].includes(state.value.phase));
const visibleSkills=computed(()=>focused.value?state.value.skills?.filter(s=>s.id===state.value.selectedId):state.value.skills??[]);
const visual=computed(()=>EFFECT_VISUALS[state.value.effect?.kind]??EFFECT_VISUALS.generic);
const targetName=computed(()=>props.cards.find(c=>String(c.id)===String(state.value.effect?.targetCardId))?.name||playerName(state.value.effect?.targetPlayer??state.value.player));
function readiness(skill){
 const cd=skillCooldown(skill,props.battle,state.value.player),limits=skill.limits??{},uses=skill.uses_count??0;
 if(skill.disabled)return 'Nonaktif';
 if((limits.once_per_battle&&uses>=1)||(limits.max_uses>0&&uses>=limits.max_uses))return 'Sudah digunakan';
 if(cd.remaining)return `CD ${cd.remaining} ${cd.unit}`;
 return 'Siap digunakan';
}
const cost=skill=>skillApCost(skill,Number(props.battle?.action_costs?.special_skill??1));
const effectLabels=skill=>(skill.effects??[]).map(e=>e.type==='studio_skill'?'SKILL KARTU':String(e.status_key??e.type??'skill').replaceAll('_',' ')).filter((value,index,all)=>all.indexOf(value)===index).slice(0,3).join(' · ');
defineExpose({controller});
</script>
<template>
 <section ref="overlay" v-if="state.phase!=='idle' && !paused" class="skill-cinema" :class="[`phase-${state.phase}`,{focused}]" :style="{'--effect-color':visual.color}" aria-live="polite" aria-label="Aksi skill langsung">
  <div class="cinema-scrim"></div>
  <template v-if="state.phase==='resolving' && targetBox"><div class="skill-energy-travel" :style="travelStyle" :key="`travel-${state.effectIndex}`"></div><div class="skill-target-impact" :style="impactStyle" :class="`impact-${state.effect.kind}`" :key="`impact-${state.effectIndex}`"><span>{{ visual.symbol }}</span></div></template>
  <div class="cinema-content">
   <header><small>{{ heading }}</small><h2>{{ playerName(state.player) }} <span>{{ state.authoritative ? 'mengaktifkan skill' : 'sedang memilih…' }}</span></h2><p>{{ state.card?.name }}</p></header>
   <div class="cinema-choices">
    <article v-for="skill in visibleSkills" :key="skill.id" class="cinema-skill" :class="{chosen:skill.id===state.selectedId,unselected:state.authoritative&&skill.id!==state.selectedId,unavailable:!state.authoritative&&readiness(skill)!=='Siap digunakan'}">
     <div class="cinema-skill-art"><i class="skill-orbit"></i><SkillIcon :icon="skill.icon" :name="skill.name" /></div>
     <div class="cinema-skill-copy"><small>{{ effectLabels(skill) || 'SPECIAL SKILL' }}</small><h3>{{ skill.name }}</h3><p>{{ skill.description }}</p><footer><b v-if="battle?.action_points_enabled">{{ cost(skill) }} AP</b><b v-if="skill.cost_spec?.value">{{ skill.cost_spec.value }} {{ skill.cost_spec.type }}</b><span>{{ state.authoritative?'Diterima':readiness(skill) }}</span></footer></div>
    </article>
   </div>
   <div v-if="state.phase==='resolving'" class="cinema-resolution" :key="state.effectIndex" :class="`effect-${state.effect.kind}`">
    <span class="effect-symbol">{{ visual.symbol }}</span><div><small>{{ targetName }} <template v-if="state.effectCount>1">· {{ state.effectIndex }}/{{ state.effectCount }}</template></small><strong>{{ visual.label }} <template v-if="state.effect.amount!=null">{{ state.effect.kind==='damage'?'−':state.effect.kind==='heal'?'+':'' }}{{ state.effect.amount }}</template></strong><span v-if="state.effect.hpAfter!=null">HP {{ state.effect.hpAfter }}</span><span v-else-if="state.effect.status">{{ state.effect.status.replaceAll('_',' ') }}</span></div>
   </div>
   <p v-else-if="!state.authoritative" class="cinema-hint">{{ state.selectedId ? 'Menentukan target dan mengonfirmasi aksi…' : 'Menunggu pilihan pemain' }}</p>
  </div>
  <div v-if="['activating','resolving'].includes(state.phase)" class="cinema-particles" aria-hidden="true"><i v-for="n in 12" :key="n" :style="{'--n':n}"></i></div>
 </section>
</template>
<style scoped>
.phase-resolving .cinema-scrim{opacity:.55}.skill-target-impact{position:absolute;border:3px solid var(--effect-color);border-radius:10%;box-shadow:0 0 30px var(--effect-color),inset 0 0 25px var(--effect-color);animation:target-pulse 1s ease-out;z-index:1;display:grid;place-items:center}.skill-target-impact span{font-size:7cqh;color:var(--effect-color);text-shadow:0 2px 8px #001}.impact-burn{background:linear-gradient(0deg,#ff870060,transparent 70%)}.impact-shield{border-width:6px;background:#67cfff22}.impact-heal{background:#83ffb333}.skill-energy-travel{position:absolute;left:50%;top:50%;width:18px;height:18px;background:var(--effect-color);box-shadow:0 0 35px 12px var(--effect-color);border-radius:50%;z-index:3;animation:energy-travel .7s both}@keyframes energy-travel{to{transform:translate(var(--travel-x),var(--travel-y));opacity:0}}@keyframes target-pulse{0%{opacity:0;transform:scale(.95)}40%{opacity:1;transform:scale(1.04)}100%{opacity:.7;transform:scale(1)}}

.skill-cinema{position:absolute;inset:0;z-index:75;pointer-events:none;overflow:hidden;container-type:size;color:#fff9e8;font-family:inherit}.cinema-scrim{position:absolute;inset:0;background:radial-gradient(ellipse at center,#07132caa,#030c1be6);backdrop-filter:blur(3px)}.cinema-content{position:absolute;inset:6% 12%;display:flex;align-items:center;flex-direction:column;justify-content:center;gap:3cqh}.cinema-content header{text-align:center;z-index:1}.cinema-content header>small{font-size:1.8cqh;letter-spacing:.3em;color:#f2cd73;font-weight:800}.cinema-content h2{font-size:3.5cqh;margin:1cqh 0}.cinema-content h2 span{font-weight:400;color:#d9e6f5}.cinema-content header p{font-size:2cqh;margin:0;color:#b9d5ea}.cinema-choices{display:flex;justify-content:center;gap:3cqw;width:100%;max-height:62cqh}.cinema-skill{width:26cqw;min-width:0;max-width:440px;border:1px solid #a8ccdd88;border-radius:18px;background:linear-gradient(160deg,#163754,#07192c);box-shadow:0 18px 65px #0009;overflow:hidden;transition:opacity .3s,transform .5s,border-color .3s;animation:skill-arrive .5s both}.cinema-skill.chosen{border-color:#ffdc87;box-shadow:0 0 0 2px #cfac5060,0 0 65px #69ceff40}.cinema-skill.unselected{opacity:0;transform:scale(.8) rotateY(15deg)}.cinema-skill.unavailable{filter:saturate(.45);opacity:.75}.cinema-skill-art{position:relative;display:grid;place-items:center;height:22cqh;background:radial-gradient(circle,#42baff22,transparent 67%);font-size:12cqh;color:#9adfff}.cinema-skill-art :deep(img){width:17cqh;height:17cqh;z-index:1}.skill-orbit{position:absolute;width:19cqh;height:19cqh;border:1px solid #9ddfff44;border-radius:50%;box-shadow:0 0 35px #2a9fff28;transform:rotate(-20deg) scaleX(1.05)}.cinema-skill-copy{padding:2cqh 2cqw}.cinema-skill-copy>small{text-transform:uppercase;letter-spacing:.08em;color:#c6ab68;font-size:1.3cqh}.cinema-skill h3{font-size:3cqh;line-height:1.15;margin:1cqh 0;overflow-wrap:anywhere}.cinema-skill p{font-size:1.85cqh;line-height:1.45;color:#c6d5e7;margin:0;display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden}.cinema-skill footer{display:flex;align-items:center;justify-content:space-between;gap:10px;border-top:1px solid #ffffff22;padding-top:1.4cqh;margin-top:2cqh;font-size:1.6cqh;color:#c4daf0}.cinema-skill footer b{color:#ffe4a1}.cinema-hint{font-size:1.7cqh;color:#abc4d9}.focused .cinema-skill{width:32cqw;max-width:520px;transform:scale(1.03)}.focused .cinema-skill-art{height:16cqh}.focused .cinema-skill-art :deep(img){height:14cqh;width:14cqh}.phase-activating .cinema-skill{box-shadow:0 0 90px var(--effect-color);animation:skill-activate .8s}.cinema-resolution{display:flex;align-items:center;gap:2cqw;padding:1.7cqh 3cqw;min-width:28cqw;background:#071327ed;border:1px solid var(--effect-color);border-radius:14px;box-shadow:0 0 45px color-mix(in srgb,var(--effect-color) 22%,transparent);animation:skill-impact .3s ease-out;z-index:2}.effect-symbol{font-size:5cqh;color:var(--effect-color)}.cinema-resolution div{display:grid;gap:.5cqh}.cinema-resolution small{font-size:1.5cqh;color:#c8d9eb}.cinema-resolution strong{font-size:3.4cqh;color:var(--effect-color)}.cinema-resolution div>span{font-size:1.5cqh}.phase-outro{animation:skill-exit .35s both}.cinema-particles{position:absolute;inset:0;pointer-events:none}.cinema-particles i{position:absolute;left:50%;top:50%;width:5px;height:5px;border-radius:50%;background:var(--effect-color);box-shadow:0 0 14px var(--effect-color);animation:skill-particle 1.1s calc(var(--n)*-.05s) ease-out infinite;--angle:calc(var(--n)*30deg)}@keyframes skill-arrive{from{opacity:0;transform:scale(1.12) translateY(18px)}to{opacity:1;transform:scale(1)}}@keyframes skill-activate{50%{filter:brightness(1.35);transform:scale(1.07)}}@keyframes skill-impact{from{opacity:0;transform:translateY(12px) scale(.9)}}@keyframes skill-exit{to{opacity:0}}@keyframes skill-particle{from{opacity:.9;transform:rotate(var(--angle)) translateX(6cqw)}to{opacity:0;transform:rotate(var(--angle)) translateX(30cqw)}}@media(prefers-reduced-motion:reduce){.skill-cinema *,.skill-cinema{animation:none!important;transition:none!important}.cinema-particles{display:none}.cinema-scrim{backdrop-filter:none}}
</style>

<style scoped>
.cinema-scrim{background:#163e6a88}.cinema-content header{padding:.8cqh 2cqw;border:1px solid #e0c373;border-radius:12px;background:#f5fbfff5;box-shadow:0 4px 18px #0c2e5a44;color:#113469}.cinema-content header>small{color:#0a7bab}.cinema-content h2 span,.cinema-content header p{color:#477099}.cinema-skill{border:10px solid transparent;border-image:url('/images/battle-arena/panel-frame.svg') 29 stretch;border-image-width:19px;border-radius:0;background:linear-gradient(145deg,#ffffff,#edf7ff);background-clip:padding-box;color:#153a6a}.cinema-skill-copy>small{color:#7054ae}.cinema-skill-copy>p{color:#48678c}.cinema-skill-copy footer{color:#176e9d}.cinema-skill-copy footer>b{background:#deedff;color:#174e85}.cinema-skill-copy footer>span{color:#237f5a}.cinema-skill-art{background:radial-gradient(circle,#e6dbff,#eef8ff 70%)}.cinema-hint{padding:.5cqh 1.5cqw;border-radius:20px;background:#f0f9fff0;color:#315d87}.cinema-resolution{background:#f5fbff;border-color:#7fbedb}.cinema-resolution small,.cinema-resolution div>span{color:#3c6087}.cinema-resolution strong{color:#163b6f}
</style>
