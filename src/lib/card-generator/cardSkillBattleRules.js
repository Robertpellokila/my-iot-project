import { PILOT } from './cardSchema.js';
// The same constrained compiler builds editor previews and server rules.
// Unknown clauses are rejected as a whole, never activated partially.
export const SKILL_RULE_VERSION = 2;
export const SKILL_BEHAVIORS = [['auto', 'Ikuti deskripsi skill']];
const canonical = value => String(value ?? '').trim().replace(/\s+/g, ' ').replace(/[.;]+$/, '').toLowerCase();
const op = (type, amount, extra = {}) => ({ type, ...(amount == null ? {} : { amount }), ...extra });
const unsupported = reason => ({ version: SKILL_RULE_VERSION, behavior: 'auto', enabled: false, reason, effects: [] });
export const SKILL_DESCRIPTION_TEMPLATES = [...new Map(PILOT.cards.flatMap(card => card.skills.map(skill => [skill.description, {name:skill.name,description:skill.description}]))).values()];
const auditedDescriptions = new Set(SKILL_DESCRIPTION_TEMPLATES.map(skill => canonical(skill.description)));
export function compileStudioSkill(skill = {}) {
  const description = String(skill.description ?? '').trim();
  let text = canonical(description), cooldown = Number(text.match(/\bcd\s+(\d+)/)?.[1] ?? 0);
  text = text.replace(/\. cd \d+\b/i, '').replace(/[.;]+$/, '');
  let target = 'ally_field', operations = [], choices = [], attacks = false, exclusive = false;
  let once = false, ap = 1, maxTargets = 1, m;
  const match = expression => text.match(expression);
  if (!String(skill.name ?? '').trim() || !text) return unsupported('Isi nama dan deskripsi skill.');
  const simpleCustom = /^(?:pulihkan \d{1,3} hp pada 1 ally|beri shield \d{1,3} (?:ke|pada) 1 ally|\+\d{1,3} def pada diri sampai menerima 1 hit)(?:\. cd \d{1,2})?$/.test(canonical(description));
  if (!auditedDescriptions.has(canonical(description)) && !simpleCustom) return unsupported('Deskripsi belum didukung. Pilih pola skill atau atur efek khusus di Skill & Catalog.');
  if ((m = match(/^serangan normal ally berikutnya ke target mendapat \+(\d+) damage$/))) {
    target = 'enemy_active'; operations = [op('mark', Number(m[1]))];
  } else if (text.startsWith('serangan normal')) {
    attacks = true; target = 'enemy_active';
    const attack = op('attack', 0, { condition: 'always', multiplier: 1 });
    let rest = text.slice('serangan normal'.length).replace(/^;?\s*/, ''), secondary;
    if (/(?:dan )?menerapkan burn 1$/.test(rest)) {
      rest = rest.replace(/(?:dan )?menerapkan burn 1$/, '').trim(); secondary = op('burn', 1);
    }
    if (!rest) operations = [attack];
    else if ((m = rest.match(/^\+(\d+)$/))) { attack.amount = Number(m[1]); operations = [attack]; }
    else {
      const conditions = [
        [/^\+(\d+) damage jika ada ally di bench$/, 'ally_bench'],
        [/^\+(\d+) damage jika diri memiliki shield$/, 'self_shield'],
        [/^\+(\d+) damage pada aksi pertama setelah summon$/, 'first_summon_action'],
        [/^\+(\d+)(?: damage)? (?:jika|saat) baru masuk active$/, 'entered_active'],
        [/^\+(\d+) setelah kamu summon ally$/, 'ally_summoned'],
        [/^\+(\d+) setelah ally melakukan switch legal$/, 'ally_switched'],
        [/^\+(\d+) (?:setelah switch legal|jika baru melakukan switch)$/, 'self_switched'],
        [/^\+(\d+) jika baru berpindah dari bench$/, 'self_switched'],
        [/^\+(\d+) jika target sedang root$/, 'target_root'],
        [/^\+(\d+) jika target sedang terkena debuff$/, 'target_debuff'],
        [/^\+(\d+) pada target (?:yang tidak memiliki shield|tanpa shield)$/, 'target_no_shield'],
        [/^\+(\d+) jika ada ally di bawah 50% hp$/, 'ally_low_hp'],
        [/^\+(\d+) jika target memiliki burn$/, 'target_burn'],
        [/^\+(\d+) jika hp diri di atas 50%$/, 'self_high_hp'],
      ];
      for (const [expression, condition] of conditions) {
        if ((m = rest.match(expression))) { attack.amount = Number(m[1]); attack.condition = condition; operations = [attack]; break; }
      }
      if (!operations.length && /^(?:target tidak dapat melakukan switch sukarela sampai akhir turn berikutnya|cegah 1 switch sukarela target)$/.test(rest)) operations = [attack, op('root', 1)];
      if (!operations.length && (m = rest.match(/^\+(\d+) def pada diri sampai menerima 1 hit$/))) operations = [attack, op('defense', Number(m[1]), { target: 'self', expiry: 'hit' })];
      if (!operations.length && (m = rest.match(/^kurangi damage serangan target berikutnya sebesar (\d+)$/))) operations = [attack, op('attack_reduction', Number(m[1]), { expiry: 'attack' })];
    }
    if (operations.length && secondary) operations.push(secondary);
  } else if ((m = match(/^serang maks\. 2 target, masing-masing (0\.65)× atk$/))) {
    target = 'enemy_active'; maxTargets = 2; attacks = true; operations = [op('attack', 0, { condition: 'always', multiplier: Number(m[1]) })];
  } else if ((m = match(/^beri shield (\d+) (?:ke|pada) (1 ally|diri)(?:\. tidak dapat dipakai pada turn yang sama dengan cache restore)?$/))) {
    target = m[2] === 'diri' ? 'self_card' : 'ally_field'; exclusive = text.includes('cache restore'); operations = [op('shield', Number(m[1]))];
  } else if ((m = match(/^\+(\d+) def pada (diri|1 ally) sampai menerima 1 hit$/))) {
    target = m[2] === 'diri' ? 'self_card' : 'ally_field'; operations = [op('defense', Number(m[1]), { expiry: 'hit' })];
  } else if ((m = match(/^kurangi (\d+) damage dari hit berikutnya ke (diri|1 ally)$/))) {
    target = m[2] === 'diri' ? 'self_card' : 'ally_field'; operations = [op('reduction', Number(m[1]), { expiry: 'hit' })];
  } else if ((m = match(/^pulihkan (\d+) hp pada 1 ally$/))) operations = [op('heal', Number(m[1]))];
  else if ((m = match(/^pulihkan diri (\d+) hp pada akhir turn berikutnya$/))) {
    target = 'self_card'; operations = [op('delayed_heal', Number(m[1]), { expiry: 'next_end' })];
  } else if ((m = match(/^pulihkan (\d+) hp sekarang dan (\d+) hp pada akhir turn berikutnya$/))) operations = [op('heal', Number(m[1])), op('delayed_heal', Number(m[2]), { expiry: 'next_end' })];
  else if ((m = match(/^\+(\d+) atk pada 1 ally sampai akhir turn$/))) operations = [op('attack_buff', Number(m[1]), { expiry: 'end' })];
  else if ((m = match(/^kurangi (atk|def) target (\d+) sampai akhir turn berikutnya$/))) { target = 'enemy_active'; operations = [op(m[1] === 'atk' ? 'attack_debuff' : 'defense_debuff', Number(m[2]), { expiry: 'next_end' })]; }
  else if (text === 'target tidak dapat memakai skill 2 sampai akhir turn berikutnya') { target = 'enemy_active'; operations = [op('silence_slot2', 1, { expiry: 'next_end' })]; }
  else if (text === 'hapus 1 debuff biasa dari 1 ally') operations = [op('cleanse', 1)];
  else if ((m = match(/^hapus 1 debuff biasa dan pulihkan (\d+) hp pada 1 ally$/))) operations = [op('cleanse', 1), op('heal', Number(m[1]))];
  else if ((m = match(/^pilih: heal (\d+) pada 1 ally atau \+(\d+) def sampai 1 hit$/))) choices = [{ id: 'heal', label: `Pulihkan ${m[1]} HP`, operations: [op('heal', Number(m[1]))] }, { id: 'defense', label: `+${m[2]} DEF · 1 hit`, operations: [op('defense', Number(m[2]), { expiry: 'hit' })] }];
  else if ((m = match(/^pilih: heal (\d+) pada 1 ally atau cleanse 1 debuff$/))) choices = [{ id: 'heal', label: `Pulihkan ${m[1]} HP`, operations: [op('heal', Number(m[1]))] }, { id: 'cleanse', label: 'Hapus 1 debuff', operations: [op('cleanse', 1)] }];
  else if ((m = match(/^sekali\/battle pilih 1: heal (\d+), shield (\d+), atau \+(\d+) atk pada 1 ally sampai akhir turn$/))) {
    once = true; choices = [{ id: 'heal', label: `Pulihkan ${m[1]} HP`, operations: [op('heal', Number(m[1]))] }, { id: 'shield', label: `Shield ${m[2]}`, operations: [op('shield', Number(m[2]))] }, { id: 'attack', label: `+${m[3]} ATK · akhir giliran`, operations: [op('attack_buff', Number(m[3]), { expiry: 'end' })] }];
  } else if (/^switch (?:1 ally|posisi dengan 1 bench) sebagai aksi; tidak menarik kartu$/.test(text)) { target = 'ally_active'; operations = [op('switch')]; }
  else if (text === 'cegah 1 switch sukarela target sampai akhir turn berikutnya') { target = 'enemy_active'; operations = [op('root', 1)]; }
  else if ((m = match(/^active dan bench mendapat \+(\d+) def sampai awal turn berikutnya$/))) { target = 'self_card'; operations = [op('team_defense', Number(m[1]), { expiry: 'next_start' })]; }
  else if (text === canonical('Sekali/battle, saat NUL-006 Active, habiskan 2 AP: pilih 1 Base Card non-Fusion di Graveyard yang bukan fusion_consumed; kembalikan ke Bench dengan 40% Max HP. Kartu yang dibangkitkan tidak boleh Attack/Skill sampai turn berikutnya dan penggunaan once-per-battle tidak di-reset.')) {
    once = true; ap = 2; target = 'ally_graveyard'; operations = [op('revive', .4)];
  }
  if (!operations.length && !choices.length) return unsupported('Deskripsi belum didukung. Gunakan pola efek yang tersedia atau atur di Skill & Catalog.');
  if (cooldown > 20 || [...operations, ...choices.flatMap(c => c.operations)].some(item => item.amount > 999)) return unsupported('Nilai efek atau cooldown melampaui batas battle.');
  const program = { version: SKILL_RULE_VERSION, target, operations, choices, attacks, max_targets: maxTargets, exclusive };
  return { enabled: skill.battle?.enabled !== false, behavior: 'auto', version: SKILL_RULE_VERSION, program,
    activation_timing: 'main_phase', source_zones: ['active'], consumes_turn: false, cost_spec: { type: 'none' },
    target_spec: { type: target, required: target !== 'self_card', choices: choices.map(({ id, label }) => ({ id, label })), max_targets: maxTargets, needs_bench: operations.some(item => item.type === 'switch') },
    limits: { cooldown_turns: cooldown, action_points: ap, once_per_battle: once }, effects: [{ type: 'studio_skill', program }] };
}
export const withBattleRule = skill => ({ ...skill, battle: { ...compileStudioSkill(skill), ...(typeof skill.battle?.selection_enabled === 'boolean' ? {selection_enabled:skill.battle.selection_enabled} : {}) } });
export function battleRuleSummary(skill) {
  const rule = compileStudioSkill(skill);
  return rule.enabled ? `Siap battle · ${rule.limits.action_points} AP · CD ${rule.limits.cooldown_turns}${rule.limits.once_per_battle ? ' · sekali per battle' : ''}${rule.program.choices.length ? ' · pilih satu efek' : ''}` : rule.reason || 'Skill dinonaktifkan.';
}
