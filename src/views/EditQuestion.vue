<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from '../lib/supabase';

const route = useRoute();
const router = useRouter();
const loading = ref(true);
const saving = ref(false);
const deleting = ref(false);
const errorMessage = ref('');
const successMessage = ref('');

const form = ref({ question:'', option_a:'', option_b:'', option_c:'', option_d:'', correct_answer:'A', explanation:'', category:'programming', difficulty:'easy', is_active:true });
const categories = ['programming','javascript','html','css','database','algorithm','general'];
const difficulties = ['easy','medium','hard'];
const answers = ['A','B','C','D'];
const isFormValid = computed(() => form.value.question.trim() && form.value.option_a.trim() && form.value.option_b.trim() && form.value.option_c.trim() && form.value.option_d.trim());

async function loadQuestion(){
  loading.value=true; errorMessage.value='';
  try{
    const {data,error}=await supabase.from('coding_questions').select('*').eq('id',route.params.id).single();
    if(error) throw error;
    form.value={question:data.question||'',option_a:data.option_a||'',option_b:data.option_b||'',option_c:data.option_c||'',option_d:data.option_d||'',correct_answer:data.correct_answer||'A',explanation:data.explanation||'',category:data.category||'programming',difficulty:data.difficulty||'easy',is_active:data.is_active??true};
  }catch(error){errorMessage.value=error.message||'Question tidak ditemukan.';}finally{loading.value=false;}
}

async function updateQuestion(){
  if(!isFormValid.value){errorMessage.value='Question dan semua pilihan wajib diisi.';return;}
  saving.value=true; errorMessage.value=''; successMessage.value='';
  try{
    const payload={question:form.value.question.trim(),option_a:form.value.option_a.trim(),option_b:form.value.option_b.trim(),option_c:form.value.option_c.trim(),option_d:form.value.option_d.trim(),correct_answer:form.value.correct_answer,explanation:form.value.explanation.trim()||null,category:form.value.category,difficulty:form.value.difficulty,is_active:form.value.is_active};
    const {error}=await supabase.from('coding_questions').update(payload).eq('id',route.params.id);
    if(error) throw error;
    successMessage.value='Question berhasil diperbarui.';
  }catch(error){errorMessage.value=error.message||'Gagal memperbarui question.';}finally{saving.value=false;}
}

async function deleteQuestion(){
  if(!window.confirm('Yakin ingin menghapus question ini?')) return;
  deleting.value=true; errorMessage.value='';
  try{
    const {error}=await supabase.from('coding_questions').delete().eq('id',route.params.id);
    if(error) throw error;
    await router.replace({name:'questions'});
  }catch(error){errorMessage.value=error.message||'Gagal menghapus question.';}finally{deleting.value=false;}
}

onMounted(loadQuestion);
</script>

<template>
  <main class="edit-page">
    <section class="shell">
      <header class="header-card"><div><span class="eyebrow">BATTLE ARENA ADMIN</span><h1>Edit Coding Question</h1><p>Update question, answer, settings, dan status.</p></div><button class="back" @click="router.push({name:'questions'})">← ALL QUESTIONS</button></header>
      <div v-if="loading" class="state">Loading question...</div>
      <template v-else>
        <div v-if="successMessage" class="alert success">{{ successMessage }}</div>
        <div v-if="errorMessage" class="alert error">{{ errorMessage }}</div>
        <form class="form" @submit.prevent="updateQuestion">
          <section class="card"><h2>Question</h2><textarea v-model="form.question" rows="5" placeholder="Question..."></textarea></section>
          <section class="card"><h2>Answer Options</h2><div class="grid"><label>A<input v-model="form.option_a" type="text"></label><label>B<input v-model="form.option_b" type="text"></label><label>C<input v-model="form.option_c" type="text"></label><label>D<input v-model="form.option_d" type="text"></label></div></section>
          <section class="card"><h2>Correct Answer</h2><div class="answers"><label v-for="a in answers" :key="a" :class="{selected:form.correct_answer===a}"><input v-model="form.correct_answer" type="radio" :value="a"><strong>{{a}}</strong> Option {{a}}</label></div></section>
          <section class="card"><h2>Explanation</h2><textarea v-model="form.explanation" rows="4" placeholder="Explanation..."></textarea></section>
          <section class="card"><h2>Settings</h2><div class="grid"><label>Category<select v-model="form.category"><option v-for="item in categories" :key="item" :value="item">{{item}}</option></select></label><label>Difficulty<select v-model="form.difficulty"><option v-for="item in difficulties" :key="item" :value="item">{{item}}</option></select></label></div><label class="active"><input v-model="form.is_active" type="checkbox"> Active Question</label></section>
          <section class="preview"><span>LIVE PREVIEW</span><h3>{{form.question||'Question...'}}</h3><div class="preview-grid"><div v-for="a in answers" :key="a" :class="{correct:form.correct_answer===a}"><b>{{a}}</b><p>{{form[`option_${a.toLowerCase()}`]||`Option ${a}`}}</p></div></div></section>
          <footer class="actions"><button type="button" class="delete" :disabled="deleting||saving" @click="deleteQuestion">{{deleting?'DELETING...':'DELETE QUESTION'}}</button><div><button type="button" class="cancel" @click="router.push({name:'questions'})">CANCEL</button><button type="submit" class="save" :disabled="!isFormValid||saving||deleting">{{saving?'SAVING...':'SAVE CHANGES'}}</button></div></footer>
        </form>
      </template>
    </section>
  </main>
