<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import BattleActionArtwork from './battle/BattleActionArtwork.vue';
import { supabase } from '../lib/supabase';
import { comboCode } from '../lib/battle/comboRules.js';
import { displayCardCode } from '../utils/displayCardCode.js';
import { formatTcgType, normalizeTcgType } from '../utils/tcgTypes.js';

const props = defineProps({ compact: Boolean, cards: { type: Array, default: () => [] } });
const emit = defineEmits(['catalog-count']);
const recipes = ref([]);
const loading = ref(true);
const failed = ref(false);
const search = ref('');
const mode = ref('all');
const currentPage = ref(1);
const recipeList = ref(null);
const pageSize = 9;
const modes = [
  { key: 'all', label: 'Semua resep' },
  { key: 'pair', label: 'Pasangan · 2 kartu' },
  { key: 'triple', label: 'Triple · 3 kartu' },
  { key: 'formation', label: 'Formation · 4 kartu' },
];
const typeIcons = { knight: '♜', fire: '♨', water: '◈', forest: '❧', thunder: 'ϟ', light: '☀', dark: '☾' };
const kind = recipe => recipe.type_keys.length === 4 ? 'formation' : recipe.type_keys.length === 3 ? 'triple' : 'pair';
const kindLabel = recipe => ({ pair: 'Combo pasangan', triple: 'Triple Combo', formation: 'Formation' })[kind(recipe)];
const slots = recipe => recipe.members?.length ? recipe.members : recipe.type_keys.map(type => ({ type }));
const cardFor = slot => slot.card_code ? props.cards.find(card => comboCode(card.card_code) === comboCode(slot.card_code)
  || comboCode(displayCardCode(card)) === comboCode(slot.card_code)) : null;
const slotCode = slot => displayCardCode({ card_code: slot.card_code });
const slotArt = slot => {
  const card = cardFor(slot);
  const url = card?.physical_card_image_url || card?.image_url;
  return typeof url === 'string' && /^(https?:\/\/|\/(?!\/))/.test(url) ? url : null;
};
const searchKey = value => String(value ?? '').trim().toLowerCase().replaceAll('_', '-');
const filtered = computed(() => {
  const query = searchKey(search.value);
  return recipes.value.filter(recipe => (mode.value === 'all' || kind(recipe) === mode.value)
    && (!query || searchKey([recipe.combo_name, ...recipe.type_keys, ...slots(recipe).flatMap(slot => [slotCode(slot), slot.tag, cardFor(slot)?.name])]
      .filter(Boolean).join(' ')).includes(query)));
});
const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize)));
const visibleRecipes = computed(() => filtered.value.slice((currentPage.value - 1) * pageSize, currentPage.value * pageSize));
watch([search, mode], () => { currentPage.value = 1; });
watch(pageCount, count => { currentPage.value = Math.min(currentPage.value, count); });
const number = value => Number(value).toLocaleString('id-ID', { maximumFractionDigits: 2 });
const powerFormula = recipe => {
  const terms = [`ATK utama × ${number(recipe.primary_multiplier ?? 1)}`,
    ...recipe.type_keys.slice(1).map((_, i) => `ATK pendamping ${i + 1} × ${number(recipe.assist_multipliers?.[i] ?? .6)}`)];
  if (recipe.bonus_damage) terms.push(number(recipe.bonus_damage));
  return `(${terms.join(' + ')}) × ${number(recipe.damage_multiplier ?? 1)}`;
};
const effects = recipe => [
  recipe.defense_ignore_pct > 0 && `Tembus ${number(recipe.defense_ignore_pct * 100)}% DEF`,
  recipe.heal_after > 0 && `+${number(recipe.heal_after)} HP tiap peserta`,
  recipe.shield_after > 0 && `Shield ${number(recipe.shield_after)} untuk kartu utama`,
  recipe.status_key && `${formatTcgType(recipe.status_key)} → ${{ enemy: 'target lawan', primary: 'kartu utama', participants: 'semua peserta' }[recipe.status_target] || 'target lawan'}`,
  recipe.effect_json?.cleanse_negative_status && 'Bersihkan status negatif peserta',
].filter(Boolean);

