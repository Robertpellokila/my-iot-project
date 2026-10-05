-- Allow optimized card cover uploads while keeping compatibility with existing clients.
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::text[],
    file_size_limit = 1048576
WHERE id = 'card-images';
