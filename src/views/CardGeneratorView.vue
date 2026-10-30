<script setup>
import {useAdminFeedback,studioNoticeType} from '../composables/useAdminToast.js';
import { computed, ref, watch, onDeactivated } from 'vue';
import {useRoute} from 'vue-router';
import SearchableSelect from '../components/SearchableSelect.vue';
import {editableStudioCard,studioLibrary,recordToStudioCard,artworkFromCatalog,studioSaveEntries,catalogImageAsset} from '../lib/card-generator/cardCatalogBridge.js';
import { useCardGenerator } from '../composables/useCardGenerator.js';
import { PILOT, CARD_BY_CODE } from '../lib/card-generator/cardSchema.js';
import manifest from '../data/card-generator/artwork-manifest.json';
import { fusionsFor } from '../lib/card-generator/cardFusionResolver.js';
import { cardReadiness, renderSignature, validateDataset, artworkResolutionIssue } from '../lib/card-generator/cardValidationService.js';
import { renderCardSvg } from '../lib/card-generator/cardRenderer.js';
import { uploadArtwork, verifyAsset, invalidateArtwork, emptyArtwork, setArtworkAsset, artworkAssets } from '../lib/card-generator/cardArtworkService.js';
import { inspectSvg, downloadBlob } from '../lib/card-generator/cardExportService.js';
import { compareProduction } from '../lib/card-generator/cardProductionMapping.js';
import { supabase } from '../lib/supabase.js';
import CardLibraryPanel from '../components/card-generator/CardLibraryPanel.vue';
import CardPreview from '../components/card-generator/CardPreview.vue';
import CardPropertiesPanel from '../components/card-generator/CardPropertiesPanel.vue';
import CardValidationPanel from '../components/card-generator/CardValidationPanel.vue';
import CardFrameRenderer from '../components/card-generator/CardFrameRenderer.vue';
import CardExportDialog from '../components/card-generator/CardExportDialog.vue';
import CardRfidDialog from '../components/card-generator/CardRfidDialog.vue';
import CardRfidLookupDialog from '../components/card-generator/CardRfidLookupDialog.vue';
import FusionRecipeEditor from '../components/card-generator/FusionRecipeEditor.vue';
import SkillCatalog from './SkillCatalog.vue';
import { createDraft, normalizeDraft, validateDraft, TEMPLATES } from '../lib/card-generator/cardDrafts.js';
import { RARITY_THEMES } from '../lib/card-generator/cardRarityTheme.js';
import { FIXED_BACK, fixedBackAvailable } from '../lib/card-generator/cardBack.js';
import { referenceFrameFor } from '../lib/card-generator/cardReferenceFrames.js';
import { cardIdentity } from '../lib/card-generator/cardRenderer.js';
import '../components/card-generator/card-generator.css';

