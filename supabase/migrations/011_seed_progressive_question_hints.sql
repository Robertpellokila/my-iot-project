-- Give the seeded/legacy active question bank two progressive study hints.
-- Preserve question-specific hints authored in the admin editor.
UPDATE public.coding_questions
SET hint_1 = COALESCE(
      NULLIF(btrim(hint_1), ''),
      CASE lower(coalesce(category, 'general'))
        WHEN 'scratch' THEN 'Temukan jenis blok Scratch yang disebut: peristiwa, gerakan, tampilan, atau kontrol.'
        WHEN 'block_coding' THEN 'Perhatikan susunan blok dan perubahan nilai yang terjadi.'
        WHEN 'programming_basics' THEN 'Pisahkan nilai awal, operasi, dan hasil yang diminta.'
        WHEN 'javascript' THEN 'Telusuri kode dari baris pertama dan perhatikan nilai setiap ekspresi.'
        WHEN 'html' THEN 'Pikirkan fungsi tag dan hubungan antara tag pembuka, isi, serta penutup.'
        WHEN 'css' THEN 'Cari aturan yang mengatur elemen atau tampilan yang ditanyakan.'
        WHEN 'algorithm' THEN 'Cari masukan, langkah berulang, dan kondisi berhenti.'
        WHEN 'database' THEN 'Perhatikan tabel, kolom, dan syarat pencarian dalam pertanyaan.'
        ELSE 'Tentukan konsep utama yang sedang diuji sebelum memilih jawaban.'
      END
    ),
    hint_2 = COALESCE(
      NULLIF(btrim(hint_2), ''),
      CASE lower(coalesce(category, 'general'))
        WHEN 'scratch' THEN 'Jalankan skrip dari blok awal. Hitung setiap gerakan atau pengulangan sesuai urutannya.'
        WHEN 'block_coding' THEN 'Simulasikan program satu blok demi satu blok menggunakan nilai awal pada soal.'
        WHEN 'programming_basics' THEN 'Hitung perubahan langkah demi langkah, lalu periksa kembali hasil akhirnya.'
        WHEN 'javascript' THEN 'Evaluasi ekspresi sesuai urutan operasi, kemudian ikuti hasilnya ke baris berikutnya.'
        WHEN 'html' THEN 'Cocokkan tag dengan tujuan konten yang ingin dibuat.'
        WHEN 'css' THEN 'Terapkan aturan pada elemen sasaran, lalu cek properti yang ditanyakan.'
        WHEN 'algorithm' THEN 'Coba jalankan algoritma dengan contoh kecil sampai kondisi akhirnya tercapai.'
        WHEN 'database' THEN 'Terapkan filter terlebih dahulu, kemudian lihat baris yang memenuhi semua syarat.'
        ELSE 'Uraikan masalah menjadi langkah sederhana dan cek kembali tiap langkah.'
      END
    )
WHERE is_active = true
  AND (NULLIF(btrim(hint_1), '') IS NULL OR NULLIF(btrim(hint_2), '') IS NULL);

NOTIFY pgrst, 'reload schema';
