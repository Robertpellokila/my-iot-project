import { RARITY_THEMES, TYPE_BADGES } from './cardRarityTheme.js';
import { fusionsFor, eligibleCodes, materialCombinations } from './cardFusionResolver.js';
import { textIssues, imageUrl, placement } from './cardRenderer.js';
import { LAYOUT, LAYOUT_VERSION, TEXT_BOXES, EDITION_ARTWORK, cardPrintSettings, printGeometry } from './cardLayoutTokens.js';
import { FIXED_BACK, fixedBackAvailable } from './cardBack.js';
import { validateDraft } from './cardDrafts.js';
import { referenceFrameFor } from './cardReferenceFrames.js';

export function validateDataset(dataset) {
  const errors = [];
  const cards = dataset.cards ?? [];
  const expected = dataset.id === 'tbc-pilot-v1.1-audited-necromancer' ? { base:30, fusion:12 } : dataset.expected_counts ?? { base:30, fusion:12 };
  if (cards.filter(card => card.kind === 'base').length !== expected.base) errors.push(`Dataset harus memiliki tepat ${expected.base} Base Card.`);
  if (cards.filter(card => card.kind === 'fusion').length !== expected.fusion) errors.push(`Dataset harus memiliki tepat ${expected.fusion} Fusion Card.`);
  if (new Set(cards.map(card => card.card_code)).size !== cards.length) errors.push('card_code duplikat.');
  for (const card of cards) {
    if (!/^(?:[A-Z]{3}-\d{3}|F\d{2})$/.test(card.card_code)) errors.push(`${card.card_code}: identitas tidak valid.`);
    if (!TYPE_BADGES[card.type] || !RARITY_THEMES[card.rarity]) errors.push(`${card.card_code}: Type / rarity tidak valid.`);
    if (!card.name || !card.role) errors.push(`${card.card_code}: identitas tidak lengkap.`);
    for (const key of ['hp', 'attack', 'defense']) {
      if (!Number.isInteger(card.stats?.[key]) || card.stats[key] < 0 || card.stats[key] > 999 || (key === 'hp' && !card.stats[key])) errors.push(`${card.card_code}: ${key} tidak valid.`);
    }
    if (card.skills?.length !== 2 || card.skills.some(skill => !skill.name || !skill.description || skill.source_text !== `${skill.name} — ${skill.description}`)) errors.push(`${card.card_code}: dua skill lengkap diperlukan.`);
    for (const skill of card.skills ?? []) {
      const cooldown = skill.description?.match(/CD (\d+)/);
      const ap = skill.description?.match(/(\d+) AP/);
      if (skill.cooldown_turns !== (cooldown ? Number(cooldown[1]) : null) ||
          skill.ap_cost !== (ap ? Number(ap[1]) : null) ||
          skill.once_per_battle !== /Sekali\/battle/.test(skill.description ?? '')) {
        errors.push(`${card.card_code}: cooldown / AP / batas penggunaan berbeda dari teks sumber.`);
      }
      if (!Array.isArray(skill.effect_clauses) || skill.effect_clauses.join('; ') !== skill.description) errors.push(`${card.card_code}: effect clauses tidak cocok dengan teks sumber.`);
    }
    if (card.kind === 'base') {
      const actual = fusionsFor(card, dataset.recipes, cards).map(recipe => recipe.id).sort();
      if (JSON.stringify(actual) !== JSON.stringify([...card.source_fusions].sort())) errors.push(`${card.card_code}: referensi Fusion berbeda dari dokumen.`);
    }
  }
  if (dataset.recipes?.length !== expected.fusion || new Set(dataset.recipes.map(recipe => recipe.id)).size !== expected.fusion) errors.push(`Tepat ${expected.fusion} resep unik diperlukan.`);
  for (const recipe of dataset.recipes ?? []) {
    if (!cards.some(card => card.card_code === recipe.result_code && card.kind === 'fusion')) errors.push(`${recipe.id}: hasil Fusion tidak ditemukan.`);
    if (!['EXACT', 'ONE_OF', 'TAG'].includes(recipe.mode)) errors.push(`${recipe.id}: mode tidak valid.`);
    if (recipe.slots.length !== (recipe.id === 'F12' ? 3 : 2)) errors.push(`${recipe.id}: jumlah material tidak sesuai.`);
    for (const slot of recipe.slots) {
      if (!['EXACT', 'ONE_OF', 'TAG'].includes(slot.mode) || !slot.eligible_codes.length) errors.push(`${recipe.id}: slot tidak valid.`);
      if (slot.mode === 'EXACT' && slot.eligible_codes.length !== 1) errors.push(`${recipe.id}: EXACT harus spesifik.`);
      if (slot.mode === 'TAG' && !/^fusion:[A-Z_]+$/.test(slot.tag)) errors.push(`${recipe.id}: tag Fusion tidak valid.`);
      if (eligibleCodes(slot, cards).length !== slot.eligible_codes.length) errors.push(`${recipe.id}: material tidak legal / tag tidak cocok.`);
    }
    if (!materialCombinations(recipe, cards).length) errors.push(`${recipe.id}: tidak dapat dibuat dari pool pilot.`);
  }
  const necro = cards.find(card => card.card_code === 'NUL-006');
  const limits = necro?.necro_recall;
  if (!limits || !limits.once_per_battle || limits.ap_cost !== 2 || limits.requires_caster_zone !== 'active' || limits.material_kind !== 'base' || limits.allow_fusion || limits.allow_fusion_consumed || limits.destination !== 'bench' || limits.max_hp_ratio !== .4 || !limits.attack_skill_locked_until_next_turn || limits.reset_once_per_battle) errors.push('Guardrail Necro Recall tidak lengkap.');
  return errors;
}

