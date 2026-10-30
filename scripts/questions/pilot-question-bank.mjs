// Authoring source only: never import answer keys into the player bundle.
import { BLOCK_SPECS, DEFAULT_GRADING } from '../../src/lib/questions/scratchBlocks.js';
export const seedVersion = 'tbc-pilot-questions-2026-10-v2';
const N = n => ({ type: 'tbc_number', fields: { NUM: n } });
const T = text => ({ type: 'tbc_text', fields: { TEXT: text } });
const V = name => ({ type: 'tbc_value', fields: { VAR: name } });
const input = block => ({ block });
const block = (type, fields = {}, inputs = {}) => ({ type: `tbc_${type}`, ...(Object.keys(fields).length ? { fields } : {}), ...(Object.keys(inputs).length ? { inputs: Object.fromEntries(Object.entries(inputs).map(([k,v]) => [k,input(v)])) } : {}) });
const chain = (...nodes) => nodes.reduceRight((next, node) => ({ ...structuredClone(node), ...(next ? { next: { block: next } } : {}) }), null);
const W = (...nodes) => ({ blocks: { languageVersion: 0, blocks: [{ ...chain(...nodes), x: 30, y: 30 }] } });
const flag = () => block('flag');
const move = n => block('move', {}, { STEPS: N(n) });
const say = value => block('say', {}, { TEXT: typeof value === 'string' ? T(value) : value, SECONDS: N(2) });
const set = (name, value) => block('set', { VAR: name }, { VALUE: typeof value === 'number' ? N(value) : value });
const change = (name, n) => block('change', { VAR: name }, { VALUE: N(n) });
const repeat = (n, ...body) => block('repeat', {}, { TIMES: N(n), DO: chain(...body) });
const compare = (a, op, b) => block('compare', { OP: op }, { A: a, B: b });
const condition = (check, ...body) => block('if', {}, { IF: check, DO: chain(...body) });
const math = (a, op, b) => block('math', { OP: op }, { A: a, B: b });
const list = [];
function add(level, mode, key, category, topic, question, fields, explanation, hints) {
  list.push({ key: `${level}-${mode}-${key}`, level, mode, category, topic, question, ...fields, explanation, hints });
}
const choice = (level,key,category,topic,question,options,explanation,hints,extra={}) => add(level,'choice',key,category,topic,question,{options,...extra},explanation,hints);
const picture = (level,key,category,topic,question,options,diagram,explanation,hints,extra={}) => add(level,'image_choice',key,category,topic,question,{options,diagram,...extra},explanation,hints);
const order = (level,key,category,topic,question,blocks,explanation,hints,extra={}) => add(level,'block_order',key,category,topic,question,{blocks,...extra},explanation,hints);
const bug = (level,key,category,topic,question,code,bugLine,explanation,hints,extra={}) => add(level,'find_bug',key,category,topic,question,{code,bugLine,...extra},explanation,hints);
const workspace = (level,key,topic,question,initial,solution,explanation,hints,extra={}) => {
  const types = new Set();
  function visit(node) { if (!node || typeof node !== 'object') return; if (node.type) types.add(node.type); for (const v of Object.values(node)) if (typeof v === 'object') visit(v); }
  visit(initial); visit(solution);
  const allowed_types = [...types].sort();
  const categories = [...new Set(BLOCK_SPECS.filter(s => types.has(s.definition.type)).map(s => s.category))];
  add(level,'scratch_blocks',key,'scratch',topic,question,{initial,solutions:[solution],config:{version:1,allowed_types,categories,initial},grading:{...DEFAULT_GRADING},...extra},explanation,hints);
};
const scratch = (title,program) => ({kind:'scratch',title,program});
const codeImage = (language,code) => ({kind:'code',language,code});

// EASY: concrete instructions, events, sequence, variables and small loops.
choice('easy','coding','programming_basics','Mengenal coding','Apa yang paling tepat menjelaskan coding?',
 ['Menulis instruksi agar komputer melakukan tugas','Menggambar semua bagian komputer','Mempercepat internet dengan menekan tombol','Menghafal warna pada layar'],
 'Coding adalah menyusun instruksi yang dapat dijalankan komputer. Instruksi dibuat untuk menyelesaikan tugas tertentu.',
 ['Pikirkan cara memberi perintah kepada komputer.','Komputer mengikuti instruksi yang kita tulis, bukan menebak keinginan kita.']);
choice('easy','variable','programming_basics','Variabel','Di game, jumlah koin pemain bisa berubah. Apa kegunaan variabel koin?',
 ['Menyimpan jumlah koin agar bisa dibaca dan diubah','Menghapus semua koin dari game','Membuat komputer berjalan tanpa listrik','Mengubah setiap gambar menjadi koin'],
 'Variabel menyimpan suatu nilai, misalnya jumlah koin. Nilainya bisa dibaca dan diperbarui ketika pemain mendapat koin.',
 ['Bayangkan sebuah kotak bernama koin.','Isi kotak itu adalah angka yang perlu diingat program.']);
choice('easy','loop','scratch','Perulangan','Di Scratch, blok repeat 4 berisi move 5 steps. Sprite tidak menyentuh tepi dan arahnya tidak berubah. Berapa total langkah geraknya?',
 ['20 langkah','9 langkah','4 langkah','5 langkah'],
 'Move 5 steps dijalankan empat kali: 5 + 5 + 5 + 5 = 20 langkah.',
 ['Perintah di dalam repeat dijalankan berulang.','Jumlahkan 5 sebanyak 4 kali.']);
