<script setup>
import { ref,onMounted,onBeforeUnmount,watch,nextTick } from 'vue';
import * as Blockly from 'blockly/core';
import * as English from 'blockly/msg/en';
import { BLOCK_SPECS,EMPTY_WORKSPACE,DEFAULT_BLOCK_CONFIG,toolboxFor } from '../../lib/questions/scratchBlocks.js';
Blockly.setLocale(English);
for(const spec of BLOCK_SPECS) if(!Blockly.Blocks[spec.definition.type]) Blockly.defineBlocksWithJsonArray([spec.definition]);
const props=defineProps({modelValue:{type:Object,default:()=>EMPTY_WORKSPACE},config:{type:Object,default:()=>DEFAULT_BLOCK_CONFIG},readonly:Boolean,disabled:Boolean,label:{type:String,default:'Workspace blok'}});
const emit=defineEmits(['update:modelValue','error']);
const host=ref(null),error=ref('');let workspace,observer,loading=false,last='';
function load(){if(!workspace)return;try{loading=true;Blockly.serialization.workspaces.load(props.modelValue??EMPTY_WORKSPACE,workspace);last=JSON.stringify(props.modelValue);error.value='';if(props.readonly)workspace.zoomToFit();}catch(e){error.value='Workspace tidak dapat dibuka. Periksa data blok.';emit('error',e.message);}finally{loading=false;}}
function fit(){workspace?.zoomToFit();}
function undo(redo=false){workspace?.undo(redo);}
function clear(){workspace?.clear();}
onMounted(()=>{
 workspace=Blockly.inject(host.value,{renderer:'zelos',toolbox:props.readonly?undefined:toolboxFor(props.config),readOnly:props.readonly,trashcan:!props.readonly,scrollbars:true,sounds:false,maxBlocks:100,
  move:{scrollbars:true,drag:true,wheel:true},zoom:{controls:true,wheel:true,startScale:props.readonly?.85:.9,maxScale:1.6,minScale:.35,scaleSpeed:1.1},grid:{spacing:24,length:2,colour:'#d4dce4',snap:true}});
 load();workspace.addChangeListener(event=>{if(loading||event.isUiEvent||props.readonly||props.disabled)return;const value=Blockly.serialization.workspaces.save(workspace);last=JSON.stringify(value);emit('update:modelValue',value);});
 observer=new ResizeObserver(()=>{Blockly.svgResize(workspace);if(props.readonly)fit();});observer.observe(host.value);
});
watch(()=>props.modelValue,()=>{if(JSON.stringify(props.modelValue)!==last)load();},{deep:true});
watch(()=>props.config,()=>workspace?.updateToolbox(toolboxFor(props.config)),{deep:true});
watch(()=>props.readonly,async()=>{await nextTick();});
onBeforeUnmount(()=>{observer?.disconnect();workspace?.dispose();});
defineExpose({fit,getWorkspace:()=>workspace,serialize:()=>workspace?Blockly.serialization.workspaces.save(workspace):EMPTY_WORKSPACE});
</script>
<template><div class="block-workspace" :class="{locked:disabled,readonly}" :aria-label="label"><nav v-if="!readonly" class="block-tools"><strong>{{ label }}</strong><button type="button" :disabled="disabled" @click="undo(false)">↶ Undo</button><button type="button" :disabled="disabled" @click="undo(true)">↷ Redo</button><button type="button" @click="fit">Fit</button><button type="button" :disabled="disabled" @click="clear">Hapus semua</button></nav><p v-if="error" role="alert">{{ error }}</p><div ref="host" class="block-canvas" :inert="disabled || undefined"/><small v-if="!readonly">Sambungkan blok di workspace. Klik kanan untuk duplikat/hapus. Ctrl/Cmd+Z untuk undo. Mode quiz memeriksa program, tanpa menjalankan sprite atau audio.</small></div></template>
<style scoped>
.block-workspace{min-width:0;border:1px solid #cbd8e2;border-radius:12px;overflow:hidden;background:#f8fafc;color:#294653}.block-tools{display:flex;gap:7px;align-items:center;flex-wrap:wrap;padding:10px;border-bottom:1px solid #d7e1e8;background:white}.block-tools strong{margin-right:auto;font-size:13px}.block-tools button{padding:7px 11px;border:1px solid #c8d6e1;border-radius:6px;background:white;color:#23485e;cursor:pointer}.block-canvas{height:480px;width:100%;position:relative}.readonly .block-canvas{height:320px}.locked .block-canvas{opacity:.75}.block-workspace>small{display:block;padding:10px 14px;font:12px/1.5 Arial;color:#536878}.block-workspace>p{padding:12px;color:#ae3434}@media(max-width:700px){.block-canvas{height:410px}}
</style>
