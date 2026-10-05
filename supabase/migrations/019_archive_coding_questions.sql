-- Keep coding questions referenced by battle history, while allowing admin
-- deletion to archive and deactivate them instead of breaking old rounds.
ALTER TABLE public.coding_questions
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS coding_questions_archived_created_idx
  ON public.coding_questions (deleted_at, created_at DESC)
  WHERE deleted_at IS NOT NULL;

COMMENT ON COLUMN public.coding_questions.deleted_at IS
  'Soft-delete timestamp. Archived questions stay available to historical battle rounds but are excluded from new question pools.';
