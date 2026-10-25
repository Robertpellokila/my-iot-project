export function eligibleCodes(slot, cards) {
  return cards.filter(card => card.kind === 'base' && slot.eligible_codes.includes(card.card_code) &&
    (slot.mode !== 'TAG' || card.tags.includes(slot.tag))).map(card => card.card_code);
}

// Match every slot to a distinct material instance; material order is irrelevant.
export function validateMaterials(recipe, materials, cards) {
  if (!recipe || materials.length !== recipe.slots.length) return false;
  const identities = materials.map((material, index) => typeof material === 'string' ? index : material.instance_id ?? material.card_code);
  if (new Set(identities).size !== materials.length) return false;
  const match = (index, used) => {
    if (index === recipe.slots.length) return true;
    const eligible = eligibleCodes(recipe.slots[index], cards);
    return materials.some((material, materialIndex) => {
      const code = typeof material === 'string' ? material : material.card_code;
      if (used.has(materialIndex) || !eligible.includes(code)) return false;
      return match(index + 1, new Set([...used, materialIndex]));
    });
  };
  return match(0, new Set());
}

export function materialCombinations(recipe, cards) {
  const expand = (index, selected) => index === recipe.slots.length
    ? [selected]
    : eligibleCodes(recipe.slots[index], cards).flatMap(code => expand(index + 1, [...selected, code]));
  return expand(0, []).filter(codes => new Set(codes).size === codes.length && validateMaterials(recipe, codes, cards));
}

export const fusionsFor = (card, recipes, cards) => recipes.filter(recipe =>
  recipe.slots.some(slot => eligibleCodes(slot, cards).includes(card.card_code)));

export function fusionOverview(card, recipes, cards) {
  if (card.kind === 'fusion') return ['Premium Fusion · 2 AP', 'Material legal: lihat resep lengkap di generator.'];
  const options = fusionsFor(card, recipes, cards);
  if (!options.length) return ['—'];
  return [...new Set(options.flatMap(recipe => recipe.slots.flatMap((slot, occupied) =>
    eligibleCodes(slot, cards).includes(card.card_code)
      ? [`${recipe.id} · ${recipe.slots.filter((_, index) => index !== occupied).map(partner => eligibleCodes(partner, cards).join('/')).join(' + ')}`]
      : [])))];
}
