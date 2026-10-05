-- Skill lifecycle, rule completeness, immutable revisions, and playtest notes.
-- Apply with `supabase db query --linked --file ...` for this project until
-- the pre-existing migration history has been reconciled.
BEGIN;

ALTER TABLE public.special_skills
  ADD COLUMN IF NOT EXISTS catalog_status text NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS trigger_spec jsonb NOT NULL DEFAULT '{"type":"main_phase"}'::jsonb,
  ADD COLUMN IF NOT EXISTS skill_version integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS change_note text;

ALTER TABLE public.special_skills
  ALTER COLUMN catalog_status SET DEFAULT 'draft';

UPDATE public.special_skills
SET catalog_status = CASE
      WHEN is_active AND coalesce(metadata ->> 'catalog_only', 'false') <> 'true' THEN 'active'
      ELSE 'draft'
    END,
    trigger_spec = CASE
      WHEN trigger_spec = '{}'::jsonb THEN jsonb_build_object(
        'type', coalesce(nullif(activation_timing, ''), 'main_phase')
      )
      ELSE trigger_spec
    END,
    skill_version = greatest(coalesce(skill_version, 1), 1),
    is_active = is_active AND coalesce(metadata ->> 'catalog_only', 'false') <> 'true';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.special_skills'::regclass
      AND conname = 'special_skills_catalog_status_check'
  ) THEN
    ALTER TABLE public.special_skills
      ADD CONSTRAINT special_skills_catalog_status_check
      CHECK (catalog_status IN ('draft', 'playtest', 'active', 'archived'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.special_skills'::regclass
      AND conname = 'special_skills_trigger_spec_object_check'
  ) THEN
    ALTER TABLE public.special_skills
      ADD CONSTRAINT special_skills_trigger_spec_object_check
      CHECK (jsonb_typeof(trigger_spec) = 'object');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.special_skills'::regclass
      AND conname = 'special_skills_version_positive_check'
  ) THEN
    ALTER TABLE public.special_skills
      ADD CONSTRAINT special_skills_version_positive_check
      CHECK (skill_version > 0);
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.special_skill_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  special_skill_id uuid NOT NULL REFERENCES public.special_skills(id) ON DELETE CASCADE,
  skill_version integer NOT NULL CHECK (skill_version > 0),
  change_note text,
  snapshot jsonb NOT NULL,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (special_skill_id, skill_version)
);

