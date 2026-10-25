<script setup>
defineProps({
  player: { type: String, required: true },
  name: { type: String, default: "" },
  preview: { type: String, default: "" },
  processing: Boolean,
  error: { type: String, default: "" },
  disabled: Boolean,
});
const emit = defineEmits(["select", "remove"]);
const selectFile = (event) => {
  const file = event.target.files?.[0];
  if (file) emit("select", file);
  event.target.value = "";
};
</script>

<template>
  <section class="setup-player-photo" :class="player" :aria-label="`Foto ${name || (player === 'p1' ? 'Player 1' : 'Player 2')}`" :aria-busy="processing">
    <div class="setup-photo-preview">
      <img v-if="preview" :src="preview" :alt="`Pratinjau foto ${name}`" />
      <div v-else class="setup-photo-trainer" :class="player" aria-hidden="true"></div>
      <span>{{ player === 'p1' ? 'P1' : 'P2' }}</span>
    </div>
    <div class="setup-photo-controls">
      <strong>Foto pemain <small>Opsional</small></strong>
      <p :id="`photo-help-${player}`">JPG, PNG, WebP · maks. 5 MB</p>
      <div class="setup-photo-actions">
        <label class="setup-photo-select" :class="{ disabled: disabled || processing }">
          <input type="file" accept="image/jpeg,image/png,image/webp" :disabled="disabled || processing" :aria-label="`${preview ? 'Ganti' : 'Upload'} foto ${name || player}`" :aria-describedby="`photo-help-${player}${error ? ` photo-error-${player}` : ''}`" @change="selectFile" />
          <span>{{ processing ? 'Memproses…' : preview ? 'Ganti foto' : 'Upload foto' }}</span>
        </label>
        <button v-if="preview" type="button" class="setup-photo-remove" :disabled="disabled || processing" :aria-label="`Hapus foto ${name || player}`" @click="emit('remove')">Hapus</button>
      </div>
      <small class="setup-photo-note" aria-live="polite">{{ processing ? 'Menyiapkan foto…' : preview ? 'Foto ini akan tampil di layar pertandingan.' : 'Tanpa foto, gunakan avatar bawaan.' }}</small>
    </div>
    <p v-if="error" :id="`photo-error-${player}`" class="setup-photo-error" role="alert">{{ error }}</p>
  </section>
</template>

<style scoped>
.setup-player-photo { --photo-accent:#3488a6; display:grid; grid-template-columns:80px minmax(0,1fr); align-items:center; gap:12px; padding:14px; min-width:0; border:1px solid #dce6dd; border-radius:12px; background:#f8fbf8; color:#294631; }
.setup-player-photo.p2 { --photo-accent:#9564b2; }
.setup-photo-preview { position:relative; width:80px; aspect-ratio:1; overflow:hidden; border:2px solid var(--photo-accent); border-radius:14px; background:#e3eeeb; }
.setup-photo-preview img { width:100%; height:100%; object-fit:cover; object-position:center 25%; }
.setup-photo-trainer { width:100%; height:100%; background:url('/images/tbc-trainers.png') left center / 200% 100% no-repeat; }
.setup-photo-trainer.p2 { background-position:right center; }
.setup-photo-preview > span { position:absolute; left:0; bottom:0; padding:3px 7px; border-radius:0 6px 0 0; color:white; background:var(--photo-accent); font-size:9px; font-weight:800; }
.setup-photo-controls { min-width:0; }
.setup-photo-controls > strong { display:flex; flex-wrap:wrap; align-items:baseline; gap:6px; font-size:12px; }
.setup-photo-controls > strong small { color:#7a8b7e; font-size:10px; font-weight:400; }
.setup-photo-controls > p { margin:5px 0 9px; color:#657a6b; font-size:10px; line-height:1.5; }
.setup-photo-actions { display:flex; flex-wrap:wrap; align-items:center; gap:7px; }
.setup-photo-select { position:relative; display:inline-flex; align-items:center; min-height:34px; padding:7px 11px; border:1px solid #a4c3ab; border-radius:7px; color:#245e35; background:white; cursor:pointer; font-size:11px; font-weight:700; }
.setup-photo-select:hover { background:#eff7ee; }
.setup-photo-select input { position:absolute; width:1px; height:1px; padding:0; border:0; clip-path:inset(50%); overflow:hidden; }
.setup-photo-select:has(input:focus-visible) { outline:2px solid #257b9b; outline-offset:3px; }
.setup-photo-select.disabled { opacity:.6; cursor:wait; }
.setup-photo-remove { min-height:34px; padding:7px 4px; border:0; border-radius:4px; color:#627668; background:transparent; font-size:10px; cursor:pointer; }
.setup-photo-remove:hover { color:#953c3c; }
.setup-photo-remove:focus-visible { outline:2px solid #257b9b; outline-offset:2px; }
.setup-photo-note { display:block; margin-top:7px; color:#718376; font-size:9px; line-height:1.5; }
.setup-photo-error { grid-column:1 / -1; margin:0; color:#a43c3c; font-size:11px; line-height:1.5; }
@media(max-width:420px) { .setup-player-photo { grid-template-columns:66px minmax(0,1fr); padding:12px; gap:10px; } .setup-photo-preview { width:66px; } }
</style>
