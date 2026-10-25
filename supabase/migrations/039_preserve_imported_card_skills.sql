-- Opening a pre-Studio registered card in the unified editor must preserve its
-- existing explicit skill bindings instead of creating two extra template skills.
BEGIN;
CREATE OR REPLACE FUNCTION public.tcg_prepare_registered_studio_import()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NOT (coalesce(OLD.metadata,'{}') ? 'studio_card') AND NEW.metadata ? 'studio_card'
 AND EXISTS(SELECT 1 FROM game_card_special_skills WHERE game_card_id=OLD.id) THEN
   NEW.metadata:=NEW.metadata||'{"studio_legacy_bindings":true}'::jsonb;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tbc_prepare_registered_studio_import ON public.game_cards;
CREATE TRIGGER tbc_prepare_registered_studio_import BEFORE UPDATE OF metadata ON public.game_cards
 FOR EACH ROW EXECUTE FUNCTION public.tcg_prepare_registered_studio_import();

CREATE OR REPLACE FUNCTION public.tcg_studio_card_saved() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE item record; printed jsonb; previous jsonb; next_icon text; previous_icon text;
BEGIN
 -- The unified editor explicitly synchronizes printed presentation. Only
 -- changed name/description/icon fields are applied; effects and limits remain
 -- authoritative. Older clients without this flag cannot overwrite overrides.
 IF TG_OP='UPDATE' AND NEW.metadata#>>'{studio_card,sync_skill_presentation}'='true' THEN
   FOR item IN SELECT s.id,l.sort_order FROM game_card_special_skills l JOIN special_skills s ON s.id=l.special_skill_id
     WHERE l.game_card_id=NEW.id AND l.sort_order IN (1,2) AND (s.metadata->>'studio_customized'='true' OR NEW.metadata->>'studio_legacy_bindings'='true') LOOP
     printed:=NEW.metadata#>ARRAY['studio_card','skills',(item.sort_order-1)::text];
     previous:=OLD.metadata#>ARRAY['studio_card','skills',(item.sort_order-1)::text];
     next_icon:=NEW.metadata#>>ARRAY['studio_artwork','skill_icons',(item.sort_order-1)::text,'url'];
     previous_icon:=OLD.metadata#>>ARRAY['studio_artwork','skill_icons',(item.sort_order-1)::text,'url'];
     IF printed IS NOT NULL THEN
       UPDATE special_skills SET
         name=CASE WHEN printed->>'name' IS DISTINCT FROM previous->>'name' THEN coalesce(nullif(trim(printed->>'name'),''),name) ELSE name END,
         description=CASE WHEN printed->>'description' IS DISTINCT FROM previous->>'description' THEN printed->>'description' ELSE description END,
         icon=CASE WHEN next_icon IS DISTINCT FROM previous_icon THEN next_icon ELSE special_skills.icon END
       WHERE id=item.id AND (printed->>'name' IS DISTINCT FROM previous->>'name' OR printed->>'description' IS DISTINCT FROM previous->>'description' OR next_icon IS DISTINCT FROM previous_icon);
     END IF;
   END LOOP;
 END IF;
 IF NEW.metadata->>'studio_legacy_bindings'='true' THEN
   IF TG_OP='INSERT' AND NEW.metadata->>'catalog_source_id' IS NOT NULL THEN
     INSERT INTO game_card_special_skills(game_card_id,special_skill_id,sort_order,enabled,overrides)
     SELECT NEW.id,special_skill_id,sort_order,enabled,overrides FROM game_card_special_skills
     WHERE game_card_id::text=NEW.metadata->>'catalog_source_id'
     ON CONFLICT(game_card_id,special_skill_id) DO NOTHING;
   END IF;
 ELSIF jsonb_typeof(NEW.metadata#>'{studio_card,skills}')='array' THEN
   PERFORM public.sync_studio_battle_skills(NEW.id,NEW.metadata#>'{studio_card,skills}',NEW.metadata->'studio_artwork');
 END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.sync_card_studio_battle_skills(p_dataset text,p_card_keys text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE owner uuid:=auth.uid(); c record; n integer:=0; total integer:=0;
BEGIN
 IF owner IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 FOR c IN SELECT g.id,g.metadata FROM card_studio_entries e JOIN game_cards g ON g.id=e.game_card_id WHERE e.owner_id=owner AND e.dataset_id=p_dataset AND (p_card_keys IS NULL OR e.card_key=ANY(p_card_keys)) LOOP
   IF c.metadata->>'studio_legacy_bindings'='true' THEN
     n:=n+least(2,(SELECT count(*) FROM game_card_special_skills l JOIN special_skills s ON s.id=l.special_skill_id WHERE l.game_card_id=c.id AND l.enabled AND s.is_active AND s.catalog_status='active'));
   ELSE
     n:=n+public.sync_studio_battle_skills(c.id,c.metadata#>'{studio_card,skills}',c.metadata->'studio_artwork');
   END IF;
   total:=total+2;
 END LOOP;
 RETURN jsonb_build_object('synced_slots',n,'pending_slots',greatest(0,total-n));
END $$;
REVOKE ALL ON FUNCTION public.tcg_prepare_registered_studio_import() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tcg_studio_card_saved() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sync_card_studio_battle_skills(text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sync_card_studio_battle_skills(text,text[]) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
