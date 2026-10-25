-- Shared spectator presentation; existing battles keep the original duel layout.
ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS public_layout text NOT NULL DEFAULT 'center_duel'
  CHECK (public_layout IN ('center_duel', 'top_bottom', 'side_panel', 'stadium'));

NOTIFY pgrst, 'reload schema';
