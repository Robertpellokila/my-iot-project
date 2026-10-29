<script setup>
import { computed, ref, watch } from 'vue';
import SearchableSelect from '../SearchableSelect.vue';
import SkillIcon from './SkillIcon.vue';
import { splitSkillIcon, skillMediaValue, skillLimitLabel } from '../../lib/battle/skillPresentation.js';
import { cloneRule, RULE_TEMPLATES, TARGET_LABELS, OP_LABELS, CONDITION_LABELS, EFFECT_LABELS, applyRuleTemplate, describeOperation, describeEffects, skillRuleIssues } from '../../lib/battle/skillEditor.js';

const props = defineProps({ skill: { type: Object, required: true }, saving: Boolean });
const emit = defineEmits(['save']);
const draft = ref({}), imageUrl = ref(''), symbol = ref('✦'), templateId = ref(''), rawEffects = ref(''), rawEdited = ref(false), localError = ref(''), initialDraft = ref('');
watch(() => props.skill, skill => {
  draft.value = cloneRule(skill);
  draft.value.limits ??= {};
  draft.value.limits.action_points ??= 1;
  draft.value.target_spec ??= {};
  draft.value.cost_spec ??= { type: 'none' };
  draft.value.change_note = '';
  const media = splitSkillIcon(skill.icon); imageUrl.value = media.imageUrl; symbol.value = media.symbol;
  rawEffects.value = JSON.stringify(skill.effects ?? [], null, 2); rawEdited.value = false; localError.value = '';
  templateId.value = (RULE_TEMPLATES.find(t => t.name.toLowerCase() === skill.name?.toLowerCase()) ?? RULE_TEMPLATES.find(t => t.description === skill.description))?.id ?? '';
  initialDraft.value = JSON.stringify({ ...draft.value, icon: skill.icon || '✦' });
}, { immediate: true });
const program = computed(() => draft.value.effects?.length === 1 && draft.value.effects[0].type === 'studio_skill' ? draft.value.effects[0].program : null);
const groups = computed(() => program.value ? (program.value.choices?.length ? program.value.choices : [{ id: 'direct', label: 'Efek', operations: program.value.operations }]) : []);
const chosenTemplate = computed(() => RULE_TEMPLATES.find(t => t.id === templateId.value));
const candidate = computed(() => {
  const next = cloneRule(draft.value);
  if (rawEdited.value) next.effects = JSON.parse(rawEffects.value);
  next.icon = skillMediaValue(imageUrl.value, symbol.value);
  return next;
});
const issues = computed(() => {
  try { return skillRuleIssues(candidate.value); } catch (error) { return [rawEdited.value ? 'Format efek JSON atau gambar belum valid. Periksa pengaturan lanjutan.' : error.message]; }
});
const summary = computed(() => { try { return describeEffects(candidate.value.effects); } catch { return []; } });
const cooldownKey = computed(() => Object.hasOwn(draft.value.limits, 'cooldown_turns') ? 'cooldown_turns' : Object.hasOwn(draft.value.limits, 'cooldown_rounds') ? 'cooldown_rounds' : Object.hasOwn(draft.value.limits, 'cooldown') ? 'cooldown' : 'cooldown_turns');
const dirty = computed(() => {
  try { return JSON.stringify(candidate.value) !== initialDraft.value; } catch { return true; }
});
function useTemplate() {
  if (!chosenTemplate.value) return;
  draft.value = applyRuleTemplate(draft.value, chosenTemplate.value);
  rawEffects.value = JSON.stringify(draft.value.effects, null, 2); rawEdited.value = false; localError.value = '';
}
function updateChoiceLabels() {
  if (!program.value?.choices?.length) return;
  for (const choice of program.value.choices) choice.label = choice.operations.map(describeOperation).join(' + ');
  draft.value.target_spec.choices = program.value.choices.map(({ id, label }) => ({ id, label }));
}
function submit(status) {
  localError.value = '';
  try {
    const next = candidate.value;
    if (!next.name?.trim() || !next.code?.trim()) throw new Error('Nama skill dan kode internal wajib diisi.');
    if (status === 'active' && issues.value.length) throw new Error(issues.value.join(' '));
    emit('save', { ...next, catalog_status: status, is_active: status === 'active' });
  } catch (error) { localError.value = error.message; }
}
const adjustable = op => !['switch', 'cleanse', 'root', 'silence_slot2', 'burn'].includes(op.type);
const simpleAmount = effect => ['damage_card', 'heal_card', 'damage_player', 'heal_player', 'add_skill_gauge'].includes(effect.type) && effect.amount?.mode === 'fixed';
</script>

