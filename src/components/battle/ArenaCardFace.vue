<script setup>
import {computed,ref,watch} from 'vue';
import {publicCardStats} from '../../utils/publicCardStats.js';
import {displayCardCode} from '../../utils/displayCardCode.js';
import {formatTcgType} from '../../utils/tcgTypes.js';
import BattleActionIcon from './BattleActionIcon.vue';
import SkillIcon from './SkillIcon.vue';
const props=defineProps({card:{type:Object,required:true},skills:{type:Array,default:()=>[]},compact:Boolean});
const stats=computed(()=>publicCardStats(props.card));
const hpPercent=computed(()=>Math.max(0,Math.min(100,(stats.value.hp??0)/Math.max(1,stats.value.maxHp??1)*100)));
const type=computed(()=>formatTcgType(props.card.element||props.card.type||'neutral'));
const palette=computed(()=>({Forest:['#4bb45c','#eaffdd'],Water:['#43b8ed','#e8faff'],Thunder:['#f4bd27','#fff6cc'],Fire:['#ed8d3b','#fff0d5'],Light:['#e6c444','#fff9d6'],Dark:['#9c77db','#f1e5ff'],Knight:['#52abd3','#e5f6ff']}[type.value]??['#7abbd6','#ecf8ff']));
const sources=computed(()=>[props.card.image_url??props.card.imageUrl,props.card.avatar_url,props.card.physical_card_image_url].filter(url=>/^(https?:\/\/|\/|data:image\/|blob:)/i.test(String(url??''))));
const imageIndex=ref(0);
// A new live card object with the same URLs is not a new image. Preserve the
// fallback too, rather than retrying a broken source on every HP refresh.
watch(()=>JSON.stringify(sources.value),()=>{imageIndex.value=0});
const image=computed(()=>sources.value[imageIndex.value]);
const printed=computed(()=>image.value&&image.value===props.card.physical_card_image_url);
const skillRows=computed(()=>{const rows=props.skills.length?props.skills:(props.card.skills??props.card.metadata?.studio_card?.skills);return Array.isArray(rows)?rows:[];});
const code=computed(()=>displayCardCode(props.card));
const rarity=computed(()=>props.card.rarity??props.card.metadata?.studio_card?.rarity??'');
const rarityColor=computed(()=>({common:'#537c9e',uncommon:'#16964a',rare:'#1675da',epic:'#813ce1',legendary:'#a86e0b'}[String(rarity.value).toLowerCase()]??'#1675da'));
const fusion=computed(()=>props.card.card_kind==='fusion'||props.card.origin_type==='fusion'||Boolean(props.card.is_fusion));
</script>
<template>
 <div class="arena-card-face" :class="{compact,printed}" :style="{'--face-accent':palette[0],'--face-wash':palette[1],'--rarity-color':rarityColor}" :aria-label="`${card.name}. ${type}. HP ${stats.hp??'—'}/${stats.maxHp??'—'}. ATK ${stats.attack??'—'}. DEF ${stats.defense??'—'}.`">
  <template v-if="printed"><img class="face-printed-image" :src="image" :alt="card.name" draggable="false" @error="imageIndex++" /><div v-if="!compact" class="face-printed-stats"><span>ATK <b>{{stats.attack??'—'}}</b></span><span>DEF <b>{{stats.defense??'—'}}</b></span></div></template>
  <template v-else>
   <header class="face-title"><strong>{{card.name}}</strong><span>{{type}}</span></header>
   <div class="face-art"><img v-if="image" :src="image" :alt="card.name" draggable="false" @error="imageIndex++" /><div v-else class="face-image-missing"><BattleActionIcon name="summon"/><span>{{card.name}}</span></div></div>
   <div class="face-combat"><span class="face-atk"><BattleActionIcon name="attack"/>{{stats.attack??'—'}}</span><span class="face-def"><BattleActionIcon name="defense"/>{{stats.defense??'—'}}</span></div>
   <div v-if="!compact" class="face-meta">
    <div class="face-identity">
     <span class="face-code" :title="code||type">{{code||type}}</span>
     <div v-if="fusion || card.exhausted" class="face-traits"><small v-if="fusion">🧬 Fusion</small><small v-if="card.exhausted">Exhausted</small></div>
    </div>
    <b v-if="rarity">{{rarity}}</b>
   </div>
   <div v-if="!compact" class="face-skills" :class="{'single-skill':skillRows.length===1}">
    <span v-for="(skill,index) in skillRows.slice(0,2)" :key="skill.id??index" class="face-skill" :title="skill.name"><span class="face-skill-icon"><SkillIcon :icon="skill.icon" :name="skill.name"/></span><strong>{{skill.name}}</strong></span>
    <small v-if="!skillRows.length">Belum ada skill ditampilkan</small>
   </div>
  </template>
  <div v-if="!compact" class="face-hp"><span>HP <b>{{stats.hp??'—'}} / {{stats.maxHp??'—'}}</b></span><i><em :style="{width:`${hpPercent}%`}" :class="{low:hpPercent<=25}"/></i></div>
 </div>
