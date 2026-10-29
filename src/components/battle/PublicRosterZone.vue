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
const zoneLabel = computed(() => ({active:'ACTIVE',bench:'BENCH',graveyard:'GRAVEYARD'}[props.zone] ?? props.zone));
const zoneIcon = computed(() => ({active:'◉',bench:'⇄',graveyard:'◇'}[props.zone] ?? '◉'));
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
    <header class="tbc-zone-heading"><strong><span aria-hidden="true">{{zoneIcon}}</span> {{zoneLabel}} <em v-if="live">LIVE</em></strong><span>{{ cards.length }}<small v-if="zone !== 'graveyard'"> / {{ capacity }}</small></span></header>
    <div v-if="cards.length" class="tbc-zone-grid" :style="{ '--zone-columns': slots.length }">
      <div v-for="(card, index) in slots" :key="cardId(card) ?? `empty-${index}`" class="tbc-zone-slot" :class="{ arriving: card && arriving.includes(String(cardId(card))), featured: card && String(cardId(card)) === String(featuredId), inspected: card && String(cardId(card)) === String(inspectedId) }" :data-card-id="cardId(card)" :data-player="player">
        <template v-if="card"><div class="tbc-zone-art"><PublicDisplayCard :card="card" compact /></div><div class="tbc-zone-caption"><span class="tbc-zone-name" :title="card.name">{{ card.name }}</span><div class="tbc-zone-stats"><span>ATK <b>{{ publicCardStats(card).attack ?? '—' }}</b></span><span>DEF <b>{{ publicCardStats(card).defense ?? '—' }}</b></span></div><small class="tbc-zone-hp">HP {{ publicCardStats(card).hp ?? '—' }} / {{ publicCardStats(card).maxHp ?? '—' }}</small></div></template>
        <div v-else class="tbc-zone-slot-empty" aria-label="Slot kosong">＋</div>
      </div>
    </div>
    <div v-else class="tbc-zone-empty"><span aria-hidden="true">{{zoneIcon}}</span><strong>{{ zone === 'graveyard' ? 'Graveyard kosong' : capacity === 0 ? 'Bench tidak digunakan' : zone === 'bench' ? 'Bench kosong' : 'Menunggu Summon' }}</strong><small v-if="capacity > 0">{{ zone === 'bench' ? 'Kartu cadangan akan tampil di sini' : 'Menunggu kartu masuk arena' }}</small></div>
    <nav v-if="pageCount > 1" class="tbc-zone-pager" :aria-label="`Halaman ${zone} ${player}`"><button type="button" :disabled="currentPage === 0" aria-label="Kartu sebelumnya" @click="page = currentPage - 1">‹</button><span>{{ currentPage + 1 }} / {{ pageCount }}</span><button type="button" :disabled="currentPage + 1 === pageCount" aria-label="Kartu berikutnya" @click="page = currentPage + 1">›</button></nav>
  </section>
</template>

<style scoped>
.tbc-zone{--zone-color:#0a6dad;position:relative;display:grid;grid-template-rows:auto minmax(0,1fr);min-width:0;min-height:0;gap:.3cqw;padding:.45cqw;border:1px solid #c4e2f4;border-radius:.65cqw;background:linear-gradient(135deg,#ffffffd9,#e9f7ffd9);color:#173b68}
.zone-bench{--zone-color:#237b87}.zone-graveyard{--zone-color:#7545be;background:linear-gradient(135deg,#fff,#f1edffd9)}
.tbc-zone-heading{display:flex;align-items:center;justify-content:space-between;gap:.25cqw;color:var(--zone-color);font-size:.72cqw;line-height:1.2;font-weight:900;white-space:nowrap}.tbc-zone-heading strong{letter-spacing:-.015em}.tbc-zone-heading strong>span{display:none}.tbc-zone-heading small{font-size:.6cqw;color:#4c6c8a}.tbc-zone-heading em{font-size:.4cqw;vertical-align:middle;border-radius:3px;background:#158453;padding:.15cqw .25cqw;color:white;font-style:normal}
.tbc-zone-grid{min-width:0;min-height:0;display:grid;grid-template-columns:repeat(var(--zone-columns,4),minmax(0,1fr));gap:.4cqw;justify-content:center}
.tbc-zone-slot{min-width:0;min-height:0;display:grid;grid-template-rows:minmax(0,1fr) auto;gap:.2cqw;border-radius:.35cqw}
.tbc-zone-art{width:100%;max-width:5cqw;justify-self:center;min-height:0;container-type:size;display:grid;place-items:center}.tbc-zone-art :deep(.tbc-card){width:min(100cqw,71.59cqh);height:min(100cqh,139.68cqw)}
.tbc-zone-caption{min-width:0;text-align:center}.tbc-zone-name{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:.55cqw;font-weight:750;color:#28547d}.tbc-zone-hp{display:block;font-size:.48cqw;color:#246e53;line-height:1.3}.tbc-zone-stats{display:none}
.featured .tbc-zone-art :deep(.arena-card-face){box-shadow:0 0 0 2px #e8b73f,0 0 7px #f2ca6e}.inspected .tbc-zone-art :deep(.arena-card-face){box-shadow:0 0 0 2px #0788cb,0 0 9px #43caff}.zone-live{border-color:#24a7da;background:#e7f9ff}
.tbc-zone-empty{display:grid;place-content:center;text-align:center;border:1px dashed #bed4e4;border-radius:.5cqw;color:#60839e;font-size:.6cqw}.tbc-zone-empty>span,.tbc-zone-empty small{display:none}.tbc-zone-empty strong{font-weight:600}
.tbc-zone:has(.tbc-zone-pager){padding-bottom:1.5cqw}.tbc-zone-pager{position:absolute;inset:auto .3cqw .2cqw;display:flex;align-items:center;justify-content:center;gap:.6cqw;font-size:.55cqw}.tbc-zone-pager button{border:1px solid #a9cde2;background:white;color:#176699;border-radius:.25cqw;padding:0;min-width:1.4cqw;height:1.15cqw;font-size:1cqw;line-height:1;cursor:pointer}.tbc-zone-pager button:disabled{opacity:.35;cursor:default}.tbc-zone-pager button:focus-visible{outline:2px solid #126fa9;outline-offset:2px}
.arriving{animation:zone-arrival 1.4s ease-out}@keyframes zone-arrival{0%,40%{box-shadow:0 0 .7cqw #ecc75c;background:#fff1b6}100%{box-shadow:none;background:none}}:is(.zone-bench,.zone-graveyard) .tbc-zone-grid{display:flex;justify-content:center;gap:0;padding-top:.25cqw}:is(.zone-bench,.zone-graveyard) .tbc-zone-slot{width:min(40%,5cqw);flex:0 1 min(40%,5cqw);position:relative}:is(.zone-bench,.zone-graveyard) .tbc-zone-slot+.tbc-zone-slot{margin-left:max(-20%,-2.5cqw)}:is(.zone-bench,.zone-graveyard) .tbc-zone-slot:not(:last-child) .tbc-zone-caption{visibility:hidden}:is(.zone-bench,.zone-graveyard) .tbc-zone-slot:not(:last-child) .tbc-zone-art{transform:rotate(-5deg);transform-origin:50% 90%}:is(.zone-bench,.zone-graveyard) .tbc-zone-slot.inspected{z-index:3}.inspected .tbc-zone-caption{visibility:visible!important}
@media(prefers-reduced-motion:reduce){.arriving{animation:none}}
</style>