let requestVersion = 0;
let refreshTimer;
async function loadRecipes() {
  const version = ++requestVersion;
  try {
    const { data, error } = await supabase.from('tcg_combo_rule_catalog')
      .select('id,combo_name,rule_kind,type_keys,enabled,ap_cost,primary_multiplier,assist_multipliers,damage_multiplier,bonus_damage,defense_ignore_pct,heal_after,shield_after,status_key,status_target,effect_json,members,shared_tag,priority')
      .eq('enabled', true).order('combo_name').order('id');
    if (error) throw error;
    if (version !== requestVersion) return;
    recipes.value = (data ?? []).filter(recipe => recipe.enabled === true && Array.isArray(recipe.type_keys)
      && recipe.type_keys.length >= 2 && recipe.type_keys.length <= 4);
    failed.value = false;
    emit('catalog-count', recipes.value.length);
  } catch {
    if (version !== requestVersion) return;
    recipes.value = [];
    failed.value = true;
    emit('catalog-count', null);
  } finally {
    if (version === requestVersion) loading.value = false;
  }
}
const refreshVisible = () => { if (document.visibilityState === 'visible') loadRecipes(); };
function setPage(value) {
  currentPage.value = Math.min(pageCount.value, Math.max(1, value));
  recipeList.value?.scrollIntoView({ block: 'start', behavior: 'instant' });
}
onMounted(() => {
  loadRecipes();
  window.addEventListener('focus', refreshVisible);
  document.addEventListener('visibilitychange', refreshVisible);
  refreshTimer = window.setInterval(refreshVisible, 30000);
});
onBeforeUnmount(() => {
  requestVersion++;
  window.clearInterval(refreshTimer);
  window.removeEventListener('focus', refreshVisible);
  document.removeEventListener('visibilitychange', refreshVisible);
});
</script>

