-- Keep answer keys available to server-side SECURITY DEFINER RPCs and admins,
-- but never expose them through the public player REST role.
DO $$
DECLARE
  v_column record;
BEGIN
  FOR v_column IN
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'coding_questions'
  LOOP
    EXECUTE format(
      'REVOKE SELECT (%I) ON TABLE public.coding_questions FROM PUBLIC, anon',
      v_column.column_name
    );
  END LOOP;
END;
$$;

REVOKE SELECT ON TABLE public.coding_questions FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.coding_questions TO authenticated;
GRANT SELECT (
  id, question, image_url,
  option_a, option_b, option_c, option_d,
  explanation, category, difficulty, level, is_active,
  question_type, blocks, code_snippet, hint_1, hint_2,
  learning_topic, learning_url
) ON TABLE public.coding_questions TO anon;

-- Player sessions use the anon role and receive only active question rows.
-- Logged-in administrators retain their separate is_admin() read policy.
DROP POLICY IF EXISTS "Authenticated can read active questions"
  ON public.coding_questions;

NOTIFY pgrst, 'reload schema';