const { workspace, owner, loading, message, error, cloudBusy, catalogLinks, replace, saveCloud, loadCloud } = useCardGenerator();
const route=useRoute(),catalogOpen=ref(false),catalogCards=ref([]),catalogSelection=ref('');
const selected = ref('TOC-003'), checked = ref([]), tab = ref('studio'), busy = ref(false), exportOpen = ref(false), exportSelection = ref([]), mapping = ref(null);
const creating = ref(false);
const rfidCard=ref(null),rulesOpen=ref(false),rulesSaving=ref(false),savedEntries=new Map(),ruleSlots=new Map();
const rfidLookupOpen=ref(false),rfidInitialUid=ref('');
const fusionOpen=ref(false),fusionCard=ref(null),fusionEditor=ref(null),fusionSaving=ref(false);
const editorSaving=computed(()=>rulesSaving.value||fusionSaving.value);
const currentEntry=()=>studioSaveEntries([currentCard.value],workspace)[0];
const signature=entry=>JSON.stringify({card:entry.card,artwork:entry.artwork});
onDeactivated(()=>{rfidCard.value=null;rfidLookupOpen.value=false;rulesOpen.value=false;fusionOpen.value=false;});
const libraryCards = computed(() => studioLibrary(workspace));
const pilotCards=computed(()=>libraryCards.value.filter(card=>CARD_BY_CODE.has(card.card_code)));
// Returning from registration restores the current design for this account.
watch(loading, value => {
  if (value || !owner.value) return;
  try {
    const last = sessionStorage.getItem(`tbc:card-studio:${owner.value}:selection`);
    if (libraryCards.value.some(card => card.card_code === last)) selected.value = last;
  } catch { /* Selection is optional when browser storage is unavailable. */ }
});
watch(selected, value => {
  if (loading.value || !owner.value) return;
  try { sessionStorage.setItem(`tbc:card-studio:${owner.value}:selection`,value); } catch { /* Workspace data is saved separately. */ }
});
watch(libraryCards, cards => {
  if (!cards.some(card => card.card_code === selected.value)) selected.value = 'COB-006';
  checked.value = checked.value.filter(code => cards.some(card => card.card_code === code));
}, { flush: 'sync' });
const currentCard = computed(() => libraryCards.value.find(card => card.card_code === selected.value) || PILOT.cards.find(card => card.card_code === 'COB-006'));
const formCard=computed(()=>editableStudioCard(currentCard.value));
const saveCards=async(cards=tab.value==='review'&&checked.value.length?libraryCards.value.filter(card=>checked.value.includes(card.card_code)):[currentCard.value])=>{
 const entries=studioSaveEntries(cards,workspace),snapshots=entries.map(entry=>[entry.key,signature(entry)]);
 if(!await saveCloud(entries))return false;
 for(const [key,value] of snapshots)savedEntries.set(key,value);
 return true;
};
const ensureCurrentSaved=async()=>{
 if(busy.value||cloudBusy.value||loading.value)return false;
 const entry=currentEntry();
 return catalogLinks.value[selected.value]&&savedEntries.get(selected.value)===signature(entry) ? true : await saveCards([currentCard.value]);
};
const registerCurrent=async(initialUid='')=>{
 if(currentCard.value.kind==='fusion'){message.value='Kartu Fusion dipanggil melalui resep dan tidak memakai RFID.';return;}
 rfidInitialUid.value=typeof initialUid==='string'?initialUid:'';
 if(!await ensureCurrentSaved())return;
 busy.value=true;error.value='';
 try{const {data,error:e}=await supabase.from('game_cards').select('*').eq('id',catalogLinks.value[selected.value]).single();if(e)throw e;if(!data)throw new Error('Kartu belum tersedia di akun. Simpan kembali.');rfidCard.value=data;}
 catch(e){error.value=e.message;}finally{busy.value=false;}
};
const openRules=async()=>{if(await ensureCurrentSaved()){fusionOpen.value=false;rulesOpen.value=true;}};
const openFusion=async()=>{
 if(currentCard.value.kind!=='fusion'||!await ensureCurrentSaved())return;
 busy.value=true;error.value='';
 try{const {data,error:e}=await supabase.from('game_cards').select('*').eq('id',catalogLinks.value[selected.value]).single();if(e)throw e;fusionCard.value=data;rulesOpen.value=false;fusionOpen.value=true;}
 catch(e){error.value=e.message;}finally{busy.value=false;}
};
const saveCurrent=()=>fusionOpen.value?fusionEditor.value?.save():saveCards();
const fusionSaved=async data=>{
 updateCard({fusion_data:String(data.summary??'').slice(0,1500)});
 if(await saveCards([currentCard.value]))message.value='Resep Fusion dan ringkasan kartu tersimpan.';
};
const skillSaved=async skill=>{
 const index=skill.metadata?.slot ? Number(skill.metadata.slot)-1 : ruleSlots.get(skill.id);
 if(!Number.isInteger(index)||index<0||index>1){message.value='Aturan skill tersimpan.';return;}
 busy.value=true;
 try{
 updateCard({skills:formCard.value.skills.map((item,i)=>i===index?{...item,name:skill.name,description:skill.description,battle:{...item.battle,authority:'custom'}}:item)});
 let imageError='';try{await applySkillImage(index,skill.icon);}catch(e){imageError=e.message;}
 await saveCards([currentCard.value]);
 if(imageError)error.value=`Aturan skill tersimpan, tetapi gambar untuk preview belum dimuat: ${imageError}`;
 }finally{busy.value=false;}
};
const applySkillImage=async(index,url)=>{
 if(!/^https?:\/\/|^\//i.test(url??'')){if(artwork.value.skill_icons?.[index]){setArtworkAsset(artwork.value,`skill-${index+1}-icon`,null);invalidateArtwork(artwork.value);}return;}
 if(artwork.value.skill_icons?.[index]?.url===url)return;
 setArtworkAsset(artwork.value,`skill-${index+1}-icon`,await catalogImageAsset(url));invalidateArtwork(artwork.value);
};
const openCatalog=async()=>{catalogOpen.value=true;const {data,error:err}=await supabase.from('game_cards').select('*').order('name');if(err){error.value=err.message;return;}catalogCards.value=(data??[]).filter(card=>!card.archived_at);};
const importCatalog=async(id=catalogSelection.value)=>{
 if(!id||busy.value)return;busy.value=true;error.value='';
 try{
  let record=catalogCards.value.find(card=>card.id===id);
  if(!record){const result=await supabase.from('game_cards').select('*').eq('id',id).single();if(result.error)throw result.error;record=result.data;}
  const {data:links,error:linkError}=await supabase.from('game_card_special_skills').select('sort_order,enabled,special_skills(id,name,description,icon,metadata)').eq('game_card_id',id).order('sort_order');
  if(linkError)throw linkError;
  if(record.archived_at)throw new Error('Kartu berada di Sampah. Pulihkan dari Album sebelum membukanya di Studio.');
  const storedKey=Object.keys(catalogLinks.value).find(key=>catalogLinks.value[key]===id);
  const definitions=(links??[]).filter(link=>link.special_skills).sort((a,b)=>a.sort_order-b.sort_order);
  ruleSlots.clear();definitions.slice(0,2).forEach((link,i)=>ruleSlots.set(link.special_skills.id,i));
  let card=recordToStudioCard(record,definitions.map(link=>link.special_skills));
  if(storedKey)card=normalizeDraft({...card,card_code:storedKey,source_pilot_code:CARD_BY_CODE.has(storedKey)?storedKey:undefined});
  const index=workspace.custom_cards.findIndex(item=>item.card_code===card.card_code);
  if(index<0){if(workspace.custom_cards.length>=200)throw new Error('Maksimal 200 kartu per workspace.');workspace.custom_cards.push(card);}else workspace.custom_cards[index]=card;
  workspace.artworks[card.card_code]??=emptyArtwork();
  try{workspace.artworks[card.card_code]=await artworkFromCatalog(record);}catch(err){error.value=err.message;}
  catalogLinks.value[card.card_code]=record.id;selected.value=card.card_code;tab.value='studio';catalogOpen.value=false;
  for(const [i,link] of definitions.slice(0,2).entries())try{await applySkillImage(i,link.special_skills.icon);}catch(err){error.value=err.message;}
  savedEntries.set(card.card_code,signature(currentEntry()));
  message.value='Kartu tersimpan dibuka. Edit di sini atau langsung hubungkan RFID.';
 }catch(err){error.value=err.message;}finally{busy.value=false;}
};
watch([loading,()=>route.query.catalog,()=>route.query.rfid],async([waiting,id,rfid])=>{
 if(waiting||!id||route.name!=='card-generator')return;
 await importCatalog(String(id));
 if(catalogLinks.value[selected.value]===id&&rfid==='1')await registerCurrent();
},{immediate:true});
watch(selected,()=>{rulesOpen.value=false;fusionOpen.value=false;fusionCard.value=null;});
const addCard = (template, source = null) => {
  message.value='';
  if (workspace.custom_cards.length >= 200) { error.value = 'Maksimal 200 kartu baru per workspace.'; return; }
  let card = createDraft(template, workspace.custom_cards);
  if (source) {
    const identity = cardIdentity(source);
    card = normalizeDraft({ ...source, source_pilot_code:undefined,source_game_card_id:undefined,source_catalog_code:undefined,card_code: card.card_code, display_code: card.display_code, name: identity.name, subtitle: identity.variant });
  }
  workspace.artworks[card.card_code] = source?JSON.parse(JSON.stringify(workspace.artworks[source.card_code]??emptyArtwork())):emptyArtwork();
  workspace.custom_cards.push(card); selected.value = card.card_code; creating.value = false; tab.value = 'studio';
  message.value = 'Template dipilih. Lengkapi data kartu dan upload ilustrasinya.';
};
const updateCard = patch => {
  const index = workspace.custom_cards.findIndex(card => card.card_code === selected.value);
  try { const next=normalizeDraft({ ...formCard.value, ...patch });if(index<0)workspace.custom_cards.push(next);else workspace.custom_cards[index]=next;invalidateArtwork(artwork.value); }
  catch (err) { error.value = err.message; }
};
const artwork = computed(() => workspace.artworks[selected.value]);
const previewArtwork = computed(() => ({ ...artwork.value, back: workspace.back }));
const currentBrief = computed(() => manifest.entries.find(entry => entry.card_code === selected.value));
const recipe = computed(() => PILOT.recipes.find(item => item.result_code === selected.value));
const recipes = computed(() => currentCard.value.is_custom ? [] : fusionsFor(currentCard.value, PILOT.recipes, PILOT.cards));
const statuses = computed(() => Object.fromEntries(libraryCards.value.map(card => {
  const art = workspace.artworks[card.card_code];
  const status = cardReadiness(card, PILOT, art, workspace.back);
  if (art.character?.sha256 && Object.entries(workspace.artworks).some(([code, candidate]) => code !== card.card_code && candidate.character?.sha256 === art.character.sha256)) {
    status.errors.push('Artwork karakter dipakai pada kartu lain.'); status.ready = false; status.status = 'Validation Error';
  }
  return [card.card_code, status];
})));
const readyCount = computed(() => Object.values(statuses.value).filter(status => status.ready).length);
const artworkCount = computed(() => Object.values(workspace.artworks).filter(art => art.character?.url).length);
const currentStatus = computed(() => statuses.value[selected.value]);
const toggleCheck = code => { checked.value = checked.value.includes(code) ? checked.value.filter(value => value !== code) : [...checked.value, code]; };
const selectVisible = codes => { checked.value = [...new Set([...checked.value, ...codes])]; };
const openExport = codes => { exportSelection.value = libraryCards.value.filter(card => codes.includes(card.card_code)); exportOpen.value = true; };
const jsonDownload = (data, filename) => downloadBlob(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }), filename);
const downloadWorkspace = () => {jsonDownload({ ...workspace, source_sha256: PILOT.source_sha256, saved_at: new Date().toISOString() }, 'TBC-pilot-workspace.json');adminToast.success('Berkas workspace siap diunduh.');};
const downloadManifest = () => {jsonDownload({ ...manifest, entries: manifest.entries.map(brief => {
  const art = workspace.artworks[brief.card_code];
  return { ...brief, ...art, artwork_path: art.character?.path ?? null,
    production_status: statuses.value[brief.card_code].ready ? 'ready_for_print' : art.character ? art.approval_status === 'approved' ? 'reviewed' : 'draft' : 'artwork_required' };
}) }, 'TBC-artwork-production-manifest.json');adminToast.success('Manifest artwork siap diunduh.');};
const importWorkspace = async event => {
  const file = event.target.files?.[0]; if (!file) return;
  try { if (file.size > 2 * 1024 * 1024) throw new Error('File workspace maksimal 2 MB.'); const incoming = JSON.parse(await file.text());
    if (incoming.source_sha256 && incoming.source_sha256 !== PILOT.source_sha256) throw new Error('Versi dokumen sumber berbeda.');
    replace(incoming); message.value = 'Workspace dimuat. Verifikasi artwork sebelum mencetak.';
  } catch (err) { error.value = err.message; } finally { event.target.value = ''; }
};
const perform = async work => { if (busy.value) return; busy.value = true; error.value = ''; message.value = ''; try { await work(); } catch (err) { error.value = err.message; } finally { busy.value = false; } };
const upload = (file, layer) => {
  const code = selected.value;
  return perform(async () => {
    const asset = await uploadArtwork(file, code, layer);
    const target = workspace.artworks[code]; setArtworkAsset(target,layer,asset); target.version++; target.asset_status = 'unchecked'; invalidateArtwork(target);
    const label = /^skill-[12]-icon$/.test(layer) ? `ikon Skill ${layer[6]}` : `layer ${layer}`;
    message.value = `${code}: ${label} tersimpan. Review ulang sebelum approve.`;
  });
};
const remove = layer => { setArtworkAsset(artwork.value,layer,null); artwork.value.version++; artwork.value.asset_status = 'unchecked'; invalidateArtwork(artwork.value);adminToast.info('Gambar dilepas dari draft. Simpan ke akun untuk menerapkan perubahan.'); };
const updateIconFit = (index,fit) => {
  const icon = artwork.value.skill_icons?.[index]; if (!icon || busy.value) return;
  icon.fit = fit === 'contain' ? 'contain' : 'cover'; artwork.value.version++; invalidateArtwork(artwork.value);
};
const updatePlacement = () => invalidateArtwork(artwork.value);
const checkAssets = async target => { for (const asset of artworkAssets(target)) await verifyAsset(asset); target.asset_status = 'verified'; };
const approve = () => {
  const code = selected.value, target = artwork.value;
  return perform(async () => {
    if (!target.character) throw new Error('Upload artwork karakter terlebih dahulu.');
    if (Object.entries(workspace.artworks).some(([id, candidate]) => id !== code && candidate.character?.sha256 === target.character.sha256)) throw new Error('Artwork karakter harus unik untuk setiap kartu.');
    const resolutionIssue = artworkResolutionIssue(currentCard.value, target.character);
    if (resolutionIssue) throw new Error(resolutionIssue);
    await checkAssets(target); target.approval_status = 'approved'; target.production_status = 'reviewed'; target.render_receipt = null;
    message.value = `${code}: artwork disetujui. Jalankan pemeriksaan render untuk kesiapan cetak.`;
  });
};
const verifyRender = () => {
  const card = currentCard.value, target = artwork.value;
  return perform(async () => {
    const dataErrors = card.is_custom ? validateDraft(card) : validateDataset(PILOT);
    if (dataErrors.length) throw new Error(dataErrors.join(' '));
    if (!target.character) throw new Error('Artwork karakter belum tersedia.');
    await checkAssets(target);
    const frame = referenceFrameFor(card); if (frame) await verifyAsset(frame);
    if (fixedBackAvailable()) { await verifyAsset(FIXED_BACK); workspace.back.asset_status = 'verified'; }
    await document.fonts.ready;
    const errors = inspectSvg(renderCardSvg(card, PILOT, { ...target, back: workspace.back }));
    if (errors.length) throw new Error(errors.join(' '));
    target.render_receipt = renderSignature(card, { ...target, back: workspace.back });
    message.value = 'Batas teks dan asset lolos pemeriksaan. Periksa status kesiapan cetak di preview.';
  });
};
const auditProduction = () => perform(async () => {
  const { data, error: loadError } = await supabase.from('game_cards').select('id,card_code,name,hp,attack,defense,rarity,metadata,fusion_only').in('card_code', PILOT.cards.map(card => card.production_mapping.card_code));
  if (loadError) throw new Error('Katalog existing belum dapat dibaca.');
  mapping.value = compareProduction(PILOT, data ?? []);
  jsonDownload({ dataset: PILOT.id, source_sha256: PILOT.source_sha256, write_performed: false, mapping: mapping.value }, 'TBC-pilot-production-comparison.json');
  message.value = `Audit baca selesai: ${mapping.value.filter(row => row.matches).length} kode cocok. Laporan perbedaan diunduh.`;
});
const masters = computed(() => {
  const example = CARD_BY_CODE.get('TOC-003');
  return TEMPLATES.map(template => ({ template,
    card: template === 'Common' ? example : { ...example, design_template:['Trial Join','Winning'].includes(template)?template:null, card_code: `STUDY-${template.toUpperCase()}`, display_code: example.card_code, kind: 'preview', rarity: template === 'Winning' ? 'Mythic' : template === 'Trial Join' ? 'Common' : template === 'Fusion' ? 'Legendary' : template },
    artwork: workspace.artworks['TOC-003'], study: template !== 'Common',
  }));
});
const adminToast=useAdminFeedback({error,message,scope:'CardGeneratorView'});
</script>

