-- Run inside BEGIN / ROLLBACK after 051. Exercise all active non-Studio
-- definitions, including unbound catalog entries, without editing definitions.
CREATE TEMP TABLE legacy_skill_dispatch_results(name text, result text);
DO $smoke$
DECLARE skill record; b uuid; src uuid; ally uuid; enemy uuid; dead uuid; s uuid; target uuid;
 code text; token text; r jsonb; effect jsonb; amount integer; malformed boolean;
BEGIN
 FOR skill IN SELECT * FROM public.special_skills WHERE is_active AND coalesce(metadata->>'studio_generated','false')<>'true' ORDER BY code LOOP
  b:=gen_random_uuid();src:=gen_random_uuid();ally:=gen_random_uuid();enemy:=gen_random_uuid();dead:=gen_random_uuid();s:=gen_random_uuid();
  code:='LEGACY-SKILL-QA-'||b;token:=gen_random_uuid()::text;
  PERFORM set_config('tcg.intra_turn_action','off',true);
  INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,player1_skill,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench)
  VALUES(b,code,'tcg_v1','battle','p1',1,20,token,gen_random_uuid()::text,50,200,200,200,100,false,false,true,true,10,10,0,20,20,1,60,now(),now()+interval '1 minute',4,4);
  -- Session initialization fills player HP/gauge; injure after that trigger.
  UPDATE public.battle_sessions SET player1_hp=50,player1_skill=100 WHERE id=b;
  INSERT INTO public.battle_cards(id,battle_id,player,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element)
  VALUES(src,b,'p1',gen_random_uuid()::text,'Legacy source','active',1,100,100,100,30,10,'Forest'),
   (ally,b,'p1',gen_random_uuid()::text,'Ally','active',2,200,200,50,30,10,'Water'),
   (enemy,b,'p2',gen_random_uuid()::text,'Opponent','active',1,300,300,300,30,10,'Water'),
   (dead,b,'p1',gen_random_uuid()::text,'Graveyard','graveyard',NULL,100,100,0,30,10,'Water');
  INSERT INTO public.battle_card_skills(id,battle_id,battle_card_id,player,special_skill_id,skill_code,name,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,disabled)
  VALUES(s,b,src,'p1',skill.id,skill.code,skill.name,skill.skill_type,skill.activation_timing,skill.source_zones,skill.target_spec,skill.cost_spec,skill.limits,skill.effects,skill.consumes_turn,false);
  target:=CASE skill.target_spec->>'type' WHEN 'enemy_active' THEN enemy WHEN 'ally_active' THEN ally WHEN 'ally_graveyard' THEN dead WHEN 'self_card' THEN src ELSE NULL END;
  malformed:=skill.target_spec->>'type' IN ('self_player','enemy_player') AND EXISTS(SELECT 1 FROM jsonb_array_elements(skill.effects) e WHERE e->>'target'='target_card');
  r:=public.submit_battle_action(code,'p1',token,'special_skill',src,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid(),'target_card_id',target));
  IF malformed THEN
   IF coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM public.battle_sessions WHERE id=b)<>10 OR EXISTS(SELECT 1 FROM public.battle_special_skill_uses WHERE battle_card_skill_id=s) THEN RAISE EXCEPTION 'Malformed target spent resources: % %',skill.name,r; END IF;
   INSERT INTO legacy_skill_dispatch_results VALUES(skill.name,'CONFIGURATION_REQUIRED: player target cannot supply target_card');
   CONTINUE;
  END IF;
  IF NOT coalesce((r->>'ok')::boolean,false) OR (SELECT count(*) FROM public.battle_special_skill_uses WHERE battle_card_skill_id=s)<>1 THEN RAISE EXCEPTION 'Legacy activation failed: % %',skill.name,r; END IF;
  FOR effect IN SELECT value FROM jsonb_array_elements(skill.effects) LOOP
   amount:=coalesce((effect#>>'{amount,value}')::integer,0);
   CASE effect->>'type'
    WHEN 'heal_player' THEN
     IF (SELECT player1_hp FROM public.battle_sessions WHERE id=b)<>least(200,50+amount) THEN RAISE EXCEPTION 'Player heal mismatch: %',skill.name; END IF;
    WHEN 'heal_card' THEN
     IF (SELECT current_hp FROM public.battle_cards WHERE id=target)<>least(200,50+amount) THEN RAISE EXCEPTION 'Card heal mismatch: %',skill.name; END IF;
    WHEN 'damage_card' THEN
     IF (SELECT current_hp FROM public.battle_cards WHERE id=enemy)<>300-amount THEN RAISE EXCEPTION 'Card damage mismatch: %',skill.name; END IF;
    WHEN 'add_status' THEN
     IF NOT EXISTS(SELECT 1 FROM public.battle_status_effects WHERE battle_id=b AND target_card_id=enemy AND status_key=effect->>'status_key' AND active) THEN RAISE EXCEPTION 'Status missing: %',skill.name; END IF;
    WHEN 'move_zone' THEN
     IF (SELECT zone FROM public.battle_cards WHERE id=src)<>effect->>'to_zone' THEN RAISE EXCEPTION 'Sacrifice missing: %',skill.name; END IF;
    WHEN 'revive' THEN
     IF NOT EXISTS(SELECT 1 FROM public.battle_cards WHERE id=dead AND zone=effect->>'to_zone' AND current_hp=round(100*(effect#>>'{restore_hp,value}')::numeric)) THEN RAISE EXCEPTION 'Revive mismatch: %',skill.name; END IF;
    ELSE RAISE EXCEPTION 'Unasserted legacy effect: % %',skill.name,effect->>'type';
   END CASE;
  END LOOP;
  IF skill.cost_spec->>'type'='skill_gauge' AND (SELECT player1_skill FROM public.battle_sessions WHERE id=b)<>100-(skill.cost_spec->>'value')::integer THEN RAISE EXCEPTION 'Gauge not spent: %',skill.name; END IF;
  INSERT INTO legacy_skill_dispatch_results VALUES(skill.name,'PASS');
 END LOOP;
END $smoke$;
