import { PILOT, TYPES, RARITIES } from './cardSchema.js';
import { normalizeDraft } from './cardDrafts.js';
import { cardIdentity, footerData, imageUrl } from './cardRenderer.js';
import { emptyArtwork, digestBlob } from './cardArtworkService.js';
import { normalizeTcgType } from '../../utils/tcgTypes.js';
import { withBattleRule } from './cardSkillBattleRules.js';

export function editableStudioCard(card) {
  if (card.is_custom) return card;
  const {name,variant}=cardIdentity(card);
  return normalizeDraft({...card,source_pilot_code:card.card_code,display_code:card.card_code,name,subtitle:variant,fusion_data:footerData(card,PILOT)});
}
export function studioLibrary(workspace) {
  const custom=new Map(workspace.custom_cards.map(card=>[card.card_code,card]));
  return [...PILOT.cards.map(card=>custom.get(card.card_code)??card),...workspace.custom_cards.filter(card=>!card.source_pilot_code)];
}
export function recordToStudioCard(record,linkedSkills=[]) {
  const saved=record.metadata?.studio_card??{},parts=String(record.name??'').split(/\s+[—–]\s+|:\s+/);
  const type=TYPES.find(value=>value.toLowerCase()===normalizeTcgType(record.element))??'Knight';
  const rarity=RARITIES.find(value=>value.toLowerCase()===String(record.rarity).toLowerCase())??'Common';
  const skills=linkedSkills.length?linkedSkills:(record.metadata?.skills??saved.skills??[]);
  // RFID copies retain design metadata, but must have their own editable identity.
  return normalizeDraft({...saved,card_code:`DRAFT-${record.id.toUpperCase()}`,source_pilot_code:undefined,source_game_card_id:record.id,source_catalog_code:record.card_code,
    display_code:saved.display_code??String(record.card_code??'').replaceAll('_','-').slice(0,12),name:parts[0],subtitle:parts.slice(1).join(' — '),
    role:saved.role??record.metadata?.role??'Character',type,rarity,kind:record.fusion_only?'fusion':'base',
    stats:{hp:record.hp,attack:record.attack,defense:record.defense},tags:record.tags??[],
    skills:[0,1].map(i=>({name:skills[i]?.name??'',description:skills[i]?.description??skills[i]?.effect??'',battle:skills[i]?.metadata?.studio_customized?{...skills[i]?.metadata?.studio_rule,authority:'custom'}:skills[i]?.battle??skills[i]?.metadata?.studio_rule})),
  });
}
export function recordArtwork(record) {
  return {...emptyArtwork(),...record.metadata?.studio_artwork};
}
export async function artworkFromCatalog(record) {
  const artwork=recordArtwork(record);
  if(artwork.character?.url===record.image_url||!imageUrl(record.image_url))return artwork;
  artwork.character=await catalogImageAsset(record.image_url,'cover');
  return artwork;
}
export async function catalogImageAsset(url,fit='cover') {
  const response=await fetch(url,{credentials:'omit'});
  if(!response.ok)throw new Error('Ilustrasi katalog belum dapat dimuat. Data kartu tetap tersedia.');
  const blob=await response.blob();
  if(!/^image\/(png|webp|jpeg)$/.test(blob.type)||blob.size>10*1024*1024)throw new Error('Upload ulang ilustrasi katalog sebagai PNG, WebP, atau JPG.');
  const bitmap=await createImageBitmap(blob);
  const asset={url,sha256:await digestBlob(blob),width:bitmap.width,height:bitmap.height,x:0,y:0,scale:1,fit};
  bitmap.close();return asset;
}
export function studioSaveEntries(cards,workspace) {
  return cards.map(card=>{
    const editable=editableStudioCard(card);
    return {key:card.card_code,card:{...editable,sync_skill_presentation:true,skills:editable.skills.map(withBattleRule)},artwork:workspace.artworks[card.card_code]??emptyArtwork()};
  });
}
