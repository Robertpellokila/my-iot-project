// Presentation only: recipe matching and action requests keep the catalogue ID.
export function displayCardCode(card) {
  const candidates = [
    card?.display_code,
    card?.metadata?.studio_card?.display_code,
    card?.metadata?.source_card_code,
    card?.card_code,
    card?.metadata?.studio_card?.card_code,
  ];
  const code = candidates.find(value => typeof value === 'string' && value.trim())?.trim() ?? '';
  // Battle snapshots may not include Studio metadata. Strip only the generated
  // UUID suffix, preserving meaningful underscores in ordinary catalogue codes.
  return code.replace(/_STUDIO_[A-F0-9]{32}$/i, '');
}
