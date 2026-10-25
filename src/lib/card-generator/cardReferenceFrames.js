import editions from '../../data/card-generator/edition-frames.json' with { type: 'json' };
import frames from '../../data/card-generator/reference-frames.json' with { type: 'json' };

export function referenceFrameFor(card, template = card.design_template || (card.kind === 'fusion' ? 'Fusion' : card.rarity)) {
  if (editions[template]) return editions[template];
  if (template === 'Rare') return frames[card.type === 'Forest' ? 'rare-forest' : card.type === 'Knight' ? 'rare-knight' : 'rare-thunder'];
  return frames[{ Common: 'common', Uncommon: 'uncommon', Epic: 'epic' }[template]] ?? null;
}

export function themeForCard(card, template, themes) {
  const base = themes[template];
  if (template === 'Rare' && card.type === 'Forest') return { ...base, main:'#008527', dark:'#002b1c', light:'#f6ffe8', gem:'#77f438' };
  return base;
}

// Source PNGs are kept byte-for-byte. Only these decorative areas are visible;
// artwork, numbers, names, effects and footer values are rendered from card data.
export function referenceFrameClip(uid, template) {
  const ring = (outer, inner) => `<path fill-rule="evenodd" clip-rule="evenodd" d="${outer} ${inner}"/>`;
  return `<clipPath id="${uid}-reference-frame">
    ${ring('M0 0H756V1056H0Z', 'M39 49H719V684H729V1032H27V684H39Z')}
    ${template === 'Epic' ? '<path d="M378 0 414 31 378 61 342 31Z"/>' : ''}
    <path d="M568 597H709L730 617V647L709 668H565L582 646 591 624Z"/>
  </clipPath>
  ${template === 'Epic' ? `<clipPath id="${uid}-reference-gems"><path d="M378 0 414 31 378 61 342 31ZM378 526 418 558 378 592 338 558Z"/></clipPath>` : ''}`;
}
