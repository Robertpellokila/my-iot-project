import { SKILL_DESCRIPTION_TEMPLATES, compileStudioSkill } from '../card-generator/cardSkillBattleRules.js';

export const cloneRule = value => JSON.parse(JSON.stringify(value));
export const TARGET_LABELS = {
  enemy_active: 'Kartu Active lawan', ally_active: 'Kartu Active milikmu',
  ally_field: 'Kartu Active atau Bench milikmu', self_card: 'Kartu pemilik skill ini',
  ally_graveyard: 'Base Card milikmu di Graveyard', enemy_active_or_bench: 'Kartu Active atau Bench lawan',
  self_player: 'Pemain sendiri', enemy_player: 'Pemain lawan',
};
export const OP_LABELS = {
  attack: 'Serangan normal + bonus damage', shield: 'Beri Shield', heal: 'Pulihkan HP',
  defense: 'Tambah DEF', reduction: 'Kurangi damage hit berikutnya', mark: 'Bonus serangan ally berikutnya',
  attack_reduction: 'Kurangi damage serangan target berikutnya', delayed_heal: 'Pulihkan HP di akhir giliran berikutnya',
  attack_buff: 'Tambah ATK', attack_debuff: 'Kurangi ATK', defense_debuff: 'Kurangi DEF',
  silence_slot2: 'Blokir skill kedua', cleanse: 'Hapus 1 debuff', switch: 'Tukar Active dengan Bench',
  root: 'Cegah switch sukarela', team_defense: 'Tambah DEF semua Active dan Bench', burn: 'Terapkan Burn',
  revive: 'Bangkitkan Base non-Fusion ke Bench',
};
export const CONDITION_LABELS = {
  always: 'Selalu', ally_bench: 'Ada ally di Bench', self_shield: 'Pemilik skill memiliki Shield',
  first_summon_action: 'Aksi pertama setelah summon', entered_active: 'Baru masuk Active',
  ally_summoned: 'Setelah summon ally', ally_switched: 'Setelah ally melakukan switch',
  self_switched: 'Pemilik skill baru melakukan switch', target_root: 'Target terkena Root',
  target_debuff: 'Target terkena debuff', target_no_shield: 'Target tanpa Shield',
  ally_low_hp: 'Ada ally dengan HP di bawah 50%', target_burn: 'Target terkena Burn', self_high_hp: 'HP pemilik skill di atas 50%',
};
export const EXPIRY_LABELS = { hit: 'sampai menerima 1 hit', attack: 'sampai serangan berikutnya', end: 'sampai akhir giliran', next_end: 'sampai akhir giliran berikutnya', next_start: 'sampai awal giliran berikutnya' };
export const EFFECT_LABELS = { damage_card: 'Damage kartu', heal_card: 'Pulihkan HP kartu', damage_player: 'Damage pemain', heal_player: 'Pulihkan HP pemain', add_skill_gauge: 'Tambah Skill Gauge', add_status: 'Terapkan status', move_zone: 'Pindahkan kartu', revive: 'Bangkitkan kartu', remove_status: 'Hapus status', set_card_exhausted: 'Ubah kelelahan kartu' };
export const RULE_TEMPLATES = SKILL_DESCRIPTION_TEMPLATES.map((skill, index) => ({ id: String(index), ...skill, rule: compileStudioSkill(skill) })).filter(item => item.rule.enabled);

// Replacing mechanics is explicit. Printed copy and identity never regenerate rules.
export function applyRuleTemplate(skill, template) {
  const next = cloneRule(skill), rule = cloneRule(template.rule);
  for (const key of ['activation_timing', 'source_zones', 'target_spec', 'cost_spec', 'limits', 'effects', 'consumes_turn']) next[key] = rule[key];
  next.skill_type = 'active';
  next.trigger_spec = { type: 'main_phase', label: 'Aktif manual pada main phase' };
  return next;
}

export function describeOperation(op) {
  let text = OP_LABELS[op.type] || `Efek tidak dikenali: ${op.type}`;
  if (op.type === 'revive') return `${text} dengan ${Math.round(Number(op.amount) * 100)}% Max HP. Attack/Skill terkunci hingga giliran berikutnya; penggunaan sekali per battle tetap terpakai.`;
  if (op.amount != null && !['cleanse', 'root', 'silence_slot2', 'burn'].includes(op.type)) text += ` ${op.amount}`;
  if (op.type === 'attack') text += ` (${op.multiplier ?? 1}× ATK; bonus: ${CONDITION_LABELS[op.condition] || op.condition})`;
  if (op.target === 'self') text += ' pada pemilik skill';
  if (op.expiry) text += ` · ${EXPIRY_LABELS[op.expiry] || op.expiry}`;
  if (op.type === 'switch') text += ' · tanpa menarik kartu';
  return text;
}

