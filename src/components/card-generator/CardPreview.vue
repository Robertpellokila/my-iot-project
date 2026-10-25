<script setup>
import { ref } from 'vue';
import CardFrameRenderer from './CardFrameRenderer.vue';
defineProps({ card: Object, dataset: Object, artwork: Object, status: Object });
const side = ref('front'), zoom = ref(1), actualSize = ref(false), guides = ref(false);
</script>
<template>
  <section class="cg-preview">
    <div class="cg-preview-heading"><span>{{ card.card_code }} <i> / </i>{{ card.kind === 'fusion' ? 'FUSION MASTER' : `${card.rarity.toUpperCase()} MASTER` }}</span><span class="cg-status" :class="{ ready: status.ready }">{{ status.status }}</span></div>
    <div class="cg-preview-tools">
      <div class="cg-segment"><button type="button" :class="{ active: side === 'front' }" @click="side = 'front'">Depan</button><button type="button" :class="{ active: side === 'back' }" @click="side = 'back'">Belakang</button></div>
      <select v-model.number="zoom" aria-label="Zoom preview" @change="actualSize = false"><option :value=".75">75%</option><option :value="1">Fit</option><option :value="1.25">125%</option><option :value="1.5">150%</option><option :value="2">200%</option></select>
      <button type="button" :class="{ active: actualSize }" @click="actualSize = !actualSize">1:1</button>
      <button type="button" :aria-pressed="guides" @click="guides = !guides">Safe area</button>
    </div>
    <div class="cg-preview-canvas"><div class="cg-preview-artboard" :style="{ width: actualSize ? '63mm' : zoom === 1 ? 'min(350px,100%)' : `${350 * zoom}px`, minWidth: actualSize ? '63mm' : zoom === 1 ? '0' : `${350 * zoom}px` }"><CardFrameRenderer :card="card" :dataset="dataset" :artwork="artwork" :side="side" :guides="guides" /></div></div>
    <div class="cg-preview-ruler"><span>63 × {{ ['Trial Join','Winning'].includes(card.design_template) ? '94.5' : '88' }} mm <i>trim</i></span><span>+ 3 mm bleed <i>export</i></span></div>
    <p class="cg-preview-note">{{ actualSize ? 'Skala layar perkiraan. Gunakan test sheet 100% untuk memeriksa ukuran cetak.' : 'Preview komposisi · posisi elemen tetap sama pada semua master.' }}</p>
  </section>
</template>
