<script setup>
import {computed} from 'vue';
const props=defineProps({action:{type:String,required:true}});
const cells={summon:[0,0],attack:[1,0],special:[2,0],more:[0,1],end_turn:[1,1],combo:[2,1],fusion:[0,2],ultimate:[1,2],heal:[2,2],defense:[0,1]};
const cell=computed(()=>cells[props.action]??cells.special);
</script>
<template>
 <span class="battle-action-artwork" aria-hidden="true">
  <img v-if="action==='synergy'" class="action-art-single" src="/images/battle-arena/synergy-v1.webp" alt="" draggable="false" />
  <img v-else class="action-art-atlas" src="/images/battle-arena/action-atlas-v1.webp" alt="" draggable="false" :style="{left:`${cell[0]*-100}%`,transform:`translateY(${-(cell[1]+.5)/3*100}%)`}" />
 </span>
</template>
<style scoped>
.battle-action-artwork{position:relative;display:block;overflow:hidden;isolation:isolate;width:100%;aspect-ratio:2.6;background:#ddf0fc;pointer-events:none}
.action-art-atlas{position:absolute;display:block;top:50%;width:300%;max-width:none;height:auto}
.action-art-single{display:block;width:100%;height:100%;object-fit:cover}
</style>
