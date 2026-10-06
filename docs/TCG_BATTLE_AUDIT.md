# Audit Timedoor Battle Cards — TCG v1

## Ringkasan

Battle lama menggabungkan aturan giliran dengan RFID dan beberapa asumsi zona. Perubahan lokal menambahkan konfigurasi per sesi untuk slot, AP, kesempatan serang, Combo, type rule catalog, dan aturan summon Active-only.

Hand, pengocokan, dan pembagian kartu tetap dilakukan di meja. Sistem menyimpan ukuran physical deck yang ditentukan di Game Setup (default 20) dan mengurangi penghitung saat RFID card dimainkan. Tidak ada hand digital atau draw phase.

## Status cakupan

| Area | Status | Catatan |
| --- | --- | --- |
| Physical deck | Didukung | Default 20, dapat diubah di Game Setup. |
| Hand/draw digital | Di luar sistem | Sesuai klarifikasi; prosedur fisik di meja. |
| Active/Bench slots | Didukung | Per sesi, configurable; default masing-masing 4. |
| RFID summon | Didukung lokal | Hanya masuk slot Active kosong. Server menolak scan saat Active penuh, tanpa auto-bench. |
| Bench return/switch | Didukung lokal | Bench mengisi slot Active kosong atau menukar Active terpilih ketika penuh. |
| AP dan biaya aksi | Didukung lokal | Disimpan per battle; nilai dapat diubah dari Game Setup. |
| Serangan per kartu | Didukung lokal | Batas per turn configurable dan divalidasi server. |
| Combo 2 kartu | Didukung lokal | Semua peserta harus Active, hidup, tidak terblokir, dan belum memakai kesempatan serang. |
| 21 pair + same type | Didukung lokal | Rule silang dan tujuh rule same-type di-seed ke katalog database. |
| Knight/Light | Didukung lokal | Tipe canonical. Alias Warrior→Knight dan Holy→Light; kartu baru otomatis memakai rule catalog. |
| Triple/Formation | Didukung lokal | Toggle Game Setup dan rule wajib; tersedia Chaos Storm dan Guardian Formation. |
| Generic Combo | Didukung lokal | Toggle mengizinkan combo dua kartu tanpa rule tipe khusus. |
| Fusion | Sebagian didukung | Tetap menggunakan recipe dan resolver fusion yang ada, terpisah dari Combo. |
| Status | Sebagian didukung | Combo menggunakan resolver status existing untuk heal, shield, cleanse, dan status. Uji durasi per turn masih diperlukan setelah migration. |
| Skills/event engine | Sebagian didukung | Katalog skill/generic effect sudah ada; belum seluruh event contoh pada spesifikasi disatukan ke dispatcher generik. |
| Public spectator | Sebagian didukung | Mencerminkan state server dan data combo; cinematic TV lengkap untuk setiap combo belum dibuat. |

## Risiko dan batas penerapan

- Backend menjadi sumber validasi untuk turn, AP, zona, target, status, dan combo.
- Migration 024 meningkatkan RPC existing dengan memeriksa bentuk definisi SQL terlebih dahulu dan membatalkan migrasi bila sumber tidak cocok.
- Perubahan frontend dan migration masih lokal; belum diterapkan ke Supabase.
- Pemeriksaan sebelumnya menemukan riwayat migration lokal dan remote tidak sejajar. Jangan `db push` sebelum riwayat dan SQL ditinjau.
- Dynamic migration matching sudah dibandingkan read-only dengan definisi RPC linked saat ini: seluruh 16 source snippets yang dicari ditemukan. Itu belum menggantikan eksekusi pada database uji.

## File utama

- `src/views/GameSetup.vue`: slot, deck fisik, AP, cost, serangan per kartu, dan toggle rules.
- `src/views/PlayerBattle.vue`: Active-only Combo, preview biaya/efek, drag Bench/Active, dan pesan summon.
- `src/views/GameLanding.vue`: tutorial zona, deck fisik, aksi, dan kombinasi tipe.
- `src/utils/tcgTypes.js`: normalisasi tujuh tipe TCG beserta alias lama.
- `supabase/migrations/024_configurable_active_only_tcg_combos.sql`: katalog combo dan validasi server.