</template>
<style scoped>
.arena-card-face{--face-accent:#6dbada;--face-wash:#ecf8ff;container-type:inline-size;position:relative;display:grid;grid-template-rows:7% 44% 9% 11% 21% 8%;min-width:0;width:100%;aspect-ratio:63/94;padding:3.3%;overflow:hidden;border:2px solid var(--face-accent);border-radius:7%/4.7%;background:linear-gradient(135deg,#fff,var(--face-wash));color:#102c61;box-shadow:inset 0 0 0 2px #fff,0 0 0 2px #fff6c8,0 7px 18px #122b5629;font-family:Inter,Arial,sans-serif}
/* Reserve the same artwork, metadata and skill space for every card. An icon
   scales with the card's width, never with the number of occupied skill slots. */
.arena-card-face> *{min-height:0;min-width:0}
.face-title{display:flex;align-items:center;justify-content:space-between;gap:4%;padding:2% 2% 3%;min-width:0;flex:none}
.face-title strong{font-size:7.5cqw;line-height:1.1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;letter-spacing:-.04em}
.face-title>span{font-size:4cqw;font-weight:850;text-transform:uppercase;white-space:nowrap;color:#24436e}
.face-art{position:relative;min-height:0;border-radius:3%;overflow:hidden;background:linear-gradient(130deg,#fff,var(--face-wash));border:1px solid #fff}
.face-art>img{width:100%;height:100%;position:absolute;inset:0;object-fit:cover}
.face-image-missing{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;color:#567d9f;font-size:7cqw;font-weight:800;text-align:center}
.face-image-missing svg{width:25%;height:auto;color:var(--face-accent)}
.face-combat{position:relative;z-index:1;display:flex;justify-content:space-between;align-items:start;margin:-6% 1% 0}
.face-combat>span{display:flex;align-items:center;justify-content:center;gap:6%;width:36%;padding:3% 4%;border:2px solid #fff;border-radius:13%/25%;box-shadow:0 2px 3px #1b365633;font-size:8cqw;font-weight:900;line-height:1;color:#fff}
.face-atk{background:linear-gradient(#ff375c,#e60037)}.face-def{background:linear-gradient(#248bfc,#0759cd)}.face-combat svg{width:26%;height:auto;flex:none}
.face-meta{display:flex;justify-content:space-between;align-items:start;padding:1% 2%;gap:3%;overflow:hidden;font-size:4.6cqw;font-weight:800;line-height:1.2}
.face-identity{flex:1;min-width:0}.face-code{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.face-traits{display:flex;flex-wrap:wrap;gap:3% 6%;margin-top:3%}.face-meta small{font-size:4cqw;white-space:nowrap}.face-meta>b{flex:none;text-transform:uppercase;font-size:4cqw;padding:3% 5%;color:#fff;background:var(--rarity-color,#1775d6);border-radius:3px}
.face-skills{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));align-content:center;align-items:start;gap:5%;padding:1%;overflow:hidden}
.face-skill{display:flex;flex-direction:column;align-items:center;gap:1cqw;min-width:0;text-align:center}
.single-skill>.face-skill{grid-column:1/-1}
.face-skill-icon{display:grid;place-items:center;flex:none;width:20cqw;height:20cqw;border-radius:50%;border:2px solid #e5bd51;background:radial-gradient(circle,#3080c8,#09396d);color:#fff;font-size:11cqw;overflow:hidden}
.face-skill-icon :deep(img){width:100%;height:100%;object-fit:cover}
.face-skills strong{font-size:4.3cqw;line-height:1.2;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.face-skills>small{grid-column:1/-1;align-self:center;text-align:center;color:#54728e;font-size:4.7cqw}
.face-hp{padding:2% 2% 1%;font-size:4.5cqw;flex:none}.face-hp>span{display:flex;justify-content:space-between;align-items:center;line-height:1.4}.face-hp b{font-size:5cqw}
.face-hp>i{display:block;height:2cqw;background:#bfdbe5;border-radius:9px;margin-top:2%;overflow:hidden}.face-hp em{display:block;height:100%;border-radius:inherit;background:linear-gradient(90deg,#0eb777,#3edd9a);transition:width .3s}.face-hp em.low{background:#f15959}
.face-printed-image{display:block;flex:1;min-height:0;width:100%;height:0;object-fit:contain}.printed{display:flex;flex-direction:column;padding:0;background:#fff}.printed .face-hp{padding:2% 4% 4%;background:#f4faff}.face-printed-stats{display:flex;justify-content:space-between;flex:none;padding:2% 4%;font-size:5cqw;background:#f4faff}.face-printed-stats b{font-size:6cqw}
.compact{aspect-ratio:63/88;grid-template-rows:9% 80% 11%}.compact .face-title strong{font-size:9cqw}.compact .face-title>span{font-size:5cqw}.compact .face-combat{margin-bottom:2%}
@media(prefers-reduced-motion:reduce){.face-hp em{transition:none}}
</style>