<template>
  <main class="cg-workspace">
    <header class="cg-main-header"><div><span class="cg-eyebrow">TIMEDOOR BATTLE CARDS</span><h1>Card Studio</h1><p>Satu tempat untuk data, desain, skill, dan kartu fisikmu.</p></div><div class="cg-header-actions"><button class="cg-primary" type="button" :disabled="loading || !owner || cloudBusy || busy || editorSaving" @click="saveCurrent">{{ cloudBusy ? 'Menyimpan…' : tab==='review'&&checked.length ? `Simpan ${checked.length} kartu` : fusionOpen ? 'Simpan resep' : 'Simpan kartu' }}</button><button v-if="currentCard.kind==='fusion'" type="button" :disabled="loading || cloudBusy || busy || editorSaving" @click="openFusion">Atur resep Fusion</button><button type="button" :disabled="loading || !owner || cloudBusy || busy || editorSaving || currentCard.kind==='fusion'" :title="currentCard.kind==='fusion'?'Fusion dipanggil melalui resep tanpa RFID':undefined" @click="registerCurrent">Hubungkan RFID</button><button type="button" :disabled="!owner || busy || loading || editorSaving" @click="openExport(checked.length ? checked : [selected])">Export / Cetak <span>{{ checked.length || 1 }}</span> ↗</button></div></header>
    <p v-if="error" class="cg-error" role="alert">{{ error }} <button type="button" aria-label="Tutup pesan" @click="error = ''">×</button></p>
    <p v-if="message" class="cg-message" :class="{'cg-warning':studioNoticeType(message)==='warning'}" role="status">{{ message }} <button type="button" aria-label="Tutup pesan" @click="message = ''">×</button></p>
    <p v-if="loading" class="cg-empty">Memuat workspace…</p>
    <template v-else-if="owner">
      <div class="cg-catalog-actions"><button type="button" :disabled="loading || !owner || busy || cloudBusy || editorSaving" @click="rfidLookupOpen=true">◉ Cek kartu RFID</button><RouterLink to="/admin/game/catalog?tab=synergy">Atur Synergy ↗</RouterLink><button type="button" :disabled="busy || cloudBusy || rulesSaving" @click="openCatalog">Pilih kartu tersimpan</button><RouterLink :to="{name:'album-card'}">Buka Album ↗</RouterLink><span>{{ catalogLinks[selected]?'✓ Kartu tersedia di akun':'Draft baru · simpan tanpa UID terlebih dahulu' }}</span><span v-if="currentCard.kind==='fusion'">Fusion memakai resep, tanpa UID RFID.</span></div>
      <section v-if="catalogOpen" class="cg-catalog-picker"><label>Pilih data kartu<SearchableSelect v-model="catalogSelection"><option value="">Pilih kartu…</option><option v-for="card in catalogCards" :key="card.id" :value="card.id">{{ card.name }} · {{ card.metadata?.studio_card?.display_code || card.card_code }}{{ card.uid ? ` · RFID ${card.uid}` : ' · Desain tersimpan' }}</option></SearchableSelect></label><button type="button" :disabled="!catalogSelection || busy" @click="importCatalog()">Buka kartu</button><button type="button" @click="catalogOpen=false">Tutup</button></section>
      <div class="cg-workspace-bar"><nav class="cg-tabs" aria-label="Tampilan generator"><button v-for="item in [['studio','Studio'],['review','Review 42 kartu'],['masters','9 templates']]" :key="item[0]" type="button" :class="{ active: tab === item[0] }" :aria-pressed="tab === item[0]" @click="tab = item[0]">{{ item[1] }}</button></nav><div class="cg-progress-summary"><span><b>{{ artworkCount }}</b> / {{ libraryCards.length }} artwork</span><span><i></i><b>{{ readyCount }}</b> ready for print</span></div></div>
      <section v-if="creating" class="cg-template-picker" aria-labelledby="cg-choose-template"><div class="cg-section-title"><div><h2 id="cg-choose-template">Pilih template kartu</h2><p class="cg-muted">Pilih rarity, lalu isi data. Posisi elemen dan back sudah tetap.</p></div><button type="button" @click="creating = false">Tutup</button></div><div class="cg-template-grid"><button v-for="item in TEMPLATES" :key="item" type="button" :style="{ '--rarity-color': RARITY_THEMES[item].main }" @click="addCard(item)"><span class="cg-template-sample"><CardFrameRenderer :card="masters.find(master => master.template === item).card" :dataset="PILOT" :artwork="masters.find(master => master.template === item).artwork" :template="item" /></span><strong>{{ item }}</strong><small>Pakai template ↗</small></button></div></section>
      <div v-if="tab === 'studio'" class="cg-studio-grid cg-studio-grid--editing">
        <CardLibraryPanel :cards="libraryCards" :selected="selected" :checked="checked" :statuses="statuses" @select="value=>{if(!busy&&!cloudBusy&&!editorSaving)selected=value}" @check="toggleCheck" @select-visible="selectVisible" @create="creating = true" />
        <div class="cg-center-panel"><CardPreview :card="currentCard" :dataset="PILOT" :artwork="previewArtwork" :status="currentStatus" /><CardValidationPanel :status="currentStatus" :busy="busy" @validate="verifyRender" /></div>
        <div class="cg-edit-column"><nav class="cg-edit-tabs" aria-label="Edit kartu"><button type="button" :aria-pressed="!rulesOpen && !fusionOpen" :disabled="editorSaving" @click="rulesOpen=false;fusionOpen=false">Data &amp; desain</button><button type="button" :aria-pressed="rulesOpen" :disabled="busy || cloudBusy || editorSaving" @click="openRules">Aturan skill</button><button v-if="currentCard.kind==='fusion'" type="button" :aria-pressed="fusionOpen" :disabled="busy || cloudBusy || editorSaving" @click="openFusion">Resep Fusion</button></nav>
        <div v-if="rulesOpen" class="cg-rule-panel"><SkillCatalog :key="catalogLinks[selected]" embedded :card-id="catalogLinks[selected]" @saved="skillSaved" @saving="rulesSaving=$event"/></div>
        <div v-if="fusionCard && currentCard.kind==='fusion'" v-show="fusionOpen" class="cg-rule-panel"><FusionRecipeEditor ref="fusionEditor" :key="fusionCard.id" :card="fusionCard" @saving="fusionSaving=$event" @saved="fusionSaved"/></div>
        <CardPropertiesPanel v-if="!rulesOpen && !fusionOpen" :card="formCard" :artwork="artwork" :back="workspace.back" :brief="currentBrief" :recipe="recipe" :recipes="recipes" :busy="busy || cloudBusy" @upload="upload" @remove="remove" @change="updatePlacement" @approve="approve" @reject="invalidateArtwork(artwork)" @icon-fit="updateIconFit" @update-card="updateCard" @duplicate="addCard(currentCard.kind === 'fusion' ? 'Fusion' : currentCard.rarity, currentCard)" />
        </div>
      </div>
      <section v-if="tab === 'review'" class="cg-review"><div class="cg-review-header"><div><h2>Pilot collection</h2><p>Periksa komposisi seluruh kartu. Pilih kartu untuk ekspor atau buka di studio.</p></div><button type="button" @click="checked = PILOT.cards.map(card => card.card_code)">Pilih semua 42</button><button type="button" @click="checked = []">Hapus pilihan</button></div><div class="cg-review-grid"><article v-for="card in pilotCards" :key="card.card_code"><div class="cg-review-card-heading"><label><input type="checkbox" :checked="checked.includes(card.card_code)" @change="toggleCheck(card.card_code)" />{{ card.card_code }}</label><span>{{ statuses[card.card_code].status }}</span></div><button type="button" class="cg-review-card" :aria-label="`Buka ${card.card_code} di studio`" @click="selected = card.card_code; tab = 'studio'"><CardFrameRenderer :card="card" :dataset="PILOT" :artwork="{ ...workspace.artworks[card.card_code], back: workspace.back }" /></button></article></div></section>
      <section v-if="tab === 'masters'" class="cg-review"><div class="cg-review-header"><div><h2>Template kartu</h2><p>Tujuh frame rarity, Trial Join Card, dan Winning Card. Artwork contoh dapat diganti dengan ilustrasi kartu milikmu.</p></div></div><div class="cg-review-grid cg-master-grid"><article v-for="master in masters" :key="master.template"><h3>{{ master.template }}</h3><p>{{ master.study ? 'Contoh isi · data & gambar bisa diganti' : master.card.card_code }}</p><CardFrameRenderer :card="master.card" :dataset="PILOT" :artwork="master.artwork" :template="master.template" /></article></div></section>
      <footer class="cg-workspace-footer"><span>Draft tersimpan di perangkat ini.</span><div><button type="button" :disabled="busy || cloudBusy" @click="downloadWorkspace">Download workspace</button><label class="cg-inline-file"><input type="file" accept="application/json,.json" :disabled="busy || cloudBusy" @change="importWorkspace" /><span>Import workspace</span></label><button type="button" :disabled="busy || cloudBusy" @click="loadCloud">Muat dari akun</button><button type="button" @click="downloadManifest">42 artwork briefs</button><button type="button" :disabled="busy" @click="auditProduction">Audit katalog existing</button></div></footer>
      <CardExportDialog v-if="exportOpen" :cards="exportSelection" :dataset="PILOT" :workspace="workspace" @close="exportOpen = false" @edit="code => { selected = code; tab = 'studio'; exportOpen = false; }" />
      <CardRfidLookupDialog v-if="rfidLookupOpen" :can-link="currentCard.kind!=='fusion'" :current-name="currentCard.name" @close="rfidLookupOpen=false" @open-card="id=>{rfidLookupOpen=false;importCatalog(id)}" @link-uid="uid=>{rfidLookupOpen=false;registerCurrent(uid)}"/>
      <CardRfidDialog v-if="rfidCard" :card="rfidCard" :initial-uid="rfidInitialUid" @close="rfidCard=null" @linked="data=>{message=`RFID ${data.uid} terhubung ke ${data.name}.`}"/>
    </template>
  </main>
