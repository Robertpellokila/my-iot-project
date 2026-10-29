<script setup>
import {nextTick,onMounted,onBeforeUnmount,ref,shallowRef,watch} from 'vue';
import {useRoute} from 'vue-router';
import {adminToastStore as store} from '../../lib/adminNotifications.js';
const route=useRoute(),items=shallowRef([]),target=shallowRef('body'),host=ref(null),polite=ref(''),urgent=ref('');
const icons={success:'✓',danger:'!',warning:'!',info:'i',loading:'◌'};let observer,stop,announceVersion=0;const revisions=new Map();
function modalTarget(){const dialogs=[...document.querySelectorAll('dialog[open]')];return dialogs.reverse().find(dialog=>{try{return dialog.matches(':modal');}catch{return true;}})??'body';}
async function showLayer(reopen=false){await nextTick();if(!host.value)return;try{const open=host.value.matches(':popover-open');if(!items.value.length){if(open)host.value.hidePopover();return;}if(open&&!reopen)return;if(open)host.value.hidePopover();host.value.showPopover();}catch{/* Fixed positioning also supports browsers without Popover. */}}
function syncTarget(){const next=modalTarget();if(target.value!==next){target.value=next;void showLayer(true);}}
function visibility(){if(document.hidden)store.pauseAll('hidden');else store.resumeAll('hidden');}
function unfocus(item,event){if(!event.currentTarget.contains(event.relatedTarget))store.resume(item.id,'focus');}
watch(()=>route.path,path=>{if(!path.startsWith('/admin')&&path!=='/login')store.clear();});
onMounted(()=>{
 stop=store.subscribe(async value=>{
  items.value=value;syncTarget();
  const changed=value.filter(item=>revisions.get(item.id)!==item.revision);for(const item of value)revisions.set(item.id,item.revision);for(const id of revisions.keys())if(!value.some(item=>item.id===id))revisions.delete(id);
  if(changed.length){const current=++announceVersion;const latest=changed.at(-1),text=`${latest.title}. ${latest.message}`;polite.value='';urgent.value='';await nextTick();if(current===announceVersion){if(latest.type==='danger')urgent.value=text;else polite.value=text;}await showLayer();}
  else if(!value.length)void showLayer();
 });
 observer=new MutationObserver(records=>{if(records.some(record=>record.type==='attributes'||[...record.addedNodes,...record.removedNodes].some(node=>node.nodeType===1&&(node.tagName==='DIALOG'||node.querySelector?.('dialog')))))syncTarget();});
 observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['open']});
 document.addEventListener('visibilitychange',visibility);visibility();
});
onBeforeUnmount(()=>{stop?.();observer?.disconnect();document.removeEventListener('visibilitychange',visibility);store.resumeAll('hidden');});
</script>
<template>
 <Teleport :to="target"><aside ref="host" class="admin-toast-host" popover="manual" aria-label="Notifikasi admin" :class="{'has-toasts':items.length,'in-dialog':target!=='body'}">
  <div class="admin-toast-announcement" aria-live="polite" aria-atomic="true">{{ polite }}</div><div class="admin-toast-announcement" aria-live="assertive" aria-atomic="true">{{ urgent }}</div>
  <TransitionGroup name="admin-toast" tag="div" class="admin-toast-stack">
   <article v-for="item in items" :key="item.id" class="admin-toast" :data-type="item.type" role="group" :aria-label="`${item.title}: ${item.message}`" @mouseenter="store.pause(item.id,'pointer')" @mouseleave="store.resume(item.id,'pointer')" @focusin="store.pause(item.id,'focus')" @focusout="unfocus(item,$event)">
    <span class="admin-toast-icon" :class="{spinning:item.type==='loading'}" aria-hidden="true">{{ icons[item.type] }}</span><div class="admin-toast-copy"><strong>{{ item.title }}</strong><p>{{ item.message }}</p></div>
    <button type="button" class="admin-toast-close" :aria-label="`Tutup notifikasi ${item.title}`" @click="store.dismiss(item.id)">×</button>
    <i v-if="item.duration" :key="`${item.id}:${item.revision}`" class="admin-toast-progress" aria-hidden="true" :style="{animationDuration:`${item.duration}ms`,animationPlayState:item.paused?'paused':'running'}"/>
   </article>
  </TransitionGroup>
 </aside></Teleport>