choice('easy','condition','programming_basics','Kondisi','Atur skor ke 3. Jika skor > 5, katakan "Hebat". Setelah kondisi, katakan "Selesai". Pesan apa yang muncul?',
 ['Hanya Selesai','Hanya Hebat','Hebat lalu Selesai','Tidak ada pesan'],
 '3 > 5 bernilai salah, jadi pesan Hebat dilewati. Perintah setelah kondisi tetap berjalan dan menampilkan Selesai.',
 ['Bandingkan skor 3 dengan batas 5.','Perintah setelah kondisi tidak berada di dalam bagian jika.']);

picture('easy','move','scratch','Membaca blok gerak','Setelah bendera hijau diklik, berapa total langkah yang ditempuh? Anggap arah sprite tetap dan tidak ada skrip lain.',
 ['25 langkah','15 langkah','10 langkah','35 langkah'],scratch('Gerak berurutan',W(flag(),move(10),move(15))),
 'Dua blok move berjalan berurutan: 10 + 15 = 25 langkah.', ['Baca blok dari atas ke bawah.','Kedua gerakan dijalankan, bukan hanya gerakan terakhir.']);
picture('easy','repeat','scratch','Membaca loop','Perhatikan blok pada gambar. Berapa total langkah setelah semua pengulangan selesai?',
 ['30 langkah','13 langkah','10 langkah','3 langkah'],scratch('Gerak berulang',W(flag(),repeat(3,move(10)))),
 'Blok move 10 berada di dalam repeat 3, sehingga dijalankan tiga kali dan menghasilkan 30 langkah.', ['Lihat angka pada repeat.','Kalikan jumlah pengulangan dengan langkah setiap pengulangan.']);
picture('easy','coins','scratch','Perubahan variabel','Berapa nilai koin yang dikatakan sprite setelah program pada gambar selesai?',
 ['5','3','2','23'],scratch('Menghitung koin',W(flag(),set('koin',2),change('koin',3),say(V('koin')))),
 'Set memberi nilai awal 2, lalu change menambah 3. Nilai akhirnya 5.', ['Set menetapkan nilai awal.','Change menambah nilai sebelumnya, bukan menggantinya.']);
picture('easy','say','scratch','Urutan instruksi','Setelah bendera diklik, bagaimana urutan dua pesan yang terlihat?',
 ['Halo lalu Ayo belajar','Ayo belajar lalu Halo','Halo saja','Kedua pesan muncul bersamaan'],scratch('Urutan pesan',W(flag(),say('Halo'),say('Ayo belajar'))),
 'Say pertama menampilkan Halo selama 2 detik. Setelah itu say kedua menampilkan Ayo belajar.', ['Perhatikan blok yang terhubung tepat di bawah bendera.','Say for seconds selesai dahulu sebelum blok berikutnya berjalan.']);

order('easy','morning','programming_basics','Algoritma berurutan','Susun instruksi tepat sesuai tujuan: mulai program, minta nama, simpan jawaban sebagai nama, lalu sapa nama tersebut.',
 ['Mulai program','Tanyakan: siapa namamu?','Simpan jawaban ke variabel nama','Tampilkan: Halo, diikuti nilai nama'],
 'Program meminta masukan sebelum menyimpannya. Sapaan memakai nilai yang sudah disimpan.', ['Nilai nama berasal dari jawaban pengguna.','Jangan memakai nama sebelum jawaban disimpan.']);
order('easy','scratch-event','scratch','Event dan urutan','Susun blok Scratch agar saat bendera diklik, sprite bergerak 10 langkah dahulu, menunggu 1 detik, lalu mengatakan Halo.',
 ['Ketika bendera hijau diklik','Gerak 10 langkah','Tunggu 1 detik','Katakan Halo selama 2 detik'],
 'Event memulai skrip. Sesudah bergerak, sprite menunggu, lalu mengucapkan Halo.', ['Event adalah awal skrip.','Soal meminta jeda setelah gerakan, sebelum pesan.']);
order('easy','score','scratch','Inisialisasi variabel','Susun blok agar skor selalu dimulai dari 0 setiap bendera diklik, bertambah 2, lalu nilainya ditampilkan.',
 ['Ketika bendera hijau diklik','Atur skor ke 0','Ubah skor sebesar 2','Katakan nilai skor'],
 'Skor diatur ke 0 sebelum ditambah 2. Pesan terakhir menampilkan nilai 2.', ['Mulai dengan event, kemudian nilai awal.','Jika skor diatur ke 0 setelah penambahan, hasil penambahan akan hilang.']);
order('easy','repeat-message','scratch','Loop dan pesan akhir','Susun blok: mulai dari bendera, ulangi gerak 5 langkah sebanyak 2 kali, tutup pengulangan, lalu katakan Selesai di luar loop.',
 ['Ketika bendera hijau diklik','Ulangi 2 kali:','    Gerak 5 langkah','Selesai pengulangan','Katakan Selesai'],
 'Gerakan berada di dalam loop, sedangkan pesan Selesai berada setelah loop dan hanya muncul sekali.', ['Blok gerak harus berada di antara awal dan akhir pengulangan.','Pesan akhir diletakkan setelah pengulangan ditutup.']);

bug('easy','minus','scratch','Bug perubahan skor','Skrip ini harus menambah skor dari 0 menjadi 1. Baris mana yang harus diperbaiki?',
 'Ketika bendera hijau diklik\nAtur skor ke 0\nUbah skor sebesar -1\nKatakan nilai skor',2,
 'Baris 3 mengurangi skor. Ganti -1 menjadi 1 agar skor bertambah dari 0 menjadi 1.', ['Periksa arah perubahan nilainya.','Angka negatif mengurangi skor.']);
