<script setup>
import {useAdminFeedback} from '../composables/useAdminToast.js';
import SearchableSelect from "../components/SearchableSelect.vue";
import AdminTable from "../components/AdminTable.vue";
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from '../lib/supabase';

const router = useRouter();
const route = useRoute();
const questions = ref([]);
const loading = ref(false);
const deletingId = ref(null);
const errorMessage = ref('');
const successMessage = ref('');
const search = ref('');
const category = ref('');
const difficulty = ref('');
const status = ref('active');
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
    if (status.value === 'active') query = query.is('deleted_at', null).eq('is_active', true);
    if (status.value === 'inactive') query = query.is('deleted_at', null).eq('is_active', false);
    if (status.value === 'archived') query = query.not('deleted_at', 'is', null);
    if (status.value === 'all') query = query.is('deleted_at', null);

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
  if (question.deleted_at) return;
  successMessage.value='';errorMessage.value='';
  const previous = question.is_active;
  question.is_active = !previous;
  try {
    const { error } = await supabase.from('coding_questions').update({ is_active: question.is_active }).eq('id', question.id);
    if (error) throw error;
    successMessage.value=question.is_active?'Soal diaktifkan untuk quiz.':'Soal dinonaktifkan untuk quiz.';
  } catch (error) {
    question.is_active = previous;
    errorMessage.value = error.message || 'Gagal mengubah status.';
  }
}

async function deleteQuestion(question) {
  if (!window.confirm(`Hapus question ini? Jika sudah dipakai di riwayat battle, question akan diarsipkan agar data battle lama tetap utuh.\n\n${question.question}`)) return;
  deletingId.value = question.id;
  successMessage.value='';errorMessage.value = '';
  try {
    const { error } = await supabase.from('coding_questions').delete().eq('id', question.id);
    if (error?.code === '23503') {
      const { error: archiveError } = await supabase
        .from('coding_questions')
        .update({ is_active: false, deleted_at: new Date().toISOString() })
        .eq('id', question.id);
      if (archiveError) throw archiveError;
      successMessage.value = 'Question diarsipkan karena sudah dipakai di battle. Riwayat battle tetap tersimpan.';
    } else if (error) {
      throw error;
    } else {
      successMessage.value = 'Question berhasil dihapus permanen.';
    }
    if (questions.value.length === 1 && page.value > 1) page.value--;
    await fetchQuestions();
  } catch (error) {
    errorMessage.value = error.message || 'Gagal menghapus question.';
  } finally {
    deletingId.value = null;
  }
}

