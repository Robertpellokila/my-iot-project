<script setup>
import { computed, inject } from 'vue';
import ArenaCardFace from './ArenaCardFace.vue';
import { battleCardId } from '../../utils/publicBattleActivity.js';
const props = defineProps({ card: { type: Object, default: null }, compact: Boolean, statuses: { type: Array, default: () => [] } });
const skillMap = inject('publicBattleSkills', null);
const skills = computed(() => skillMap?.value?.[battleCardId(props.card)] ?? []);
</script>
<template>
  <article class="tbc-card" :class="{'tbc-card-compact': compact, 'tbc-card-fallen': card?.zone === 'graveyard', 'tbc-card-empty': !card}">
    <ArenaCardFace v-if="card" :card="card" :skills="skills" :compact="compact" />
    <div v-else class="public-card-empty"><span>＋</span><strong>Belum ada kartu Active</strong><small>Menunggu Summon</small></div>
    <div v-if="!compact && statuses.length" class="tbc-card-status-labels"><span v-for="status in statuses.slice(0, 3)" :key="status.key" :title="`${status.label} ${status.valueText || ''} ${status.durationText || ''}`">{{status.icon}} {{status.label}} {{status.valueText}} {{status.durationText}}</span><span v-if="statuses.length > 3">+{{statuses.length-3}}</span></div>
    <span v-if="card?.zone === 'graveyard'" class="tbc-card-defeated">{{card.consumed_for_fusion ? 'FUSION' : 'KO'}}</span>
  </article>
</template>
<style scoped>
.tbc-card{position:relative;width:100%;height:100%;min-width:0;min-height:0;container-type:inline-size;color:#102b5c}
.tbc-card :deep(.arena-card-face){height:100%;aspect-ratio:auto}
.tbc-card-status-labels{position:absolute;left:0;right:0;bottom:-7%;display:flex;justify-content:center;gap:2%;font-size:3.1cqw;font-weight:800;white-space:nowrap}
.tbc-card-status-labels span{padding:1.4% 2.5%;border:1px solid #adcce7;border-radius:5px;background:#f4faff;box-shadow:0 2px 5px #17365a20}
.tbc-card-fallen :deep(.face-art),.tbc-card-fallen :deep(.face-printed-image){filter:grayscale(.8)}
.tbc-card-defeated{position:absolute;top:42%;left:15%;right:15%;text-align:center;background:#163255cc;color:white;border:1px solid #f0d58c;border-radius:5px;padding:4%;font-size:12cqw;font-weight:900}
.public-card-empty{height:100%;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:5%;padding:8%;text-align:center;border:2px dashed #a1d6ee;border-radius:6%;background:#effaffbd;box-shadow:inset 0 0 30px #fff9}
.public-card-empty>span{font-size:35cqw;font-weight:300;color:#2998cb}.public-card-empty strong{font-size:8cqw}.public-card-empty small{font-size:5.5cqw;color:#41658b}
</style>
