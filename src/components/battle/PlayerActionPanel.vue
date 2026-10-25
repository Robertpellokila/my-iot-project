<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import SkillIcon from './SkillIcon.vue';

const props = defineProps({
  context: { type: Object, required: true },
  actions: { type: Array, required: true },
  review: { type: Object, default: null },
  busy: Boolean,
});
const emit = defineEmits(['choose', 'confirm', 'cancel', 'cancel-summon']);
const drawer = ref(null);
const confirmation = ref(null);
const drawerOpen = ref(false);
const inspected = ref(null);
const panel = ref(null);
const primary = computed(() => props.actions.filter(action => action.primary));
const additional = computed(() => props.actions.filter(action => !action.primary && action.key !== 'end_turn'));
const endTurn = computed(() => props.actions.find(action => action.key === 'end_turn'));
let sizeObserver;

function choose(action) {
  if (props.busy) return;
  if (!action.ready) {
    inspected.value = action.key;
    drawerOpen.value = true;
    return;
  }
  drawerOpen.value = false;
  // Close the native dialog before opening an existing battle picker.
  drawer.value?.close();
  emit('choose', action.key);
}
const inspection = computed(() => props.actions.find(action => action.key === inspected.value));
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
onBeforeUnmount(() => sizeObserver?.disconnect());
</script>

