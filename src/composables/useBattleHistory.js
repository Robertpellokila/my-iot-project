import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { supabase } from '../lib/supabase';
import { useAdminFeedback } from './useAdminToast.js';

export function useBattleHistory() {
  const battles = ref([]), loading = ref(true), error = ref('');
  const search = ref(''), statusFilter = ref('all'), activeFilter = ref('all');
  const page = ref(1), pageSize = ref(10), total = ref(0), summary = ref({});
  const selectedIds = ref([]), updatingBattleIds = ref([]);
  const deleteDialog = ref(null), deleteMode = ref('selected'), cleanupAge = ref('30');
  const deleteRows = ref([]), cleanupTotal = ref(0), previewLoading = ref(false);
  const deleting = ref(false), deleteError = ref(''), acknowledged = ref(false);
  const toast = useAdminFeedback({ error, scope: 'BattleHistory' });
  let request = 0, previewRequest = 0, searchTimer;
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)));
  const selectable = computed(() => battles.value.filter(b => b.can_delete));
  const allSelected = computed(() => selectable.value.length > 0 && selectable.value.every(b => selectedIds.value.includes(b.id)));
  const hasFilters = computed(() => !!search.value.trim() || statusFilter.value !== 'all' || activeFilter.value !== 'all');

  async function loadBattles() {
    const version = ++request;
    loading.value = true;
    error.value = '';
    selectedIds.value = [];
    try {
      const { data, error: failure } = await supabase.rpc('admin_battle_history', {
        p_search: search.value.trim(), p_status: statusFilter.value, p_access: activeFilter.value,
        p_page: page.value, p_page_size: pageSize.value,
      });
      if (version !== request) return;
      if (failure) throw failure;
      if (!Array.isArray(data?.rows)) throw new Error('Riwayat belum dapat dimuat. Coba muat ulang.');
      battles.value = data.rows;
      total.value = data.total;
      page.value = data.page;
      summary.value = data.summary;
    } catch (e) {
      if (version === request) error.value = e.message || 'Riwayat belum dapat dimuat.';
    } finally {
      if (version === request) loading.value = false;
    }
  }
  watch([search, statusFilter, activeFilter, pageSize], () => {
    clearTimeout(searchTimer);
    request++;
    page.value = 1;
    selectedIds.value = [];
    loading.value = true;
    searchTimer = setTimeout(loadBattles, 300);
  });
  function resetFilters() { search.value = ''; statusFilter.value = 'all'; activeFilter.value = 'all'; }
  function changePage(value) { if (loading.value || value < 1 || value > pageCount.value) return; page.value = value; void loadBattles(); }
  function togglePage() { selectedIds.value = allSelected.value ? [] : selectable.value.map(b => b.id); }
  async function refreshAdminData() { clearTimeout(searchTimer); await loadBattles(); if (!error.value) toast.info('Riwayat battle dimuat ulang.'); }

  async function previewCleanup() {
    const version = ++previewRequest;
    previewLoading.value = true; deleteError.value = ''; deleteRows.value = []; acknowledged.value = false;
    try {
      const before = cleanupAge.value === 'all' ? null : new Date(Date.now() - Number(cleanupAge.value) * 86400000).toISOString();
      const { data, error: failure } = await supabase.rpc('admin_battle_history_cleanup', { p_before: before });
      if (version !== previewRequest) return;
      if (failure) throw failure;
      if (!Array.isArray(data?.rows)) throw new Error('Daftar riwayat belum dapat diperiksa.');
      deleteRows.value = data.rows; cleanupTotal.value = data.total;
    } catch (e) { if (version === previewRequest) deleteError.value = e.message || 'Pratinjau gagal dimuat.'; }
    finally { if (version === previewRequest) previewLoading.value = false; }
  }
  async function openDelete(mode, rows = []) {
    deleteMode.value = mode; deleteRows.value = rows; cleanupTotal.value = rows.length;
    deleteError.value = ''; acknowledged.value = false;
    await nextTick(); deleteDialog.value.showModal();
    if (mode === 'cleanup') await previewCleanup();
  }
  function closeDelete() {
    if (deleting.value) return;
    previewRequest++; previewLoading.value = false; deleteDialog.value?.close();
  }
  async function confirmDelete() {
    if (deleting.value || previewLoading.value || !acknowledged.value || !deleteRows.value.length) return;
    deleting.value = true; deleteError.value = '';
    try {
      const { data, error: failure } = await supabase.rpc('admin_delete_battle_history', { p_ids: deleteRows.value.map(b => b.id) });
      if (failure) throw failure;
      if (!Number.isInteger(data?.deleted) || data.deleted < 1) throw new Error('Penghapusan belum terkonfirmasi. Periksa riwayat sebelum mencoba lagi.');
      deleteDialog.value.close();
      toast.success(`${data.deleted} riwayat battle berhasil dihapus.`);
      await loadBattles();
    } catch (e) { deleteError.value = e.message || 'Riwayat belum berhasil dihapus.'; acknowledged.value = false; }
    finally { deleting.value = false; }
  }
  const isBattleActive = b => b.status !== 'finished' && !b.winner && b.is_active !== false && (!b.active_until || new Date(b.active_until).getTime() > Date.now());
  async function setBattleActive(battle, active) {
    if (updatingBattleIds.value.includes(battle.id) || (active && (battle.winner || battle.status === 'finished'))) return null;
    updatingBattleIds.value = [...updatingBattleIds.value, battle.id];
    try {
      const { data, error: failure } = await supabase.from('battle_sessions').update({ is_active: active }).eq('id', battle.id).select('*').single();
      if (failure) throw failure;
      toast.success(active ? 'Battle diaktifkan.' : 'Battle dinonaktifkan.');
      await loadBattles(); return data;
    } catch (e) { error.value = e.message || 'Status akses gagal diperbarui.'; return null; }
    finally { updatingBattleIds.value = updatingBattleIds.value.filter(id => id !== battle.id); }
  }
  onMounted(loadBattles);
  onBeforeUnmount(() => { request++; previewRequest++; clearTimeout(searchTimer); });
  return { battles, loading, error, search, statusFilter, activeFilter, page, pageSize, total, summary,
    selectedIds, updatingBattleIds, pageCount, selectable, allSelected, hasFilters, loadBattles,
    resetFilters, changePage, togglePage, refreshAdminData, isBattleActive, setBattleActive, toast,
    deleteDialog, deleteMode, cleanupAge, deleteRows, cleanupTotal, previewLoading, deleting, deleteError,
    acknowledged, previewCleanup, openDelete, closeDelete, confirmDelete };
}