<template>
  <section class="combo-catalog" :class="{ 'combo-compact': compact }" aria-labelledby="combo-title">
    <header class="combo-intro">
      <div class="combo-copy">
        <span class="combo-eyebrow">TIMEDOOR · COMBO PLAYBOOK</span>
        <component :is="compact ? 'h2' : 'h1'" id="combo-title">Satu tim.<br><em>Satu serangan.</em></component>
        <p>Pilih kartu yang saling melengkapi, tentukan penyerang utama, lalu serang bersama. Kartu peserta tetap di arena setelah Combo.</p>
        <RouterLink v-if="compact" class="combo-link" to="/combo">Jelajahi Combo <span aria-hidden="true">↗</span></RouterLink>
        <p v-else class="combo-source-note">Resep aktif dari pengaturan guru. Mode dan biaya AP saat bermain mengikuti pengaturan battle; battle yang sudah dimulai memakai aturan yang tersimpan.</p>
      </div>
      <div class="combo-illustration">
        <BattleActionArtwork action="combo" />
        <div class="combo-team-strip" aria-label="Mode Combo">
          <div><b>2</b><span>Pasangan<small>Resep atau Generic</small></span></div>
          <div><b>3</b><span>Triple<small>Resep tiga kartu</small></span></div>
          <div><b>4</b><span>Formation<small>Resep empat kartu</small></span></div>
        </div>
      </div>
    </header>

    <div class="combo-rhythm">
      <div><span class="combo-eyebrow">SERANG, LALU ATUR STRATEGI</span><h2 v-if="!compact">Combo punya jeda.</h2><h3 v-else>Combo punya jeda.</h3><p>Semua jenis Combo berbagi cooldown. Giliran lawan tidak dihitung.</p></div>
      <ol aria-label="Contoh cooldown Combo pada giliran sendiri">
        <li><span>Giliranmu 1</span><b>Gunakan Combo</b></li>
        <li><span>Giliranmu 2</span><b>Jeda Combo</b></li>
        <li><span>Giliranmu 3</span><b>Siap lagi</b></li>
      </ol>
    </div>

    <template v-if="!compact">
      <section class="combo-generic" aria-labelledby="generic-title">
        <span class="generic-symbol" aria-hidden="true">2×</span>
        <div><span class="combo-eyebrow">GENERIC COMBO · 2 BASE ACTIVE</span><h2 id="generic-title">Belum ada resep yang cocok?</h2><p><b>Combined Strike</b> tersedia jika Generic diaktifkan dan dua kartu pilihanmu tidak cocok dengan resep khusus. Kekuatan dasarnya: ATK utama + 50% ATK pendamping, dibulatkan ke bawah. Tanpa bonus efek.</p><small>Biaya default 2 AP. Generic tidak menggantikan resep Triple atau Formation.</small></div>
      </section>

      <section ref="recipeList" class="combo-recipes" aria-labelledby="combo-recipes-title">
        <header class="combo-list-heading"><div><span class="combo-eyebrow">CARI PARTNER KARTUMU</span><h2 id="combo-recipes-title">Resep Combo</h2></div><span v-if="!loading && !failed" class="combo-count">{{ filtered.length }} dari {{ recipes.length }} resep aktif</span></header>
        <label class="combo-search"><span>Cari resep</span><input v-model="search" type="search" placeholder="Nama combo, tipe, kode kartu, atau tag" autocomplete="off"></label>
        <div class="combo-filters" role="group" aria-label="Jenis Combo"><button v-for="item in modes" :key="item.key" type="button" :aria-pressed="mode === item.key" @click="mode = item.key">{{ item.label }}</button></div>
        <p v-if="loading" class="combo-state" role="status">Memuat resep Combo…</p>
        <div v-else-if="failed" class="combo-state" role="alert"><p>Resep Combo belum dapat dimuat. Coba muat ulang katalog ini.</p><button type="button" @click="loadRecipes">Muat ulang Combo</button></div>
        <div v-else-if="!recipes.length" class="combo-state"><h3>Resep sedang disiapkan.</h3><p>Guru dapat mengaktifkan resep di Skill &amp; Catalog → Resep Combo. Generic tetap mengikuti pengaturan battle.</p></div>
        <div v-else-if="!filtered.length" class="combo-state"><h3>Belum ada resep yang cocok.</h3><p>Coba nama, tipe, kode kartu, atau tag lain.</p><button type="button" @click="search = ''; mode = 'all'">Tampilkan semua resep</button></div>
        <div v-else class="combo-recipe-grid">
          <article v-for="recipe in visibleRecipes" :key="recipe.id" class="combo-recipe" :data-mode="kind(recipe)">
            <header><span>{{ kindLabel(recipe) }}</span><b :title="'Biaya dasar resep; biaya saat bermain mengikuti pengaturan battle.'">{{ recipe.ap_cost }} AP dasar</b></header>
            <div class="combo-partners" :aria-label="`${recipe.type_keys.length} peserta: ${recipe.type_keys.map(formatTcgType).join(', ')}`">
              <template v-for="(slot, index) in slots(recipe)" :key="index">
                <span v-if="index" class="combo-plus" aria-hidden="true">+</span>
                <div class="combo-partner" :class="`type-${normalizeTcgType(slot.type)}`">
                  <img v-if="slotArt(slot)" :src="slotArt(slot)" alt="" loading="lazy">
                  <i v-else aria-hidden="true">{{ typeIcons[normalizeTcgType(slot.type)] || '✦' }}</i>
                  <span>{{ formatTcgType(slot.type) }}</span>
                </div>
              </template>
            </div>
            <div class="combo-outcome"><span aria-hidden="true">↓</span><h3>{{ recipe.combo_name }}</h3></div>
            <p class="combo-summary">{{ recipe.effect_json?.summary || `${recipe.type_keys.length} kartu Base Active menyerang satu target bersama.` }}</p>
            <p v-if="recipe.shared_tag || recipe.members?.some(slot => slot.card_code || slot.tag)" class="combo-specific">{{ recipe.shared_tag ? 'Wajib berbagi satu tag' : 'Ada syarat kartu / tag' }}</p>
            <details>
              <summary>Lihat syarat &amp; efek</summary>
              <div class="combo-recipe-detail">
                <h4>Kartu yang diperlukan</h4>
                <ol><li v-for="(slot, index) in slots(recipe)" :key="index"><b>{{ formatTcgType(slot.type) }}</b><span v-if="slot.card_code"> · {{ slotCode(slot) }}<template v-if="cardFor(slot)"> · {{ cardFor(slot).name }}</template></span><span v-if="slot.tag"> · tag “{{ slot.tag }}”</span></li></ol>
                <p v-if="recipe.shared_tag">Semua peserta harus memiliki minimal satu tag yang sama, selain tag fusion:.</p>
                <p>Satu kartu berbeda untuk setiap baris. Semua syarat dalam satu baris harus terpenuhi. Kamu bebas memilih kartu utama.</p>
                <h4>Kekuatan dasar</h4><p class="combo-formula">{{ powerFormula(recipe) }}</p><p>Kontribusi tiap pendamping dibulatkan ke bawah, lalu total dibulatkan. Damage akhir masih dipengaruhi DEF, Shield, dan efek battle.</p>
                <h4>Efek tambahan</h4><ul v-if="effects(recipe).length"><li v-for="effect in effects(recipe)" :key="effect">{{ effect }}</li></ul><p v-else>Tidak ada efek tambahan.</p>
                <p v-if="recipe.heal_after > 0">Pemulihan hanya untuk HP kartu peserta, maksimal Max HP; bukan HP pemain.</p>
                <p v-if="recipe.shield_after || recipe.status_key || recipe.effect_json?.cleanse_negative_status">Shield, status tambahan, dan pembersihan status memerlukan Status Effects aktif.</p>
              </div>
            </details>
          </article>
        </div>
        <nav v-if="pageCount > 1 && !failed" class="combo-pagination" aria-label="Halaman resep Combo"><button type="button" :disabled="currentPage === 1" @click="setPage(currentPage - 1)">← Sebelumnya</button><span>Halaman {{ currentPage }} dari {{ pageCount }}</span><button type="button" :disabled="currentPage === pageCount" @click="setPage(currentPage + 1)">Berikutnya →</button></nav>
      </section>

      <section class="combo-rules" aria-labelledby="combo-rules-title"><div><span class="combo-eyebrow">SEBELUM MENEKAN COMBO</span><h2 id="combo-rules-title">Siapkan timmu.</h2><RouterLink to="/cards">Lihat koleksi kartu ↗</RouterLink></div><ul><li><b>Base Active, siap menyerang.</b> Gunakan kartu berbeda yang masih hidup, tidak exhausted, belum menyerang, dan tidak terkunci status. Kartu Fusion tidak ikut Combo.</li><li><b>Semua peserta memakai jatah serang.</b> Mereka tetap di Active dan tidak bisa mundur, Switch, atau menjadi bahan Fusion sampai giliranmu berikutnya.</li><li><b>Satu cooldown untuk semua Combo.</b> Mengganti peserta atau masuk ulang tidak menghapus jeda. Aksi yang ditolak tidak memakai AP atau memulai cooldown.</li><li><b>Ikuti resep yang dipilih battle.</b> Jika beberapa resep cocok, prioritas tertinggi dipakai, lalu yang paling spesifik. Periksa preview sebelum konfirmasi.</li></ul></section>
    </template>
  </section>
