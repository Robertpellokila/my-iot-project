<script setup>
import { computed } from 'vue';
import CardFrameRenderer from './CardFrameRenderer.vue';
import { PILOT } from '../../lib/card-generator/cardSchema.js';
import { recordToStudioCard, recordArtwork } from '../../lib/card-generator/cardCatalogBridge.js';
import { imageUrl } from '../../lib/card-generator/cardRenderer.js';
const props=defineProps({card:{type:Object,required:true}});
const studio=computed(()=>{
  if(!props.card.metadata?.studio_card)return null;
  try{return recordToStudioCard(props.card);}catch{return null;}
});
const artwork=computed(()=>{
 const art=recordArtwork(props.card);
 // Registration can replace the illustration while keeping its Studio design.
 if(props.card.image_url&&art.character)art.character={...art.character,url:props.card.image_url};
 return art;
});
const picture=computed(()=>imageUrl(props.card.physical_card_image_url||props.card.image_url));
const symbol=computed(()=>({Knight:'♜',Fire:'♨',Water:'◉',Forest:'❧',Thunder:'ϟ',Light:'☀',Dark:'☾'})[props.card.element]||'✦');
</script>
<template>
 <CardFrameRenderer v-if="studio" :card="studio" :dataset="PILOT" :artwork="artwork" />
 <div v-else class="album-card-face">
  <header><strong>{{ card.name }}</strong><span>{{ card.element }}</span></header>
  <div class="album-illustration"><img v-if="picture" :src="picture" alt="" loading="lazy"><span v-else aria-hidden="true">{{ symbol }}</span></div>
  <div class="album-stats"><span>HP <b>{{ card.hp }}</b></span><span>ATK <b>{{ card.attack }}</b></span><span>DEF <b>{{ card.defense }}</b></span></div>
  <footer>{{ card.card_code || 'Kartu' }} <span>{{ card.rarity || 'Common' }}</span></footer>
 </div>
</template>
<style scoped>
.album-card-face{aspect-ratio:63/88;display:flex;flex-direction:column;gap:10px;padding:13px;background:linear-gradient(145deg,#fffdf5,#e4f1e1);color:#214b37;border:2px solid #c4d6ba;border-radius:15px;box-shadow:0 4px 12px #24423015;font-family:Inter,Arial,sans-serif;overflow:hidden}
header{display:flex;flex-direction:column;gap:5px}header strong{font-size:clamp(11px,1.05vw,17px);line-height:1.25}header span{font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:#56765b}.album-illustration{flex:1;min-height:0;display:grid;place-items:center;overflow:hidden;background:radial-gradient(circle,#fffef6,#dcebd5);border-radius:9px;border:1px solid #ccdcc5}.album-illustration img{width:100%;height:100%;min-height:0;object-fit:contain}.album-illustration>span{font-size:64px;color:#5f8b55}.album-stats{display:flex;justify-content:space-between;gap:5px}.album-stats>span{display:flex;flex:1;flex-direction:column;background:#ffffffb8;padding:7px 3px;border-radius:6px;text-align:center;font-size:9px;color:#53745e}.album-stats b{font-size:17px;color:#173f2d}footer{display:flex;justify-content:space-between;gap:5px;font-size:9px;overflow-wrap:anywhere}footer span{text-transform:capitalize}
</style>