bug('easy','event','scratch','Bug event','Sprite seharusnya bergerak hanya ketika tombol spasi ditekan. Baris mana yang memakai event yang salah?',
 'Ketika bendera hijau diklik\nGerak 10 langkah\nKatakan Ayo',0,
 'Baris 1 harus memakai event ketika tombol spasi ditekan. Bendera hijau adalah pemicu yang berbeda.', ['Pemicu program berada di awal.','Gerakan dan pesan sudah benar; yang perlu diubah adalah kapan skrip dimulai.']);
bug('easy','loop-count','scratch','Bug jumlah pengulangan','Sprite harus bergerak total 30 langkah, 10 langkah pada setiap pengulangan. Baris mana yang harus diperbaiki?',
 'Ketika bendera hijau diklik\nUlangi 2 kali:\n    Gerak 10 langkah\nSelesai pengulangan',1,
 'Baris 2 harus mengulang 3 kali. Dua pengulangan hanya menghasilkan 20 langkah.', ['Hitung total langkah dari jumlah pengulangan.','Untuk mencapai 30 dengan langkah 10, tentukan jumlah pengulangannya.']);
bug('easy','display-value','scratch','Bug menampilkan data','Program harus menyebut nilai variabel skor, yaitu 5. Baris mana yang justru menyebut teks biasa?',
 'Ketika bendera hijau diklik\nAtur skor ke 5\nTunggu 1 detik\nKatakan teks "skor"',3,
 'Baris 4 harus menggunakan blok nilai variabel skor, bukan teks "skor". Teks biasa tidak membaca isi variabel.', ['Bedakan nama variabel dengan isi variabel.','Periksa input pada perintah Katakan.']);

workspace('easy','move','Event dan gerak','Lengkapi skrip: when flag clicked → move 10 steps. Gunakan tepat satu event dan satu blok gerak.',W(flag()),W(flag(),move(10)),
 'Move 10 disambungkan di bawah event bendera agar dijalankan setelah bendera diklik.', ['Ambil blok move dari Motion.','Sambungkan blok gerak di bawah event dan isi steps dengan 10.']);
workspace('easy','repeat','Loop sederhana','Lengkapi skrip: when flag clicked → repeat 3. Masukkan tepat satu move 10 steps ke dalam repeat. Jangan tambahkan gerakan di luar loop.',W(flag()),W(flag(),repeat(3,move(10))),
 'Satu move 10 di dalam repeat 3 menghasilkan 30 langkah. Yang dinilai adalah susunan loop dan nilai input.', ['Repeat ada di kategori Control.','Letakkan move di rongga repeat, bukan setelahnya.']);
workspace('easy','coins','Variabel dan penambahan','Susun setelah bendera: set koin to 2 → change koin by 3 → say nilai variabel koin for 2 seconds. Gunakan nama variabel koin.',W(flag()),W(flag(),set('koin',2),change('koin',3),say(V('koin'))),
 'Nilai awal koin adalah 2 dan bertambah 3, sehingga pesan menampilkan 5. Say harus berisi blok variabel, bukan teks koin.', ['Gunakan set sebelum change.','Tarik nilai variabel koin ke input TEXT pada say; durasinya 2 detik.']);
workspace('easy','positive','Kondisi sederhana','Setelah bendera, set koin to 1. Tambahkan if koin > 0 dengan say "Ada koin" for 2 seconds di dalamnya. Tidak perlu else.',W(flag()),W(flag(),set('koin',1),condition(compare(V('koin'),'>',N(0)),say('Ada koin'))),
 'Kondisi koin > 0 benar karena nilainya 1. Say berada di dalam if dan menampilkan Ada koin.', ['Ambil if dari Control dan pembanding > dari Operators.','Gunakan blok nilai koin di sisi kiri pembanding dan angka 0 di kanan.']);

// MEDIUM: diagnose a specific bug, repair it, then trace the resulting state.
choice('medium','replace-change','scratch','Memperbaiki reset skor','Skor dimulai dari 0. Di dalam repeat 3 dipakai set skor to 2, padahal targetnya skor akhir 6. Perbaikan yang tepat adalah…',
 ['Ganti set di dalam loop dengan change skor by 2','Ganti nilai awal skor menjadi 6 lalu pertahankan set','Pindahkan set skor to 2 setelah loop','Ganti repeat 3 menjadi repeat 6 tanpa mengubah set'],
 'Set selalu menimpa nilai dengan 2. Change menambahkan 2 ke nilai sebelumnya, sehingga tiga pengulangan menghasilkan 6.', ['Bandingkan arti set dengan change.','Targetnya menambahkan dua pada setiap pengulangan.']);
choice('medium','boundary','programming_basics','Batas kondisi','Pemain lulus jika skor minimal 10. Kode memakai kondisi skor > 10 sehingga skor 10 tidak lulus. Kondisi penggantinya adalah…',
 ['skor >= 10','skor < 10','skor == 10 saja','skor > 11'],
 'Minimal 10 berarti 10 atau lebih. Operator >= memasukkan nilai batas 10.', ['Uji kondisi menggunakan skor tepat 10.','Diperlukan kondisi lebih besar atau sama dengan batas.']);
