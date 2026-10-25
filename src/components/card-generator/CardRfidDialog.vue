<script setup>
import {ref,computed,onMounted,onBeforeUnmount} from 'vue';
import {supabase} from '../../lib/supabase.js';
import AlbumCardFace from './AlbumCardFace.vue';
const props=defineProps({card:{type:Object,required:true}});
const emit=defineEmits(['close','linked']);
const dialog=ref(null),uid=ref(''),busy=ref(false),error=ref(''),result=ref(null),reader=ref('connecting');
const valid=computed(()=>uid.value.trim().length>=4&&uid.value.trim().length<=128&&!/[\x00-\x1f\x7f]/.test(uid.value));
let channel,alive=true;
async function link(){
 if(!valid.value||busy.value||result.value)return;
 const scanned=uid.value.trim();busy.value=true;error.value='';
 try{
  const {data,error:e}=await supabase.rpc('link_studio_card_rfid',{p_game_card_id:props.card.id,p_uid:scanned});
  if(e)throw e;if(!data?.id)throw new Error('Hubungan RFID belum tersimpan. Coba lagi.');
  if(!alive)return;result.value=data;emit('linked',data);
 }catch(e){if(alive)error.value=e.message||'RFID belum dapat dihubungkan. Coba lagi.';}finally{busy.value=false;}
}
function close(){if(!busy.value)emit('close');}
function next(){uid.value='';result.value=null;error.value='';}
onMounted(()=>{
 dialog.value.showModal();
 channel=supabase.channel(`studio-rfid:${props.card.id}:${Date.now()}`).on('postgres_changes',{event:'INSERT',schema:'public',table:'scan_events'},payload=>{
  if(!alive||busy.value||result.value)return;
  uid.value=String(payload.new?.uid??'').trim();error.value='';
 }).subscribe(status=>{if(alive)reader.value=status==='SUBSCRIBED'?'ready':['CHANNEL_ERROR','TIMED_OUT','CLOSED'].includes(status)?'offline':'connecting';});
});
onBeforeUnmount(()=>{alive=false;dialog.value?.close();if(channel)supabase.removeChannel(channel);});
</script>
<template>
 <dialog ref="dialog" class="studio-rfid-dialog" aria-labelledby="rfid-heading" @cancel.prevent="close" @click="event=>{if(event.target===dialog)close()}">
  <button class="rfid-close" type="button" aria-label="Tutup panel RFID" :disabled="busy" @click="close">×</button>
  <div class="rfid-layout">
   <div class="rfid-card-summary"><AlbumCardFace :card="card"/><strong>{{ card.name }}</strong><span>{{ card.metadata?.studio_card?.display_code || card.card_code }}</span><dl><div><dt>ATK</dt><dd>{{ card.attack }}</dd></div><div><dt>HP</dt><dd>{{ card.hp }}</dd></div><div><dt>DEF</dt><dd>{{ card.defense }}</dd></div></dl></div>
   <section class="rfid-controls">
    <p class="rfid-eyebrow">KARTU FISIK</p><h2 id="rfid-heading">Hubungkan RFID</h2><p>Data, desain, dan skill mengikuti kartu tersimpan ini. Cukup scan UID kartu fisiknya.</p>
    <template v-if="!result">
     <div class="rfid-reader" role="status"><span aria-hidden="true">◉</span><div><strong>{{ reader==='ready'?'Reader siap menerima scan':reader==='offline'?'Koneksi reader belum tersedia':'Menghubungkan reader…' }}</strong><small>Tempelkan kartu ke reader, atau masukkan UID di bawah.</small></div></div>
     <form @submit.prevent="link"><label for="studio-rfid-uid">UID RFID<input id="studio-rfid-uid" v-model="uid" autofocus autocomplete="off" maxlength="128" placeholder="Scan atau masukkan UID" :disabled="busy" @input="error=''"/></label><p v-if="error" role="alert" class="rfid-error">{{ error }}</p><button class="rfid-primary" type="submit" :disabled="!valid || busy">{{ busy?'Menghubungkan…':'Hubungkan kartu' }}</button></form>
     <p class="rfid-footnote">Satu desain dapat dipakai beberapa kartu fisik. UID yang sudah dipakai kartu lain tidak akan ditimpa.</p>
    </template>
    <div v-else class="rfid-result" role="status"><span aria-hidden="true">✓</span><h3>{{ result.already_linked?'RFID sudah terhubung':'RFID berhasil dihubungkan' }}</h3><p>{{ result.name }}</p><code>{{ result.uid }}</code><p>Kartu fisik ini siap digunakan dalam battle.</p><div><button type="button" class="rfid-primary" @click="next">Hubungkan UID lain</button><button type="button" @click="close">Selesai</button></div></div>
   </section>
  </div>
 </dialog>
