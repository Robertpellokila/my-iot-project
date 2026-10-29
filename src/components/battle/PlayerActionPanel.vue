<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import BattleActionIcon from './BattleActionIcon.vue';
import BattleActionArtwork from './BattleActionArtwork.vue';

const props = defineProps({
  context: { type: Object, required: true },
  actions: { type: Array, required: true },
  review: { type: Object, default: null },
  busy: Boolean,
});
const emit = defineEmits(['choose', 'confirm', 'cancel', 'cancel-summon', 'inspect-skill']);
const drawer = ref(null);
const confirmation = ref(null);
const drawerOpen = ref(false);
const inspected = ref(null);
const panel = ref(null);
const primary = computed(() => props.actions.filter(action => action.primary));
const additional = computed(() => props.actions.filter(action => !action.primary && action.key !== 'end_turn'));
const endTurn = computed(() => props.actions.find(action => action.key === 'end_turn'));
let sizeObserver;
const readyNotice = ref(null);
const announced = new Set();
let noticeTimer;
const readyKeys = computed(() => props.actions.filter(a => a.ready).map(a => a.key).join(','));
watch([() => props.context.scope, readyKeys, () => props.context.interrupted, () => props.busy], () => {
  clearTimeout(noticeTimer); readyNotice.value = null;
  if (props.busy || props.context.interrupted || props.context.scanning) return;
  const candidate = ['special','ultimate','fusion','combo','heal','synergy'].map(key => props.actions.find(a => a.key === key && a.ready)).find(a => a && !announced.has(`${props.context.scope}:${a.key}`));
  if (!candidate) return;
  announced.add(`${props.context.scope}:${candidate.key}`);
  if (announced.size > 100) announced.delete(announced.values().next().value);
  readyNotice.value = { key: candidate.primary ? candidate.key : 'more', text: candidate.readyHint || `${candidate.label} siap!` };
  noticeTimer = setTimeout(() => { readyNotice.value = null; }, 6000);
}, { immediate: true });

function choose(action) {
  if (props.busy || !action.ready) return;
  readyNotice.value = null;
  drawerOpen.value = false;
  // Close the native dialog before opening an existing battle picker.
  drawer.value?.close();
  emit('choose', action.key);
}
const inspection = computed(() => props.actions.find(action => action.key === inspected.value));
function inspect(action) {
  readyNotice.value = null;
  if (action.key === 'special' && action.inspectSkills) { emit('inspect-skill'); return; }
  inspected.value = action.key; drawerOpen.value = true;
}
function openMore() { inspected.value = null; drawerOpen.value = true; }
function closeDrawer() { drawerOpen.value = false; }
watch(drawerOpen, async open => {
  await nextTick();
  if (open && !drawer.value?.open) drawer.value?.showModal();
  else if (!open) drawer.value?.close();
});
watch(() => props.review, async review => {
  await nextTick();
  if (review && !confirmation.value?.open) confirmation.value?.showModal();
  else if (!review) confirmation.value?.close();
});
watch(() => props.context.scope, closeDrawer);
watch(() => props.context.interrupted, interrupted => { if (interrupted) closeDrawer(); });
watch(panel, element => {
  sizeObserver?.disconnect();
  if (!element) return;
  sizeObserver = new ResizeObserver(([entry]) => {
    element.closest('.player-battle-ui')?.style.setProperty('--action-panel-height', `${entry.borderBoxSize?.[0]?.blockSize ?? element.offsetHeight}px`);
  });
  sizeObserver.observe(element);
});
onBeforeUnmount(() => { sizeObserver?.disconnect(); clearTimeout(noticeTimer); });
</script>

