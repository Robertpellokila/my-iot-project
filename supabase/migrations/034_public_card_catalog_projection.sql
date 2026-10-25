-- Shared public card projection: printable codes, whitelisted learning data and truthful skill availability.
CREATE OR REPLACE FUNCTION public.get_landing_cards() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT coalesce(jsonb_agg(entry ORDER BY landing_display_order,name,id),'[]'::jsonb)
  FROM (
    SELECT c.id,c.name,c.landing_display_order,
      jsonb_build_object('id',c.id,'name',c.name,'card_code',coalesce(nullif(c.metadata#>>'{studio_card,display_code}',''),c.card_code),
        'element',c.element,'rarity',c.rarity,'hp',c.hp,'attack',c.attack,'defense',c.defense,
        'image_url',c.image_url,'physical_card_image_url',c.physical_card_image_url,'lore',c.lore,
        'metadata',jsonb_strip_nulls(jsonb_build_object('learning_arc',c.metadata->'learning_arc','learning_mission',c.metadata->'learning_mission','lesson_topic',c.metadata->'lesson_topic','education_theme',c.metadata->'education_theme')),
        'fusion_only',c.fusion_only OR EXISTS(SELECT 1 FROM fusion_recipes f WHERE f.result_game_card_id=c.id),
        'landing_group',c.landing_group,'landing_display_order',c.landing_display_order,
        'skills',coalesce((SELECT jsonb_agg(safe_skill ORDER BY sort_order) FROM (
          SELECT g.sort_order,jsonb_build_object('id',s.id,'name',coalesce(g.overrides->>'name',s.name),
            'description',coalesce(g.overrides->>'description',s.description),'icon',coalesce(g.overrides->>'icon',s.icon),
            'metadata',jsonb_build_object('catalog_only',(NOT s.is_active OR coalesce((s.metadata->>'catalog_only')::boolean,false)))) safe_skill
          FROM game_card_special_skills g JOIN special_skills s ON s.id=g.special_skill_id
          WHERE g.game_card_id=c.id AND g.enabled ORDER BY g.sort_order,s.id LIMIT 2
        ) skill_rows),(SELECT jsonb_agg(jsonb_build_object('name',printed->>'name','description',printed->>'description','icon',printed->>'icon','metadata',jsonb_build_object('catalog_only',true))) FROM (SELECT value printed FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.metadata->'skills')='array' THEN c.metadata->'skills' ELSE '[]'::jsonb END) LIMIT 2) printed_skills),'[]'::jsonb)) entry
    FROM game_cards c WHERE c.featured_on_landing AND c.landing_active
  ) published;
$$;
REVOKE ALL ON FUNCTION public.get_landing_cards() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_landing_cards() TO anon,authenticated;

NOTIFY pgrst,'reload schema';