</template>

<style scoped>
*{box-sizing:border-box}.edit-page{min-height:100vh;padding:40px 24px;background:#030816;color:#fff;font-family:Inter,system-ui,sans-serif}.shell{max-width:1050px;margin:auto}.header-card,.card,.preview{border:1px solid rgba(255,255,255,.08);background:#071126;border-radius:16px}.header-card{display:flex;justify-content:space-between;align-items:center;padding:26px;margin-bottom:16px}.eyebrow{font-size:10px;color:#5edcff;font-weight:900;letter-spacing:.16em}.header-card h1{margin:7px 0 5px}.header-card p{margin:0;color:#8295af;font-size:13px}.back{border:1px solid rgba(90,205,255,.22);border-radius:9px;padding:12px 14px;background:rgba(70,180,225,.06);color:#70dfff;font-weight:900;cursor:pointer}.form{display:flex;flex-direction:column;gap:15px}.card,.preview{padding:23px}.card h2{margin:0 0 16px;font-size:16px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.grid label{display:flex;flex-direction:column;gap:7px;font-size:10px;color:#9db0c7}.card input,.card textarea,.card select{width:100%;border:1px solid rgba(255,255,255,.1);border-radius:9px;background:#050d1e;color:#fff;padding:12px}.answers{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.answers label{display:flex;align-items:center;justify-content:center;gap:7px;min-height:68px;border:1px solid rgba(255,255,255,.08);border-radius:10px;color:#8da0b9;cursor:pointer}.answers input{display:none}.answers label.selected{border-color:#58d9ff;background:rgba(60,180,225,.08);color:#fff}.answers strong{display:grid;place-items:center;width:28px;height:28px;border-radius:7px;background:#13243b}.answers label.selected strong{background:#5bdcff;color:#06131d}.active{display:flex!important;flex-direction:row!important;align-items:center;gap:8px!important;margin-top:16px}.active input{width:auto}.preview{border-color:rgba(235,205,65,.18);background:linear-gradient(145deg,rgba(35,31,12,.8),rgba(7,15,34,.95))}.preview>span{font-size:9px;color:#e5c84e;font-weight:900}.preview h3{margin:12px 0 15px}.preview-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.preview-grid>div{display:flex;align-items:center;gap:8px;padding:10px;border:1px solid rgba(255,255,255,.07);border-radius:9px}.preview-grid b{display:grid;place-items:center;width:27px;height:27px;border-radius:7px;background:#9eafc6;color:#07121e}.preview-grid p{margin:0;color:#acb9ca;font-size:10px}.preview-grid>div.correct{border-color:rgba(80,230,145,.25)}.preview-grid>div.correct b{background:#5beaa4}.actions{display:flex;justify-content:space-between;gap:10px}.actions>div{display:flex;gap:10px}.actions button{min-width:135px;height:44px;border-radius:9px;font-weight:900;font-size:9px;cursor:pointer}.delete{color:#ff8299;border:1px solid rgba(255,90,120,.25);background:rgba(190,40,70,.08)}.cancel{color:#9eb0c6;border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.03)}.save{border:0;background:linear-gradient(90deg,#4fd8ff,#65efc8)}.alert,.state{padding:13px 15px;border-radius:10px;margin-bottom:14px;font-size:12px}.success{color:#6df0a9;background:rgba(39,165,94,.12);border:1px solid rgba(80,230,145,.25)}.error{color:#ff8da5;background:rgba(174,38,68,.12);border:1px solid rgba(255,90,120,.25)}.state{text-align:center;color:#8497b0;background:#071126}.actions button:disabled{opacity:.4;cursor:not-allowed}@media(max-width:700px){.edit-page{padding:20px 12px}.header-card{align-items:flex-start;flex-direction:column;gap:15px}.grid,.preview-grid{grid-template-columns:1fr}.answers{grid-template-columns:1fr 1fr}.actions,.actions>div{flex-direction:column}.actions button{width:100%}}
</style>
