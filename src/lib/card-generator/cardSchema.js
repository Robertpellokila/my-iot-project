import source from '../../data/card-generator/pilot-v1.1.json' with { type: 'json' };

const freeze = value => {
  if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
};
export const PILOT = freeze(source);
export const CARD_BY_CODE = new Map(PILOT.cards.map(card => [card.card_code, card]));
export const RARITIES = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic'];
export const TYPES = PILOT.types;
export const templateFor = card => card.design_template || (card.kind === 'fusion' ? 'Fusion' : card.rarity);
export const canonicalCard = code => CARD_BY_CODE.get(code);
