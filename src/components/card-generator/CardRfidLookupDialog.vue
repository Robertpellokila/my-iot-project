<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { supabase } from '../../lib/supabase.js';
import AlbumCardFace from './AlbumCardFace.vue';
const emit=defineEmits(['close','open-card','link-uid']);
const props=defineProps({canLink:Boolean,currentName:String});
const dialog=ref(null),uid=ref(''),result=ref(null),busy=ref(false),error=ref(''),reader=ref('connecting'),lastReader=ref('');
const valid=computed(()=>uid.value.trim().length>=4&&uid.value.trim().length<=128&&!/[\x00-\x1f\x7f]/.test(uid.value));
let channel,alive=true,request=0;
watch(uid,()=>{request++;result.value=null;error.value='';busy.value=false;},{flush:'sync'});
async function lookup(value=uid.value){
 uid.value=String(value??'').trim().toUpperCase();
 if(!valid.value){error.value='Masukkan UID 4–128 karakter atau tap kartu ke reader.';return;}
 const version=++request;busy.value=true;result.value=null;error.value='';
 try{
  const {data,error:failure}=await supabase.rpc('admin_lookup_card_rfid',{p_uid:uid.value});
  if(!alive||version!==request)return;
  if(failure)throw failure;
  if(!data||!Array.isArray(data.cards))throw new Error('Hasil pembacaan belum tersedia. Coba cek lagi.');
  result.value=data;
 }catch(failure){if(alive&&version===request)error.value=failure.code==='PGRST202'?'Menu cek RFID belum tersedia di server. Hubungi admin untuk memperbarui aplikasi.':failure.message||'Kartu belum dapat diperiksa. Coba lagi.';}
 finally{if(alive&&version===request)busy.value=false;}
}
onMounted(()=>{
 dialog.value.showModal();
 channel=supabase.channel(`studio-rfid-lookup:${Date.now()}`).on('postgres_changes',{event:'INSERT',schema:'public',table:'scan_events'},payload=>{
  if(!alive||!payload.new?.uid)return;
  lastReader.value=payload.new.device_id||'';
  void lookup(payload.new.uid);
 }).subscribe(status=>{if(alive)reader.value=status==='SUBSCRIBED'?'ready':['CHANNEL_ERROR','TIMED_OUT','CLOSED'].includes(status)?'offline':'connecting';});
});
onBeforeUnmount(()=>{alive=false;request++;dialog.value?.close();if(channel)supabase.removeChannel(channel);});
</script>
<template>
 <dialog ref="dialog" class="rfid-lookup" aria-labelledby="rfid-lookup-title" @cancel.prevent="emit('close')" @click="event=>{if(event.target===dialog)emit('close')}">
  <header><div><span class="lookup-eyebrow">CARD STUDIO · KARTU FISIK</span><h2 id="rfid-lookup-title">Cek kartu RFID</h2><p>Tap kartu untuk melihat data yang terhubung ke UID-nya.</p></div><button class="lookup-close" type="button" aria-label="Tutup cek RFID" @click="emit('close')">×</button></header>
  <div class="lookup-reader" :class="reader" role="status"><span aria-hidden="true">◉</span><div><strong>{{ reader==='ready'?'Siap menerima tap kartu':reader==='offline'?'Koneksi scan terputus':'Menghubungkan ke scan kartu…' }}</strong><small>{{ reader==='offline'?'Masukkan UID secara manual sambil menunggu koneksi pulih.':'Mendengarkan scan baru dari reader yang terhubung.' }}{{ lastReader?` Scan terakhir: ${lastReader}.`:'' }}</small></div></div>
  <form @submit.prevent="lookup()"><label for="rfid-lookup-uid">UID kartu<input id="rfid-lookup-uid" v-model="uid" autofocus maxlength="128" autocomplete="off" spellcheck="false" placeholder="Tap kartu atau ketik UID"/></label><button class="lookup-primary" type="submit" :disabled="busy||!valid">{{ busy?'Memeriksa…':'Cek UID' }}</button></form>
  <p v-if="error" class="lookup-error" role="alert">{{ error }}</p>
  <div v-if="busy" class="lookup-empty" role="status">Mencari kartu dengan UID {{ uid }}…</div>
  <section v-else-if="result" class="lookup-result" aria-live="polite">
   <div class="lookup-result-heading"><strong :class="result.registered?'found':'new'">{{ result.cards.length?'✓ Kartu ditemukan':result.registered?'UID sudah terdaftar':'UID baru' }}</strong><code>{{ result.uid }}</code></div>
   <p v-if="result.cards.length>1" class="lookup-error">UID ini terhubung ke beberapa data kartu. Periksa kartunya di Album sebelum mengubah hubungan RFID.</p>
   <article v-for="card in result.cards" :key="card.id" class="lookup-card">
    <div class="lookup-art"><AlbumCardFace :card="card"/></div>
    <div class="lookup-card-info"><span class="lookup-code">{{ card.metadata?.studio_card?.display_code||card.card_code }}</span><h3>{{ card.name }}</h3><p>{{ card.element }} · {{ card.rarity }}</p><dl><div><dt>HP</dt><dd>{{ card.hp }}</dd></div><div><dt>ATK</dt><dd>{{ card.attack }}</dd></div><div><dt>DEF</dt><dd>{{ card.defense }}</dd></div></dl><p class="lookup-card-status">{{ card.archived_at?'Kartu ada di Sampah. Pulihkan di Album untuk menggunakannya.':card.battle_enabled===false?'Kartu dinonaktifkan untuk battle.':card.physical_scan_enabled===false?'Data kartu tersimpan; scan untuk battle dinonaktifkan.':'Kartu aktif dan terhubung ke RFID.' }}</p><button v-if="!card.archived_at" type="button" class="lookup-primary" @click="emit('open-card',card.id)">Buka di Studio →</button><RouterLink v-else :to="{name:'album-card'}" @click="emit('close')">Buka Album untuk memulihkan →</RouterLink></div>
   </article>
   <div v-if="!result.cards.length" class="lookup-new"><span aria-hidden="true">▤</span><h3>{{ result.registration?'Belum terhubung ke kartu battle':'Kartu fisik ini belum terdaftar' }}</h3><p v-if="result.registration">UID tercatat di daftar RFID{{ result.registration.label?` sebagai ${result.registration.label}`:'' }}. Pilih desain kartu untuk menggunakannya dalam battle.</p><p v-else>Kamu bisa menghubungkan UID ini ke desain kartu yang sedang dibuka di Studio.</p><button v-if="canLink" type="button" class="lookup-primary" @click="emit('link-uid',result.uid)">Hubungkan ke {{ currentName||'kartu yang dibuka' }}</button><p v-else>Pilih kartu Base di Studio terlebih dahulu, lalu hubungkan RFID.</p></div>
  </section>
  <div v-else class="lookup-empty"><span aria-hidden="true">▣</span><strong>Tempelkan satu kartu ke reader</strong><p>Gambar dan data kartu akan muncul di sini. Kamu juga bisa mengetik UID di atas.</p></div>
  <footer>Menu ini hanya memeriksa data. Hubungan UID berubah setelah kamu memilih dan mengonfirmasi Hubungkan RFID.</footer>
 </dialog>