// A receipt is bound to this exact data, artwork version, placement, and layout.
export function renderSignature(card, artwork) {
  return JSON.stringify({ card, layout: LAYOUT_VERSION,
    layers: ['background', 'character', 'foreground'].map(key => {
      const layer = artwork?.[key];
      return layer ? { url: layer.url, hash: layer.sha256, width: layer.width, height: layer.height, ...placement(layer), fit: layer.fit } : null;
    }), skill_icons: [0,1].map(index => {
      const layer = artwork?.skill_icons?.[index];
      return layer ? { url:layer.url, hash:layer.sha256, width:layer.width, height:layer.height, ...placement(layer), fit:layer.fit } : null;
    }), reference_frame: referenceFrameFor(card)?.sha256 ?? null, back: FIXED_BACK.sha256 || FIXED_BACK.id });
}

export function artworkPrintResolution(card, character, print = {}) {
  const settings = printGeometry(cardPrintSettings(card, print));
  const edition = EDITION_ARTWORK[card.design_template];
  const widthMm = settings.width * (edition ? edition.w / 1024 : LAYOUT.artwork.width / LAYOUT.width);
  const heightMm = settings.height * (edition ? edition.h / 1536 : LAYOUT.artwork.height / LAYOUT.height);
  const dimensionsValid = [character?.width, character?.height].every(value => Number.isFinite(value) && value > 0);
  // Cover crops the longer dimension; contain scales the entire image to fit.
  const pixelsPerMm = dimensionsValid
    ? (character.fit === 'contain' ? Math.max : Math.min)(character.width / widthMm, character.height / heightMm)
    : 0;
  const dpi = pixelsPerMm * 25.4 / placement(character).scale;
  return { dpi, targetDpi: settings.dpi, sufficient: dpi + 1e-6 >= settings.dpi, widthMm, heightMm };
}

export function artworkResolutionIssue(card, character, print = {}) {
  const resolution = artworkPrintResolution(card, character, print);
  return resolution.sufficient ? null : `Resolusi artwork efektif ${Math.floor(resolution.dpi)} DPI; perlu ${resolution.targetDpi} DPI pada ukuran cetak dan zoom ini.`;
}

