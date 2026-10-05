-- Fix the seeded find-the-bug question: SQL string escapes had been stored as
-- literal backslash-n characters, and its generic if/else diagram was unrelated.
UPDATE public.coding_questions
SET question = 'Baris mana yang menambahkan 2 poin ke skor saat koin diterima?',
    image_url = '/images/questions/score-increment.svg',
    code_snippet = E'when I receive coin\nchange score by 1\nchange score by 2\nsay score',
    explanation = 'Baris "change score by 2" menambahkan dua poin pada variabel score setiap kali blok tersebut dijalankan.',
    hint_1 = 'Cari perintah yang mengubah variabel score.',
    hint_2 = 'Bandingkan angka setelah "change score by" pada setiap baris.'
WHERE id = '3e41c09d-1a15-5628-aa58-c78f2ad6f29b'
  AND question_type = 'find_bug';
