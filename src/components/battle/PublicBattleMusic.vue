<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';

const props = defineProps({ ducked: Boolean });
const menu = ref(null);
const audioElement = ref(null);
const track = ref(null);
const source = ref('');
const playing = ref(false);
const starting = ref(false);
const loading = ref(true);
const volume = ref(30);
const loop = ref(true);
const error = ref('');
const storageNotice = ref('');
const trackName = computed(() => track.value?.name ?? 'Belum ada lagu');
const maxBytes = 30 * 1024 * 1024;
let revision = 0;
let disposed = false;

function storedTrack(mode, value) {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') return reject(new Error('Storage unavailable'));
    const request = indexedDB.open('tbc-battle-music', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('tracks');
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('Storage busy'));
    request.onsuccess = () => {
      const db = request.result;
      db.onversionchange = () => db.close();
      const transaction = db.transaction('tracks', mode === 'read' ? 'readonly' : 'readwrite');
      const store = transaction.objectStore('tracks');
      const operation = mode === 'read' ? store.get('selected')
        : mode === 'remove' ? store.delete('selected') : store.put(value, 'selected');
      transaction.oncomplete = () => { db.close(); resolve(operation.result); };
      transaction.onabort = transaction.onerror = () => { db.close(); reject(transaction.error); };
    };
  });
}

function installTrack(value) {
  audioElement.value?.pause();
  playing.value = false;
  starting.value = false;
  if (source.value) URL.revokeObjectURL(source.value);
  track.value = value;
  source.value = value ? URL.createObjectURL(value.blob) : '';
  error.value = '';
}

async function chooseTrack(event) {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;
  if (!(file.type.startsWith('audio/') || /\.(mp3|wav|ogg|m4a|aac|flac|webm)$/i.test(file.name))) {
    error.value = 'Pilih file audio MP3, WAV, OGG, atau M4A.';
    return;
  }
  if (!file.size || file.size > maxBytes) {
    error.value = 'Ukuran lagu harus di antara 1 byte dan 30 MB.';
    return;
  }
  const version = ++revision;
  loading.value = true;
  storageNotice.value = '';
  installTrack({ blob: file, name: file.name });
  try { await storedTrack('write', { blob: file, name: file.name }); }
  catch {
    if (!disposed && version === revision) storageNotice.value = 'Lagu bisa diputar sekarang. Pilih ulang setelah halaman ditutup.';
  } finally {
    if (!disposed && version === revision) loading.value = false;
  }
}

async function togglePlayback() {
  const audio = audioElement.value;
  if (!audio || !source.value) return;
  if (!audio.paused) { audio.pause(); return; }
  const version = revision;
  starting.value = true;
  error.value = '';
  audio.volume = (volume.value / 100) * (props.ducked ? 0.25 : 1);
  try { await audio.play(); }
  catch (failure) {
    if (!disposed && version === revision && failure.name !== 'AbortError') {
      error.value = failure.name === 'NotAllowedError'
        ? 'Klik Play lagi untuk mengizinkan musik di browser.'
        : 'Lagu tidak dapat diputar. Coba file MP3, WAV, atau OGG lainnya.';
    }
  } finally { if (!disposed && version === revision) starting.value = false; }
}

async function removeTrack() {
  const version = ++revision;
  installTrack(null);
  loading.value = true;
  storageNotice.value = '';
  try { await storedTrack('remove'); }
  catch { if (!disposed && version === revision) storageNotice.value = 'Lagu dihentikan. Salinan tersimpan belum berhasil dihapus.'; }
  finally { if (!disposed && version === revision) loading.value = false; }
}

function closeMenu() {
  if (!menu.value?.open) return;
  menu.value.open = false;
  menu.value.querySelector('summary')?.focus();
}

watch([volume, loop], () => {
  try { localStorage.setItem('tbc:battle-music:settings', JSON.stringify({ volume: volume.value, loop: loop.value })); }
  catch { /* Playback does not require saved preferences. */ }
});
watch([volume, () => props.ducked, audioElement], () => {
  if (audioElement.value) audioElement.value.volume = (volume.value / 100) * (props.ducked ? 0.25 : 1);
});

onMounted(async () => {
  try {
    const saved = JSON.parse(localStorage.getItem('tbc:battle-music:settings') || 'null');
    if (Number.isFinite(saved?.volume)) volume.value = Math.max(0, Math.min(100, saved.volume));
    if (typeof saved?.loop === 'boolean') loop.value = saved.loop;
  } catch { /* Default volume is deliberately below the effects. */ }
  const version = revision;
  try {
    const saved = await storedTrack('read');
    if (!disposed && version === revision && saved?.blob instanceof Blob && saved.blob.size <= maxBytes) installTrack(saved);
  } catch { /* Selecting a song still works without IndexedDB. */ }
  finally { if (!disposed && version === revision) loading.value = false; }
});
onUnmounted(() => {
  disposed = true;
  revision++;
  audioElement.value?.pause();
  if (source.value) URL.revokeObjectURL(source.value);
});
</script>

