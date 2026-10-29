<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import QRCode from 'qrcode';
import TeacherBattleControls from '../components/battle/TeacherBattleControls.vue';
import { supabase } from '../lib/supabase';
import { useBattleHistory } from '../composables/useBattleHistory.js';

const router = useRouter();
const {
  battles, loading, error, search, statusFilter, activeFilter, page, pageSize, total, summary,
  selectedIds, updatingBattleIds, pageCount, selectable, allSelected, hasFilters, loadBattles,
  resetFilters, changePage, togglePage, refreshAdminData, isBattleActive, setBattleActive, toast,
  deleteDialog, deleteMode, cleanupAge, deleteRows, cleanupTotal, previewLoading, deleting, deleteError,
  acknowledged, previewCleanup, openDelete, closeDelete, confirmDelete,
} = useBattleHistory();
const selectedBattle = ref(null), detailQrs = ref({ p1: '', p2: '' }), zoomedQr = ref(null);
const formatDate = value => value && Number.isFinite(new Date(value).getTime())
  ? new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : '—';
const statusLabel = status => ({ waiting: 'Menunggu pemain', ready: 'Siap dimulai', battle: 'Berlangsung', question: 'Kuis', finished: 'Selesai' }[status] || status || '—');
const startingPlayerName = b => b.starting_player === 'p2' ? b.player2_name || 'Player 2' : b.player1_name || 'Player 1';
const winnerName = b => b.winner === 'p1' ? b.player1_name || 'Player 1' : b.winner === 'p2' ? b.player2_name || 'Player 2' : b.winner === 'draw' ? 'Seri' : '—';
const hasWinner = b => !!b?.winner;
const playerUrl = (b, player) => `${window.location.origin}/play/${encodeURIComponent(b.code)}/${player}`;
const openSetup = () => router.push({ name: 'game-setup' });
const openPublicBattle = b => router.push({ name: 'public-battle', params: { code: b.code } });
const openPlayer = (b, player) => router.push({ name: 'player-battle', params: { code: b.code, player } });
async function copyCode(b) {
  try { await navigator.clipboard.writeText(b.code); toast.success('Kode battle berhasil disalin.'); }
  catch { toast.danger('Kode belum dapat disalin. Izinkan akses clipboard atau salin secara manual.'); }
}
async function changeAccess(b, active) {
  const updated = await setBattleActive(b, active);
  if (updated && selectedBattle.value?.id === b.id) selectedBattle.value = { ...selectedBattle.value, ...updated };
}
async function showBattleDetails(b) {
  selectedBattle.value = b; detailQrs.value = { p1: '', p2: '' };
  try {
    const { data, error: failure } = await supabase.rpc('admin_battle_access', { p_code: b.code });
    if (failure) throw failure;
    if (selectedBattle.value?.id !== b.id) return;
    selectedBattle.value = { ...selectedBattle.value, ...data };
    const [p1, p2] = await Promise.all(['p1', 'p2'].map(side => QRCode.toDataURL(playerUrl(b, side), { width: 360, margin: 1, errorCorrectionLevel: 'M' })));
    if (selectedBattle.value?.id === b.id) detailQrs.value = { p1, p2 };
  } catch { toast.danger('Kode pribadi atau QR belum dapat dimuat. Tutup dan buka kembali detail battle.'); }
}
function closeBattleDetails() { selectedBattle.value = null; zoomedQr.value = null; }
function openZoomedQr(player) {
  if (detailQrs.value[player]) zoomedQr.value = { player, name: selectedBattle.value[player === 'p1' ? 'player1_name' : 'player2_name'], image: detailQrs.value[player] };
}
function updateTeacherBattle(updated) {
  if (selectedBattle.value?.id === updated.id) selectedBattle.value = { ...selectedBattle.value, ...updated };
  void loadBattles();
}
</script>