<template>
  <footer ref="panel" class="player-action-panel arena-action-panel" aria-label="Panel aksi battle" :aria-busy="busy">
    <div class="command-context">
      <div class="command-card" aria-live="polite" aria-atomic="true">
        <img v-if="context.card?.image_url" :src="context.card.image_url" alt="" />
        <span v-else class="command-card-symbol" aria-hidden="true">◉</span>
        <div><strong>{{ context.card?.name || (context.scanning ? 'Menunggu scan RFID' : 'Pilih kartu Active') }}</strong><span>{{ context.hint }}</span></div>
      </div>
      <div class="command-budget">
        <span v-if="context.apEnabled" class="command-ap"><b>{{ context.ap }}</b> / {{ context.maxAp }} AP</span>
        <span v-if="context.seconds !== null" class="command-clock" :class="{ urgent: context.seconds <= 10 }">◷ {{ context.seconds }} dtk</span>
        <span v-if="!context.myTurn" class="command-turn">Giliran lawan</span>
      </div>
    </div>

    <div v-if="context.scanning" class="command-scan" role="status">
      <span aria-hidden="true">📡</span><div><strong>Tempelkan kartu ke pembaca RFID-mu</strong><p>Kartu terdaftar akan masuk ke Active. Salah menekan? Batalkan sebelum kartu terbaca.</p><small v-if="!context.canCancelSummon">{{ context.cancelSummonHint }}</small></div>
      <button type="button" class="command-secondary command-cancel-summon" :disabled="busy || !context.canCancelSummon" @click="emit('cancel-summon')">{{ busy ? 'Memproses…' : 'Batal Summon' }}</button>
    </div>
    <div v-else class="command-row">
      <div class="command-primary">
        <div v-for="action in primary" :key="action.key" class="command-slot" :data-tone="action.key">
        <span v-if="readyNotice?.key === action.key" class="command-ready-bubble" role="status"><BattleActionIcon name="check" /> {{ readyNotice.text }}</span>
        <button type="button" class="command-button" :class="[action.key, { locked: !action.ready, available: action.ready }]" :data-action="action.key" :aria-disabled="!action.ready || busy" :disabled="busy || !action.ready" :title="action.reason || action.description" @click="choose(action)">
          <BattleActionArtwork :action="action.key" />
          <span v-if="context.apEnabled && action.key!=='special'" class="arena-action-cost">{{action.costLabel}}</span>
          <span class="command-button-top"><span class="command-icon"><BattleActionIcon :name="action.key" /></span><span v-if="action.ready && !busy" class="command-status"><BattleActionIcon name="check" /> Siap</span></span>
          <strong>{{ action.label }}</strong><small><BattleActionIcon v-if="!action.ready" name="lock" />{{ action.ready ? action.costLabel : action.shortReason }}</small>
        </button>
        <button v-if="!action.ready && !busy" type="button" class="command-help" :aria-label="action.inspectSkills ? 'Lihat informasi skill' : `Mengapa ${action.label} belum tersedia?`" :title="action.reason" @click="inspect(action)"><BattleActionIcon name="info" /></button>
        </div>
        <div class="command-slot" data-tone="more">
          <span v-if="readyNotice?.key === 'more'" class="command-ready-bubble" role="status"><BattleActionIcon name="check" /> {{ readyNotice.text }}</span>
          <button type="button" class="command-button more" :class="{ available: additional.some(action => action.ready) }" aria-haspopup="dialog" :aria-expanded="drawerOpen && !inspected" :disabled="busy" @click="openMore"><BattleActionArtwork action="more" /><span class="command-button-top"><span class="command-icon"><BattleActionIcon name="more" /></span><span v-if="additional.some(action => action.ready) && !busy" class="command-status">{{ additional.filter(action => action.ready).length }} siap</span></span><strong>Aksi lainnya</strong><small>Lihat semua aksi</small></button>
        </div>
      </div>
      <button v-if="endTurn" type="button" class="command-end" :class="{ available: endTurn.ready }" data-tone="end_turn" data-action="end_turn" :aria-disabled="!endTurn.ready || busy" :disabled="busy || !endTurn.ready" :title="endTurn.reason" @click="choose(endTurn)"><BattleActionArtwork action="end_turn" /><span class="command-icon"><BattleActionIcon name="end_turn" /></span><strong>Akhiri giliran</strong><small>{{ endTurn.ready ? `${context.ap} AP tersisa` : endTurn.shortReason }}</small></button>
    </div>
    <p v-if="busy" class="command-processing" role="status">Memproses aksi… Tunggu hasilnya sebelum memilih langkah berikutnya.</p>
  </footer>

  <Teleport to="body">
    <dialog ref="drawer" class="battle-command-dialog arena-command-dialog arena-frame" aria-labelledby="command-drawer-title" @cancel="closeDrawer" @close="drawerOpen = false" @click="event => { if (event.target === drawer) closeDrawer(); }">
      <header><div><span class="command-eyebrow">{{ context.card?.name || 'PANEL AKSI' }}</span><h2 id="command-drawer-title">{{ inspection ? inspection.label : 'Aksi lainnya' }}</h2></div><button type="button" class="command-close" aria-label="Tutup aksi lainnya" @click="closeDrawer">✕</button></header>
      <template v-if="inspection">
        <p class="command-inspect-reason" role="status">{{ inspection.reason }}</p><p class="command-description">{{ inspection.description }}</p><button type="button" class="command-secondary" @click="inspected = null">Lihat aksi lainnya</button>
      </template>
      <template v-else>
        <p class="command-description">Pilih aksi sesuai rencanamu. Tanda hijau berarti siap; aksi yang redup menampilkan syarat yang belum terpenuhi.</p>
        <details v-if="context.pilotRules" class="command-pilot-rules">
          <summary>Aturan giliran, Bench, dan Fusion</summary>
          <ul>
            <li>Setiap kartu punya 1 kesempatan serang per giliran: Attack, skill damage, Combo, Ultimate, atau Synergy damage. Semua peserta Combo memakai jatahnya; Synergy memakai jatah kartu sumber.</li>
            <li>Setelah menyerang atau memberi debuff, kartu tetap di Active hingga giliranmu berikutnya. Skill Switch dari teman juga tidak dapat memindahkannya. Heal dan Shield tetap boleh digunakan.</li>
            <li>Bahan Fusion belum boleh melakukan aksi ofensif pada giliran ini. Maksimal 1 Fusion di Active. Fusion baru menunggu giliranmu berikutnya untuk menyerang atau memberi debuff; skill bantuan boleh langsung digunakan.</li>
            <li>Pindah zona tidak mereset cooldown, jatah skill, atau status. Bahan Fusion yang dikonsumsi tidak bisa dibangkitkan. Kartu yang dibangkitkan menunggu giliranmu berikutnya untuk Attack/Skill.</li>
            <li>HP pemain dan HP kartu berbeda. Pada batas {{ context.roundLimit }} ronde, HP pemain yang lebih tinggi menang; HP sama berarti seri.</li>
          </ul>
        </details>
        <div class="command-extra-grid">
          <button v-for="action in additional" :key="action.key" type="button" class="command-extra" :class="{ locked: !action.ready, available: action.ready }" :data-tone="action.key" :data-action="action.key" :aria-disabled="!action.ready" :disabled="busy || !action.ready" @click="choose(action)">
            <BattleActionArtwork :action="action.key" /><span class="command-icon"><BattleActionIcon :name="action.key" /></span><span class="command-extra-heading"><strong>{{ action.label }}</strong><b>{{ action.costLabel }}</b></span><p>{{ action.description }}</p><small :class="{ 'command-extra-ready': action.ready }"><BattleActionIcon :name="action.ready ? 'check' : 'lock'" />{{ action.ready ? 'Siap digunakan' : action.reason }}</small>
          </button>
        </div>
      </template>
    </dialog>

    <dialog ref="confirmation" class="battle-command-dialog command-review-dialog arena-frame" aria-labelledby="command-review-title" @cancel="event => { event.preventDefault(); if (!busy) emit('cancel'); }" @click="event => { if (event.target === confirmation && !busy) emit('cancel'); }">
      <template v-if="review">
        <header><div><span class="command-eyebrow">PERIKSA SEBELUM MELANJUTKAN</span><h2 id="command-review-title">{{ review.title }}</h2></div><button type="button" class="command-close" aria-label="Tutup konfirmasi" :disabled="busy" @click="emit('cancel')">✕</button></header>
        <p class="command-description">{{ review.description }}</p>
        <dl class="command-review-facts"><template v-for="fact in review.facts" :key="fact.label"><dt>{{ fact.label }}</dt><dd>{{ fact.value }}</dd></template></dl>
        <p v-if="review.warning" class="command-review-warning">{{ review.warning }}</p>
        <p v-if="review.reason" class="command-inspect-reason" role="status">{{ review.reason }}</p>
        <footer class="command-review-actions"><button type="button" class="command-secondary" :disabled="busy" autofocus @click="emit('cancel')">Batal</button><button type="button" class="command-confirm" :disabled="busy || !review.ready" @click="emit('confirm')">{{ busy ? 'Memproses…' : review.confirmLabel }}</button></footer>
      </template>
    </dialog>
  </Teleport>
