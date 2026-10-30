-- Read-only inspection: never links, moves, creates, or deletes a card.
BEGIN;
CREATE OR REPLACE FUNCTION public.admin_lookup_card_rfid(p_uid text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE scan_uid text:=upper(btrim(coalesce(p_uid,'')));cards jsonb;registration jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login admin diperlukan.' USING ERRCODE='42501';END IF;
 IF length(scan_uid) NOT BETWEEN 4 AND 128 OR scan_uid~'[[:cntrl:]]' THEN RAISE EXCEPTION 'UID RFID harus 4–128 karakter tanpa karakter kontrol.';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.id),'[]') INTO cards FROM public.game_cards c WHERE upper(btrim(c.uid))=scan_uid;
 SELECT jsonb_build_object('id',r.id,'uid',r.uid,'label',r.label,'card_type',r.card_type,'is_active',r.is_active)
 INTO registration FROM public.rfid_cards r WHERE upper(btrim(r.uid))=scan_uid ORDER BY r.id LIMIT 1;
 RETURN jsonb_build_object('uid',scan_uid,'cards',cards,'registration',registration,'registered',jsonb_array_length(cards)>0 OR registration IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.admin_lookup_card_rfid(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_lookup_card_rfid(text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
