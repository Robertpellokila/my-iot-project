<script setup>
defineProps({ index: Number, asset: Object, busy: Boolean });
const emit = defineEmits(['upload','remove','fit']);
const changed = event => {
  const file = event.target.files?.[0];
  if (file) emit('upload',file);
  event.target.value = '';
};
</script>
<template>
  <div class="cg-skill-icon-upload" :data-skill-upload="index + 1">
    <div class="cg-skill-icon-thumb"><img v-if="asset?.url" :src="asset.url" :style="{ objectFit:asset.fit === 'contain' ? 'contain' : 'cover' }" :alt="`Ikon Skill ${index + 1}`" /><span v-else aria-hidden="true">＋</span></div>
    <div class="cg-skill-icon-controls"><strong>Ikon Skill {{ index + 1 }}</strong><small>{{ asset ? `${asset.width} × ${asset.height} px` : 'Upload gambar khusus untuk skill ini.' }}</small>
      <div class="cg-skill-icon-actions"><label class="cg-file-button"><input type="file" accept="image/png,image/webp,image/jpeg" :aria-label="`Upload ikon Skill ${index + 1}`" :disabled="busy" @change="changed" /><span>{{ asset ? 'Ganti ikon' : 'Upload ikon' }}</span></label><button v-if="asset" type="button" :disabled="busy" :aria-label="`Hapus ikon Skill ${index + 1}`" @click="emit('remove')">Hapus</button></div>
      <select v-if="asset" :value="asset.fit" :disabled="busy" :aria-label="`Tampilan ikon Skill ${index + 1}`" @change="emit('fit',$event.target.value)"><option value="cover">Isi lingkaran</option><option value="contain">Tampilkan gambar utuh</option></select>
    </div>
    <p>PNG / WebP / JPG · maks. 10 MB · minimal 128 × 128 px. {{ asset ? 'Hapus untuk memakai ikon otomatis.' : 'Tanpa upload, ikon otomatis tetap tersedia.' }}</p>
  </div>
</template>
