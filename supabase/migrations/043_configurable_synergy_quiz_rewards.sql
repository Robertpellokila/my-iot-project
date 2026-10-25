BEGIN;
CREATE TABLE public.battle_effect_catalog(
 code text PRIMARY KEY CHECK(code~'^[a-z][a-z0-9_]{1,63}$'),
 kind text NOT NULL CHECK(kind IN ('synergy','quiz_bonus')),
 element text, name text NOT NULL, icon text NOT NULL DEFAULT '✦', description text NOT NULL DEFAULT '',
 effect_type text NOT NULL, effect_values jsonb NOT NULL, min_cards integer NOT NULL DEFAULT 2,
 enabled boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((kind='synergy' AND element IN ('knight','fire','water','forest','thunder','light','dark','ice')) OR (kind='quiz_bonus' AND element IS NULL))
);
CREATE UNIQUE INDEX battle_effect_catalog_element ON public.battle_effect_catalog(element) WHERE kind='synergy';
CREATE TABLE public.battle_reward_settings(id integer PRIMARY KEY DEFAULT 1 CHECK(id=1),choice_count integer NOT NULL DEFAULT 3 CHECK(choice_count BETWEEN 1 AND 6),updated_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.battle_reward_settings DEFAULT VALUES;
ALTER TABLE public.battle_effect_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_reward_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.battle_effect_catalog,public.battle_reward_settings FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.battle_effect_catalog,public.battle_reward_settings TO authenticated;
CREATE POLICY battle_effect_admin_read ON public.battle_effect_catalog FOR SELECT TO authenticated USING(public.is_admin());
CREATE POLICY battle_reward_admin_read ON public.battle_reward_settings FOR SELECT TO authenticated USING(public.is_admin());

CREATE FUNCTION public.tcg_catalog_type(value text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT CASE lower(trim(value)) WHEN 'grass' THEN 'forest' WHEN 'nature' THEN 'forest' WHEN 'electric' THEN 'thunder' WHEN 'wind' THEN 'thunder' WHEN 'lightning' THEN 'thunder' WHEN 'holy' THEN 'light' WHEN 'warrior' THEN 'knight' WHEN 'shadow' THEN 'dark' ELSE lower(trim(value)) END
$$;
CREATE FUNCTION public.tcg_validate_catalog_rule() RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE k text; v numeric; max_value numeric;
BEGIN
 IF length(trim(NEW.name)) NOT BETWEEN 1 AND 100 OR NEW.name~*'^(https?://|data:|/)' OR length(NEW.description)>2000 OR length(NEW.icon)>2048 OR NEW.icon~*'^(javascript:|data:|//)' THEN RAISE EXCEPTION 'Isi nama, gambar, dan penjelasan yang valid.'; END IF;
 IF NEW.effect_type NOT IN ('heal_percent','heal_flat','shield_percent','add_gauge','attack_debuff_percent','power_strike','defense','cleanse','burst','piercing_burst') THEN RAISE EXCEPTION 'Jenis efek belum didukung.'; END IF;
 IF NEW.kind='quiz_bonus' AND NEW.effect_type IN ('burst','piercing_burst') THEN RAISE EXCEPTION 'Efek serangan dengan kartu sumber hanya tersedia untuk Synergy.'; END IF;
 IF NEW.min_cards NOT BETWEEN 2 AND 4 OR jsonb_typeof(NEW.effect_values) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Syarat kartu atau nilai efek tidak valid.'; END IF;
 FOREACH k IN ARRAY CASE WHEN NEW.kind='synergy' THEN ARRAY['2','3','4'] ELSE ARRAY['1'] END LOOP
  IF jsonb_typeof(NEW.effect_values->k) IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Isi nilai efek untuk setiap tingkat.'; END IF;
  v:=(NEW.effect_values->>k)::numeric;
  max_value:=CASE WHEN NEW.effect_type='heal_flat' THEN 1000 WHEN NEW.effect_type IN ('burst','piercing_burst') THEN 500 WHEN NEW.effect_type IN ('shield_percent','attack_debuff_percent') THEN 95 ELSE 100 END;
  IF v<0 OR v>max_value OR (NEW.effect_type IN ('burst','piercing_burst') AND v<1) OR (NEW.effect_type IN ('power_strike','defense') AND v<>50) OR (NEW.effect_type='cleanse' AND v<>0) THEN RAISE EXCEPTION 'Nilai efek di luar batas atau tidak sesuai jenis efek.'; END IF;
 END LOOP;
 NEW.name:=trim(NEW.name);NEW.updated_at:=now();RETURN NEW;
END $$;
CREATE TRIGGER battle_effect_validate BEFORE INSERT OR UPDATE ON public.battle_effect_catalog FOR EACH ROW EXECUTE FUNCTION public.tcg_validate_catalog_rule();
INSERT INTO public.battle_effect_catalog(code,kind,element,name,icon,effect_type,effect_values) VALUES
 ('synergy_knight','synergy','knight','Knight Aegis','🛡','shield_percent','{"2":30,"3":45,"4":60}'),
 ('synergy_fire','synergy','fire','Blaze Burst','🔥','burst','{"2":150,"3":180,"4":220}'),
 ('synergy_water','synergy','water','Aqua Barrier','💧','shield_percent','{"2":40,"3":60,"4":80}'),
 ('synergy_forest','synergy','forest','Nature Restore','🌿','heal_percent','{"2":30,"3":45,"4":60}'),
 ('synergy_thunder','synergy','thunder','Volt Charge','⚡','add_gauge','{"2":40,"3":70,"4":100}'),
 ('synergy_light','synergy','light','Radiant Recovery','☀','heal_percent','{"2":20,"3":30,"4":40}'),
 ('synergy_dark','synergy','dark','Shadow Burst','🌑','piercing_burst','{"2":140,"3":170,"4":200}'),
 ('synergy_ice','synergy','ice','Frost Curse','❄','attack_debuff_percent','{"2":25,"3":40,"4":60}'),
 ('power_strike','quiz_bonus',NULL,'Power Strike','⚔','power_strike','{"1":50}'),
 ('iron_guard','quiz_bonus',NULL,'Iron Guard','🛡','defense','{"1":50}'),
 ('recovery','quiz_bonus',NULL,'Recovery','💚','heal_percent','{"1":25}'),
 ('overcharge','quiz_bonus',NULL,'Overcharge','⚡','add_gauge','{"1":50}'),
 ('cleanse','quiz_bonus',NULL,'Cleanse','✨','cleanse','{"1":0}');

CREATE FUNCTION public.save_battle_effect_rule(p_rule jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE prior public.battle_effect_catalog; saved public.battle_effect_catalog;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 SELECT * INTO prior FROM public.battle_effect_catalog WHERE code=p_rule->>'code' FOR UPDATE;
 IF prior.code IS NOT NULL AND (p_rule->>'updated_at' IS NULL OR prior.updated_at IS DISTINCT FROM (p_rule->>'updated_at')::timestamptz) THEN RAISE EXCEPTION 'Aturan sudah berubah. Muat ulang sebelum menyimpan.'; END IF;
 IF prior.code IS NOT NULL AND (prior.kind IS DISTINCT FROM p_rule->>'kind' OR prior.element IS DISTINCT FROM nullif(p_rule->>'element','')) THEN RAISE EXCEPTION 'Jenis dan tipe aturan tersimpan tidak dapat diganti.'; END IF;
 INSERT INTO public.battle_effect_catalog(code,kind,element,name,icon,description,effect_type,effect_values,min_cards,enabled)
 VALUES(p_rule->>'code',p_rule->>'kind',nullif(p_rule->>'element',''),p_rule->>'name',coalesce(nullif(p_rule->>'icon',''),'✦'),coalesce(p_rule->>'description',''),p_rule->>'effect_type',p_rule->'effect_values',coalesce((p_rule->>'min_cards')::integer,2),coalesce((p_rule->>'enabled')::boolean,true))
 ON CONFLICT(code) DO UPDATE SET name=excluded.name,icon=excluded.icon,description=excluded.description,effect_type=excluded.effect_type,effect_values=excluded.effect_values,min_cards=excluded.min_cards,enabled=excluded.enabled RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $$;
CREATE FUNCTION public.save_battle_reward_settings(p_choice_count integer,p_updated_at timestamptz) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE prior public.battle_reward_settings; saved public.battle_reward_settings;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Admin login diperlukan.' USING ERRCODE='42501'; END IF;
 SELECT * INTO prior FROM public.battle_reward_settings WHERE id=1 FOR UPDATE;
 IF prior.updated_at IS DISTINCT FROM p_updated_at THEN RAISE EXCEPTION 'Pengaturan berubah. Muat ulang sebelum menyimpan.'; END IF;
 UPDATE public.battle_reward_settings SET choice_count=p_choice_count,updated_at=now() WHERE id=1 RETURNING * INTO saved;RETURN to_jsonb(saved);
END $$;

ALTER TABLE public.battle_sessions ADD COLUMN synergy_rules_snapshot jsonb,ADD COLUMN quiz_bonus_rules_snapshot jsonb,ADD COLUMN quiz_bonus_choice_count integer CHECK(quiz_bonus_choice_count BETWEEN 1 AND 6);
ALTER TABLE public.battle_bonus_skills ADD COLUMN rule_snapshot jsonb;
UPDATE public.battle_sessions SET
 synergy_rules_snapshot=(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.code),'[]') FROM public.battle_effect_catalog r WHERE kind='synergy' AND enabled),
 quiz_bonus_rules_snapshot=(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.code),'[]') FROM public.battle_effect_catalog r WHERE kind='quiz_bonus' AND enabled),
 quiz_bonus_choice_count=3 WHERE status IN ('battle','question','waiting','ready');