<template>
  <details ref="menu" class="public-music" @keydown.esc.stop.prevent="closeMenu">
    <summary :title="playing ? `Backsong: ${trackName}` : 'Atur backsong'">
      <span aria-hidden="true">♫</span><strong>{{ playing ? 'MUSIC ON' : 'BACKSONG' }}</strong><i v-if="playing" aria-hidden="true"></i>
    </summary>
    <section class="music-panel" aria-label="Pengaturan backsong">
      <header><div><small>AUDIO ARENA</small><h2>Backsong</h2></div><button type="button" aria-label="Tutup pengaturan backsong" @click="closeMenu">×</button></header>
      <div class="music-track"><span aria-hidden="true">♫</span><div><strong :title="trackName">{{ trackName }}</strong><small>{{ track ? 'Tersedia di browser ini' : 'Pilih lagu untuk mengiringi pertandingan.' }}</small></div></div>
      <div class="music-actions">
        <label class="music-upload"><input type="file" accept="audio/*,.mp3,.wav,.ogg,.m4a" :disabled="loading" aria-label="Pilih file backsong" @change="chooseTrack" /><span>{{ track ? 'Ganti lagu' : 'Pilih lagu' }}</span></label>
        <button v-if="track" type="button" class="music-remove" :disabled="loading" @click="removeTrack">Hapus</button>
      </div>
      <p class="music-hint">MP3, WAV, OGG, M4A · maks. 30 MB. Lagu disimpan di browser ini.</p>
      <button type="button" class="music-play" :disabled="!track || starting" :aria-pressed="playing" @click="togglePlayback"><span aria-hidden="true">{{ playing ? 'Ⅱ' : '▶' }}</span>{{ starting ? 'Memulai…' : playing ? 'Pause backsong' : 'Play backsong' }}</button>
      <label class="music-volume">Volume <output>{{ volume }}%</output><input v-model.number="volume" type="range" min="0" max="100" step="1" aria-label="Volume backsong" /></label>
      <label class="music-loop"><input v-model="loop" type="checkbox" /> Ulangi lagu</label>
      <p class="music-hint">Volume musik otomatis mengecil saat serangan dan pertanyaan.</p>
      <p v-if="error" class="music-error" role="alert">{{ error }}</p>
      <p v-if="storageNotice" class="music-hint" role="status">{{ storageNotice }}</p>
    </section>
  </details>
  <audio v-if="source" ref="audioElement" :src="source" :loop="loop" preload="metadata" @play="playing = true" @pause="playing = false" @ended="playing = false" @error="error = 'Format lagu tidak dapat dibaca. Pilih file audio lainnya.'" />
</template>

<style scoped>
.public-music { position:fixed; z-index:9501; left:128px; bottom:4px; color:#f2d57e; font-family:Inter,Arial,sans-serif; }
summary { display:flex; align-items:center; gap:6px; min-height:24px; padding:4px 8px; border:1px solid #dcb85780; border-radius:5px; background:#06152ce6; box-shadow:0 2px 9px #0005; list-style:none; cursor:pointer; user-select:none; }
summary::-webkit-details-marker { display:none; }
summary > span { font-size:13px; line-height:1; }
summary > strong { font-size:8px; letter-spacing:.035em; }
summary > i { width:5px; height:5px; border-radius:50%; background:#8be1b1; }
summary:hover,.public-music[open] summary { background:#10274e; border-color:#ffe398; }
.music-panel { position:absolute; bottom:calc(100% + 10px); left:0; width:320px; max-width:calc(100vw - 144px); max-height:calc(100dvh - 64px); overflow:auto; padding:20px; color:#f1f5ff; border:1px solid #a98c50; border-radius:12px; background:#091a30; box-shadow:0 12px 50px #0008; }
header { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:20px; }
header small { color:#d5b873; font-size:9px; letter-spacing:.15em; }
h2 { margin:5px 0 0; font-size:20px; }
button,input { font:inherit; }
button { cursor:pointer; }
button:disabled { opacity:.5; cursor:default; }
header button { border:0; background:transparent; color:#aabbd1; padding:5px 8px; font-size:24px; }
.music-track { display:flex; align-items:center; gap:12px; }
.music-track > span { display:grid; place-items:center; width:42px; height:42px; flex:none; border:1px solid #304b68; border-radius:8px; color:#f2d57e; font-size:24px; background:#132a45; }
.music-track > div { min-width:0; }
.music-track strong { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-size:13px; }
.music-track small { display:block; margin-top:5px; color:#a7bbd2; font-size:11px; line-height:1.5; }
.music-actions { display:flex; align-items:center; gap:12px; margin-top:16px; }
.music-upload { position:relative; display:inline-flex; padding:9px 13px; border:1px solid #405879; border-radius:6px; background:#132b47; font-size:12px; font-weight:650; cursor:pointer; }
.music-upload input { position:absolute; width:1px; height:1px; overflow:hidden; clip-path:inset(50%); }
.music-remove { border:0; padding:8px; background:none; color:#b5c7de; font-size:11px; }
.music-hint { margin:10px 0; color:#91a8c2; font-size:10px; line-height:1.7; }
.music-play { display:flex; justify-content:center; align-items:center; gap:8px; width:100%; padding:12px; margin:18px 0; border:1px solid #e8cb7a; border-radius:7px; background:#f2d57e; color:#14253b; font-size:13px; font-weight:750; }
.music-volume { display:flex; flex-wrap:wrap; justify-content:space-between; gap:10px; font-size:12px; }
.music-volume output { color:#f2d57e; font-variant-numeric:tabular-nums; }
.music-volume input { width:100%; margin:0; accent-color:#f2d57e; }
.music-loop { display:flex; align-items:center; gap:7px; margin:16px 0; font-size:12px; }
.music-loop input { accent-color:#f2d57e; }
.music-error { margin:12px 0 0; padding:10px; border-radius:5px; background:#4b2432; color:#ffc9c6; font-size:11px; line-height:1.6; }
:is(summary,button,input):focus-visible,.music-upload:has(input:focus-visible) { outline:2px solid #fff0b4; outline-offset:3px; }
@media(max-width:760px),(max-height:500px) { .public-music { left:40px; } summary { min-height:22px; padding:3px 6px; } summary strong { display:none; }.music-panel { max-width:calc(100vw - 56px); } }
</style>
