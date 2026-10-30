BEGIN;

-- Existing matches retain their old rules. New matches freeze this policy and catalog.
ALTER TABLE public.battle_sessions
 ADD COLUMN combo_policy jsonb,
 ADD COLUMN combo_rules_snapshot jsonb,
 ADD COLUMN player1_combo_last_owner_turn integer,
 ADD COLUMN player2_combo_last_owner_turn integer;
ALTER TABLE public.battle_sessions ALTER COLUMN triple_combo_enabled SET DEFAULT true,
 ALTER COLUMN generic_combo_enabled SET DEFAULT true, ALTER COLUMN formation_enabled SET DEFAULT true;
ALTER TABLE public.tcg_combo_rule_catalog
 ADD COLUMN members jsonb NOT NULL DEFAULT '[]',
 ADD COLUMN shared_tag boolean NOT NULL DEFAULT false,
 ADD COLUMN priority integer NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 100);
ALTER TABLE public.tcg_combo_rule_catalog DROP CONSTRAINT tcg_combo_rule_catalog_rule_kind_type_keys_key;
CREATE UNIQUE INDEX tcg_combo_rule_name_unique ON public.tcg_combo_rule_catalog(lower(trim(combo_name)));
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.tcg_combo_rule_catalog FROM anon,authenticated;
CREATE POLICY combo_admin_read_all ON public.tcg_combo_rule_catalog FOR SELECT TO authenticated USING(public.is_admin());
UPDATE public.battle_sessions SET combo_rules_snapshot=(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id),'[]') FROM public.tcg_combo_rule_catalog r WHERE enabled);

CREATE FUNCTION public.tcg_combo_code(value text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT replace(regexp_replace(upper(trim(coalesce(value,''))),'_STUDIO_[A-F0-9]{32}$',''),'-','_');
$$;
-- At most four participants: backtracking prevents one card filling two recipe slots.
CREATE FUNCTION public.tcg_combo_members_match(requirements jsonb,cards jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE requirement jsonb; c jsonb; i integer;
BEGIN
 IF jsonb_array_length(requirements)=0 THEN RETURN true; END IF;
 IF jsonb_array_length(cards)=0 THEN RETURN false; END IF;
 requirement:=requirements->0;
 FOR i IN 0..jsonb_array_length(cards)-1 LOOP
  c:=cards->i;
  IF (coalesce(requirement->>'type','')='' OR public.tcg_canonical_card_type(c->>'element')=requirement->>'type')
   AND (coalesce(requirement->>'card_code','')='' OR public.tcg_combo_code(c->>'card_code')=public.tcg_combo_code(requirement->>'card_code'))
   AND (coalesce(requirement->>'tag','')='' OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(nullif(c->'tags','null'),'[]')) t WHERE lower(trim(t))=lower(trim(requirement->>'tag'))))
   AND public.tcg_combo_members_match(requirements-0,cards-i) THEN RETURN true; END IF;
 END LOOP;
 RETURN false;
END $$;
CREATE FUNCTION public.tcg_combo_recipe_matches(rule public.tcg_combo_rule_catalog,cards jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE tag text;
BEGIN
 IF NOT public.tcg_combo_members_match(rule.members,cards) THEN RETURN false; END IF;
 IF rule.shared_tag THEN
  FOR tag IN SELECT lower(trim(t)) FROM jsonb_array_elements_text(coalesce(nullif(cards->0->'tags','null'),'[]')) t WHERE trim(t)<>'' AND lower(trim(t)) NOT LIKE 'fusion:%' LOOP
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(cards) c WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(nullif(c->'tags','null'),'[]')) t WHERE lower(trim(t))=tag)) THEN RETURN true; END IF;
  END LOOP;
  RETURN false;
 END IF;
 RETURN true;
END $$;

