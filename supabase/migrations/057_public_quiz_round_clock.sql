-- Question content and its round clock are separate reads. RLS previously
-- returned zero round rows to players, leaving the countdown without an anchor.
BEGIN;
ALTER TABLE public.battle_question_rounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read available battle quiz rounds" ON public.battle_question_rounds;
CREATE POLICY "Public can read available battle quiz rounds"
 ON public.battle_question_rounds FOR SELECT TO anon,authenticated
 USING (EXISTS (
  SELECT 1 FROM public.battle_sessions b
  WHERE b.id=battle_question_rounds.battle_id
    AND (b.status='finished' OR (
      coalesce(b.is_active,true) AND (b.active_until IS NULL OR b.active_until>now())
    ))
 ));
DROP POLICY IF EXISTS "Admins can read quiz round history" ON public.battle_question_rounds;
CREATE POLICY "Admins can read quiz round history"
 ON public.battle_question_rounds FOR SELECT TO authenticated USING (public.is_admin());
-- Clients read clocks/results; the existing authorized RPCs own every write.
REVOKE ALL ON public.battle_question_rounds FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.battle_question_rounds TO anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
