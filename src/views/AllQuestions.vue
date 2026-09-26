<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../lib/supabase';

const router = useRouter();
const questions = ref([]);
const loading = ref(false);
const deletingId = ref(null);
const errorMessage = ref('');
const successMessage = ref('');
const search = ref('');
const category = ref('');
const difficulty = ref('');
const status = ref('');
const page = ref(1);
const perPage = ref(10);
const totalItems = ref(0);
let searchTimer;

const categories = ['programming','javascript','html','css','database','algorithm','general'];
const difficulties = ['easy','medium','hard'];
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const startItem = computed(() => totalItems.value ? ((page.value - 1) * perPage.value) + 1 : 0);
const endItem = computed(() => Math.min(page.value * perPage.value, totalItems.value));

async function fetchQuestions() {
  loading.value = true;
  errorMessage.value = '';
  try {
    let query = supabase
      .from('coding_questions')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false });

    const keyword = search.value.trim().replace(/,/g, ' ');
    if (keyword) query = query.or(`question.ilike.%${keyword}%,category.ilike.%${keyword}%,difficulty.ilike.%${keyword}%`);
    if (category.value) query = query.eq('category', category.value);
    if (difficulty.value) query = query.eq('difficulty', difficulty.value);
    if (status.value === 'active') query = query.eq('is_active', true);
    if (status.value === 'inactive') query = query.eq('is_active', false);

    const from = (page.value - 1) * perPage.value;
    const to = from + perPage.value - 1;
    const { data, error, count } = await query.range(from, to);
    if (error) throw error;

    questions.value = data ?? [];
    totalItems.value = count ?? 0;
  } catch (error) {
    console.error(error);
    errorMessage.value = error.message || 'Gagal mengambil question.';
  } finally {
    loading.value = false;
  }
}

function editQuestion(id) {
  router.push({ name: 'question-edit', params: { id } });
}

async function toggleActive(question) {
  const previous = question.is_active;
  question.is_active = !previous;
  try {
    const { error } = await supabase.from('coding_questions').update({ is_active: question.is_active }).eq('id', question.id);
    if (error) throw error;
  } catch (error) {
    question.is_active = previous;
    errorMessage.value = error.message || 'Gagal mengubah status.';
  }
}

async function deleteQuestion(question) {
  if (!window.confirm(`Hapus question ini?\n\n${question.question}`)) return;
  deletingId.value = question.id;
  errorMessage.value = '';
  try {
    const { error } = await supabase.from('coding_questions').delete().eq('id', question.id);
    if (error) throw error;
    successMessage.value = 'Question berhasil dihapus.';
    if (questions.value.length === 1 && page.value > 1) page.value--;
    await fetchQuestions();
  } catch (error) {
    errorMessage.value = error.message || 'Gagal menghapus question.';
  } finally {
    deletingId.value = null;
  }
}

watch(page, fetchQuestions);
watch(perPage, () => { page.value = 1; fetchQuestions(); });
watch([category, difficulty, status], () => { page.value = 1; fetchQuestions(); });
watch(search, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => { page.value = 1; fetchQuestions(); }, 350);
});

onMounted(fetchQuestions);
</script>

<template>
  <main class="questions-page">
    <section class="shell">
      <header class="header-card">
        <div>
          <span class="eyebrow">BATTLE ARENA ADMIN</span>
          <h1>All Coding Questions</h1>
          <p>Search, filter, edit, activate/deactivate, dan delete question.</p>
        </div>
        <button class="primary" @click="router.push({ name: 'question-add' })">+ ADD QUESTION</button>
      </header>

      <div v-if="successMessage" class="alert success">{{ successMessage }}</div>
      <div v-if="errorMessage" class="alert error">{{ errorMessage }}</div>

      <section class="filters">
        <input v-model="search" type="search" placeholder="Search question..." />
        <select v-model="category">
          <option value="">All Categories</option>
          <option v-for="item in categories" :key="item" :value="item">{{ item }}</option>
        </select>
        <select v-model="difficulty">
          <option value="">All Difficulties</option>
          <option v-for="item in difficulties" :key="item" :value="item">{{ item }}</option>
        </select>
        <select v-model="status">
          <option value="">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </section>

      <section class="table-card">
        <div v-if="loading" class="state">Loading questions...</div>
        <div v-else-if="questions.length === 0" class="state">Tidak ada question ditemukan.</div>
        <div v-else class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Question</th><th>Category</th><th>Difficulty</th><th>Answer</th><th>Status</th><th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="q in questions" :key="q.id">
                <td class="question-cell"><strong>{{ q.question }}</strong><small v-if="q.explanation">{{ q.explanation }}</small></td>
                <td><span class="pill">{{ q.category }}</span></td>
                <td><span class="pill" :class="q.difficulty">{{ q.difficulty }}</span></td>
                <td><span class="answer">{{ q.correct_answer }}</span></td>
                <td><button class="status-btn" :class="{ active: q.is_active }" @click="toggleActive(q)">{{ q.is_active ? 'ACTIVE' : 'INACTIVE' }}</button></td>
                <td><div class="actions"><button class="edit" @click="editQuestion(q.id)">EDIT</button><button class="delete" :disabled="deletingId === q.id" @click="deleteQuestion(q)">{{ deletingId === q.id ? 'DELETING...' : 'DELETE' }}</button></div></td>
              </tr>
            </tbody>
          </table>
        </div>

        <footer class="pagination">
          <span>Showing {{ startItem }}-{{ endItem }} of {{ totalItems }}</span>
          <div>
            <select v-model.number="perPage"><option :value="10">10 / page</option><option :value="20">20 / page</option><option :value="50">50 / page</option></select>
            <button :disabled="page <= 1" @click="page--">PREV</button>
            <strong>{{ page }} / {{ totalPages }}</strong>
            <button :disabled="page >= totalPages" @click="page++">NEXT</button>
          </div>
        </footer>
      </section>
    </section>
  </main>
