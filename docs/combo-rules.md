# Aturan Combo untuk piloting

Migrasi 058 berlaku pada battle TCG baru. Pertandingan lama mempertahankan perilakunya; resep lama dibekukan saat migrasi agar penyuntingan katalog tidak mengubah pertandingan tersebut. Statistik kartu, skill, artwork, UID, dan hasil pertandingan tidak diubah.

| Mode | Peserta | Biaya default | Syarat |
| --- | --- | --- | --- |
| Generic / Combined Strike | 2 Base Active | 2 AP | Tidak ada resep khusus yang cocok; Generic diaktifkan |
| Combo pasangan | 2 Base Active | 2 AP | Memenuhi resep tipe, kode kartu, dan/atau tag |
| Triple Combo | 3 Base Active | 3 AP | Triple aktif dan memenuhi resep tiga peserta |
| Formation | 4 Base Active | 3 AP | Formation aktif dan memenuhi resep empat peserta |

Biaya aktual mengikuti Game Setup. Ketiga toggle tersedia dan aktif secara default, serta ikut nonaktif ketika Card Combination dimatikan. Formation adalah serangan bersama empat kartu, bukan aura pasif. Generic tidak menggantikan resep Triple atau Formation yang tidak cocok.

## Jatah dan cooldown

- Peserta harus berbeda, hidup, tidak exhausted, berada di Active, dan belum memakai kesempatan serang. Status yang mengunci aksi tetap berlaku. Fusion tidak ikut Combo pada aturan baru.
- Seluruh peserta memakai satu jatah serang dan mendapat komitmen ofensif: tidak boleh mundur/Switch atau menjadi bahan Fusion sampai giliran pemilik berikutnya. Peserta tidak dikonsumsi ke Graveyard.
- Semua mode berbagi satu jatah pemain per giliran. Setelah sukses, **lewati satu giliran milik sendiri**: Combo pada giliran sendiri 1 → cooldown pada 2 → siap pada 3. Giliran lawan tidak menguranginya.
- Jatah dicatat pada pemain. Mengganti peserta, Switch, Fusion, Revive, reload, atau reconnect tidak meresetnya. Pemain lawan mempunyai jatahnya sendiri.
- Aksi ditolak tidak mengurangi AP/HP atau memulai cooldown. Request yang sama menggunakan receipt idempotensi; klik ganda tidak menggandakan efek.
- Cooldown membatasi Combo, sementara aksi lain tetap mengikuti AP, status, dan jatah serangnya masing-masing.

## Resep dan pengaturan admin

Buka **Skill & Catalog → Resep Combo** atau tautan dari Game Setup. Pilih 2/3/4 peserta, nama, dan tipe masing-masing; kode kartu atau tag per peserta bersifat opsional. Semua syarat pada satu baris harus dipenuhi oleh satu kartu, dan satu kartu tidak dapat mengisi dua baris. Urutan baris tidak menentukan kartu utama.

Pilihan “semua peserta berbagi satu tag” memerlukan irisan tag pada seluruh peserta. Tag `fusion:` tidak dipakai sebagai tag Combo. Kode cetak `COB-008` mengenali kode penyimpanan `COB_008` dan akhiran Studio. Jenis kartu tetap harus sesuai tipe barisnya.

Jika beberapa resep cocok, prioritas terbesar menang, lalu resep paling spesifik (kode kartu/tag), lalu ID yang lebih awal. Resep dapat dinonaktifkan tanpa dihapus. Penyimpanan lama setelah resep diubah orang lain ditolak, dengan draft tetap tersedia untuk ditinjau.

Katalog yang sudah ada dipertahankan: pasangan menurut tipe, Chaos Storm (Dark + Fire + Thunder), dan Guardian Formation (Forest + Knight + Light + Thunder). Tidak ada hubungan kode/tag baru yang ditebak atau ditambahkan ke kartu. Admin dapat mempersempit resep tersebut atau menambahkan resep khusus. Kode, tag, dan tipe dipertandingkan terhadap snapshot kartu battle.

## Damage dan efek

Generic memakai `ATK utama + floor(0,5 × ATK pendamping)`, tanpa bonus damage/status/Heal/Shield. Resep khusus memakai pengali utama, pengali setiap pendamping, bonus damage, dan pengali total dari katalog. Pendamping dihitung sesuai urutan pilihan pemain sesudah kartu utama.

Selanjutnya kurangi DEF efektif setelah penetrasi, minimal 1 damage; Shield dan efek battle tetap diperhitungkan server. Serangan langsung hanya ketika lawan tidak memiliki Active dan opsi Direct Attack diaktifkan, mengikuti rumus langsung yang sudah ada. Preview menampilkan kekuatan dasar sebelum DEF/efek, bukan menjanjikan damage akhir.

Heal resep memulihkan kartu peserta sampai Max HP, bukan HP pemain. Shield melindungi kartu utama; status tambahan mengikuti penerimanya. Shield, status tambahan, dan cleanse memerlukan Status Effects aktif. Bonus-bonus tersebut tidak berubah menjadi efek pasif setiap giliran.

Satu Combo dapat menghasilkan damage lebih besar daripada satu serangan Fusion: ia menggunakan 2–4 kartu, lebih banyak AP, seluruh jatah serang peserta, dan cooldown bersama. Keseimbangan angka tetap harus diamati saat piloting; uji fungsi tidak membuktikan win rate atau durasi match sudah ideal.

## Validasi

`tests/battle/comboRules.test.js` memeriksa pencocokan peserta, kode, tag, prioritas, cooldown, dan preview. `tests/battle/comboRulesRemoteSmoke.sql` menjalankan aksi melalui RPC sebenarnya dalam transaksi ROLLBACK, termasuk ketiga mode, batas AP, efek, pergantian giliran, replay, snapshot, dan hak akses. `tests/visual/combo-rules.spec.js` menguji setup, editor, konfirmasi peserta, cooldown/reload, dan retry di browser. Regresi komitmen ofensif dan panel aksi diuji bersama.
