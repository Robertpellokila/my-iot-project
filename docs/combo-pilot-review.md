# Evaluasi Combo untuk piloting — 30 Oktober 2026

Status awal: hasil pemeriksaan dan usulan balancing. **Pembaruan 30 Oktober:** user meminta seluruh mode dan aturan diterapkan. Migrasi 058 kini menerapkan cooldown bersama dan resep yang dapat dibatasi untuk battle baru; rincian final ada di [combo-rules.md](combo-rules.md). Bukti pertandingan di bawah tetap merupakan catatan sebelum perubahan.

## Aturan yang benar-benar berjalan

Battle `BX6VAY` memakai 3 AP per giliran, Combo dua kartu 2 AP, dan satu kesempatan serang per kartu. Semua peserta harus hidup dan berada di Active, belum memakai jatah serang, serta lolos pemeriksaan status/Fusion baru. Sesudah Combo, kedua peserta menggunakan jatah serang dan tidak boleh mundur atau menjadi bahan Fusion sampai giliran pemilik berikutnya.

Belum ada cooldown Combo lintas giliran atau batas penggunaan per match. Pasangan yang masih siap dapat melakukan Combo pada setiap giliran pemilik. Dengan 3 AP dan biaya 2 AP, dua Combo pada giliran yang sama tidak cukup AP; konfigurasi AP lain dapat mengubah kondisi itu. Triple Combo dan Formation nonaktif pada battle ini.

Katalog dua-kartu saat diperiksa memakai 100% ATK utama + floor(70% ATK pendamping), ditambah bonus resep, lalu dikurangi DEF efektif target. Beberapa resep juga mempunyai penetrasi DEF, Heal, Shield, Stun, atau efek lain. Kerusakan langsung ke pemain dan damage akibat kartu KO mengikuti aturan terpisah; damage ke kartu bukan otomatis sebesar itu ke pemain.

## Bukti dari pertandingan

Log menyimpan **Shadow Blitz**, 2 AP, 62 damage, target 118 → 56 HP, tidak KO, damage pemain 0, dan efek Curse. Kartu utama NULL CAT memiliki ATK 35, pendamping BYTE FOX ATK 36, target DEF 11.

Perhitungan resep: `35 + floor(36 × 0,70) + 10 = 70`; penetrasi 25% mengurangi DEF efektif menjadi `11 − round(11 × 0,25) = 8`; hasilnya `70 − 8 = 62` damage. Ini menjelaskan kekuatan satu aksi, tetapi satu peristiwa tidak cukup untuk menyimpulkan durasi rata-rata seluruh match.

## Usulan perubahan pertama

1. Pertahankan **2 AP**, dengan batas eksplisit **satu Combo per pemain per giliran**.
2. Sesudah berhasil memakai Combo, pemain melewati **satu giliran miliknya tanpa Combo**. Contoh: giliran milik sendiri 1 boleh Combo, 2 cooldown, 3 boleh lagi. Giliran lawan tidak menghitung cooldown. Berlaku untuk pemain dan seluruh jenis Combo, sehingga mengganti pasangan, Switch, Fusion, atau Revive tidak meresetnya. Penolakan aksi tidak menghabiskan AP atau memulai cooldown.
3. Pertahankan jatah serang bersama dan komitmen Active yang sudah ada. Pada giliran cooldown, Attack biasa, skill, atau Synergy masih tersedia sesuai syarat masing-masing.
4. Revisi sesuai permintaan user: Generic, Triple dan Formation tetap tersedia dan aktif secara default. Semua jenis berbagi jatah/cooldown yang sama.

Jika diterapkan nanti, simpan konfigurasi dan penggunaan Combo pada battle/ledger pemain; hitung cooldown dari owner-turn; periksa di backend dan tampilkan alasan/tanda siap di UI. Reconnect atau pergantian pasangan tidak boleh melewati pembatasan. Preview harus menunjukkan damage, bonus status, biaya AP dan giliran Combo berikutnya. Hindari mengubah aturan match yang sudah dimulai tanpa pemberitahuan.

Uji cooldown dahulu sebelum sekaligus menurunkan ATK kartu atau multiplier. Jika Combo tetap mendominasi, opsi tahap berikutnya adalah menurunkan kontribusi pendamping dari 70% ke 50% dan meninjau paket damage + kontrol/heal/shield yang terlalu besar. Ini belum angka balance final.

## Yang dicatat saat playtest

- Berapa giliran pemilik dibutuhkan untuk KO pertama dan mengakhiri battle.
- Proporsi Attack biasa, skill, Combo dan giliran tanpa aksi; apakah pemain merasa selalu harus memilih Combo.
- Damage kartu dan damage pemain secara terpisah, termasuk Heal/Shield dan efek kontrol.
- Durasi bertarung versus waktu kuis. Kuis setiap ronde dapat mendominasi waktu nyata walaupun kartu cepat KO.
- Hasil saat pemain unggul/jumlah Active lebih banyak: apakah lawan masih punya kesempatan memulihkan posisi.
