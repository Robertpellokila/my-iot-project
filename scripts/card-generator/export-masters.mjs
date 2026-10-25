import { mkdirSync,readFileSync,writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { PILOT,CARD_BY_CODE } from '../../src/lib/card-generator/cardSchema.js';
import { renderCardSvg } from '../../src/lib/card-generator/cardRenderer.js';
import { referenceFrameFor } from '../../src/lib/card-generator/cardReferenceFrames.js';
const output=new URL('../../docs/card-generator/masters/',import.meta.url);mkdirSync(output,{recursive:true});
const samples=[['Common','TOC-003'],['Uncommon','TOC-005'],['Rare','COB-006'],['Epic','COB-008'],['Legendary',null],['Mythic',null],['Fusion','F01']];
for(const [template,code] of samples){
 const card=code?CARD_BY_CODE.get(code):{...CARD_BY_CODE.get('F01'),card_code:`STUDY-${template.toUpperCase()}`,kind:'preview',name:`${template} — Frame study`,rarity:template,tags:[]};
 const frame=referenceFrameFor(card,template);
 let reference_frame=null;
 if(frame){
  const bytes=readFileSync(new URL(`../../public${frame.url}`,import.meta.url));
  if(createHash('sha256').update(bytes).digest('hex')!==frame.sha256)throw new Error(`Reference frame hash mismatch: ${template}`);
  reference_frame={...frame,url:`data:image/png;base64,${bytes.toString('base64')}`};
 }
 writeFileSync(new URL(`${template.toLowerCase()}-proof.svg`,output),renderCardSvg(card,PILOT,{reference_frame}, {template,proof:true}));
}
writeFileSync(new URL('index.html',output),`<!doctype html><meta charset="utf-8"><title>TBC seven master proofs</title><style>body{margin:32px;background:#eef4ed;color:#23412e;font:15px Arial}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:24px}article{background:#fff;padding:14px;border-radius:12px}img{width:100%}p{line-height:1.6}</style><h1>TBC · Seven master proofs</h1><p>Self-contained SVG proofs with embedded reference frame decorations and dynamic card data. Final character artwork is still required. The approved shared back is installed. Legendary and Mythic use preview data outside the pilot pool.</p><main>${samples.map(([name])=>`<article><h2>${name}</h2><img src="${name.toLowerCase()}-proof.svg" alt="${name} frame proof"></article>`).join('')}</main>`);
console.log('Seven SVG proofs exported; no card marked print-ready.');
