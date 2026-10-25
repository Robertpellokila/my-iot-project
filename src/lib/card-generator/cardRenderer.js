import {renderEdition,editionTextIssues,EDITION_TEMPLATES} from './cardEditionTemplates.js';
import { LAYOUT, cardPrintSettings, LAYOUT_VERSION, TEXT_BOXES, printGeometry } from './cardLayoutTokens.js';
import { RARITY_THEMES, TYPE_BADGES } from './cardRarityTheme.js';
import { fitText, textWidth } from './cardTextFitter.js';
import { fusionsFor, eligibleCodes } from './cardFusionResolver.js';
import { FIXED_BACK, fixedBackAvailable } from './cardBack.js';
import { referenceFrameFor, referenceFrameClip, themeForCard } from './cardReferenceFrames.js';

export const escapeXml = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[char]));
export const imageUrl = value => /^(https?:\/\/|blob:|data:image\/(png|webp|jpeg);base64,|\/(?!\/))/i.test(value ?? '') ? value : '';
const number = (value, fallback, min, max) => Number.isFinite(Number(value)) ? Math.max(min, Math.min(max, Number(value))) : fallback;
export const placement = value => ({ x: number(value?.x, 0, -300, 300), y: number(value?.y, 0, -220, 220), scale: number(value?.scale, 1, .3, 3) });
export function cardIdentity(card) {
  const [name, ...variant] = card.name.split(/\s+—\s+/);
  return { name: name.toUpperCase(), variant: variant.join(' — ') || card.subtitle || '' };
}
export function footerData(card, dataset) {
  if (card.is_custom) return card.fusion_data || '—';
  if (card.kind === 'fusion') {
    const recipe = dataset.recipes.find(item => item.result_code === card.card_code);
    return recipe ? `${recipe.mode}: ${recipe.slots.map(slot => slot.eligible_codes.join('/')).join(' + ')}` : '—';
  }
  const options = fusionsFor(card, dataset.recipes, dataset.cards);
  // Like the supplied template, multi-recipe cards list result IDs in the footer.
  // Every complete recipe remains visible in properties and the audited dataset.
  if (options.length > 1) return options.map(recipe => recipe.id).join(', ');
  return options.map(recipe => {
    const partners = recipe.slots.filter(slot => !eligibleCodes(slot, dataset.cards).includes(card.card_code));
    return `${recipe.id} (${recipe.mode}: ${partners.map(slot => slot.eligible_codes.join('/')).join(' + ')})`;
  }).join(' · ') || '—';
}
export function cardTextLayout(card, dataset) {
  const identity = cardIdentity(card);
  const variant = identity.variant.toUpperCase();
  const nameFont = { weight:900, family:'Arial Black, Arial' };
  const singleName = fitText(identity.name,315,1,variant ? [60,54,48,42,36,30,26,22] : [60,54,48,42,36,30],nameFont);
  return {
    code: fitText(card.display_code || card.card_code, 122, 1, [25, 23, 21, 19, 17, 15], { weight:800 }),
    name: !variant && singleName.overflow ? fitText(identity.name,315,2,[30,28,26,24,22],nameFont) : singleName,
    variant: fitText(variant, 340, 1, [21, 19, 17, 15], { weight:700, spacing:2 }),
    skills: card.skills.map(skill => {
      const oneLine = fitText(skill.description,500,1,[24,23,22]);
      const normal = oneLine.overflow ? fitText(skill.description, 500, 2, [24, 23, 22]) : oneLine;
      const body = normal.overflow ? fitText(skill.description, 500, 3, [19]) : normal;
      return { title: fitText(skill.name, 500, 1, [34, 31, 28, 25], { weight:900, family:'Arial Black, Arial' }), body };
    }),
    fusion: fitText(footerData(card, dataset), 423, 1, [22, 20, 18, 16]),
    tags: fitText(card.tags.map(tag => tag.replace(/^fusion:/, '')).join(', ') || '—', 423, 1, [22, 20, 18, 16]),
  };
}
export function textIssues(card, dataset) {
  if(EDITION_TEMPLATES.includes(card.design_template)) return editionTextIssues(card);
  const fit = cardTextLayout(card, dataset);
  return [fit.code.overflow && 'Kode cetak terlalu panjang', fit.name.overflow && 'Nama terlalu panjang', fit.variant.overflow && 'Nama varian terlalu panjang', ...fit.skills.flatMap((skill, index) => [skill.title.overflow && `Judul Skill ${index + 1} terlalu panjang`, skill.body.overflow && `Skill ${index + 1} melebihi ruang aman cetak`]), fit.fusion.overflow && 'Ringkasan Fusion terlalu panjang', fit.tags.overflow && 'Tag terlalu panjang'].filter(Boolean);
}
function textBlock(block, x, y, options = {}) {
  if (!block.lines.length) return '';
  const { fill = '#071e14', weight = 400, anchor = 'start', lineHeight = 1.06, label = '', spacing = 0, display = false, extra = '', uid } = options;
  const bounds = TEXT_BOXES[label];
  return `<text data-text-box="${escapeXml(label)}" ${block.overflow ? 'data-text-overflow="true"' : ''} ${bounds && uid ? `clip-path="url(#${uid}-text-${label})"` : ''} x="${x}" y="${y}" fill="${fill}" font-size="${block.size}" font-weight="${weight}" text-anchor="${anchor}" letter-spacing="${spacing}" ${display ? 'font-family="Arial Black, Arial, sans-serif"' : ''} ${extra}>${block.lines.map((line,index) => {
    const width = textWidth(line,block.size,{weight,family:display ? 'Arial Black, Arial' : 'Arial',spacing});
    const limit = Math.min(block.width ?? Infinity,bounds?.width ?? Infinity);
    // Store the measured advance in the SVG too, so opening an export with a
    // fallback font cannot make the line grow beyond its original panel.
    const constrain = !block.overflow && width > 0 ? ` textLength="${Math.min(width,limit).toFixed(3)}" lengthAdjust="spacingAndGlyphs"` : '';
    return `<tspan x="${x}" dy="${index ? block.size * lineHeight : 0}"${constrain}>${escapeXml(line)}</tspan>`;
  }).join('')}</text>`;
}
const ICONS = {
  sword: 'M-11 18-18 11-11 4-17-2-12-7-7-2 9-20 22-23 20-10 2 7 7 12 2 17-4 11Z',
  heart: 'M0 19C-8 12-21 2-21-8-21-24-3-25 0-13 4-25 21-24 21-8 21 2 8 12 0 19Z',
  shield: 'M0-23C7-19 14-17 21-17V1C21 13 9 22 0 28-9 22-21 13-21 1V-17C-14-17-7-19 0-23Z',
  leaf: TYPE_BADGES.Forest.path,
  flame: 'M1-25C8-10 21-6 19 9 18 28-18 29-20 10-23-3-9-11-9-20-5-9-6-1 1 4 6-4 7-13 1-25Z',
  star: 'M0-21 6-7 22-6 10 5 14 22 0 14-14 22-10 5-22-6-6-7Z',
  tag: 'M-18-18H3L21 0 0 21-18 3ZM-9-10a4 4 0 1 0 0 .1Z',
  data: 'M-17-21H17V20H-17ZM-11-12H11V-8H-11ZM-11-3H11V1H-11ZM-11 6H4V10H-11Z',
};
const icon = (name,x,y,scale=1,fill='white',extra='') => `<path d="${ICONS[name] ?? ICONS.star}" transform="translate(${x} ${y}) scale(${scale})" fill="${fill}" fill-rule="evenodd" ${extra}/>`;
// Shared symbols for every rarity and edition; only their placement and size vary.
function statIcon(kind,x,y,scale,uid) {
  const symbol = {attack:'sword',hp:'heart',defense:'shield'}[kind];
  const fill = {attack:'stat-blade',hp:'lime',defense:'ice'}[kind];
  const stroke = {attack:'#b91e32',hp:'#268b06',defense:'#0876b0'}[kind];
  const facet = kind === 'attack' ? '<path d="M9-20 22-23 20-10 2 7-3 2Z" fill="white"/><path d="M-17-2-12-7 7 12 2 17Z" fill="#ff7893"/>' : kind === 'hp' ? '<path d="M0-13C-3-25-21-24-21-8-21 2-8 12 0 19Z" fill="#d0ff04" opacity=".3"/>' : '<path d="M0-23V28C9 22 21 13 21 1V-17C14-17 7-19 0-23Z" fill="#006ac1" opacity=".3"/>';
  return `<g data-stat-icon="${kind}" transform="translate(${x} ${y}) scale(${scale})">${icon(symbol,0,0,1,`url(#${uid}-${fill})`,`stroke="${stroke}" stroke-width="1" stroke-linejoin="round"`)}${facet}</g>`;
}
function typeIcon(type,x,y,size) {
  const badge = TYPE_BADGES[type];
  return `<svg data-type-icon="${escapeXml(type)}" x="${x-size/2}" y="${y-size/2}" width="${size}" height="${size}" viewBox="-24 -24 48 48" overflow="hidden"><path d="${badge?.path ?? ICONS.star}" transform="scale(${type==='Forest'?1:1.4})" fill="${badge?.color ?? '#637385'}" fill-rule="evenodd"/></svg>`;
}
// Straight chamfers and separate inset plates reproduce the reference's stamped metal edges.
const plate = (x,y,w,h,cut=20) => `M${x+cut} ${y}H${x+w-cut}L${x+w} ${y+cut}V${y+h-cut}L${x+w-cut} ${y+h}H${x+cut}L${x} ${y+h-cut}V${y+cut}Z`;
const ribbon = (x,y,w,h,cut=30) => `M${x+cut} ${y}H${x+w-cut}L${x+w} ${y+h/2} ${x+w-cut} ${y+h}H${x+cut}L${x} ${y+h/2}Z`;
function bevel(path,inner,uid,edge='silver',outline=4) {
  return `<path d="${path}" fill="url(#${uid}-${edge})" stroke="#06110c" stroke-width="${outline}" stroke-linejoin="round"/><path d="${inner}" fill="none" stroke="#ffffffc9" stroke-width="1.5" stroke-linejoin="round"/>`;
}
function frameArmor(theme,template,uid) {
  let result = `<rect width="756" height="1056" rx="31" fill="url(#${uid}-silver)"/>
    <path d="M20 124V51Q20 20 51 20H129L153 0H602L627 20H706Q736 20 736 51V124L756 144V500L736 521V574L756 595V776L736 797V882L756 903V1007Q756 1033 733 1036H627L602 1056H153L129 1036H49Q20 1036 20 1007V929L0 910V598L20 577V522L0 502V145Z" fill="url(#${uid}-armor)" stroke="#06140a" stroke-width="5"/>
    <path d="M26 123V52Q26 26 52 26H131L156 6H600L625 26H705Q730 26 730 52V123M26 930V1006Q26 1030 50 1030H131L156 1050H600L625 1030H705Q730 1030 730 1006V930" fill="none" stroke="${theme.gem}" stroke-width="3"/>
    <path d="M132 23 157 0H602L627 23 606 38H151Z" fill="url(#${uid}-armor)" stroke="#081c0c" stroke-width="4"/>
    <path d="M157 1H600L579 20H174ZM143 24l18-17h36l-17 17ZM594 24l-16-17h22l16 17Z" fill="${theme.gem}" opacity=".65"/>
    <path d="M26 40H730V1028H26Z" fill="url(#${uid}-facets)"/>
    <g fill="url(#${uid}-silver)" stroke="#07110a" stroke-width="2"><path d="M0 31Q0 0 31 0H148L127 19H52Q20 19 20 52V109L0 127Z"/><path d="M756 31Q756 0 725 0H608L629 19H704Q736 19 736 52V109L756 127Z"/><path d="M0 1025Q0 1056 31 1056H148L127 1037H52Q20 1037 20 1004V947L0 929Z"/><path d="M756 1025Q756 1056 725 1056H608L629 1037H704Q736 1037 736 1004V947L756 929Z"/>
    <path d="M0 503 20 522V577L0 599ZM756 503l-20 19V577l20 22ZM0 777l20 20V883L0 904ZM756 777l-20 20V883l20 21Z"/></g>
    <g fill="${theme.gem}" stroke="#061b0b" stroke-width="2"><path d="M0 147 19 127V178L0 198ZM756 147l-19-20V178l19 20ZM0 228l19-20v49L0 277ZM756 228l-19-20v49l19 20ZM0 599l19 19V675L0 657ZM756 599l-19 19V675l19-18ZM0 911l19 19v49L0 960ZM756 911l-19 19v49l19-19Z"/></g>`;
  // Distinct, integrated material details; all information panels keep identical anchors.
  if (template === 'Uncommon') result += `<path d="M9 319 17 311V459L9 467M747 319l-8-8V459l8 8" fill="${theme.gem}"/><path d="m348 18 15 13 15-13 15 13 15-13" fill="none" stroke="${theme.metal}" stroke-width="2"/>`;
  if (template === 'Rare') result += `<path d="M7 316 17 304V476L7 487ZM749 316l-10-12V476l10 11Z" fill="${theme.gem}"/><path d="m340 14 17 11 21-11 21 11 17-11" fill="none" stroke="${theme.metal}" stroke-width="3"/>`;
  if (template === 'Epic') result += `<g fill="${theme.gem}" stroke="${theme.metal}" stroke-width="1.5"><path d="m378 5 14 14-14 15-14-15ZM342 13l7 7-7 7-7-7ZM414 13l7 7-7 7-7-7Z"/></g><path d="M11 308v180M745 308v180" stroke="${theme.gem}" stroke-width="4" stroke-dasharray="40 9 6 9"/>`;
  if (template === 'Legendary') result += `<g fill="none" stroke="${theme.metal}" stroke-width="2"><path d="M304 12q19 29 43 7l31 14 31-14q24 22 43-7M11 305q15 28 0 56 15 28 0 56 15 28 0 56M745 305q-15 28 0 56-15 28 0 56-15 28 0 56"/></g>${icon('star',378,20,.55,theme.metal)}`;
  if (template === 'Mythic') result += `<path d="M9 300v192M747 300v192M165 8H591M165 1048H591" stroke="url(#${uid}-prism)" stroke-width="6"/><path d="m355 8 23 24 23-24-23 7Z" fill="url(#${uid}-prism)" stroke="${theme.light}" stroke-width="1.5"/>`;
  if (template === 'Fusion') result += `<path d="m350 9 18 19 18-19 18 19M11 300l8 19-8 19 8 19-8 19 8 19-8 19M745 300l-8 19 8 19-8 19 8 19-8 19 8 19" fill="none" stroke="${theme.metal}" stroke-width="4"/><path d="M10 442v42M746 442v42" stroke="${theme.gem}" stroke-width="5"/>`;
  return `<g data-frame-material="${template}">${result}</g>`;
}
function skillOrb(card,index,cy,uid,asset) {
  const badge = TYPE_BADGES[card.type] ?? TYPE_BADGES.Forest;
  if (imageUrl(asset?.url)) {
    const pos = placement(asset);
    return `<g transform="translate(107 ${cy})" data-skill-icon="custom"><circle r="58" fill="#06160e" stroke="#ebffc9" stroke-width="2"/><g clip-path="url(#${uid}-icon-circle)"><image data-skill-icon-image="${index+1}" href="${escapeXml(imageUrl(asset.url))}" x="-53" y="-53" width="106" height="106" preserveAspectRatio="xMidYMid ${asset.fit === 'contain' ? 'meet' : 'slice'}" transform="translate(${pos.x} ${pos.y}) scale(${pos.scale})"/></g><circle r="54" fill="none" stroke="#112a18" stroke-width="2"/></g>`;
  }
  let rays = '';
  for (let angle=0;angle<360;angle+=30) rays += `<path d="M-3-12-1-51 4-51 3-12Z" transform="rotate(${angle})" fill="#d7ff8a" opacity=".18"/>`;
  const attackSymbol = card.type === 'Forest' ? 'leaf' : card.type === 'Knight' ? 'sword' : card.type === 'Fire' ? 'flame' : null;
  let symbol;
  if (index === 0) {
    const main = attackSymbol ? icon(attackSymbol,0,0,1.5,'#eaffba','stroke="#173e08" stroke-width="1.5"') : `<path d="${badge.path}" transform="scale(2)" fill="#f7ffe3"/>`;
    symbol = main;
  } else if (/heal|Pulihkan/i.test(card.skills[index].description)) {
    symbol = icon('leaf',0,0,1.8,'#eaffd8') + '<path d="M-6-17H6V-6H17V6H6V17H-6V6H-17V-6H-6Z" fill="#fff9cf"/>';
  } else {
    symbol = icon('shield',0,-3,1.6,'#efffda','stroke="#c9ff8a" stroke-width="1"') + icon('shield',0,-2,1.22,'#096d18') + `<path d="${card.type === 'Forest' ? ICONS.leaf : badge.path}" transform="translate(0 2) scale(.9)" fill="white"/>`;
  }
  return `<g transform="translate(107 ${cy})" data-skill-icon="${index ? 'support' : card.type.toLowerCase()}"><circle r="58" fill="#06160e" stroke="#ebffc9" stroke-width="2"/><circle r="52" fill="url(#${uid}-${index ? 'support-orb' : 'attack-orb'})" stroke="#0b2e13" stroke-width="2"/>${rays}${symbol}<path d="M-43-20A48 48 0 0 1-10-46" fill="none" stroke="#dfff8d" stroke-width="2" opacity=".7"/></g>`;
}
export function renderCardSvg(card,dataset,artwork={},options={}) {
  const template = options.template ?? card.design_template ?? (card.kind === 'fusion' ? 'Fusion' : card.rarity);
  const theme = themeForCard(card,template,RARITY_THEMES);
  if (!theme) throw new Error('Master rarity tidak ditemukan.');
  const badge = TYPE_BADGES[card.type] ?? TYPE_BADGES.Knight;
  const fit = cardTextLayout(card,dataset), p = printGeometry(cardPrintSettings({...card,design_template:template},options.print));
  const { height:H,artwork:art } = LAYOUT;
  const W = EDITION_TEMPLATES.includes(template) ? 704 : LAYOUT.width;
  const uid = `cg-${String(card.card_code).replace(/[^a-zA-Z0-9_-]/g, '-')}-${template.replace(/\s+/g, '-')}-${options.side ?? 'front'}`;
  const text = (block,x,y,options={}) => textBlock(block,x,y,{...options,uid});
  const singleText = (value,label,x,y,sizes,options={}) => text(fitText(value,TEXT_BOXES[label].width-2,1,sizes,{weight:options.weight ?? 700,family:options.display ? 'Arial Black, Arial' : 'Arial'}),x,y,{weight:700,...options,label});
  const reference = referenceFrameFor(card,template);
  const frameUrl = reference && artwork.reference_frame?.sha256 === reference.sha256 && /^data:image\/(png|webp);base64,/.test(artwork.reference_frame?.url ?? '') ? artwork.reference_frame.url : reference?.url;
  const gradient = (name,colors,radial=false) => `<${radial ? 'radialGradient' : 'linearGradient'} id="${uid}-${name}" ${radial ? '' : 'x1="0" y1="0" x2="1" y2="1"'}>${colors.map((color,index)=>`<stop offset="${index/(colors.length-1)}" stop-color="${color}"/>`).join('')}</${radial ? 'radialGradient' : 'linearGradient'}>`;
  const metal = ['Legendary','Fusion'].includes(template) ? [theme.light,theme.metal,'#9b6e1c',theme.light,theme.metal] : ['#fbfdfa','#bcc2bd','#f8faf4','#959d98','#e9ece7'];
  const defs = `<defs>
    ${gradient('gold',['#fff5bb','#e9b633','#fff0a5','#a36b0a','#fff4c4'])}${gradient('silver',metal)}${gradient('armor',[theme.gem,theme.main,theme.dark,theme.main,theme.gem])}${gradient('name',[theme.main,theme.dark,'#001c15',theme.dark])}
    ${gradient('body',['#fffef8','#fffff5',theme.light])}${gradient('ivory',['#ffffff','#fffef0','#e7ebde'])}${gradient('paper',['#fff8dd','#f0e3b7','#fff9e8'])}
    ${gradient('red',['#ff3748','#ef0729','#ab001b'])}${gradient('green',[theme.dark,theme.dark,'#00180c'])}${gradient('hp-green',['#003b19','#002211','#00180c'])}${gradient('blue',['#003657','#001b38','#00344f'])}
    ${gradient('stat-blade',['#ffffff','#ffe8ec','#ffbccb'])}${gradient('lime',['#c3ff00','#4df000'])}${gradient('ice',['#35cfff','#0093e1'])}${gradient('label',template==='Common' ? ['#878d86','#464b48','#8b9188'] : [theme.gem,theme.main,theme.dark])}
    ${gradient('prism',['#8eefff','#d7bbe9','#f8df8b','#8edbd8'])}${gradient('attack-orb',[card.type==='Forest' ? '#78e600' : badge.color,'#16580a','#001b0c'],true)}${gradient('support-orb',['#6bff2a','#009a14','#00220e'],true)}
    <pattern id="${uid}-facets" patternUnits="userSpaceOnUse" width="112" height="84"><path d="M0 0H112L56 42Z" fill="white" opacity=".07"/><path d="M0 0 56 42 0 84Z" fill="#001208" opacity=".18"/><path d="M56 42 112 84H0Z" fill="black" opacity=".08"/></pattern>
    <pattern id="${uid}-panel-lines" width="170" height="130" patternUnits="userSpaceOnUse"><g stroke="${theme.gem}" stroke-width="11" stroke-linecap="round" opacity=".24"><path d="m42 2-25 25M158-12 58 88M187 17 87 117M128 110l-29 29"/></g></pattern>
    <clipPath id="${uid}-art"><path d="${plate(40,49,676,525,22)}"/></clipPath>
    <clipPath id="${uid}-icon-circle"><circle r="53"/></clipPath>
    ${Object.entries(TEXT_BOXES).map(([label,box])=>`<clipPath id="${uid}-text-${label}"><rect x="${box.x}" y="${box.y}" width="${box.width}" height="${box.height}"/></clipPath>`).join('')}
    ${reference ? referenceFrameClip(uid,template) : ''}
    ${LAYOUT.skills.map((box,index)=>`<clipPath id="${uid}-skill-${index}"><rect x="190" y="${box.y+8}" width="514" height="${box.height-13}"/></clipPath>`).join('')}
    <clipPath id="${uid}-panels">${LAYOUT.skills.map(box=>`<rect x="${box.x}" y="${box.y}" width="${box.width}" height="${box.height}" rx="29"/>`).join('')}</clipPath>
    <filter id="${uid}-shadow" x="-.1" y="-.2" width="1.2" height="1.5"><feDropShadow dx="0" dy="2" stdDeviation="1.4" flood-color="#00120b" flood-opacity=".9"/></filter>
  </defs>`;
  const layerImage = (asset,index) => {
    const url = imageUrl(asset?.url); if (!url) return '';
    const transform = placement(asset), cx = art.x+art.width/2, cy=art.y+art.height/2;
    return `<image data-art-layer="${index}" href="${escapeXml(url)}" x="${art.x}" y="${art.y}" width="${art.width}" height="${art.height}" preserveAspectRatio="xMidYMid ${asset.fit==='contain' ? 'meet' : 'slice'}" transform="translate(${cx+transform.x} ${cy+transform.y}) scale(${transform.scale}) translate(${-cx} ${-cy})"/>`;
  };
  const layers = ['background','character','foreground'].map((key,index)=>layerImage(artwork[key],index)).join('');
  const artContent = !imageUrl(artwork.character?.url) ? `<rect x="40" y="49" width="676" height="525" fill="${theme.dark}"/><rect x="40" y="49" width="676" height="525" fill="url(#${uid}-facets)"/><path d="m378 232 44 27v51l-44 27-44-27v-51Z" fill="none" stroke="${theme.gem}" stroke-width="1.5"/><text x="378" y="376" text-anchor="middle" font-size="20" fill="${theme.light}" letter-spacing="1">UPLOAD ILUSTRASI KARTU</text><text x="378" y="408" text-anchor="middle" font-size="16" fill="${theme.metal}">${escapeXml(card.card_code)} · PNG / WebP tanpa teks</text>` : '';
  const skills = LAYOUT.skills.map((box,index)=>`<g data-anchor="skill-${index+1}">
    <rect x="${box.x}" y="${box.y+3}" width="${box.width}" height="${box.height}" rx="29" fill="#03230f" opacity=".75"/>
    <rect x="${box.x}" y="${box.y}" width="${box.width}" height="${box.height}" rx="29" fill="url(#${uid}-body)" stroke="#e6cb46" stroke-width="2"/>
    <rect x="${box.x+3}" y="${box.y+3}" width="${box.width-6}" height="${box.height-6}" rx="27" fill="none" stroke="#ffffff" stroke-width="1.5"/>
    <rect x="577" y="${box.y+1}" width="141" height="${box.height-2}" fill="url(#${uid}-panel-lines)" clip-path="url(#${uid}-panels)"/>
    ${skillOrb(card,index,box.y+box.height/2,uid,artwork.skill_icons?.[index])}
    <g clip-path="url(#${uid}-skill-${index})">${text(fit.skills[index].title,190,box.y+40,{weight:900,display:true,label:`skill-${index+1}-name`})}${text(fit.skills[index].body,190,box.y+(fit.skills[index].body.lines.length>2 ? 64 : 70),{lineHeight:fit.skills[index].body.lines.length>2 ? 1 : 1.03,label:`skill-${index+1}-body`})}</g>
    ${fit.skills[index].body.overflow ? `<rect x="422" y="${box.y+box.height-19}" width="278" height="16" fill="#fff0e9"/><text x="428" y="${box.y+box.height-7}" fill="#a43922" font-size="11">TEXT OVERFLOW · NOT PRINT READY</text>` : ''}</g>`).join('');
  const referenceImage = reference ? `<image data-reference-frame="${template}" href="${escapeXml(frameUrl)}" width="756" height="${1056*reference.height/reference.trim_height}" preserveAspectRatio="none" clip-path="url(#${uid}-reference-frame)"/>` : '';
  const rarityLabel = template.toUpperCase();
  const nameY = fit.variant.lines.length ? 632 : fit.name.lines.length>1 ? 615 : 643;
  const front = `${frameArmor(theme,template,uid)}
    <path d="${plate(24,30,708,564,36)}" fill="url(#${uid}-silver)" stroke="#02100a" stroke-width="4"/>
    <path d="${plate(37,46,682,531,24)}" fill="#00190b" stroke="#080e0a" stroke-width="4"/>
    <g clip-path="url(#${uid}-art)">${artContent}${layers}</g>
    <path d="${plate(40,49,676,525,22)}" fill="none" stroke="#e7e9dd" stroke-width="2"/>
    ${referenceImage}
    <g data-anchor="attack" filter="url(#${uid}-shadow)">
      ${bevel('M65 31H242L266 60 238 122H48L29 99V65Z','M65 36H239L260 60 234 117H51L35 96V67Z',uid)}
      <path d="M67 39H236L255 61 230 113H54L40 94V68Z" fill="url(#${uid}-red)" stroke="#fff7e8" stroke-width="2"/>
      <path d="M67 40H138L73 113H55L41 94V68ZM177 40H214L149 113H112Z" fill="white" opacity=".055"/>
      ${statIcon('attack',84,80,1.58,uid)}
      ${singleText(String(card.stats.attack),'attack-value',174,84,[52,48,44,40],{fill:'white',weight:900,display:true,anchor:'middle'})}${singleText('ATK','attack-label',174,113,[29,27],{fill:'white',weight:800,anchor:'middle'})}
    </g>
    <g data-anchor="type" filter="url(#${uid}-shadow)">
      ${bevel(ribbon(541,31,203,89,28),ribbon(546,36,193,79,25),uid)}
      <path d="${ribbon(550,39,184,72,22)}" fill="url(#${uid}-body)" stroke="${theme.gem}" stroke-width="3"/>
      ${typeIcon(card.type,580,76,48)}
      ${text({lines:[card.type.toUpperCase()],size:29,width:105,overflow:false},664.5,87,{label:'type',weight:800,anchor:'middle',fill:card.type==='Fire' ? '#981410' : '#061e10'})}
    </g>
    <g data-anchor="hp" filter="url(#${uid}-shadow)">
      ${bevel('M46 489H205L249 541 211 580H46L25 559V511Z','M48 494H202L242 541 208 575H48L31 556V514Z',uid,template === 'Epic' ? 'gold' : 'silver',5)}
      <path d="M50 499H199L236 541 205 570H50L37 553V517Z" fill="url(#${uid}-hp-green)" stroke="${theme.gem}" stroke-width="2"/>
      ${statIcon('hp',77,537,1.28,uid)}
      ${singleText(String(card.stats.hp),'hp-value',164,540,[48,44,40,36],{fill:'white',weight:900,display:true,anchor:'middle'})}${singleText('HP','hp-label',164,566,[26],{fill:'white',anchor:'middle'})}
    </g>
    <g data-anchor="defense" filter="url(#${uid}-shadow)">
      ${bevel('M553 492H708L730 514V558L708 580H553L514 541Z','M556 498H706L724 516V556L706 574H556L521 541Z',uid,template === 'Epic' ? 'gold' : 'silver',5)}
      <path d="M558 502H703L720 519V553L703 570H558L527 541Z" fill="url(#${uid}-blue)" stroke="${theme.gem}" stroke-width="2"/>
      ${statIcon('defense',586,532,1.14,uid)}${singleText(String(card.stats.defense),'defense-value',666,540,[48,44,40,36],{fill:'white',weight:900,display:true,anchor:'middle'})}${singleText('DEF','defense-label',666,566,[26],{fill:'white',anchor:'middle'})}
    </g>
    <g data-anchor="name" filter="url(#${uid}-shadow)">
      ${bevel(plate(28,594,186,74,20),plate(34,600,174,62,17),uid)}<path d="${plate(39,603,165,57,15)}" fill="url(#${uid}-paper)" stroke="#928564" stroke-width="1.5"/>
      ${text(fit.code,107,643,{fill:'#0c2b21',weight:800,anchor:'middle',label:'card-code'})}
      ${reference ? '' : `${bevel(plate(558,594,172,74,20),plate(564,600,160,62,17),uid)}<path d="${plate(568,603,152,57,15)}" fill="url(#${uid}-label)" stroke="${theme.metal}" stroke-width="1.5"/>
      ${icon('star',605,631,.6)}${text({lines:[rarityLabel],size:21,width:85,overflow:false},668,641,{label:'rarity',fill:'white',weight:900,display:true,anchor:'middle'})}`}
      ${bevel(ribbon(168,576,420,96,45),ribbon(174,582,408,84,41),uid,['Rare','Epic'].includes(template) ? 'gold' : 'silver')}<path d="${ribbon(183,586,390,76,37)}" fill="url(#${uid}-name)" stroke="${theme.gem}" stroke-width="2"/><path d="${ribbon(183,586,390,76,37)}" fill="url(#${uid}-facets)"/>
      ${text(fit.name,378,nameY,{fill:`url(#${uid}-ivory)`,weight:900,anchor:'middle',display:true,lineHeight:1.04,label:fit.variant.lines.length ? 'name' : 'name-full',extra:'stroke="#e1ad36" stroke-width="1.6" paint-order="stroke fill"'})}
      ${text(fit.variant,378,657,{fill:'#fffef0',weight:700,anchor:'middle',spacing:2,label:'variant'})}
    </g>
    ${reference && template === 'Epic' ? `<image data-reference-gems="Epic" href="${escapeXml(frameUrl)}" width="756" height="${1056*reference.height/reference.trim_height}" preserveAspectRatio="none" clip-path="url(#${uid}-reference-gems)"/>` : ''}
    ${skills}
    <g data-anchor="fusion"><path d="M58 933H699Q726 933 726 959V977L716 984H40L30 977V960Q30 933 58 933Z" fill="url(#${uid}-green)" stroke="#d9dc26" stroke-width="1.2"/>
      ${icon('data',65,958,.75,'#eaff32')}<path d="M99 941v34M270 941v34" stroke="${theme.gem}" stroke-width="1.3"/>
      ${singleText('FUSION DATA','fusion-label',115,966,[22,21,20],{fill:'#eaff32',weight:800})}${text(fit.fusion,286,966,{fill:'#fffdf1',label:'fusion'})}
    </g>
    <g data-anchor="tags"><path d="M40 984H716L726 991V1007Q726 1031 701 1031H55Q30 1031 30 1007V991Z" fill="url(#${uid}-green)" stroke="#d9dc26" stroke-width="1.2"/>
      ${icon('tag',65,1007,.75,'#eaff32')}<path d="M99 992v30M270 992v30" stroke="${theme.gem}" stroke-width="1.3"/>
      ${singleText('TAG','tags-label',115,1017,[22],{fill:'#eaff32',weight:800})}${text(fit.tags,286,1017,{fill:'#fffdf1',label:'tags'})}
    </g>`;
  const proof = options.proof ? `<g pointer-events="none"><path d="M85 375 670 665" stroke="white" stroke-width="54" opacity=".82"/><text transform="translate(378 529) rotate(26)" text-anchor="middle" fill="#a3372c" font-size="36" font-weight="700" letter-spacing="5">PROOF · NOT FOR PRINT</text></g>` : '';
  const content = options.side==='back' ? renderBack(artwork.back,W,H) : EDITION_TEMPLATES.includes(template) ? renderEdition(card,artwork,uid,template,{escapeXml,imageUrl,placement,statIcon:(kind,x,y,scale)=>statIcon(kind,x,y,scale,uid),typeIcon,skillOrb,textBlock,frameUrl}) : front;
  const guides = options.guides ? `<rect data-safe-guide="true" x="36" y="36" width="${W-72}" height="984" rx="12" fill="none" stroke="#b24642" stroke-dasharray="8 6" stroke-width="1.5"/>` : '';
  const bleed = options.bleed ? {x:p.bleedX,y:p.bleedY} : {x:0,y:0};
  const crop = options.bleed && p.guides ? `<path d="M-30 0H-5M0-30V-5M${W+5} 0h25M${W}-30V-5M-30 ${H}H-5M0 ${H+5}v25M${W+5} ${H}h25M${W} ${H+5}v25" fill="none" stroke="#354b40" stroke-width="1"/>` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="${-bleed.x} ${-bleed.y} ${W+2*bleed.x} ${H+2*bleed.y}" width="${options.bleed ? p.widthMm : p.width}mm" height="${options.bleed ? p.heightMm : p.height}mm" role="img" aria-label="${escapeXml(card.card_code+' '+card.name)}" data-layout-version="${LAYOUT_VERSION}" font-family="Arial, Helvetica, sans-serif">${defs}<title>${escapeXml(card.name)}</title><desc>${escapeXml(card.skills.map(skill=>skill.source_text).join('\n'))}</desc><rect x="${-bleed.x}" y="${-bleed.y}" width="${W+2*bleed.x}" height="${H+2*bleed.y}" fill="${options.side==='back' ? '#0bb62c' : theme.dark}"/>${content}${guides}${proof}${crop}</svg>`;
}
function renderBack(back={},width=756,height=1056) {
  if (!fixedBackAvailable()) return '<rect width="756" height="1056" fill="#edf4e8"/><text x="378" y="505" text-anchor="middle" fill="#426044" font-size="25">BACK REFERENSI BELUM TERPASANG</text>';
  const embedded = back.image?.sha256===FIXED_BACK.sha256 && /^data:image\/png;base64,/.test(back.image?.url ?? '') ? back.image.url : FIXED_BACK.url;
  return `<image data-fixed-back="${FIXED_BACK.id}" href="${escapeXml(embedded)}" width="${width}" height="${height}" preserveAspectRatio="none"/>`;
}
