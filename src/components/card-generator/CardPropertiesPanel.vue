<script setup>
import CardArtworkEditor from './CardArtworkEditor.vue';
import CardDataForm from './CardDataForm.vue';
defineProps({card:Object,artwork:Object,back:Object,brief:Object,recipe:Object,recipes:Array,busy:Boolean});
const emit=defineEmits(['upload','remove','change','approve','reject','update-card','duplicate','icon-fit']);
</script>
<template>
 <aside class="cg-properties cg-properties--editable">
  <div class="cg-panel-heading"><h2>Data kartu</h2><span>Draft perangkat tersimpan otomatis</span></div>
  <CardDataForm :card="card" :artwork="artwork" :busy="busy" @update="emit('update-card',$event)" @upload="(file,layer)=>emit('upload',file,layer)" @remove="layer=>emit('remove',layer)" @icon-fit="(index,fit)=>emit('icon-fit',index,fit)" />
  <section class="cg-property-section"><button type="button" :disabled="busy" @click="emit('duplicate')">Duplikat kartu</button></section>
  <CardArtworkEditor :key="card.card_code" :artwork="artwork" :back="back" :brief="brief" :busy="busy" @upload="(file,layer)=>emit('upload',file,layer)" @remove="layer=>emit('remove',layer)" @change="emit('change')" @approve="emit('approve')" @reject="emit('reject')" />
 </aside>
</template>
