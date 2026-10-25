import { renderCardSvg } from './cardRenderer.js';
import { printGeometry, cardPrintSettings } from './cardLayoutTokens.js';
import { cardReadiness, validateRenderedSvg, validateDataset } from './cardValidationService.js';
import { verifyAsset } from './cardArtworkService.js';
import { pngWithDensity } from './pngDensity.js';
import { FIXED_BACK, fixedBackAvailable } from './cardBack.js';
import { validateDraft } from './cardDrafts.js';
import { referenceFrameFor } from './cardReferenceFrames.js';

const blobDataUrl = blob => new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = reject; reader.readAsDataURL(blob); });
export function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob); const link = document.createElement('a');
  link.href = url; link.download = name; link.click(); setTimeout(() => URL.revokeObjectURL(url), 30000);
}
export function checkExport(card, dataset, artwork, back, proof) {
  if (validateDataset(dataset).length) throw new Error('Dataset tidak valid; perbaiki sebelum ekspor.');
  if (card.is_custom && validateDraft(card).length) throw new Error(validateDraft(card).join(' '));
  if (!proof && !cardReadiness(card, dataset, artwork, back).ready) throw new Error(`${card.card_code} belum Ready for Print. Gunakan proof untuk review.`);
}
export async function embeddedArtwork(artwork, back, cache = new Map(), frame = null) {
  const embed = async asset => {
    if (!asset?.url) return null;
    if (!cache.has(asset.sha256)) cache.set(asset.sha256, blobDataUrl(await verifyAsset(asset)));
    return { ...asset, url: await cache.get(asset.sha256) };
  };
  return { ...artwork, background: await embed(artwork.background), character: await embed(artwork.character), foreground: await embed(artwork.foreground),
    skill_icons: await Promise.all([0,1].map(index => embed(artwork.skill_icons?.[index]))),
    reference_frame: await embed(frame), back: { ...back, image: fixedBackAvailable() ? await embed(FIXED_BACK) : null } };
}
export function inspectSvg(markup) {
  const host = document.createElement('div');
  Object.assign(host.style, { position: 'fixed', top: '0', left: '-10000px', width: '756px', visibility: 'hidden' });
  host.innerHTML = markup; document.body.append(host);
  try { return validateRenderedSvg(host.querySelector('svg')); } finally { host.remove(); }
}
export async function svgForExport(card, dataset, artwork, back, options = {}, cache) {
  checkExport(card, dataset, artwork, back, options.proof);
  await document.fonts.ready;
  const embedded = await embeddedArtwork(artwork, back, cache, options.side === 'back' ? null : referenceFrameFor(card, options.template));
  const svg = renderCardSvg(card, dataset, embedded, { ...options, bleed: true });
  if (!options.proof && options.side !== 'back' && inspectSvg(svg).length) throw new Error('Teks melewati ruang aman cetak.');
  return svg;
}
export async function rasterizeSvg(markup, settings) {
  const geometry = printGeometry(settings);
  const canvas = document.createElement('canvas'); canvas.width = geometry.widthPx; canvas.height = geometry.heightPx;
  const context = canvas.getContext('2d'); if (!context) throw new Error('Canvas tidak tersedia.');
  const url = URL.createObjectURL(new Blob([markup], { type: 'image/svg+xml' }));
  try {
    const image = new Image();
    await new Promise((resolve, reject) => { image.onload = resolve; image.onerror = () => reject(new Error('Komposisi SVG tidak dapat diraster.')); image.src = url; });
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error('PNG tidak dapat dibuat.')), 'image/png'));
    return { blob: await pngWithDensity(blob, geometry.dpi), dataUrl: canvas.toDataURL('image/png'), width: canvas.width, height: canvas.height };
  } finally { URL.revokeObjectURL(url); }
}

