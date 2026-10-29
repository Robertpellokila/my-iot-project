-- Targeted account repair: bind F12's pilot recipe to the saved Studio card.
-- Keep the archived catalogue card and its inactive recipe unchanged.
BEGIN;
DO $repair$
DECLARE
  target public.game_cards;
  owner uuid;
  saved jsonb;
  existing public.fusion_recipes;
BEGIN
  SELECT * INTO STRICT target FROM public.game_cards
  WHERE id='9430466a-81e4-4fd9-96b9-481576421bfd' FOR UPDATE;
  IF target.archived_at IS NOT NULL OR NOT target.battle_enabled OR NOT target.fusion_only
     OR target.metadata#>>'{studio_card,source_pilot_code}' IS DISTINCT FROM 'F12'
     OR (target.hp,target.attack,target.defense) IS DISTINCT FROM (195,48,24) THEN
    RAISE EXCEPTION 'Academy Nexus changed; review the repair before applying.';
  END IF;
  SELECT * INTO existing FROM public.fusion_recipes
  WHERE result_game_card_id=target.id ORDER BY created_at LIMIT 1;
  IF existing.id IS NOT NULL THEN
    IF existing.code='studio_f12_academy_nexus' AND existing.is_active THEN RETURN; END IF;
    RAISE EXCEPTION 'Studio already has a recipe; preserve it and review manually.';
  END IF;
  SELECT e.owner_id INTO owner FROM public.card_studio_entries e
  JOIN public.profiles p ON p.id=e.owner_id AND p.role='admin'
  WHERE e.game_card_id=target.id LIMIT 1;
  IF owner IS NULL THEN RAISE EXCEPTION 'Studio admin owner missing.'; END IF;
  PERFORM set_config('request.jwt.claim.sub',owner::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated')::text,true);
  saved:=public.save_studio_fusion_recipe(target.id,jsonb_build_object(
    'code','studio_f12_academy_nexus','name','ACADEMY NEXUS Fusion','icon','🧬',
    'description','Gabungkan COB-008, TOC-008, dan OTT-008 dari Active atau Bench menjadi Academy Nexus.',
    'is_active',true,'consumes_turn',false,'result_zone','active','material_destination','graveyard',
    'limits',jsonb_build_object('once_per_battle',true,'max_uses',1),
    'result_stat_spec',jsonb_build_object(
      'hp',jsonb_build_object('mode','fixed','value',target.hp),
      'attack',jsonb_build_object('mode','fixed','value',target.attack),
      'defense',jsonb_build_object('mode','fixed','value',target.defense)
    )
  ),'[
    {"material_type":"exact_card","card_code":"COB_008","quantity":1,"allowed_zones":["active","bench"]},
    {"material_type":"exact_card","card_code":"TOC_008","quantity":1,"allowed_zones":["active","bench"]},
    {"material_type":"exact_card","card_code":"OTT_008","quantity":1,"allowed_zones":["active","bench"]}
  ]'::jsonb);
  IF saved#>>'{recipe,result_game_card_id}' IS DISTINCT FROM target.id::text
     OR jsonb_array_length(saved->'materials')<>3 THEN
    RAISE EXCEPTION 'Recipe save did not return the expected target/materials.';
  END IF;
END $repair$;
COMMIT;
