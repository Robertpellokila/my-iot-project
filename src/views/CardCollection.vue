<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue';
import { supabase } from '../lib/supabase';
import { normalizeTcgType } from '../utils/tcgTypes.js';
import AlbumCardFace from '../components/card-generator/AlbumCardFace.vue';

const cards=ref([]),skills=ref([]),links=ref([]),loading=ref(true),error=ref(''),notice=ref('');
const skillStatusKnown=ref(false);
const search=ref(''),element=ref('All'),filter=ref('all'),page=ref(1),pageSize=8;
const elements=['All','Knight','Fire','Water','Forest','Thunder','Light','Dark'];
const dialog=ref(null),selectedId=ref(null),saving=ref(null),publication=ref({});
const flip=ref(null);let flipTimer,opener;
const selected=computed(()=>cards.value.find(card=>card.id===selectedId.value));
const battleSkillCount=computed(()=>links.value.filter(link=>link.game_card_id===selected.value?.id&&link.enabled&&skills.value.some(skill=>skill.id===link.special_skill_id&&skill.is_active&&!skill.metadata?.catalog_only&&Array.isArray(skill.effects)&&skill.effects.length>0)).length);
const filtered=computed(()=>cards.value.filter(card=>{
 const keyword=search.value.trim().toLowerCase();
 return (!keyword||[card.name,card.card_code,card.uid,card.metadata?.source_card_code].some(v=>String(v??'').toLowerCase().includes(keyword)))
 &&(element.value==='All'||normalizeTcgType(card.element)===element.value.toLowerCase())
 &&(filter.value==='all'||filter.value==='studio'&&card.metadata?.studio_card||filter.value==='rfid'&&card.uid||filter.value==='published'&&card.featured_on_landing&&card.landing_active);
}));
const pages=computed(()=>Math.max(1,Math.ceil(filtered.value.length/pageSize)));
const spread=index=>filtered.value.slice((index-1)*pageSize,index*pageSize);
const current=computed(()=>spread(page.value));
const slots=items=>Array.from({length:4},(_,i)=>items[i]??null);
const halves=computed(()=>[slots(current.value.slice(0,4)),slots(current.value.slice(4,8))]);
const published=computed(()=>cards.value.filter(c=>c.featured_on_landing&&c.landing_active).length);
const cardSkills=computed(()=>{
 const card=selected.value;if(!card)return [];
 if(card.metadata?.studio_card)return card.metadata.skills??card.metadata.studio_card.skills??[];
 const attached=links.value.filter(l=>l.game_card_id===card.id&&l.enabled).sort((a,b)=>a.sort_order-b.sort_order).map(l=>{
  const skill=skills.value.find(s=>s.id===l.special_skill_id);return skill?{...skill,...l.overrides}:null;
 }).filter(Boolean);
 return attached.length?attached:card.metadata?.skills??[];
});
async function loadCards(){
 loading.value=true;error.value='';
 try{
  const [a,b,c]=await Promise.all([
   supabase.from('game_cards').select('*').order('name'),
   supabase.from('special_skills').select('id,name,description,icon,metadata,is_active,effects'),
   supabase.from('game_card_special_skills').select('game_card_id,special_skill_id,sort_order,enabled,overrides').eq('enabled',true),
  ]);
  if(a.error)throw a.error;cards.value=a.data??[];skills.value=b.data??[];links.value=c.data??[];skillStatusKnown.value=!b.error&&!c.error;
  page.value=Math.min(page.value,pages.value);
 }catch(e){error.value=e.message||'Koleksi belum dapat dimuat.';}finally{loading.value=false;}
}
function endFlip(){clearTimeout(flipTimer);flip.value=null;}
function turnPage(target){
 if(flip.value||target<1||target>pages.value||target===page.value)return;
 const old=spread(page.value),next=spread(target),forward=target>page.value;
 if(!matchMedia('(prefers-reduced-motion: reduce)').matches){
  flip.value={direction:forward?'next':'previous',front:slots(forward?old.slice(4):old.slice(0,4)),back:slots(forward?next.slice(0,4):next.slice(4)),under:slots(forward?old.slice(0,4):old.slice(4))};
  flipTimer=setTimeout(endFlip,760);
 }
 page.value=target;
}
watch(pages,value=>{if(page.value>value){endFlip();page.value=value;}});
watch([search,element,filter],()=>{endFlip();page.value=1;});
async function openCard(card,event){
 selectedId.value=card.id;publication.value={featured_on_landing:!!card.featured_on_landing,landing_active:card.landing_active!==false,landing_group:card.landing_group||'',landing_display_order:card.landing_display_order||0};
 error.value='';opener=event?.currentTarget;await nextTick();dialog.value.showModal();
}
function closeCard(){dialog.value?.close();selectedId.value=null;opener?.focus();}
async function publish(card,changes){
 if(saving.value)return false;saving.value=card.id;error.value='';notice.value='';
 try{
  const {data,error:e}=await supabase.from('game_cards').update(changes).eq('id',card.id).select('id,featured_on_landing,landing_active,landing_group,landing_display_order').single();
  if(e)throw e;if(!data)throw new Error('Perubahan belum tersimpan. Silakan masuk kembali.');
  Object.assign(card,data);notice.value=`Pengaturan tampilan ${card.name} tersimpan.`;return true;
 }catch(e){error.value=e.message||'Pengaturan belum dapat disimpan.';return false;}finally{saving.value=null;}
}
async function savePublication(){
 const order=Number(publication.value.landing_display_order);
 if(!Number.isInteger(order)||Math.abs(order)>100000){error.value='Urutan harus bilangan bulat antara −100000 dan 100000.';return;}
 if(await publish(selected.value,{...publication.value,landing_display_order:order}))closeCard();
}
onMounted(loadCards);onBeforeUnmount(endFlip);
</script>

