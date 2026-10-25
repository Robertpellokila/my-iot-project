<script setup>
import {defineAsyncComponent} from 'vue';
const BlockWorkspace=defineAsyncComponent(()=>import('../questions/BlockWorkspace.vue'));
import { computed, onUnmounted, ref, watch } from 'vue';
import QuizTimer from '../questions/QuizTimer.vue';
import QuizBonusChoices from './QuizBonusChoices.vue';
import {supabase} from '../../lib/supabase';
import {effectSummary} from '../../lib/battle/battleRuleCatalog.js';
import { codeLines, blockTone, shuffleItems } from '../../lib/questions/questionModel.js';
const props=defineProps({battle:{type:Object,required:true},question:{type:Object,default:null},round:{type:Object,default:null},active:Boolean,loading:Boolean,error:{type:String,default:''},event:{type:Object,default:null}});
const snapshot=ref(null),roundSnapshot=ref(null),result=ref(null),held=ref(false),answers=ref({}),blocks=ref([]);
let holdTimer;
const playerName=side=>side==='p1'?props.battle.player1_name||'Player 1':props.battle.player2_name||'Player 2';
const visible=computed(()=>props.active||held.value);
const bonusChoice=ref(null);
const bonusOptions=computed(()=>(bonusChoice.value?.options??[]).map(rule=>({code:rule.code,name:rule.name,icon:rule.icon,summary:effectSummary(rule),description:rule.description})));
watch([visible,()=>result.value?.winner,()=>props.battle.code,()=>roundSnapshot.value?.id],([show,winner],previous,cleanup)=>{
 let cancelled=false,interval;cleanup(()=>{cancelled=true;clearInterval(interval);});bonusChoice.value=null;
 if(!show||!winner||props.battle.question_bonus_enabled===false)return;
 const load=async()=>{try{const {data,error}=await supabase.rpc('get_public_battle_bonus_choice',{p_code:props.battle.code});if(!cancelled&&!error&&data?.ok&&data.question_round_id===roundSnapshot.value?.id)bonusChoice.value=data;}catch{/* Existing question/result display remains available offline. */}};
 void load();interval=setInterval(load,1200);
},{immediate:true});
function hold(){clearTimeout(holdTimer);held.value=true;holdTimer=setTimeout(()=>held.value=false,7500);}
watch(()=>props.round,(round)=>{
  if(!round)return;
  if(round.id!==roundSnapshot.value?.id){result.value=null;answers.value={};held.value=false;clearTimeout(holdTimer);if(snapshot.value?.id!==round.question_id)snapshot.value=null;}
  roundSnapshot.value={...round};
  if(round.winner_player){result.value={winner:round.winner_player,title:`${playerName(round.winner_player)} menjawab benar!`};hold();}
  else if(round.status==='timed_out'){result.value={title:'Quiz selesai · tidak ada pemenang'};hold();}
},{immediate:true,flush:'sync'});
watch(()=>props.question,question=>{
  if(!question)return;
  if(question.id!==snapshot.value?.id)blocks.value=shuffleItems(question.blocks??[]);
  snapshot.value={...question};
},{immediate:true});
watch(()=>props.event,event=>{
  if(!event)return;
  if(event.type==='question_winner') {result.value={winner:event.source_player,title:`${playerName(event.source_player)} menjawab benar!`};hold();}
  if(event.type==='question_timeout'){result.value={title:'Waktu habis · battle dilanjutkan'};hold();}
  if(event.type==='question_wrong'){answers.value={...answers.value,[event.source_player]:'Belum tepat'};}
},{flush:'sync'});
watch(()=>props.active,(active,previous)=>{if(!active&&previous){if(!result.value)result.value={title:'Quiz selesai · battle dilanjutkan'};hold();}});
onUnmounted(()=>clearTimeout(holdTimer));
</script>
<template>
  <Transition name="public-quiz"><section v-if="visible" class="public-quiz-display" aria-label="Quiz live untuk penonton">
    <header><div><span>CODING CHALLENGE · ROUND {{ roundSnapshot?.round_number ?? battle.round }}</span><h2>{{ result?'Hasil quiz':'Siapa yang menjawab lebih dulu?' }}</h2></div><QuizTimer v-if="!result" :round="roundSnapshot" :seconds="Number(snapshot?.duration_seconds??battle.question_time_limit_seconds??0)"/><span v-else class="quiz-resolved">QUIZ SELESAI</span></header>
    <div v-if="result" class="quiz-result" :class="result.winner" role="status"><span>{{ result.winner?'✓':'◷' }}</span><div><strong>{{ result.title }}</strong><p>{{ result.winner && active && battle.question_bonus_enabled!==false?'Pemenang sedang memilih bonus skill.':'Battle dilanjutkan setelah quiz.' }}</p></div></div>
    <div v-if="bonusOptions.length" class="public-bonus-content"><QuizBonusChoices readonly :options="bonusOptions" :selected-code="bonusChoice.selected_code" :player-name="playerName(bonusChoice.player)"/></div>
    <div v-else-if="error && !snapshot" class="quiz-state">{{ error }}</div><div v-else-if="!snapshot" class="quiz-state">{{ result ? 'Hasil quiz sudah diterima.' : 'Memuat soal quiz…' }}</div>
    <div v-else class="quiz-content" :class="{'has-image':snapshot.image_url}">
      <div class="quiz-prompt"><p>{{ snapshot.question }}</p><img v-if="snapshot.image_url" :src="snapshot.image_url" alt="Potongan kode atau ilustrasi soal quiz"/><pre v-else-if="snapshot.code_snippet && snapshot.question_type!=='find_bug'"><code>{{ snapshot.code_snippet }}</code></pre></div>
      <div class="quiz-answers" :class="{'block-pool':snapshot.question_type==='block_order','many-blocks':snapshot.question_type==='block_order' && blocks.length>6}">
        <BlockWorkspace v-if="snapshot.question_type==='scratch_blocks'" :key="snapshot.id" :model-value="snapshot.block_config?.initial" :config="snapshot.block_config" readonly label="Program awal quiz"/>
        <template v-else-if="snapshot.question_type==='block_order'"><small>Susun blok berikut menjadi program yang benar.</small><div v-for="(block,index) in blocks" :key="index" class="spectator-block" :class="`tone-${blockTone(block)}`">{{ block }}</div></template>
        <template v-else-if="snapshot.question_type==='find_bug'"><small>Pilih baris yang bermasalah.</small><div v-for="(line,index) in codeLines(snapshot.code_snippet)" :key="index" class="quiz-option"><b>{{ index+1 }}</b><code>{{ line }}</code></div></template>
        <div v-for="(option,index) in snapshot.question_type==='choice'?snapshot.options:[]" :key="index" class="quiz-option"><b>{{ String.fromCharCode(65+index) }}</b><span>{{ option }}</span></div>
      </div>
    </div>
    <footer><div v-for="side in ['p1','p2']" :key="side" :class="side"><strong>{{ playerName(side) }}</strong><span>{{ result?.winner===side?'✓ Jawaban benar':result?.winner?'Quiz selesai':answers[side]??(result?'Quiz selesai':'Sedang menjawab…') }}</span></div></footer>
  </section></Transition>
