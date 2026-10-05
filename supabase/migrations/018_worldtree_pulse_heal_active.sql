-- Configure Worldtree Pulse as a playable ally-card heal.
-- The source catalog entry had a descriptive text only and no executable effects.
DO $migration$
DECLARE
  v_skill_id uuid := 'b74adbe6-3601-4f7f-a97b-03fe7fbbd20c';
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.special_skills
    WHERE id = v_skill_id
      AND name = 'Worldtree Pulse'
  ) THEN
    RAISE EXCEPTION 'Expected Worldtree Pulse catalog skill was not found';
  END IF;

  UPDATE public.special_skills
  SET
    description = 'Sekali per battle, pulihkan 15 HP pada satu kartu Active milikmu; cooldown 3 ronde.',
    skill_type = 'active',
    activation_timing = 'main_phase',
    source_zones = ARRAY['active']::text[],
    target_spec = jsonb_build_object('type', 'ally_active', 'required', true),
    cost_spec = jsonb_build_object('type', 'none', 'value', 0),
    limits = jsonb_build_object(
      'once_per_battle', true,
      'max_uses', 1,
      'cooldown_rounds', 3
    ),
    effects = jsonb_build_array(
      jsonb_build_object(
        'type', 'heal_card',
        'target', 'target_card',
        'owner', 'self',
        'allowed_zones', jsonb_build_array('active'),
        'amount', jsonb_build_object('mode', 'fixed', 'value', 15)
      )
    ),
    consumes_turn = true,
    trigger_spec = jsonb_build_object(
      'type', 'main_phase',
      'label', 'Aktif manual pada main phase'
    ),
    catalog_status = 'active',
    metadata = (coalesce(metadata, '{}'::jsonb) - 'catalog_only')
      || jsonb_build_object('rules_status', 'active_heal_ally'),
    updated_at = now()
  WHERE id = v_skill_id;
END;
$migration$;