</template>

<style scoped>
.combo-catalog{--combo-ink:#24342d;--combo-purple:#7045ad;--combo-muted:#69766f;--combo-line:#dde6dc;max-width:1256px;margin:0 auto;padding:64px 28px 80px;color:var(--combo-ink);font-family:'DM Sans',sans-serif}
.combo-catalog *{box-sizing:border-box}.combo-catalog h1,.combo-catalog h2,.combo-catalog h3{font-family:'Space Grotesk',sans-serif}.combo-catalog button,.combo-catalog input{font:inherit}.combo-catalog button,.combo-catalog summary{cursor:pointer}.combo-catalog :is(button,a,summary,input):focus-visible{outline:3px solid #267b91;outline-offset:4px}.combo-catalog p{line-height:1.8}.combo-eyebrow{font-size:10px;font-weight:800;letter-spacing:.14em;color:var(--combo-purple)}
.combo-intro{display:grid;grid-template-columns:1fr 1fr;gap:48px;align-items:center}.combo-copy h1,.combo-copy h2{font-size:clamp(38px,4.6vw,62px);line-height:1.04;letter-spacing:-2px;margin:18px 0 20px}.combo-copy em{font-style:normal;color:var(--combo-purple)}.combo-copy>p{font-size:14px;max-width:490px;color:var(--combo-muted);margin:0 0 20px}.combo-copy .combo-source-note{font-size:11px;margin:0}.combo-link{display:inline-flex;gap:28px;align-items:center;padding:14px 18px;border-radius:8px;background:var(--combo-purple);color:white;text-decoration:none;font-size:12px;font-weight:800}.combo-link:hover{background:#5d3795}.combo-illustration{min-width:0;border:1px solid #dfd5e9;border-radius:18px;overflow:hidden;background:#f3edf9;transform:rotate(1.5deg)}.combo-illustration :deep(.battle-action-artwork){aspect-ratio:1.8}.combo-team-strip{display:flex;justify-content:space-between;padding:20px 18px;gap:12px;background:#fff}.combo-team-strip>div{display:flex;gap:9px;align-items:center}.combo-team-strip b{font:700 34px/1 'Space Grotesk',sans-serif;color:var(--combo-purple);letter-spacing:-2px}.combo-team-strip span{font-size:12px;font-weight:800}.combo-team-strip small{display:block;font-size:9px;font-weight:500;color:var(--combo-muted);margin-top:4px}
.combo-rhythm{margin:48px 0 0;display:grid;grid-template-columns:1fr 1.3fr;gap:36px;align-items:center;padding:26px 0;border-top:1px solid var(--combo-line);border-bottom:1px solid var(--combo-line)}.combo-rhythm h2,.combo-rhythm h3{font-size:24px;letter-spacing:-.8px;margin:8px 0}.combo-rhythm p{font-size:12px;color:var(--combo-muted);margin:0;max-width:310px}.combo-rhythm ol{list-style:none;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;padding:0;margin:0}.combo-rhythm li{position:relative;padding:13px 12px;border-radius:8px;background:#f1eafa;color:#654198}.combo-rhythm li:nth-child(2){background:#edf0e9;color:#6e786a}.combo-rhythm li:last-child{background:#e6f2e6;color:#23723a}.combo-rhythm li+li::before{content:'→';position:absolute;left:-11px;top:24px;font-size:11px;color:#71816d}.combo-rhythm li span{display:block;font-size:10px;margin-bottom:6px}.combo-rhythm li b{font-size:12px}
.combo-generic{display:flex;align-items:start;gap:22px;margin:46px 0;padding:25px;border-radius:12px;background:#eff4ed;border:1px solid var(--combo-line)}.generic-symbol{flex:none;display:grid;place-items:center;width:52px;height:58px;border:2px solid #a8b7a1;border-radius:8px;box-shadow:-5px 4px 0 #d1dccb;font:700 23px 'Space Grotesk',sans-serif;color:#567449}.combo-generic h2{font-size:23px;letter-spacing:-.7px;margin:8px 0}.combo-generic p{font-size:12px;margin:0 0 10px;color:#50674f}.combo-generic small{font-size:11px;color:#62765d}.combo-generic .combo-eyebrow{color:#557347}
.combo-recipes{scroll-margin-top:105px}.combo-list-heading{display:flex;justify-content:space-between;align-items:end;gap:16px;margin-bottom:22px}.combo-list-heading h2{font-size:36px;letter-spacing:-1.2px;margin:9px 0 0}.combo-count{color:var(--combo-muted);font-size:12px;white-space:nowrap}.combo-search{display:flex;align-items:center;border:1px solid #d7e2d3;border-radius:8px;overflow:hidden;background:white;gap:16px;padding:0 16px}.combo-search>span{font-size:12px;font-weight:800;flex:none}.combo-search input{display:block;width:100%;min-width:0;border:0;background:transparent;padding:16px 0;font-size:13px;color:var(--combo-ink)}.combo-search:focus-within{outline:2px solid #267b91;outline-offset:3px}.combo-search input:focus-visible{outline:none}.combo-filters{display:flex;gap:8px;flex-wrap:wrap;margin:15px 0 26px}.combo-filters button{padding:10px 14px;font-size:11px;border:1px solid var(--combo-line);border-radius:7px;background:white;color:var(--combo-muted)}.combo-filters button[aria-pressed=true]{background:var(--combo-purple);color:white;border-color:var(--combo-purple)}
.combo-recipe-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px;align-items:start}.combo-recipe{padding:20px;border:1px solid #dfe4dc;border-radius:13px;background:#fff;min-width:0;overflow-wrap:anywhere}.combo-recipe>header{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:10px;font-weight:800;color:var(--combo-purple)}.combo-recipe>header>b{border-radius:5px;padding:6px 7px;background:#fff3c5;color:#715605;font-size:10px;white-space:nowrap}.combo-partners{display:flex;align-items:center;justify-content:center;gap:7px;padding:22px 0 10px}.combo-partner{flex:1;max-width:78px;text-align:center;min-width:0;--type-color:#56636f;--type-bg:#eef2f5}.combo-partner i,.combo-partner img{display:grid;place-items:center;width:50px;height:60px;border-radius:8px;border:1px solid color-mix(in srgb,var(--type-color) 30%,white);margin:0 auto 8px;background:var(--type-bg);color:var(--type-color);font-size:29px;font-style:normal;object-fit:cover;box-shadow:0 3px 0 var(--type-bg)}.combo-partner span{font-size:10px;font-weight:700}.combo-plus{font-size:15px;color:#a6b19e;padding-bottom:17px}.combo-partner.type-fire{--type-color:#b64a25;--type-bg:#fff0e3}.combo-partner.type-water{--type-color:#287fb5;--type-bg:#e8f5fe}.combo-partner.type-forest{--type-color:#388342;--type-bg:#ecf7e9}.combo-partner.type-thunder{--type-color:#aa7a00;--type-bg:#fff8d7}.combo-partner.type-light{--type-color:#a08219;--type-bg:#fffae6}.combo-partner.type-dark{--type-color:#7951a6;--type-bg:#f2ecfa}.combo-outcome>span{display:block;text-align:center;font-size:18px;color:#baabca;margin-bottom:10px}.combo-outcome h3{font-size:23px;line-height:1.15;letter-spacing:-.7px;margin:0}.combo-summary{font-size:12px;color:var(--combo-muted);margin:10px 0 17px;min-height:44px}.combo-specific{font-size:10px;color:#78539e;margin:0 0 14px;font-weight:700}.combo-recipe summary{font-size:11px;font-weight:800;color:var(--combo-purple);border-top:1px solid #e8ece4;padding:13px 0 0}.combo-recipe-detail{font-size:12px;line-height:1.7;color:#59665c;padding-top:5px}.combo-recipe-detail h4{font-size:12px;color:var(--combo-ink);margin:17px 0 6px}.combo-recipe-detail p{font-size:11px;margin:10px 0}.combo-recipe-detail ol,.combo-recipe-detail ul{padding-left:18px;margin:7px 0}.combo-recipe-detail li{margin-bottom:6px}.combo-recipe-detail .combo-formula{padding:12px;background:#f7f3fb;border-left:2px solid #b89fd5;border-radius:0 5px 5px 0;color:#614d7d}
.combo-state{padding:32px;background:#fff;border:1px dashed var(--combo-line);border-radius:10px;text-align:center;color:var(--combo-muted);font-size:13px}.combo-state h3{font-size:20px;color:var(--combo-ink)}.combo-state button,.combo-pagination button{padding:10px 13px;border-radius:7px;border:1px solid #d5c6e6;background:white;color:var(--combo-purple);font-weight:700;font-size:12px}.combo-state button:hover,.combo-pagination button:hover:not(:disabled){background:#f3edf9}.combo-pagination{display:flex;justify-content:center;align-items:center;gap:20px;margin-top:28px;font-size:12px;color:var(--combo-muted)}.combo-pagination button:disabled{opacity:.45;cursor:default}.combo-rules{display:grid;grid-template-columns:1fr 2fr;gap:40px;margin-top:55px;padding-top:32px;border-top:1px solid var(--combo-line)}.combo-rules h2{font-size:30px;letter-spacing:-1px;margin:10px 0 18px}.combo-rules a{color:var(--combo-purple);font-size:12px;font-weight:800;text-decoration:none}.combo-rules ul{padding-left:18px;margin:0;display:grid;grid-template-columns:1fr 1fr;gap:22px 32px}.combo-rules li{font-size:12px;color:var(--combo-muted);line-height:1.8}.combo-rules li b{display:block;color:var(--combo-ink)}.combo-compact{padding-top:35px;padding-bottom:30px}
@media(max-width:1000px){.combo-intro{gap:28px}.combo-team-strip{padding:15px 12px;gap:8px}.combo-team-strip>div{gap:5px}.combo-team-strip small{font-size:8px}.combo-team-strip span{font-size:10px}.combo-team-strip b{font-size:28px}.combo-recipe-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.combo-rhythm{gap:20px}.combo-rules{grid-template-columns:1fr;gap:24px}}
@media(max-width:620px){.combo-catalog{padding:38px 16px 50px}.combo-intro{grid-template-columns:1fr;gap:28px}.combo-copy h1,.combo-copy h2{font-size:46px;margin:14px 0 18px}.combo-copy>p{font-size:13px}.combo-illustration{transform:none}.combo-team-strip{padding:18px 14px}.combo-team-strip>div{gap:8px}.combo-team-strip span{font-size:11px}.combo-team-strip b{font-size:30px}.combo-team-strip small{font-size:8px}.combo-rhythm{grid-template-columns:1fr;margin-top:30px;gap:18px}.combo-rhythm ol{gap:10px}.combo-rhythm li{padding:12px 8px}.combo-rhythm li b{font-size:10px}.combo-rhythm li span{font-size:9px}.combo-rhythm p{max-width:none}.combo-generic{gap:16px;padding:20px 16px;margin:28px 0}.generic-symbol{width:35px;height:43px;font-size:18px}.combo-generic h2{font-size:22px}.combo-list-heading{align-items:start;flex-direction:column;gap:10px}.combo-list-heading h2{font-size:31px}.combo-search{align-items:start;flex-direction:column;gap:0;padding:12px}.combo-search input{padding:10px 0 0;font-size:12px}.combo-filters{gap:7px}.combo-filters button{font-size:10px;flex:1 1 40%;padding:11px 8px}.combo-recipe-grid{grid-template-columns:1fr}.combo-recipe{padding:22px}.combo-partners{gap:10px}.combo-pagination{gap:8px;font-size:10px}.combo-pagination button{font-size:10px;padding:10px 8px}.combo-rules ul{grid-template-columns:1fr;gap:18px}.combo-rules{margin-top:35px}.combo-compact{padding-top:15px;padding-bottom:15px}.combo-recipes{scroll-margin-top:125px}}
</style>
