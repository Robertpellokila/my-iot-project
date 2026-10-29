<script setup>
import {useAdminFeedback} from '../../composables/useAdminToast.js';
import {defineAsyncComponent,ref,watch} from 'vue';
const PlayerPhotoCamera=defineAsyncComponent(()=>import('./PlayerPhotoCamera.vue'));
const cameraOpen=ref(false);
const props=defineProps({
  player: { type: String, required: true },
  name: { type: String, default: "" },
  preview: { type: String, default: "" },
  processing: Boolean,
  error: { type: String, default: "" },
  warning:String,stage:String,removeBackground:{type:Boolean,default:true},backgroundRemoved:Boolean,
  disabled: Boolean,
});
const emit = defineEmits(["select", "remove", "background", "retry-background"]);
const selectFile = (event) => {
  const file = event.target.files?.[0];
  if (file) emit("select", file);
  event.target.value = "";
};
const adminToast=useAdminFeedback({error:()=>props.error,warning:()=>props.warning,scope:`photo:${props.player}`});
watch(()=>props.processing,(value,previous)=>{if(previous&&!value&&props.preview&&!props.error&&!props.warning)adminToast.success(`Foto ${props.name||props.player} siap. Foto disimpan saat battle dibuat.`);});
function removePhoto(){emit('remove');adminToast.info('Foto dihapus dari pengaturan battle.');}
</script>

<template>
  <section class="setup-player-photo" :class="player" :aria-label="`Foto ${name || (player === 'p1' ? 'Player 1' : 'Player 2')}`" :aria-busy="processing">
    <div class="setup-photo-preview" :class="{cutout:backgroundRemoved}">
      <img v-if="preview" :src="preview" :alt="`Pratinjau foto ${name}`" />
      <div v-else class="setup-photo-trainer" :class="player" aria-hidden="true"></div>
      <span>{{ player === 'p1' ? 'P1' : 'P2' }}</span>
    </div>
    <PlayerPhotoCamera v-if="cameraOpen" :name="name || player" @capture="file=>{cameraOpen=false;emit('select',file);}" @close="cameraOpen=false"/>
    <div class="setup-photo-controls">
      <strong>Foto pemain <small>Opsional</small></strong>
      <p :id="`photo-help-${player}`">JPG, PNG, WebP · maks. 5 MB</p>
      <div class="setup-photo-actions">
        <button type="button" class="setup-photo-camera" :disabled="disabled || processing" @click="cameraOpen=true">Ambil foto</button>
        <label class="setup-photo-select" :class="{ disabled: disabled || processing }">
          <input type="file" accept="image/jpeg,image/png,image/webp" :disabled="disabled || processing" :aria-label="`${preview ? 'Ganti' : 'Upload'} foto ${name || player}`" :aria-describedby="`photo-help-${player}${error ? ` photo-error-${player}` : ''}`" @change="selectFile" />
          <span>{{ processing ? 'Memproses…' : preview ? 'Ganti foto' : 'Upload foto' }}</span>
        </label>
        <button v-if="preview" type="button" class="setup-photo-remove" :disabled="disabled" :aria-label="`Hapus foto ${name || player}`" @click="removePhoto">Hapus</button>
      </div>
      <label class="setup-photo-background"><input type="checkbox" :checked="removeBackground" :disabled="disabled||processing" :aria-label="`Hapus background otomatis ${name||player}`" @change="emit('background',$event.target.checked)"><span>Hapus background otomatis</span></label>
      <small class="setup-photo-note" aria-live="polite">{{ processing ? stage||'Menyiapkan foto…' : backgroundRemoved ? 'Background dihapus · siap tampil di battle.' : preview ? 'Foto asli siap digunakan.' : 'Foto kamera dan upload diproses dengan pengaturan yang sama.' }}</small>
      <button v-if="preview && (backgroundRemoved||processing)" type="button" class="photo-original" :disabled="disabled" @click="emit('background',false)">Pakai foto asli</button>
      <small class="setup-photo-privacy">Foto diproses di perangkatmu, lalu disimpan saat battle dibuat. Pemrosesan pertama bisa lebih lama.</small>
    </div>
    <div v-if="warning" class="setup-photo-warning" role="status"><p>{{ warning }}</p><button type="button" :disabled="disabled||processing" @click="emit('retry-background')">Coba hapus background lagi</button><button type="button" :disabled="disabled||processing" @click="emit('background',false)">Pakai foto asli</button></div>
    <p v-if="error" :id="`photo-error-${player}`" class="setup-photo-error" role="alert">{{ error }}</p>
  </section>
</template>

<style scoped>
.setup-player-photo { --photo-accent:#3488a6; display:grid; grid-template-columns:80px minmax(0,1fr); align-items:center; gap:12px; padding:14px; min-width:0; border:1px solid #dce6dd; border-radius:12px; background:#f8fbf8; color:#294631; }
.setup-player-photo.p2 { --photo-accent:#9564b2; }
.setup-photo-preview { position:relative; width:80px; aspect-ratio:1; overflow:hidden; border:2px solid var(--photo-accent); border-radius:14px; background:#e3eeeb; }
.setup-photo-preview.cutout{background-color:#f5f8f1;background-image:conic-gradient(#d8e5d1 25%,transparent 0 50%,#d8e5d1 0 75%,transparent 0);background-size:16px 16px}
.setup-photo-preview img { width:100%; height:100%; object-fit:contain; object-position:center bottom; }
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
.setup-player-photo .setup-photo-camera{min-height:34px;padding:7px 11px;background:#edf6e4;color:#2c663c;border:1px solid #b9d1aa;border-radius:7px;font:700 11px Inter,Arial,sans-serif;cursor:pointer}.setup-player-photo .setup-photo-camera:disabled{opacity:.55;cursor:default}.setup-player-photo .setup-photo-camera:focus-visible{outline:2px solid #257b9b;outline-offset:3px}.setup-photo-background{display:flex;align-items:center;gap:7px;margin-top:12px;font-size:10px;color:#506d52;cursor:pointer}.setup-player-photo .setup-photo-background input{width:14px;height:14px;padding:0;margin:0;flex:none;accent-color:#277847}.setup-photo-privacy{display:block;font-size:9px;line-height:1.6;color:#80907a;margin-top:5px}.setup-photo-warning{grid-column:1/-1;border:1px solid #ead3ac;border-radius:8px;background:#fff7e8;padding:10px;color:#91652e;font-size:10px;line-height:1.7}.setup-photo-warning p{margin:0 0 8px}.setup-photo-warning button,.photo-original{font:650 10px Inter,Arial,sans-serif;color:#47783b;background:transparent;border:0;text-decoration:underline;cursor:pointer;padding:4px 0;margin-right:12px}.setup-photo-warning button:focus-visible,.photo-original:focus-visible{outline:2px solid #257b9b;outline-offset:3px}
.setup-photo-error { grid-column:1 / -1; margin:0; color:#a43c3c; font-size:11px; line-height:1.5; }
@media(max-width:420px) { .setup-player-photo { grid-template-columns:66px minmax(0,1fr); padding:12px; gap:10px; } .setup-photo-preview { width:66px; } }
</style>
