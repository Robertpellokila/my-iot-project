<script setup>
import { onMounted, onUnmounted, reactive, ref } from 'vue';
import { DEFAULT_PRINT, printGeometry, cardPrintSettings } from '../../lib/card-generator/cardLayoutTokens.js';
import { exportCards, downloadBlob } from '../../lib/card-generator/cardExportService.js';
const props = defineProps({ cards: Array, dataset: Object, workspace: Object });
const emit = defineEmits(['close']);
const options = reactive({ format: 'png', side: 'front', flip: 'long-edge', proof: true, print: cardPrintSettings(props.cards[0]) });
const busy = ref(false), progress = ref(0), error = ref('');
const dialog = ref(null);
const previousFocus = document.activeElement;
const trapFocus = event => {
  if (event.key !== 'Tab') return;
  const nodes = [...dialog.value.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled)')];
  const first = nodes[0], last = nodes.at(-1);
  if (!first) { event.preventDefault(); dialog.value.focus(); }
  else if (event.shiftKey && (document.activeElement === first || document.activeElement === dialog.value)) { event.preventDefault(); last.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
};
onMounted(() => { dialog.value?.focus(); document.addEventListener('keydown', trapFocus); });
onUnmounted(() => { document.removeEventListener('keydown', trapFocus); previousFocus?.focus?.(); });
const scaleCard = () => { Object.assign(options.print,cardPrintSettings(props.cards[0],options.print)); };
const run = async () => { if (busy.value) return; error.value = ''; busy.value = true; try { printGeometry(options.print); const result = await exportCards(props.cards, props.dataset, props.workspace, options, value => progress.value = value); downloadBlob(result.blob, result.name); } catch (err) { error.value = err.message; } finally { busy.value = false; } };
</script>
<template><div class="cg-modal-backdrop" @click.self="!busy && emit('close')" @keydown.esc="!busy && emit('close')"><section ref="dialog" class="cg-export-dialog" role="dialog" aria-modal="true" aria-labelledby="cg-export-title" tabindex="-1"><header><div><small class="cg-eyebrow">PRINT & EXPORT</small><h2 id="cg-export-title">Ekspor {{ cards.length }} kartu</h2></div><button type="button" aria-label="Tutup ekspor" :disabled="busy" @click="emit('close')">×</button></header><div class="cg-export-fields"><label>Format<select v-model="options.format" :disabled="busy"><option value="png">PNG · high resolution</option><option value="svg">SVG · editable vector</option><option value="pdf">PDF · ukuran kartu</option><option value="sheet">PDF · A4 test / duplex sheet</option></select></label><label>Sisi<select v-model="options.side" :disabled="busy"><option value="front">Depan</option><option value="back">Belakang</option><option value="both">Depan + belakang</option></select></label><label>Lebar trim (mm)<input v-model.number="options.print.width" type="number" min="30" max="190" step="1" :disabled="busy" @change="scaleCard" /></label><label>Tinggi trim (mm)<input :value="options.print.height" readonly /></label><label>Bleed (mm)<input v-model.number="options.print.bleed" type="number" min="0" max="10" step=".5" :disabled="busy" /></label><label>Resolusi<select v-model.number="options.print.dpi" :disabled="busy"><option :value="300">300 DPI</option><option :value="600">600 DPI</option></select></label><label v-if="options.format === 'sheet'">Duplex flip<select v-model="options.flip" :disabled="busy"><option value="long-edge">Long edge · cermin kolom</option><option value="short-edge">Short edge · cermin baris</option></select></label></div><label class="cg-checkline"><input v-model="options.print.guides" type="checkbox" :disabled="busy" /><span>Crop guides di luar garis trim</span></label><label class="cg-checkline"><input v-model="options.proof" type="checkbox" :disabled="busy" /><span>Proof berwatermark untuk review. Matikan hanya untuk kartu Ready for Print.</span></label><p class="cg-source-note">Cetak pada skala 100%, tanpa “fit to page”. Uji satu lembar, periksa garis trim depan/belakang, lalu sesuaikan registrasi printer. Preview 1:1 di layar bergantung pada perangkat.</p><p v-if="error" class="cg-error" role="alert">{{ error }}</p><progress v-if="busy" :value="progress" max="1"></progress><footer><span>Komposisi yang sama dengan live preview</span><button class="cg-primary" type="button" :disabled="busy" @click="run">{{ busy ? `${Math.round(progress * 100)}% · Mengekspor…` : 'Download export' }}</button></footer></section></div></template>
