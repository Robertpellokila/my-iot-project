-- One catalog record is the reusable design; every physical copy has its UID.
BEGIN;
CREATE OR REPLACE FUNCTION public.link_studio_card_rfid(p_game_card_id uuid,p_uid text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE source public.game_cards; existing public.game_cards; linked uuid; scan_uid text:=trim(p_uid); meta jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF scan_uid IS NULL OR length(scan_uid) NOT BETWEEN 4 AND 128 OR scan_uid~'[[:cntrl:]]' THEN RAISE EXCEPTION 'UID RFID harus 4–128 karakter tanpa karakter kontrol.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('card-rfid:'||scan_uid,0));
 SELECT * INTO source FROM public.game_cards WHERE id=p_game_card_id FOR SHARE;
 IF source.id IS NULL THEN RAISE EXCEPTION 'Kartu sumber sudah tidak tersedia. Pilih kartu dari Album.'; END IF;
 IF source.fusion_only THEN RAISE EXCEPTION 'Kartu Fusion dipanggil melalui resep dan tidak memakai UID RFID.'; END IF;
 SELECT * INTO existing FROM public.game_cards WHERE uid=scan_uid FOR UPDATE;
 IF existing.id IS NOT NULL THEN
   IF existing.id=source.id OR existing.metadata->>'catalog_source_id'=source.id::text THEN
     RETURN jsonb_build_object('id',existing.id,'uid',existing.uid,'name',existing.name,'already_linked',true);
   END IF;
   RAISE EXCEPTION 'UID ini sudah terhubung ke kartu %. Gunakan kartu RFID lain.',existing.name USING ERRCODE='23505';
 END IF;
 meta:=(coalesce(source.metadata,'{}')-'timedoor_seed_key')||jsonb_build_object('catalog_source_id',source.id,'studio_template',false);
 IF source.metadata ? 'timedoor_seed_key' THEN meta:=meta||jsonb_build_object('catalog_source_seed_key',source.metadata->'timedoor_seed_key'); END IF;
 INSERT INTO public.game_cards(uid,card_code,name,element,hp,attack,defense,rarity,level,lore,image_url,physical_card_image_url,avatar_url,card_kind,fusion_only,physical_scan_enabled,metadata,tags)
 VALUES(scan_uid,source.card_code,source.name,source.element,source.hp,source.attack,source.defense,source.rarity,source.level,source.lore,source.image_url,source.physical_card_image_url,source.avatar_url,'normal',false,true,meta,source.tags) RETURNING id INTO linked;
 -- Non-Studio legacy cards also retain all their explicit bindings. Studio
 -- copies are created by the existing atomic skill trigger (migration 037).
 IF NOT (source.metadata ? 'studio_card') THEN
   INSERT INTO public.game_card_special_skills(game_card_id,special_skill_id,sort_order,enabled,overrides)
   SELECT linked,special_skill_id,sort_order,enabled,overrides FROM public.game_card_special_skills WHERE game_card_id=source.id;
 END IF;
 RETURN jsonb_build_object('id',linked,'uid',scan_uid,'name',source.name,'already_linked',false);
END $$;
REVOKE ALL ON FUNCTION public.link_studio_card_rfid(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.link_studio_card_rfid(uuid,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
