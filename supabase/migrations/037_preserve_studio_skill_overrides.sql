-- Preserve explicitly edited skill masters. Studio print saves must not reset
-- battle rules; new RFID copies inherit the saved source rules by slot.
BEGIN;

CREATE OR REPLACE FUNCTION public.tcg_studio_skill_is_custom(p_skill public.special_skills)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE card_meta jsonb; printed jsonb; baseline jsonb; slot integer;
BEGIN
 IF coalesce(p_skill.metadata->>'studio_customized','false')='true' THEN RETURN true; END IF;
 IF coalesce(p_skill.metadata->>'studio_generated','false')<>'true' THEN RETURN false; END IF;
 IF coalesce(p_skill.metadata->>'slot','') NOT IN ('1','2') THEN RETURN true; END IF;
 slot:=(p_skill.metadata->>'slot')::integer;
 SELECT g.metadata INTO card_meta FROM public.game_cards g WHERE g.id::text=p_skill.metadata->>'studio_card_id';
 printed:=card_meta#>ARRAY['studio_card','skills',(slot-1)::text];
 baseline:=p_skill.metadata->'studio_rule';
 -- Missing provenance is not permission to overwrite a user's definition.
 IF printed IS NULL OR baseline IS NULL THEN RETURN true; END IF;
 RETURN ROW(p_skill.name,p_skill.description,p_skill.icon,p_skill.target_spec,p_skill.cost_spec,p_skill.limits,p_skill.effects,p_skill.skill_type,p_skill.activation_timing,p_skill.source_zones,p_skill.consumes_turn,p_skill.catalog_status)
 IS DISTINCT FROM ROW(coalesce(nullif(trim(printed->>'name'),''),'Skill '||slot),printed->>'description',card_meta#>>ARRAY['studio_artwork','skill_icons',(slot-1)::text,'url'],coalesce(baseline->'target_spec','{}'::jsonb),'{"type":"none"}'::jsonb,coalesce(baseline->'limits','{}'::jsonb),coalesce(baseline->'effects','[]'::jsonb),'active'::text,'main_phase'::text,ARRAY['active']::text[],false,CASE WHEN coalesce((baseline->>'enabled')::boolean,false) AND coalesce((printed#>>'{battle,enabled}')::boolean,true) THEN 'active' ELSE 'draft' END);
END $$;

-- Mark edits at the database boundary, including clients other than Catalog.
-- A nested Studio sync supplies the same generated rule as metadata.studio_rule;
-- direct Catalog writes carry the explicit marker, so trigger depth isn't an
-- authorization mechanism. Unmarked changes are caught against the baseline.
CREATE OR REPLACE FUNCTION public.tcg_mark_studio_skill_override()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF OLD.metadata->>'studio_generated'='true' AND (
   OLD.metadata->>'studio_customized'='true'
   OR (NEW.metadata->>'studio_customized'='true')
   OR (pg_trigger_depth()=1 AND (
     NEW.code IS DISTINCT FROM OLD.code OR NEW.catalog_status IS DISTINCT FROM OLD.catalog_status
     OR NEW.trigger_spec IS DISTINCT FROM OLD.trigger_spec
     OR (ROW(NEW.name,NEW.description,NEW.icon,NEW.skill_type,NEW.activation_timing,NEW.source_zones,NEW.target_spec,NEW.cost_spec,NEW.limits,NEW.effects,NEW.consumes_turn)
       IS DISTINCT FROM ROW(OLD.name,OLD.description,OLD.icon,OLD.skill_type,OLD.activation_timing,OLD.source_zones,OLD.target_spec,OLD.cost_spec,OLD.limits,OLD.effects,OLD.consumes_turn)
       AND public.tcg_studio_skill_is_custom(NEW))))
 ) THEN
   NEW.metadata:=coalesce(NEW.metadata,'{}')||jsonb_build_object('studio_customized',true);
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS zz_tbc_preserve_studio_skill_override ON public.special_skills;
CREATE TRIGGER zz_tbc_preserve_studio_skill_override BEFORE UPDATE ON public.special_skills
 FOR EACH ROW EXECUTE FUNCTION public.tcg_mark_studio_skill_override();

-- Preserve edits already made before this migration, using the old card data
-- while it is still available. Do not recompile or activate any skill here.
UPDATE public.special_skills s SET metadata=s.metadata||'{"studio_customized":true}'::jsonb
WHERE s.metadata->>'studio_generated'='true' AND coalesce(s.metadata->>'studio_customized','false')<>'true'
 AND public.tcg_studio_skill_is_custom(s);

CREATE OR REPLACE FUNCTION public.sync_studio_battle_skills(p_game_card_id uuid,p_skills jsonb,p_artwork jsonb DEFAULT '{}')
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE skill jsonb; rule jsonb; slot integer:=0; sid uuid; v_code text; enabled boolean; active_count integer:=0;
 existing public.special_skills; inherited public.special_skills; card_meta jsonb; next_meta jsonb;
BEGIN
 IF p_game_card_id IS NULL OR jsonb_typeof(p_skills) IS DISTINCT FROM 'array' OR jsonb_array_length(p_skills)<>2 THEN RAISE EXCEPTION 'Skill Studio harus tepat dua slot.'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('studio-skills:'||p_game_card_id::text,0));
 SELECT metadata INTO STRICT card_meta FROM public.game_cards WHERE id=p_game_card_id;
 FOR skill IN SELECT value FROM jsonb_array_elements(p_skills) LOOP
   slot:=slot+1; v_code:='studio_'||replace(p_game_card_id::text,'-','')||'_'||slot;
   existing:=NULL; inherited:=NULL;
   -- Slot identity survives a manually renamed skill code.
   SELECT s.* INTO existing FROM public.special_skills s
   WHERE s.metadata->>'studio_card_id'=p_game_card_id::text AND s.metadata->>'slot'=slot::text AND s.metadata->>'studio_generated'='true'
   ORDER BY s.created_at,s.id LIMIT 1 FOR UPDATE;
   IF existing.id IS NOT NULL AND existing.metadata->>'studio_customized'='true' THEN
     sid:=existing.id;
     enabled:=existing.is_active AND existing.catalog_status='active' AND coalesce((skill#>>'{battle,selection_enabled}')::boolean,true);
   ELSE
     -- Read only an explicit saved source, never arbitrary client-supplied
     -- effects. Existing customized RFID definitions remain independent.
     SELECT s.* INTO inherited FROM public.game_card_special_skills l JOIN public.special_skills s ON s.id=l.special_skill_id
     WHERE l.game_card_id::text=card_meta->>'catalog_source_id' AND l.game_card_id<>p_game_card_id
       AND s.metadata->>'slot'=slot::text AND s.metadata->>'studio_generated'='true'
       AND s.metadata->>'studio_customized'='true'
     ORDER BY l.sort_order,s.id LIMIT 1;
     IF inherited.id IS NOT NULL THEN
       enabled:=inherited.is_active AND inherited.catalog_status='active';
       next_meta:=inherited.metadata||jsonb_build_object('studio_card_id',p_game_card_id,'slot',slot,'studio_customized',true,'studio_source_skill_id',inherited.id);
       INSERT INTO public.special_skills(code,name,description,icon,category,skill_type,activation_timing,source_zones,trigger_spec,target_spec,cost_spec,limits,effects,consumes_turn,priority,is_active,catalog_status,metadata)
       VALUES(v_code,inherited.name,inherited.description,inherited.icon,inherited.category,inherited.skill_type,inherited.activation_timing,inherited.source_zones,inherited.trigger_spec,inherited.target_spec,inherited.cost_spec,inherited.limits,inherited.effects,inherited.consumes_turn,slot,enabled,inherited.catalog_status,next_meta)
       ON CONFLICT(code) DO UPDATE SET name=excluded.name,description=excluded.description,icon=excluded.icon,category=excluded.category,skill_type=excluded.skill_type,activation_timing=excluded.activation_timing,source_zones=excluded.source_zones,trigger_spec=excluded.trigger_spec,target_spec=excluded.target_spec,cost_spec=excluded.cost_spec,limits=excluded.limits,effects=excluded.effects,consumes_turn=excluded.consumes_turn,is_active=excluded.is_active,catalog_status=excluded.catalog_status,metadata=excluded.metadata,updated_at=now() RETURNING id INTO sid;
       enabled:=enabled AND coalesce((skill#>>'{battle,selection_enabled}')::boolean,true);
     ELSE
       rule:=public.studio_default_skill_rule(skill->>'description');
       enabled:=coalesce((rule->>'enabled')::boolean,false) AND coalesce((skill#>>'{battle,enabled}')::boolean,true);
       INSERT INTO public.special_skills(code,name,description,icon,category,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,priority,is_active,catalog_status,metadata)
       VALUES(v_code,coalesce(nullif(trim(skill->>'name'),''),'Skill '||slot),skill->>'description',p_artwork#>>ARRAY['skill_icons',(slot-1)::text,'url'],'studio_card','active','main_phase',ARRAY['active'],coalesce(rule->'target_spec','{}'),'{"type":"none"}',coalesce(rule->'limits','{}'),coalesce(rule->'effects','[]'),false,slot,enabled,CASE WHEN enabled THEN 'active' ELSE 'draft' END,jsonb_build_object('studio_generated',true,'studio_version',2,'studio_card_id',p_game_card_id,'studio_rule',rule,'slot',slot,'rules_status',CASE WHEN enabled THEN 'executable' ELSE 'configuration_required' END))
       ON CONFLICT(code) DO UPDATE SET name=excluded.name,description=excluded.description,icon=excluded.icon,target_spec=excluded.target_spec,cost_spec=excluded.cost_spec,limits=excluded.limits,effects=excluded.effects,is_active=excluded.is_active,catalog_status=excluded.catalog_status,metadata=excluded.metadata,updated_at=now() RETURNING id INTO sid;
     END IF;
   END IF;
   INSERT INTO public.game_card_special_skills(game_card_id,special_skill_id,sort_order,enabled,overrides) VALUES(p_game_card_id,sid,slot,enabled,'{}') ON CONFLICT(game_card_id,special_skill_id) DO UPDATE SET sort_order=excluded.sort_order,enabled=excluded.enabled;
   IF enabled THEN active_count:=active_count+1; END IF;
 END LOOP;
 RETURN active_count;
END $$;

REVOKE ALL ON FUNCTION public.tcg_studio_skill_is_custom(public.special_skills) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tcg_mark_studio_skill_override() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sync_studio_battle_skills(uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
