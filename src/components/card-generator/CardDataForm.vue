<script setup>
import { TEMPLATES } from '../../lib/card-generator/cardDrafts.js';
import { TYPES, RARITIES, templateFor } from '../../lib/card-generator/cardSchema.js';
import { RARITY_THEMES } from '../../lib/card-generator/cardRarityTheme.js';
import CardSkillIconUpload from './CardSkillIconUpload.vue';
import { SKILL_DESCRIPTION_TEMPLATES, battleRuleSummary } from '../../lib/card-generator/cardSkillBattleRules.js';
const props = defineProps({ card: Object, artwork: Object, busy: Boolean });
const emit = defineEmits(['update','upload','remove','icon-fit']);
const change = patch => emit('update', patch);
const changeTemplate = value => change(['Trial Join','Winning'].includes(value) ? {design_template:value,kind:'base'} : {design_template:null,kind:value==='Fusion'?'fusion':'base',rarity:value==='Fusion'?'Legendary':value});
const changeSkill = (index, key, value) => change({ skills: props.card.skills.map((skill, i) => i === index ? { ...skill, [key]: value } : skill) });
const changeSkillTemplate = (index, description) => {if(description)changeSkill(index,'description',description);};
</script>
<template>
  <form class="cg-data-form" @submit.prevent>
    <section class="cg-form-section">
      <fieldset :disabled="busy">
        <legend>Template kartu</legend>
        <div class="cg-rarity-options" role="group" aria-label="Template rarity">
          <button v-for="item in TEMPLATES" :key="item" type="button" :style="{ '--rarity-color': RARITY_THEMES[item].main }" :aria-pressed="templateFor(card) === item" @click="changeTemplate(item)">
            <i aria-hidden="true"></i><span>{{ item }}</span><span class="cg-rarity-check" aria-hidden="true">✓</span>
          </button>
        </div>
        <p class="cg-field-hint">Pilih bingkai rarity atau edisi khusus.</p><label v-if="card.design_template" class="cg-field">Rarity kartu<select :value="card.rarity" @change="change({rarity:$event.target.value})"><option v-for="rarity in RARITIES" :key="rarity">{{ rarity }}</option></select></label>
      </fieldset>
    </section>

    <section class="cg-form-section">
      <fieldset :disabled="busy">
        <legend>Identitas kartu</legend>
        <div class="cg-form-fields">
          <div class="cg-form-pair">
            <label class="cg-field">Kode cetak
              <input :value="card.display_code" maxlength="12" placeholder="#001" required @input="change({ display_code: $event.target.value })" />
            </label>
            <label class="cg-field">Type
              <select aria-label="Type" :value="card.type" @change="change({ type: $event.target.value })"><option v-for="type in TYPES" :key="type">{{ type }}</option></select>
            </label>
          </div>
          <label class="cg-field">Nama karakter / Fusion
            <input :value="card.name" maxlength="150" placeholder="Coby" required @input="change({ name: $event.target.value })" />
          </label>
          <label class="cg-field"><span>Nama varian <small aria-hidden="true">Opsional</small></span>
            <input aria-label="Nama varian" :value="card.subtitle" maxlength="150" placeholder="Circuit Buddy" @input="change({ subtitle: $event.target.value })" />
          </label>
          <label v-if="card.design_template === 'Winning'" class="cg-field">Nomor seri <small>Opsional</small><input :value="card.serial_number" maxlength="32" placeholder="CH006-S1-014" @input="change({serial_number:$event.target.value})" /></label>
          <label class="cg-field">Role
            <input :value="card.role" maxlength="150" placeholder="Guardian, Support, Striker…" required @input="change({ role: $event.target.value })" />
          </label>
        </div>
      </fieldset>
    </section>

    <section class="cg-form-section">
      <fieldset :disabled="busy">
        <legend>Statistik</legend>
        <div class="cg-form-stats">
          <label v-for="[key,label] in [['attack','ATK'],['hp','HP'],['defense','DEF']]" :key="key" class="cg-field" :data-stat="key">{{ label }}
            <input type="number" inputmode="numeric" :value="card.stats[key]" :min="key === 'hp' ? 1 : 0" max="999" step="1" required @input="change({ stats: { ...card.stats, [key]: $event.target.value === '' ? '' : Number($event.target.value) } })" />
          </label>
        </div>
      </fieldset>
    </section>

    <section v-for="(skill,index) in card.skills" :key="index" class="cg-form-section cg-skill-input">
      <fieldset :disabled="busy">
        <legend>Skill {{ index + 1 }}</legend>
        <div class="cg-form-fields">
          <label class="cg-field">Nama skill
            <input :value="skill.name" maxlength="200" :placeholder="index === 0 ? 'Contoh: Spark Link' : 'Contoh: Banner Cover'" required @input="changeSkill(index, 'name', $event.target.value)" />
          </label>
          <label class="cg-field">Efek skill
            <textarea :value="skill.description" rows="4" maxlength="6000" placeholder="Tulis efek lengkap, termasuk CD dan biaya AP jika ada." required @input="changeSkill(index, 'description', $event.target.value)"></textarea>
          </label>
          <label class="cg-field">Pola efek battle
            <select value="" @change="changeSkillTemplate(index, $event.target.value)">
              <option value="">Pilih pola efek…</option>
              <option v-for="item in SKILL_DESCRIPTION_TEMPLATES" :key="item.description" :value="item.description">{{ item.name }} · {{ item.description }}</option>
            </select>
          </label>
          <p class="cg-field-hint">{{ skill.battle?.authority==='custom'?'Aturan kustom tersimpan. Buka tab Aturan skill untuk mengubah efek, AP, atau cooldown.':battleRuleSummary(skill) }}. Aturan ini ikut disalin saat kartu dihubungkan ke RFID.</p>
        </div>
        <CardSkillIconUpload :index="index" :asset="artwork.skill_icons?.[index]" :busy="busy" @upload="file => emit('upload',file,`skill-${index+1}-icon`)" @remove="emit('remove',`skill-${index+1}-icon`)" @fit="fit => emit('icon-fit',index,fit)" />
      </fieldset>
    </section>

    <section class="cg-form-section">
      <fieldset :disabled="busy">
        <legend>Fusion &amp; tag</legend>
        <div class="cg-form-fields">
          <label class="cg-field">{{ card.kind === 'fusion' ? 'Ringkasan Fusion untuk cetak' : 'Fusion Data' }}
            <textarea :value="card.fusion_data" rows="2" maxlength="1500" :required="card.kind === 'fusion'" :placeholder="card.kind === 'fusion' ? 'COB-006 + TOC-006' : 'F01 (EXACT: TOC-006)'" @input="change({ fusion_data: $event.target.value })"></textarea>
          </label>
          <p v-if="card.kind==='fusion'" class="cg-field-hint">Atur material EXACT, ONE TAG, dan ONE OF di tab Resep Fusion.</p>
          <div>
            <label class="cg-field">TAG
              <input :value="card.tags.join(', ')" maxlength="300" placeholder="VINE, GUARD" @change="change({ tags: $event.target.value.split(',').map(tag => tag.trim()).filter(Boolean) })" />
            </label>
            <p class="cg-field-hint">Pisahkan setiap tag dengan koma.</p>
          </div>
        </div>
      </fieldset>
    </section>
    <p class="cg-form-note">Preview mengikuti perubahan data. Teks yang melebihi ruang kartu akan ditandai sebelum dicetak.</p>
  </form>
</template>
