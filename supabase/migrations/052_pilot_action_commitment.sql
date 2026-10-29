-- Pilot action rules. Changes battle behavior only; card stats, artwork,
-- recipes, skill definitions and existing battle snapshots are not rewritten.
BEGIN;

CREATE OR REPLACE FUNCTION public.tcg_pilot_is_fusion(c public.battle_cards)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT coalesce(c.is_fusion_result,false) OR coalesce(c.origin_type='fusion',false) OR coalesce(c.card_kind='fusion',false) OR c.fusion_recipe_id IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.tcg_pilot_committed(p_card uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce((c.battle_metadata->>'pilot_offense_owner_turn')::integer >= public.tcg_studio_owner_turn(c.battle_id,c.player),false)
   -- Also honor attacks already made before this migration was installed.
   OR (c.attack_turn_index=b.turn_index AND coalesce(c.attacks_this_turn,0)>0)
 FROM battle_cards c JOIN battle_sessions b ON b.id=c.battle_id WHERE c.id=p_card AND b.ruleset='tcg_v1';
$$;

CREATE OR REPLACE FUNCTION public.tcg_pilot_offense_reason(p_card uuid,p_attack boolean DEFAULT true)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c battle_cards; b battle_sessions; owner_turn integer;
BEGIN
 SELECT * INTO c FROM battle_cards WHERE id=p_card;
 SELECT * INTO b FROM battle_sessions WHERE id=c.battle_id;
 IF b.ruleset IS DISTINCT FROM 'tcg_v1' THEN RETURN NULL; END IF;
 owner_turn:=public.tcg_studio_owner_turn(b.id,c.player);
 IF coalesce((c.battle_metadata->>'pilot_fusion_owner_turn')::integer>=owner_turn,false) THEN
   RETURN 'Fusion baru bisa menyerang atau memberi debuff pada giliranmu berikutnya. Skill bantuan tetap boleh digunakan.';
 END IF;
 IF p_attack AND (coalesce((c.battle_metadata->>'pilot_attack_owner_turn')::integer>=owner_turn,false)
   OR (c.attack_turn_index=b.turn_index AND coalesce(c.attacks_this_turn,0)>0)) THEN
   RETURN 'Kesempatan serang kartu ini sudah habis. Attack, skill damage, Combo, Ultimate, dan Synergy damage berbagi 1 kesempatan per giliran.';
 END IF;
 RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.tcg_pilot_record_offense(p_card uuid,p_attack boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c battle_cards; b battle_sessions; t integer;
BEGIN
 SELECT * INTO c FROM battle_cards WHERE id=p_card FOR UPDATE;
 SELECT * INTO b FROM battle_sessions WHERE id=c.battle_id;
 IF b.ruleset IS DISTINCT FROM 'tcg_v1' THEN RETURN; END IF;
 t:=public.tcg_studio_owner_turn(b.id,c.player);
 UPDATE battle_cards SET battle_metadata=coalesce(battle_metadata,'{}')||jsonb_build_object('pilot_offense_owner_turn',t)
   ||CASE WHEN p_attack THEN jsonb_build_object('pilot_attack_owner_turn',t) ELSE '{}'::jsonb END,
   attack_turn_index=CASE WHEN p_attack THEN b.turn_index ELSE attack_turn_index END,
   last_attacked_turn=CASE WHEN p_attack THEN b.turn_index ELSE last_attacked_turn END,
   attacks_this_turn=CASE WHEN p_attack THEN greatest(1,CASE WHEN attack_turn_index=b.turn_index THEN coalesce(attacks_this_turn,0) ELSE 0 END) ELSE attacks_this_turn END
 WHERE id=p_card;
END $$;

-- Classify the selected branch, so a heal choice is not locked merely because
-- another choice does damage. Enemy debuffs lock retreat but spend no attack.
CREATE OR REPLACE FUNCTION public.tcg_pilot_skill_flags(p_effects jsonb,p_option text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE e jsonb; op jsonb; ops jsonb; damage boolean:=false; offensive boolean:=false;
BEGIN
 FOR e IN SELECT value FROM jsonb_array_elements(coalesce(p_effects,'[]')) LOOP
   IF e->>'type'='studio_skill' THEN
     ops:=coalesce(e#>'{program,operations}','[]');
     IF jsonb_array_length(coalesce(e#>'{program,choices}','[]'))>0 THEN
       SELECT value->'operations' INTO ops FROM jsonb_array_elements(e#>'{program,choices}') WHERE value->>'id'=p_option;
     END IF;
     FOR op IN SELECT value FROM jsonb_array_elements(coalesce(ops,'[]')) LOOP
       damage:=damage OR op->>'type'='attack';
       offensive:=offensive OR op->>'type' IN ('attack','burn','root','attack_debuff','defense_debuff','silence_slot2','mark','attack_reduction');
     END LOOP;
   ELSE
     damage:=damage OR e->>'type' IN ('damage_card','damage_player');
     offensive:=offensive OR e->>'type' IN ('damage_card','damage_player')
       OR (e->>'type' IN ('add_status','remove_status','move_zone','set_card_exhausted')
           AND (e->>'owner' IN ('enemy','opponent') OR e->>'target' IN ('enemy_player','enemy_active','all_enemy_active')));
   END IF;
 END LOOP;
 RETURN jsonb_build_object('attack',coalesce(damage,false),'offensive',coalesce(offensive,false));
END $$;

CREATE OR REPLACE FUNCTION public.tcg_card_action_block_reason(p_battle_id uuid,p_card_id uuid,p_action text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE prior text; c battle_cards;
BEGIN
 prior:=public.tcg_card_block_pre_studio(p_battle_id,p_card_id,p_action); IF prior IS NOT NULL THEN RETURN prior; END IF;
 IF p_action IN ('attack','combo_attack','special_skill','ultimate','synergy') AND EXISTS(SELECT 1 FROM battle_status_effects WHERE battle_id=p_battle_id AND target_card_id=p_card_id AND status_key='studio_revival_lock' AND active) THEN RETURN 'Kartu yang dibangkitkan baru dapat Attack/Skill pada giliran berikutnya.'; END IF;
 IF p_action IN ('switch_active','move_to_bench','return_from_bench') AND EXISTS(SELECT 1 FROM battle_status_effects WHERE battle_id=p_battle_id AND target_card_id=p_card_id AND status_key='root' AND active) THEN RETURN 'Root: kartu tidak dapat melakukan Switch sukarela.'; END IF;
 SELECT * INTO c FROM battle_cards WHERE id=p_card_id AND battle_id=p_battle_id;
 IF p_action IN ('move_to_bench','switch_active','fusion_material') AND public.tcg_pilot_committed(c.id) THEN
   RETURN 'Sudah melakukan aksi ofensif. Kartu harus tetap di Active hingga giliranmu berikutnya; belum boleh ke Bench atau menjadi bahan Fusion.';
 END IF;
 IF p_action IN ('attack','combo_attack','ultimate') THEN RETURN public.tcg_pilot_offense_reason(c.id,true); END IF;
 RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.tcg_battle_card_can_attack(p_card_id uuid,p_turn_index bigint,p_max_attacks integer)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM battle_cards c JOIN battle_sessions b ON b.id=c.battle_id WHERE c.id=p_card_id
 AND CASE WHEN b.ruleset='tcg_v1' THEN public.tcg_pilot_offense_reason(c.id,true) IS NULL
 ELSE c.attack_turn_index IS DISTINCT FROM p_turn_index OR coalesce(c.attacks_this_turn,0)<greatest(1,coalesce(p_max_attacks,1)) END);
$$;

-- Shared row guard covers manual moves, ally Switch effects and Fusion result
-- entry. Battle row locks serialize concurrent attempts at the Active cap.
CREATE OR REPLACE FUNCTION public.tcg_pilot_card_rules()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b battle_sessions; t integer;
BEGIN
 SELECT * INTO b FROM battle_sessions WHERE id=NEW.battle_id FOR UPDATE;
 IF b.ruleset IS DISTINCT FROM 'tcg_v1' THEN RETURN NEW; END IF;
 t:=public.tcg_studio_owner_turn(b.id,NEW.player);
 IF TG_OP='INSERT' THEN
   IF NEW.fusion_recipe_id IS NOT NULL AND b.status='battle' THEN
     NEW.battle_metadata:=coalesce(NEW.battle_metadata,'{}')||jsonb_build_object('pilot_fusion_owner_turn',t);
   END IF;
 ELSE
   IF NEW.fusion_consumed AND NOT coalesce(OLD.fusion_consumed,false) AND public.tcg_pilot_committed(OLD.id) THEN
     RAISE EXCEPTION USING ERRCODE='P0520',MESSAGE='Bahan Fusion sudah melakukan aksi ofensif. Tunggu giliranmu berikutnya.';
   END IF;
   IF NEW.attack_turn_index=b.turn_index AND coalesce(NEW.attacks_this_turn,0)>0
     AND (NEW.attack_turn_index IS DISTINCT FROM OLD.attack_turn_index OR NEW.attacks_this_turn>coalesce(OLD.attacks_this_turn,0)) THEN
     NEW.battle_metadata:=coalesce(NEW.battle_metadata,'{}')||jsonb_build_object('pilot_offense_owner_turn',t,'pilot_attack_owner_turn',t);
   END IF;
 END IF;
 IF NEW.zone='active' AND public.tcg_pilot_is_fusion(NEW) AND (TG_OP='INSERT' OR OLD.zone IS DISTINCT FROM NEW.zone)
   AND EXISTS(SELECT 1 FROM battle_cards c WHERE c.battle_id=NEW.battle_id AND c.player=NEW.player AND c.id<>NEW.id
     AND c.zone='active' AND coalesce(c.current_hp,c.hp,0)>0 AND public.tcg_pilot_is_fusion(c)) THEN
   RAISE EXCEPTION USING ERRCODE='P0520',MESSAGE='Maksimal 1 kartu Fusion di Active. Pindahkan Fusion yang lama ke Bench terlebih dahulu jika sudah boleh mundur.';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS zzz_pilot_card_rules ON public.battle_cards;
CREATE TRIGGER zzz_pilot_card_rules BEFORE INSERT OR UPDATE OF zone,attack_turn_index,attacks_this_turn,fusion_consumed ON public.battle_cards FOR EACH ROW EXECUTE FUNCTION public.tcg_pilot_card_rules();

-- Ultimate previously did not spend the card's attack allowance. Its event
-- occurs before the turn changes; failed actions roll this mark back too.
CREATE OR REPLACE FUNCTION public.tcg_pilot_ultimate_history()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.type='ultimate' AND NEW.card_id IS NOT NULL THEN PERFORM public.tcg_pilot_record_offense(NEW.card_id,true); END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tbc_pilot_ultimate_history ON public.battle_events;
CREATE TRIGGER tbc_pilot_ultimate_history AFTER INSERT ON public.battle_events FOR EACH ROW EXECUTE FUNCTION public.tcg_pilot_ultimate_history();

DO $$ BEGIN
 IF to_regprocedure('public.tcg_apply_effects_pre_pilot(uuid,text,uuid,jsonb,jsonb)') IS NULL THEN
   ALTER FUNCTION public.tcg_apply_effects(uuid,text,uuid,jsonb,jsonb) RENAME TO tcg_apply_effects_pre_pilot;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.tcg_apply_effects(p_battle_id uuid,p_source_player text,p_source_card_id uuid,p_effects jsonb,p_context jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE flags jsonb; reason text; r jsonb;
BEGIN
 flags:=public.tcg_pilot_skill_flags(p_effects,p_context->>'skill_option');
 IF (flags->>'offensive')::boolean THEN
   reason:=public.tcg_pilot_offense_reason(p_source_card_id,(flags->>'attack')::boolean);
   IF reason IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'message',reason); END IF;
   IF (flags->>'attack')::boolean THEN
     reason:=public.tcg_card_action_block_reason(p_battle_id,p_source_card_id,'attack');
     IF reason IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'message',reason); END IF;
   END IF;
 END IF;
 BEGIN
   -- Prevent a compound damage+Switch skill from bypassing the retreat lock.
   IF (flags->>'offensive')::boolean THEN PERFORM public.tcg_pilot_record_offense(p_source_card_id,false); END IF;
   r:=public.tcg_apply_effects_pre_pilot(p_battle_id,p_source_player,p_source_card_id,p_effects,p_context);
   IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION USING ERRCODE='P0521',MESSAGE=r::text; END IF;
   IF (flags->>'attack')::boolean THEN PERFORM public.tcg_pilot_record_offense(p_source_card_id,true); END IF;
   RETURN r;
 EXCEPTION WHEN SQLSTATE 'P0521' THEN RETURN SQLERRM::jsonb;
 WHEN SQLSTATE 'P0520' THEN RETURN jsonb_build_object('ok',false,'message',SQLERRM);
 END;
END $$;

-- Patch existing authoritative functions in place. Exact guards fail closed
-- on schema drift; a second installation is a no-op for each patch.
DO $patch$
DECLARE s text; patched text; needle text;
BEGIN
 s:=pg_get_functiondef('public.tcg_execute_studio_skill(uuid,text,uuid,jsonb,jsonb)'::regprocedure);
 IF strpos(s,'p_program->>''attacks''')>0 THEN
   s:=replace(s,'coalesce((p_program->>''attacks'')::boolean,false)',
     'EXISTS(SELECT 1 FROM jsonb_array_elements(operations) chosen_op WHERE chosen_op->>''type''=''attack'')');
   EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.tcg_execute_catalog_synergy(uuid,text,uuid)'::regprocedure);
 IF strpos(s,'tcg_pilot_offense_reason')=0 THEN
   needle:=' r:=public.tcg_apply_catalog_player_effect(b.id,p_player,rule->>''effect_type'',value,c.id);';
   IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unrecognized Synergy executor'; END IF;
   s:=replace(s,needle,$body$
 IF rule->>'effect_type' IN ('burst','piercing_burst','attack_debuff_percent') THEN
   IF public.tcg_pilot_offense_reason(c.id,rule->>'effect_type' IN ('burst','piercing_burst')) IS NOT NULL THEN
     RETURN jsonb_build_object('ok',false,'message',public.tcg_pilot_offense_reason(c.id,rule->>'effect_type' IN ('burst','piercing_burst')));
   END IF;
   IF rule->>'effect_type' IN ('burst','piercing_burst') AND public.tcg_card_action_block_reason(b.id,c.id,'attack') IS NOT NULL THEN
     RETURN jsonb_build_object('ok',false,'message',public.tcg_card_action_block_reason(b.id,c.id,'attack'));
   END IF;
 END IF;
$body$||needle);
   needle:=' used:=jsonb_set(used,ARRAY[selected_type],''true'',true);';
   IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unrecognized Synergy completion'; END IF;
   s:=replace(s,needle,$body$
 IF rule->>'effect_type' IN ('burst','piercing_burst','attack_debuff_percent') THEN
   PERFORM public.tcg_pilot_record_offense(c.id,rule->>'effect_type' IN ('burst','piercing_burst'));
 END IF;
$body$||needle);
   EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.tcg_match_fusion_recipe(uuid,text,uuid)'::regprocedure);
 IF strpos(s,'tcg_pilot_committed')=0 THEN
   -- Filter during both diagnostic counting and recursive selection, allowing
   -- an unused copy to match instead of rejecting a recipe on its first copy.
   patched:=regexp_replace(s,'(and coalesce\(\s*bc.fusion_consumed,\s*false\s*\) = false)',E'\\1 AND NOT coalesce(public.tcg_pilot_committed(bc.id),false)','g');
   IF patched=s THEN RAISE EXCEPTION 'Unrecognized Fusion matcher candidates'; END IF; s:=patched;
   needle:='  if v_match is null then';
   IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unrecognized Fusion matcher result'; END IF;
   s:=replace(s,needle,$body$
  -- The result replaces consumed materials, so a Fusion used as a legal
  -- material is excluded from the projected cap.
  IF v_match IS NOT NULL AND EXISTS(SELECT 1 FROM battle_cards c
    WHERE c.battle_id=p_battle_id AND c.player=v_player AND c.zone='active' AND coalesce(c.current_hp,c.hp,0)>0
      AND public.tcg_pilot_is_fusion(c) AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_match) m WHERE m->>'battle_card_id'=c.id::text)) THEN
    RETURN jsonb_build_object('ok',true,'available',false,'recipe_id',v_recipe.id,'recipe_name',v_recipe.name,
      'result_name',v_result_card.name,'requirements',v_diagnostics,'materials',v_match,
      'message','Maksimal 1 kartu Fusion di Active. Pindahkan Fusion yang lama ke Bench terlebih dahulu jika sudah boleh mundur.');
  END IF;
$body$||needle);
   s:=replace(s,'Material Fusion belum memenuhi seluruh requirement.','Material Fusion belum lengkap atau sudah melakukan aksi ofensif. Bahan harus belum menyerang/memberi debuff pada giliran ini.');
   EXECUTE s;
 END IF;
 -- Return a readable rejection for the shared cap/consumption row guards.
 s:=pg_get_functiondef('public.submit_battle_action(text,text,text,text,uuid,jsonb)'::regprocedure);
 IF strpos(s,'SQLSTATE ''P0520''')=0 THEN
   needle:='EXCEPTION WHEN SQLSTATE ''P0290'' THEN RETURN SQLERRM::jsonb;';
   IF strpos(s,needle)=0 THEN RAISE EXCEPTION 'Unrecognized atomic action guard'; END IF;
   EXECUTE replace(s,needle,needle||E'\n WHEN SQLSTATE ''P0520'' THEN RETURN jsonb_build_object(''ok'',false,''code'',''PILOT_RULE_BLOCKED'',''message'',SQLERRM);');
 END IF;
END $patch$;

REVOKE ALL ON FUNCTION public.tcg_pilot_is_fusion(public.battle_cards),public.tcg_pilot_committed(uuid),public.tcg_pilot_offense_reason(uuid,boolean),public.tcg_pilot_record_offense(uuid,boolean),public.tcg_pilot_skill_flags(jsonb,text),public.tcg_pilot_card_rules(),public.tcg_pilot_ultimate_history(),public.tcg_apply_effects_pre_pilot(uuid,text,uuid,jsonb,jsonb),public.tcg_apply_effects(uuid,text,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
