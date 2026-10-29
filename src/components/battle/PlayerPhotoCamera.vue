<script setup>
import {useAdminFeedback} from '../../composables/useAdminToast.js';
import {nextTick,onMounted,onBeforeUnmount,ref} from 'vue';
const props=defineProps({name:String});const emit=defineEmits(['capture','close']);
const dialog=ref(null),video=ref(null),loading=ref(true),ready=ref(false),capturing=ref(false),error=ref(''),facing=ref('user'),canFlip=ref(false);
let stream,request=0,disposed=false,previousFocus;
function stop(){request++;for(const track of stream?.getTracks()??[])track.stop();stream=null;ready.value=false;if(video.value)video.value.srcObject=null;}
function cameraError(err){return ({NotAllowedError:'Izin kamera belum diberikan. Izinkan kamera di browser, atau gunakan upload foto.',NotFoundError:'Kamera tidak ditemukan. Sambungkan kamera atau gunakan upload foto.',NotReadableError:'Kamera sedang dipakai aplikasi lain. Tutup aplikasi tersebut lalu coba lagi.',OverconstrainedError:'Kamera ini belum mendukung pilihan tersebut. Coba kamera lain.'})[err?.name]||'Kamera belum dapat dibuka. Coba lagi atau gunakan upload foto.';}
async function start(){
 stop();const current=request;loading.value=true;error.value='';
 try{
  if(!window.isSecureContext||!navigator.mediaDevices?.getUserMedia){error.value='Kamera langsung memerlukan HTTPS atau localhost. Kamu tetap bisa memakai upload atau kamera ponsel di bawah.';return;}
  const acquired=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:facing.value},width:{ideal:1280},height:{ideal:960}},audio:false});
  if(disposed||current!==request){for(const track of acquired.getTracks())track.stop();return;}
  stream=acquired;await nextTick();video.value.srcObject=stream;await video.value.play();
  if(disposed||current!==request)return;ready.value=true;
  try{const devices=await navigator.mediaDevices.enumerateDevices();if(current===request)canFlip.value=devices.filter(d=>d.kind==='videoinput').length>1;}catch{/* A single available camera is enough. */}
 }catch(err){if(!disposed&&current===request){error.value=cameraError(err);for(const track of stream?.getTracks()??[])track.stop();stream=null;}}
 finally{if(!disposed&&current===request)loading.value=false;}
}
async function capture(){
 if(!ready.value||capturing.value)return;capturing.value=true;error.value='';const current=request;
 try{
  const frame=video.value;if(!frame?.videoWidth||!frame?.videoHeight)throw new Error('Belum ada gambar kamera. Tunggu sebentar lalu coba lagi.');
  const scale=Math.min(1,1280/Math.max(frame.videoWidth,frame.videoHeight));const canvas=document.createElement('canvas');canvas.width=Math.round(frame.videoWidth*scale);canvas.height=Math.round(frame.videoHeight*scale);canvas.getContext('2d').drawImage(frame,0,0,canvas.width,canvas.height);
  const blob=await new Promise((resolve,reject)=>canvas.toBlob(value=>value?resolve(value):reject(new Error('Foto belum dapat diambil. Coba lagi.')),'image/jpeg',.92));
  if(disposed||current!==request)return;stop();emit('capture',new File([blob],'player-camera.jpg',{type:'image/jpeg',lastModified:Date.now()}));
 }catch(err){error.value=err.message||'Foto belum dapat diambil. Coba lagi.';}
 finally{capturing.value=false;}
}
function fromPhone(event){const file=event.target.files?.[0];event.target.value='';if(file){stop();emit('capture',file);}}
function close(){stop();emit('close');}
function hidden(){if(document.visibilityState==='hidden'){stop();loading.value=false;error.value='Kamera dijeda saat halaman tidak aktif. Tekan Coba kamera lagi untuk melanjutkan.';}}
onMounted(async()=>{previousFocus=document.activeElement;await nextTick();dialog.value?.showModal();dialog.value?.querySelector('h2')?.focus();document.addEventListener('visibilitychange',hidden);void start();});
onBeforeUnmount(()=>{disposed=true;stop();document.removeEventListener('visibilitychange',hidden);dialog.value?.close();if(previousFocus?.isConnected)previousFocus.focus({preventScroll:true});});
const adminToast=useAdminFeedback({error:()=>error.value.includes('dijeda')?'':error.value,warning:()=>error.value.includes('dijeda')?error.value:'',scope:'battle/PlayerPhotoCamera'});
</script>
<template>
 <dialog ref="dialog" class="photo-camera" aria-labelledby="photo-camera-title" @cancel.prevent="close" @click="event=>{if(event.target===dialog)close();}">
  <header><div><span>FOTO PEMAIN</span><h2 id="photo-camera-title" tabindex="-1">Ambil foto {{ name }}</h2><p>Posisikan wajah dan tubuh di tengah. Gunakan cahaya yang cukup.</p></div><button type="button" aria-label="Tutup kamera" @click="close">✕</button></header>
  <div class="camera-preview"><video ref="video" autoplay playsinline muted :class="{mirrored:facing==='user'}" aria-label="Pratinjau kamera"/><p v-if="loading" role="status">Menunggu kamera…</p><p v-else-if="!ready&&!error">Pratinjau kamera belum tersedia.</p><div v-if="ready" class="camera-frame" aria-hidden="true"></div></div>
  <p v-if="error" class="camera-error" role="alert">{{ error }}</p>
  <footer><button type="button" @click="close">Batal</button><button v-if="error" type="button" @click="start">Coba kamera lagi</button><button v-if="canFlip&&ready" type="button" @click="facing=facing==='user'?'environment':'user';start()">Ganti kamera</button><button type="button" class="camera-shutter" :disabled="!ready||capturing" @click="capture">{{ capturing?'Mengambil foto…':'Ambil foto' }}</button></footer>
  <label class="camera-phone"><input type="file" accept="image/jpeg,image/png,image/webp" capture="user" :aria-label="`Ambil foto ${name} dengan kamera ponsel`" @change="fromPhone">Gunakan kamera ponsel / pilih foto</label>
 </dialog>
