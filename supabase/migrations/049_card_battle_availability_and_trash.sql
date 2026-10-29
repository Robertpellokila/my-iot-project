BEGIN;
ALTER TABLE public.game_cards ADD COLUMN battle_enabled boolean NOT NULL DEFAULT true,
 ADD COLUMN archived_at timestamptz,ADD COLUMN availability_version integer NOT NULL DEFAULT 1;
ALTER TABLE public.game_cards ADD CONSTRAINT archived_cards_not_available CHECK(archived_at IS NULL OR (NOT battle_enabled AND NOT featured_on_landing AND NOT landing_active));
-- Archived rows are visible only to admins; battle engines retain snapshot access.
ALTER POLICY "Enable read access for all users" ON public.game_cards USING(archived_at IS NULL OR public.is_admin());
-- Card management is a teacher/admin operation; public catalogue reads remain available.
DROP POLICY IF EXISTS "Enable insert access for all users" ON public.game_cards;
DROP POLICY IF EXISTS "Enable update access for all users" ON public.game_cards;
CREATE POLICY game_card_admin_insert ON public.game_cards FOR INSERT TO authenticated WITH CHECK(public.is_admin());
CREATE POLICY game_card_admin_update ON public.game_cards FOR UPDATE TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin());
-- A physical copy also respects the reusable source card's availability.
CREATE FUNCTION public.tcg_card_battle_available(p_card uuid) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.game_cards;current_id uuid:=p_card;visited uuid[]:='{}';parent text;
BEGIN
 LOOP
  IF current_id IS NULL OR current_id=ANY(visited) OR cardinality(visited)>=32 THEN RETURN false;END IF;
  visited:=array_append(visited,current_id);
  SELECT * INTO c FROM public.game_cards WHERE id=current_id;
  IF c.id IS NULL OR c.archived_at IS NOT NULL OR NOT c.battle_enabled THEN RETURN false;END IF;
  parent:=nullif(c.metadata->>'catalog_source_id','');IF parent IS NULL THEN RETURN true;END IF;
  current_id:=public.tcg_try_uuid(parent);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.tcg_card_battle_available(uuid) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.manage_game_card(p_game_card_id uuid,p_action text,p_expected_version integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.game_cards;already boolean;parent text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login admin diperlukan.' USING ERRCODE='42501';END IF;
 IF coalesce(p_action,'') NOT IN ('enable','disable','archive','restore') THEN RAISE EXCEPTION 'Aksi kartu tidak valid.';END IF;
 SELECT * INTO c FROM public.game_cards WHERE id=p_game_card_id FOR UPDATE;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Kartu tidak ditemukan. Muat ulang Album.';END IF;
 IF p_action='enable' THEN
  IF c.archived_at IS NOT NULL THEN RAISE EXCEPTION 'Pulihkan kartu dari Sampah terlebih dahulu.';END IF;
  parent:=nullif(c.metadata->>'catalog_source_id','');
  IF parent IS NOT NULL AND NOT public.tcg_card_battle_available(public.tcg_try_uuid(parent)) THEN RAISE EXCEPTION 'Aktifkan atau pulihkan kartu sumbernya terlebih dahulu di Album.';END IF;
 END IF;
 already:=CASE p_action WHEN 'archive' THEN c.archived_at IS NOT NULL WHEN 'restore' THEN c.archived_at IS NULL WHEN 'enable' THEN c.battle_enabled ELSE NOT c.battle_enabled END;
 IF already THEN RETURN jsonb_build_object('ok',true,'card',to_jsonb(c),'already_applied',true);END IF;
 IF p_expected_version IS DISTINCT FROM c.availability_version THEN RAISE EXCEPTION 'Status kartu sudah berubah. Refresh Album lalu coba lagi.' USING ERRCODE='40001';END IF;
 UPDATE public.game_cards SET
  battle_enabled=CASE WHEN p_action='enable' THEN true ELSE false END,
  archived_at=CASE p_action WHEN 'archive' THEN clock_timestamp() WHEN 'restore' THEN NULL ELSE archived_at END,
  featured_on_landing=CASE WHEN p_action IN ('archive','restore') THEN false ELSE featured_on_landing END,
  landing_active=CASE WHEN p_action IN ('archive','restore') THEN false ELSE landing_active END,
  availability_version=availability_version+1 WHERE id=c.id RETURNING * INTO c;
 RETURN jsonb_build_object('ok',true,'card',to_jsonb(c));
END $$;
REVOKE ALL ON FUNCTION public.manage_game_card(uuid,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.manage_game_card(uuid,text,integer) TO authenticated;
-- Existing field/bench/graveyard snapshots keep their rules. Only new entries
-- are gated, for both Classic and TCG, including all summon/Fusion code paths.
CREATE FUNCTION public.tcg_guard_card_battle_entry() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE current_id uuid:=coalesce(NEW.game_card_id,NEW.card_id);visited uuid[]:='{}';c public.game_cards;parent text;
BEGIN
 IF current_id IS NULL THEN RETURN NEW;END IF;
 LOOP
  IF current_id IS NULL OR current_id=ANY(visited) OR cardinality(visited)>=32 THEN RAISE EXCEPTION 'Sumber kartu tidak tersedia untuk battle.';END IF;
  visited:=array_append(visited,current_id);
  SELECT * INTO c FROM public.game_cards WHERE id=current_id FOR SHARE;
  IF c.id IS NULL OR c.archived_at IS NOT NULL OR NOT c.battle_enabled THEN RAISE EXCEPTION 'Kartu nonaktif atau berada di Sampah. Pilih kartu lain atau minta admin mengaktifkannya.';END IF;
  parent:=nullif(c.metadata->>'catalog_source_id','');IF parent IS NULL THEN RETURN NEW;END IF;
  current_id:=public.tcg_try_uuid(parent);
 END LOOP;
END $$;
CREATE TRIGGER zzz_guard_card_battle_entry BEFORE INSERT ON public.battle_cards FOR EACH ROW EXECUTE FUNCTION public.tcg_guard_card_battle_entry();
REVOKE ALL ON FUNCTION public.tcg_guard_card_battle_entry() FROM PUBLIC,anon,authenticated;
-- Reuse the current scanner, AP/cooldown engine, matcher and save logic.
DO $patch$ DECLARE s text;needle text; BEGIN
 s:=pg_get_functiondef('public.process_multiplayer_rfid_scan(text,text)'::regprocedure);
 s:=regexp_replace(s,'(?i)(begin[[:space:]]+)',E'\\1 IF EXISTS(SELECT 1 FROM public.game_cards c WHERE upper(trim(c.uid))=upper(trim(p_uid)) AND NOT public.tcg_card_battle_available(c.id)) THEN RETURN jsonb_build_object(''ok'',false,''code'',''CARD_BATTLE_DISABLED'',''message'',''Kartu nonaktif atau berada di Sampah. Gunakan kartu lain atau batalkan Summon.'');END IF;\n');EXECUTE s;
 s:=pg_get_functiondef('public.get_player_fusions(text,text,text)'::regprocedure);
 IF strpos(s,'where fr.is_active = true')=0 THEN RAISE EXCEPTION 'Unexpected Fusion listing definition';END IF;
 s:=replace(s,'where fr.is_active = true','where fr.is_active = true AND public.tcg_card_battle_available(fr.result_game_card_id)');EXECUTE s;
 s:=pg_get_functiondef('public.tcg_match_fusion_recipe(uuid,text,uuid)'::regprocedure);
 needle:=E'  if not coalesce(\n    v_result_card.fusion_only,';
 -- Insert after the result-card lookup and NOT FOUND guard, before Fusion type validation.
 IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unexpected Fusion matcher definition';END IF;
 s:=overlay(s placing E'  IF NOT public.tcg_card_battle_available(v_result_card.id) THEN RETURN jsonb_build_object(''ok'',false,''available'',false,''message'',''Kartu hasil Fusion nonaktif atau berada di Sampah.'');END IF;\n' from strpos(s,needle) for 0);EXECUTE s;
 s:=pg_get_functiondef('public.get_landing_cards()'::regprocedure);
 IF strpos(s,'WHERE c.featured_on_landing AND c.landing_active')=0 THEN RAISE EXCEPTION 'Unexpected public catalogue definition';END IF;
 s:=replace(s,'WHERE c.featured_on_landing AND c.landing_active','WHERE c.featured_on_landing AND c.landing_active AND c.archived_at IS NULL');EXECUTE s;
 s:=pg_get_functiondef('public.link_studio_card_rfid(uuid,text)'::regprocedure);
 needle:=' IF source.fusion_only THEN';
 IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unexpected RFID link definition';END IF;
 -- Disabled sources may still prepare RFID copies; archived sources must be restored first.
 s:=replace(s,needle,E' IF source.archived_at IS NOT NULL THEN RAISE EXCEPTION ''Pulihkan kartu sumber dari Sampah sebelum menghubungkan RFID.'';END IF;\n'||needle);
 -- New copies inherit the source's explicit battle status.
 s:=replace(s,'card_kind,fusion_only,physical_scan_enabled,metadata,tags)','card_kind,fusion_only,physical_scan_enabled,metadata,tags,battle_enabled)');
 s:=replace(s,'true,meta,source.tags) RETURNING','true,meta,source.tags,source.battle_enabled) RETURNING');EXECUTE s;
 s:=pg_get_functiondef('public.save_card_studio(text,jsonb,jsonb)'::regprocedure);
 needle:='   IF existing.uid IS NOT NULL';
 IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unexpected Studio save definition';END IF;
 s:=replace(s,needle,E'   IF existing.archived_at IS NOT NULL THEN RAISE EXCEPTION ''Kartu berada di Sampah. Pulihkan dari Album sebelum menyimpan kembali.'';END IF;\n'||needle);EXECUTE s;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
