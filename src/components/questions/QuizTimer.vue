<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { quizClockState } from '../../lib/questions/quizClock.js';
const props=defineProps({round:{type:Object,default:null},seconds:{type:Number,default:0},unavailable:Boolean});
const now=ref(Date.now());const interval=setInterval(()=>now.value=Date.now(),250);onUnmounted(()=>clearInterval(interval));
const clock=computed(()=>quizClockState(props.round,props.seconds,now.value));
</script>
<template><div class="quiz-timer" :class="{urgent:!unavailable && clock.remaining!==null && clock.remaining<=8}" role="timer" aria-label="Waktu quiz"><span>WAKTU QUIZ</span><strong>{{ unavailable?'Timer belum tersedia':round?.winner_player?'Jawaban diterima':clock.label }}</strong><div v-if="seconds>0 && !unavailable" class="timer-track"><i :style="{width:`${clock.progress}%`}"/></div></div></template>
<style scoped>
.quiz-timer { flex:none; min-width:120px; padding:9px 13px; border:1px solid #c1dbca; border-radius:8px; background:#edf8f0; color:#1a6742; text-align:center; }.quiz-timer>span { display:block; font:800 9px/1.4 Arial,sans-serif; letter-spacing:.08em; }.quiz-timer strong { display:block; font:800 19px/1.4 Arial,sans-serif; font-variant-numeric:tabular-nums; }.timer-track { margin-top:4px; height:4px; border-radius:4px; background:#cbe1d2; overflow:hidden; }.timer-track i { display:block; height:100%; background:#219963; }.urgent { color:#972e1e; border-color:#edb5a7; background:#fff1e9; }.urgent .timer-track i { background:#d55233; }
</style>