</template>

<style scoped>

.player-action-panel, .battle-command-dialog {
  --command-ink: #203d36;
  --command-line: #dbe6df;
  font-family: Inter, Arial, sans-serif;
  color: var(--command-ink);
  box-sizing: border-box;
}
.player-action-panel *, .battle-command-dialog * { box-sizing: border-box; }
.command-pilot-rules { margin: 0 0 16px; padding: 12px 16px; border: 1px solid #b6d4ef; border-radius: 12px; background: #f1f7ff; color: #173c68; font-size: 14px; line-height: 1.6; }
.command-pilot-rules summary { cursor: pointer; font-weight: 700; }
.command-pilot-rules ul { padding-left: 20px; margin: 10px 0 0; }
.command-pilot-rules li + li { margin-top: 8px; }
[data-tone] {
  --action-color: #32626b;
  --action-wash: #f0f9f8;
  --action-tile: #d9efec;
  --action-border: #bfded8;
}
[data-tone="summon"] { --action-color: #245fc4; --action-wash: #f0f6ff; --action-tile: #dce9ff; --action-border: #c4d7f5; }
[data-tone="attack"], [data-tone="combo"] { --action-color: #b44036; --action-wash: #fff4f1; --action-tile: #ffe0d8; --action-border: #edc6bd; }
[data-tone="special"], [data-tone="fusion"] { --action-color: #7046bc; --action-wash: #f6f1ff; --action-tile: #e9dcff; --action-border: #d9c8f1; }
[data-tone="more"], [data-tone="synergy"] { --action-color: #16746f; --action-wash: #eefaf7; --action-tile: #d3eee7; --action-border: #bce0d7; }
[data-tone="end_turn"], [data-tone="ultimate"] { --action-color: #94631d; --action-wash: #fff9ee; --action-tile: #f9e8c5; --action-border: #e8d6b1; }
[data-tone="heal"], [data-tone="defense"] { --action-color: #237447; --action-wash: #f0f9f1; --action-tile: #d9eedb; --action-border: #c0ddc4; }
.player-action-panel {
  position: fixed; z-index: 150; left: 50%; bottom: max(12px, env(safe-area-inset-bottom)); transform: translateX(-50%);
  width: min(1080px, calc(100% - 32px)); padding: 14px 16px;
  border: 1px solid var(--command-line); border-radius: 22px;
  background: #fffffff7; box-shadow: 0 8px 36px #21453420;
}
.command-context { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 0 2px 12px; margin-bottom: 12px; border-bottom: 1px solid #e8eee9; }
.command-card { display: flex; align-items: center; gap: 10px; min-width: 0; }
.command-card img, .command-card-symbol { width: 38px; height: 42px; object-fit: contain; background: #eef5e8; border-radius: 9px; flex: none; }
.command-card-symbol { display: grid; place-items: center; color: #69966e; font-size: 23px; }
.command-card > div { min-width: 0; }
.command-card strong { display: block; font-size: 14px; white-space: nowrap; text-overflow: ellipsis; overflow: hidden; }
.command-card div > span { display: block; font-size: 11px; color: #627a6a; margin-top: 5px; line-height: 1.5; }
.command-budget { display: flex; align-items: center; justify-content: end; gap: 10px; flex: none; flex-wrap: wrap; }
.command-ap { font-size: 11px; white-space: nowrap; padding: 7px 10px; background: #eaf4e4; border-radius: 8px; }
.command-ap b { font-size: 21px; margin-right: 3px; }
.command-clock { font-size: 12px; white-space: nowrap; color: #507057; }
.command-clock.urgent { color: #ad342c; font-weight: 800; }
.command-turn { font-size: 10px; color: #7b6744; }
.command-row { display: grid; grid-template-columns: minmax(0, 1fr) 140px; gap: 18px; }
.command-primary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
.command-slot { position: relative; display: flex; min-width: 0; }
.command-slot > .command-button { width: 100%; }
.command-button {
  display: flex; flex-direction: column; align-items: stretch; justify-content: center; gap: 4px;
  min-height: 106px; min-width: 0; padding: 12px 14px; text-align: left;
  border: 1px solid var(--action-border); border-radius: 14px;
  background: var(--action-wash); color: var(--action-color);
  box-shadow: inset 0 3px var(--action-color);
  transition: background .15s ease, box-shadow .15s ease, transform .15s ease;
}
.command-button-top { display: flex; align-items: center; justify-content: space-between; gap: 6px; margin-bottom: 3px; min-width: 0; }
.command-icon { display: grid; place-items: center; flex: none; width: 34px; height: 34px; border-radius: 10px; background: var(--action-tile); color: var(--action-color); }
.command-icon svg { display: block; width: 23px; height: 23px; }
.command-button strong { font-size: 13px; line-height: 1.35; font-weight: 750; }
.command-button small { display: flex; align-items: center; gap: 4px; font-size: 10px; line-height: 1.5; color: #5b6c69; }
.command-button small svg { width: 11px; height: 11px; flex: none; }
.command-status { display: inline-flex; align-items: center; justify-content: center; gap: 3px; padding: 3px 7px; border: 1px solid #b8ddc1; border-radius: 20px; background: #e3f5e7; color: #22643b; font-size: 9px; font-weight: 750; line-height: 1.2; white-space: nowrap; }
.command-status svg { width: 11px; height: 11px; stroke-width: 2.5; }
.command-button.locked { background: #fafbfc; box-shadow: inset 0 3px var(--action-border); }
.command-button.locked strong { color: #5d6772; }
.command-button.locked small { color: #65707a; }
.command-button.locked .command-icon { background: var(--action-wash); }
.command-help { position: absolute; top: 12px; right: 9px; display: grid; place-items: center; width: 28px; height: 28px; padding: 5px; border: 0; border-radius: 8px; background: transparent; color: var(--action-color); }
.command-help:hover { background: var(--action-tile); }
.command-help svg { width: 17px; height: 17px; }
.command-end { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 5px; padding: 10px; border: 1px solid var(--action-border); border-radius: 14px; background: var(--action-wash); color: var(--action-color); }
.command-end .command-icon { background: transparent; }
.command-end strong { font-size: 12px; }
.command-end small { font-size: 10px; line-height: 1.5; }
.command-end:disabled { background: #fafbfc; color: #66717b; border-color: #dce3e7; }
.command-end:disabled .command-icon { color: #8c969e; }
.command-ready-bubble { position: absolute; z-index: 3; bottom: calc(100% + 10px); left: 50%; transform: translateX(-50%); display: flex; align-items: center; gap: 6px; max-width: 245px; width: max-content; padding: 9px 13px; border: 1px solid #b4d9bf; border-radius: 12px; background: #f0fff4; color: #22643b; box-shadow: 0 4px 15px #153c2d20; font-size: 12px; font-weight: 750; line-height: 1.45; pointer-events: none; animation: ready-appear .2s ease-out; }
.command-ready-bubble svg { width: 16px; height: 16px; flex: none; }
.command-ready-bubble::after { content: ''; position: absolute; top: 100%; left: 50%; width: 9px; height: 9px; background: #f0fff4; border-right: 1px solid #b4d9bf; border-bottom: 1px solid #b4d9bf; transform: translate(-50%, -4px) rotate(45deg); }
@keyframes ready-appear { from { opacity: 0; translate: 0 4px; } to { opacity: 1; translate: 0 0; } }
.command-scan { display: flex; align-items: center; gap: 14px; padding: 6px 4px; }
.command-scan > span { font-size: 28px; }
.command-scan > div { min-width: 0; flex: 1; }
.command-scan strong { font-size: 14px; }
.command-scan p { font-size: 12px; line-height: 1.6; margin: 6px 0 0; color: #627a6a; }
.command-scan small { display: block; margin-top: 7px; font-size: 11px; line-height: 1.6; color: #8c642f; }
.command-cancel-summon { flex: none; }
.command-processing { margin: 10px 0 0; font-size: 11px; color: #477352; }
.battle-command-dialog { position: fixed; inset: 0; margin: auto; width: min(820px, calc(100% - 32px)); max-height: 85dvh; overflow: auto; padding: 26px; border: 1px solid var(--command-line); border-radius: 20px; background: #fff; box-shadow: 0 24px 80px #15382e3b; overscroll-behavior: contain; }
.battle-command-dialog::backdrop { background: #19382b70; backdrop-filter: blur(3px); }
.battle-command-dialog:not([open]) { display: none; }
.battle-command-dialog header { display: flex; justify-content: space-between; align-items: start; gap: 20px; }
.command-eyebrow { font-size: 10px; font-weight: 800; letter-spacing: .12em; color: #55835c; }
.battle-command-dialog h2 { font-size: 27px; letter-spacing: -.8px; margin: 9px 0 0; line-height: 1.25; }
.command-close { width: 40px; height: 40px; flex: none; border: 1px solid var(--command-line); border-radius: 9px; background: #f5f8f2; color: var(--command-ink); }
.command-description { font-size: 13px; line-height: 1.8; color: #627a6a; margin: 16px 0 22px; }
.command-extra-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.command-extra { display: grid; grid-template-columns: 38px minmax(0, 1fr); align-content: start; gap: 10px 12px; text-align: left; min-width: 0; padding: 18px; border: 1px solid var(--action-border); border-radius: 14px; background: var(--action-wash); color: var(--action-color); }
.command-extra .command-icon { width: 38px; height: 38px; }
.command-extra-heading { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.command-extra-heading strong { font-size: 15px; }
.command-extra-heading b { padding: 4px 7px; border-radius: 6px; background: #ffffffb3; font-size: 10px; font-weight: 700; white-space: nowrap; }
.command-extra p, .command-extra small { grid-column: 1 / -1; margin: 0; font-size: 12px; line-height: 1.7; }
.command-extra p { color: #5c6b68; }
.command-extra small { display: flex; align-items: start; gap: 6px; padding-top: 10px; border-top: 1px solid var(--action-border); color: #626e75; }
.command-extra small svg { flex: none; width: 14px; height: 14px; margin-top: 3px; }
.command-extra .command-extra-ready { color: #22643b; font-weight: 750; }
.command-extra-ready svg { background: #d6efdd; border-radius: 50%; }
.command-extra.locked { background: #fafbfc; color: #606c77; }
.command-extra.locked .command-icon { background: var(--action-wash); }
.command-inspect-reason, .command-review-warning { border-left: 3px solid #cc9d3a; background: #fff6df; padding: 14px 16px; line-height: 1.8; font-size: 13px; margin: 22px 0; }
.command-review-dialog { width: min(540px, calc(100% - 32px)); }
.command-review-facts { display: grid; grid-template-columns: auto minmax(0, 1fr); margin: 18px 0; gap: 12px 20px; background: #f1f7ea; border: 1px solid #dce8d1; border-radius: 12px; padding: 18px; font-size: 13px; }
.command-review-facts dt { color: #688269; }
.command-review-facts dd { margin: 0; text-align: right; font-weight: 700; overflow-wrap: anywhere; }
.command-review-actions { display: flex; gap: 10px; justify-content: end; margin-top: 24px; }
.command-secondary, .command-confirm { padding: 12px 18px; border-radius: 9px; font-size: 13px; font-weight: 700; border: 1px solid #cbdcc9; background: #fff; color: #2c5f3d; min-height: 44px; }
.command-confirm { background: #176e44; border-color: #176e44; color: #fff; }
.player-action-panel button, .battle-command-dialog button { font-family: inherit; cursor: pointer; }
.player-action-panel button:disabled, .battle-command-dialog button:disabled { cursor: not-allowed; opacity: 1; }
.player-action-panel[aria-busy="true"] .command-button { opacity: .65; }
.player-action-panel button:focus-visible, .battle-command-dialog button:focus-visible { outline: 2px solid var(--action-color, #27889a); outline-offset: 3px; }
.command-button:hover:not(:disabled), .command-extra:hover:not(:disabled), .command-end:hover:not(:disabled) { border-color: var(--action-color); box-shadow: inset 0 3px var(--action-color), 0 3px 10px #1b31490d; }
.command-button:active:not(:disabled) { transform: translateY(1px); }
@media (max-width: 760px) {
  .player-action-panel { width: calc(100% - 16px); padding: 10px; bottom: max(8px, env(safe-area-inset-bottom)); border-radius: 17px; }
  .command-context { align-items: start; gap: 8px; margin-bottom: 9px; padding: 0 0 9px; }
  .command-card { gap: 7px; }
  .command-card img, .command-card-symbol { width: 29px; height: 34px; }
  .command-card strong { font-size: 12px; }
  .command-card div > span { font-size: 10px; max-width: 210px; }
  .command-budget { gap: 5px; max-width: 104px; }
  .command-ap { padding: 4px 7px; font-size: 10px; }
  .command-ap b { font-size: 17px; }
  .command-clock { font-size: 10px; }
  .command-turn { font-size: 9px; }
  .command-row { grid-template-columns: 1fr; gap: 8px; }
  .command-primary { gap: 6px; }
  .command-button { min-height: 94px; padding: 9px 7px 8px; gap: 3px; border-radius: 11px; }
  .command-button-top { gap: 3px; margin-bottom: 2px; }
  .command-icon { width: 26px; height: 28px; border-radius: 7px; }
  .command-icon svg { width: 19px; height: 19px; }
  .command-status { font-size: 8px; padding: 3px 4px; }
  .command-status svg { display: none; }
  .command-button strong { font-size: 10px; }
  .command-button small { font-size: 9px; gap: 3px; }
  .command-button small svg { display: none; }
  .command-help { width: 25px; height: 28px; right: 3px; top: 9px; padding: 5px; }
  .command-help svg { width: 14px; height: 14px; }
  .command-end { justify-self: end; flex-direction: row; gap: 7px; min-height: 32px; border-radius: 8px; padding: 5px 9px; }
  .command-end .command-icon { width: 16px; height: 18px; }
  .command-end .command-icon svg { width: 16px; height: 16px; }
  .command-end strong, .command-end small { font-size: 10px; }
  .command-ready-bubble { font-size: 11px; max-width: min(190px, 50vw); padding: 8px 10px; }
  .command-slot:last-child .command-ready-bubble { left: auto; right: 0; transform: none; }
  .command-slot:last-child .command-ready-bubble::after { left: auto; right: 25px; }
  .battle-command-dialog { inset: auto 0 0; width: 100%; max-height: 88dvh; border-radius: 20px 20px 0 0; padding: 22px 18px max(22px, env(safe-area-inset-bottom)); }
  .battle-command-dialog h2 { font-size: 25px; }
  .command-extra-grid { grid-template-columns: 1fr; }
  .command-extra { padding: 15px; }
  .command-extra-heading strong { font-size: 14px; }
  .command-review-actions > * { flex: 1; }
  .command-scan { flex-wrap: wrap; }
  .command-scan > div { flex-basis: calc(100% - 54px); }
  .command-scan strong { font-size: 12px; }
  .command-scan p { font-size: 11px; }
  .command-cancel-summon { margin-left: 42px; width: calc(100% - 42px); }
}
@media (prefers-reduced-motion: reduce) {
  .command-ready-bubble { animation: none; }
  .command-button { transition: none; }
}
</style>

<style src="./arena-actions.css" scoped></style>
