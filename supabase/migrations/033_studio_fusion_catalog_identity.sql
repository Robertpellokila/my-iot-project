-- Keep saved Studio Fusions separate from existing recipe templates.
CREATE OR REPLACE FUNCTION public.save_card_studio(p_dataset text,p_workspace jsonb,p_entries jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE owner uuid:=auth.uid(); item jsonb; card jsonb; art jsonb; key text; gid uuid; source_id uuid;
 existing public.game_cards%rowtype; meta jsonb; code text; label text; result jsonb:='[]';
BEGIN
 IF owner IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF p_dataset IS NULL OR length(p_dataset)>100 OR jsonb_typeof(p_workspace) IS DISTINCT FROM 'object'
 OR p_workspace->>'dataset_id' IS DISTINCT FROM p_dataset OR jsonb_typeof(p_entries) IS DISTINCT FROM 'array'
 OR jsonb_array_length(p_entries) NOT BETWEEN 1 AND 242 OR octet_length(p_workspace::text)>4000000 THEN
  RAISE EXCEPTION 'Workspace atau pilihan kartu tidak valid.';
 END IF;
 -- Serialize saves by account/dataset before changing any catalog projections.
 PERFORM pg_advisory_xact_lock(hashtextextended(owner::text||':'||p_dataset,0));
 FOR item IN SELECT value FROM jsonb_array_elements(p_entries) LOOP
  card:=item->'card';art:=coalesce(item->'artwork','{}');key:=item->>'key';
  IF key IS NULL OR length(key)>80 OR key IS DISTINCT FROM card->>'card_code'
  OR jsonb_typeof(card) IS DISTINCT FROM 'object' OR jsonb_typeof(art) IS DISTINCT FROM 'object'
  OR length(trim(coalesce(card->>'name',''))) NOT BETWEEN 1 AND 150
  OR coalesce(card->>'type','') NOT IN ('Knight','Fire','Water','Forest','Thunder','Light','Dark')
 OR coalesce(lower(card->>'rarity'),'') NOT IN ('common','uncommon','rare','epic','legendary','mythic')
 OR coalesce(card->>'kind','') NOT IN ('base','fusion')
  OR jsonb_typeof(card->'skills') IS DISTINCT FROM 'array' OR jsonb_array_length(card->'skills')<>2
  OR NOT coalesce((card#>>'{stats,hp}')~'^[0-9]{1,3}$',false)
  OR NOT coalesce((card#>>'{stats,attack}')~'^[0-9]{1,3}$',false)
  OR NOT coalesce((card#>>'{stats,defense}')~'^[0-9]{1,3}$',false)
  OR (card#>>'{stats,hp}')::integer<1 THEN RAISE EXCEPTION 'Lengkapi nama, tipe, rarity dan statistik kartu %.',key; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(card->'skills') skill WHERE length(coalesce(skill->>'name',''))>200 OR length(coalesce(skill->>'description',''))>6000) THEN RAISE EXCEPTION 'Teks skill terlalu panjang.'; END IF;
  gid:=NULL;existing:=NULL;
  SELECT game_card_id INTO gid FROM public.card_studio_entries WHERE owner_id=owner AND dataset_id=p_dataset AND card_key=key FOR UPDATE;
  IF gid IS NULL AND nullif(card->>'source_game_card_id','') IS NOT NULL THEN gid:=(card->>'source_game_card_id')::uuid; END IF;
  IF gid IS NOT NULL THEN
   SELECT * INTO existing FROM public.game_cards WHERE id=gid FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Kartu sumber sudah tidak tersedia. Muat ulang katalog.'; END IF;
   IF existing.uid IS NOT NULL AND card->>'kind'='fusion' THEN RAISE EXCEPTION 'Kartu RFID tidak dapat diubah menjadi Fusion. Buat kartu Fusion baru.'; END IF;
  END IF;
  code:=trim(both '_' from regexp_replace(upper(coalesce(nullif(card->>'display_code',''),key)),'[^A-Z0-9]+','_','g'));
  -- The print code box can abbreviate long legacy catalog codes. Keep the
  -- original identifier unless the editor actually changed the printed code.
  IF existing.card_code=card->>'source_catalog_code' AND card->>'display_code'=left(replace(existing.card_code,'_','-'),12) THEN code:=existing.card_code; END IF;
  IF code='' THEN RAISE EXCEPTION 'Isi kode kartu.'; END IF;
  -- A print code may already belong to an existing Fusion recipe. Each new
  -- Studio Fusion gets an internal catalog identity; its printed code stays editable.
  IF card->>'kind'='fusion' THEN
   IF gid IS NULL THEN code:=code||'_STUDIO_'||upper(replace(gen_random_uuid()::text,'-',''));
   ELSIF existing.card_code~'_STUDIO_[A-F0-9]{32}$' THEN
    IF existing.metadata#>>'{studio_card,display_code}'=card->>'display_code' THEN code:=existing.card_code;
    ELSE code:=code||substring(existing.card_code from '_STUDIO_[A-F0-9]{32}$'); END IF;
   END IF;
  END IF;
  label:=trim(card->>'name')||CASE WHEN trim(coalesce(card->>'subtitle',''))<>'' THEN ' — '||trim(card->>'subtitle') ELSE '' END;
  meta:=coalesce(existing.metadata,'{}')||jsonb_build_object('studio_card',card,'studio_artwork',art,'studio_template',existing.uid IS NULL,
   'source_card_code',card->>'display_code','role',card->>'role',
   'skills',(SELECT jsonb_agg(value||jsonb_build_object('slot',ordinality,'icon',art#>>ARRAY['skill_icons',(ordinality-1)::text,'url'])) FROM jsonb_array_elements(card->'skills') WITH ORDINALITY));
  IF gid IS NULL THEN
   INSERT INTO public.game_cards(name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled,image_url,metadata,tags)
   VALUES(label,code,card->>'type',(card#>>'{stats,hp}')::integer,(card#>>'{stats,attack}')::integer,(card#>>'{stats,defense}')::integer,lower(card->>'rarity'),
    CASE WHEN card->>'kind'='fusion' THEN 'fusion' ELSE 'normal' END,card->>'kind'='fusion',false,art#>>'{character,url}',meta,
    ARRAY(SELECT jsonb_array_elements_text(coalesce(card->'tags','[]')))) RETURNING id INTO gid;
  ELSE
   UPDATE public.game_cards SET name=label,card_code=code,element=card->>'type',hp=(card#>>'{stats,hp}')::integer,attack=(card#>>'{stats,attack}')::integer,defense=(card#>>'{stats,defense}')::integer,
    rarity=lower(card->>'rarity'),card_kind=CASE WHEN card->>'kind'='fusion' THEN 'fusion' ELSE 'normal' END,fusion_only=card->>'kind'='fusion',
    image_url=coalesce(art#>>'{character,url}',image_url),metadata=meta,tags=ARRAY(SELECT jsonb_array_elements_text(coalesce(card->'tags','[]')))
   WHERE id=gid;
  END IF;
  INSERT INTO public.card_studio_entries(owner_id,dataset_id,card_key,game_card_id) VALUES(owner,p_dataset,key,gid)
   ON CONFLICT(owner_id,dataset_id,card_key) DO UPDATE SET game_card_id=excluded.game_card_id,updated_at=now();
  result:=result||jsonb_build_array(jsonb_build_object('card_key',key,'game_card_id',gid));
 END LOOP;
 INSERT INTO public.card_generator_projects(owner_id,dataset_id,workspace) VALUES(owner,p_dataset,p_workspace)
 ON CONFLICT(owner_id,dataset_id) DO UPDATE SET workspace=excluded.workspace,updated_at=now();
 RETURN jsonb_build_object('entries',result,'saved_at',now());
END $$;
REVOKE ALL ON FUNCTION public.save_card_studio(text,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_card_studio(text,jsonb,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