<template>
 <main class="card-album">
  <header class="album-heading">
   <div><p class="eyebrow">TIMEDOOR · CARD COLLECTION</p><h1>Album Card</h1><p>Koleksi desain dan kartu RFID. Pilih kartu untuk ditampilkan di halaman publik.</p></div>
   <div class="album-totals"><strong>{{ cards.length }}<span>kartu tersimpan</span></strong><strong>{{ published }}<span>tampil di publik</span></strong></div>
  </header>
  <div v-if="error" role="alert" class="album-alert">{{ error }} <button @click="error=''" aria-label="Tutup pesan">×</button></div>
  <p v-if="notice" role="status" class="album-notice">{{ notice }}</p>
  <section class="album-tools" aria-label="Cari dan filter kartu">
   <label class="album-search"><span>Cari koleksi</span><input v-model="search" placeholder="Nama, kode kartu, atau RFID…" type="search"></label>
   <label><span>Daftar kartu</span><select v-model="filter"><option value="all">Semua kartu</option><option value="studio">Desain Studio</option><option value="rfid">Memiliki RFID</option><option value="published">Tampil di publik</option></select></label>
   <button @click="loadCards" :disabled="loading">{{ loading?'Memuat…':'↻ Refresh' }}</button>
   <RouterLink :to="{name:'card-generator'}" class="album-primary">+ Buat kartu</RouterLink>
   <div class="album-types"><button v-for="type in elements" :key="type" :class="{chosen:element===type}" :aria-pressed="element===type" @click="element=type">{{ type==='All'?'Semua tipe':type }}</button></div>
  </section>
  <p v-if="loading" class="album-empty" role="status">Membuka koleksi…</p>
  <p v-else-if="!filtered.length" class="album-empty">Belum ada kartu yang sesuai. Simpan desain dari Card Studio atau ubah filter pencarian.</p>
  <template v-else>
   <div class="album-book" :class="{'is-turning':flip}" aria-label="Halaman album">
    <section v-for="(half,side) in halves" :key="side" class="album-page" :class="side?'page-right':'page-left'" :aria-label="`Halaman ${(page-1)*2+side+1}`">
     <header class="page-heading"><span>{{ side?'TIMEDOOR BATTLE CARDS':'KOLEKSI KARTU' }}</span><span>{{ (page-1)*2+side+1 }}</span></header>
     <div class="album-grid">
      <article v-for="(card,index) in half" :key="card?.id??index" class="album-pocket" :class="{vacant:!card}">
       <template v-if="card">
        <button class="album-open" :aria-label="`Lihat ${card.name}`" @click="openCard(card,$event)"><AlbumCardFace :card="card" /></button>
        <div class="pocket-caption"><strong>{{ card.name }}</strong><span>{{ card.uid?`RFID · ${card.uid}`:card.metadata?.studio_card?'Desain Studio':'Katalog' }}</span></div>
        <button class="publish-toggle" :class="{published:card.featured_on_landing&&card.landing_active}" :aria-pressed="!!(card.featured_on_landing&&card.landing_active)" :disabled="!!saving" @click="publish(card,{featured_on_landing:!(card.featured_on_landing&&card.landing_active),landing_active:true})">{{ saving===card.id?'Menyimpan…':card.featured_on_landing&&card.landing_active?'✓ Tampil di publik':'Tampilkan di publik' }}</button>
       </template>
       <span v-else aria-hidden="true">✦</span>
      </article>
     </div>
    </section>
    <template v-if="flip">
     <div class="flip-under album-page" :class="flip.direction==='next'?'page-left':'page-right'" aria-hidden="true"><div class="page-heading">TIMEDOOR BATTLE CARDS</div><div class="album-grid"><div v-for="(card,i) in flip.under" :key="i" class="album-pocket" :class="{vacant:!card}"><AlbumCardFace v-if="card" :card="card" /><div v-if="card" class="pocket-caption"><strong>{{ card.name }}</strong><span>{{ card.uid?`RFID · ${card.uid}`:card.metadata?.studio_card?'Desain Studio':'Katalog' }}</span></div><span v-if="card" class="publish-toggle static-publish" :class="{published:card.featured_on_landing&&card.landing_active}">{{ card.featured_on_landing&&card.landing_active?'✓ Tampil di publik':'Tampilkan di publik' }}</span></div></div></div>
     <div class="album-leaf" :class="`flip-${flip.direction}`" aria-hidden="true" @animationend.self="endFlip">
      <div v-for="face in ['front','back']" :key="face" class="leaf-face album-page" :class="`leaf-${face}`"><div class="page-heading">TIMEDOOR BATTLE CARDS</div><div class="album-grid"><div v-for="(card,i) in flip[face]" :key="i" class="album-pocket" :class="{vacant:!card}"><AlbumCardFace v-if="card" :card="card" /><div v-if="card" class="pocket-caption"><strong>{{ card.name }}</strong><span>{{ card.uid?`RFID · ${card.uid}`:card.metadata?.studio_card?'Desain Studio':'Katalog' }}</span></div><span v-if="card" class="publish-toggle static-publish" :class="{published:card.featured_on_landing&&card.landing_active}">{{ card.featured_on_landing&&card.landing_active?'✓ Tampil di publik':'Tampilkan di publik' }}</span></div></div></div>
     </div>
    </template>
   </div>
   <nav class="album-pagination" aria-label="Pagination album"><button :disabled="page===1||!!flip" @click="turnPage(page-1)">← Sebelumnya</button><p aria-live="polite">Lembar <strong>{{ page }}</strong> dari {{ pages }} <span>· {{ filtered.length }} kartu</span></p><button :disabled="page===pages||!!flip" @click="turnPage(page+1)">Berikutnya →</button></nav>
  </template>
  <dialog ref="dialog" class="album-dialog" aria-labelledby="album-detail-title" @cancel.prevent="closeCard" @click="($event.target===dialog)&&closeCard()">
   <div v-if="selected" class="album-dialog-content">
    <button class="album-close" @click="closeCard" aria-label="Tutup detail kartu" autofocus>×</button>
    <div class="album-detail-art"><AlbumCardFace :card="selected" /></div>
    <div class="album-detail-info">
     <p class="eyebrow">{{ selected.metadata?.studio_card?'DESAIN STUDIO':'KATALOG KARTU' }}</p><h2 id="album-detail-title">{{ selected.name }}</h2><p>{{ selected.element }} · {{ selected.rarity || 'Common' }} · {{ selected.metadata?.studio_card?.display_code || selected.card_code }}</p>
     <dl class="detail-stats"><div v-for="[key,label] in [['hp','HP'],['attack','ATK'],['defense','DEF']]" :key="key"><dt>{{ label }}</dt><dd>{{ selected[key] }}</dd></div></dl>
     <section class="detail-skills"><h3>Skill kartu</h3><article v-for="(skill,i) in cardSkills" :key="i"><strong>{{ skill.name||`Skill ${i+1}` }}</strong><p>{{ skill.description }}</p></article><p v-if="!cardSkills.length">Belum ada data skill. Lengkapi di Studio.</p></section>
     <p v-if="selected.metadata?.studio_card" class="skill-binding-status"><strong>{{ skillStatusKnown?`${battleSkillCount} skill terhubung ke battle`:'Status skill battle belum dapat dimuat' }}</strong><span v-if="skillStatusKnown&&!battleSkillCount">Teks skill tersimpan pada desain. Efek battle belum dikonfigurasi untuk kartu ini.</span><RouterLink :to="{name:'skill-catalog'}">Buka Skill &amp; Catalog →</RouterLink></p>
     <p class="rfid-status">{{ selected.uid?`RFID terhubung: ${selected.uid}`:'Belum terhubung ke RFID · siap digunakan sebagai sumber registrasi.' }}</p>
     <div class="detail-actions"><RouterLink :to="{name:'card-generator',query:{catalog:selected.id}}" class="album-primary">Edit di Studio</RouterLink><RouterLink v-if="!selected.fusion_only" :to="{name:'card-generator',query:{catalog:selected.id,rfid:'1'}}">Hubungkan RFID</RouterLink></div>
     <form class="publication-form" @submit.prevent="savePublication"><h3>Tampilan halaman publik</h3><label class="check-label"><input v-model="publication.featured_on_landing" type="checkbox"> Pilih untuk halaman publik</label><label class="check-label"><input v-model="publication.landing_active" type="checkbox"> Aktif ditampilkan</label><div class="publication-fields"><label>Kelompok<input v-model="publication.landing_group" maxlength="80" placeholder="Contoh: Starter team"></label><label>Urutan<input v-model.number="publication.landing_display_order" type="number" min="-100000" max="100000" step="1"></label></div><p v-if="error" role="alert" class="album-alert">{{ error }}</p><button type="submit" class="album-primary" :disabled="!!saving">{{ saving?'Menyimpan…':'Simpan pengaturan tampilan' }}</button></form>
    </div>
   </div>
  </dialog>
 </main>
