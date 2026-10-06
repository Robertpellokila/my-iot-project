# Timedoor Battle Cards — TCG v1

Dokumen ini menjelaskan ruleset yang dipakai oleh battle baru dengan `ruleset: tcg_v1` dan Action Points aktif. Aturan per battle disimpan di `battle_sessions` dan diatur lewat Game Setup.

## Arena dan deck fisik

Default Game Setup: 4 slot Active, 4 slot Bench, physical deck 20 kartu, 3 AP per giliran, dan 1 kesempatan serang per kartu Active per giliran. Semua jumlah tersebut dapat diubah di Game Setup.

Hand, pengocokan, dan pengambilan kartu adalah aturan permainan di meja. Aplikasi tidak menyimpan hand digital atau draw phase. Aplikasi hanya mencatat ukuran physical deck dan menguranginya setelah kartu RFID yang sah dimainkan.

Kartu awal yang di-scan masuk ke Active. Setelah battle dimulai, pemain memilih Summon lalu scan kartu dari hand fisik. Scan summon hanya menaruh kartu ke slot Active yang kosong. Jika Active penuh, pemain harus memindahkan Active ke Bench dahulu; sistem menolak scan summon dan tidak mengalihkannya ke Bench.

Bench dan Graveyard mengikuti jumlah slot/aturan battle. Kartu di Graveyard tidak menyerang atau ikut Combo. Skill tertentu dapat berinteraksi dengan Graveyard bila deskripsi skill dan validasi server mengizinkannya.

## Giliran dan AP

Pada awal giliran, pemain menerima jumlah AP yang diatur di Game Setup. AP yang tersisa tidak dibawa ke giliran berikutnya. Pemain dapat mengakhiri giliran lebih awal; timer tetap berlaku. Biaya tiap aksi juga berasal dari Game Setup, sementara skill dapat mengatur override AP sendiri.

Biaya default:

| Aksi | AP default |
| --- | ---: |
| Serangan biasa | 1 |
| Summon | 1 |
| Switch Active/Bench | 1 |
| Special Skill | 1 |
| Combo 2 kartu Active | 2 |
| Triple Combo | 3 |
| Fusion | 2 |
| Ultimate | 2 |

Semua biaya dapat diubah pada Game Setup. Nilai skill tertentu dapat mengoverride biaya Special Skill.

## Zona dan perpindahan

- Hanya kartu Active yang dapat menyerang, menjadi target serangan, atau ikut Combo.
- Kartu Bench tidak dapat menyerang atau membantu Combo.
- Seret Active ke Bench untuk mengosongkan slotnya.
- Kartu Bench dapat kembali ke slot Active yang kosong. Jika Active penuh, kartu Bench bertukar posisi dengan Active yang dipilih.
- Jumlah slot tidak dikunci di komponen; server membaca `max_active` dan `max_bench` dari battle.

## Serangan

Kartu Active hanya dapat menyerang jika masih hidup, tidak diblokir status, dan belum menggunakan batas serangnya pada giliran tersebut. Batas default adalah satu kali dan dapat diubah di Game Setup. Backend memvalidasi giliran, AP, zona, target, status, dan kesempatan serang sebelum mengubah HP.

Serangan tertarget memakai rumus saat ini `maksimal 1, ATK − DEF efektif`. Jika tidak ada Active lawan dan Direct Attack aktif, basic attack dapat mengenai HP pemain lawan. Kartu yang KO masuk Graveyard. Sisa physical deck 0 dan tidak ada kartu playable juga diperiksa sebagai kondisi kekalahan.

## Combo Attack

Combo memilih dua sampai empat kartu **dari Active**. Pemain memilih kartu utama secara eksplisit; urutan slot tidak dibatasi. Semua peserta harus milik pemain yang sama, hidup, tidak diblokir status, dan masih memiliki kesempatan serang. Setelah Combo sukses, seluruh peserta memakai kesempatan serangnya.

- Combo 2 kartu adalah aksi standar.
- Triple Combo hanya tersedia jika diaktifkan di Game Setup dan pasangan tiga tipe memiliki aturan terdaftar.
- Combo empat kartu memerlukan Formation aktif serta aturan empat kartu yang tersedia.
- Bench tidak pernah menjadi peserta.
- Generic Combo opsional tersedia untuk pasangan tanpa aturan tipe khusus.
- Combo bukan Fusion: semua kartu peserta tetap berada di arena.

Tabel aturan tipe ada di `tcg_combo_rule_catalog`. Urutan tipe dinormalisasi server, sehingga pasangan yang sama cocok tanpa bergantung urutan pilihan. Data awal mencakup 21 pasangan silang dan tujuh pasangan tipe sama untuk Knight, Fire, Water, Forest, Thunder, Light, dan Dark. Contoh Triple Combo awal adalah Fire + Thunder + Dark — Chaos Storm. Rule tidak terdaftar ditolak oleh server.

Efek tipe saat ini mencakup bonus damage, tembus sebagian DEF, heal, Shield, cleanse, dan status satu giliran seperti Burn, Freeze, Stun, Poison, atau Curse. Data efek disimpan per rule, bukan di switch-case frontend.

## Fusion dan Skill

Combo mempertahankan kartu sumber; Fusion mengonsumsi material sesuai resep dan membuat kartu hasil. Fusion memakai recipe dan validasi backend yang sudah ada, termasuk biaya AP battle.

Satu kartu dapat memiliki beberapa skill. Skill yang dipakai dicek dari daftar skill kartu dan aturan katalognya: target, biaya gauge/AP, cooldown, durasi, batas pemakaian, status aktif, dan status aksi. Status effect mengikuti resolver yang sudah ada; UI kartu menampilkan animasinya tanpa badge teks besar.

## Quiz dan public battle

Pengaturan kuis—topik, level, interval, durasi, dan reward—tetap berasal dari Game Setup. Quiz menjeda aksi battle sampai dijawab atau hasil kedua pemain selesai diproses. Jawaban dapat membuka pilihan bonus skill sesuai konfigurasi.

Public Battle menampilkan state server, AP kedua pemain, kartu Active, dan efek yang berjalan. Aksi, scan, Combo, dan perpindahan zona tetap divalidasi server melalui RPC; UI player tidak menjadi sumber aturan.

## Cakupan lokal dan penerapan

Perubahan skema dan resolver tersedia sebagai migration `024_configurable_active_only_tcg_combos.sql`. File migrasi tersebut baru berada di workspace; ia belum diterapkan ke project Supabase. Setelah migration di-review dan diterapkan, ruleset TCG yang dibuat berikutnya akan memakai aturan ini.