choice('medium','js-update','javascript','Melacak variabel','JavaScript berikut dijalankan: let skor = 4; skor = skor + 3; console.log(skor); Apa yang dicetak?',
 ['7','4','3','43'],
 'Skor bertipe angka. 4 ditambah 3 menghasilkan 7, lalu nilai baru disimpan kembali ke skor.', ['Kedua nilai adalah angka, bukan teks dalam tanda petik.','Gunakan nilai baru ketika membaca console.log.'],{execution:{language:'javascript',code:'let skor = 4;\nskor = skor + 3;\nconsole.log(skor);',stdout:'7'}});
choice('medium','python-indent','python','Memperbaiki indentasi','Python: if skor > 0: diikuti print("Ada poin") tanpa indentasi. Bagaimana memperbaikinya agar print berada di dalam if?',
 ['Tambahkan indentasi sebelum print pada baris berikutnya','Hapus titik dua setelah if','Ganti if menjadi print','Tambahkan tanda kutip pada seluruh program'],
 'Python memakai indentasi untuk menandai isi blok. Print harus diberi indentasi di bawah baris if yang berakhir titik dua.', ['Perhatikan bagaimana Python menandai isi suatu blok.','Baris di dalam if menjorok ke kanan secara konsisten.']);

picture('medium','set-loop','scratch','Membaca bug reset','Berapa nilai skor yang dikatakan setelah loop selesai? Perhatikan jenis blok di dalam repeat.',
 ['2','6','3','0'],scratch('Set bukan change',W(flag(),set('skor',0),repeat(3,set('skor',2)),say(V('skor')))),
 'Set skor to 2 dijalankan berulang, tetapi setiap kali hanya menyimpan 2. Tidak ada penjumlahan menjadi 6.', ['Nama blok di dalam loop adalah set.','Nilai lama ditimpa setiap kali set berjalan.']);
picture('medium','strict-comparison','scratch','Batas kondisi','Skor awal 5. Pesan apa yang muncul dari percabangan pada gambar?',
 ['Coba lagi','Lulus','5','Tidak ada pesan'],scratch('Periksa batas kondisi',W(flag(),set('skor',5),block('if_else',{}, {IF:compare(V('skor'),'>',N(5)),DO:say('Lulus'),ELSE:say('Coba lagi')}))),
 '5 > 5 bernilai salah, jadi cabang else menampilkan Coba lagi. Jika 5 harus lulus, gunakan kondisi yang mencakup nilai sama.', ['Apakah 5 lebih besar dari 5?','Saat kondisi salah, bagian else yang dijalankan.']);
picture('medium','js-string','javascript','Teks dan angka','Apa output JavaScript pada gambar?',
 ['21','3','2','Program selalu error'],codeImage('JavaScript','let skor = "2";\nskor = skor + 1;\nconsole.log(skor);'),
 'Skor adalah string "2". Operator + dengan string menggabungkan teks sehingga hasilnya "21".', ['Nilai awal memakai tanda petik.','Penjumlahan angka dan penggabungan teks menghasilkan hal berbeda.'],{execution:{language:'javascript',code:'let skor = "2";\nskor = skor + 1;\nconsole.log(skor);',stdout:'21'}});
picture('medium','python-range','python','Batas loop Python','Apa angka yang dicetak program Python pada gambar?',
 ['6','10','3','4'],codeImage('Python','total = 0\nfor n in range(1, 4):\n    total += n\nprint(total)'),
 'Range(1, 4) menghasilkan 1, 2, dan 3; batas akhir 4 tidak ikut. Totalnya 6.', ['Batas akhir range tidak disertakan.','Jumlahkan hanya angka 1, 2, dan 3.'],{execution:{language:'python',code:'total = 0\nfor n in range(1, 4):\n    total += n\nprint(total)',stdout:'6'}});

order('medium','python-total','python','Akumulasi tanpa reset','Susun Python untuk menghitung total tiga angka di daftar. Inisialisasi total sekali sebelum loop dan cetak hasil setelah loop.',
 ['total = 0','for angka in [2, 3, 4]:','    total += angka','print(total)'],
 'Total harus diinisialisasi sebelum loop agar tidak kembali ke 0 di tiap pengulangan. Hasil akhirnya 9.', ['Pertahankan indentasi yang terlihat pada blok.','Print tidak menjorok karena berjalan setelah loop.'],{execution:{language:'python',code:'total = 0\nfor angka in [2, 3, 4]:\n    total += angka\nprint(total)',stdout:'9'}});
order('medium','js-fix-total','javascript','Inisialisasi sebelum dipakai','Susun JavaScript dengan urutan: buat skor bernilai 0, tambah 2, kali 3, lalu cetak skor.',
 ['let skor = 0;','skor += 2;','skor *= 3;','console.log(skor);'],
 'Skor harus dibuat sebelum diubah. Urutan yang diminta menghasilkan (0 + 2) × 3 = 6.', ['Deklarasi let harus berada di awal.','Perkalian dilakukan setelah penambahan sesuai instruksi.'],{execution:{language:'javascript',code:'let skor = 0;\nskor += 2;\nskor *= 3;\nconsole.log(skor);',stdout:'6'}});
order('medium','scratch-fix','scratch','Memperbaiki akumulasi','Susun skrip agar skor berawal 0 lalu bertambah 2 sebanyak 3 kali. Tampilkan skor setelah loop, bukan di dalamnya.',
 ['Ketika bendera hijau diklik','Atur skor ke 0','Ulangi 3 kali:','    Ubah skor sebesar 2','Selesai pengulangan','Katakan nilai skor'],
 'Inisialisasi diletakkan sebelum loop dan perubahan skor di dalam loop. Pesan setelah loop menampilkan skor 6.', ['Set nilai awal cukup satu kali.','Letakkan Katakan setelah penutup pengulangan.']);