CREATE FUNCTION public.tcg_validate_combo_recipe() RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE m jsonb; n integer:=cardinality(NEW.type_keys); types text[];
BEGIN
 IF NEW.combo_name IS NULL OR length(trim(NEW.combo_name)) NOT BETWEEN 1 AND 100 OR array_position(NEW.type_keys,NULL) IS NOT NULL
  OR NEW.primary_multiplier NOT BETWEEN 0 AND 2 OR NEW.damage_multiplier NOT BETWEEN 0 AND 1.5
  OR cardinality(NEW.assist_multipliers)<>n-1 OR EXISTS(SELECT 1 FROM unnest(NEW.assist_multipliers) v WHERE v IS NULL OR v NOT BETWEEN 0 AND 1)
  OR NEW.bonus_damage NOT BETWEEN 0 AND 50 OR NEW.heal_after NOT BETWEEN 0 AND 50 OR NEW.shield_after NOT BETWEEN 0 AND 50
  OR (NEW.status_key IS NOT NULL AND NEW.status_key NOT IN ('burn','poison','freeze','stun','root','curse','shield'))
  OR jsonb_typeof(NEW.members) IS DISTINCT FROM 'array' OR jsonb_array_length(NEW.members) NOT IN (0,n)
  OR jsonb_typeof(NEW.effect_json) IS DISTINCT FROM 'object' OR length(coalesce(NEW.effect_json->>'summary',''))>1000
 THEN RAISE EXCEPTION 'Isi resep, jumlah peserta, dan nilai efek Combo yang valid.'; END IF;
 FOR m IN SELECT * FROM jsonb_array_elements(NEW.members) LOOP
  IF jsonb_typeof(m) IS DISTINCT FROM 'object' OR public.tcg_canonical_card_type(m->>'type') IS DISTINCT FROM m->>'type'
   OR m->>'type' IS NULL OR length(coalesce(m->>'card_code',''))>100 OR length(coalesce(m->>'tag',''))>100
   OR lower(trim(coalesce(m->>'tag',''))) LIKE 'fusion:%' THEN RAISE EXCEPTION 'Setiap peserta memerlukan tipe valid; gunakan tag Combo, bukan tag fusion:.'; END IF;
 END LOOP;
 IF jsonb_array_length(NEW.members)>0 THEN
  SELECT array_agg(member.value->>'type' ORDER BY member.value->>'type') INTO types FROM jsonb_array_elements(NEW.members) member(value);
  IF types IS DISTINCT FROM NEW.type_keys THEN RAISE EXCEPTION 'Tipe peserta harus sesuai susunan tipe resep.'; END IF;
 END IF;
 NEW.combo_name:=trim(NEW.combo_name);NEW.updated_at:=clock_timestamp();RETURN NEW;
END $$;
CREATE TRIGGER zz_validate_combo_recipe BEFORE INSERT OR UPDATE ON public.tcg_combo_rule_catalog FOR EACH ROW EXECUTE FUNCTION public.tcg_validate_combo_recipe();