</template>
<style scoped>
.rfid-lookup{--ink:#173c36;--green:#197344;--muted:#5f786b;box-sizing:border-box;width:min(800px,calc(100vw - 24px));max-height:90dvh;overflow:auto;padding:28px;border:1px solid #c1d8c7;border-radius:20px;background:#fcfefb;color:var(--ink);font-family:Inter,Arial,sans-serif;box-shadow:0 20px 80px #173c3640}.rfid-lookup::backdrop{background:#142c3466;backdrop-filter:blur(5px)}.rfid-lookup header{display:flex;align-items:start;justify-content:space-between;gap:15px}.lookup-eyebrow{font-size:10px;letter-spacing:.12em;font-weight:750;color:var(--green)}.rfid-lookup h2{font-size:28px;letter-spacing:-.7px;margin:8px 0}.rfid-lookup p{font-size:13px;line-height:1.65;color:var(--muted);margin:6px 0 12px}.rfid-lookup button{border:1px solid #c1d8c7;border-radius:9px;padding:11px 16px;font:700 12px/1.5 Inter,Arial,sans-serif;background:white;color:var(--ink);cursor:pointer}.rfid-lookup .lookup-close{padding:3px 12px;font-size:25px}.lookup-reader{display:flex;gap:14px;align-items:center;margin:18px 0;padding:15px;background:#edf7ef;border:1px solid #c1decc;border-radius:12px}.lookup-reader>span{font-size:28px;color:var(--green)}.lookup-reader strong{font-size:13px}.lookup-reader small{display:block;font-size:11px;line-height:1.6;color:var(--muted);margin-top:4px;overflow-wrap:anywhere}.lookup-reader.offline{background:#fff8eb;border-color:#e5cf99}.rfid-lookup form{display:flex;align-items:end;gap:12px}.rfid-lookup form label{display:grid;gap:7px;flex:1;min-width:0;font-size:12px;font-weight:700}.rfid-lookup input{width:100%;box-sizing:border-box;padding:12px;border:1px solid #b3cfc0;border-radius:9px;background:white;color:var(--ink);font:15px/1.4 ui-monospace,monospace}.rfid-lookup .lookup-primary{background:var(--green);color:white;border-color:var(--green)}.rfid-lookup button:disabled{opacity:.5;cursor:default}.lookup-error{padding:12px;border:1px solid #e3b6a6;border-radius:9px;background:#fff3ec;color:#8a3b24!important}.lookup-empty{display:grid;justify-items:center;text-align:center;padding:35px 18px;margin:20px 0;border:2px dashed #c2d8cc;border-radius:14px;background:#f4f9f5;font-size:14px}.lookup-empty>span{font-size:40px;color:#73a38a;margin-bottom:14px}.lookup-empty strong{font-size:16px}.lookup-empty p{max-width:360px}.lookup-result-heading{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:24px 0 15px}.lookup-result-heading strong{font-size:12px;padding:7px 12px;border-radius:6px;background:#e1f1e6;color:#226f43}.lookup-result-heading strong.new{background:#e8f2ff;color:#2163a2}.lookup-result-heading code{font:13px ui-monospace,monospace;overflow-wrap:anywhere}.lookup-card{display:grid;grid-template-columns:180px minmax(0,1fr);gap:26px;padding:22px;border:1px solid #c8ddcf;border-radius:14px;background:white;margin-bottom:12px}.lookup-art{align-self:start}.lookup-code{font:700 11px ui-monospace,monospace;color:#5b7e69}.lookup-card h3{font-size:24px;line-height:1.3;margin:8px 0;overflow-wrap:anywhere}.lookup-card dl{display:flex;gap:25px;padding:14px 0;border-top:1px solid #deebe1;border-bottom:1px solid #deebe1;margin:15px 0}.lookup-card dt{font-size:10px;color:var(--muted)}.lookup-card dd{font-size:25px;font-weight:800;margin:4px 0 0;font-variant-numeric:tabular-nums}.lookup-card-status{font-size:12px!important}.lookup-card a{font-size:12px;color:var(--green);font-weight:700}.lookup-new{padding:25px;border:1px solid #c9daec;border-radius:14px;background:#f1f8ff;text-align:center}.lookup-new>span{color:#397da8;font-size:35px}.lookup-new h3{font-size:20px;margin:10px 0}.rfid-lookup footer{margin-top:20px;font-size:10px;line-height:1.7;color:#70867b}.rfid-lookup :is(input,button,a):focus-visible{outline:3px solid #2e8ba5;outline-offset:3px}@media(max-width:520px){.rfid-lookup{padding:21px 17px}.rfid-lookup h2{font-size:25px}.lookup-card{grid-template-columns:minmax(0,1fr);padding:18px;gap:18px}.lookup-art{width:180px;max-width:100%;margin:0 auto}.lookup-card h3{font-size:18px}.lookup-card dl{gap:13px}.lookup-card dd{font-size:20px}.lookup-result-heading{align-items:start;flex-direction:column}.lookup-card .lookup-primary{width:100%}.lookup-new{padding:20px 15px}}
</style>
