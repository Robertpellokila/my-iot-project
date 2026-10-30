-- Player and unauthenticated spectator clients need these two new display fields.
-- Answers remain in correct_answer/correct_sequence/bug_line and the private key table.
BEGIN;
GRANT SELECT (block_config,duration_seconds) ON TABLE public.coding_questions TO anon;
NOTIFY pgrst,'reload schema';
COMMIT;