</template>

<style scoped>
.cg-edit-column{min-width:0}.cg-edit-tabs{display:flex;gap:6px;padding:8px;border:1px solid var(--cg-line);border-radius:10px 10px 0 0;background:#edf5e9}.cg-edit-tabs>button{flex:1;font-size:11px}.cg-edit-tabs>button[aria-pressed=true]{background:#fff;color:#17623d;border-color:#9dbd9d}.cg-rule-panel{max-height:calc(100dvh - 200px);overflow:auto;border:1px solid var(--cg-line);background:#fff;border-radius:0 0 10px 10px}.cg-edit-column>.cg-properties{border-radius:0 0 10px 10px}@media(max-width:1420px){.cg-edit-column{grid-column:1/-1}.cg-rule-panel{max-height:none}}
.cg-catalog-actions{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:20px}.cg-catalog-actions a{color:#176b49;font-weight:700;font-size:13px}.cg-catalog-actions span{margin-left:auto;color:#54735d;font-size:12px}.cg-catalog-picker{display:flex;align-items:end;gap:12px;padding:20px;background:white;border:1px solid #d7e4d8;border-radius:12px;margin-bottom:20px}.cg-catalog-picker label{display:grid;gap:8px;flex:1;min-width:0}.cg-catalog-picker button{flex-shrink:0}@media(max-width:700px){.cg-catalog-picker{flex-wrap:wrap}.cg-catalog-picker label{flex-basis:100%}}
</style>

<style scoped>
.cg-message.cg-warning{color:#8b6429;background:#fff5dc;border-color:#e7d5a6}
</style>
