// One immutable geometry for all seven masters. Exact finished ratio: 63:88.
export const LAYOUT_VERSION = '7.1.1';
export const LAYOUT = Object.freeze({ width: 756, height: 1056,
  artwork: { x: 40, y: 49, width: 676, height: 525 },
  name: { x: 169, y: 576, width: 418, height: 96 },
  skills: [{ x: 35, y: 684, width: 686, height: 114 }, { x: 35, y: 810, width: 686, height: 111 }],
  fusion: { x: 30, y: 933, width: 696, height: 51 },
  tags: { x: 30, y: 984, width: 696, height: 47 },
  safe: 36,
});
// Inner rectangles exclude bevels, icons and chamfered panel ends. Preview and
// print validation share these bounds, including Type and every stat value.
export const TEXT_BOXES = Object.freeze({
  type: { x:611, y:57, width:107, height:39 },
  'attack-value': { x:129, y:43, width:90, height:45 },
  'attack-label': { x:139, y:90, width:70, height:24 },
  'hp-value': { x:118, y:502, width:91, height:40 },
  'hp-label': { x:140, y:547, width:48, height:21 },
  'defense-value': { x:625, y:502, width:80, height:40 },
  'defense-label': { x:637, y:547, width:58, height:21 },
  'card-code': { x:43, y:614, width:126, height:33 },
  name: { x:214, y:583, width:328, height:55 },
  'name-full': { x:214, y:584, width:328, height:78 },
  variant: { x:204, y:642, width:348, height:22 },
  rarity: { x:624, y:613, width:89, height:33 },
  'skill-1-name': { x:190, y:692, width:510, height:40 },
  'skill-1-body': { x:190, y:734, width:510, height:59 },
  'skill-2-name': { x:190, y:818, width:510, height:40 },
  'skill-2-body': { x:190, y:860, width:510, height:56 },
  'fusion-label': { x:115, y:944, width:149, height:28 },
  'tags-label': { x:115, y:995, width:149, height:28 },
  fusion: { x:285, y:944, width:427, height:28 },
  tags: { x:285, y:995, width:427, height:28 },
});
export const DEFAULT_PRINT = Object.freeze({ width: 63, height: 88, bleed: 3, dpi: 300, guides: true });
// Native 1024 × 1536 coordinates shared by rendering and print resolution checks.
export const EDITION_ARTWORK = Object.freeze({
  'Trial Join': { x: 0, y: 0, w: 1024, h: 1035 },
  Winning: { x: 36, y: 147, w: 952, h: 850 },
});
export function cardPrintSettings(card, options = {}) {
  const edition = ['Trial Join','Winning'].includes(card?.design_template);
  const width = options.width ?? DEFAULT_PRINT.width;
  return {...DEFAULT_PRINT,...options,width,height:Math.round(width*(edition?1.5:88/63)*1000)/1000,aspect:edition?'edition':'standard'};
}
export function printGeometry(options = {}) {
  const settings = { ...DEFAULT_PRINT, ...options };
  if (![settings.width, settings.height, settings.bleed, settings.dpi].every(Number.isFinite) ||
      settings.width < 30 || settings.width > 200 || settings.height < 40 || settings.height > 250 ||
      settings.bleed < 0 || settings.bleed > 10 || settings.dpi < 150 || settings.dpi > 600) {
    throw new Error('Ukuran cetak atau resolusi tidak valid.');
  }
  if (Math.abs(settings.width / settings.height - (settings.aspect==='edition'?2/3:63/88)) > .001) {
    throw new Error('Pertahankan rasio template agar kartu tidak terdistorsi.');
  }
  const widthMm = settings.width + settings.bleed * 2;
  const heightMm = settings.height + settings.bleed * 2;
  return { ...settings, widthMm, heightMm, widthPx: Math.round(widthMm / 25.4 * settings.dpi),
    heightPx: Math.round(heightMm / 25.4 * settings.dpi),
    bleedX: settings.bleed / settings.width * (settings.aspect==='edition'?704:LAYOUT.width),
    bleedY: settings.bleed / settings.height * LAYOUT.height };
}