CREATE FUNCTION public.save_combo_recipe(p_rule jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE prior public.tcg_combo_rule_catalog; r public.tcg_combo_rule_catalog; saved public.tcg_combo_rule_catalog;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 IF p_rule->>'id' IS NOT NULL THEN
  SELECT * INTO prior FROM public.tcg_combo_rule_catalog WHERE id=(p_rule->>'id')::bigint FOR UPDATE;
  IF prior.id IS NULL OR prior.updated_at IS DISTINCT FROM (p_rule->>'updated_at')::timestamptz THEN RAISE EXCEPTION 'Resep sudah berubah. Muat ulang sebelum menyimpan.'; END IF;
 END IF;
 r:=jsonb_populate_record(NULL::public.tcg_combo_rule_catalog,p_rule);
 INSERT INTO public.tcg_combo_rule_catalog(id,rule_kind,type_keys,combo_name,enabled,ap_cost,primary_multiplier,assist_multipliers,damage_multiplier,bonus_damage,defense_ignore_pct,heal_after,shield_after,status_key,status_target,effect_json,members,shared_tag,priority)
 VALUES(coalesce(prior.id,nextval(pg_get_serial_sequence('public.tcg_combo_rule_catalog','id'))),r.rule_kind,r.type_keys,r.combo_name,coalesce(r.enabled,true),CASE cardinality(r.type_keys) WHEN 2 THEN 2 ELSE 3 END,
 coalesce(r.primary_multiplier,1),r.assist_multipliers,coalesce(r.damage_multiplier,1),coalesce(r.bonus_damage,0),coalesce(r.defense_ignore_pct,0),coalesce(r.heal_after,0),coalesce(r.shield_after,0),nullif(r.status_key,''),coalesce(r.status_target,'enemy'),
 jsonb_build_object('summary',coalesce(r.effect_json->>'summary',''),'cleanse_negative_status',coalesce((r.effect_json->>'cleanse_negative_status')::boolean,false)),coalesce(r.members,'[]'),coalesce(r.shared_tag,false),coalesce(r.priority,0))
 ON CONFLICT(id) DO UPDATE SET rule_kind=excluded.rule_kind,type_keys=excluded.type_keys,combo_name=excluded.combo_name,enabled=excluded.enabled,ap_cost=excluded.ap_cost,
 primary_multiplier=excluded.primary_multiplier,assist_multipliers=excluded.assist_multipliers,damage_multiplier=excluded.damage_multiplier,bonus_damage=excluded.bonus_damage,defense_ignore_pct=excluded.defense_ignore_pct,
 heal_after=excluded.heal_after,shield_after=excluded.shield_after,status_key=excluded.status_key,status_target=excluded.status_target,effect_json=excluded.effect_json,members=excluded.members,shared_tag=excluded.shared_tag,priority=excluded.priority RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $$;

CREATE FUNCTION public.tcg_snapshot_combo_policy() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.ruleset='tcg_v1' THEN
   NEW.combo_policy:='{"version":1,"cooldown_owner_turns":1,"max_per_turn":1,"base_only":true}';
   SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.priority DESC,r.id),'[]') INTO NEW.combo_rules_snapshot FROM public.tcg_combo_rule_catalog r WHERE enabled;
  ELSE NEW.combo_policy:=NULL;NEW.combo_rules_snapshot:=NULL;END IF;
  NEW.player1_combo_last_owner_turn:=NULL;NEW.player2_combo_last_owner_turn:=NULL;
 ELSE
  NEW.combo_policy:=OLD.combo_policy;NEW.combo_rules_snapshot:=OLD.combo_rules_snapshot;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tbc_snapshot_combo_policy BEFORE INSERT OR UPDATE ON public.battle_sessions FOR EACH ROW EXECUTE FUNCTION public.tcg_snapshot_combo_policy();

-- Patch the installed engine, preserving private access, turn guards and pilot locks.
DO $patch$
DECLARE s text; old text; replacement text;
BEGIN
 s:=pg_get_functiondef('public.tcg_submit_active_combo_attack(text,text,text,uuid,uuid[],uuid)'::regprocedure);
 old:='  v_response jsonb;';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo declaration anchor missing'; END IF;
 s:=replace(s,old,old||E'\n  v_owner_turn integer;\n  v_last_combo integer;\n  v_combo_cards jsonb;');
 old:='  v_enemy := CASE WHEN v_player=';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo guard anchor missing'; END IF;
 replacement:=$text$
  v_owner_turn := public.tcg_studio_owner_turn(v_battle.id,v_player);
  v_last_combo := CASE WHEN v_player='p1' THEN v_battle.player1_combo_last_owner_turn ELSE v_battle.player2_combo_last_owner_turn END;
  IF v_battle.combo_policy IS NOT NULL AND v_last_combo IS NOT NULL AND v_owner_turn < v_last_combo+2 THEN
    RETURN jsonb_build_object('ok',false,'code','COMBO_COOLDOWN','combo_ready_owner_turn',v_last_combo+2,
      'message',CASE WHEN v_owner_turn=v_last_combo THEN 'Jatah Combo giliran ini sudah dipakai. Semua jenis Combo berbagi cooldown.' ELSE 'Combo cooldown pada giliran ini. Siap pada giliranmu berikutnya.' END);
  END IF;