<template>
  <form class="rule-editor" @submit.prevent="submit(draft.catalog_status || 'draft')">
    <section class="rule-preview" aria-label="Ringkasan efek battle">
      <div class="rule-kicker">SAAT DIPAKAI <span v-if="dirty">Belum disimpan</span></div>
      <strong>{{ TARGET_LABELS[draft.target_spec.type] || 'Target belum ditentukan' }}</strong>
      <ul v-if="summary.length"><li v-for="(text, index) in summary" :key="index">{{ text }}</li></ul>
      <p v-else>Belum ada efek yang dijalankan. Mulai dengan memilih pola skill.</p>
      <div class="rule-facts"><span>{{ draft.limits.action_points ?? 1 }} AP</span><span>{{ skillLimitLabel(draft) }}</span><span v-if="draft.limits.once_per_battle">Sekali per battle</span><span v-else-if="draft.limits.max_uses">Maks. {{ draft.limits.max_uses }} kali</span><span v-if="draft.consumes_turn">Mengakhiri giliran</span></div>
      <small v-if="program?.exclusive">Tidak dapat dipakai pada giliran yang sama dengan skill lain pada kartu ini.</small>
    </section>

    <fieldset class="rule-section">
      <legend><span>1</span> Teks pada kartu</legend>
      <p>Nama dan deskripsi untuk pemain. Mengubah teks ini tidak mengubah efek battle.</p>
      <label>Nama skill<input v-model="draft.name" required /></label>
      <label>Deskripsi kartu<textarea v-model="draft.description" rows="3" placeholder="Contoh: Pulihkan 7 HP pada 1 ally. CD 2." /></label>
      <details class="rule-details"><summary>Gambar &amp; identitas skill</summary>
        <div class="rule-media"><SkillIcon :icon="imageUrl || symbol" :name="draft.name" /><label>URL gambar skill<input v-model="imageUrl" inputmode="url" /></label></div>
        <label>Simbol pengganti<input v-model="symbol" /></label>
        <label>Kode internal<input v-model="draft.code" required /><small>Identitas unik skill; tidak perlu diubah untuk mengatur efek.</small></label>
      </details>
    </fieldset>

    <fieldset class="rule-section">
      <legend><span>2</span> Efek saat battle</legend>
      <p>Pilih pola yang paling dekat, lalu sesuaikan angkanya. Pola mengisi target, efek, dan biaya sekaligus.</p>
      <details class="rule-template" :open="!draft.effects?.length">
        <summary>{{ draft.effects?.length ? 'Ganti pola efek' : 'Mulai dari pola skill' }}</summary>
        <label>Pola skill<SearchableSelect v-model="templateId"><option value="">Pilih atau cari pola…</option><option v-for="t in RULE_TEMPLATES" :key="t.id" :value="t.id">{{ t.name }} — {{ t.description }}</option></SearchableSelect></label>
        <p v-if="chosenTemplate" class="template-description">{{ chosenTemplate.description }}</p>
        <button type="button" class="rule-secondary" :disabled="!chosenTemplate" @click="useTemplate">Gunakan pola ini</button>
        <small>Ini mengganti aturan battle. Nama, gambar, dan deskripsi kartu tetap milikmu.</small>
      </details>
      <template v-if="program && !rawEdited">
        <div class="rule-target"><small>SIAPA YANG TERKENA EFEK</small><strong>{{ TARGET_LABELS[program.target] }}</strong><span v-if="program.max_targets > 1">Pilih maksimal {{ program.max_targets }} target berbeda</span><span v-if="draft.target_spec.needs_bench">Pemain juga memilih 1 kartu Bench untuk ditukar.</span></div>
        <p v-if="program.choices?.length" class="rule-hint">Pemain memilih <b>satu</b> opsi berikut saat menggunakan skill.</p>
        <div v-for="(group, groupIndex) in groups" :key="group.id" class="rule-effect-group">
          <h4 v-if="program.choices?.length">Pilihan {{ groupIndex + 1 }}</h4>
          <div v-for="(op, index) in group.operations" :key="index" class="rule-operation">
            <strong>{{ OP_LABELS[op.type] || op.type }}</strong>
            <p>{{ describeOperation(op) }}</p>
            <label v-if="adjustable(op)">{{ op.type === 'revive' ? 'HP yang dipulihkan (%)' : op.type === 'attack' ? 'Bonus damage' : 'Nilai efek' }}
              <input v-if="op.type === 'revive'" :value="Math.round(op.amount * 100)" type="number" min="1" max="100" @input="op.amount = Number($event.target.value) / 100; updateChoiceLabels()" />
              <input v-else v-model.number="op.amount" type="number" min="0" max="999" @input="updateChoiceLabels" />
            </label>
            <label v-if="op.type === 'attack'">Bonus berlaku ketika<SearchableSelect v-model="op.condition"><option v-for="(label, key) in CONDITION_LABELS" :key="key" :value="key">{{ label }}</option></SearchableSelect></label>
          </div>
        </div>
      </template>
      <template v-else-if="!rawEdited">
        <div v-for="(effect, index) in draft.effects" :key="index" class="rule-operation">
          <strong>{{ EFFECT_LABELS[effect.type] || effect.type }}</strong><p>{{ describeEffects([effect])[0] }}</p>
          <label v-if="simpleAmount(effect)">Nilai efek<input v-model.number="effect.amount.value" type="number" min="0" max="999" /></label>
          <template v-if="effect.type === 'add_status'"><label>Durasi status (giliran)<input v-model.number="effect.duration_turns" type="number" min="1" /></label><small>Jenis status, tumpukan, dan target tetap mengikuti aturan tersimpan.</small></template>
        </div>
      </template>
      <p v-else class="rule-hint">Efek mengikuti perubahan di pengaturan lanjutan. Ringkasan di atas akan ikut diperbarui.</p>
    </fieldset>

    <fieldset class="rule-section">
      <legend><span>3</span> Biaya &amp; batas pemakaian</legend>
      <div class="rule-grid"><label>Biaya poin giliran<select v-model.number="draft.limits.action_points"><option :value="1">1 AP</option><option :value="2">2 AP</option></select><small>AP yang dikurangi setiap kali skill digunakan.</small></label>
      <label>Jeda pemakaian<input v-model.number="draft.limits[cooldownKey]" :placeholder="'0'" type="number" min="0" max="999" /><small>{{ cooldownKey === 'cooldown_turns' ? 'Giliran pemilik' : 'Ronde' }}. Isi 0 untuk tanpa jeda.</small></label></div>
      <label class="rule-check"><input v-model="draft.limits.once_per_battle" type="checkbox" /> Hanya sekali per battle</label>
      <label v-if="!draft.limits.once_per_battle">Maksimal penggunaan per battle<input v-model.number="draft.limits.max_uses" type="number" min="0" placeholder="0" /><small>0 = tidak terbatas.</small></label>
      <label class="rule-check"><input v-model="draft.consumes_turn" type="checkbox" /> Akhiri giliran setelah digunakan</label>
      <small v-if="draft.cost_spec.type === 'skill_gauge'">Biaya tambahan tersimpan: {{ draft.cost_spec.value ?? draft.cost_spec.amount }} Skill Gauge.</small>
    </fieldset>

    <details class="rule-details" @toggle="!rawEdited && (rawEffects = JSON.stringify(draft.effects ?? [], null, 2))"><summary>Pengaturan lanjutan</summary>
      <p>Untuk aturan khusus. Pola skill di atas sudah menyiapkan target dan pilihan efek yang sesuai.</p>
      <label>Target<SearchableSelect v-model="draft.target_spec.type"><option v-for="(label, key) in TARGET_LABELS" :key="key" :value="key">{{ label }}</option></SearchableSelect></label>
      <label>Biaya tambahan<select v-model="draft.cost_spec.type"><option value="none">Tanpa biaya tambahan</option><option value="skill_gauge">Skill Gauge</option></select></label>
      <label v-if="draft.cost_spec.type === 'skill_gauge'">Jumlah Skill Gauge<input v-model.number="draft.cost_spec.value" type="number" min="0" max="100" /></label>
      <label>Daftar efek JSON<textarea :value="rawEffects" rows="10" spellcheck="false" class="rule-json" @input="rawEffects = $event.target.value; rawEdited = true" /></label>
      <label>Status katalog<select v-model="draft.catalog_status"><option value="draft">Draft</option><option value="playtest">Playtest</option><option value="active">Aktif</option><option value="archived">Arsip</option></select></label>
      <label>Catatan perubahan versi<input v-model="draft.change_note" placeholder="Contoh: heal diturunkan setelah uji battle" /></label>
    </details>

    <section class="rule-readiness" :class="{ valid: !issues.length }" aria-live="polite">
      <strong>{{ issues.length ? 'Perlu dilengkapi sebelum aktif' : 'Konfigurasi lengkap' }}</strong>
      <ul v-if="issues.length"><li v-for="issue in issues" :key="issue">{{ issue }}</li></ul>
      <p v-else>Siap diaktifkan. Uji di battle tetap diperlukan untuk memeriksa keseimbangan dan kombinasi efek.</p>
    </section>
    <p v-if="localError" class="rule-error" role="alert">{{ localError }}</p>
    <p class="rule-hint">Perubahan berlaku pada battle baru. Battle yang sudah berjalan tetap memakai aturan awalnya.</p>
    <div class="rule-actions">
      <button v-if="draft.catalog_status !== 'active'" type="submit" class="rule-secondary" :disabled="saving">{{ draft.catalog_status === 'active' ? 'Simpan perubahan' : draft.catalog_status === 'playtest' ? 'Simpan Playtest' : draft.catalog_status === 'archived' ? 'Simpan arsip' : 'Simpan draft' }}</button>
      <button v-if="draft.catalog_status !== 'active'" type="button" class="rule-primary" :disabled="saving || issues.length > 0" @click="submit('active')">{{ saving ? 'Menyimpan…' : 'Simpan & aktifkan' }}</button>
      <button v-else type="button" class="rule-primary" :disabled="saving || issues.length > 0" @click="submit('active')">{{ saving ? 'Menyimpan…' : 'Simpan skill · versi berikutnya' }}</button>
    </div>
  </form>
