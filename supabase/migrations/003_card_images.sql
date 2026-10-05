-- Card artwork is resized in the browser and stored as a public optimized image (max 1 MB).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'card-images',
  'card-images',
  true,
  1048576,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Card images are publicly viewable') THEN
    EXECUTE 'CREATE POLICY "Card images are publicly viewable" ON storage.objects FOR SELECT TO public USING (bucket_id = ''card-images'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users upload card images') THEN
    EXECUTE 'CREATE POLICY "Authenticated users upload card images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''card-images'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users delete card images') THEN
    EXECUTE 'CREATE POLICY "Authenticated users delete card images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''card-images'')';
  END IF;
END $$;
