<script setup>
import { computed } from 'vue';
import PublicDisplayCard from './PublicDisplayCard.vue';
import { battleCardId } from '../../utils/publicBattleActivity.js';

const props = defineProps({ activity: { type: Object, required: true } });
const visibleCards = computed(() => {
  const start = Math.max(0, Math.min(props.activity.index - 1, props.activity.cards.length - 4));
  return props.activity.cards.slice(start, start + 4).map((card, offset) => ({ card, index: start + offset }));
});
</script>

<template>
  <section class="public-live-viewer arena-frame" :class="activity.side" aria-label="Aktivitas pemain secara live">
    <header>
      <div><span class="live-label"><i/> LIVE · {{ activity.playerName }}</span><h2>{{ activity.message }}</h2></div>
      <span class="pile-count">{{ activity.cards.length }} kartu</span>
    </header>
    <div v-if="activity.card" class="viewer-content">
      <div class="inspected-card"><PublicDisplayCard :card="activity.card"/></div>
      <div class="pile-context">
        <div class="inspected-label" role="status"><small>SEDANG DILIHAT</small><strong>{{ activity.card.name }}</strong><span>Kartu {{ activity.index + 1 }} dari {{ activity.cards.length }}</span></div>
        <div class="pile-cards">
          <div v-for="entry in visibleCards" :key="battleCardId(entry.card)" class="pile-card" :class="{ 'is-inspected': entry.index === activity.index }">
            <div class="pile-card-art"><PublicDisplayCard :card="entry.card" compact/></div>
            <span>{{ entry.card.name }}</span>
          </div>
        </div>
      </div>
    </div>
    <div v-else class="empty-pile"><strong>{{ activity.zoneLabel }} kosong</strong><span>{{ activity.playerName }} sedang melihat area {{ activity.zoneLabel }}.</span></div>
    <footer>Mengikuti tampilan {{ activity.playerName }} secara langsung</footer>
  </section>
</template>

<style scoped>
.public-live-viewer { --live-accent:#167caf; position:absolute; inset:27% 24% 15%; z-index:35; display:flex; flex-direction:column; overflow:hidden; color:#173d52; background:#f4faff; border:.16cqw solid #e3c672; border-radius:.7cqw; box-shadow:0 1cqw 4cqw #00132c99; font-family:Arial,sans-serif; }
.public-live-viewer.p2 { --live-accent:#8247b3; }
header { display:flex; justify-content:space-between; align-items:center; gap:1cqw; padding:.8cqw 1.2cqw; color:white; background:#12344e; border-bottom:.1cqw solid #d6ba70; }
.live-label { display:flex; align-items:center; gap:.4cqw; color:#c6edff; font-size:.75cqw; font-weight:700; }.p2 .live-label { color:#ecd8ff; }.live-label i { width:.4cqw; height:.4cqw; border-radius:50%; background:#77e9a3; box-shadow:0 0 .4cqw #77e9a3; }
h2 { margin:.3cqw 0 0; font-size:1.5cqw; }.pile-count { font-size:.9cqw; color:#f4dfa9; white-space:nowrap; }
.viewer-content { display:grid; grid-template-columns:34% minmax(0,1fr); gap:1.5cqw; padding:1cqw 1.4cqw; min-height:0; flex:1; }
.inspected-card,.pile-card-art { container-type:size; min-height:0; min-width:0; display:grid; place-items:center; }
.inspected-card :deep(.tbc-card),.pile-card-art :deep(.tbc-card) { width:min(100cqw,70cqh); height:min(100cqh,142.857cqw); }
.pile-context { min-height:0; display:flex; flex-direction:column; gap:1cqw; }.inspected-label { display:flex; flex-direction:column; gap:.3cqw; }.inspected-label small { font-size:.65cqw; letter-spacing:.08em; color:var(--live-accent); font-weight:800; }.inspected-label strong { font-size:1.45cqw; overflow-wrap:anywhere; }.inspected-label>span { font-size:.75cqw; color:#526d7b; }
.pile-cards { min-height:0; display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:.5cqw; flex:1; }.pile-card { min-height:0; display:grid; grid-template-rows:minmax(0,1fr) auto; gap:.4cqw; padding:.3cqw; border:.12cqw solid transparent; border-radius:.3cqw; }.pile-card>span { text-align:center; font-size:.62cqw; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }.is-inspected { border-color:var(--live-accent); background:#dfedf7; }.is-inspected>span { color:var(--live-accent); font-weight:800; }
.empty-pile { flex:1; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:1cqw; }.empty-pile strong { font-size:1.5cqw; }.empty-pile span { font-size:1cqw; }
footer { padding:.5cqw 1cqw; text-align:center; background:#e3eef5; border-top:1px solid #cadce7; color:#526b7d; font-size:.7cqw; }
</style>

<style scoped>
.public-live-viewer{inset:24% 24% 14%;color:#193e6b}.public-live-viewer header{background:#edf8ff;color:#12366a;border-bottom-color:#c6e1ef}.public-live-viewer .live-label,.public-live-viewer .pile-count{color:#166da1}.public-live-viewer h2{font-weight:850}.public-live-viewer footer{background:#e9f6ff;color:#3e668c}.public-live-viewer .inspected-card :deep(.tbc-card){width:min(100cqw,67.02cqh);height:min(100cqh,149.21cqw)}
@media(max-width:700px){.public-live-viewer{inset:18% 17% 10%}}
</style>
