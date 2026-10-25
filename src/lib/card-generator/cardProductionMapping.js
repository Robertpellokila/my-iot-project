export function compareProduction(dataset, records) {
  return dataset.cards.map(card => {
    const matches = records.filter(row => row.card_code === card.production_mapping.card_code || row.metadata?.source_card_code === card.card_code);
    return { card_code: card.card_code, production_code: card.production_mapping.card_code, matches: matches.length,
      differences: matches.map(row => {
        const expected = { name:card.name, rarity:card.rarity, ...card.stats };
        const actual = Object.fromEntries(Object.keys(expected).map(key => [key, row[key] ?? null]));
        const fields = Object.keys(expected).filter(key => key === 'rarity'
          ? String(actual[key]).toLowerCase() !== expected[key].toLowerCase()
          : String(actual[key]) !== String(expected[key]));
        return { id:row.id, fields, actual, expected };
      }),
      action: !matches.length ? 'review_new_definition' : 'review_conflicts_do_not_overwrite' };
  });
}
