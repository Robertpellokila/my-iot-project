<script setup>
import { ref, watch } from 'vue';
import { FIXED_BACK, fixedBackAvailable } from '../../lib/card-generator/cardBack.js';
const props = defineProps({ artwork: Object, busy: Boolean, brief: Object, back: Object });
const emit = defineEmits(['upload', 'remove', 'change', 'approve', 'reject']);
const layer = ref('character'), reviewed = ref(false);
watch(() => props.artwork.version, () => { reviewed.value = false; });
const fileChanged = event => { const file = event.target.files?.[0]; if (file) emit('upload', file, layer.value); event.target.value = ''; reviewed.value = false; };
</script>
<template>
  <section class="cg-property-section cg-artwork-editor">
    <div class="cg-section-title"><h3>Artwork</h3><small>v{{ artwork.version }}</small></div>
    <label>Layer<select v-model="layer"><option value="background">1 · Background</option><option value="character">2 · Character / full composition</option><option value="foreground">3 · Foreground detail</option></select></label>
    <div class="cg-upload-surface">
      <img v-if="artwork[layer]?.url" :src="artwork[layer].url" alt="Artwork layer terpilih" />
      <p>{{ artwork[layer] ? `${artwork[layer].width} × ${artwork[layer].height} px` : 'PNG transparan atau komposisi WebP penuh' }}</p>
      <label class="cg-file-button"><input type="file" accept="image/png,image/webp" :disabled="busy" @change="fileChanged" /><span>{{ busy ? 'Mengunggah…' : artwork[layer] ? 'Ganti artwork' : 'Upload artwork' }}</span></label>
      <button v-if="artwork[layer]" class="cg-text-button" type="button" :disabled="busy" @click="emit('remove', layer); reviewed = false">Hapus layer</button>
      <small>Max 10 MB · dioptimalkan untuk penyimpanan</small>
    </div>
    <template v-if="artwork[layer]">
      <label>Posisi horizontal <output>{{ artwork[layer].x }}</output><input v-model.number="artwork[layer].x" type="range" min="-300" max="300" :disabled="busy" @input="emit('change'); reviewed = false" /></label>
      <label>Posisi vertikal <output>{{ artwork[layer].y }}</output><input v-model.number="artwork[layer].y" type="range" min="-220" max="220" :disabled="busy" @input="emit('change'); reviewed = false" /></label>
      <label>Scale <output>{{ Number(artwork[layer].scale).toFixed(2) }}×</output><input v-model.number="artwork[layer].scale" type="range" min=".3" max="3" step=".01" :disabled="busy" @input="emit('change'); reviewed = false" /></label>
      <label>Fit<select v-model="artwork[layer].fit" :disabled="busy" @change="emit('change'); reviewed = false"><option value="cover">Cover · isi area</option><option value="contain">Contain · tampilkan utuh</option></select></label>
    </template>
    <details v-if="brief" class="cg-brief"><summary>Brief ilustrasi · {{ brief.artwork_id }}</summary><dl><dt>Karakter</dt><dd>{{ brief.mascot }} · {{ brief.species }}</dd><dt>Pose / kamera</dt><dd>{{ brief.pose_description }} · {{ brief.camera }}</dd><dt>Environment / lighting</dt><dd>{{ brief.environment }} · {{ brief.lighting }}</dd><dt>Referensi karakter</dt><dd>{{ brief.character_reference.length ? brief.character_reference.join(', ') : 'Belum tersedia; cocokkan dengan referensi maskot yang disetujui.' }}</dd></dl><p>{{ brief.artwork_prompt }}</p></details>
    <template v-if="artwork.character">
      <label class="cg-checkline"><input v-model="reviewed" type="checkbox" :disabled="busy" /><span>Karakter, pose unik, keterbacaan, dan referensi maskot sudah ditinjau.</span></label>
      <div class="cg-inline-actions"><button type="button" :disabled="!reviewed || busy" @click="emit('approve')">Approve artwork</button><button v-if="artwork.approval_status === 'approved'" type="button" :disabled="busy" @click="emit('reject'); reviewed = false">Kembalikan ke draft</button></div>
    </template>
    <details class="cg-back-settings"><summary>Back tetap · semua rarity</summary><p>Gambar Timedoor Academy / TBC yang sama otomatis dipakai untuk semua kartu dan ekspor.</p><img v-if="fixedBackAvailable()" class="cg-fixed-back-preview" :src="FIXED_BACK.url" alt="Back tetap Timedoor Battle Cards" /><p v-else>File asli gambar back referensi belum terpasang.</p></details>
  </section>
</template>