CREATE FUNCTION public.tcg_snapshot_battle_catalog() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.code),'[]') INTO NEW.synergy_rules_snapshot FROM public.battle_effect_catalog r WHERE kind='synergy' AND enabled;
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.code),'[]') INTO NEW.quiz_bonus_rules_snapshot FROM public.battle_effect_catalog r WHERE kind='quiz_bonus' AND enabled;
  SELECT coalesce(NEW.quiz_bonus_choice_count,choice_count) INTO NEW.quiz_bonus_choice_count FROM public.battle_reward_settings WHERE id=1;
 ELSE
  NEW.synergy_rules_snapshot:=OLD.synergy_rules_snapshot;NEW.quiz_bonus_rules_snapshot:=OLD.quiz_bonus_rules_snapshot;NEW.quiz_bonus_choice_count:=OLD.quiz_bonus_choice_count;
 END IF;RETURN NEW;
END $$;
CREATE TRIGGER tbc_snapshot_battle_catalog BEFORE INSERT OR UPDATE ON public.battle_sessions FOR EACH ROW EXECUTE FUNCTION public.tcg_snapshot_battle_catalog();
CREATE FUNCTION public.tcg_snapshot_bonus_rule() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='UPDATE' THEN NEW.rule_snapshot:=OLD.rule_snapshot;RETURN NEW;END IF;
 SELECT r INTO NEW.rule_snapshot FROM public.battle_sessions b CROSS JOIN LATERAL jsonb_array_elements(coalesce(b.quiz_bonus_rules_snapshot,'[]')) r WHERE b.id=NEW.battle_id AND r->>'code'=NEW.skill_type LIMIT 1;
 IF NEW.rule_snapshot IS NULL THEN RAISE EXCEPTION 'Bonus tidak tersedia pada aturan battle ini.'; END IF;RETURN NEW;
