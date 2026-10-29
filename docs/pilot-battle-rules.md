# Aturan battle pilot — 28 Oktober 2026

Berlaku pada alur TCG dengan AP, melalui migrasi 052 dan UI Player Battle.
Stats kartu, gambar, definisi skill, resep Fusion, besaran pemulihan HP,
pengali Combo/Synergy/Ultimate, dan biaya AP tersimpan tidak diubah.

## Kesempatan serang dan komitmen di Active

Setiap kartu mempunyai **1 kesempatan serang per giliran pemiliknya**.

| Aksi | Memakai kesempatan serang | Mengunci mundur sampai giliran pemilik berikutnya |
| --- | --- | --- |
| Attack atau skill damage | Ya | Ya |
| Combo | Ya, untuk semua peserta | Ya, untuk semua peserta |
| Ultimate | Ya, kartu sumber | Ya, kartu sumber |
| Synergy damage | Ya, kartu sumber | Ya, kartu sumber |
| Skill debuff / Synergy penurunan ATK | Tidak | Ya, kartu sumber |
| Heal, Shield, buff, cleanse | Tidak | Tidak |

Kartu lain yang hanya memenuhi jumlah tipe Synergy tidak memakai jatah serang.
Skill yang menawarkan pilihan efek mengikuti pilihan yang benar-benar dipakai.
Cooldown, AP dan batas penggunaan skill tetap berlaku.

Sesudah aksi ofensif, kartu tidak boleh dipindahkan dari Active ke Bench,
ditukar melalui skill teman, atau dipakai sebagai bahan Fusion hingga giliran
pemiliknya berikutnya. Lock tetap berlaku selama giliran lawan. Heal dan Shield
masih boleh diberikan pada kartu tersebut.

- **Boleh:** masuk dari Bench → Attack → tetap di Active.
- **Boleh:** Switch sebelum Attack; syarat bonus setelah Switch tetap berlaku.
- **Boleh:** Attack → menerima Shield/Heal.
- **Ditolak:** Attack → Bench, Attack → diselamatkan Wind Relay, Attack → Fusion.
- **Ditolak:** Attack → Ultimate/skill damage/Synergy damage dengan kartu yang sama.

Perpindahan tidak mereset kesempatan serang, cooldown, penggunaan sekali per
battle, atau status yang belum berakhir. Pada mode AP, jumlah kembali dari Bench
bukan batas sekali seumur pertandingan; legalitas mengikuti AP, status, slot,
dan komitmen kartu. Mode lama tanpa AP mempertahankan aturan pergerakannya.

## Fusion dan Revive

- Bahan Fusion harus memenuhi resep dan belum melakukan aksi ofensif pada giliran ini.
- Maksimal **1 kartu Fusion di Active per pemain**, termasuk saat kartu Fusion
  masuk dari Bench melalui perpindahan biasa atau skill Switch.
- Boleh mengganti Fusion lama dengan Fusion dari Bench jika Fusion lama boleh mundur.
- Fusion baru tidak dapat menyerang, memberi debuff, menjadi peserta Combo,
  atau menjadi sumber Ultimate/Synergy ofensif hingga giliran pemilik berikutnya.
  Skill bantuan boleh digunakan langsung jika AP dan syaratnya terpenuhi.
- Bahan yang dikonsumsi tetap berada di Graveyard sebagai bahan terpakai dan
  tidak dapat dibangkitkan oleh Necro Recall.
- Kartu yang dibangkitkan menunggu giliran pemilik berikutnya untuk Attack/Skill,
  termasuk Synergy; riwayat penggunaan sekali per battle tetap tersimpan.

## Petunjuk pemain

Tombol yang terkunci menampilkan alasan. Di **Aksi lainnya → Aturan giliran,
Bench, dan Fusion** tersedia ringkasan. Kartu Base yang KO hanya ditandai sebagai
calon target Revive, bukan otomatis siap: skill, AP, cooldown, dan tempat Bench
tetap perlu dipenuhi.

HP pemain berbeda dari HP kartu. Pada batas ronde pertandingan, pemain dengan
HP pemain lebih tinggi menang; HP sama menghasilkan seri. Jumlah ronde mengikuti
pengaturan pertandingan, ditampilkan di ringkasan UI.

## Pemasangan dan verifikasi

Migrasi tidak menulis ulang kartu atau battle yang sudah berlangsung. Aturan
memeriksa aksi berikutnya; Fusion yang baru dibuat sesudah pemasangan mendapat
penundaan ofensif. Kartu Fusion yang sudah ada tidak dihapus atau dipindah paksa.
Counter Attack yang sudah tercatat pada giliran berjalan tetap dihormati.

110 pemeriksaan SQL aturan pilot dan 89 aktivasi skill tersimpan lolos dalam
transaksi rollback, sebelum dan setelah pemasangan. Pemeriksaan mencakup kedua
pemain, penolakan tanpa pemotongan AP/gauge/HP, perpindahan lewat skill, pilihan
efek, bahan Fusion, batas Active, cooldown dan Necro Recall. Hash seluruh data
master kartu, skill, binding, dan resep sama sebelum/sesudah pemasangan.
21 unit test dan 39 kasus browser lolos (tiga kasus browser diulang terpisah;
tes jeda disesuaikan dengan label Host yang sudah digunakan). Build produksi lolos.