order('medium','html-nesting','html','Tag HTML bersarang','Susun HTML sesuai struktur ini: buka main, buka h1, tulis Halo, tutup h1, lalu tutup main.',
 ['<main>','  <h1>','    Halo','  </h1>','</main>'],
 'Tag yang dibuka di dalam main harus ditutup sebelum main ditutup. Teks Halo menjadi judul h1.', ['H1 berada di dalam main.','Tag yang dibuka paling akhir ditutup lebih dahulu.'],{htmlCheck:{html:'<main>\n  <h1>\n    Halo\n  </h1>\n</main>',selector:'main > h1',text:'Halo'}});

bug('medium','name','python','Nama variabel konsisten','Python ini harus mencetak nilai skor, tetapi terjadi NameError. Baris mana yang salah?',
 'skor = 5\nbonus = 2\nskor += bonus\nprint(score)',3,
 'Baris 4 memakai score yang belum didefinisikan. Ganti menjadi print(skor); hasilnya 7.', ['Bandingkan nama yang didefinisikan dengan nama yang dipakai.','Python membedakan skor dan score.'],{execution:{language:'python',code:'skor = 5\nbonus = 2\nskor += bonus\nprint(skor)',stdout:'7'},brokenError:'NameError'});
bug('medium','const','javascript','Variabel yang boleh berubah','JavaScript berikut error ketika skor diperbarui. Baris deklarasi mana yang perlu diganti agar skor dapat berubah?',
 'const skor = 1;\nskor = skor + 1;\nconsole.log(skor);',0,
 'Deklarasi pada baris 1 harus menggunakan let, karena skor akan diisi nilai baru. Const tidak mengizinkan penugasan ulang.', ['Perhatikan jenis deklarasi, bukan operasi penambahannya.','Gunakan let untuk nilai yang perlu ditugaskan ulang.'],{execution:{language:'javascript',code:'let skor = 1;\nskor = skor + 1;\nconsole.log(skor);',stdout:'2'},brokenError:'TypeError'});
bug('medium','increment','scratch','Arah perubahan nyawa','Nyawa seharusnya berkurang satu ketika sprite disentuh musuh. Baris mana yang membuat hasilnya berlawanan?',
 'Ketika menerima pesan kena musuh\nUbah nyawa sebesar 1\nKatakan nilai nyawa',1,
 'Baris 2 menambah nyawa. Ubah 1 menjadi -1 agar setiap pesan kena musuh mengurangi nyawa satu.', ['Cari instruksi yang mengubah nyawa.','Pengurangan memakai perubahan bernilai negatif.']);
bug('medium','indent','python','Indentasi blok','Pilih satu baris yang perlu ditambah indentasi agar Python ini valid dan pesan tampil hanya saat skor positif.',
 'skor = 2\nif skor > 0:\nprint("Positif")',2,
 'Baris 3 adalah isi if sehingga harus diberi indentasi, misalnya empat spasi.', ['Baris setelah if adalah isi blok kondisi.','Python tidak memakai kurung kurawal untuk menandai isi if.'],{execution:{language:'python',code:'skor = 2\nif skor > 0:\n    print("Positif")',stdout:'Positif'},brokenError:'IndentationError'});

workspace('medium','change','Perbaiki reset dalam loop','Perbaiki satu blok: target skor akhir 6. Pertahankan urutan bendera → set skor 0 → repeat 3 → say skor selama 2 detik. Di dalam repeat, ganti set skor 2 menjadi change skor by 2.',
 W(flag(),set('skor',0),repeat(3,set('skor',2)),say(V('skor'))),W(flag(),set('skor',0),repeat(3,change('skor',2)),say(V('skor'))),
 'Change menambah nilai lama, sedangkan set menimpanya. Tiga penambahan sebesar 2 menghasilkan 6.', ['Perbaiki jenis blok di dalam rongga repeat.','Jangan mengubah set skor 0 yang berada sebelum loop.']);
workspace('medium','count','Perbaiki batas perulangan','Program harus bergerak total 40 langkah. Pertahankan move 10 di dalam repeat dan pesan Selesai setelahnya. Perbaiki hanya angka pengulangan.',
 W(flag(),repeat(2,move(10)),say('Selesai')),W(flag(),repeat(4,move(10)),say('Selesai')),
 'Dibutuhkan 4 pengulangan × 10 langkah = 40 langkah. Say tetap berada di luar loop.', ['Hitung 40 dibagi 10.','Ubah nilai TIMES pada repeat, bukan nilai STEPS.']);
workspace('medium','compare','Perbaiki operator kondisi','Pesan Lulus harus tampil jika skor lebih dari 5. Nilai awal skor sudah 7. Perbaiki operator perbandingan saja; pertahankan say Lulus selama 2 detik di dalam if.',
 W(flag(),set('skor',7),condition(compare(V('skor'),'<',N(5)),say('Lulus'))),W(flag(),set('skor',7),condition(compare(V('skor'),'>',N(5)),say('Lulus'))),
 'Operator > memeriksa apakah skor lebih besar dari 5. Pada skor 7, kondisi benar dan pesan Lulus tampil.', ['Tanda pembanding menunjuk ke sisi nilai yang lebih kecil.','Ganti < menjadi > pada blok Operators.']);
