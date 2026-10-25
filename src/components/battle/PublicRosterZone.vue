<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import PublicDisplayCard from './PublicDisplayCard.vue';
import { publicCardStats } from '../../utils/publicCardStats.js';

const props = defineProps({
  cards: { type: Array, default: () => [] },
  zone: { type: String, required: true },
  player: { type: String, required: true },
  capacity: { type: Number, default: 4 },
  featuredId: { default: null },
  inspectedId: { default: null },
  live: Boolean,
});
const cardId = card => card?.battleId ?? card?.battle_id ?? card?.id ?? null;
const page = ref(0);
const arriving = ref([]);
let arrivalTimer;
const pageCount = computed(() => Math.max(1, Math.ceil(props.cards.length / 4)));
const currentPage = computed(() => Math.min(page.value, pageCount.value - 1));
const slots = computed(() => props.cards.slice(currentPage.value * 4, currentPage.value * 4 + 4));
watch(() => props.inspectedId, id => {
  if (id == null) return;
  const index = props.cards.findIndex(card => String(cardId(card)) === String(id));
  if (index >= 0) page.value = Math.floor(index / 4);
}, { immediate: true });
watch(() => props.cards.map(card => String(cardId(card))), (ids, previous) => {
  const added = ids.filter(id => !previous.includes(id));
  clearTimeout(arrivalTimer);
  arriving.value = added;
  if (added.length) page.value = Math.floor(ids.indexOf(added[0]) / 4);
  else page.value = Math.min(page.value, pageCount.value - 1);
  arrivalTimer = setTimeout(() => { arriving.value = []; }, 1800);
});
onUnmounted(() => clearTimeout(arrivalTimer));
</script>

<template>
  <section class="tbc-zone" :class="[`zone-${zone}`, { 'has-arrival': arriving.length, 'zone-live': live, 'zone-empty': !cards.length }]" :aria-label="`${player === 'p1' ? 'Player 1' : 'Player 2'} ${zone}`">
    <header class="tbc-zone-heading"><strong><span aria-hidden="true">{{ zone === 'bench' ? '⇄' : '◉' }}</span> {{ zone === 'bench' ? 'BENCH' : 'ACTIVE' }} <em v-if="live">LIVE</em></strong><span>{{ cards.length }}<small> / {{ capacity }}</small></span></header>
    <div v-if="cards.length" class="tbc-zone-grid" :style="{ '--zone-columns': slots.length }">
      <div v-for="(card, index) in slots" :key="cardId(card) ?? `empty-${index}`" class="tbc-zone-slot" :class="{ arriving: card && arriving.includes(String(cardId(card))), featured: card && String(cardId(card)) === String(featuredId), inspected: card && String(cardId(card)) === String(inspectedId) }" :data-card-id="cardId(card)" :data-player="player">
        <template v-if="card"><div class="tbc-zone-art"><PublicDisplayCard :card="card" compact /></div><div class="tbc-zone-caption"><span class="tbc-zone-name" :title="card.name">{{ card.name }}</span><div class="tbc-zone-stats"><span>ATK <b>{{ publicCardStats(card).attack ?? '—' }}</b></span><span>DEF <b>{{ publicCardStats(card).defense ?? '—' }}</b></span></div><small class="tbc-zone-hp">HP {{ publicCardStats(card).hp ?? '—' }} / {{ publicCardStats(card).maxHp ?? '—' }}</small></div></template>
        <div v-else class="tbc-zone-slot-empty" aria-label="Slot kosong">＋</div>
      </div>
    </div>
    <div v-else class="tbc-zone-empty"><span aria-hidden="true">{{ zone === 'bench' ? '⇄' : '◉' }}</span><strong>{{ capacity === 0 ? 'Bench tidak digunakan' : zone === 'bench' ? 'Bench kosong' : 'Active kosong' }}</strong><small v-if="capacity > 0">{{ zone === 'bench' ? 'Kartu cadangan akan tampil di sini' : 'Menunggu kartu masuk arena' }}</small></div>
    <nav v-if="pageCount > 1" class="tbc-zone-pager" :aria-label="`Halaman ${zone} ${player}`"><button type="button" :disabled="currentPage === 0" aria-label="Kartu sebelumnya" @click="page = currentPage - 1">‹</button><span>{{ currentPage + 1 }} / {{ pageCount }}</span><button type="button" :disabled="currentPage + 1 === pageCount" aria-label="Kartu berikutnya" @click="page = currentPage + 1">›</button></nav>
  </section>
</template>

