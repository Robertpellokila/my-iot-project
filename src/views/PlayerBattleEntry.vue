<script setup>
defineOptions({inheritAttrs:false});
import {computed,onMounted,onBeforeUnmount,provide,ref,watch} from 'vue';
import {useRoute,useRouter} from 'vue-router';
import {supabase} from '../lib/supabase';
import {BATTLE_PLAYER_ACCESS,readPlayerAccess,savePlayerAccess,clearPlayerAccess} from '../lib/battle/playerAccess.js';
import PlayerBattle from './PlayerBattle.vue';
const route=useRoute(),router=useRouter();const code=computed(()=>String(route.params.code??'').trim().toUpperCase()),player=computed(()=>route.params.player==='p2'?'p2':'p1');
const token=ref(''),ready=ref(false),loading=ref(true),submitting=ref(false),accessCode=ref(''),error=ref('');let version=0;
function revoked(message){clearPlayerAccess(code.value,player.value);token.value='';ready.value=false;error.value=message||'Akses diperbarui guru. Masukkan kode pribadi yang terbaru.';}
provide(BATTLE_PLAYER_ACCESS,{token,revoked});
async function validate(){const current=++version;loading.value=true;ready.value=false;error.value='';
 const saved=readPlayerAccess(code.value,player.value);token.value=saved?.token??'';
 if(!token.value){loading.value=false;return;}
 try{const {data,error:failure}=await supabase.rpc('get_battle_player_state',{p_code:code.value,p_player:player.value,p_token:token.value});if(current!==version)return;if(failure)throw failure;if(!data?.ok){revoked(data?.message);return;}ready.value=true;}
 catch{if(current===version)error.value='Koneksi belum tersedia. Coba sambungkan kembali; aksesmu tetap tersimpan pada tab ini.';}
 finally{if(current===version)loading.value=false;}
}
async function enter(){if(submitting.value)return;submitting.value=true;error.value='';const current=version;try{
 const {data,error:failure}=await supabase.rpc('redeem_battle_player_code',{p_access_code:accessCode.value,p_code:code.value,p_player:player.value});if(current!==version)return;if(failure)throw failure;if(!data?.ok){error.value=data?.message||'Kode pribadi belum dapat digunakan.';return;}savePlayerAccess(data.code,data.player,data.token);token.value=data.token;accessCode.value='';ready.value=true;
 }catch{error.value='Belum dapat masuk. Periksa koneksi lalu coba lagi.';}finally{submitting.value=false;}}
watch(()=>[code.value,player.value],()=>{void validate();});
onMounted(async()=>{
 // Deliberately never redeem a credential embedded in a copied URL.
 if(Object.keys(route.query).length)await router.replace({path:route.path,query:{},hash:''});
 await validate();
});onBeforeUnmount(()=>version++);
</script>
<template>
 <PlayerBattle v-if="ready"/>
 <main v-else class="player-access-page"><section class="player-access-card"><span class="access-kicker">TIMEDOOR · PLAYER {{ player==='p1'?'1':'2' }}</span><h1>Masuk ke battle-mu.</h1><p>Battle <b>{{ code }}</b>. Masukkan kode pribadi yang diberikan guru untuk pemain ini. Link halaman saja tidak memberikan akses bermain.</p><p v-if="loading" role="status">Memeriksa akses tersimpan…</p><form v-else @submit.prevent="enter"><label>Kode pribadi pemain<input v-model="accessCode" required autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="20" placeholder="XXXX XXXX XXXX"></label><p v-if="error" class="access-error" role="alert">{{ error }}</p><button type="submit" :disabled="submitting">{{ submitting?'Memeriksa…':'Masuk sebagai Player '+(player==='p1'?'1':'2') }}</button><button v-if="token&&!ready" type="button" class="access-reconnect" @click="validate">Sambungkan kembali</button></form><RouterLink :to="`/battle/${encodeURIComponent(code)}`">Hanya menonton pertandingan →</RouterLink><small>Kode bersifat pribadi. Jika perangkat diganti atau akses ditolak, minta bantuan guru.</small></section></main>
</template>
<style scoped>
.player-access-page{min-height:100dvh;display:grid;place-items:center;padding:24px;background:#f1f7ec;color:#214c33;font-family:Inter,Arial,sans-serif}.player-access-card{width:min(470px,100%);padding:35px;border:1px solid #cfdfc8;border-radius:20px;background:#fff;box-shadow:0 20px 70px #234c2c15}.access-kicker{font-size:10px;letter-spacing:.15em;font-weight:750;color:#739465}.player-access-card h1{font-size:31px;letter-spacing:-.9px;margin:14px 0}.player-access-card p{font-size:13px;line-height:1.8;color:#657e62}.player-access-card label{display:grid;gap:8px;font-size:12px;font-weight:700;margin:23px 0 15px}.player-access-card input{padding:13px;border:1px solid #c8dac4;border-radius:8px;font:650 19px monospace;letter-spacing:.1em;text-transform:uppercase;min-width:0}.player-access-card button{display:block;width:100%;padding:13px;background:#226c40;color:white;font-weight:750;border:1px solid #226c40;border-radius:8px;cursor:pointer}.player-access-card button:disabled{opacity:.6}.player-access-card .access-reconnect{background:white;color:#37703f;margin-top:10px}.player-access-card .access-error{color:#9c532d;background:#fff4e5;padding:12px;border-radius:8px}.player-access-card a{display:block;color:#3b7b43;font-size:12px;margin:22px 0;text-decoration:none}.player-access-card small{display:block;color:#82907b;font-size:10px;line-height:1.8}.player-access-card :is(button,input,a):focus-visible{outline:3px solid #338894;outline-offset:3px}@media(max-width:520px){.player-access-card{padding:26px 22px}.player-access-card h1{font-size:27px}}
</style>