workspace('medium','until','Perbaiki loop yang tidak selesai','Program repeat until hitung = 3 tidak pernah selesai. Tambahkan change hitung by 1 tepat setelah move 5 di dalam loop. Pertahankan blok lain dan nama hitung.',
 W(flag(),set('hitung',0),block('until',{}, {IF:compare(V('hitung'),'=',N(3)),DO:move(5)}),say('Selesai')),
 W(flag(),set('hitung',0),block('until',{}, {IF:compare(V('hitung'),'=',N(3)),DO:chain(move(5),change('hitung',1))}),say('Selesai')),
 'Hitung berubah dari 0 ke 1, 2, lalu 3. Setelah tiga gerakan, loop berhenti dan pesan Selesai tampil.', ['Kondisi akhir bergantung pada variabel hitung.','Perubahan hitung harus berada di dalam loop agar terjadi pada setiap pengulangan.']);

// HARD: Python/JavaScript tracing, web structure/styles, and multi-step algorithms.
choice('hard','python-alias','python','Referensi list','Python: a = [1, 2]; b = a; b.append(3); print(len(a)). Apa outputnya?',
 ['3','2','1','Error karena b bukan list'],
 'B = a membuat kedua nama menunjuk list yang sama. Menambah elemen lewat b juga terlihat lewat a, sehingga panjang a menjadi 3.', ['Penugasan b = a tidak membuat salinan list baru.','Append mengubah list yang sudah ada.'],{execution:{language:'python',code:'a = [1, 2]\nb = a\nb.append(3)\nprint(len(a))',stdout:'3'}});
choice('hard','js-strict','javascript','Kesetaraan ketat','JavaScript: console.log("5" === 5); Apa outputnya?',
 ['false','true','5','SyntaxError'],
 '=== membandingkan nilai sekaligus tipe. String "5" berbeda tipe dari angka 5, sehingga hasilnya false.', ['Perhatikan tanda petik di operand kiri.','=== tidak mengubah string menjadi number sebelum membandingkan.'],{execution:{language:'javascript',code:'console.log("5" === 5);',stdout:'false'}});
choice('hard','missing-tag','html','Tag penutup website','Lengkapi ??? agar markup <section><h2>Judul</h2><p>Halo???</section> menutup paragraf secara eksplisit.',
 ['</p>','<p>','</h2>','</div>'],
 'Paragraf dibuka dengan <p>, sehingga tag penutup eksplisit yang sesuai adalah </p>. Browser kadang memperbaiki HTML yang tidak lengkap; soal ini meminta struktur eksplisit.', ['Cari tag yang membuka teks Halo.','Tag penutup memakai garis miring sebelum nama tag.'],{htmlCheck:{html:'<section><h2>Judul</h2><p>Halo</p></section>',selector:'section > p',text:'Halo'}});
choice('hard','css-specificity','css','Prioritas selector CSS','Tanpa !important, CSS berisi p { color: blue; } lalu .pesan { color: red; }. Apa warna teks <p class="pesan">Halo</p>?',
 ['Merah','Biru','Hijau','Tidak berwarna'],
 'Selector class .pesan lebih spesifik daripada selector elemen p, sehingga deklarasi merah menang pada elemen tersebut.', ['Bandingkan selector class dengan selector elemen.','Class mempunyai prioritas spesifisitas lebih tinggi daripada nama tag.'],{htmlCheck:{html:'<style>p { color: blue; } .pesan { color: red; }</style><p class="pesan">Halo</p>',selector:'.pesan',property:'color',value:'rgb(255, 0, 0)'}});

picture('hard','python-even','python','Loop dan modulo','Apa angka yang dicetak kode Python pada gambar?',
 ['12','21','6','9'],codeImage('Python','total = 0\nfor n in range(1, 7):\n    if n % 2 == 0:\n        total += n\nprint(total)'),
 'N % 2 == 0 memilih bilangan genap. Dari 1 sampai 6, yang dijumlahkan adalah 2 + 4 + 6 = 12.', ['Range berhenti sebelum 7.','Hanya bilangan dengan sisa pembagian 2 sama dengan 0 yang ditambahkan.'],{execution:{language:'python',code:'total = 0\nfor n in range(1, 7):\n    if n % 2 == 0:\n        total += n\nprint(total)',stdout:'12'}});
picture('hard','js-map','javascript','Array dan fungsi','Apa output JavaScript pada gambar? Angka dicetak dalam satu baris.',
 ['4-6','2-3','3-4','2-3-4'],codeImage('JavaScript','const data = [1, 2, 3];\nconst hasil = data\n  .filter(n => n > 1)\n  .map(n => n * 2);\nconsole.log(hasil.join("-"));'),
 'Filter menyisakan [2, 3]. Map mengalikan masing-masing dengan 2 menjadi [4, 6]. Join menggabungkannya sebagai 4-6.', ['Jalankan filter sebelum map.','Join memakai tanda hubung di antara dua hasil.'],{execution:{language:'javascript',code:'const data = [1, 2, 3];\nconst hasil = data\n  .filter(n => n > 1)\n  .map(n => n * 2);\nconsole.log(hasil.join("-"));',stdout:'4-6'}});