$text$;
 s:=replace(s,old,replacement||old);
 old:='    IF NOT public.tcg_battle_card_can_attack(v_participant.id,v_battle.turn_index,v_battle.max_attacks_per_card) THEN';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo participant anchor missing'; END IF;
 s:=replace(s,old,$text$
    IF v_battle.combo_policy IS NOT NULL AND public.tcg_pilot_is_fusion(v_participant) THEN
      RETURN jsonb_build_object('ok',false,'code','COMBO_BASE_ONLY','message','Combo memakai kartu Base saja. Kartu Fusion memiliki serangan dan skill sendiri.');
    END IF;
$text$||old);
 old:=$text$    SELECT * INTO v_rule FROM public.tcg_combo_rule_catalog r
     WHERE r.enabled
       AND (r.rule_kind=v_kind OR (v_kind='formation' AND r.rule_kind='ultimate'))
       AND r.type_keys=v_types
     LIMIT 1;$text$;
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo recipe anchor missing'; END IF;
 s:=replace(s,old,$text$
    SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) INTO v_combo_cards FROM public.battle_cards c WHERE c.id=ANY(v_participants) AND c.battle_id=v_battle.id;
    SELECT r.* INTO v_rule FROM jsonb_populate_recordset(NULL::public.tcg_combo_rule_catalog,
      coalesce(v_battle.combo_rules_snapshot,(SELECT coalesce(jsonb_agg(to_jsonb(c)),'[]') FROM public.tcg_combo_rule_catalog c WHERE enabled))) r
     WHERE r.enabled AND (r.rule_kind=v_kind OR (v_kind='formation' AND r.rule_kind='ultimate')) AND r.type_keys=v_types
       AND public.tcg_combo_recipe_matches(r,v_combo_cards)
     ORDER BY r.priority DESC,
       ((SELECT coalesce(sum(CASE WHEN coalesce(m->>'card_code','')<>'' THEN 2 ELSE 0 END + CASE WHEN coalesce(m->>'tag','')<>'' THEN 1 ELSE 0 END),0) FROM jsonb_array_elements(r.members) m)+CASE WHEN r.shared_tag THEN 1 ELSE 0 END) DESC,
       r.id LIMIT 1;
$text$);
 old:='    player1_action_points=CASE WHEN v_player=';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo usage anchor missing'; END IF;
 s:=replace(s,old,$text$    player1_combo_last_owner_turn=CASE WHEN v_player='p1' AND v_battle.combo_policy IS NOT NULL THEN v_owner_turn ELSE player1_combo_last_owner_turn END,
    player2_combo_last_owner_turn=CASE WHEN v_player='p2' AND v_battle.combo_policy IS NOT NULL THEN v_owner_turn ELSE player2_combo_last_owner_turn END,
$text$||old);
 old:='  RETURN v_response;';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo response anchor missing'; END IF;
 s:=replace(s,old,$text$  IF v_battle.combo_policy IS NOT NULL THEN v_response:=v_response||jsonb_build_object('combo_ready_owner_turn',v_owner_turn+2); END IF;
$text$||old);
 EXECUTE s;
 -- The dedicated resolver owns cost validation (2, 3 or 4 participants).
 -- A higher two-card cost must not block an affordable Triple/Formation first.
 s:=pg_get_functiondef('public.tcg_submit_battle_action_core_v2(text,text,text,text,uuid,jsonb)'::regprocedure);
 old:='v_cost := public.tcg_resolve_action_point_cost(v_action, v_battle.action_costs);';
 IF strpos(s,old)=0 THEN RAISE EXCEPTION 'Combo dispatcher cost anchor missing'; END IF;
 s:=replace(s,old,'v_cost := CASE WHEN v_action=''combo_attack'' THEN 0 ELSE public.tcg_resolve_action_point_cost(v_action, v_battle.action_costs) END;');
 EXECUTE s;
END $patch$;

REVOKE ALL ON FUNCTION public.save_combo_recipe(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_combo_recipe(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.tcg_combo_code(text),public.tcg_combo_members_match(jsonb,jsonb),public.tcg_combo_recipe_matches(public.tcg_combo_rule_catalog,jsonb),public.tcg_validate_combo_recipe(),public.tcg_snapshot_combo_policy() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
