import { isSkillImage } from './skillState.js';

export const splitSkillIcon = value => {
  const icon = String(value ?? '').trim();
  return isSkillImage(icon) ? { imageUrl: icon, symbol: '✦' } : { imageUrl: '', symbol: icon || '✦' };
};
export function skillMediaValue(imageUrl, symbol = '✦') {
  const image = String(imageUrl ?? '').trim();
  if (image && !isSkillImage(image)) throw new Error('URL gambar skill harus berupa https://… atau path gambar /images/….');
  const fallback = String(symbol ?? '').trim();
  if (fallback && (fallback.length > 32 || /https?:|data:|javascript:|\//i.test(fallback))) throw new Error('Gunakan simbol singkat untuk ikon pengganti. Masukkan URL pada Gambar skill.');
  return image || fallback || '✦';
}
export function skillLimitLabel(skill) {
  const limits = skill?.limits ?? {};
  const ownerTurns = Object.hasOwn(limits, 'cooldown_turns');
  const cooldown = Number(ownerTurns ? limits.cooldown_turns : limits.cooldown_rounds ?? limits.cooldown ?? 0) || 0;
  return cooldown ? `${cooldown} ${ownerTurns ? 'giliran pemilik' : 'ronde'}` : 'Tanpa cooldown';
}
export const skillOptionLabel = skill => `${skill.name || 'Skill tanpa nama'}${skill.description ? ` — ${String(skill.description).slice(0,100)}` : ''}`;
export function describeBasicSkill({type, amount, target, actionPoints=1, cooldown=0, cooldownUnit='owner', once=false, endsTurn=false}) {
  const targets = {enemy_active:'1 kartu Active lawan',ally_active:'1 kartu Active milikmu',ally_field:'1 kartu Active atau Bench milikmu',self_card:'kartu ini',self_player:'HP pemainmu',enemy_player:'pemain lawan',ally_graveyard:'1 kartu milikmu di Graveyard'};
  const subject = targets[target] || target || 'target yang dipilih';
  const value = Math.max(0, Number(amount) || 0);
  const actions = {damage_card:`Berikan ${value} damage pada ${subject}.`,heal_card:`Pulihkan ${value} HP pada ${subject}, maksimal hingga HP penuh.`,damage_player:`Berikan ${value} damage langsung pada ${target==='self_player'?'pemainmu':'pemain lawan'}.`,heal_player:`Pulihkan ${value} HP ${target==='enemy_player'?'pemain lawan':'pemainmu'}, maksimal hingga HP penuh.`,add_skill_gauge:`Tambah ${value} poin Skill Gauge untuk ${target==='enemy_player'?'pemain lawan':'pemainmu'}.`};
  const names = {damage_card:'Serangan Terarah',heal_card:'Pemulihan Sahabat',damage_player:'Serangan Langsung',heal_player:'Semangat Pulih',add_skill_gauge:'Dorongan Energi'};
  if (!actions[type]) return null;
  return { name: names[type], description: `${actions[type]} Biaya ${actionPoints} AP.${Number(cooldown)>0 ? ` Cooldown ${cooldown} ${cooldownUnit==='owner'?'giliran pemilik':'ronde'}.` : ''}${once?' Hanya sekali per battle.':''}${endsTurn?' Mengakhiri giliran.':''}` };
}
