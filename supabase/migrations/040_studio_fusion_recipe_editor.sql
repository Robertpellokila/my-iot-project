-- Save a recipe and all requirements in one transaction; existing battle
-- matchers continue to use exact_card / tag / one_of unchanged.
BEGIN;
CREATE OR REPLACE FUNCTION public.save_studio_fusion_recipe(p_result_game_card_id uuid,p_recipe jsonb,p_materials jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result_card game_cards; existing fusion_recipes; rid uuid; label text; recipe_code text; material jsonb; row_data fusion_recipe_materials; position integer:=0; total integer:=0; required_total integer:=0; field text; spec jsonb; mode text; amount numeric; modes text[]:=ARRAY['exact_card','tag','one_of']; zones text[]; codes text[];
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_recipe) IS DISTINCT FROM 'object' OR jsonb_typeof(p_materials) IS DISTINCT FROM 'array' OR jsonb_array_length(p_materials) NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Resep memerlukan 1–20 baris material.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('studio-fusion:'||p_result_game_card_id::text,0));
 SELECT * INTO result_card FROM game_cards WHERE id=p_result_game_card_id FOR SHARE;
 IF result_card.id IS NULL OR NOT coalesce(result_card.fusion_only,false) THEN RAISE EXCEPTION 'Pilih kartu Fusion sebagai hasil resep.'; END IF;
 rid:=coalesce(nullif(p_recipe->>'id','')::uuid,gen_random_uuid());
 SELECT * INTO existing FROM fusion_recipes WHERE id=rid FOR UPDATE;
 IF existing.id IS NOT NULL AND existing.result_game_card_id<>p_result_game_card_id THEN RAISE EXCEPTION 'Resep ini milik kartu Fusion lain.' USING ERRCODE='42501'; END IF;
 IF existing.id IS NOT NULL AND p_recipe->>'updated_at' IS NOT NULL AND existing.updated_at IS DISTINCT FROM (p_recipe->>'updated_at')::timestamptz THEN RAISE EXCEPTION 'Resep sudah diubah dari halaman lain. Buka ulang resep sebelum menyimpan.'; END IF;
 label:=trim(p_recipe->>'name');recipe_code:=lower(trim(p_recipe->>'code'));
 IF coalesce(length(label),0) NOT BETWEEN 1 AND 150 OR coalesce(recipe_code,'')!~'^[a-z0-9_-]{1,120}$' THEN RAISE EXCEPTION 'Isi nama dan kode resep yang valid.'; END IF;
 IF coalesce(length(p_recipe->>'description'),0)>3000 THEN RAISE EXCEPTION 'Penjelasan resep maksimal 3000 karakter.'; END IF;
 IF coalesce(p_recipe->>'result_zone','active') NOT IN ('active','bench') OR coalesce(p_recipe->>'material_destination','graveyard')<>'graveyard' THEN RAISE EXCEPTION 'Hasil harus di Active/Bench dan material dikonsumsi ke Graveyard.'; END IF;
 IF jsonb_typeof(p_recipe->'result_stat_spec') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Lengkapi statistik hasil Fusion.'; END IF;
 FOREACH field IN ARRAY ARRAY['hp','attack','defense'] LOOP
   spec:=p_recipe#>ARRAY['result_stat_spec',field];mode:=spec->>'mode';
   IF mode IS NULL OR mode NOT IN ('fixed','material_sum_percent','highest_material_percent') OR jsonb_typeof(spec->'value') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Mode/nilai statistik % tidak valid.',field; END IF;
   amount:=(spec->>'value')::numeric;
   IF amount<0 OR amount>(CASE WHEN mode='fixed' THEN 10000 ELSE 10 END) OR (field='hp' AND amount=0) OR (mode='fixed' AND trunc(amount)<>amount) THEN RAISE EXCEPTION 'Nilai statistik % di luar batas.',field; END IF;
 END LOOP;
 IF coalesce(p_recipe#>>'{limits,max_uses}','0')!~'^[0-9]{1,3}$' OR coalesce((p_recipe#>>'{limits,max_uses}')::integer,0)>100 THEN RAISE EXCEPTION 'Batas pemakaian harus 0–100.'; END IF;
 -- Validate every requirement before deleting any previous material rows.
 FOR material IN SELECT value FROM jsonb_array_elements(p_materials) LOOP
   position:=position+1;
   IF material->>'material_type' IS NULL OR NOT (material->>'material_type'=ANY(modes)) THEN RAISE EXCEPTION 'Material %: pilih EXACT, ONE TAG, atau ONE OF.',position; END IF;
   IF coalesce(material->>'quantity','')!~'^[0-9]{1,2}$' OR (material->>'quantity')::integer NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Material %: jumlah harus 1–20.',position; END IF;
   total:=total+(material->>'quantity')::integer;
   IF NOT coalesce((material->>'optional')::boolean,false) THEN required_total:=required_total+(material->>'quantity')::integer; END IF;
   IF jsonb_typeof(material->'allowed_zones') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Material %: pilih zona Active atau Bench.',position; END IF;
   SELECT array_agg(DISTINCT value) INTO zones FROM jsonb_array_elements_text(material->'allowed_zones');
   IF coalesce(cardinality(zones),0)=0 OR NOT zones<@ARRAY['active','bench']::text[] THEN RAISE EXCEPTION 'Material %: zona tidak valid.',position; END IF;
   IF material->>'material_type'='exact_card' AND NOT EXISTS(SELECT 1 FROM game_cards WHERE upper(card_code)=upper(trim(material->>'card_code'))) THEN RAISE EXCEPTION 'Material %: kartu EXACT tidak ditemukan.',position; END IF;
   IF material->>'material_type'='tag' AND length(trim(coalesce(material->>'tag',''))) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Material %: isi tag ONE TAG.',position; END IF;
   IF material->>'material_type'='one_of' THEN
     IF jsonb_typeof(material->'card_codes') IS DISTINCT FROM 'array' OR jsonb_array_length(material->'card_codes') NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Material %: pilih alternatif ONE OF.',position; END IF;
     SELECT array_agg(DISTINCT upper(trim(value))) INTO codes FROM jsonb_array_elements_text(material->'card_codes');
     IF EXISTS(SELECT 1 FROM unnest(codes) code WHERE NOT EXISTS(SELECT 1 FROM game_cards WHERE upper(card_code)=code)) THEN RAISE EXCEPTION 'Material %: alternatif kartu tidak ditemukan.',position; END IF;
   END IF;
 END LOOP;
 IF total>20 THEN RAISE EXCEPTION 'Jumlah seluruh material maksimal 20 kartu.'; END IF;
 IF required_total=0 THEN RAISE EXCEPTION 'Resep harus mempunyai minimal satu material wajib.'; END IF;
 INSERT INTO fusion_recipes(id,code,name,description,icon,result_game_card_id,result_zone,material_destination,requirements,result_overrides,consumes_turn,is_active,cost_spec,limits,conditions,result_stat_spec,priority,metadata)
 VALUES(rid,recipe_code,label,nullif(trim(p_recipe->>'description'),''),coalesce(p_recipe->>'icon','✦'),p_result_game_card_id,coalesce(p_recipe->>'result_zone','active'),'graveyard',coalesce(p_recipe->'requirements','{}'),coalesce(p_recipe->'result_overrides','{}'),coalesce((p_recipe->>'consumes_turn')::boolean,false),coalesce((p_recipe->>'is_active')::boolean,false),coalesce(p_recipe->'cost_spec','{"type":"none","value":0}'),coalesce(p_recipe->'limits','{}'),coalesce(p_recipe->'conditions','{}'),p_recipe->'result_stat_spec',coalesce((p_recipe->>'priority')::integer,100),coalesce(existing.metadata,'{}')||'{"configured_from":"card_studio_fusion"}')
 ON CONFLICT(id) DO UPDATE SET code=excluded.code,name=excluded.name,description=excluded.description,icon=excluded.icon,result_zone=excluded.result_zone,material_destination=excluded.material_destination,requirements=excluded.requirements,result_overrides=excluded.result_overrides,consumes_turn=excluded.consumes_turn,is_active=excluded.is_active,cost_spec=excluded.cost_spec,limits=excluded.limits,conditions=excluded.conditions,result_stat_spec=excluded.result_stat_spec,priority=excluded.priority,metadata=excluded.metadata,updated_at=now();
 DELETE FROM fusion_recipe_materials WHERE recipe_id=rid;
 position:=0;
 FOR material IN SELECT value FROM jsonb_array_elements(p_materials) LOOP
   position:=position+1;
   SELECT * INTO row_data FROM jsonb_populate_record(NULL::fusion_recipe_materials,material);
   INSERT INTO fusion_recipe_materials(recipe_id,group_key,material_type,game_card_id,element,rarity,min_level,max_level,quantity,allowed_zones,optional,metadata,card_code,card_codes,tag,sort_order)
   VALUES(rid,coalesce(row_data.group_key,'main'),row_data.material_type,row_data.game_card_id,row_data.element,row_data.rarity,row_data.min_level,row_data.max_level,row_data.quantity,row_data.allowed_zones,coalesce(row_data.optional,false),coalesce(row_data.metadata,'{}'),CASE WHEN row_data.material_type='exact_card' THEN upper(trim(row_data.card_code)) END,CASE WHEN row_data.material_type='one_of' THEN ARRAY(SELECT DISTINCT upper(trim(code)) FROM unnest(row_data.card_codes) code) ELSE '{}' END,CASE WHEN row_data.material_type='tag' THEN lower(trim(row_data.tag)) END,position*10);
 END LOOP;
 RETURN jsonb_build_object('recipe',(SELECT to_jsonb(r) FROM fusion_recipes r WHERE id=rid),'materials',(SELECT jsonb_agg(to_jsonb(m) ORDER BY sort_order) FROM fusion_recipe_materials m WHERE recipe_id=rid));
END $$;
REVOKE ALL ON FUNCTION public.save_studio_fusion_recipe(uuid,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_studio_fusion_recipe(uuid,jsonb,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
