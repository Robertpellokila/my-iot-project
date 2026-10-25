<script setup>
import { isSkillImage } from '../../lib/battle/skillState.js';
import { ref, watch } from 'vue';
const props=defineProps({ icon:String, name:String });
const failed=ref(false);
watch(()=>props.icon,()=>{failed.value=false;});
</script>
<template><img v-if="isSkillImage(icon) && !failed" :src="icon" :alt="name || ''" class="skill-image" @error="failed=true" /><span v-else aria-hidden="true">{{ isSkillImage(icon) ? '✦' : icon || '✦' }}</span></template>
<style scoped>.skill-image{width:100%;height:100%;max-width:100%;object-fit:contain;border-radius:50%;}</style>