picture('hard','html-heading','html','Struktur halaman','Dari HTML pada gambar, teks mana yang menjadi heading h1 di dalam main?',
 ['Belajar coding','Menu','Mulai','Semua teks adalah h1'],codeImage('HTML','<nav>Menu</nav>\n<main>\n  <h1>Belajar coding</h1>\n  <p>Mulai</p>\n</main>'),
 'Teks Belajar coding berada di antara <h1> dan </h1>. Menu berada dalam nav dan Mulai dalam p.', ['Cari pasangan tag h1.','Jangan menyamakan paragraf dengan heading.'],{htmlCheck:{html:'<nav>Menu</nav>\n<main>\n  <h1>Belajar coding</h1>\n  <p>Mulai</p>\n</main>',selector:'main > h1',text:'Belajar coding'}});
picture('hard','css-width','css','Membaca box model','Elemen menggunakan CSS pada gambar. Berapa lebar border box-nya, tanpa menghitung margin?',
 ['124 piksel','100 piksel','120 piksel','104 piksel'],codeImage('CSS','.kartu {\n  box-sizing: content-box;\n  width: 100px;\n  padding: 10px;\n  border: 2px solid black;\n}'),
 'Content-box berarti width hanya lebar isi. Total lebar = 100 + 10 + 10 padding + 2 + 2 border = 124 piksel.', ['Ada padding dan border di sisi kiri sekaligus kanan.','Jangan menambahkan margin karena tidak ada dan tidak diminta.'],{htmlCheck:{html:'<style>.kartu{box-sizing:content-box;width:100px;padding:10px;border:2px solid black;}</style><div class="kartu">Kartu</div>',selector:'.kartu',width:124}});

order('hard','python-sum','python','Fungsi dan akumulasi','Susun definisi fungsi Python jumlah(n), lalu panggil jumlah(4). Loop harus menjumlahkan 1 sampai n, return sesudah loop, dan print di luar fungsi.',
 ['def jumlah(n):','    total = 0','    for angka in range(1, n + 1):','        total += angka','    return total','print(jumlah(4))'],
 'Range(1, n + 1) menyertakan n. Return dijalankan setelah loop selesai; jumlah(4) menghasilkan 10.', ['Perhatikan tingkat indentasi fungsi dan loop.','Return ada di dalam fungsi, tetapi di luar loop.'],{execution:{language:'python',code:'def jumlah(n):\n    total = 0\n    for angka in range(1, n + 1):\n        total += angka\n    return total\nprint(jumlah(4))',stdout:'10'}});
order('hard','js-loop','javascript','Loop dan akumulator','Susun JavaScript: total dimulai 0, loop i dari 1 sampai 3, tambahkan i ke total, tutup loop, lalu cetak total.',
 ['let total = 0;','for (let i = 1; i <= 3; i++) {','  total += i;','}','console.log(total);'],
 'Total diperbarui menjadi 1, 3, lalu 6. Console.log diletakkan di luar loop sehingga hanya mencetak hasil akhir.', ['Deklarasikan total sebelum loop.','Kurung kurawal penutup harus ada sebelum console.log.'],{execution:{language:'javascript',code:'let total = 0;\nfor (let i = 1; i <= 3; i++) {\n  total += i;\n}\nconsole.log(total);',stdout:'6'}});
order('hard','html-document','html','Struktur dokumen website','Susun dokumen HTML lengkap: doctype, html, head berisi title, body berisi h1, lalu tutup html. Gunakan setiap blok sekali.',
 ['<!DOCTYPE html>','<html lang="id">','  <head><title>Latihan</title></head>','  <body><h1>Halo</h1></body>','</html>'],
 'Doctype adalah deklarasi awal. Head menyimpan metadata dan title, sedangkan body berisi konten halaman.', ['Head diletakkan sebelum body.','Html membungkus head dan body.'],{htmlCheck:{html:'<!DOCTYPE html>\n<html lang="id">\n  <head><title>Latihan</title></head>\n  <body><h1>Halo</h1></body>\n</html>',selector:'body > h1',text:'Halo'}});
order('hard','js-dom','javascript','Event dan DOM','HTML sudah memiliki <button id="mulai">Mulai</button> dan <p id="pesan"></p>. Susun JS: ambil tombol, pasang listener click, isi pesan dengan Halo di dalam listener, tutup listener.',
 ['const tombol = document.querySelector("#mulai");','tombol.addEventListener("click", () => {','  document.querySelector("#pesan").textContent = "Halo";','});'],
 'Tombol harus ditemukan sebelum listener dipasang. Pesan diubah di dalam callback sehingga baru berubah setelah tombol diklik.', ['Kode pengambilan tombol berjalan lebih dahulu.','Baris pengubah pesan harus berada di antara awal dan akhir callback.'],{htmlCheck:{html:'<button id="mulai">Mulai</button><p id="pesan"></p>',script:'const tombol = document.querySelector("#mulai");\ntombol.addEventListener("click", () => {\n  document.querySelector("#pesan").textContent = "Halo";\n});',click:'#mulai',selector:'#pesan',text:'Halo'}});

bug('hard','python-colon','python','Syntax error Python','Python berikut gagal diparse karena tanda baca pada satu baris. Baris mana yang kurang titik dua?',
 'angka = [1, 2, 3]\nfor n in angka\n    print(n)',1,
 'Baris for harus diakhiri titik dua: for n in angka:. Indentasi print sudah benar.', ['Baris pembuka loop Python memerlukan tanda baca tertentu.','Daftar dan perintah print sudah valid.'],{execution:{language:'python',code:'angka = [1, 2, 3]\nfor n in angka:\n    print(n)',stdout:'1\n2\n3'},brokenError:'SyntaxError'});