END $$;
CREATE TRIGGER tbc_snapshot_bonus_rule BEFORE INSERT OR UPDATE ON public.battle_bonus_skills FOR EACH ROW EXECUTE FUNCTION public.tcg_snapshot_bonus_rule();

CREATE FUNCTION public.get_battle_rule_catalog(p_code text,p_player text,p_token text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code));
 IF b.id IS NULL OR p_player IS NULL OR p_player NOT IN ('p1','p2') OR p_token IS NULL OR p_token IS DISTINCT FROM (CASE WHEN p_player='p1' THEN b.player1_token ELSE b.player2_token END) THEN RETURN jsonb_build_object('ok',false,'message','Token tidak valid.'); END IF;
 RETURN jsonb_build_object('ok',true,'synergies',coalesce(b.synergy_rules_snapshot,'[]'),'bonuses',coalesce(b.quiz_bonus_rules_snapshot,'[]'),'choice_count',coalesce(b.quiz_bonus_choice_count,3));
END $$;
CREATE FUNCTION public.tcg_catalog_bonus_offer(p_battle_id uuid) RETURNS text[] LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(array_agg(code),'{}'::text[]) FROM (
  SELECT r->>'code' code FROM public.battle_sessions b CROSS JOIN LATERAL jsonb_array_elements(coalesce(b.quiz_bonus_rules_snapshot,'[]')) r
  WHERE b.id=p_battle_id ORDER BY random() LIMIT (SELECT coalesce(quiz_bonus_choice_count,3) FROM public.battle_sessions WHERE id=p_battle_id)
 ) offered
