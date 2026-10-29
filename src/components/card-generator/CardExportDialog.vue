<script setup>
import { useAdminToast } from '../../composables/useAdminToast.js';
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { printGeometry, cardPrintSettings } from '../../lib/card-generator/cardLayoutTokens.js';
import { cardReadiness, renderSignature } from '../../lib/card-generator/cardValidationService.js';
import { duplicateArtworkCodes } from '../../lib/card-generator/cardArtworkService.js';
import { exportCards, prepareCardsForPrint, downloadBlob } from '../../lib/card-generator/cardExportService.js';
const props = defineProps({ cards: Array, dataset: Object, workspace: Object });
const emit = defineEmits(['close', 'edit']);
const options = reactive({ format: 'png', side: 'front', flip: 'long-edge', proof: true, print: cardPrintSettings(props.cards[0]) });
const busy = ref(false), progress = ref(0), error = ref(''), phase = ref('');
const reviewed = ref(false), prepared = ref(false), failures = ref([]);
const dialog = ref(null), toastId = ref(null);
const adminToast = useAdminToast();
const readyCards = computed(() => {
  try {
    return props.cards.filter(card => cardReadiness(card, props.dataset, props.workspace.artworks[card.card_code], props.workspace.back, options.print).ready
      && !duplicateArtworkCodes(props.workspace.artworks, card.card_code).length);
  } catch { return []; }
});
const resetReport = () => { prepared.value = false; failures.value = []; error.value = ''; };
watch(() => JSON.stringify([options.print, options.proof]), resetReport);
watch(() => props.cards.map(card => renderSignature(card, props.workspace.artworks[card.card_code])).join('\n'), () => { reviewed.value = false; resetReport(); });
const previousFocus = document.activeElement;
const trapFocus = event => {
  if (event.key !== 'Tab') return;
  const nodes = [...dialog.value.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled),summary')];
  const first = nodes[0], last = nodes.at(-1);
  if (!first) { event.preventDefault(); dialog.value.focus(); }
  else if (event.shiftKey && (document.activeElement === first || document.activeElement === dialog.value)) { event.preventDefault(); last.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
};
onMounted(() => { dialog.value?.focus(); document.addEventListener('keydown', trapFocus); });
onUnmounted(() => { document.removeEventListener('keydown', trapFocus); previousFocus?.focus?.(); });
const scaleCard = () => { Object.assign(options.print, cardPrintSettings(props.cards[0], options.print)); };
const start = label => {
  error.value = ''; progress.value = 0; busy.value = true; phase.value = label;
  if (toastId.value) adminToast.dismiss(toastId.value);
  toastId.value = adminToast.loading(`${label}. Tunggu hingga selesai.`, { title: 'Ekspor kartu' });
};
const fail = err => {
  failures.value = err.failures ?? [];
  error.value = failures.value.length ? `${failures.value.length} kartu belum Ready for Print. Lihat rincian di bawah.` : err.message;
  adminToast.update(toastId.value, { type: 'danger', title: 'Ekspor belum selesai', message: error.value || 'Berkas belum dapat diekspor. Coba lagi.' });
};
const prepare = async () => {
  if (busy.value || !reviewed.value) return;
  start('Memeriksa kartu');
  try {
    const result = await prepareCardsForPrint(props.cards, props.dataset, props.workspace, { print: options.print, approveArtwork: true }, value => progress.value = value);
    failures.value = result.failures; prepared.value = true;
    adminToast.update(toastId.value, { type: result.failures.length ? 'warning' : 'success', title: 'Pemeriksaan selesai',
      message: `${result.readyCards.length} dari ${props.cards.length} kartu siap dicetak.${result.failures.length ? ` ${result.failures.length} kartu perlu diperbaiki; rincian tersedia di dialog ekspor.` : ' Klik Download export untuk mengunduh.'}` });
  } catch (err) { fail(err); }
  finally { busy.value = false; }
};
const run = async (readyOnly = false) => {
  if (busy.value) return;
  const cards = readyOnly ? [...readyCards.value] : props.cards;
  start('Mengekspor kartu');
  try {
    printGeometry(options.print);
    const result = await exportCards(cards, props.dataset, props.workspace, options, value => progress.value = value);
    downloadBlob(result.blob, result.name);
    adminToast.update(toastId.value, { type: 'success', title: 'Ekspor selesai', message: `Berkas kartu siap diunduh. ${cards.length} kartu diekspor.` });
  } catch (err) { fail(err); }
  finally { busy.value = false; }
};
</script>

<template>
  <div class="cg-modal-backdrop" @click.self="!busy && emit('close')" @keydown.esc="!busy && emit('close')">
    <section ref="dialog" class="cg-export-dialog" role="dialog" aria-modal="true" aria-labelledby="cg-export-title" tabindex="-1">
      <header><div><small class="cg-eyebrow">PRINT & EXPORT</small><h2 id="cg-export-title">Ekspor {{ cards.length }} kartu</h2></div><button type="button" aria-label="Tutup ekspor" :disabled="busy" @click="emit('close')">×</button></header>
      <div class="cg-export-fields">
        <label>Format<select v-model="options.format" :disabled="busy"><option value="png">PNG · high resolution</option><option value="svg">SVG · editable vector</option><option value="pdf">PDF · ukuran kartu</option><option value="sheet">PDF · A4 test / duplex sheet</option></select></label>
        <label>Sisi<select v-model="options.side" :disabled="busy"><option value="front">Depan</option><option value="back">Belakang</option><option value="both">Depan + belakang</option></select></label>
        <label>Lebar trim (mm)<input v-model.number="options.print.width" type="number" min="30" max="190" step="1" :disabled="busy" @change="scaleCard" /></label>
        <label>Tinggi trim (mm)<input :value="options.print.height" readonly /></label>
        <label>Bleed (mm)<input v-model.number="options.print.bleed" type="number" min="0" max="10" step=".5" :disabled="busy" /></label>
        <label>Resolusi<select v-model.number="options.print.dpi" :disabled="busy"><option :value="300">300 DPI</option><option :value="600">600 DPI</option></select></label>
        <label v-if="options.format === 'sheet'">Duplex flip<select v-model="options.flip" :disabled="busy"><option value="long-edge">Long edge · cermin kolom</option><option value="short-edge">Short edge · cermin baris</option></select></label>
      </div>
      <label class="cg-checkline"><input v-model="options.print.guides" type="checkbox" :disabled="busy" /><span>Crop guides di luar garis trim</span></label>
      <label class="cg-checkline"><input v-model="options.proof" type="checkbox" :disabled="busy" /><span>Proof berwatermark untuk review. Matikan untuk ekspor cetak.</span></label>
      <section v-if="!options.proof" class="cg-print-review" aria-label="Persiapan cetak">
        <strong>{{ readyCards.length }} / {{ cards.length }} kartu Ready for Print</strong>
        <p>Kualitas gambar diperiksa sesuai ukuran cetak, DPI, dan zoom. Desain tetap seperti preview.</p>
        <label class="cg-checkline"><input v-model="reviewed" type="checkbox" :disabled="busy" /><span>Saya sudah meninjau dan menyetujui desain {{ cards.length }} kartu yang dipilih.</span></label>
        <button type="button" :disabled="busy || !reviewed" @click="prepare">Setujui &amp; periksa {{ cards.length }} kartu</button>
        <p v-if="prepared && !failures.length" role="status">Semua kartu lolos. Klik Download export untuk mengunduh tanpa watermark.</p>
      </section>
      <p class="cg-source-note">Cetak pada skala 100%, tanpa “fit to page”. Uji satu lembar, periksa garis trim depan/belakang, lalu sesuaikan registrasi printer. Preview 1:1 di layar bergantung pada perangkat.</p>
      <p v-if="error" class="cg-error" role="alert">{{ error }}</p>
      <section v-if="failures.length && !options.proof" class="cg-print-failures" aria-label="Kartu yang perlu diperbaiki">
        <strong>{{ failures.length }} kartu perlu diperbaiki</strong>
        <ul><li v-for="item in failures" :key="item.code"><button type="button" :disabled="busy" @click="emit('edit', item.code)">Buka {{ item.code }}</button><span>{{ item.message }}</span></li></ul>
      </section>
      <progress v-if="busy" :value="progress" max="1" :aria-label="phase"></progress>
      <footer>
        <span>Komposisi yang sama dengan live preview</span>
        <div class="cg-export-buttons">
          <button v-if="!options.proof && failures.length && readyCards.length" type="button" :disabled="busy" @click="run(true)">Download {{ readyCards.length }} kartu yang lolos</button>
          <button class="cg-primary" type="button" :disabled="busy || (!options.proof && prepared && failures.length > 0)" @click="run()">{{ busy ? `${Math.round(progress * 100)}% · ${phase}…` : 'Download export' }}</button>
        </div>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.cg-print-review { display:grid; gap:10px; margin:14px 0; padding:14px; border:1px solid #c9ddcd; border-radius:8px; background:#f1f7ef; font-size:12px; }
.cg-print-review p { margin:0; line-height:1.6; color:#54735d; }
.cg-print-review > button { justify-self:start; }
.cg-print-failures { padding:12px; border:1px solid #e1bdb0; border-radius:8px; font-size:12px; }
.cg-print-failures ul { max-height:200px; overflow:auto; padding:0; margin:10px 0 0; list-style:none; }
.cg-print-failures li { display:grid; gap:5px; padding:8px 0; line-height:1.6; }
.cg-print-failures button { justify-self:start; }
.cg-export-buttons { display:flex; flex-wrap:wrap; justify-content:flex-end; gap:8px; }
</style>
