<script setup>
import { computed, reactive } from 'vue';
import { RARITIES, TYPES } from '../../lib/card-generator/cardSchema.js';
const props = defineProps({ cards: Array, selected: String, checked: Array, statuses: Object });
const emit = defineEmits(['select', 'check', 'select-visible', 'create']);
const filters = reactive({ search: '', kind: '', type: '', rarity: '', status: '', sort: 'code' });
const visible = computed(() => props.cards.filter(card => (!filters.search || `${card.card_code} ${card.name}`.toLowerCase().includes(filters.search.toLowerCase())) &&
  (!filters.kind || card.kind === filters.kind) && (!filters.type || card.type === filters.type) && (!filters.rarity || card.rarity === filters.rarity) && (!filters.status || props.statuses[card.card_code]?.status === filters.status))
  .sort((a, b) => filters.sort === 'name' ? a.name.localeCompare(b.name) : filters.sort === 'rarity' ? RARITIES.indexOf(a.rarity) - RARITIES.indexOf(b.rarity) : a.card_code.localeCompare(b.card_code)));
</script>
<template>
  <aside class="cg-library">
    <div class="cg-panel-heading"><h2>Card library</h2><span>{{ visible.length }} / {{ cards.length }}</span></div>
    <button type="button" class="cg-create-card" @click="emit('create')">＋ Buat kartu</button>
    <label class="cg-search"><span class="cg-sr">Cari kartu</span><input v-model="filters.search" type="search" placeholder="Cari ID atau nama…" /></label>
    <div class="cg-library-filters">
      <select v-model="filters.kind" aria-label="Jenis kartu"><option value="">Base + Fusion</option><option value="base">Base cards</option><option value="fusion">Fusion cards</option></select>
      <select v-model="filters.type" aria-label="Type"><option value="">Semua Type</option><option v-for="type in TYPES" :key="type">{{ type }}</option></select>
      <select v-model="filters.rarity" aria-label="Rarity"><option value="">Semua rarity</option><option v-for="rarity in RARITIES" :key="rarity">{{ rarity }}</option></select>
      <select v-model="filters.status" aria-label="Status artwork"><option value="">Semua status</option><option v-for="status in ['Artwork Missing','Artwork Draft','Artwork Approved','Ready for Print','Validation Error']" :key="status">{{ status }}</option></select>
    </div>
    <div class="cg-library-sort"><button type="button" @click="emit('select-visible', visible.map(card => card.card_code))">Pilih hasil</button><select v-model="filters.sort" aria-label="Urutkan"><option value="code">Urut ID</option><option value="name">Urut nama</option><option value="rarity">Urut rarity</option></select></div>
    <div class="cg-card-list">
      <div v-for="card in visible" :key="card.card_code" class="cg-library-row" :class="{ active: selected === card.card_code }">
        <input type="checkbox" :checked="checked.includes(card.card_code)" :aria-label="`Pilih ${card.card_code} untuk ekspor`" @change="emit('check', card.card_code)" />
        <button type="button" @click="emit('select', card.card_code)"><small>{{ card.is_custom ? card.display_code || card.card_code : card.card_code }} <i v-if="card.is_custom">CUSTOM</i><i v-else-if="card.kind === 'fusion'">FUSION</i></small><strong>{{ card.name }}</strong><span><i class="cg-state-dot" :class="{ ready: statuses[card.card_code]?.ready, draft: statuses[card.card_code]?.status === 'Artwork Draft' }"></i>{{ statuses[card.card_code]?.status }}</span></button>
      </div>
      <p v-if="!visible.length" class="cg-empty">Tidak ada kartu yang cocok. Ubah pencarian atau filter.</p>
    </div>
  </aside>
</template>
