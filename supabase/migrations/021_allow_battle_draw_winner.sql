-- Deck-out and round-limit resolution can end a battle in a draw.
-- Keep the persisted winner values aligned with both server resolvers.
BEGIN;

ALTER TABLE public.battle_sessions
  DROP CONSTRAINT IF EXISTS battle_sessions_winner_check;

ALTER TABLE public.battle_sessions
  ADD CONSTRAINT battle_sessions_winner_check
  CHECK (winner IS NULL OR winner IN ('p1', 'p2', 'draw'));

COMMENT ON CONSTRAINT battle_sessions_winner_check
  ON public.battle_sessions
  IS 'Winner is null while unresolved, or p1, p2, or draw when finished.';

COMMIT;