$$;
ALTER TABLE public.battle_question_bonus_choices DROP CONSTRAINT battle_question_bonus_choices_three_options;
ALTER TABLE public.battle_question_bonus_choices ADD CONSTRAINT battle_question_bonus_choices_option_count CHECK(cardinality(skill_options) BETWEEN 1 AND 6);
DO $patch$ DECLARE s text; a integer; z integer; gate text:='IF coalesce(v_battle.question_bonus_enabled, true) THEN'; BEGIN
 s:=pg_get_functiondef('public.tcg_grade_battle_question_answer(text,text,text,uuid,integer)'::regprocedure);
 a:=strpos(s,'SELECT array_agg(skill_type ORDER BY random()) INTO v_reward_choices');
 z:=strpos(substr(s,a),'AS shuffled;');
 IF a=0 OR z=0 OR strpos(s,gate)=0 THEN RAISE EXCEPTION 'Unrecognized quiz reward offer function'; END IF;
 s:=substr(s,1,a-1)||'v_reward_choices := public.tcg_catalog_bonus_offer(v_battle.id);'||substr(s,a+z+length('AS shuffled;')-1);
 s:=replace(s,gate,'IF coalesce(v_battle.question_bonus_enabled, true) AND jsonb_array_length(coalesce(v_battle.quiz_bonus_rules_snapshot,''[]''))>0 THEN');
 EXECUTE s;
END $patch$;

