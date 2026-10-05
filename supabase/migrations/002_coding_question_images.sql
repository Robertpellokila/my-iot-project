-- Store optional public images for coding quiz questions.
ALTER TABLE IF EXISTS public.coding_questions
  ADD COLUMN IF NOT EXISTS image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'quiz-images',
  'quiz-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Quiz images are publicly viewable') THEN
    EXECUTE 'CREATE POLICY "Quiz images are publicly viewable" ON storage.objects FOR SELECT TO public USING (bucket_id = ''quiz-images'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users upload quiz images') THEN
    EXECUTE 'CREATE POLICY "Authenticated users upload quiz images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''quiz-images'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users update quiz images') THEN
    EXECUTE 'CREATE POLICY "Authenticated users update quiz images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = ''quiz-images'') WITH CHECK (bucket_id = ''quiz-images'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users delete quiz images') THEN
    EXECUTE 'CREATE POLICY "Authenticated users delete quiz images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''quiz-images'')';
  END IF;
END $$;
