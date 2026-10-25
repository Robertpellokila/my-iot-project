import { RARITIES, TYPES, CARD_BY_CODE } from './cardSchema.js';
const validIdentity = input => /^DRAFT-[A-Z0-9-]{1,40}$/.test(input?.card_code ?? '') || (input?.source_pilot_code === input?.card_code && CARD_BY_CODE.has(input.card_code));
export const TEMPLATES = [...RARITIES, 'Fusion', 'Trial Join', 'Winning'];
const skillFrom = skill => {
  const name = String(skill?.name ?? ''), description = String(skill?.description ?? '');
  if (name.length > 200 || description.length > 6000) throw new Error('Teks skill melebihi batas workspace.');
  return { name, description, battle: skill?.battle && typeof skill.battle === 'object' ? skill.battle : undefined, source_text: `${name} — ${description}`,
    cooldown_turns: description.match(/CD (\d+)/)?.[1] ? Number(description.match(/CD (\d+)/)[1]) : null,
    ap_cost: description.match(/(\d+) AP/)?.[1] ? Number(description.match(/(\d+) AP/)[1]) : null,
    once_per_battle: /Sekali\/battle/.test(description), effect_clauses: description.split('; ') };
};
export function normalizeDraft(input) {
  if (!validIdentity(input)) throw new Error('Identitas draft tidak valid.');
  const text = (key, limit = 300) => {
    const value = String(input[key] ?? '');
    if (value.length > limit) throw new Error(`Data ${key} terlalu panjang.`);
    return value;
  };
  return { is_custom: true, card_code: input.card_code, display_code: text('display_code', 12),
    ...(input.source_pilot_code === input.card_code && CARD_BY_CODE.has(input.card_code) ? {source_pilot_code:input.card_code} : {}),
    ...(/^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i.test(input.source_game_card_id ?? '') ? {source_game_card_id:input.source_game_card_id} : {}),
    ...(input.source_catalog_code ? {source_catalog_code:text('source_catalog_code',300)} : {}),
    design_template: ['Trial Join','Winning'].includes(input.design_template) ? input.design_template : null,
    name: text('name'), subtitle: text('subtitle'), role: text('role'), serial_number:text('serial_number',32),
    kind: input.kind === 'fusion' ? 'fusion' : 'base', rarity: RARITIES.includes(input.rarity) ? input.rarity : 'Common',
    type: TYPES.includes(input.type) ? input.type : TYPES[0],
    stats: Object.fromEntries(['hp','attack','defense'].map(key => [key, input.stats?.[key] === '' ? '' : Number(input.stats?.[key] ?? 0)])),
    skills: [0, 1].map(index => skillFrom(input.skills?.[index])),
    tags: Array.isArray(input.tags) ? input.tags.map(tag => String(tag)).filter(Boolean).slice(0, 20) : [],
    fusion_data: text('fusion_data', 1500), source_fusions: [],
  };
}
export function createDraft(template, existing = []) {
  let index = 1;
  while (existing.some(card => card.card_code === `DRAFT-${String(index).padStart(3,'0')}`)) index++;
  return normalizeDraft({ card_code: `DRAFT-${String(index).padStart(3,'0')}`, display_code: `#${String(index).padStart(3,'0')}`,
    design_template:['Trial Join','Winning'].includes(template)?template:null,
    name: 'Kartu baru', kind: template === 'Fusion' ? 'fusion' : 'base', rarity: template === 'Winning' ? 'Mythic' : template === 'Trial Join' ? 'Common' : template === 'Fusion' ? 'Legendary' : template,
    stats: { hp:100, attack:30, defense:10 } });
}
export function validateDraft(card) {
  const errors = [], prefix = 'Kartu baru';
  if (!card.is_custom || !validIdentity(card)) errors.push('Identitas draft tidak valid.');
  for (const [key, label] of [['display_code','Kode cetak'], ['name','Nama'], ['role','Role']]) if (!String(card[key] ?? '').trim()) errors.push(`${prefix}: isi ${label}.`);
  if (!TYPES.includes(card.type) || !RARITIES.includes(card.rarity)) errors.push('Type / rarity tidak valid.');
  for (const key of ['hp','attack','defense']) if (!Number.isInteger(card.stats?.[key]) || card.stats[key] < 0 || card.stats[key] > 999 || (key === 'hp' && !card.stats[key])) errors.push(`${prefix}: ${key} harus bilangan bulat ${key === 'hp' ? '1' : '0'}–999.`);
  if (card.skills?.length !== 2 || card.skills.some(skill => !skill.name.trim() || !skill.description.trim())) errors.push('Isi nama dan efek untuk kedua skill.');
  if (card.kind === 'fusion' && !card.fusion_data.trim()) errors.push('Isi resep pada Fusion Data.');
  return errors;
}