</template>
<style scoped>
.public-bonus-content{min-height:0;overflow:auto;flex:1;padding:18px}
.public-quiz-display { position:absolute; z-index:100; inset:4% 9%; display:flex; flex-direction:column; overflow:hidden; border:3px solid #e9c86e; border-radius:16px; background:#f6fbff; color:#183b56; box-shadow:0 20px 100px #001027b3; font-family:Arial,sans-serif; }.public-quiz-display header { display:flex; align-items:center; justify-content:space-between; gap:20px; padding:18px 25px; background:#143752; color:white; }header span { color:#fae09d; font-size:11px; font-weight:800; letter-spacing:.08em; }h2 { margin:6px 0 0; font-size:clamp(16px,1.8vw,29px); }.quiz-content { display:grid; grid-template-columns:1fr 1fr; align-content:start; gap:24px; padding:24px; min-height:0; overflow:auto; flex:1; }.quiz-prompt { min-width:0; }.quiz-prompt p { font-size:clamp(16px,1.65vw,27px); font-weight:800; line-height:1.45; margin:0 0 16px; overflow-wrap:anywhere; }.quiz-prompt img { display:block; max-width:100%; max-height:34vh; object-fit:contain; margin:auto; }.quiz-prompt pre { white-space:pre-wrap; overflow-wrap:anywhere; font-size:16px; background:#e4eff6; padding:15px; border-radius:8px; }.quiz-answers { display:flex; flex-direction:column; justify-content:center; gap:12px; min-width:0; }.quiz-answers small { font-size:14px; color:#4f6d82; }.quiz-option { display:flex; gap:14px; align-items:center; background:white; border:1px solid #b6d0e1; border-radius:9px; padding:15px; font-size:clamp(14px,1.2vw,23px); line-height:1.4; overflow-wrap:anywhere; }.quiz-option b { display:grid; place-items:center; width:32px; height:32px; flex:none; border-radius:6px; background:#dceff9; color:#20648c; }.quiz-option code { white-space:pre-wrap; min-width:0; font-size:inherit; }.spectator-block { padding:12px 16px; background:#2d70cb; border-radius:6px; border-bottom:3px solid #174a9b; color:white; font-size:clamp(12px,1vw,18px); line-height:1.3; overflow-wrap:anywhere; }.tone-event { background:#a46506; border-color:#7d4b04; }.tone-control { background:#ad590d; border-color:#7b3f08; }.tone-looks { background:#7944b9; border-color:#572e89; }.tone-variable { background:#a74716; border-color:#77300d; }.quiz-result { display:flex; align-items:center; justify-content:center; gap:18px; padding:14px 24px; background:#e2f5e8; border-bottom:1px solid #b6d5c1; }.quiz-result>span { font-size:32px; color:#187c4a; }.quiz-result strong { font-size:clamp(17px,1.6vw,28px); }.quiz-result p { margin:4px 0 0; font-size:13px; color:#597666; }.quiz-result.p2 { background:#eee5fb; }.quiz-result.p2>span { color:#7544ac; }footer { display:flex; justify-content:space-between; gap:20px; padding:16px 25px; background:#e6f0f7; border-top:1px solid #c3d8e7; }footer>div { display:flex; align-items:center; gap:14px; min-width:0; }footer strong { font-size:16px; color:#155d85; }footer .p2 strong { color:#7b409d; }footer span { font-size:13px; }.quiz-state { padding:40px; flex:1; }.public-quiz-enter-active,.public-quiz-leave-active { transition:opacity .2s ease; }.public-quiz-enter-from,.public-quiz-leave-to { opacity:0; }@media(max-width:800px) { .public-quiz-display { inset:2%; }header,footer { padding:12px!important; }.quiz-content { gap:12px; padding:14px; }footer>div { flex-direction:column; align-items:start; gap:4px; }.quiz-option { padding:8px; } }@media(prefers-reduced-motion:reduce) { .public-quiz-enter-active,.public-quiz-leave-active { transition:none; } }
.many-blocks { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); align-content:center; }.many-blocks small { grid-column:1 / -1; }
</style>
