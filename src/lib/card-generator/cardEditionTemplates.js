import {fitText} from './cardTextFitter.js';
export const EDITION_TEMPLATES=['Trial Join','Winning'];
export const isEditionTemplate=card=>EDITION_TEMPLATES.includes(card?.design_template);
const fit=(value,width,lines,sizes,bold=false)=>fitText(value,width,lines,sizes,{weight:bold?800:400,family:'Arial'});
// Native 1024 × 1536 reference coordinates. All editable content has its own safe bounds.
export function editionTextLayout(card,template=card.design_template){
 const trial=template==='Trial Join';
 return {
  name:fit([card.name,card.subtitle].filter(Boolean).join(': '),trial?568:506,1,trial?[58,54,48,42,36]:[49,44,40,36,32],true),
  code:fit(card.display_code||card.card_code,trial?300:124,1,trial?[30,28,25,22]:[23,21,19,17],true),
  serial:fit(card.serial_number||card.display_code||card.card_code,230,1,[23,21,19,17],true),
  type:fit(card.type,trial?164:98,1,trial?[38,34,30,27]:[28,25,23,20],true),
  rarity:fit(card.rarity,trial?250:300,1,trial?[32,29,26]:[62,56,48,42],true),
  skills:card.skills.map(skill=>({title:fit(skill.name,trial?390:310,1,trial?[40,36,32,28]:[42,38,34,30,28],true),body:fit(skill.description,trial?380:350,trial?2:4,trial?[28,26,24,21]:[27,25,23,21])}))
 };
}
export function editionTextIssues(card){const f=editionTextLayout(card);return [f.name.overflow&&'Nama/varian melebihi panel edisi',f.code.overflow&&'Kode cetak terlalu panjang',f.type.overflow&&'Tipe melebihi panel edisi',f.rarity.overflow&&'Rarity melebihi panel edisi',f.serial.overflow&&'Nomor seri terlalu panjang',...f.skills.flatMap((s,i)=>[s.title.overflow&&`Judul Skill ${i+1} terlalu panjang`,s.body.overflow&&`Skill ${i+1} melebihi ruang aman cetak`])].filter(Boolean);}
export function renderEdition(card,artwork,uid,template,h){
 const {escapeXml:esc,imageUrl,placement,statIcon,typeIcon,skillOrb,textBlock,frameUrl}=h;
 const trial=template==='Trial Join',f=editionTextLayout(card,template);
 const boundsText=(block,x,y,bounds,id,opts={})=>`<defs><clipPath id="${uid}-edition-${id}"><rect x="${bounds[0]}" y="${bounds[1]}" width="${bounds[2]}" height="${bounds[3]}"/></clipPath></defs><g clip-path="url(#${uid}-edition-${id})">${textBlock(block,x,y,{label:`edition-${id}`,fill:'#061e56',weight:800,...opts,extra:`${opts.extra??''} data-panel-bounds="${bounds.join(',')}"`})}</g>`;
 // Leave space for the italic glyph overhang and outline on champion stats.
 const value=(number,x,y,width,height,id,size=67,color='#09214c',extra='')=>boundsText(fit(String(number),width-(extra?14:0),1,[size,size-8,size-16,size-24,size-32],true),x,y,[x-width/2,y-height+8,width,height],id,{anchor:'middle',fill:color,extra});
 const art=trial?{x:0,y:0,w:1024,h:1035}:{x:36,y:147,w:952,h:850};
 const layers=['background','character','foreground'].map((key,i)=>{const asset=artwork[key],url=imageUrl(asset?.url);if(!url)return '';const p=placement(asset),cx=art.x+art.w/2,cy=art.y+art.h/2;return `<image data-art-layer="${i}" href="${esc(url)}" x="${art.x}" y="${art.y}" width="${art.w}" height="${art.h}" preserveAspectRatio="xMidYMid ${asset.fit==='contain'?'meet':'slice'}" transform="translate(${cx+p.x*1024/704} ${cy+p.y*1536/1056}) scale(${p.scale}) translate(${-cx} ${-cy})"/>`;}).join('');
 const placeholder=layers?'':`<rect width="1024" height="1536" fill="${trial?'#cde5be':'#d0eafb'}"/><text x="512" y="480" text-anchor="middle" font-size="30" fill="#285766">Upload ilustrasi kartu</text>`;
 const orb=(i,x,y,r)=>{
  const asset=artwork.skill_icons?.[i],url=imageUrl(asset?.url);
  if(url)return `<defs><clipPath id="${uid}-edition-icon-${i}"><circle cx="${x}" cy="${y}" r="${r}"/></clipPath></defs><image data-skill-upload="${i+1}" href="${esc(url)}" x="${x-r}" y="${y-r}" width="${r*2}" height="${r*2}" preserveAspectRatio="xMidYMid ${asset.fit==='contain'?'meet':'slice'}" clip-path="url(#${uid}-edition-icon-${i})"/>`;
  return `<g transform="translate(${x} ${y}) scale(${r/61}) translate(-107 0)">${skillOrb(card,i,0,uid)}</g>`;
 };
 let content=`<defs><clipPath id="${uid}-edition-round"><rect width="1024" height="1536" rx="50"/></clipPath><linearGradient id="${uid}-edition-title" x2="0" y2="1"><stop stop-color="#fffef4"/><stop offset=".6" stop-color="#fff0bd"/><stop offset="1" stop-color="#d9a13c"/></linearGradient></defs><g clip-path="url(#${uid}-edition-round)">${placeholder}${layers}${[0,1].map(i=>orb(i,trial?(i?739:286):157,trial?1164:(i?1225:1064),trial?103:57)).join('')}<image data-edition-frame="${esc(template)}" href="${esc(frameUrl)}" width="1024" height="1536"/>
 `;
 if(trial){
  // Replace the fixed raster emblems inside their ivory panels. The ornate frame
  // remains unchanged; these SVG wells and symbols are also used by print export.
  content+=`<defs><linearGradient id="${uid}-icon-well" x2=".4" y2="1"><stop stop-color="#f8f2e4"/><stop offset=".5" stop-color="#fffcf3"/><stop offset="1" stop-color="#fbf8ef"/></linearGradient></defs>
  <g fill="url(#${uid}-icon-well)"><rect data-icon-well="attack" x="53" y="73" width="82" height="91" rx="11"/><rect data-icon-well="type" x="790" y="72" width="68" height="75" rx="9"/><rect data-icon-well="hp" x="56" y="1412" width="65" height="62" rx="13"/><rect data-icon-well="defense" x="732" y="1407" width="65" height="68" rx="9"/></g>
  ${statIcon('attack',94,119,1.8)}${statIcon('hp',88,1444,1.2)}${statIcon('defense',764,1439,1.1)}${typeIcon(card.type,823,109,66)}
  ${value(card.stats.attack,181,161,110,62,'attack',58,'#a8270d')}
  ${boundsText(f.type,910,148,[824,113,168,43],'type',{anchor:'middle'})}
  ${boundsText(f.code,512,960,[362,931,300,33],'code',{anchor:'middle'})}
  ${boundsText(f.name,512,1010,[228,965,568,58],'name',{anchor:'middle'})}`;
  for(let i=0;i<2;i++){const cx=i?739:286,x=i?549:96;content+=`<g data-anchor="skill-${i+1}">
   ${boundsText(f.skills[i].title,cx,1308,[cx-195,1277,390,40],`skill-${i}-name`,{anchor:'middle'})}
   ${boundsText(f.skills[i].body,cx,1353,[x,1329,380,59],`skill-${i}-body`,{anchor:'middle',weight:600,lineHeight:1.04})}</g>`;}
  content+=`${value(card.stats.hp,236,1466,116,64,'hp',60,'#07832c')}${value(card.stats.defense,912,1466,104,64,'defense',60,'#007bce')}
   ${boundsText(f.rarity,512,1477,[387,1448,250,36],'rarity',{anchor:'middle'})}`;
 }else{
  content+=`${boundsText(f.name,515,113,[263,66,506,61],'name',{anchor:'middle',fill:'url(#'+uid+'-edition-title)',extra:'stroke="#291600" stroke-width="5" stroke-linejoin="round" paint-order="stroke fill"'})}
  ${value(card.stats.attack,170,148,104,72,'attack',72,'#071122','font-style="italic" stroke="#fff" stroke-width="4" paint-order="stroke fill"')}
  ${statIcon('attack',82,102,2)}<circle cx="945" cy="106" r="39" fill="#fffbed"/>${typeIcon(card.type,945,106,71)}
  ${boundsText(f.type,850,88,[799,60,102,35],'type',{anchor:'middle',extra:'font-style="italic"'})}
  ${boundsText(f.code,845,160,[782,135,126,30],'code',{anchor:'middle',fill:'#fff9e7'})}`;
  for(let i=0;i<2;i++){const y=i?1225:1064;content+=`<g data-anchor="skill-${i+1}">
   ${boundsText(f.skills[i].title,267,y+13,[263,y-22,315,84],`skill-${i}-name`,{fill:i?'#dff7ff':'#fff1c1',lineHeight:1.05,extra:`stroke="${i?'#001c5c':'#311600'}" stroke-width="4" stroke-linejoin="round" paint-order="stroke fill"`})}
   ${boundsText(f.skills[i].body,598,y-36,[595,y-61,354,118],`skill-${i}-body`,{weight:500,lineHeight:1.05})}</g>`;}
  content+=`${statIcon('hp',86,1394,2)}${statIcon('defense',844,1394,2)}
   ${value(card.stats.hp,186,1436,119,88,'hp',80,'#ffe6ab','font-style="italic" stroke="#310d03" stroke-width="7" paint-order="stroke fill"')}
   ${value(card.stats.defense,935,1436,110,88,'defense',80,'#00357d','font-style="italic" stroke="#faffff" stroke-width="5" paint-order="stroke fill"')}
   ${boundsText({...f.rarity,lines:f.rarity.lines.map(l=>l.toUpperCase())},512,1409,[358,1354,308,66],'rarity',{anchor:'middle',fill:'#f6f4ff',extra:'stroke="#082d80" stroke-width="8" stroke-linejoin="round" paint-order="stroke fill"'})}
   ${boundsText(f.serial,512,1484,[397,1459,230,31],'serial',{anchor:'middle'})}`;
 }
 return `<g data-edition-template="${esc(template)}" transform="scale(.6875)">${content}</g></g>`;
}