CREATE FUNCTION public.tcg_apply_catalog_player_effect(p_battle_id uuid,p_player text,p_effect text,p_value numeric,p_card_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions; c public.battle_cards; enemy text; hp integer; max_hp integer; amount integer:=0; delta integer:=0; damage integer:=0; shield numeric; debuff numeric; defended boolean;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE id=p_battle_id FOR UPDATE;
 IF b.id IS NULL OR p_player IS NULL OR p_player NOT IN ('p1','p2') OR p_value<0 OR p_value>1000 THEN RETURN jsonb_build_object('ok',false,'message','Efek tidak valid.'); END IF;
 enemy:=CASE WHEN p_player='p1' THEN 'p2' ELSE 'p1' END;
 hp:=CASE WHEN p_player='p1' THEN b.player1_hp ELSE b.player2_hp END;max_hp:=CASE WHEN p_player='p1' THEN b.player1_max_hp ELSE b.player2_max_hp END;
 CASE p_effect
 WHEN 'heal_percent','heal_flat' THEN
  amount:=CASE WHEN p_effect='heal_percent' THEN round(max_hp*p_value/100)::integer ELSE round(p_value)::integer END;
  delta:=greatest(0,least(max_hp,hp+amount)-hp);
  IF p_player='p1' THEN b.player1_hp:=hp+delta;ELSE b.player2_hp:=hp+delta;END IF;
 WHEN 'shield_percent' THEN
  IF p_player='p1' THEN b.player1_synergy_shield:=greatest(coalesce(b.player1_synergy_shield,0),p_value/100);ELSE b.player2_synergy_shield:=greatest(coalesce(b.player2_synergy_shield,0),p_value/100);END IF;
 WHEN 'add_gauge' THEN
  IF p_player='p1' THEN delta:=least(100,b.player1_skill+p_value::integer)-b.player1_skill;b.player1_skill:=b.player1_skill+delta;ELSE delta:=least(100,b.player2_skill+p_value::integer)-b.player2_skill;b.player2_skill:=b.player2_skill+delta;END IF;
 WHEN 'attack_debuff_percent' THEN
  IF enemy='p1' THEN b.player1_attack_debuff:=greatest(coalesce(b.player1_attack_debuff,0),p_value/100);ELSE b.player2_attack_debuff:=greatest(coalesce(b.player2_attack_debuff,0),p_value/100);END IF;
 WHEN 'power_strike' THEN IF p_player='p1' THEN b.player1_power_strike_ready:=true;ELSE b.player2_power_strike_ready:=true;END IF;
 WHEN 'defense' THEN IF p_player='p1' THEN b.player1_defending:=true;ELSE b.player2_defending:=true;END IF;
 WHEN 'cleanse' THEN IF p_player='p1' THEN b.player1_attack_debuff:=0;ELSE b.player2_attack_debuff:=0;END IF;
 WHEN 'burst','piercing_burst' THEN
  SELECT * INTO c FROM public.battle_cards c0 WHERE c0.id=p_card_id AND c0.battle_id=b.id AND c0.player=p_player AND c0.zone='active' AND coalesce(c0.current_hp,c0.base_hp,c0.hp,0)>0;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Kartu sumber tidak tersedia.'); END IF;
  damage:=greatest(1,round(c.attack*p_value/100)::integer);debuff:=CASE WHEN p_player='p1' THEN b.player1_attack_debuff ELSE b.player2_attack_debuff END;
  damage:=round(damage*(1-coalesce(debuff,0)))::integer;
  IF p_player='p1' THEN b.player1_attack_debuff:=0;ELSE b.player2_attack_debuff:=0;END IF;
  defended:=CASE WHEN enemy='p1' THEN b.player1_defending ELSE b.player2_defending END;
  IF p_effect='burst' AND coalesce(defended,false) THEN damage:=round(damage*.5)::integer;IF enemy='p1' THEN b.player1_defending:=false;ELSE b.player2_defending:=false;END IF;END IF;
  shield:=CASE WHEN enemy='p1' THEN b.player1_synergy_shield ELSE b.player2_synergy_shield END;
  damage:=greatest(0,round(damage*(1-coalesce(shield,0)))::integer);
  IF enemy='p1' THEN b.player1_synergy_shield:=0;b.player1_hp:=greatest(0,b.player1_hp-damage);ELSE b.player2_synergy_shield:=0;b.player2_hp:=greatest(0,b.player2_hp-damage);END IF;
 ELSE RETURN jsonb_build_object('ok',false,'message','Efek belum didukung.');
 END CASE;
 UPDATE public.battle_sessions SET player1_hp=b.player1_hp,player2_hp=b.player2_hp,player1_skill=b.player1_skill,player2_skill=b.player2_skill,
  player1_synergy_shield=b.player1_synergy_shield,player2_synergy_shield=b.player2_synergy_shield,player1_attack_debuff=b.player1_attack_debuff,player2_attack_debuff=b.player2_attack_debuff,
  player1_power_strike_ready=b.player1_power_strike_ready,player2_power_strike_ready=b.player2_power_strike_ready,player1_defending=b.player1_defending,player2_defending=b.player2_defending WHERE id=b.id;
 RETURN jsonb_build_object('ok',true,'effect_type',p_effect,'value',p_value,'damage',damage,'heal',CASE WHEN p_effect IN ('heal_percent','heal_flat') THEN delta ELSE 0 END,'gauge_added',CASE WHEN p_effect='add_gauge' THEN delta ELSE 0 END);
END $$;
CREATE FUNCTION public.tcg_execute_catalog_synergy(p_battle_id uuid,p_player text,p_card_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;c public.battle_cards; rule jsonb; used jsonb; selected_type text; total integer; tier text; r jsonb; value numeric;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE id=p_battle_id FOR UPDATE;
 SELECT * INTO c FROM public.battle_cards WHERE id=p_card_id AND battle_id=b.id AND player=p_player AND zone='active' AND NOT coalesce(exhausted,false) AND coalesce(current_hp,base_hp,hp,0)>0 FOR UPDATE;
 IF c.id IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Pilih kartu Active yang masih dapat bertindak.'); END IF;
 selected_type:=public.tcg_catalog_type(c.element);
 SELECT r0 INTO rule FROM jsonb_array_elements(coalesce(b.synergy_rules_snapshot,'[]')) r0 WHERE r0->>'element'=selected_type LIMIT 1;
 IF rule IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Synergy tipe ini tidak diaktifkan pada battle ini.'); END IF;
 SELECT count(*) INTO total FROM public.battle_cards WHERE battle_id=b.id AND player=p_player AND zone='active' AND NOT coalesce(exhausted,false) AND coalesce(current_hp,base_hp,hp,0)>0 AND public.tcg_catalog_type(battle_cards.element)=selected_type;
 IF total<(rule->>'min_cards')::integer THEN RETURN jsonb_build_object('ok',false,'message',format('Butuh %s kartu Active bertipe sama.',rule->>'min_cards')); END IF;
 used:=coalesce(CASE WHEN p_player='p1' THEN b.player1_synergy_used ELSE b.player2_synergy_used END,'{}');
 IF EXISTS(SELECT 1 FROM jsonb_each(used) e WHERE public.tcg_catalog_type(e.key)=selected_type AND e.value='true'::jsonb) THEN RETURN jsonb_build_object('ok',false,'message','Synergy tipe ini sudah digunakan.'); END IF;
 tier:=least(4,total)::text;value:=(rule->'effect_values'->>tier)::numeric;
 r:=public.tcg_apply_catalog_player_effect(b.id,p_player,rule->>'effect_type',value,c.id);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 used:=jsonb_set(used,ARRAY[selected_type],'true',true);
 UPDATE public.battle_sessions SET player1_synergy_used=CASE WHEN p_player='p1' THEN used ELSE player1_synergy_used END,player2_synergy_used=CASE WHEN p_player='p2' THEN used ELSE player2_synergy_used END WHERE id=b.id;
 INSERT INTO public.battle_events(battle_id,type,source_player,target_player,card_id,payload) VALUES(b.id,'synergy',p_player,CASE WHEN p_player='p1' THEN 'p2' ELSE 'p1' END,c.id,r||jsonb_build_object('element',selected_type,'skill_name',rule->>'name','synergy_points',total,'message',rule->>'name'));
 RETURN r||jsonb_build_object('synergy_name',rule->>'name','synergy_points',total);
END $$;
DO $patch$ DECLARE s text;a integer;z integer;marker text:=E'  elsif p_action =\n    ''synergy''\n  then'; BEGIN
 s:=pg_get_functiondef('public.submit_battle_action_core_3d15(text,text,text,text,uuid,jsonb)'::regprocedure);
 s:=regexp_replace(s,'(?i)(declare[[:space:]]+)',E'\\1 v_catalog_result jsonb;\n');
 a:=strpos(s,marker);z:=strpos(substr(s,a+length(marker)),E'  elsif p_action =');
 IF a=0 OR z=0 THEN RAISE EXCEPTION 'Unrecognized Synergy engine branch'; END IF;
 s:=substr(s,1,a-1)||marker||E'\n    v_catalog_result := public.tcg_execute_catalog_synergy(v_battle.id,p_player,p_card_id);\n    IF NOT coalesce((v_catalog_result->>''ok'')::boolean,false) THEN RETURN v_catalog_result; END IF;\n    SELECT * INTO v_battle FROM public.battle_sessions WHERE id=v_battle.id;\n    v_synergy_points := coalesce((v_catalog_result->>''synergy_points'')::integer,0);\n    v_damage := coalesce((v_catalog_result->>''damage'')::integer,0);\n    v_actual_heal := coalesce((v_catalog_result->>''heal'')::integer,0);\n'||substr(s,a+length(marker)+z-1);
 EXECUTE s;
END $patch$;

CREATE OR REPLACE FUNCTION public.use_battle_bonus_skill(p_code text,p_player text,p_token text,p_bonus_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions; bonus public.battle_bonus_skills; rule jsonb;r jsonb;guard jsonb;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 IF b.id IS NULL OR p_player IS NULL OR p_player NOT IN ('p1','p2') OR p_token IS NULL OR p_token IS DISTINCT FROM (CASE WHEN p_player='p1' THEN b.player1_token ELSE b.player2_token END) THEN RETURN jsonb_build_object('ok',false,'message','Token tidak valid.'); END IF;
 guard:=public.tcg_sync_battle_turn(p_code,p_player,p_token);IF NOT coalesce((guard->>'ok')::boolean,false) THEN RETURN guard; END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE id=b.id;
 IF b.status IS DISTINCT FROM 'battle' OR b.winner IS NOT NULL OR coalesce(b.question_active,false) OR b.current_turn IS DISTINCT FROM p_player OR coalesce(b.pending_action,'')<>'' OR (b.turn_deadline_at IS NOT NULL AND b.turn_deadline_at<=now()) THEN RETURN jsonb_build_object('ok',false,'message','Bonus hanya dapat dipakai saat giliranmu dan tidak ada aksi tertunda.'); END IF;
 SELECT * INTO bonus FROM public.battle_bonus_skills WHERE id=p_bonus_id AND battle_id=b.id AND player=p_player FOR UPDATE;
 IF bonus.id IS NULL OR coalesce(bonus.used,false) THEN RETURN jsonb_build_object('ok',false,'message','Bonus tidak tersedia atau sudah digunakan.'); END IF;
 rule:=bonus.rule_snapshot;
 IF rule IS NULL THEN SELECT r0 INTO rule FROM jsonb_array_elements(coalesce(b.quiz_bonus_rules_snapshot,'[]')) r0 WHERE r0->>'code'=bonus.skill_type LIMIT 1; END IF;
 IF rule IS NULL THEN RETURN jsonb_build_object('ok',false,'message','Aturan bonus tidak ditemukan.'); END IF;
 r:=public.tcg_apply_catalog_player_effect(b.id,p_player,rule->>'effect_type',(rule->'effect_values'->>'1')::numeric);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 UPDATE public.battle_bonus_skills SET used=true WHERE id=bonus.id;
 INSERT INTO public.battle_events(battle_id,type,source_player,payload) VALUES(b.id,'bonus_skill_used',p_player,r||jsonb_build_object('skill_type',bonus.skill_type,'skill_name',rule->>'name','message',rule->>'name'));
 RETURN r||jsonb_build_object('skill_type',bonus.skill_type,'ends_turn',false,'message','Bonus berhasil digunakan.');
END $$;

CREATE FUNCTION public.get_public_battle_bonus_choice(p_code text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;c public.battle_question_bonus_choices;options jsonb;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code));
 IF b.id IS NULL OR NOT coalesce(b.is_active,true) OR (b.active_until IS NOT NULL AND b.active_until<=now()) THEN RETURN jsonb_build_object('ok',true,'pending',false,'options','[]'::jsonb); END IF;
 SELECT * INTO c FROM public.battle_question_bonus_choices WHERE battle_id=b.id AND (
  (selected_skill_type IS NULL AND b.question_active AND question_round_id=b.current_question_round_id)
  OR (selected_at>now()-interval '8 seconds')
 ) ORDER BY created_at DESC LIMIT 1;
 IF c.question_round_id IS NULL THEN RETURN jsonb_build_object('ok',true,'pending',false,'options','[]'::jsonb); END IF;
 SELECT coalesce(jsonb_agg(r ORDER BY array_position(c.skill_options,r->>'code')),'[]') INTO options FROM jsonb_array_elements(coalesce(b.quiz_bonus_rules_snapshot,'[]')) r WHERE r->>'code'=ANY(c.skill_options);
 RETURN jsonb_build_object('ok',true,'pending',c.selected_skill_type IS NULL,'question_round_id',c.question_round_id,'player',c.player,'selected_code',c.selected_skill_type,'options',options);
END $$;

REVOKE ALL ON FUNCTION public.tcg_catalog_type(text),public.tcg_validate_catalog_rule(),public.tcg_snapshot_battle_catalog(),public.tcg_snapshot_bonus_rule(),public.tcg_catalog_bonus_offer(uuid),public.tcg_apply_catalog_player_effect(uuid,text,text,numeric,uuid),public.tcg_execute_catalog_synergy(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.save_battle_effect_rule(jsonb),public.save_battle_reward_settings(integer,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_battle_effect_rule(jsonb),public.save_battle_reward_settings(integer,timestamptz) TO authenticated;
REVOKE ALL ON FUNCTION public.get_battle_rule_catalog(text,text,text),public.use_battle_bonus_skill(text,text,text,uuid),public.get_public_battle_bonus_choice(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_battle_rule_catalog(text,text,text),public.use_battle_bonus_skill(text,text,text,uuid),public.get_public_battle_bonus_choice(text) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
