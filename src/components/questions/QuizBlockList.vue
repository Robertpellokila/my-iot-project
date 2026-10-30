<script setup>
import { ref } from 'vue';
import { blockTone } from '../../lib/questions/questionModel.js';
const props = defineProps({ modelValue:{type:Array,default:()=>[]}, disabled:Boolean, editable:Boolean });
const emit = defineEmits(['update:modelValue']);
const dragging = ref(null);
function move(from, to) {
  if (props.disabled || !Number.isInteger(from) || from < 0 || from >= props.modelValue.length || to < 0 || to >= props.modelValue.length) return;
  const items = [...props.modelValue]; const [item] = items.splice(from,1); items.splice(to,0,item); emit('update:modelValue',items);
}
function edit(index, text) { const items=props.modelValue.map((item,i)=>i===index?{...item,text}:item); emit('update:modelValue',items); }
function drop(event,index) { if(dragging.value===null)return;event.stopPropagation();move(dragging.value,index);dragging.value=null; }
</script>
<template>
  <ol class="quiz-blocks" aria-label="Urutan blok program">
    <li v-for="(block,index) in modelValue" :key="block.originalIndex ?? block.id" :class="`block-${blockTone(block.text)}`" :draggable="!disabled" @dragstart.stop="dragging=index; $event.dataTransfer.setData('text/plain',String(index))" @dragover.prevent @drop.prevent="drop($event,index)" @dragend="dragging=null">
      <span class="block-number">{{ index+1 }}</span>
      <input v-if="editable" :value="block.text" :aria-label="`Teks blok ${index+1}`" maxlength="180" :disabled="disabled" @input="edit(index,$event.target.value)" />
      <span v-else class="block-text">{{ block.text }}</span>
      <div class="block-controls"><button type="button" :disabled="disabled || index===0" :aria-label="`Naikkan blok ${index+1}`" @click="move(index,index-1)">↑</button><button type="button" :disabled="disabled || index===modelValue.length-1" :aria-label="`Turunkan blok ${index+1}`" @click="move(index,index+1)">↓</button><button v-if="editable" type="button" :disabled="disabled" :aria-label="`Hapus blok ${index+1}`" @click="emit('update:modelValue',modelValue.filter((_,i)=>i!==index))">×</button></div>
    </li>
  </ol>
</template>
<style scoped>
.quiz-blocks { list-style:none; padding:0; margin:0; display:grid; gap:9px; }
.quiz-blocks li { --block:#286aca; display:flex; align-items:center; gap:10px; min-width:0; padding:12px 10px; border:1px solid color-mix(in srgb,var(--block),black 22%); border-bottom-width:3px; border-radius:7px; background:var(--block); color:white; position:relative; }
.quiz-blocks li::after { content:''; position:absolute; bottom:-7px; left:30px; width:28px; height:7px; background:var(--block); border-radius:0 0 5px 5px; z-index:1; }
.quiz-blocks .block-event { --block:#a46506; }.quiz-blocks .block-control { --block:#ad590d; }.quiz-blocks .block-looks { --block:#7944b9; }.quiz-blocks .block-variable { --block:#a74716; }
.block-number { font:700 12px ui-monospace,monospace; opacity:.8; }.block-text { white-space:pre-wrap; flex:1; min-width:0; overflow-wrap:anywhere; font:700 14px/1.4 Arial,sans-serif; }
.quiz-blocks input { flex:1; min-width:0; width:100%; padding:6px 8px; border:1px solid #ffffff70; border-radius:4px; background:#ffffffef; color:#18344c; font:600 14px Arial,sans-serif; }
.block-controls { display:flex; gap:4px; flex:none; }.block-controls button { border:1px solid #ffffff70; border-radius:4px; width:28px; height:28px; background:#ffffff20; color:#fff; cursor:pointer; font:700 15px Arial,sans-serif; }.block-controls button:disabled { opacity:.35; cursor:default; }
button:focus-visible,input:focus-visible { outline:3px solid #ffc84c; outline-offset:2px; }li[draggable=true] { cursor:grab; }
@media(max-width:500px) { .quiz-blocks li { gap:5px; padding:10px 6px; }.block-controls { gap:2px; }.block-controls button { width:24px; }.block-text { font-size:12px; } }
</style>