bug('hard','js-index','javascript','Indeks array','Kode seharusnya mencetak Biru, tetapi hasilnya undefined. Pada baris mana akses array melewati indeks yang tersedia?',
 'const warna = ["Merah", "Biru"];\nconst jumlah = warna.length;\nconsole.log(warna[jumlah]);',2,
 'Length adalah jumlah elemen, yaitu 2, sedangkan indeks terakhir 1. Ganti baris 3 dengan console.log(warna[jumlah - 1]);', ['Indeks array dimulai dari 0.','Indeks terakhir adalah panjang array dikurangi 1.'],{execution:{language:'javascript',code:'const warna = ["Merah", "Biru"];\nconst jumlah = warna.length;\nconsole.log(warna[jumlah - 1]);',stdout:'Biru'},brokenOutput:'undefined'});
bug('hard','html-link','html','Atribut tautan','Teks Buku tampil tetapi tidak menjadi tautan ke /buku. Baris mana yang memakai atribut tujuan yang salah?',
 '<main>\n  <a src="/buku">Buku</a>\n</main>',1,
 'Baris 2 harus menggunakan href, bukan src: <a href="/buku">Buku</a>. Atribut href menentukan tujuan tautan.', ['Periksa atribut pada tag a.','Src biasa digunakan untuk sumber gambar atau skrip, bukan tujuan anchor.'],{htmlCheck:{html:'<main>\n  <a href="/buku">Buku</a>\n</main>',selector:'main > a',attribute:'href',value:'/buku'}});
bug('hard','css-unit','css','Nilai CSS yang valid','CSS ini harus memberi lebar 240 piksel. Browser mengabaikan salah satu deklarasinya. Baris mana yang kurang satuan?',
 '.panel {\n  color: blue;\n  width: 240;\n}',2,
 'Baris 3 harus memakai width: 240px;. Lebar numerik nonnol memerlukan satuan yang sesuai.', ['Warna blue valid. Cari deklarasi ukuran.','Tambahkan px setelah angka untuk ukuran dalam piksel.'],{htmlCheck:{html:'<style>.panel{color:blue;width:240px;}</style><div class="panel">Panel</div>',selector:'.panel',width:240}});

workspace('hard','nested','Loop bersarang','Lengkapi: bendera → set total 0 → repeat 3 berisi repeat 4 berisi change total by 1 → say nilai total for 2 seconds di luar kedua loop. Gunakan dua repeat bersarang, bukan repeat 12.',
 W(flag(),set('total',0)),W(flag(),set('total',0),repeat(3,repeat(4,change('total',1))),say(V('total'))),
 'Tiga pengulangan luar × empat pengulangan dalam menambah total sebanyak 12. Susunan dua loop bersarang adalah bagian dari tugas.', ['Repeat 4 harus berada di dalam repeat 3.','Hanya change total by 1 yang berada pada loop terdalam.']);
workspace('hard','boolean','Gabungan kondisi AND','Pertahankan set skor 8 lalu set nyawa 2 setelah bendera. Tambahkan if (skor > 5) and (nyawa > 0), lalu say "Lanjut" for 2 seconds di dalam if. Urutan pembanding skor dahulu, nyawa sesudahnya.',
 W(flag(),set('skor',8),set('nyawa',2)),W(flag(),set('skor',8),set('nyawa',2),condition(block('boolean',{OP:'and'},{A:compare(V('skor'),'>',N(5)),B:compare(V('nyawa'),'>',N(0))}),say('Lanjut'))),
 'AND bernilai benar hanya jika kedua kondisi benar. Skor 8 > 5 dan nyawa 2 > 0, jadi pesan Lanjut tampil.', ['Gunakan blok and dengan dua pembanding.','Masukkan pembanding skor ke sisi kiri, pembanding nyawa ke kanan sesuai instruksi.']);
workspace('hard','sum','Menerjemahkan akumulasi Python','Terjemahkan pola total += n ke blok. Setelah bendera: set total 0 → set n 1 → repeat 4. Di dalam repeat: set total to (total + n), lalu change n by 1. Setelah loop, say total for 2 seconds. Pertahankan urutan tersebut.',
 W(flag(),set('total',0),set('n',1)),W(flag(),set('total',0),set('n',1),repeat(4,set('total',math(V('total'),'+',V('n'))),change('n',1)),say(V('total'))),
 'Nilai n yang ditambahkan adalah 1, 2, 3, dan 4, sehingga total akhir 10. N dinaikkan setelah ditambahkan ke total.', ['Masukkan blok + sebagai input VALUE pada set total.','Kiri penjumlahan adalah total dan kanan adalah n; ubah n setelah penjumlahan.']);
workspace('hard','countdown','Menerjemahkan while JavaScript','Setelah bendera dan set sisa 3, buat repeat until sisa = 0. Di dalam loop: say nilai sisa for 2 seconds, lalu change sisa by -1. Setelah loop, say "Selesai" for 2 seconds.',
 W(flag(),set('sisa',3)),W(flag(),set('sisa',3),block('until',{}, {IF:compare(V('sisa'),'=',N(0)),DO:chain(say(V('sisa')),change('sisa',-1))}),say('Selesai')),
 'Repeat until berhenti ketika sisa = 0. Pesan angkanya 3, 2, 1, lalu Selesai; angka 0 tidak dikatakan di dalam loop.', ['While sisa > 0 setara dengan mengulang sampai sisa = 0 untuk nilai awal ini.','Kurangi sisa di dalam loop agar kondisi berhenti akhirnya tercapai.']);

export const questionBank = list;