</template>

<style scoped>
.rule-editor{--ink:#193b2d;--muted:#5b7565;--line:#d9e5d9;color:var(--ink);display:grid;gap:24px;min-width:0;padding:0 24px 24px;font-size:14px;line-height:1.55}
.rule-editor *{box-sizing:border-box;min-width:0}.rule-editor p{margin:0 0 14px;color:var(--muted)}.rule-editor small{font-size:12px;font-weight:400;color:var(--muted);line-height:1.5}.rule-editor label{display:grid;gap:6px;font-weight:650;margin:12px 0}.rule-editor input,.rule-editor textarea,.rule-editor select{width:100%;border:1px solid #cbdcca;border-radius:9px;padding:11px 12px;background:#fff;color:var(--ink);font:inherit;line-height:1.5}.rule-editor textarea{resize:vertical}.rule-editor :is(input,textarea,select,button,summary):focus-visible{outline:3px solid #87c7a6;outline-offset:2px}
.rule-preview{background:#eff7ee;border:1px solid #cbdcca;border-left:4px solid #298452;border-radius:12px;padding:18px}.rule-preview>strong{display:block;font-size:17px;margin:9px 0}.rule-preview ul{padding-left:18px;margin:10px 0}.rule-preview li+li{margin-top:6px}.rule-kicker{display:flex;flex-wrap:wrap;gap:8px;justify-content:space-between;font-size:10px;font-weight:800;letter-spacing:.1em}.rule-kicker span{font-weight:500;letter-spacing:0;font-size:11px;color:#8b671a}.rule-facts{display:flex;flex-wrap:wrap;gap:6px;margin-top:15px}.rule-facts span{border:1px solid #cfdfcf;border-radius:5px;padding:3px 8px;background:#fff;font-size:11px}
.rule-section{border:0;border-top:1px solid var(--line);padding:18px 0 0;margin:0}.rule-section legend{padding:0 8px 0 0;font-size:17px;font-weight:750}.rule-section legend span{display:inline-grid;place-items:center;border-radius:50%;background:#eaf1e8;width:26px;height:26px;margin-right:6px;font-size:12px}.rule-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:12px}.rule-details,.rule-template{border:1px solid var(--line);border-radius:10px;padding:12px}.rule-details summary,.rule-template summary{cursor:pointer;font-weight:700;padding:2px}.rule-template[open] summary,.rule-details[open] summary{margin-bottom:14px}.rule-template{background:#fafcf8}.rule-template small{display:block;margin-top:10px}.template-description{font-size:12px}.rule-target{border-left:3px solid #7c9bae;padding:4px 0 4px 12px;margin:18px 0;display:grid;gap:3px}.rule-target small{font-size:9px;letter-spacing:.08em}.rule-target span{font-size:12px}.rule-effect-group{display:grid;gap:10px;margin-top:14px}.rule-effect-group h4{margin:0;font-size:12px}.rule-operation{padding:14px;border:1px solid var(--line);border-radius:10px}.rule-operation>p{font-size:12px;margin:5px 0}.rule-operation label:last-child{margin-bottom:0}.rule-editor .rule-check{display:flex;align-items:center;gap:9px;font-weight:500}.rule-check input{width:17px;height:17px;flex-shrink:0;accent-color:#218748}.rule-media{display:flex;align-items:center;gap:10px}.rule-media :deep(img),.rule-media :deep(.skill-icon){width:46px;height:46px}.rule-media label{flex:1}.rule-json{font-family:monospace!important;font-size:12px!important}.rule-readiness{padding:16px;border-radius:10px;background:#fff8e9;border:1px solid #ebd8a5}.rule-readiness.valid{background:#f4f8f0;border-color:#d0e2c9}.rule-readiness ul{padding-left:18px;font-size:12px;margin:8px 0 0}.rule-readiness p{font-size:12px;margin:5px 0 0}.rule-error{color:#a83220!important}.rule-hint{font-size:12px;margin:0!important}.rule-actions{position:sticky;z-index:2;bottom:0;display:flex;gap:8px;flex-wrap:wrap;padding:12px 0 0;background:#fff;border-top:1px solid var(--line)}.rule-actions button{flex:1;min-width:120px}.rule-editor button{padding:11px 14px;border-radius:8px;font:inherit;font-size:12px;font-weight:750;cursor:pointer;line-height:1.4}.rule-primary{background:#0caf25;color:white;border:1px solid #0caf25}.rule-secondary{background:white;color:#215d3b;border:1px solid #bdd2be}.rule-editor button:disabled{opacity:.5;cursor:not-allowed}
@media(max-width:600px){.rule-editor{padding:0 14px 16px;gap:20px}}
</style>
