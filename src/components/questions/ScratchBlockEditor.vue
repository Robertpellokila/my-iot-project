<script setup>
import { computed } from 'vue';
import QuizBlockList from './QuizBlockList.vue';
import { blockTone } from '../../lib/questions/questionModel.js';
const props=defineProps({modelValue:{type:Array,default:()=>[]},disabled:Boolean});
const emit=defineEmits(['update:modelValue']);
const palette=['Ketika bendera hijau diklik','Gerak 10 langkah','Putar 15 derajat','Pergi ke x: 0 y: 0','Katakan Halo! selama 2 detik','Ulangi 3 kali','Tunggu 1 detik','Jika menyentuh tepi, pantulkan','Ubah skor sebesar 1','Selesai pengulangan'];
const items=computed(()=>props.modelValue.map((text,id)=>({text,id})));
function add(text) { if(!props.disabled && props.modelValue.length<12) emit('update:modelValue',[...props.modelValue,text]); }
function drop(event) { const index=Number(event.dataTransfer.getData('application/tbc-block')); if(event.dataTransfer.types.includes('application/tbc-block') && palette[index]) add(palette[index]); }
</script>
<template>
  <div class="scratch-editor">
    <aside><h3>Palet blok</h3><p>Tarik ke program atau klik untuk menambahkan.</p><button v-for="block in palette" :key="block" type="button" :class="`palette-${blockTone(block)}`" :disabled="disabled || modelValue.length>=12" :draggable="!disabled" @click="add(block)" @dragstart="$event.dataTransfer.setData('application/tbc-block',String(palette.indexOf(block)))">＋ {{ block }}</button><button type="button" :disabled="disabled || modelValue.length>=12" @click="add('Blok baru')">＋ Blok sendiri</button></aside>
    <section @dragover.prevent @drop.prevent="drop"><header><h3>Program yang benar</h3><span>{{ modelValue.length }} / 12 blok</span></header><p>Susun kunci jawaban di sini. Klik teks untuk mengganti angka atau perintah.</p><QuizBlockList :model-value="items" editable :disabled="disabled" @update:model-value="emit('update:modelValue',$event.map(block=>block.text))"/><div v-if="!modelValue.length" class="empty-program">Tarik blok pertamamu ke sini.</div><small>Quiz memeriksa urutan blok sesuai kunci guru. Program tidak menjalankan proyek Scratch.</small></section>
  </div>
</template>
<style scoped>
.scratch-editor { display:grid; grid-template-columns:minmax(180px,.7fr) minmax(0,1.4fr); border:1px solid #cfdde6; border-radius:12px; overflow:hidden; color:#19374d; }.scratch-editor aside { padding:16px; background:#edf3f7; }.scratch-editor section { padding:16px; min-width:0; background:#fff; }h3 { margin:0; font-size:14px; }p,small { color:#5b7282; font-size:12px; line-height:1.5; }small { display:block; margin-top:18px; }header { display:flex; justify-content:space-between; align-items:center; gap:8px; }header span { font-size:11px; color:#557183; }aside button { display:block; width:100%; text-align:left; margin-top:8px; padding:10px; border:1px solid #b5cbde; border-left:5px solid #286aca; border-radius:5px; background:white; color:#244d73; font:600 12px/1.4 Arial,sans-serif; cursor:grab; }aside .palette-event { border-left-color:#a46506; }aside .palette-control { border-left-color:#ad590d; }aside .palette-looks { border-left-color:#7944b9; }aside .palette-variable { border-left-color:#a74716; }button:disabled { opacity:.5; cursor:default; }.empty-program { padding:45px 10px; border:2px dashed #aac6d9; border-radius:8px; text-align:center; color:#648096; font-size:13px; }button:focus-visible { outline:3px solid #168a54; outline-offset:2px; }@media(max-width:700px) { .scratch-editor { grid-template-columns:1fr; }aside { max-height:235px; overflow:auto; } }
</style>