</template>
<style scoped>
.admin-toast-host{--toast-top:112px;position:fixed;inset:var(--toast-top) 18px auto auto;width:min(410px,calc(100vw - 28px));max-height:calc(100dvh - var(--toast-top) - 16px);margin:0;padding:0;border:0;background:transparent;color:#244a35;overflow:visible;z-index:2147483647;font-family:Inter,Arial,sans-serif;pointer-events:none}.admin-toast-host.in-dialog{--toast-top:16px}.admin-toast-host:not(.has-toasts){display:none}.admin-toast-stack{display:flex;flex-direction:column;gap:10px;max-height:calc(100dvh - var(--toast-top) - 16px);overflow-y:auto;padding:2px 4px 14px;margin:-2px -4px 0}.admin-toast{--accent:#377e52;--tint:#e9f5e7;position:relative;display:flex;align-items:flex-start;gap:12px;min-width:0;padding:16px 12px 17px 16px;border:1px solid #d9e5d4;border-left:4px solid var(--accent);border-radius:12px;background:#fffefb;box-shadow:0 12px 34px #17392124;pointer-events:auto;overflow:hidden;box-sizing:border-box;text-align:left}.admin-toast[data-type=danger]{--accent:#b64a3e;--tint:#ffede8;border-color:#efd0c6;border-left-color:var(--accent)}.admin-toast[data-type=warning]{--accent:#9d6b1f;--tint:#fff4d8;border-color:#eadbb8;border-left-color:var(--accent)}.admin-toast[data-type=info],.admin-toast[data-type=loading]{--accent:#347893;--tint:#eaf5f8;border-color:#cbdfe7;border-left-color:var(--accent)}.admin-toast-icon{display:grid;place-items:center;flex:none;width:29px;height:29px;border-radius:50%;background:var(--tint);color:var(--accent);font:800 17px/1 Inter,Arial,sans-serif}.admin-toast-copy{flex:1;min-width:0}.admin-toast-copy strong{display:block;margin:0 0 5px;color:var(--accent);font-size:12px;line-height:1.3;font-weight:800}.admin-toast-copy p{margin:0;color:#435c49;font-size:12px;font-weight:450;line-height:1.65;overflow-wrap:anywhere;white-space:pre-line;max-height:195px;overflow:auto}.admin-toast-close{flex:none;display:grid;place-items:center;width:28px;height:28px;margin:-5px -3px 0 0;padding:0;border:0;border-radius:6px;background:transparent;color:#71816c;font:22px/1 Arial,sans-serif;cursor:pointer}.admin-toast-close:hover{background:#edf3e7;color:#254f35}.admin-toast-close:focus-visible{outline:3px solid #39899c;outline-offset:1px}.admin-toast-progress{position:absolute;bottom:0;left:0;height:3px;width:100%;background:var(--accent);opacity:.4;transform-origin:left;animation:admin-toast-life linear forwards}.admin-toast-announcement{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap;pointer-events:none}.admin-toast-enter-active,.admin-toast-leave-active,.admin-toast-move{transition:opacity .18s ease,transform .18s ease}.admin-toast-enter-from,.admin-toast-leave-to{opacity:0;transform:translateY(-9px)}.spinning{animation:admin-toast-spin 1.2s linear infinite}@keyframes admin-toast-life{to{transform:scaleX(0)}}@keyframes admin-toast-spin{to{transform:rotate(360deg)}}@media(max-width:600px){.admin-toast-host{--toast-top:104px;inset:var(--toast-top) 12px auto;width:calc(100vw - 24px)}.admin-toast{padding:13px 11px 14px 13px;gap:10px}.admin-toast-copy p{font-size:12px;max-height:150px}}@media(prefers-reduced-motion:reduce){.admin-toast-enter-active,.admin-toast-leave-active,.admin-toast-move{transition:none}.spinning,.admin-toast-progress{animation:none}}
</style>
