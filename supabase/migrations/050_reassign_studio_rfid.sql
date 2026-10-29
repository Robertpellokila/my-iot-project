-- UID reassignment preserves both catalog records and existing battle snapshots.
BEGIN;
CREATE OR REPLACE FUNCTION public.link_studio_card_rfid(p_game_card_id uuid,p_uid text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE source public.game_cards; existing public.game_cards; linked uuid; scan_uid text:=trim(p_uid); meta jsonb; matches integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF scan_uid IS NULL OR length(scan_uid) NOT BETWEEN 4 AND 128 OR scan_uid~'[[:cntrl:]]' THEN RAISE EXCEPTION 'UID RFID harus 4–128 karakter tanpa karakter kontrol.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('card-rfid:'||upper(scan_uid),0));
 SELECT * INTO source FROM public.game_cards WHERE id=p_game_card_id FOR SHARE;
 IF source.id IS NULL THEN RAISE EXCEPTION 'Kartu sumber sudah tidak tersedia. Pilih kartu dari Album.'; END IF;
 IF source.archived_at IS NOT NULL THEN RAISE EXCEPTION 'Pulihkan kartu sumber dari Sampah sebelum menghubungkan RFID.'; END IF;
 IF source.fusion_only THEN RAISE EXCEPTION 'Kartu Fusion dipanggil melalui resep dan tidak memakai UID RFID.'; END IF;
 SELECT count(*) INTO matches FROM public.game_cards WHERE upper(trim(uid))=upper(scan_uid);
 IF matches>1 THEN RAISE EXCEPTION 'Ada lebih dari satu kartu dengan UID yang sama. Periksa data UID di Album terlebih dahulu.'; END IF;
 SELECT * INTO existing FROM public.game_cards WHERE upper(trim(uid))=upper(scan_uid) FOR UPDATE;
 IF existing.id IS NOT NULL THEN
   IF existing.id=source.id OR existing.metadata->>'catalog_source_id'=source.id::text THEN
     RETURN jsonb_build_object('id',existing.id,'uid',existing.uid,'name',existing.name,'already_linked',true,'battle_enabled',existing.battle_enabled,'archived',existing.archived_at IS NOT NULL);
   END IF;
   RETURN jsonb_build_object('conflict',true,'uid',existing.uid,'previous_card',jsonb_build_object('id',existing.id,'name',existing.name,'card_code',existing.card_code),'target_name',source.name);
 END IF;
 meta:=(coalesce(source.metadata,'{}')-'timedoor_seed_key')||jsonb_build_object('catalog_source_id',source.id,'studio_template',false);
 IF source.metadata ? 'timedoor_seed_key' THEN meta:=meta||jsonb_build_object('catalog_source_seed_key',source.metadata->'timedoor_seed_key'); END IF;
 INSERT INTO public.game_cards(uid,card_code,name,element,hp,attack,defense,rarity,level,lore,image_url,physical_card_image_url,avatar_url,card_kind,fusion_only,physical_scan_enabled,metadata,tags,battle_enabled)
 VALUES(scan_uid,source.card_code,source.name,source.element,source.hp,source.attack,source.defense,source.rarity,source.level,source.lore,source.image_url,source.physical_card_image_url,source.avatar_url,'normal',false,true,meta,source.tags,source.battle_enabled) RETURNING id INTO linked;
 -- Imported Studio bindings are copied by migration 039's existing trigger.
 IF NOT (source.metadata ? 'studio_card') THEN
   INSERT INTO public.game_card_special_skills(game_card_id,special_skill_id,sort_order,enabled,overrides)
   SELECT linked,special_skill_id,sort_order,enabled,overrides FROM public.game_card_special_skills WHERE game_card_id=source.id;
 END IF;
 RETURN jsonb_build_object('id',linked,'uid',scan_uid,'name',source.name,'already_linked',false,'battle_enabled',source.battle_enabled);
END $$;

CREATE OR REPLACE FUNCTION public.reassign_studio_card_rfid(p_game_card_id uuid,p_uid text,p_previous_card_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE current_link jsonb; previous public.game_cards; linked jsonb; scan_uid text:=trim(p_uid);
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF p_previous_card_id IS NULL THEN RAISE EXCEPTION 'Periksa kartu asal sebelum memindahkan UID.'; END IF;
 -- Reuse the link function's auth, source availability, validation, and lock.
 current_link:=public.link_studio_card_rfid(p_game_card_id,scan_uid);
 IF NOT coalesce((current_link->>'conflict')::boolean,false) THEN
   -- A lost response may be retried. A newly free UID must not be silently
   -- claimed by a stale confirmation; undo any new copy through this error.
   IF coalesce((current_link->>'already_linked')::boolean,false) THEN RETURN current_link; END IF;
   RAISE EXCEPTION 'Hubungan UID sudah berubah. Periksa ulang sebelum memindahkan.' USING ERRCODE='40001';
 END IF;
 IF current_link#>>'{previous_card,id}' IS DISTINCT FROM p_previous_card_id::text THEN
   RAISE EXCEPTION 'UID sekarang terhubung ke kartu lain. Periksa ulang sebelum memindahkan.' USING ERRCODE='40001';
 END IF;
 SELECT * INTO previous FROM public.game_cards WHERE id=p_previous_card_id FOR UPDATE;
 UPDATE public.game_cards SET uid=NULL,physical_scan_enabled=false WHERE id=previous.id;
 linked:=public.link_studio_card_rfid(p_game_card_id,scan_uid);
 IF linked->>'id' IS NULL OR coalesce((linked->>'conflict')::boolean,false) THEN RAISE EXCEPTION 'UID belum dapat dipindahkan. Tidak ada data kartu yang diubah.'; END IF;
 RETURN linked||jsonb_build_object('transferred',true,'previous_card',jsonb_build_object('id',previous.id,'name',previous.name));
END $$;
REVOKE ALL ON FUNCTION public.link_studio_card_rfid(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.reassign_studio_card_rfid(uuid,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.link_studio_card_rfid(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reassign_studio_card_rfid(uuid,text,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
