# Test Cases — Timedoor Battle Cards TCG v1

Checklist ini untuk acceptance manual setelah migration diterapkan ke Supabase environment uji. Kasus database belum dijalankan dari workspace ini.

## Zona dan deck fisik

| Kasus | Aksi | Hasil yang diharapkan |
| --- | --- | --- |
| Deck default | Buat battle tanpa mengubah Deck Size. | Tiap player mulai dengan penghitung physical deck 20; tidak ada Hand/draw digital. |
| Deck custom | Buat battle dengan Deck Size 12. | Penghitung mulai dari 12. |
| Kartu awal | Atur Initial Cards 2, lalu scan dua kartu awal. | Battle menunggu dua scan; keduanya masuk Active. |
| Summon ke Active | Saat giliran, scan RFID sah ketika Active masih punya slot. | Kartu masuk ke slot Active kosong dan counter deck turun satu. |
| Active penuh | Scan summon saat semua slot Active terisi. | Server menolak `ACTIVE_ZONE_FULL`; kartu tidak masuk Bench, counter tidak berubah. |
| Active ke Bench | Drag Active ke slot Bench tersedia. | Kartu pindah ke Bench dan membuka slot Active. |
| Bench ke Active kosong | Drag Bench ke Active yang masih memiliki slot kosong. | Kartu mengisi slot Active kosong. |
| Switch saat Active penuh | Drag Bench ke Active pilihan saat semua slot Active terisi. | Kartu bertukar zona dan menempati slot yang dikosongkan. |
| Slot custom | Uji setup Active 2 / Bench 1, lalu Bench 0. | Server dan UI memakai jumlah setup; Bench 0 menolak pemindahan ke Bench. |

## Serangan, AP, dan combo

| Kasus | Aksi | Hasil yang diharapkan |
| --- | --- | --- |
| Basic attack | Active menyerang Active lawan. | Damage, log, AP, dan kesempatan serang diperbarui oleh server. |
| Bench attack | Kirim attack dengan ID kartu Bench. | Server menolak tanpa perubahan state. |
| Kesempatan serang habis | Kartu menyerang sampai batas per-turn, lalu coba lagi. | Serangan tambahan ditolak; batas custom 2 mengizinkan tepat dua. |
| AP kurang | Mulai action/combo dengan AP di bawah cost. | Server menolak tanpa mengubah HP/zona/AP. |
| 2 Active combo | Pilih dua Active siap, primary, dan target. | Rule catalog cocok; kedua participant menghabiskan kesempatan serang. |
| Invalid Bench combo | Kirim salah satu Bench ID sebagai participant. | Server menolak tanpa damage/AP. |
| Fire + Thunder | Pilih kedua tipe dalam dua urutan berbeda. | Rule Overcharge Flame sama-sama ditemukan dan Burn diterapkan bila status aktif. |
| Water + Forest | Jalankan pasangan. | Nature Recovery memulihkan peserta. |
| Knight + Light | Jalankan pasangan. | Holy Guard cocok dari katalog dan memberi heal/shield. |
| Alias type | Uji Warrior/Holy/Grass/Electric. | Dinormalisasi ke Knight/Light/Forest/Thunder. |
| Same-type | Jalankan dua kartu sama untuk setiap tipe. | Rule same-type masing-masing dipakai. |
| Triple | Aktifkan dan jalankan Fire + Thunder + Dark; ulangi saat toggle mati. | Chaos Storm berhasil saat aktif; ditolak saat nonaktif. |
| Triple tanpa rule | Pilih tiga tipe yang tidak terdaftar. | Ditolak meskipun Triple diaktifkan. |
| Generic combo | Aktifkan Generic, lalu gunakan pasangan tanpa rule. | Combined Strike berhasil; tanpa toggle, ditolak. |
| Formation empat kartu | Aktifkan Formation dan pilih Knight + Light + Forest + Thunder. | Guardian Formation berjalan; empat kartu Active memakai kesempatan serang. |
| Formation tak terdaftar | Pilih susunan 4 tipe yang tidak memiliki rule. | Ditolak oleh server. |
| Participant exhausted/Stun | Pilih kartu yang sudah menyerang atau terkena Stun. | Combo ditolak sebelum perubahan state. |

## Fusion, status, dan end state

| Kasus | Aksi | Hasil yang diharapkan |
| --- | --- | --- |
| Fusion valid | Jalankan resep dengan material dan AP yang cukup. | Material dikonsumsi dan kartu hasil muncul sesuai zona resep; bukan Combo. |
| Fusion slot penuh | Jalankan resep yang hasilnya masuk Active tanpa slot kosong. | Ditolak; material tidak dikonsumsi. |
| KO/graveyard | Damage kartu sampai HP 0. | Kartu masuk Graveyard; ID graveyard tidak dapat menyerang/combo. |
| Status 1 turn | Terapkan Burn, Freeze, Stun, Poison atau Curse. | Efek diproses dan berakhir pada batas turn target yang benar. |
| Status toggle OFF | Jalankan combo/passive status dengan status dimatikan. | Status tidak diterapkan; action dasar tetap bekerja. |
| Switch | Tukar Active dan Bench dengan AP cukup. | Zona/slot dan AP terbarui. |
| Deck out | Habiskan counter deck dan hilangkan kartu playable. | Resolver server menetapkan hasil battle. |
| Battle reload/public | Reload kedua halaman player dan TV setelah summon/combo/status. | Keduanya menampilkan state server yang sama. |
