<script setup>
import { computed } from 'vue';
import { renderCardSvg } from '../../lib/card-generator/cardRenderer.js';
const props = defineProps({ card: { type: Object, required: true }, dataset: { type: Object, required: true }, artwork: { type: Object, default: () => ({}) }, side: { type: String, default: 'front' }, template: String, guides: Boolean, proof: Boolean });
const markup = computed(() => renderCardSvg(props.card, props.dataset, props.artwork, { side: props.side, template: props.template, guides: props.guides, proof: props.proof }));
</script>
<template><div class="cg-card-render" :style="{aspectRatio: ['Trial Join','Winning'].includes(template || card.design_template) ? '2 / 3' : '63 / 88'}" v-html="markup"></div></template>
<style scoped>.cg-card-render { width:100%; aspect-ratio:63 / 88; } .cg-card-render :deep(svg) { display:block; width:100%; height:100%; } </style>
