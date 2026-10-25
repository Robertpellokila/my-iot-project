<script setup>
import { defineAsyncComponent, computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../../lib/supabase';
import { compressImageFile, IMAGE_UPLOAD_LIMITS } from '../../lib/compressImage';
import { QUIZ_MODES, blankQuestion, validateQuestion, questionPayload, questionDraft, checkPreviewAnswer, codeLines, shuffleItems } from '../../lib/questions/questionModel.js';
import StructuredBlockQuestion from './StructuredBlockQuestion.vue';
const BlockWorkspace = defineAsyncComponent(() => import('./BlockWorkspace.vue')); 
import {EMPTY_WORKSPACE} from '../../lib/questions/scratchBlocks.js';
import ScratchBlockEditor from './ScratchBlockEditor.vue';
import QuizBlockList from './QuizBlockList.vue';
const props=defineProps({questionId:{type:String,default:null}});
const router=useRouter();
const draft=ref(blankQuestion());
const loading=ref(false), saving=ref(false), compressing=ref(false);
const loaded=ref(!props.questionId);
const error=ref(''), success=ref(''), showErrors=ref(false);
const imageUrl=ref(''), imageFile=ref(null), imagePreview=ref(''), imageName=ref('');
const previewWorkspace=ref(structuredClone(EMPTY_WORKSPACE));
const preview=ref(null), previewBlocks=ref([]), previewResult=ref(null);
let imageRequest=0;
const busy=computed(()=>loading.value||saving.value||compressing.value);
const errors=computed(()=>validateQuestion(draft.value,imagePreview.value));
const categories=['scratch','block_coding','programming_basics','programming','javascript','html','css','database','algorithm','general'];
function revokePreview(){if(imagePreview.value.startsWith('blob:'))URL.revokeObjectURL(imagePreview.value);}
function clearImage(){imageRequest++;revokePreview();imageFile.value=null;imagePreview.value='';imageUrl.value='';imageName.value='';}
async function pickImage(file){
  if(!file||saving.value)return;
  const request=++imageRequest; compressing.value=true;error.value='';
  try{
    const compressed=await compressImageFile(file,{maxSourceBytes:IMAGE_UPLOAD_LIMITS.sourceBytes,maxOutputBytes:IMAGE_UPLOAD_LIMITS.outputBytes,maxDimension:IMAGE_UPLOAD_LIMITS.maxDimension});
    if(request!==imageRequest)return;
    revokePreview();imageFile.value=compressed;imagePreview.value=URL.createObjectURL(compressed);imageName.value=file.name;
  }catch(e){if(request===imageRequest)error.value=e.message||'Gambar tidak dapat dibaca.';}
  finally{if(request===imageRequest)compressing.value=false;}
}
function pasteImage(event){const file=[...(event.clipboardData?.files??[])].find(file=>file.type.startsWith('image/'));if(file){event.preventDefault();void pickImage(file);}}
function reset(){clearImage();draft.value=blankQuestion();preview.value=null;previewResult.value=null;showErrors.value=false;}
function startPreview(){
  showErrors.value=true;if(errors.value.length)return;
  preview.value={...questionPayload(draft.value,imagePreview.value),block_solutions:draft.value.block_solutions,block_grading:draft.value.block_grading};previewWorkspace.value=JSON.parse(JSON.stringify(draft.value.block_config.initial));previewResult.value=null;
  previewBlocks.value=shuffleItems(preview.value.blocks.map((text,originalIndex)=>({text,originalIndex})));
}
function answerPreview(answer){previewResult.value=checkPreviewAnswer(preview.value,answer);}
watch(draft,()=>{preview.value=null;previewResult.value=null;},{deep:true});
watch(imagePreview,()=>{preview.value=null;});
async function loadQuestion(){
  if(!props.questionId)return;loading.value=true;
  error.value='';
  try{const {data,error:loadError}=await supabase.from('coding_questions').select('*').eq('id',props.questionId).single();if(loadError)throw loadError;draft.value=questionDraft(data);if(data.question_type==='scratch_blocks'){const {data:key,error:keyError}=await supabase.from('coding_question_block_keys').select('solutions,grading').eq('question_id',data.id).single();if(keyError)throw keyError;draft.value.block_solutions=key.solutions;draft.value.block_grading=key.grading;}imageUrl.value=data.image_url||'';imagePreview.value=imageUrl.value;loaded.value=true;}
  catch(e){error.value=e.message||'Soal tidak dapat dimuat.';}finally{loading.value=false;}
}
onMounted(loadQuestion);
onUnmounted(()=>{imageRequest++;revokePreview();});
async function save(){
  if(busy.value||!loaded.value)return;showErrors.value=true;if(errors.value.length)return;
  saving.value=true;error.value='';success.value='';let uploadedPath=null;
  try{
    let url=imageUrl.value;
    if(imageFile.value){uploadedPath=`${crypto.randomUUID()}.webp`;const {error:uploadError}=await supabase.storage.from('quiz-images').upload(uploadedPath,imageFile.value,{contentType:'image/webp',upsert:false});if(uploadError){uploadedPath=null;throw uploadError;}url=supabase.storage.from('quiz-images').getPublicUrl(uploadedPath).data.publicUrl;}
    const payload=questionPayload(draft.value,url);
    let saveError;
    if(draft.value.mode==='scratch_blocks') {
      ({error:saveError}=await supabase.rpc('save_block_question',{p_id:props.questionId,p_question:payload,p_solutions:draft.value.block_solutions,p_grading:draft.value.block_grading}));
    } else {
      const query=props.questionId?supabase.from('coding_questions').update(payload).eq('id',props.questionId):supabase.from('coding_questions').insert(payload);
      ({error:saveError}=await query);
    }
    if(saveError)throw saveError;
    if(props.questionId){revokePreview();imageUrl.value=url;imagePreview.value=url;imageFile.value=null;}else reset();
    success.value=props.questionId?'Perubahan soal tersimpan.':'Soal berhasil ditambahkan ke bank quiz.';
  }catch(e){if(uploadedPath)await supabase.storage.from('quiz-images').remove([uploadedPath]);error.value=e.message||'Soal belum berhasil disimpan.';}
  finally{saving.value=false;}
}
async function remove(){
  if(busy.value||!props.questionId||!window.confirm('Hapus soal ini? Soal yang sudah dipakai dalam battle akan diarsipkan.'))return;
  saving.value=true;error.value='';
  try{const {error:deleteError}=await supabase.from('coding_questions').delete().eq('id',props.questionId);if(deleteError?.code==='23503'){const {error:archiveError}=await supabase.from('coding_questions').update({is_active:false,deleted_at:new Date().toISOString()}).eq('id',props.questionId);if(archiveError)throw archiveError;}else if(deleteError)throw deleteError;await router.push({name:'questions'});}
  catch(e){error.value=e.message;}finally{saving.value=false;}
}
</script>
<template>
  <main class="question-studio">
    <header class="studio-header"><div><span>BANK QUIZ · TIMEDOOR</span><h1>{{ questionId?'Edit question':'Add question' }}</h1><p>Buat soal, tentukan jawaban, lalu coba sebagai pemain sebelum menyimpan.</p></div><RouterLink :to="{name:'questions'}">← Semua soal</RouterLink></header>
    <p v-if="loading" role="status">Memuat soal…</p><p v-if="error" class="notice error" role="alert">{{ error }}</p><p v-if="success" class="notice success" role="status">{{ success }}</p>
    <button v-if="!loading && !loaded" type="button" class="secondary" @click="loadQuestion">Muat ulang soal</button>
    <form v-if="!loading && loaded" @submit.prevent="save">
      <fieldset :disabled="busy">
        <section class="editor-section"><h2>Mode quiz</h2><div class="mode-picker"><label v-for="mode in QUIZ_MODES" :key="mode.id" :class="{selected:draft.mode===mode.id}"><input v-model="draft.mode" type="radio" :value="mode.id" name="quiz-mode"/><strong>{{ mode.name }}</strong><small>{{ mode.description }}</small></label></div></section>
        <div class="editor-columns"><div class="editor-main">
          <section class="editor-section"><h2>Pertanyaan & bahan quiz</h2><label class="field">Pertanyaan<textarea v-model="draft.question" rows="3" maxlength="3000" placeholder="Apa yang terjadi setelah bendera hijau diklik?"/></label>
            <div class="image-upload" @dragover.prevent @drop.prevent="pickImage($event.dataTransfer.files?.[0])" @paste="pasteImage" tabindex="0" aria-label="Upload gambar atau tempel screenshot">
              <strong>{{ draft.mode==='image_choice'?'Gambar kode Scratch':'Gambar pendukung (opsional)' }}</strong><p>Tarik gambar ke sini, pilih file, atau tempel screenshot dengan Ctrl/Cmd + V.</p><input type="file" accept="image/png,image/jpeg,image/webp" aria-label="Pilih gambar soal" @change="pickImage($event.target.files?.[0]); $event.target.value=''"/><small>{{ compressing?'Menyiapkan gambar…':'PNG, JPG, WebP · maksimal 10 MB · dikompres otomatis' }}</small>
              <figure v-if="imagePreview"><img :src="imagePreview" alt="Potongan kode atau ilustrasi soal"/><figcaption>{{ imageName || 'Gambar soal' }}<button type="button" @click="clearImage">Hapus gambar</button></figcaption></figure>
            </div>
            <StructuredBlockQuestion v-if="draft.mode==='scratch_blocks'" v-model="draft" :disabled="busy"/>
            <div v-else-if="draft.mode==='block_order'" class="block-authoring"><ScratchBlockEditor v-model="draft.blocks" :disabled="busy"/></div>
            <template v-else-if="draft.mode==='find_bug'"><label class="field">Kode yang akan diperiksa<textarea v-model="draft.code_snippet" rows="5" spellcheck="false" placeholder="Ketika bendera hijau diklik&#10;Atur skor ke 0&#10;Ubah skor sebesar -1"/></label><label class="field">Baris yang salah<select v-model.number="draft.bug_line"><option v-for="(line,index) in codeLines(draft.code_snippet)" :key="index" :value="index">{{ index+1 }} · {{ line }}</option></select></label><p class="help">Gunakan 2–4 baris. Pemain memilih satu baris untuk diperbaiki.</p></template>
            <template v-else><div class="answer-fields"><label v-for="letter in ['A','B','C','D']" :key="letter" class="field">Pilihan {{ letter }}<input v-model="draft[`option_${letter.toLowerCase()}`]" maxlength="500" :placeholder="`Jawaban ${letter}`"/></label></div><label class="field">Kunci jawaban<select v-model="draft.correct_answer"><option v-for="letter in ['A','B','C','D']" :key="letter">{{ letter }}</option></select></label></template>
          </section>
          <section class="editor-section"><h2>Penjelasan & petunjuk</h2><label class="field">Penjelasan setelah menjawab<textarea v-model="draft.explanation" rows="3" placeholder="Jelaskan mengapa urutan atau jawaban tersebut benar."/></label><div class="answer-fields"><label class="field">Petunjuk pertama<input v-model="draft.hint_1"/></label><label class="field">Petunjuk kedua<input v-model="draft.hint_2"/></label></div><label class="field">Tautan materi (opsional)<input v-model="draft.learning_url" type="url" placeholder="https://scratch.mit.edu/ideas"/></label></section>
        </div><aside class="editor-side"><section class="editor-section"><h2>Pengaturan</h2><label class="field">Kategori<select v-model="draft.category"><option v-for="category in categories" :key="category">{{ category }}</option></select></label><label class="field">Kesulitan<select v-model="draft.difficulty"><option value="easy">Mudah</option><option value="medium">Sedang</option><option value="hard">Sulit</option></select></label><label class="field">Topik belajar<input v-model="draft.learning_topic" placeholder="Contoh: loop dan variabel"/></label><label class="active-toggle"><input v-model="draft.is_active" type="checkbox"/> Aktif di bank soal</label><label class="field">Durasi khusus (detik)<input v-model.number="draft.duration_seconds" type="number" min="10" max="600" placeholder="Ikuti Game Setup" @change="draft.duration_seconds=draft.duration_seconds || null"/></label><p class="help">Jika kosong, durasi quiz mengikuti Game Setup. Semua pemain dan penonton memakai waktu ronde yang sama.</p></section>
          <section class="editor-section"><h2>Coba quiz</h2><p class="help">Lihat bagaimana pemain menjawab, termasuk drag and drop blok.</p><button class="secondary" type="button" @click="startPreview">Buka preview interaktif</button><ul v-if="showErrors && errors.length" class="validation-errors"><li v-for="message in errors" :key="message">{{ message }}</li></ul><p v-else-if="!errors.length" class="ready">✓ Data soal lengkap</p></section>
        </aside></div>
        <section v-if="preview" class="editor-section quiz-preview"><header><div><span>PREVIEW PEMAIN</span><h2>{{ preview.question }}</h2></div><button type="button" class="secondary" @click="startPreview">Ulangi</button></header><img v-if="imagePreview" :src="imagePreview" alt="Ilustrasi quiz"/>
          <template v-if="preview.question_type==='scratch_blocks'"><BlockWorkspace v-model="previewWorkspace" :config="preview.block_config"/><button type="button" class="primary" @click="answerPreview({workspace:previewWorkspace})">Periksa program</button></template>
          <template v-else-if="preview.question_type==='block_order'"><QuizBlockList v-model="previewBlocks"/><button type="button" class="primary" @click="answerPreview({order:previewBlocks.map(block=>block.originalIndex)})">Periksa urutan</button></template>
          <div v-else-if="preview.question_type==='find_bug'" class="preview-answers"><button v-for="(line,index) in codeLines(preview.code_snippet)" :key="index" type="button" @click="answerPreview({line_index:index})">{{ index+1 }} · {{ line }}</button></div>
          <div v-else class="preview-answers"><button v-for="(letter,index) in ['a','b','c','d']" :key="letter" type="button" @click="answerPreview({answer_index:index})"><b>{{ letter.toUpperCase() }}</b> {{ preview[`option_${letter}`] }}</button></div>
          <p v-if="previewResult!==null" role="status" class="notice" :class="previewResult?'success':'error'">{{ previewResult?'Benar! Jawaban sesuai kunci.':'Belum benar. Coba periksa kembali.' }} {{ previewResult?preview.explanation:'' }}</p>
        </section>
        <footer class="editor-actions"><button v-if="questionId" type="button" class="delete" @click="remove">Hapus / arsipkan</button><button v-else type="button" class="secondary" @click="reset">Kosongkan form</button><button type="submit" class="primary">{{ saving?'Menyimpan…':compressing?'Menyiapkan gambar…':questionId?'Simpan perubahan':'Simpan soal' }}</button></footer>
      </fieldset>
    </form>
  </main>
</template>
<style scoped>
.question-studio { max-width:1320px; padding:32px; margin:auto; color:#203d32; font-family:Arial,sans-serif; }.studio-header { display:flex; align-items:center; justify-content:space-between; gap:20px; margin-bottom:24px; }.studio-header span,.quiz-preview header span { color:#398065; font-size:11px; font-weight:800; letter-spacing:.1em; }.studio-header h1 { font-size:30px; margin:8px 0; letter-spacing:-.03em; }.studio-header p { color:#61796d; font-size:14px; line-height:1.5; margin:0; }.studio-header a { color:#246548; font-size:13px; white-space:nowrap; }fieldset { border:0; margin:0; padding:0; min-width:0; }.editor-section { background:white; border:1px solid #d6e3da; border-radius:12px; padding:22px; margin-bottom:18px; }h2 { font-size:17px; margin:0 0 16px; }.mode-picker { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; }.mode-picker label { position:relative; display:grid; grid-template-columns:18px 1fr; align-content:start; gap:8px; padding:15px 12px; border:1px solid #d6e3da; border-radius:8px; cursor:pointer; }.mode-picker input { margin:1px 0; accent-color:#167547; }.mode-picker strong { font-size:13px; }.mode-picker small { grid-column:2; color:#6a7e72; font-size:12px; line-height:1.5; }.mode-picker .selected { border-color:#2a8b5a; background:#eff9f1; box-shadow:inset 0 0 0 1px #2a8b5a; }.editor-columns { display:grid; grid-template-columns:minmax(0,1fr) 270px; gap:20px; }.editor-main,.editor-side { min-width:0; }.field { display:flex; flex-direction:column; gap:8px; color:#385a49; font-size:12px; font-weight:700; margin-bottom:17px; }input:not([type=radio],[type=checkbox]),textarea,select { box-sizing:border-box; width:100%; min-width:0; padding:11px 12px; border:1px solid #c9dcd0; border-radius:7px; background:#fff; color:#213f31; font:400 14px/1.4 Arial,sans-serif; }textarea { resize:vertical; }input:focus,textarea:focus,select:focus,button:focus-visible,a:focus-visible { outline:2px solid #278552; outline-offset:2px; }.image-upload { padding:16px; border:1px dashed #8cbaa2; background:#f4faf6; border-radius:9px; margin:18px 0; }.image-upload strong { font-size:13px; }.image-upload p,.help { font-size:12px; color:#647d6d; line-height:1.6; }.image-upload small { display:block; margin-top:8px; color:#667b70; font-size:11px; }.image-upload figure { margin:14px 0 0; }.image-upload img { display:block; max-width:100%; max-height:300px; object-fit:contain; background:#fff; margin:auto; }.image-upload figcaption { display:flex; align-items:center; justify-content:space-between; gap:12px; font-size:11px; margin-top:9px; overflow-wrap:anywhere; }.image-upload figcaption button { flex:none; border:0; background:none; color:#934332; cursor:pointer; }.block-authoring { margin-top:20px; }.answer-fields { display:grid; grid-template-columns:1fr 1fr; gap:0 14px; }.active-toggle { display:flex; align-items:center; gap:8px; font-size:13px; }.active-toggle input { accent-color:#157d48; }.primary,.secondary,.delete { min-height:42px; padding:10px 17px; border:1px solid #bad4c4; border-radius:7px; font:700 13px Arial,sans-serif; cursor:pointer; }.primary { background:#177b4b; border-color:#177b4b; color:#fff; }.secondary { background:#f3f9f4; color:#246548; }.delete { background:#fff4ef; color:#9a4335; border-color:#e5c3b8; }.editor-actions { display:flex; justify-content:space-between; gap:12px; padding:12px 0 24px; }.notice { padding:13px 16px; border-radius:8px; font-size:13px; line-height:1.5; }.error { color:#8b3328; background:#fff0eb; border:1px solid #efc2b8; }.success,.ready { color:#206840; background:#edf8ef; }.ready { font-size:12px; padding:10px; }.validation-errors { padding-left:18px; color:#9b4935; font-size:12px; line-height:1.7; }.quiz-preview { max-width:820px; }.quiz-preview header { display:flex; align-items:start; justify-content:space-between; gap:18px; }.quiz-preview h2 { margin-top:8px; line-height:1.5; }.quiz-preview>img { max-width:100%; max-height:320px; object-fit:contain; display:block; margin:10px auto 24px; }.quiz-preview>.primary { margin-top:20px; }.preview-answers { display:grid; grid-template-columns:1fr 1fr; gap:10px; }.preview-answers button { text-align:left; padding:15px; border:1px solid #bdd6c8; border-radius:7px; background:#f4faf6; color:#204832; cursor:pointer; font:14px/1.5 Arial,sans-serif; overflow-wrap:anywhere; }.preview-answers b { margin-right:8px; }fieldset:disabled { opacity:.7; }button:disabled { cursor:default; }@media(max-width:1100px) { .editor-columns { grid-template-columns:1fr; }.editor-side { display:grid; grid-template-columns:1fr 1fr; gap:20px; }.mode-picker { grid-template-columns:1fr 1fr; } }@media(max-width:600px) { .question-studio { padding:16px; }.studio-header { flex-direction:column; align-items:start; }.editor-section { padding:16px; }.mode-picker,.answer-fields,.editor-side,.preview-answers { grid-template-columns:1fr; } }
</style>