async function restoreQuestion(question) {
  deletingId.value = question.id;
  successMessage.value='';errorMessage.value = '';
  successMessage.value = '';
  try {
    const { error } = await supabase
      .from('coding_questions')
      .update({ deleted_at: null, is_active: true })
      .eq('id', question.id);
    if (error) throw error;
    successMessage.value = 'Question dipulihkan dan diaktifkan kembali.';
    await fetchQuestions();
  } catch (error) {
    errorMessage.value = error.message || 'Gagal memulihkan question.';
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

onMounted(() => {
  if (route.query.notice === 'archived') successMessage.value = 'Question diarsipkan karena sudah dipakai di battle. Riwayat battle tetap tersimpan.';
  if (route.query.notice === 'deleted') successMessage.value = 'Question berhasil dihapus permanen.';
  if (route.query.notice) router.replace({ name: 'questions' });
  fetchQuestions();
});
const adminToast=useAdminFeedback({error:errorMessage,success:successMessage,scope:'AllQuestions'});
</script>

<template>
  <main class="questions-page">
    <section class="shell">
      <header class="header-card">
        <div>
          <span class="eyebrow">BATTLE ARENA ADMIN</span>
          <h1>All Coding Questions</h1>
          <p>Kelola soal aktif, nonaktif, dan arsip tanpa menghapus riwayat battle.</p>
        </div>
        <button class="primary" @click="router.push({ name: 'question-add' })">+ ADD QUESTION</button>
      </header>

      <div v-if="successMessage" class="alert success">{{ successMessage }}</div>
      <div v-if="errorMessage" class="alert error">{{ errorMessage }}</div>

      <section class="filters">
        <input v-model="search" type="search" placeholder="Search question..." />
        <SearchableSelect v-model="category">
          <option value="">All Categories</option>
          <option v-for="item in categories" :key="item" :value="item">{{ item }}</option>
        </SearchableSelect>
        <SearchableSelect v-model="difficulty">
          <option value="">All Difficulties</option>
          <option v-for="item in difficulties" :key="item" :value="item">{{ item }}</option>
        </SearchableSelect>
        <SearchableSelect v-model="status">
          <option value="all">All non-archived</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="archived">Archived</option>
        </SearchableSelect>
      </section>

      <section class="table-card">
        <div v-if="loading" class="state">Loading questions...</div>
        <div v-else-if="questions.length === 0" class="state">Tidak ada question ditemukan.</div>
        <div v-else class="table-wrap">
          <AdminTable>
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
                <td><button class="status-btn" :class="{ active: q.is_active && !q.deleted_at, archived: q.deleted_at }" :disabled="Boolean(q.deleted_at)" @click="toggleActive(q)">{{ q.deleted_at ? 'ARCHIVED' : q.is_active ? 'ACTIVE' : 'INACTIVE' }}</button></td>
                <td><div class="actions"><button class="edit" @click="editQuestion(q.id)">EDIT</button><button v-if="q.deleted_at" class="restore" :disabled="deletingId === q.id" @click="restoreQuestion(q)">{{ deletingId === q.id ? 'RESTORING...' : 'RESTORE' }}</button><button v-else class="delete" :disabled="deletingId === q.id" @click="deleteQuestion(q)">{{ deletingId === q.id ? 'DELETING...' : 'DELETE' }}</button></div></td>
              </tr>
            </tbody>
          </table>
          </AdminTable>
        </div>

        <footer class="pagination">
          <span>Showing {{ startItem }}-{{ endItem }} of {{ totalItems }}</span>
          <div>
            <SearchableSelect v-model.number="perPage"><option :value="10">10 / page</option><option :value="20">20 / page</option><option :value="50">50 / page</option></SearchableSelect>
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
* { box-sizing: border-box; }
.questions-page { min-height: 100vh; padding: 40px 24px; background: #f2f8f1; color: #173623; font-family: Inter, system-ui, sans-serif; }
.shell { max-width: 1280px; margin: auto; }
.header-card, .filters, .table-card { border: 1px solid #dce9db; background: #fff; border-radius: 16px; box-shadow: 0 8px 24px #1645230b; }
.header-card { display: flex; justify-content: space-between; align-items: center; padding: 26px; margin-bottom: 18px; }
.eyebrow { font-size: 10px; color: #118a2b; font-weight: 900; letter-spacing: .16em; }
.header-card h1 { margin: 7px 0 5px; color: #173623; }
.header-card p { margin: 0; color: #718675; font-size: 13px; }
.primary { border: 0; border-radius: 10px; padding: 14px 18px; background: #0caf25; color: #fff; font-weight: 900; cursor: pointer; }
.alert { padding: 13px 15px; border-radius: 10px; margin-bottom: 14px; font-size: 12px; }
.success { color: #176d2e; background: #e8f6e8; border: 1px solid #c6e5c8; }
.error { color: #9e263a; background: #fff0f1; border: 1px solid #f0c7cc; }
.filters { display: grid; grid-template-columns: 1fr 180px 180px 180px; gap: 10px; padding: 14px; margin-bottom: 16px; }
.filters input, .filters select, .pagination select { height: 42px; border: 1px solid #cfe4cf; border-radius: 9px; background: #fff; color: #21472b; padding: 0 12px; }
.filters input::placeholder { color: #879a89; }
.table-card { overflow: hidden; }
.table-wrap { overflow: auto; }
.table-wrap :deep(table) { width: 100%; min-width: 950px; border-collapse: collapse; color: #29432f; }
.table-wrap :deep(th), .table-wrap :deep(td) { text-align: left; padding: 14px 16px; border-bottom: 1px solid #e6eee5; }
.table-wrap :deep(th) { background: #f4faf3; color: #607763; font-size: 9px; text-transform: uppercase; }
.question-cell { max-width: 430px; }
.question-cell strong { display: block; color: #23452b; font-size: 12px; line-height: 1.45; }
.question-cell small { display: block; margin-top: 5px; color: #718675; }
.pill, .answer { display: inline-block; padding: 6px 9px; border-radius: 999px; background: #edf6ed; color: #406647; font-size: 8px; text-transform: uppercase; }
.pill.easy { color: #16783a; }.pill.medium { color: #89600a; }.pill.hard { color: #a3293e; }
.answer { color: #176d2e; background: #e1f4e4; font-weight: 900; }
.status-btn, .edit, .delete, .restore, .pagination button { border-radius: 8px; padding: 8px 10px; font-size: 8px; font-weight: 900; cursor: pointer; }
.status-btn { border: 1px solid #d8e5d7; background: #f6faf5; color: #718675; }
.status-btn.active { color: #16783a; border-color: #bfe0c2; background: #ebf7e9; }
.status-btn.archived { color: #80621b; border-color: #eadcae; background: #fff9e8; }
.actions { display: flex; gap: 7px; }
.edit { color: #18782d; background: #eef8ed; border: 1px solid #cfe4cf; }
.delete { color: #9e263a; background: #fff1f1; border: 1px solid #efc9cf; }
.restore { color: #176d2e; background: #e8f6e8; border: 1px solid #c3e2c5; }
.state { padding: 55px; text-align: center; color: #718675; }
.pagination { display: flex; justify-content: space-between; align-items: center; padding: 14px 16px; color: #607763; font-size: 10px; }
.pagination > div { display: flex; gap: 8px; align-items: center; }
.pagination select { width: auto; height: 34px; }
.pagination button { border: 1px solid #cfe4cf; background: #f6faf5; color: #386541; }
.pagination button:disabled { opacity: .4; cursor: not-allowed; }
.actions button:disabled { opacity: .55; cursor: wait; }
@media (max-width: 900px) { .filters { grid-template-columns: 1fr 1fr; } }
@media (max-width: 650px) { .questions-page { padding: 20px 12px; }.header-card { align-items: flex-start; flex-direction: column; gap: 16px; }.primary { width: 100%; }.filters { grid-template-columns: 1fr; }.pagination { align-items: flex-start; flex-direction: column; gap: 10px; } }
</style>