CREATE INDEX IF NOT EXISTS special_skill_revisions_skill_created_idx
  ON public.special_skill_revisions (special_skill_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.special_skill_playtest_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  special_skill_id uuid NOT NULL REFERENCES public.special_skills(id) ON DELETE CASCADE,
  skill_version integer NOT NULL CHECK (skill_version > 0),
  outcome text NOT NULL CHECK (outcome IN ('pass', 'needs_changes', 'fail', 'observation')),
  scenario text,
  observed_result text,
  change_summary text,
  battle_id uuid REFERENCES public.battle_sessions(id) ON DELETE SET NULL,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS special_skill_playtest_logs_skill_created_idx
  ON public.special_skill_playtest_logs (special_skill_id, created_at DESC);

ALTER TABLE public.special_skill_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.special_skill_playtest_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage skill revisions" ON public.special_skill_revisions;
CREATE POLICY "Admins manage skill revisions"
  ON public.special_skill_revisions
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage skill playtest logs" ON public.special_skill_playtest_logs;
CREATE POLICY "Admins manage skill playtest logs"
  ON public.special_skill_playtest_logs
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.tcg_prepare_special_skill_catalog_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_missing text[] := ARRAY[]::text[];
BEGIN
  NEW.catalog_status := lower(trim(coalesce(NEW.catalog_status, 'draft')));
  NEW.trigger_spec := coalesce(NEW.trigger_spec, '{}'::jsonb);
  NEW.skill_version := greatest(coalesce(NEW.skill_version, 1), 1);
  NEW.updated_at := now();

  IF TG_OP = 'UPDATE' THEN
    IF ROW(
      NEW.code, NEW.name, NEW.description, NEW.icon, NEW.category,
      NEW.skill_type, NEW.activation_timing, NEW.source_zones,
      NEW.target_spec, NEW.cost_spec, NEW.limits, NEW.effects,
      NEW.consumes_turn, NEW.priority, NEW.catalog_status, NEW.trigger_spec
    ) IS DISTINCT FROM ROW(
      OLD.code, OLD.name, OLD.description, OLD.icon, OLD.category,
      OLD.skill_type, OLD.activation_timing, OLD.source_zones,
      OLD.target_spec, OLD.cost_spec, OLD.limits, OLD.effects,
      OLD.consumes_turn, OLD.priority, OLD.catalog_status, OLD.trigger_spec
    ) THEN
      NEW.skill_version := OLD.skill_version + 1;
    ELSE
      NEW.skill_version := OLD.skill_version;
    END IF;
  END IF;

  IF NEW.catalog_status <> 'active' THEN
    NEW.is_active := false;
    RETURN NEW;
  END IF;

  IF coalesce(NEW.trigger_spec ->> 'type', '') <> 'main_phase' THEN
    v_missing := array_append(v_missing, 'Pemicu main phase belum dipilih; pemicu otomatis belum didukung battle.');
  END IF;
  IF coalesce(NEW.skill_type, '') <> 'active' THEN
    v_missing := array_append(v_missing, 'Battle saat ini hanya menjalankan skill aktif manual.');
  END IF;
  IF coalesce(
    NEW.target_spec ->> 'type',
    NEW.target_spec ->> 'target',
    NEW.target_spec ->> 'mode',
    ''
  ) = '' THEN
    v_missing := array_append(v_missing, 'Target skill belum lengkap.');
  END IF;
  IF coalesce(NEW.cost_spec ->> 'type', '') = '' THEN
    v_missing := array_append(v_missing, 'Biaya skill belum lengkap.');
  END IF;
  IF jsonb_typeof(NEW.effects) <> 'array'
     OR jsonb_array_length(CASE WHEN jsonb_typeof(NEW.effects) = 'array' THEN NEW.effects ELSE '[]'::jsonb END) = 0
     OR EXISTS (
       SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(NEW.effects) = 'array' THEN NEW.effects ELSE '[]'::jsonb END) AS entries(effect)
       WHERE coalesce(effect ->> 'type', '') = ''
     ) THEN
    v_missing := array_append(v_missing, 'Efek skill belum memiliki hasil yang dapat dijalankan.');
  END IF;
  IF jsonb_typeof(NEW.effects) = 'array'
     AND EXISTS (
       SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(NEW.effects) = 'array' THEN NEW.effects ELSE '[]'::jsonb END) AS entries(effect)
       WHERE effect ->> 'type' = 'add_status'
         AND CASE
           WHEN coalesce(effect ->> 'duration_turns', '') ~ '^-?[0-9]+$'
             THEN (effect ->> 'duration_turns')::integer < 1
           ELSE true
         END
     ) THEN
    v_missing := array_append(v_missing, 'Durasi status harus minimal satu turn.');
  END IF;

  IF cardinality(v_missing) > 0 THEN
    RAISE EXCEPTION 'Skill belum siap diaktifkan: %', array_to_string(v_missing, ' ')
      USING ERRCODE = 'check_violation';
  END IF;

  NEW.is_active := true;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.tcg_record_special_skill_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_snapshot jsonb;
  v_note text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.skill_version = OLD.skill_version THEN
    RETURN NEW;
  END IF;

  v_snapshot := jsonb_build_object(
    'code', NEW.code,
    'name', NEW.name,
    'description', NEW.description,
    'icon', NEW.icon,
    'category', NEW.category,
    'skill_type', NEW.skill_type,
    'activation_timing', NEW.activation_timing,
    'trigger_spec', NEW.trigger_spec,
    'source_zones', NEW.source_zones,
    'target_spec', NEW.target_spec,
    'cost_spec', NEW.cost_spec,
    'limits', NEW.limits,
    'effects', NEW.effects,
    'consumes_turn', NEW.consumes_turn,
    'priority', NEW.priority,
    'catalog_status', NEW.catalog_status,
    'is_active', NEW.is_active,
    'metadata', NEW.metadata
  );
  v_note := nullif(trim(coalesce(NEW.change_note, '')), '');
  IF v_note IS NULL THEN
    v_note := CASE WHEN TG_OP = 'INSERT' THEN 'Skill dibuat' ELSE 'Perubahan skill disimpan' END;
  END IF;

  INSERT INTO public.special_skill_revisions (
    special_skill_id, skill_version, change_note, snapshot, changed_by
  ) VALUES (
    NEW.id, NEW.skill_version, v_note, v_snapshot, auth.uid()
  )
  ON CONFLICT (special_skill_id, skill_version) DO NOTHING;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS tcg_prepare_special_skill_catalog_write_trigger
  ON public.special_skills;
CREATE TRIGGER tcg_prepare_special_skill_catalog_write_trigger
  BEFORE INSERT OR UPDATE ON public.special_skills
  FOR EACH ROW EXECUTE FUNCTION public.tcg_prepare_special_skill_catalog_write();

DROP TRIGGER IF EXISTS tcg_record_special_skill_revision_trigger
  ON public.special_skills;
CREATE TRIGGER tcg_record_special_skill_revision_trigger
  AFTER INSERT OR UPDATE ON public.special_skills
  FOR EACH ROW EXECUTE FUNCTION public.tcg_record_special_skill_revision();

INSERT INTO public.special_skill_revisions (
  special_skill_id, skill_version, change_note, snapshot
)
SELECT
  skill.id,
  skill.skill_version,
  'Versi awal sebelum workflow katalog skill',
  jsonb_build_object(
    'code', skill.code,
    'name', skill.name,
    'description', skill.description,
    'icon', skill.icon,
    'category', skill.category,
    'skill_type', skill.skill_type,
    'activation_timing', skill.activation_timing,
    'trigger_spec', skill.trigger_spec,
    'source_zones', skill.source_zones,
    'target_spec', skill.target_spec,
    'cost_spec', skill.cost_spec,
    'limits', skill.limits,
    'effects', skill.effects,
    'consumes_turn', skill.consumes_turn,
    'priority', skill.priority,
    'catalog_status', skill.catalog_status,
    'is_active', skill.is_active,
    'metadata', skill.metadata
  )
FROM public.special_skills skill
ON CONFLICT (special_skill_id, skill_version) DO NOTHING;

COMMIT;