</template>

<style scoped>
*{box-sizing:border-box}.questions-page{min-height:100vh;padding:40px 24px;background:#030816;color:#fff;font-family:Inter,system-ui,sans-serif}.shell{max-width:1280px;margin:auto}.header-card,.filters,.table-card{border:1px solid rgba(255,255,255,.08);background:#071126;border-radius:16px}.header-card{display:flex;justify-content:space-between;align-items:center;padding:26px;margin-bottom:18px}.eyebrow{font-size:10px;color:#5edcff;font-weight:900;letter-spacing:.16em}.header-card h1{margin:7px 0 5px}.header-card p{margin:0;color:#8295af;font-size:13px}.primary{border:0;border-radius:10px;padding:14px 18px;background:linear-gradient(90deg,#4fd8ff,#65efc8);font-weight:900;cursor:pointer}.alert{padding:13px 15px;border-radius:10px;margin-bottom:14px;font-size:12px}.success{color:#6df0a9;background:rgba(39,165,94,.12);border:1px solid rgba(80,230,145,.25)}.error{color:#ff8da5;background:rgba(174,38,68,.12);border:1px solid rgba(255,90,120,.25)}.filters{display:grid;grid-template-columns:1fr 180px 180px 160px;gap:10px;padding:14px;margin-bottom:16px}.filters input,.filters select,.pagination select{height:42px;border:1px solid rgba(255,255,255,.1);border-radius:9px;background:#050d1e;color:#fff;padding:0 12px}.table-card{overflow:hidden}.table-wrap{overflow:auto}table{width:100%;min-width:950px;border-collapse:collapse}th,td{text-align:left;padding:14px 16px;border-bottom:1px solid rgba(255,255,255,.06)}th{font-size:9px;color:#7890ad;text-transform:uppercase}.question-cell{max-width:430px}.question-cell strong{display:block;font-size:12px;line-height:1.45}.question-cell small{display:block;margin-top:5px;color:#6f829c}.pill,.answer{display:inline-block;padding:6px 9px;border-radius:999px;background:rgba(77,191,241,.1);font-size:8px;text-transform:uppercase}.pill.easy{color:#65eba7}.pill.medium{color:#ffd36b}.pill.hard{color:#ff829a}.answer{color:#061a13;background:#58e9a4;font-weight:900}.status-btn,.edit,.delete,.pagination button{border-radius:8px;padding:8px 10px;font-size:8px;font-weight:900;cursor:pointer}.status-btn{border:1px solid rgba(255,255,255,.08);background:transparent;color:#8da0b9}.status-btn.active{color:#66eda9;border-color:rgba(70,220,145,.25)}.actions{display:flex;gap:7px}.edit{color:#6edcff;background:rgba(65,180,220,.08);border:1px solid rgba(80,200,245,.25)}.delete{color:#ff8299;background:rgba(190,40,70,.08);border:1px solid rgba(255,90,120,.25)}.state{padding:55px;text-align:center;color:#7c90aa}.pagination{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;color:#7f92ab;font-size:10px}.pagination>div{display:flex;gap:8px;align-items:center}.pagination select{width:auto;height:34px}.pagination button{border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.03);color:#adc0d6}.pagination button:disabled{opacity:.3;cursor:not-allowed}@media(max-width:900px){.filters{grid-template-columns:1fr 1fr}}@media(max-width:650px){.questions-page{padding:20px 12px}.header-card{align-items:flex-start;flex-direction:column;gap:16px}.primary{width:100%}.filters{grid-template-columns:1fr}.pagination{align-items:flex-start;flex-direction:column;gap:10px}}
</style>