// Back-side column mirroring for duplex long-edge; short-edge mirrors rows.
export function sheetPositions(count, settings, flip = 'long-edge', back = false) {
  const p = printGeometry(settings), gap = 3;
  const columns = Math.max(1, Math.floor((210 - 20 + gap) / (p.widthMm + gap)));
  const rows = Math.max(1, Math.floor((297 - 20 + gap) / (p.heightMm + gap)));
  if (p.widthMm > 190 || p.heightMm > 277) throw new Error('Ukuran kartu melebihi area cetak A4.');
  const originX = (210 - (columns * p.widthMm + (columns - 1) * gap)) / 2;
  const originY = (297 - (rows * p.heightMm + (rows - 1) * gap)) / 2;
  return Array.from({ length: count }, (_, index) => {
    const cell = index % (columns * rows), row = Math.floor(cell / columns), column = cell % columns;
    const c = back && flip === 'long-edge' ? columns - 1 - column : column;
    const r = back && flip === 'short-edge' ? rows - 1 - row : row;
    return { page: Math.floor(index / (columns * rows)), x: originX + c * (p.widthMm + gap), y: originY + r * (p.heightMm + gap), width: p.widthMm, height: p.heightMm };
  });
}
export async function exportCards(cards, dataset, workspace, options, progress = () => {}) {
  if (!cards.length) throw new Error('Pilih minimal satu kartu.');
  if (!options.proof) {
    const hashes = Object.values(workspace.artworks).map(art => art.character?.sha256).filter(Boolean);
    if (new Set(hashes).size !== hashes.length) throw new Error('Artwork karakter duplikat; setiap kartu memerlukan ilustrasi unik.');
  }
  const geometry = printGeometry(cardPrintSettings(cards[0],options.print)), cache = new Map();
  const side = options.side ?? 'front';
  const sides = side === 'both' ? ['front', 'back'] : [side];
  const extension = options.format === 'svg' ? 'svg' : 'png';
  const entries = []; let done = 0;
  for (const card of cards) {
    const artwork = workspace.artworks[card.card_code];
    const print = cardPrintSettings(card,options.print);
    for (const cardSide of sides) {
      const svg = await svgForExport(card, dataset, artwork, workspace.back, { ...options, side: cardSide }, cache);
      const png = options.format !== 'svg' ? await rasterizeSvg(svg, print) : null;
      entries.push({ card, side: cardSide, svg, png, print, geometry:printGeometry(print) }); progress(++done / (cards.length * sides.length));
    }
  }
  const prefix = options.proof ? 'PROOF-' : '';
  if (options.format === 'pdf' || options.format === 'sheet') {
    const { jsPDF } = await import('jspdf');
    const sheet = options.format === 'sheet';
    const pdf = new jsPDF({ unit: 'mm', format: sheet ? 'a4' : [geometry.widthMm, geometry.heightMm], orientation: geometry.widthMm > geometry.heightMm && !sheet ? 'landscape' : 'portrait', compress: true });
    pdf.setProperties({ title: `${prefix}TBC pilot v1.1`, subject: 'Template aspect ratio preserved; configured bleed; raster composition at selected DPI' });
    if (sheet) {
      const groups = [...new Set(entries.map(entry=>entry.print.aspect))].map(aspect=>cards.filter(card=>cardPrintSettings(card).aspect===aspect));
      let pageIndex = 0;
      for (const group of groups) {
        const print=cardPrintSettings(group[0],options.print);
        const front=sheetPositions(group.length,print),rear=sheetPositions(group.length,print,options.flip??'long-edge',true);
        const pages=Math.max(...front.map(position=>position.page))+1;
        for(let page=0;page<pages;page++)for(const cardSide of sides){
          if(pageIndex++)pdf.addPage('a4','portrait');
          group.forEach((card,index)=>{const position=(cardSide==='back'?rear:front)[index];if(position.page!==page)return;
            const entry=entries.find(value=>value.card.card_code===card.card_code&&value.side===cardSide);
            pdf.addImage(entry.png.dataUrl,'PNG',position.x,position.y,position.width,position.height,undefined,'FAST');
          });
          pdf.setFontSize(7);pdf.setTextColor(90);pdf.text(`TBC | ${cardSide} | 100% scale | ${print.width} x ${print.height} mm | duplex ${options.flip??'long-edge'} | ${options.proof?'PROOF - NOT FOR PRINT':'print master'}`,10,291);
        }
      }
    } else entries.forEach((entry, index) => {
      if (index) pdf.addPage([entry.geometry.widthMm, entry.geometry.heightMm], entry.geometry.widthMm > entry.geometry.heightMm ? 'landscape' : 'portrait');
      pdf.addImage(entry.png.dataUrl, 'PNG', 0, 0, entry.geometry.widthMm, entry.geometry.heightMm, undefined, 'FAST');
    });
    return { blob: pdf.output('blob'), name: `${prefix}TBC-${sheet ? 'A4-duplex' : cards.length === 1 ? cards[0].card_code : 'selected-cards'}.pdf` };
  }
  if (entries.length === 1) return { blob: options.format === 'svg' ? new Blob([entries[0].svg], { type: 'image/svg+xml' }) : entries[0].png.blob,
    name: `${prefix}${entries[0].card.card_code}-${entries[0].side}.${extension}` };
  const { default: JSZip } = await import('jszip'); const zip = new JSZip();
  for (const entry of entries) zip.file(`${prefix}${entry.card.card_code}-${entry.side}.${extension}`, options.format === 'svg' ? entry.svg : entry.png.blob);
  zip.file('print-settings.json', JSON.stringify({ ...geometry, cards:cards.map(card=>({code:card.card_code,...cardPrintSettings(card,options.print)})), proof: options.proof, dataset: dataset.id }, null, 2));
  return { blob: await zip.generateAsync({ type: 'blob' }), name: `${prefix}TBC-pilot-${entries.length}-sides.zip` };
}