</template>

<style scoped>
.card-album{--ink:#214b37;--muted:#697e6b;--line:#d7e1d2;min-height:100%;padding:32px;background:#f4f7f0;color:var(--ink);font-family:Inter,Arial,sans-serif}.card-album *{box-sizing:border-box}.album-heading{display:flex;justify-content:space-between;align-items:center;gap:25px;margin-bottom:28px}.eyebrow{font-size:10px!important;font-weight:800;letter-spacing:.15em;color:#568164!important;margin:0 0 9px!important}h1{font-size:36px;letter-spacing:-1.4px;margin:0 0 10px;line-height:1.1}h2{font-size:27px;line-height:1.18;margin:0 0 10px;overflow-wrap:anywhere}h3{font-size:14px;margin:0 0 14px}.album-heading p{font-size:13px;margin:0;line-height:1.6;color:var(--muted)}.album-totals{display:flex;gap:28px;flex-shrink:0}.album-totals strong{font-size:30px}.album-totals span{display:block;font-size:10px;font-weight:500;margin-top:5px;color:var(--muted)}
button,a,input,select{font:inherit}button,a{transition:background .15s}button,.detail-actions a,.album-tools>a{background:#fff;border:1px solid var(--line);color:var(--ink);border-radius:8px;padding:11px 16px;font-size:12px;font-weight:650;text-decoration:none;cursor:pointer}button:hover,a:hover{background:#eaf3e6}button:disabled{opacity:.5;cursor:default}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #498576;outline-offset:3px}.album-primary{background:#246443!important;color:#fff!important;border-color:#246443!important}.album-primary:hover{background:#184b30!important}.album-tools{display:flex;flex-wrap:wrap;align-items:end;gap:12px;margin-bottom:24px}.album-tools label{display:flex;flex-direction:column;gap:6px;font-size:11px;color:var(--muted)}.album-search{flex:1;min-width:200px}input:not([type=checkbox]),select{width:100%;min-width:0;border:1px solid var(--line);border-radius:8px;background:#fff;color:var(--ink);padding:11px 12px;font-size:13px}input[type=checkbox]{accent-color:#246443;width:16px;height:16px}.album-types{display:flex;flex-wrap:wrap;gap:7px;width:100%;margin-top:4px}.album-types button{padding:8px 13px;font-size:11px}.album-types .chosen{background:#e0eddb;border-color:#7eab7d}.album-alert,.album-notice{padding:13px 17px;background:#fff2e8;border:1px solid #e9c7ac;border-radius:9px;font-size:13px;line-height:1.5;margin:15px 0}.album-alert button{float:right;padding:0 7px}.album-notice{background:#e8f3df;border-color:#c4ddb6}.album-empty{padding:70px 25px;text-align:center;background:#fff;border:1px solid var(--line);border-radius:14px;color:var(--muted)}
.album-book{position:relative;display:flex;perspective:2400px;border-radius:8px 16px 16px 8px;border:1px solid #d8d8c5;border-bottom:7px double #c9cbb8;background:#e4e6d6;box-shadow:0 15px 35px #30452812,0 3px 0 #fdfdf8;isolation:isolate}.album-page{width:50%;min-width:0;background:#fffef7;padding:20px 22px 24px}.page-left{border-radius:8px 0 0 8px;background:linear-gradient(90deg,#fffef7 94%,#e4e3d6)}.page-right{border-radius:0 16px 16px 0;background:linear-gradient(90deg,#d6d7c9,#fffef7 6%)}.page-heading{display:flex;justify-content:space-between;gap:8px;font-size:9px;letter-spacing:.13em;font-weight:700;color:#84917b;margin-bottom:18px;height:14px}.album-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px 18px}.album-pocket{min-width:0;padding:10px;border:1px solid #e5e8dc;background:linear-gradient(130deg,#ffffffb3,#eef1e377);border-radius:12px;box-shadow:inset 0 1px #fff,0 2px 3px #253e1e07}.album-open{display:block;width:100%;padding:0;border:0;border-radius:8px;background:transparent!important;box-shadow:0 4px 8px #1d3d2820;text-align:left;overflow:hidden}.pocket-caption{margin:10px 0;display:flex;flex-direction:column;gap:4px}.pocket-caption strong{font-size:11px;line-height:1.35;overflow-wrap:anywhere}.pocket-caption span{font-size:9px;color:var(--muted);overflow-wrap:anywhere}.publish-toggle{padding:7px 4px;width:100%;font-size:10px;background:#fffef9}.publish-toggle.published{color:#287345;border-color:#a2c695;background:#eaf5df}.static-publish{display:block;text-align:center;border:1px solid var(--line);border-radius:8px;font-weight:650}.vacant{position:relative;min-height:200px;display:flex;flex-direction:column;border-style:dashed;background:#ffffff40;color:#c2cdb6}.vacant::before{content:"";display:block;aspect-ratio:63/88;width:100%}.vacant::after{content:"";height:79px}.vacant>span{position:absolute;top:45%;left:45%;font-size:30px}.album-pagination{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:24px 0 6px}.album-pagination p{font-size:12px;color:var(--muted)}.album-pagination strong{color:var(--ink)}
.flip-under{position:absolute;top:0;bottom:0;z-index:2;pointer-events:none}.flip-under.page-left{left:0}.flip-under.page-right{right:0}.album-leaf{position:absolute;top:0;bottom:0;width:50%;z-index:3;transform-style:preserve-3d;pointer-events:none}.flip-next{left:50%;transform-origin:left;animation:turn-next .72s cubic-bezier(.35,.05,.25,1) both}.flip-previous{left:0;transform-origin:right;animation:turn-previous .72s cubic-bezier(.35,.05,.25,1) both}.leaf-face{position:absolute;inset:0;width:100%;height:100%;backface-visibility:hidden;overflow:hidden;box-shadow:0 12px 45px #1c302544}.leaf-front{background:linear-gradient(90deg,#e6e5d9,#fffef7 10%,#fffef7 85%,#f2f0e1)}.leaf-back{transform:rotateY(180deg);background:linear-gradient(90deg,#fffef7 85%,#dfdfce)}@keyframes turn-next{from{transform:rotateY(0)}to{transform:rotateY(-180deg)}}@keyframes turn-previous{from{transform:rotateY(0)}to{transform:rotateY(180deg)}}
.album-dialog{padding:0;width:min(1000px,calc(100vw - 32px));max-height:90vh;border:1px solid #cfdbc7;border-radius:20px;background:#fffef9;color:var(--ink);box-shadow:0 24px 100px #17352135}.album-dialog::backdrop{background:#e7efe2c9;backdrop-filter:blur(6px)}.album-dialog-content{display:grid;grid-template-columns:minmax(200px,.8fr) minmax(0,1fr);gap:34px;padding:36px;position:relative}.album-close{position:absolute;right:12px;top:12px;padding:3px 11px;font-size:25px;z-index:1}.album-detail-art{align-self:start;position:sticky;top:20px}.album-detail-info{padding-top:10px;min-width:0}.album-detail-info>p{font-size:12px;color:var(--muted);line-height:1.6}.detail-stats{display:flex;gap:10px;margin:22px 0}.detail-stats>div{flex:1;background:#edf4e6;border:1px solid #d7e5cc;border-radius:10px;padding:12px}.detail-stats dt{font-size:10px;color:var(--muted)}.detail-stats dd{margin:4px 0 0;font-size:26px;font-weight:750}.detail-skills article{padding:13px 15px;border:1px solid #dae4d2;border-radius:9px;background:#f5f8ef;margin:9px 0}.detail-skills strong{font-size:14px}.detail-skills p{font-size:12px;line-height:1.6;margin:5px 0 0;color:#536851}.rfid-status{overflow-wrap:anywhere}.detail-actions{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}.publication-form{border-top:1px solid var(--line);padding-top:22px;margin-top:23px}.check-label{display:flex;align-items:center;gap:8px;font-size:12px;margin:10px 0}.publication-fields{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin:18px 0}.publication-fields label{font-size:11px;display:flex;flex-direction:column;gap:6px}.publication-form>button{width:100%}
.skill-binding-status{display:flex;flex-direction:column;gap:7px;padding:13px 15px;background:#fff6dd;border:1px solid #ead8a0;border-radius:9px;color:#665020!important}.skill-binding-status a{font-size:12px;color:#246443;text-decoration:underline}
@media(max-width:1200px){.card-album{padding:22px}.album-page{padding:17px 13px}.album-grid{gap:16px 10px}.album-pocket{padding:7px}.album-totals{gap:18px}.album-heading{align-items:start}.album-heading p{max-width:380px}}
@media(max-width:850px){.album-grid{grid-template-columns:1fr}.album-heading{flex-direction:column}.album-totals strong{font-size:23px}.album-dialog-content{gap:20px;padding:35px 20px 20px;grid-template-columns:1fr}.album-detail-art{position:static;max-width:300px;margin:auto;width:100%}.album-pagination p span{display:none}.page-heading{font-size:7px;letter-spacing:0}.album-pagination button{padding:10px;font-size:11px}.album-tools>a{flex:1;text-align:center}}
@media(prefers-reduced-motion:reduce){.album-leaf{animation:none}button,a{transition:none}}
</style>
