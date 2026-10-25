-- Opt-in publishing. Existing card content and battle rules are unchanged.
ALTER TABLE public.game_cards
  ADD COLUMN IF NOT EXISTS featured_on_landing boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS landing_display_order integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS landing_group text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS landing_active boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.tcg_guard_landing_settings() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF (TG_OP='INSERT' AND (NEW.featured_on_landing OR NEW.landing_display_order<>0 OR NEW.landing_group<>'' OR NOT NEW.landing_active))
     OR (TG_OP='UPDATE' AND (NEW.featured_on_landing,NEW.landing_display_order,NEW.landing_group,NEW.landing_active)
       IS DISTINCT FROM (OLD.featured_on_landing,OLD.landing_display_order,OLD.landing_group,OLD.landing_active)) THEN
    IF NOT public.is_admin() AND coalesce(auth.role(),'')<>'service_role' AND NOT (session_user IN ('postgres','supabase_admin') AND auth.role() IS NULL) THEN
      RAISE EXCEPTION 'Only administrators can publish cards';
    END IF;
  END IF;
  IF abs(NEW.landing_display_order::bigint)>100000 OR length(NEW.landing_group)>80 THEN
    RAISE EXCEPTION 'Invalid showcase order or group';
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS guard_landing_settings ON public.game_cards;
CREATE TRIGGER guard_landing_settings BEFORE INSERT OR UPDATE ON public.game_cards
FOR EACH ROW EXECUTE FUNCTION public.tcg_guard_landing_settings();
REVOKE ALL ON FUNCTION public.tcg_guard_landing_settings() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.get_landing_cards() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT coalesce(jsonb_agg(entry ORDER BY landing_display_order,name,id),'[]'::jsonb)
  FROM (
    SELECT c.id,c.name,c.landing_display_order,
      jsonb_build_object('id',c.id,'name',c.name,'card_code',c.card_code,
        'element',c.element,'rarity',c.rarity,'hp',c.hp,'attack',c.attack,'defense',c.defense,
        'image_url',c.image_url,'physical_card_image_url',c.physical_card_image_url,'lore',c.lore,
        'fusion_only',c.fusion_only OR EXISTS(SELECT 1 FROM fusion_recipes f WHERE f.result_game_card_id=c.id),
        'landing_group',c.landing_group,'landing_display_order',c.landing_display_order,
        'skills',coalesce((SELECT jsonb_agg(safe_skill ORDER BY sort_order) FROM (
          SELECT g.sort_order,jsonb_build_object('id',s.id,'name',coalesce(g.overrides->>'name',s.name),
            'description',coalesce(g.overrides->>'description',s.description),'icon',coalesce(g.overrides->>'icon',s.icon),
            'metadata',jsonb_build_object('catalog_only',coalesce((s.metadata->>'catalog_only')::boolean,false))) safe_skill
          FROM game_card_special_skills g JOIN special_skills s ON s.id=g.special_skill_id
          WHERE g.game_card_id=c.id AND g.enabled ORDER BY g.sort_order,s.id LIMIT 2
        ) skill_rows),'[]'::jsonb)) entry
    FROM game_cards c WHERE c.featured_on_landing AND c.landing_active
  ) published;
$$;
REVOKE ALL ON FUNCTION public.get_landing_cards() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_landing_cards() TO anon,authenticated;