</template>
<style scoped>
.studio-rfid-dialog{box-sizing:border-box;width:min(820px,calc(100vw - 28px));max-height:90dvh;padding:0;border:1px solid #cbdcca;border-radius:20px;background:#fff;color:#214b37;box-shadow:0 24px 90px #173b2933;overflow:auto;font-family:Inter,Arial,sans-serif}.studio-rfid-dialog::backdrop{background:#dce8ddc9;backdrop-filter:blur(5px)}.rfid-close{position:absolute;right:14px;top:12px;z-index:1;font-size:24px;padding:0 9px}.rfid-layout{display:grid;grid-template-columns:260px minmax(0,1fr)}.rfid-card-summary{padding:30px;background:#edf5e8;display:flex;flex-direction:column;gap:10px;min-width:0}.rfid-card-summary>strong{font-size:14px;line-height:1.5;overflow-wrap:anywhere}.rfid-card-summary>span{font-size:11px;color:#667e6a}.rfid-card-summary dl{display:flex;gap:20px;margin:5px 0}.rfid-card-summary dt{font-size:9px;color:#637d68}.rfid-card-summary dd{font-size:20px;font-weight:750;margin:4px 0}.rfid-controls{padding:44px 30px 30px;min-width:0}.rfid-eyebrow{font-size:10px!important;letter-spacing:.14em;color:#39804d!important;font-weight:800}.rfid-controls h2{font-size:27px;line-height:1.2;letter-spacing:-.8px;margin:8px 0 12px}.rfid-controls>p,.rfid-controls small{font-size:12px;line-height:1.7;color:#667e6a}.rfid-reader{display:flex;gap:12px;align-items:center;padding:15px;margin:22px 0;border:1px solid #cfe0cc;border-radius:11px;background:#f5faf2}.rfid-reader>span{font-size:28px;color:#237e45}.rfid-reader strong{font-size:12px}.rfid-reader small{display:block;margin-top:3px;font-size:10px}.rfid-controls label{display:grid;gap:8px;font-size:12px;font-weight:650}.rfid-controls input{box-sizing:border-box;width:100%;min-width:0;padding:13px;border:1px solid #bcd4be;border-radius:9px;background:#fff;color:#214b37;font:15px ui-monospace,monospace}.rfid-controls button,.rfid-close{cursor:pointer;border:1px solid #cbdcca;border-radius:8px;background:#fff;color:#28583a;font-weight:650}.rfid-controls button{padding:12px 16px;font-size:12px}.rfid-controls form>button{width:100%;margin-top:14px}.rfid-primary{background:#246443!important;border-color:#246443!important;color:#fff!important}.rfid-controls button:disabled,.rfid-close:disabled{opacity:.5;cursor:default}.rfid-controls .rfid-footnote{font-size:10px;margin-top:16px}.rfid-error{padding:10px;border-radius:8px;background:#fff1e6;color:#914728;font-size:12px;line-height:1.6}.rfid-result{padding-top:20px}.rfid-result>span{display:grid;place-items:center;width:45px;height:45px;border-radius:50%;background:#e4f3dc;color:#267941;font-size:26px}.rfid-result h3{font-size:19px;line-height:1.5}.rfid-result p{font-size:12px;line-height:1.6}.rfid-result code{overflow-wrap:anywhere;font-size:15px}.rfid-result>div{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px}:is(input,button):focus-visible{outline:3px solid #509b66;outline-offset:3px}@media(max-width:600px){.rfid-layout{grid-template-columns:1fr}.rfid-card-summary{display:none}.rfid-controls{padding:42px 22px 24px}}
</style>