<style scoped>
.tbc-zone { --zone-color:#155c86; display:grid; grid-template-rows:auto minmax(0,1fr); min-height:0; min-width:0; gap:.3cqw; padding:.4cqw; border:.08cqw solid #93c7e1; border-radius:.3cqw; background:linear-gradient(145deg,#f6fcfff5,#cfe9f4f2); position:relative; }
.zone-bench { --zone-color:#795114; border-color:#d6b76c; background:linear-gradient(145deg,#fffbecf5,#f0e0b5f2); }
.tbc-zone-heading { display:flex; justify-content:space-between; align-items:center; gap:.4cqw; color:var(--zone-color); font:800 .9cqw/1.1 Arial,sans-serif; }
.tbc-zone-heading strong { letter-spacing:.045em; white-space:nowrap; }
.tbc-zone-heading small { color:#576f7d; font-size:.65cqw; font-weight:400; }
.tbc-zone-grid { display:grid; grid-template-columns:repeat(var(--zone-columns,4),minmax(0,1fr)); grid-auto-rows:minmax(0,1fr); gap:.5cqw; min-height:0; }
.tbc-zone-slot { display:grid; grid-template-rows:minmax(0,1fr) auto; gap:.3cqw; min-height:0; min-width:0; border-radius:.2cqw; }
.tbc-zone-art { min-height:0; min-width:0; container-type:size; display:grid; place-items:center; }
.tbc-zone-art :deep(.tbc-card) { width:min(100cqw,70cqh); height:min(100cqh,142.857cqw); }
.tbc-zone-name { display:block; min-width:0; text-align:center; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:#18364f; font:800 .78cqw/1.25 Arial,sans-serif; }
.tbc-zone-caption { position:relative; min-width:0; text-align:center; }
.tbc-zone-stats { display:flex; justify-content:center; gap:.4cqw; margin-top:.15cqw; color:#365467; font:600 .61cqw/1.4 Arial,sans-serif; white-space:nowrap; }
.tbc-zone-stats b { font-size:.78cqw; color:#123d5a; }.tbc-zone-stats > span:first-child b { color:#963f24; }
.tbc-zone-hp { position:absolute; bottom:calc(100% + .4cqw); left:50%; transform:translateX(-50%); padding:.12cqw .3cqw; border-radius:.2cqw; background:#f0fff1f2; color:#19563a; font:700 .6cqw/1.2 Arial,sans-serif; white-space:nowrap; box-shadow:0 1px 3px #001b2544; }
.featured .tbc-zone-name { color:#075d88; }
.featured .tbc-zone-art :deep(.tbc-card) { box-shadow:0 0 0 2px #168abd; }
.tbc-zone-slot-empty { grid-row:1 / -1; display:grid; place-items:center; border:.08cqw dashed #6b93a66b; border-radius:.3cqw; color:#648797; background:#ffffff40; font-size:1.3cqw; }
.tbc-zone-empty { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:.4cqw; padding:.5cqw; border:.08cqw dashed #9e8b5e80; border-radius:.3cqw; text-align:center; color:#5e513b; }
.tbc-zone-empty > span { color:var(--zone-color); opacity:.65; font-size:1.5cqw; }
.tbc-zone-empty strong { font-size:.75cqw; }
.tbc-zone-empty small { font-size:.58cqw; line-height:1.4; color:#71644f; }
.tbc-zone:has(.tbc-zone-pager) { padding-bottom:1.6cqw; }
.tbc-zone-pager { position:absolute; left:0; right:0; bottom:.2cqw; display:flex; align-items:center; justify-content:center; gap:.4cqw; font-size:.6cqw; }
.tbc-zone-pager button { color:white; background:#284765; border:1px solid #728896; border-radius:.2cqw; min-width:1.3cqw; height:1.2cqw; padding:0; font-size:1cqw; cursor:pointer; }
.tbc-zone-pager button:disabled { opacity:.35; cursor:default; }
.tbc-zone-pager button:focus-visible { outline:.15cqw solid white; outline-offset:.1cqw; }
.has-arrival { border-color:var(--zone-color); }
.arriving { animation:zone-arrival 1.4s ease-out; }
@keyframes zone-arrival { 0%,40% { background:#fff3af33; box-shadow:0 0 .7cqw var(--zone-color); } 100% { background:transparent; box-shadow:none; } }
@media(prefers-reduced-motion:reduce) { .arriving { animation:none; outline:.12cqw solid var(--zone-color); } }
.tbc-zone-heading em { font:800 .5cqw/1 Arial,sans-serif; padding:.2cqw .3cqw; background:#16794d; color:white; border-radius:.2cqw; font-style:normal; vertical-align:middle; }
.zone-live { border-color:#217d9d; box-shadow:inset 0 0 0 .1cqw #217d9d; }
.inspected .tbc-zone-art :deep(.tbc-card) { box-shadow:0 0 0 .18cqw #168abd,0 0 .7cqw #168abd66; }
.zone-empty .tbc-zone-empty { border:0; flex-direction:row; padding:0; }
.zone-empty .tbc-zone-empty > span,.zone-empty .tbc-zone-empty small { display:none; }
.tbc-zone-art { max-width:9cqw; width:100%; justify-self:center; }
</style>