export function describeEffects(effects) {
  if (!Array.isArray(effects)) return [];
  return effects.flatMap(effect => {
    if (effect?.type === 'studio_skill') {
      const p = effect.program ?? {};
      return p.choices?.length ? p.choices.flatMap(c => (c.operations ?? []).map(op => `Pilih ${c.label}: ${describeOperation(op)}`)) : (p.operations ?? []).map(describeOperation);
    }
    const value = effect?.amount?.value ?? effect?.value;
    return [`${EFFECT_LABELS[effect?.type] || 'Efek tidak dikenali'}${value == null ? '' : ` ${value}`}${effect?.status_key ? ` · ${effect.status_key}` : ''}${effect?.duration_turns ? ` · ${effect.duration_turns} giliran` : ''}${effect?.to_zone ? ` → ${effect.to_zone}` : ''}${effect?.restore_hp ? ` · ${effect.restore_hp.value * 100}% Max HP` : ''}${effect?.target === 'source_card' ? ' · pemilik skill' : ''}`];
  });
}

const numberIn = (value, min, max, integer = true) => ['number', 'string'].includes(typeof value) && value !== '' && Number.isFinite(Number(value)) && Number(value) >= min && Number(value) <= max && (!integer || Number.isInteger(Number(value)));
const studioTargets = ['enemy_active', 'ally_field', 'ally_active', 'ally_graveyard', 'self_card'];
export function skillRuleIssues(skill = {}) {
  const issues = [], effects = skill.effects, limits = skill.limits ?? {}, target = skill.target_spec?.type;
  if (!String(skill.name ?? '').trim() || /^(https?:\/\/|data:|\/)/i.test(skill.name)) issues.push('Isi nama kemampuan, bukan URL gambar.');
  if (!String(skill.description ?? '').trim()) issues.push('Isi deskripsi singkat yang akan dibaca pemain.');
  if (skill.skill_type !== 'active' || (skill.trigger_spec?.type ?? skill.activation_timing) !== 'main_phase') issues.push('Battle mendukung skill manual pada Main phase. Pilih pola skill untuk menyiapkannya.');
  if (!Object.hasOwn(TARGET_LABELS, target ?? '')) issues.push('Tentukan target skill yang didukung.');
  if (!['none', 'skill_gauge'].includes(skill.cost_spec?.type)) issues.push('Biaya tambahan belum valid.');
  if (skill.cost_spec?.type === 'skill_gauge' && !numberIn(skill.cost_spec.value ?? skill.cost_spec.amount, 0, 100)) issues.push('Biaya Skill Gauge harus 0–100.');
  if (!numberIn(limits.action_points ?? 1, 1, 2)) issues.push('Biaya poin giliran harus 1 atau 2 AP.');
  for (const key of ['cooldown_turns', 'cooldown_rounds', 'cooldown', 'max_uses']) if (limits[key] != null && !numberIn(limits[key], 0, 999)) issues.push('Cooldown dan batas penggunaan harus bilangan bulat positif atau 0.');
  if (!Array.isArray(effects) || !effects.length) return [...issues, 'Belum ada efek battle. Pilih pola skill di bawah.'];
  if (effects.some(effect => effect?.type === 'studio_skill') && effects.length !== 1) issues.push('Aturan Studio harus menjadi satu paket efek; jangan gabungkan dengan efek legacy.');
  for (const effect of effects) {
    if (effect?.type === 'studio_skill') {
      const p = effect.program ?? {}, choices = p.choices ?? [];
      if (p.version !== 2) issues.push('Versi aturan Studio tidak didukung.');
      if (!studioTargets.includes(p.target) || p.target !== target) issues.push('Target di efek dan target skill harus sama.');
      if (!numberIn(p.max_targets ?? 1, 1, 2) || Number(p.max_targets ?? 1) !== Number(skill.target_spec?.max_targets ?? 1)) issues.push('Jumlah target di efek dan pilihan target harus sama (1–2).');
      if (!Array.isArray(choices) || !Array.isArray(p.operations)) { issues.push('Susunan efek atau pilihan efek tidak valid.'); continue; }
      if (choices.length && p.operations.length) issues.push('Gunakan efek langsung atau pilihan efek; keduanya tidak dijalankan bersamaan.');
      const ids = choices.map(c => c?.id);
      if (ids.some(id => !id) || new Set(ids).size !== ids.length || choices.some(c => !c?.label)) issues.push('Setiap pilihan efek memerlukan nama dan ID unik.');
      const targetChoices = skill.target_spec?.choices ?? [];
      if (!Array.isArray(targetChoices) || JSON.stringify(ids) !== JSON.stringify(targetChoices.map(c => c?.id))) issues.push('Pilihan efek pada target belum sesuai dengan aturan battle.');
      const groups = choices.length ? choices.map(c => c.operations) : [p.operations];
      for (const ops of groups) {
        if (!Array.isArray(ops) || !ops.length) { issues.push('Setiap pilihan harus memiliki minimal satu efek.'); continue; }
        if (ops.some(op => op?.type === 'attack') !== Boolean(p.attacks)) issues.push('Penanda serangan harus sesuai dengan efek serangan.');
        for (const op of ops) {
          if (!op || !Object.hasOwn(OP_LABELS, op.type)) { issues.push(`Jenis efek belum didukung: ${op?.type || 'kosong'}.`); continue; }
          if (op.type !== 'switch' && !numberIn(op.amount, op.type === 'revive' ? 0.01 : 0, op.type === 'revive' ? 1 : 999, op.type !== 'revive')) issues.push(`${OP_LABELS[op.type]}: nilai efek tidak valid.`);
          if (op.expiry && !Object.hasOwn(EXPIRY_LABELS, op.expiry)) issues.push('Masa berlaku efek tidak dikenal.');
          const requiredExpiry = { defense: 'hit', reduction: 'hit', attack_reduction: 'attack', delayed_heal: 'next_end', attack_buff: 'end', attack_debuff: 'next_end', defense_debuff: 'next_end', silence_slot2: 'next_end', team_defense: 'next_start' }[op.type];
          if (requiredExpiry && op.expiry !== requiredExpiry) issues.push(`${OP_LABELS[op.type]} memerlukan durasi ${EXPIRY_LABELS[requiredExpiry]}.`);
          if (op.target != null && op.target !== 'self') issues.push('Arah efek tambahan belum dikenali.');
          if (op.type === 'revive' && op.target) issues.push('Revive harus mengenai kartu Graveyard yang dipilih.');
          if (op.type === 'attack' && (!Object.hasOwn(CONDITION_LABELS, op.condition ?? '') || !numberIn(op.multiplier ?? 1, 0.01, 10, false))) issues.push('Syarat bonus atau pengali serangan tidak valid.');
          if (op.type === 'revive' && (target !== 'ally_graveyard' || Number(limits.action_points) !== 2 || limits.once_per_battle !== true)) issues.push('Revive membutuhkan target Graveyard, 2 AP, dan batas sekali per battle.');
          if (op.type === 'switch' && (target !== 'ally_active' || !skill.target_spec?.needs_bench)) issues.push('Switch membutuhkan target Active milikmu dan pilihan Bench.');
          if (['attack', 'mark', 'root', 'silence_slot2', 'burn', 'attack_reduction', 'attack_debuff', 'defense_debuff'].includes(op.type) && target !== 'enemy_active') issues.push(`${OP_LABELS[op.type]} harus menarget kartu Active lawan.`);
          if (['heal', 'shield', 'defense', 'reduction', 'cleanse', 'delayed_heal', 'attack_buff', 'team_defense'].includes(op.type) && op.target !== 'self' && !['ally_field', 'ally_active', 'self_card'].includes(target)) issues.push(`${OP_LABELS[op.type]} membutuhkan target milikmu.`);
        }
      }
    } else if (!Object.hasOwn(EFFECT_LABELS, effect?.type ?? '')) issues.push(`Jenis efek belum didukung: ${effect?.type || 'kosong'}.`);
    else {
      if (['target_card', 'selected_graveyard_card'].includes(effect.target) && ['self_player', 'enemy_player'].includes(target)) issues.push('Efek membutuhkan kartu yang dipilih, tetapi target skill masih pemain. Pilih target kartu yang sesuai.');
      if (effect.target === 'selected_graveyard_card' && target !== 'ally_graveyard') issues.push('Efek Graveyard membutuhkan pilihan kartu dari Graveyard.');
      if (['damage_card', 'heal_card', 'damage_player', 'heal_player', 'add_skill_gauge'].includes(effect.type) && (!effect.amount || !['fixed', 'source_attack_percent', 'target_base_hp_percent', 'source_base_hp_percent', 'target_max_hp_percent'].includes(effect.amount.mode) || !numberIn(effect.amount.value, 0, 999, false))) issues.push('Nilai atau perhitungan efek belum valid.');
      if (effect.type === 'add_status' && (!effect.status_key || !numberIn(effect.duration_turns, 1, 999))) issues.push('Status memerlukan jenis dan durasi minimal 1 giliran.');
      if (effect.type === 'revive' && (!effect.restore_hp || !numberIn(effect.restore_hp.value, 0.01, 1, false))) issues.push('Persentase HP revive harus lebih dari 0% hingga 100%.');
      if (['revive', 'move_zone'].includes(effect.type) && !['active', 'bench', 'graveyard', 'hand', 'deck'].includes(effect.to_zone)) issues.push('Tujuan perpindahan kartu belum valid.');
    }
  }
  return [...new Set(issues)];
}

export function auditSkillCatalog(cards, skills, links) {
  const bySkill = new Map(skills.map(s => [s.id, s]));
  return cards.filter(c => !c.archived_at).map(card => {
    const bindings = links.filter(l => l.game_card_id === card.id);
    const entries = bindings.map(link => {
      const skill = bySkill.get(link.special_skill_id);
      const issues = skill ? skillRuleIssues(skill) : ['Skill tertaut tidak ditemukan.'];
      if (link.enabled === false) issues.push('Tautan skill pada kartu nonaktif.');
      if (skill && (!skill.is_active || skill.catalog_status !== 'active')) issues.push('Skill belum berstatus Aktif.');
      return { skill, link, issues };
    });
    const expected = card.metadata?.studio_card?.skills?.length ?? card.metadata?.skills?.length ?? 0;
    return { card, entries, missing: Math.max(0, Math.max(1, expected) - bindings.length), ready: bindings.length >= Math.max(1, expected) && entries.every(e => !e.issues.length) };
  });
}
