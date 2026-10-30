# Bank soal coding untuk piloting

Seeder `supabase/seeds/coding_questions_pilot_v2.sql` berisi **60 soal aktif** dalam bahasa Indonesia. Setiap soal mempunyai penjelasan, dua petunjuk, topik belajar, tingkat kesulitan, durasi, dan kunci jawaban.

| Mode di editor | Easy | Medium | Hard |
| --- | ---: | ---: | ---: |
| Pilihan ganda | 4 | 4 | 4 |
| Baca gambar / kode | 4 | 4 | 4 |
| Susun blok | 4 | 4 | 4 |
| Cari kesalahan | 4 | 4 | 4 |
| Scratch workspace | 4 | 4 | 4 |
| **Jumlah** | **20** | **20** | **20** |

- **Easy:** apa itu coding, variabel, event bendera hijau, urutan instruksi, penjumlahan skor, kondisi, dan loop sederhana.
- **Medium:** kesalahan reset variabel dalam loop, batas kondisi, string dibanding angka, indentasi Python, deklarasi JavaScript, dan perbaikan program blok.
- **Hard:** list Python, nested loop, akumulasi, perbandingan JavaScript, filter/map, indeks array, fungsi, DOM/event, tag HTML, spesifisitas CSS, dan box model.

Soal bergambar memakai 12 SVG lokal: enam diagram blok dari renderer Blockly aplikasi dan enam gambar kode. Python mempertahankan indentasinya; tag HTML ditampilkan sebagai kode. Workspace Scratch tetap menggunakan blok yang didukung aplikasi, termasuk untuk soal Hard; mode itu bukan editor Python atau JavaScript. Penilaiannya memeriksa struktur, input, nilai, dan urutan blok, tanpa menjalankan sprite. Instruksi soal menyebutkan struktur yang diminta.

## Memasang

1. Pastikan database sudah mempunyai migrasi fitur quiz sampai `030_structured_block_quiz.sql` dan frontend sudah menyertakan `public/images/questions/pilot-v2/`. Jangan jalankan semua migrasi lama ulang.
2. Jalankan isi `supabase/seeds/coding_questions_pilot_v2.sql` di Supabase SQL Editor dengan akses admin. Alternatif melalui CLI pada proyek yang sudah terhubung:

   ```sh
   supabase db query --linked --file supabase/seeds/coding_questions_pilot_v2.sql
   ```

3. Eksekusi pertama menghasilkan `questions_added = 60` dan `private_workspace_keys_added = 12`. Lihat soal melalui **All Questions**, filter kesulitan/kategori, lalu gunakan preview di editor.
4. Pilih kesulitan/topik yang diinginkan di Game Setup. Durasi khusus soal ini mengesampingkan durasi umum Game Setup; kosongkan kolom durasi di editor bila ingin mengikuti pengaturan battle.

| Kesulitan | Pilihan ganda | Gambar | Cari kesalahan | Susun blok | Workspace |
| --- | ---: | ---: | ---: | ---: | ---: |
| Easy | 45 dtk | 60 dtk | 60 dtk | 75 dtk | 120 dtk |
| Medium | 60 dtk | 75 dtk | 75 dtk | 90 dtk | 150 dtk |
| Hard | 90 dtk | 90 dtk | 90 dtk | 120 dtk | 180 dtk |

Seeder menambahkan soal; soal lama, battle, desain kartu, dan skill tidak diubah. ID deterministik membuat pengulangan eksekusi tidak menambah duplikat. Soal yang sudah diedit atau diarsipkan guru tetap dipertahankan. Kunci workspace disimpan di tabel privat khusus admin, dalam transaksi yang sama dengan soal. Jika penyimpanan kunci gagal, seluruh penambahan dibatalkan.

## Mengubah atau menambah soal

Sumber authoring: `scripts/questions/pilot-question-bank.mjs`. Untuk pilihan ganda, opsi pertama di sumber adalah jawaban benar; generator merotasi posisi A–D secara merata. Jangan mengimpor sumber ini ke bundle pemain karena berisi kunci.

```sh
npm run seed:questions          # Buat SQL dan gambar kode; tidak menghubungi database
npm run seed:questions:images   # Buat ulang diagram Scratch melalui Chrome/Blockly
npm run seed:questions -- --check
npm run test:question-seed
npx playwright test -c playwright.card-generator.config.js tests/visual/question-seed.spec.js --workers=1
```

Mengubah sumber lalu menjalankan seed ulang **tidak** menimpa soal terpasang. Untuk koreksi soal lama, gunakan editor admin. Untuk soal baru, tambahkan `key` baru; jangan mengubah `seedVersion` hanya untuk koreksi teks karena akan membuat kumpulan ID baru.

Verifikasi mencakup seluruh kunci jawaban, eksekusi contoh Python/JavaScript, rendering dan perilaku HTML/CSS/DOM, pemuatan Blockly, 120 jawaban benar/salah lewat fungsi penilaian PostgreSQL lokal, pengulangan seed, perlindungan edit guru, dan rollback transaksi. Uji lokal tidak otomatis memasang seed ke Supabase.
