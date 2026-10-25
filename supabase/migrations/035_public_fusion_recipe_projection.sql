-- Public Fusion recipes must follow the published Studio clone, not the
-- original catalog record that owns the battle recipe.
CREATE OR REPLACE FUNCTION public.get_landing_fusion_recipes() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  WITH published_fusion AS (
    SELECT p.id AS public_card_id, p.name, p.card_code, p.metadata
    FROM game_cards p
    WHERE p.featured_on_landing AND p.landing_active AND p.fusion_only
  ), matched_recipes AS (
    SELECT DISTINCT ON (p.public_card_id, r.id)
      p.public_card_id,
      r.id, r.name, r.code, r.is_active, r.priority
    FROM published_fusion p
    JOIN game_cards result_card ON
      lower(trim(coalesce(p.metadata#>>'{studio_card,display_code}', p.card_code))) = lower(trim(result_card.card_code))
      OR lower(trim(p.name)) = lower(trim(result_card.name))
    JOIN fusion_recipes r ON r.result_game_card_id = result_card.id
    ORDER BY p.public_card_id, r.id, r.priority NULLS LAST
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', recipe.id,
    'name', recipe.name,
    'code', recipe.code,
    'is_active', recipe.is_active,
    'priority', recipe.priority,
    'result_game_card_id', recipe.public_card_id,
    'materials', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', material.id,
        'recipe_id', recipe.id,
        'material_type', material.material_type,
        'quantity', material.quantity,
        'card_code', material.card_code,
        'card_codes', material.card_codes,
        'element', material.element,
        'tag', material.tag,
        'metadata', material.metadata
      ) ORDER BY material.sort_order, material.id)
      FROM fusion_recipe_materials material
      WHERE material.recipe_id = recipe.id
    ), '[]'::jsonb)
  ) ORDER BY recipe.priority NULLS LAST, recipe.name, recipe.id), '[]'::jsonb)
  FROM matched_recipes recipe;
$$;
REVOKE ALL ON FUNCTION public.get_landing_fusion_recipes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_landing_fusion_recipes() TO anon,authenticated;

NOTIFY pgrst, 'reload schema';