</template>
<style scoped>
.photo-camera{position:fixed;inset:0;margin:auto;width:min(660px,calc(100% - 24px));max-height:92dvh;overflow:auto;padding:24px;border:1px solid #bfd6c2;border-radius:18px;background:#fbfdf8;color:#264b34;font-family:Inter,Arial,sans-serif;box-sizing:border-box}.photo-camera:not([open]){display:none}.photo-camera::backdrop{background:#183c2a80;backdrop-filter:blur(4px)}.photo-camera header{display:flex;justify-content:space-between;gap:20px}.photo-camera header span{font-size:10px;font-weight:750;letter-spacing:.14em;color:#6c895f}.photo-camera h2{font-size:24px;margin:8px 0;letter-spacing:-.6px}.photo-camera h2:focus{outline:none}.photo-camera header p{font-size:12px;line-height:1.7;color:#71836c;margin:0 0 18px}.photo-camera button{font:700 12px Inter,Arial,sans-serif;border:1px solid #c9dcc7;border-radius:8px;background:#fff;color:#335d3f;padding:11px 15px;cursor:pointer}.photo-camera header button{height:38px;width:38px;flex:none;padding:0}.camera-preview{position:relative;display:grid;place-items:center;aspect-ratio:4/3;overflow:hidden;background:#e1e9df;border-radius:12px}.camera-preview video{width:100%;height:100%;object-fit:contain;position:absolute;inset:0}.camera-preview video.mirrored{transform:scaleX(-1)}.camera-preview>p{z-index:1;font-size:13px;color:#54734f;padding:15px;background:#f3f7eff0;border-radius:8px}.camera-frame{position:absolute;inset:9% 22%;border:1px dashed #fff9;border-radius:45% 45% 28% 28%;pointer-events:none}.photo-camera footer{display:flex;flex-wrap:wrap;gap:9px;justify-content:end;margin-top:18px}.photo-camera .camera-shutter{background:#236a41;border-color:#236a41;color:#fff}.photo-camera button:disabled{opacity:.5;cursor:default}.camera-error{padding:12px;background:#fff3de;border:1px solid #edd7b2;border-radius:8px;font-size:12px;line-height:1.8;color:#8e602a}.camera-phone{display:block;position:relative;width:fit-content;margin:17px auto 0;color:#5f7a57;font-size:11px;text-decoration:underline;cursor:pointer}.camera-phone input{position:absolute;width:1px;height:1px;clip-path:inset(50%);overflow:hidden}.photo-camera button:focus-visible,.camera-phone:has(input:focus-visible){outline:3px solid #2b8898;outline-offset:3px}@media(max-width:520px){.photo-camera{padding:18px}.photo-camera h2{font-size:21px}.photo-camera footer>*{flex:1}.camera-frame{inset:10% 18%}}
</style>
