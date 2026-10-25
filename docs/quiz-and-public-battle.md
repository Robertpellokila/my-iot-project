# Quiz dan Public Battle

## Membuat soal

Menu **Add Question** dan **Edit Question** memakai editor yang sama:

- **Pilihan ganda:** empat pilihan dengan satu kunci jawaban.
- **Baca gambar / Scratch:** upload, tarik file, atau tempel screenshot, lalu isi pilihan jawaban.
- **Susun blok:** tarik blok dari palet, edit teksnya, dan susun kunci urutan. Pemain menerima blok yang diacak. Tombol naik/turun juga tersedia untuk layar sentuh dan keyboard.
- **Cari kesalahan:** tulis 2–4 baris kode dan tentukan baris yang salah.

Gunakan **Coba quiz** sebelum menyimpan untuk mencoba jawaban benar/salah. Mode susun blok membandingkan urutan dengan kunci guru; editor ini tidak menjalankan proyek Scratch `.sb3` atau menilai hasil program secara semantik.

Timer mengikuti Game Setup (default 30 detik). Nilai `0` tetap berarti tanpa batas dan ditampilkan sebagai waktu berjalan. Server tetap menentukan tenggat, satu percobaan per pemain, pemenang, dan bonus.

## Tampilan penonton

Keempat layout memiliki Active dan Bench terpisah dengan panel terang, kartu lebih besar, HP, ATK, dan DEF. Ruang kartu menyesuaikan jumlah kartu. Kartu utama juga menampilkan tipe dan status yang sedang aktif.

Selama giliran pemain:

- Pilihan Active dan target lawan memperbarui kartu utama; pilihan terakhir bertahan setelah aksi.
- Membuka Bench/Graveyard menampilkan panel live dengan kartu yang sedang dilihat, jumlah kartu, dan nama pemain.
- Menggeser pilihan pada viewer pemain memperbarui panel penonton.
- Menutup viewer, memulai quiz, atau pergantian giliran menutup panel live. Status viewer dari giliran lama tidak ditampilkan kembali.
- Kanal realtime mencoba tersambung kembali setelah koneksi terputus dan mengirim ulang status terbaru.

Soal quiz, gambar/blok, timer, dan nama pemain yang menjawab benar ditampilkan di Public Battle. Penonton tidak mengirim jawaban atau mengubah pilihan pemain.

## Verifikasi

```sh
node --test tests/questions/questionModel.test.js tests/questions/publicBattleActivity.test.js
npm run build
```

Pemeriksaan SQL memakai PostgreSQL dalam memori (PGlite) dan fungsi grading dari migrasi proyek, tanpa mengubah battle pengguna. Pasang `@electric-sql/pglite` di direktori sementara lalu jalankan:

```sh
PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite/dist/index.js node tests/questions/quizDatabase.mjs
```

Migrasi `028_validate_interactive_quiz_answers.sql` mencakup validasi isi soal, format jawaban, token, ronde aktif, dan pembatasan akses grader internal. Pengujian SQL juga mencakup dua jawaban salah, jawaban terlambat, pengulangan jawaban, dan bonus tunggal.

Pemeriksaan browser menggunakan data contoh: empat layout, drag/drop editor, upload preview, jawaban benar/salah, timer/hasil publik, serta dua jendela yang tersambung ke kanal realtime terisolasi. Skenario reconnect dan penolakan viewer dari giliran sebelumnya juga diperiksa.