export function cardReadiness(card, dataset, artwork = {}, back = {}, print = {}) {
  const errors = [];
  const text = textIssues(card, dataset);
  const character = artwork.character;
  if (!imageUrl(character?.url)) errors.push('Artwork Missing');
  else {
    if (artwork.approval_status !== 'approved') errors.push('Artwork Draft');
    if (!character.sha256 || !character.width || !character.height) errors.push('Artwork belum diverifikasi.');
    const resolutionIssue = artworkResolutionIssue(card, character, print);
    if (resolutionIssue) errors.push(resolutionIssue);
    if (artwork.asset_status !== 'verified') errors.push('Asset perlu diperiksa ulang.');
  }
  if (!fixedBackAvailable()) errors.push('Gambar back referensi belum terpasang.');
  else if (back.asset_status !== 'verified') errors.push('Gambar back tetap perlu diverifikasi.');
  if (artwork.render_receipt !== renderSignature(card, { ...artwork, back })) errors.push('Pemeriksaan render diperlukan.');
  for (const [index, icon] of (artwork.skill_icons ?? []).entries()) if (icon) {
    if (!imageUrl(icon.url) || !/^[a-f0-9]{64}$/.test(icon.sha256 ?? '') || icon.width < 128 || icon.height < 128) errors.push(`Ikon Skill ${index + 1} memerlukan gambar terverifikasi minimal 128 × 128 px.`);
    if (artwork.asset_status !== 'verified') errors.push(`Ikon Skill ${index + 1} perlu diverifikasi.`);
  }
  const datasetErrors = card.is_custom ? validateDraft(card) : validateDataset(dataset);
  if (datasetErrors.length) errors.push(...datasetErrors);
  return { ready: !errors.length && !text.length, errors: [...errors, ...text], dataVerified: !datasetErrors.length,
    status: datasetErrors.length || text.length ? 'Validation Error' : !character?.url ? 'Artwork Missing' : artwork.approval_status !== 'approved' ? 'Artwork Draft' : !errors.length ? 'Ready for Print' : 'Artwork Approved' };
}

export function validateRenderedSvg(svg) {
  const errors = [];
  const context = document.createElement('canvas').getContext('2d');
  for (const element of svg.querySelectorAll('[data-text-box]')) {
    let box = element.getBBox();
    const label = element.getAttribute('data-text-box');
    const editionBounds = String(element.getAttribute('data-panel-bounds')??'').split(',').map(Number);
    const bounds = TEXT_BOXES[label] ?? (label.startsWith('edition-') && editionBounds.length===4 && editionBounds.every(Number.isFinite) ? {x:editionBounds[0],y:editionBounds[1],width:editionBounds[2],height:editionBounds[3]} : null);
    if (!bounds) { errors.push(`${label}: batas panel belum ditentukan.`); continue; }
    if (element.getAttribute('data-text-overflow') === 'true') errors.push(`${label}: teks terlalu panjang untuk panel.`);
    if (!element.getNumberOfChars()) continue;
    if (context) {
      // Check visible ink vertically; getBBox includes font leading. Horizontal
      // SVG bounds include the actual anchor, tracking and textLength adjustment.
      const style = getComputedStyle(element);
      context.font = `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
      const pad = Number(element.getAttribute('stroke-width') || 0) / 2;
      const lines = [...element.querySelectorAll('tspan')];
      let top = Infinity, bottom = -Infinity;
      for (const line of lines.length ? lines : [element]) {
        if (!line.getNumberOfChars()) continue;
        const baseline = line.getStartPositionOfChar(0).y;
        const metrics = context.measureText(line.textContent);
        top = Math.min(top,baseline-metrics.actualBoundingBoxAscent-pad);
        bottom = Math.max(bottom,baseline+metrics.actualBoundingBoxDescent+pad);
      }
      box = { x:box.x-pad, y:top, width:box.width+pad*2, height:bottom-top };
    }
    if (box.x < bounds.x-.5 || box.x+box.width > bounds.x+bounds.width+.5 || box.y < bounds.y-.5 || box.y+box.height > bounds.y+bounds.height+.5) errors.push(`${label}: teks melewati ruang panel.`);
  }
  return [...new Set(errors)];
}
