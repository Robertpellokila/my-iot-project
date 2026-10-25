-- OPTIONAL, review/apply explicitly. Does not change game_cards, RFID or battle.
CREATE TABLE IF NOT EXISTS public.card_generator_projects (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dataset_id text NOT NULL,
  workspace jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, dataset_id),
  CHECK (jsonb_typeof(workspace) = 'object')
);
ALTER TABLE public.card_generator_projects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.card_generator_projects FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.card_generator_projects TO authenticated;
DROP POLICY IF EXISTS "Owner manages generator projects" ON public.card_generator_projects;
CREATE POLICY "Owner manages generator projects" ON public.card_generator_projects
  FOR ALL TO authenticated USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
NOTIFY pgrst, 'reload schema';
