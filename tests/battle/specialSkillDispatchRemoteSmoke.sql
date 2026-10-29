-- Run inside a rollback transaction after migration 051. Covers both AP and
-- legacy turn modes, plus rejection without partial effects/resource spending.
DO $smoke$
DECLARE
 b uuid; c uuid; s uuid; code text; token1 text; token2 text; r jsonb;
 ap_enabled boolean; ends_turn boolean; expected_turn text; expected_ap integer;
BEGIN
 FOR mode IN 0..3 LOOP
  ap_enabled:=mode<2; ends_turn:=(mode%2)=1;
  b:=gen_random_uuid(); c:=gen_random_uuid(); s:=gen_random_uuid();
  code:='DISPATCH-QA-'||b; token1:=gen_random_uuid()::text; token2:=gen_random_uuid()::text;
  PERFORM set_config('tcg.intra_turn_action','off',true);
  INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at)
  VALUES(b,code,'tcg_v1','battle','p1',1,20,token1,token2,200,200,200,200,false,false,true,ap_enabled,3,3,0,20,20,1,60,now(),now()+interval '1 minute');
  INSERT INTO public.battle_cards(id,battle_id,player,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element)
  VALUES(c,b,'p1',gen_random_uuid()::text,'Dispatch fixture','active',1,100,100,50,30,10,'Forest'),
   (gen_random_uuid(),b,'p2',gen_random_uuid()::text,'Opponent fixture','active',1,100,100,100,30,10,'Water');
  INSERT INTO public.battle_card_skills(id,battle_id,battle_card_id,player,special_skill_id,skill_code,name,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,disabled)
  VALUES(s,b,c,'p1',(SELECT id FROM public.special_skills LIMIT 1),s::text,'Dispatch heal','active','main_phase',ARRAY['active'],'{"type":"self_card"}','{"type":"none"}','{"action_points":1,"cooldown_turns":0}',
   '[{"type":"heal_card","target":"source_card","owner":"self","allowed_zones":["active"],"amount":{"mode":"fixed","value":10}}]',ends_turn,false);
  UPDATE public.battle_sessions SET teacher_paused=true WHERE id=b;
  r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid()));
  IF coalesce((r->>'ok')::boolean,false) OR r->>'code'<>'BATTLE_PAUSED' THEN RAISE EXCEPTION 'Paused skill accepted mode %: %',mode,r; END IF;
  IF (SELECT current_hp FROM public.battle_cards WHERE id=c)<>50 OR (SELECT player1_action_points FROM public.battle_sessions WHERE id=b)<>3 OR EXISTS(SELECT 1 FROM public.battle_special_skill_uses WHERE battle_card_skill_id=s) THEN RAISE EXCEPTION 'Paused skill mutated state'; END IF;
  UPDATE public.battle_sessions SET teacher_paused=false,current_turn='p2' WHERE id=b;
  r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid()));
  IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Opponent turn accepted skill'; END IF;
  UPDATE public.battle_sessions SET current_turn='p1',player1_action_points=3 WHERE id=b;
  PERFORM set_config('tcg.intra_turn_action','off',true);
  r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid()));
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Dispatch mode % rejected: %',mode,r; END IF;
  IF (SELECT current_hp FROM public.battle_cards WHERE id=c)<>60 OR (SELECT count(*) FROM public.battle_special_skill_uses WHERE battle_card_skill_id=s)<>1 THEN RAISE EXCEPTION 'Effect/usage missing for mode %: %',mode,r; END IF;
  expected_turn:=CASE WHEN ends_turn THEN 'p2' ELSE 'p1' END;
  IF (SELECT current_turn FROM public.battle_sessions WHERE id=b)<>expected_turn THEN RAISE EXCEPTION 'Turn behavior mismatch for mode %: %',mode,r; END IF;
  IF ap_enabled THEN
   expected_ap:=CASE WHEN ends_turn THEN 0 ELSE 2 END;
   IF (SELECT player1_action_points FROM public.battle_sessions WHERE id=b)<>expected_ap THEN RAISE EXCEPTION 'AP mismatch for mode %: %',mode,r; END IF;
  END IF;
 END LOOP;
END $smoke$;