<template>
  <div class="battle-history-page">
    <div class="history-container">
      <header class="history-header">
        <div><span class="eyebrow">CATATAN PERTANDINGAN</span><h1>Battle History<span class="heading-dot">.</span></h1><p>Ikuti pertandinganmu, lihat hasilnya, dan rapikan riwayat testing.</p></div>
        <div class="header-actions"><button class="secondary" type="button" @click="openDelete('cleanup')">Bersihkan riwayat</button><button class="primary" type="button" @click="openSetup">＋ Buat battle</button></div>
      </header>
      <section class="history-summary" aria-label="Ringkasan riwayat">
        <div><span>Semua pertandingan</span><strong>{{ summary.total ?? '—' }}</strong><small>Riwayat milikmu</small></div>
        <div class="summary-live"><span>Akses aktif</span><strong>{{ summary.active ?? '—' }}</strong><small>Dilindungi dari penghapusan</small></div>
        <div><span>Pertandingan selesai</span><strong>{{ summary.finished ?? '—' }}</strong><small>Hasil sudah tersimpan</small></div>
        <div class="summary-cleanup"><span>Bisa dibersihkan</span><strong>{{ summary.deletable ?? '—' }}</strong><small>Selesai, nonaktif, atau kedaluwarsa</small></div>
      </section>
      <section class="history-workspace" aria-labelledby="history-list-title">
        <header class="workspace-heading"><div><h2 id="history-list-title">Daftar pertandingan</h2><p>Buka Detail untuk kontrol guru, kode pemain, QR, dan riwayat aksi.</p></div><button class="refresh-button secondary" type="button" :disabled="loading" @click="refreshAdminData">↻ Muat ulang</button></header>
        <form class="history-filters" role="search" aria-label="Cari riwayat battle" @submit.prevent="refreshAdminData">
          <label class="search-field"><span>Cari pertandingan</span><input v-model="search" type="search" maxlength="120" placeholder="Kode battle atau nama pemain…" autocomplete="off" /></label>
          <label><span>Status pertandingan</span><select v-model="statusFilter" aria-label="Status pertandingan"><option value="all">Semua status</option><option value="waiting">Menunggu pemain</option><option value="ready">Siap dimulai</option><option value="battle">Berlangsung</option><option value="question">Kuis</option><option value="finished">Selesai</option></select></label>
          <label><span>Status akses</span><select v-model="activeFilter" aria-label="Status akses"><option value="all">Semua akses</option><option value="active">Akses aktif</option><option value="inactive">Bisa dibersihkan</option></select></label>
        </form>
        <div class="selection-bar"><span v-if="selectedIds.length"><strong>{{ selectedIds.length }} dipilih</strong> di halaman ini</span><span v-else>Pilih pertandingan selesai atau nonaktif untuk dihapus.</span><div><button v-if="selectedIds.length" class="text-button" @click="selectedIds=[]">Batal pilih</button><button v-if="hasFilters" class="text-button" @click="resetFilters">Reset filter</button><button v-if="selectedIds.length" class="danger-soft" :disabled="loading" @click="openDelete('selected', battles.filter(b=>selectedIds.includes(b.id)))">Hapus pilihan ({{ selectedIds.length }})</button></div></div>
        <div v-if="error" class="history-error" role="alert"><strong>Riwayat belum dapat diperbarui.</strong><p>{{ error }}</p><button class="secondary" @click="refreshAdminData">Coba lagi</button></div>
        <div class="history-table-area" :aria-busy="loading">
          <div v-if="loading" class="loading-notice" role="status">Memuat pertandingan…</div>
          <table v-if="battles.length" class="history-table" :class="{refreshing:loading}">
            <caption class="sr-only">Riwayat pertandingan, halaman {{ page }} dari {{ pageCount }}</caption>
            <thead><tr><th class="check-cell"><input type="checkbox" aria-label="Pilih semua yang bisa dihapus di halaman ini" :checked="allSelected" :indeterminate="selectedIds.length>0&&!allSelected" :disabled="loading||!selectable.length" @change="togglePage" /></th><th>Pertandingan</th><th>Pemain</th><th>Status &amp; akses</th><th>Hasil</th><th><span class="sr-only">Aksi</span></th></tr></thead>
            <tbody><tr v-for="b in battles" :key="b.id" :class="{selected:selectedIds.includes(b.id)}" :data-battle-code="b.code">
              <td class="check-cell"><input v-model="selectedIds" type="checkbox" :value="b.id" :aria-label="`Pilih battle ${b.code}`" :disabled="loading||!b.can_delete" :title="b.can_delete?'Pilih untuk dihapus':'Battle aktif dilindungi'" /></td>
              <td class="match-cell"><button class="code-button" :title="`Salin kode ${b.code}`" @click="copyCode(b)">{{ b.code }} <span aria-hidden="true">⧉</span></button><time :datetime="b.created_at">{{ formatDate(b.created_at) }}</time></td>
              <td class="players-cell"><span class="player p1"><i>1</i>{{ b.player1_name || 'Player 1' }}</span><span class="player p2"><i>2</i>{{ b.player2_name || 'Player 2' }}</span></td>
              <td class="status-cell"><span class="status-badge" :class="[b.status,{paused:b.teacher_paused&&b.status!=='finished'}]">{{ b.teacher_paused&&b.status!=='finished'?'Dijeda guru':statusLabel(b.status) }}</span><div class="access-control"><button type="button" role="switch" class="active-toggle" :class="{on:isBattleActive(b)}" :aria-label="`Akses battle ${b.code}`" :aria-checked="isBattleActive(b)" :disabled="loading||updatingBattleIds.includes(b.id)||hasWinner(b)||b.status==='finished'" @click="changeAccess(b,!isBattleActive(b))"><span /></button><span>{{ isBattleActive(b)?'Akses aktif':'Akses nonaktif' }}</span></div></td>
              <td class="result-cell"><strong :class="{winner:hasWinner(b)}">{{ hasWinner(b)?(b.winner==='draw'?'Seri':`${winnerName(b)} menang`):'Belum ada hasil' }}</strong><small>Ronde {{ b.round ?? 1 }} / {{ b.total_rounds ?? '—' }}</small></td>
              <td class="row-actions"><button class="detail-button" @click="showBattleDetails(b)">Detail</button><button class="secondary public-button" @click="openPublicBattle(b)">Public ↗</button><button class="delete-button" :aria-label="`Hapus battle ${b.code}`" :disabled="loading||!b.can_delete" :title="b.can_delete?'Hapus riwayat':'Akhiri atau nonaktifkan battle sebelum menghapus'" @click="openDelete('selected',[b])"><svg aria-hidden="true" viewBox="0 0 24 24"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 10v6m4-6v6" /></svg></button></td>
            </tr></tbody>
          </table>
          <div v-else-if="!loading&&!error" class="history-empty"><span aria-hidden="true">▤</span><h3>{{ hasFilters?'Tidak ada pertandingan yang cocok':'Belum ada riwayat battle' }}</h3><p>{{ hasFilters?'Coba kode, nama pemain, atau filter yang lain.':'Buat battle pertama. Hasil dan riwayat aksinya akan tersimpan di sini.' }}</p><button v-if="hasFilters" class="secondary" @click="resetFilters">Reset filter</button><button v-else class="primary" @click="openSetup">Buat battle pertama</button></div>
        </div>
        <footer class="history-pagination"><div><p aria-live="polite">{{ total?(page-1)*pageSize+1:0 }}–{{ Math.min(page*pageSize,total) }} dari <strong>{{ total }}</strong> pertandingan</p><label>Per halaman<select aria-label="Per halaman" v-model.number="pageSize" :disabled="loading"><option :value="10">10</option><option :value="25">25</option><option :value="50">50</option></select></label></div><nav aria-label="Halaman riwayat"><button class="secondary" :disabled="loading||page<=1" @click="changePage(page-1)">← Sebelumnya</button><span>{{ page }} / {{ pageCount }}</span><button class="secondary" :disabled="loading||page>=pageCount" @click="changePage(page+1)">Berikutnya →</button></nav></footer>
      </section>
      <p class="history-footnote">Battle yang masih aktif dilindungi. Kamu dapat menjeda, melanjutkan, atau mengakhirinya lewat Detail → Kelola pertandingan.</p>
    </div>
    <dialog ref="deleteDialog" class="delete-dialog" aria-labelledby="delete-history-title" @cancel.prevent="closeDelete" @click="event=>{if(event.target===deleteDialog)closeDelete()}">
      <header class="delete-heading"><div><span class="eyebrow">KELOLA PENYIMPANAN</span><h2 id="delete-history-title">{{ deleteMode==='cleanup'?'Bersihkan riwayat lama':'Hapus riwayat battle?' }}</h2></div><button class="modal-close" aria-label="Tutup konfirmasi hapus" :disabled="deleting" @click="closeDelete">×</button></header>
      <p>Pertandingan selesai, nonaktif, atau kedaluwarsa bisa dihapus. Battle yang masih aktif tetap dilindungi.</p>
      <label v-if="deleteMode==='cleanup'" class="cleanup-period">Waktu dibuat<select v-model="cleanupAge" :disabled="deleting" @change="previewCleanup"><option value="30">Lebih dari 30 hari lalu</option><option value="7">Lebih dari 7 hari lalu</option><option value="all">Semua tanggal</option></select></label>
      <p v-if="previewLoading" role="status">Memeriksa riwayat yang dapat dibersihkan…</p>
      <template v-else><div class="delete-count"><strong>{{ deleteRows.length }}</strong><span>pertandingan akan dihapus</span></div><p v-if="cleanupTotal>deleteRows.length" class="cleanup-limit">Ada {{ cleanupTotal }} yang memenuhi syarat. Proses maksimal 100 pertandingan paling lama per konfirmasi; ulangi untuk sisanya.</p><ul v-if="deleteRows.length" class="delete-preview"><li v-for="b in deleteRows" :key="b.id"><div><b>{{ b.code }}</b><span>{{ b.player1_name||'Player 1' }} vs {{ b.player2_name||'Player 2' }}</span></div><time>{{ formatDate(b.created_at) }}</time></li></ul><p v-else-if="!deleteError" class="cleanup-empty">Tidak ada riwayat yang memenuhi pilihan ini.</p></template>
      <div class="delete-impact"><strong>Penghapusan ini permanen.</strong><p>Sesi, kartu dalam pertandingan, hasil, kuis, Fusion, dan log aksi terkait akan dihapus. Kartu di Album, UID, desain, dan aturan skill tetap tersimpan.</p><small>Catatan uji skill dan scan yang juga terkait sesi registrasi tetap disimpan. Unduh riwayat aksi dari Detail jika diperlukan.</small></div>
      <label v-if="deleteRows.length" class="delete-acknowledgment"><input v-model="acknowledged" type="checkbox" :disabled="deleting||previewLoading" />Saya memahami bahwa riwayat yang dihapus tidak bisa dikembalikan.</label>
      <p v-if="deleteError" class="history-error" role="alert">{{ deleteError }}</p>
      <footer><button class="secondary" :disabled="deleting" @click="closeDelete">Batal</button><button class="danger-solid" :disabled="deleting||previewLoading||!acknowledged||!deleteRows.length" @click="confirmDelete">{{ deleting?'Menghapus…':`Hapus ${deleteRows.length} pertandingan` }}</button></footer>
    </dialog>
    <div v-if="selectedBattle" class="modal-backdrop" @click.self="closeBattleDetails" @keydown.esc="closeBattleDetails">
      <section class="battle-modal" role="dialog" aria-modal="true" :aria-label="`Detail battle ${selectedBattle.code}`">
        <header class="modal-header">
          <div>
            <span class="eyebrow">DETAIL BATTLE</span>
            <h2>{{ selectedBattle.code }}</h2>
          </div>
          <button type="button" class="modal-close" aria-label="Tutup detail" @click="closeBattleDetails">×</button>
        </header>

        <div class="modal-summary">
          <div><span>Status</span><strong>{{ statusLabel(selectedBattle.status) }}</strong></div>
          <div><span>Ronde</span><strong>{{ selectedBattle.round ?? 1 }} / {{ selectedBattle.total_rounds ?? "-" }}</strong></div>
          <div><span>Pemenang</span><strong>{{ winnerName(selectedBattle) }}</strong></div>
          <div><span>Dibuat</span><strong>{{ formatDate(selectedBattle.created_at) }}</strong></div>
          <div><span>Status akses</span><strong>{{ isBattleActive(selectedBattle) ? "Aktif" : "Tidak aktif" }}</strong></div>
          <div><span>Berakhir</span><strong>{{ selectedBattle.active_until ? formatDate(selectedBattle.active_until) : (hasWinner(selectedBattle) ? "Pemenang ditetapkan" : "Belum ditentukan") }}</strong></div>
          <div><span>Giliran pertama</span><strong>{{ startingPlayerName(selectedBattle) }}</strong></div>
          <div><span>Kuis</span><strong>{{ selectedBattle.question_enabled ? `${selectedBattle.question_level || "medium"} · tiap ${selectedBattle.question_every_rounds || "-"} ronde` : "Nonaktif" }}</strong></div>
          <div><span>Batas waktu giliran</span><strong>{{ selectedBattle.turn_duration_seconds ? `${selectedBattle.turn_duration_seconds} detik` : "-" }}</strong></div>
        </div>

        <TeacherBattleControls :key="selectedBattle.id" :battle="selectedBattle" @update="updateTeacherBattle"/>
        <p class="qr-unavailable">QR hanya berisi alamat halaman. Scan QR lalu masukkan kode pribadi pemain. Jangan bagikan kode ini ke penonton.</p>
        <div class="detail-players">
          <article class="detail-player">
            <div class="detail-player-copy"><span>PLAYER 1</span><strong>{{ selectedBattle.player1_name || "Player 1" }}</strong><code>{{ selectedBattle.player1_access_code || "Kode tidak tersedia" }}</code></div>
            <button v-if="detailQrs.p1" type="button" class="qr-preview" aria-label="Perbesar QR Player 1" @click="openZoomedQr('p1')"><img :src="detailQrs.p1" alt="QR Player 1" /><span>Klik untuk perbesar</span></button>
            <p v-else class="qr-unavailable">Kode pribadi belum dapat dimuat. Tutup lalu buka detail untuk mencoba lagi.</p>
            <button type="button" class="modal-action" :disabled="!selectedBattle.player1_access_code" @click="openPlayer(selectedBattle, 'p1')">Buka halaman Player 1</button>
          </article>

          <article class="detail-player">
            <div class="detail-player-copy"><span>PLAYER 2</span><strong>{{ selectedBattle.player2_name || "Player 2" }}</strong><code>{{ selectedBattle.player2_access_code || "Kode tidak tersedia" }}</code></div>
            <button v-if="detailQrs.p2" type="button" class="qr-preview" aria-label="Perbesar QR Player 2" @click="openZoomedQr('p2')"><img :src="detailQrs.p2" alt="QR Player 2" /><span>Klik untuk perbesar</span></button>
            <p v-else class="qr-unavailable">Kode pribadi belum dapat dimuat. Tutup lalu buka detail untuk mencoba lagi.</p>
            <button type="button" class="modal-action" :disabled="!selectedBattle.player2_access_code" @click="openPlayer(selectedBattle, 'p2')">Buka halaman Player 2</button>
          </article>
        </div>
      </section>
    </div>

    <div v-if="zoomedQr" class="qr-zoom-backdrop" @click.self="zoomedQr = null" @keydown.esc="zoomedQr = null">
      <section class="qr-zoom-modal" role="dialog" aria-modal="true" :aria-label="`QR ${zoomedQr.player}`">
        <button type="button" class="modal-close" aria-label="Tutup QR" @click="zoomedQr = null">×</button>
        <span class="eyebrow">{{ zoomedQr.player === "p1" ? "PLAYER 1" : "PLAYER 2" }}</span>
        <h2>{{ zoomedQr.name || "Player" }}</h2>
        <img :src="zoomedQr.image" :alt="`QR ${zoomedQr.name || zoomedQr.player}`" />
        <p>Scan QR ini untuk membuka halaman player.</p>
      </section>
    </div>
  </div>
</template>
<style scoped src="../components/admin/battle-history.css"></style>