<template>
  <footer ref="panel" class="player-action-panel" aria-label="Panel aksi battle" :aria-busy="busy">
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
        <button v-for="action in primary" :key="action.key" type="button" class="command-button" :class="[action.key, { locked: !action.ready }]" :data-action="action.key" :aria-disabled="!action.ready || busy" :disabled="busy" @click="choose(action)">
          <SkillIcon v-if="action.key === 'special'" class="command-icon" :icon="action.icon" :name="action.label" />
          <span v-else class="command-icon" aria-hidden="true">{{ action.icon }}</span>
          <strong>{{ action.label }}</strong><small>{{ action.ready ? action.costLabel : action.shortReason }}</small>
        </button>
        <button type="button" class="command-button more" aria-haspopup="dialog" :aria-expanded="drawerOpen && !inspected" :disabled="busy" @click="openMore"><span class="command-icon" aria-hidden="true">•••</span><strong>Aksi lainnya</strong><small>{{ additional.filter(action => action.ready).length }} siap digunakan</small></button>
      </div>
      <button v-if="endTurn" type="button" class="command-end" data-action="end_turn" :aria-disabled="!endTurn.ready || busy" :disabled="busy" @click="choose(endTurn)"><span aria-hidden="true">→|</span><strong>Akhiri giliran</strong><small>{{ context.ap }} AP tersisa</small></button>
    </div>
    <p v-if="busy" class="command-processing" role="status">Memproses aksi… Tunggu hasilnya sebelum memilih langkah berikutnya.</p>
  </footer>

  <Teleport to="body">
    <dialog ref="drawer" class="battle-command-dialog" aria-labelledby="command-drawer-title" @cancel="closeDrawer" @close="drawerOpen = false" @click="event => { if (event.target === drawer) closeDrawer(); }">
      <header><div><span class="command-eyebrow">{{ context.card?.name || 'PANEL AKSI' }}</span><h2 id="command-drawer-title">{{ inspection ? inspection.label : 'Aksi lainnya' }}</h2></div><button type="button" class="command-close" aria-label="Tutup aksi lainnya" @click="closeDrawer">✕</button></header>
      <template v-if="inspection">
        <p class="command-inspect-reason" role="status">{{ inspection.reason }}</p><p class="command-description">{{ inspection.description }}</p><button type="button" class="command-secondary" @click="inspected = null">Lihat aksi lainnya</button>
      </template>
      <template v-else>
        <p class="command-description">Pilih aksi yang sesuai dengan kondisi kartu dan AP-mu. Aksi terkunci tetap bisa dibuka untuk membaca syaratnya.</p>
        <div class="command-extra-grid">
          <button v-for="action in additional" :key="action.key" type="button" class="command-extra" :class="{ locked: !action.ready }" :data-action="action.key" :aria-disabled="!action.ready" @click="choose(action)">
            <span class="command-extra-icon" aria-hidden="true">{{ action.icon }}</span><span class="command-extra-heading"><strong>{{ action.label }}</strong><b>{{ action.costLabel }}</b></span><p>{{ action.description }}</p><small>{{ action.ready ? 'Siap digunakan →' : action.reason }}</small>
          </button>
        </div>
      </template>
    </dialog>

    <dialog ref="confirmation" class="battle-command-dialog command-review-dialog" aria-labelledby="command-review-title" @cancel="event => { event.preventDefault(); if (!busy) emit('cancel'); }" @click="event => { if (event.target === confirmation && !busy) emit('cancel'); }">
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
.command-cancel-summon{flex:none}.command-scan>div{min-width:0;flex:1}.command-scan small{display:block;margin-top:7px;font-size:11px;line-height:1.6;color:#8c642f}
@media(max-width:760px){.command-scan{flex-wrap:wrap}.command-scan>div{flex-basis:calc(100% - 54px)}.command-cancel-summon{margin-left:42px;width:calc(100% - 42px)}}
.player-action-panel,.battle-command-dialog{--command-ink:#173b2d;--command-green:#147246;--command-line:#d8e5da;font-family:Inter,Arial,sans-serif;color:var(--command-ink);box-sizing:border-box}
.player-action-panel *,.battle-command-dialog *{box-sizing:border-box}
.player-action-panel{position:fixed;z-index:150;left:50%;bottom:max(12px,env(safe-area-inset-bottom));transform:translateX(-50%);width:min(1080px,calc(100% - 32px));border:1px solid var(--command-line);border-radius:20px;padding:14px 18px;background:#fffffff5;box-shadow:0 12px 44px #21453424}
.command-context{display:flex;align-items:center;justify-content:space-between;gap:12px;padding-bottom:12px;border-bottom:1px solid #e5ede5;margin-bottom:12px}
.command-card{display:flex;align-items:center;gap:10px;min-width:0}.command-card img,.command-card-symbol{width:38px;height:42px;object-fit:contain;background:#eef5e8;border-radius:7px;flex:none}.command-card-symbol{display:grid;place-items:center;color:#69966e;font-size:23px}.command-card>div{min-width:0}.command-card strong{display:block;font-size:14px;white-space:nowrap;text-overflow:ellipsis;overflow:hidden}.command-card div>span{display:block;font-size:11px;color:#627a6a;margin-top:5px;line-height:1.5}.command-budget{display:flex;align-items:center;justify-content:end;gap:10px;flex:none;flex-wrap:wrap}.command-ap{font-size:11px;white-space:nowrap;padding:7px 10px;background:#eaf4e4;border-radius:8px}.command-ap b{font-size:21px;margin-right:3px}.command-clock{font-size:12px;white-space:nowrap;color:#507057}.command-clock.urgent{color:#ad342c;font-weight:800}.command-turn{font-size:10px;color:#7b6744}
.command-row{display:grid;grid-template-columns:minmax(0,1fr) 140px;gap:16px}.command-primary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px}.command-button{display:grid;grid-template-columns:30px minmax(0,1fr);align-content:center;align-items:center;gap:4px 8px;text-align:left;min-height:68px;padding:11px 13px;border:1px solid var(--command-line);border-radius:11px;background:#f9fcf5;color:var(--command-ink)}.command-icon{grid-row:1/3;display:grid;place-items:center;font-size:25px;width:30px;height:30px}.command-button strong{font-size:12px;line-height:1.4}.command-button small{font-size:10px;line-height:1.4;color:#597260}.command-button.summon{background:#eaf4df;border-color:#b9d4a7}.command-button.attack{background:#edf7f8;border-color:#c3dfe2}.command-button.more{background:#fff}.command-button.locked{background:#f7f8f5;border-color:#e0e7de;color:#697b6d}.command-button.locked .command-icon{color:#839284}.command-button.locked small{color:#6a7669}.command-end{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;padding:8px 14px;border:1px solid #dacdac;border-radius:11px;background:#fcf9ef;color:#70551f}.command-end>span{font-size:20px}.command-end strong{font-size:12px}.command-end small{font-size:10px}.command-end[aria-disabled=true]{color:#817966;background:#faf9f6}.command-scan{display:flex;align-items:center;gap:14px;padding:6px 4px}.command-scan>span{font-size:28px}.command-scan strong{font-size:14px}.command-scan p{font-size:12px;line-height:1.6;margin:6px 0 0;color:#627a6a}.command-processing{margin:10px 0 0;font-size:11px;color:#477352}
.battle-command-dialog{position:fixed;inset:0;margin:auto;width:min(820px,calc(100% - 32px));max-height:85dvh;overflow:auto;padding:26px;border:1px solid var(--command-line);border-radius:20px;background:#fff;box-shadow:0 24px 80px #15382e3b;overscroll-behavior:contain}.battle-command-dialog::backdrop{background:#19382b70;backdrop-filter:blur(3px)}.battle-command-dialog:not([open]){display:none}.battle-command-dialog header{display:flex;justify-content:space-between;align-items:start;gap:20px}.command-eyebrow{font-size:10px;font-weight:800;letter-spacing:.12em;color:#55835c}.battle-command-dialog h2{font-size:27px;letter-spacing:-.8px;margin:9px 0 0;line-height:1.25}.command-close{width:40px;height:40px;flex:none;border:1px solid var(--command-line);border-radius:9px;background:#f5f8f2;color:var(--command-ink)}.command-description{font-size:13px;line-height:1.8;color:#627a6a;margin:16px 0 22px}.command-extra-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.command-extra{display:grid;grid-template-columns:30px minmax(0,1fr);align-content:start;gap:9px 12px;text-align:left;min-width:0;padding:18px;border:1px solid #bad6c2;border-radius:12px;background:#f5faef;color:var(--command-ink)}.command-extra-icon{font-size:25px}.command-extra-heading{display:flex;align-items:center;justify-content:space-between;gap:8px}.command-extra-heading strong{font-size:15px}.command-extra-heading b{font-size:10px;font-weight:650;color:#497556}.command-extra p,.command-extra small{grid-column:1/-1;margin:0;font-size:12px;line-height:1.7}.command-extra p{color:#617867}.command-extra small{font-weight:650;color:#2e7343}.command-extra.locked{background:#f9faf7;border-color:#dde4da}.command-extra.locked small{color:#86602a}.command-inspect-reason,.command-review-warning{border-left:3px solid #cc9d3a;background:#fff6df;padding:14px 16px;line-height:1.8;font-size:13px;margin:22px 0}.command-review-dialog{width:min(540px,calc(100% - 32px))}.command-review-facts{display:grid;grid-template-columns:auto minmax(0,1fr);margin:18px 0;gap:12px 20px;background:#f1f7ea;border:1px solid #dce8d1;border-radius:12px;padding:18px;font-size:13px}.command-review-facts dt{color:#688269}.command-review-facts dd{margin:0;text-align:right;font-weight:700;overflow-wrap:anywhere}.command-review-actions{display:flex;gap:10px;justify-content:end;margin-top:24px}.command-secondary,.command-confirm{padding:12px 18px;border-radius:9px;font-size:13px;font-weight:700;border:1px solid #cbdcc9;background:#fff;color:#2c5f3d;min-height:44px}.command-confirm{background:#176e44;border-color:#176e44;color:#fff}
.player-action-panel button,.battle-command-dialog button{font-family:inherit;cursor:pointer}.player-action-panel button:disabled,.battle-command-dialog button:disabled{cursor:wait;opacity:.65}.player-action-panel button:focus-visible,.battle-command-dialog button:focus-visible{outline:3px solid #27889a;outline-offset:3px}.command-button:hover:not(:disabled),.command-extra:hover{border-color:#459367}
@media(max-width:760px){.player-action-panel{width:calc(100% - 16px);padding:11px 12px;bottom:max(8px,env(safe-area-inset-bottom));border-radius:16px}.command-context{align-items:start;gap:8px;margin-bottom:9px;padding-bottom:9px}.command-card{gap:7px}.command-card img,.command-card-symbol{width:29px;height:34px}.command-card strong{font-size:12px}.command-card div>span{font-size:10px;max-width:210px}.command-budget{gap:5px;max-width:104px}.command-ap{padding:4px 7px;font-size:10px}.command-ap b{font-size:17px}.command-clock{font-size:10px}.command-turn{font-size:9px}.command-row{grid-template-columns:1fr;gap:8px}.command-primary{gap:6px}.command-button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;text-align:center;min-height:73px;padding:8px 3px}.command-icon{width:23px;height:23px;font-size:21px}.command-button strong{font-size:10px}.command-button small{font-size:9px}.command-end{justify-self:end;flex-direction:row;gap:8px;min-height:36px;border-radius:8px;padding:6px 11px}.command-end>span{font-size:16px}.command-end strong{font-size:10px}.command-end small{font-size:10px}.battle-command-dialog{inset:auto 0 0;width:100%;max-height:88dvh;border-radius:20px 20px 0 0;padding:22px 18px max(22px,env(safe-area-inset-bottom))}.battle-command-dialog h2{font-size:25px}.command-extra-grid{grid-template-columns:1fr}.command-extra{padding:15px}.command-extra-heading strong{font-size:14px}.command-review-actions>*{flex:1}.command-scan strong{font-size:12px}.command-scan p{font-size:11px}}
</style>
