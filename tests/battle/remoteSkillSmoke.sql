-- Opt-in smoke test against the linked Supabase project. All fixtures roll back.
BEGIN;
DO $smoke$
DECLARE
 b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); s1 uuid:=gen_random_uuid(); s2 uuid:=gen_random_uuid();
 request_id uuid:=gen_random_uuid(); code text:='QA-'||gen_random_uuid()::text;
 token1 text:=gen_random_uuid()::text; token2 text:=gen_random_uuid()::text;
 r jsonb; ap integer; hp_now integer; cd integer; owner_turn integer;
BEGIN
 INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at)
 VALUES(b,code,'tcg_v1','battle','p1',1,20,token1,token2,200,200,200,200,false,false,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute');
 INSERT INTO public.battle_cards(id,battle_id,player,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element)
 VALUES(c,b,'p1',gen_random_uuid()::text,'Smoke fixture','active',1,100,100,50,30,10,'Forest'),
 (gen_random_uuid(),b,'p2',gen_random_uuid()::text,'Opponent fixture','active',1,100,100,100,30,10,'Water');
 INSERT INTO public.battle_card_skills(id,battle_id,battle_card_id,player,special_skill_id,skill_code,name,skill_type,activation_timing,source_zones,target_spec,cost_spec,limits,effects,consumes_turn,disabled)
 SELECT id,b,c,'p1',(SELECT id FROM public.special_skills LIMIT 1),id::text,'Smoke heal','active','main_phase',ARRAY['active'],'{"type":"self_card"}'::jsonb,'{"type":"none"}'::jsonb,
 CASE WHEN id=s1 THEN '{"action_points":2,"cooldown_turns":2}'::jsonb ELSE '{"action_points":0,"cooldown_turns":0}'::jsonb END,
 '[{"type":"heal_card","target":"source_card","owner":"self","allowed_zones":["active"],"amount":{"mode":"fixed","value":10}}]'::jsonb,false,false FROM unnest(ARRAY[s1,s2]) AS ids(id);
 r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s1,'action_id',request_id));
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Runtime skill activation failed: %',r; END IF;
 SELECT player1_action_points,player1_owner_turn INTO ap,owner_turn FROM public.battle_sessions WHERE id=b;
 SELECT current_hp INTO hp_now FROM public.battle_cards WHERE id=c;
 IF ap<>1 OR hp_now<>60 OR owner_turn<>1 THEN RAISE EXCEPTION 'Runtime AP/real heal/owner clock mismatch: %, %, %',ap,hp_now,owner_turn; END IF;
 r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s1,'action_id',request_id));
 IF NOT coalesce((r->>'replayed')::boolean,false) THEN RAISE EXCEPTION 'Duplicate request not replayed'; END IF;
 IF (SELECT current_hp FROM public.battle_cards WHERE id=c)<>60 THEN RAISE EXCEPTION 'Duplicate applied healing twice'; END IF;
 r:=public.submit_battle_action(code,'p1','invalid-token','special_skill',c,jsonb_build_object('skill_id',s1,'action_id',request_id));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Invalid token accessed receipt'; END IF;
 r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s2,'action_id',gen_random_uuid()));
 IF NOT coalesce((r->>'ok')::boolean,false) OR (SELECT player1_action_points FROM public.battle_sessions WHERE id=b)<>1 THEN RAISE EXCEPTION 'Second skill / zero AP override failed: %',r; END IF;
 -- Zone changes must not delete or reset the runtime skill cooldown.
 SELECT cooldown_until_owner_turn INTO cd FROM public.battle_card_skills WHERE id=s1;
 UPDATE public.battle_cards SET zone='bench',slot=NULL WHERE id=c;
 UPDATE public.battle_cards SET zone='graveyard',current_hp=0 WHERE id=c;
 UPDATE public.battle_cards SET zone='active',slot=1,current_hp=70,revive_count=1 WHERE id=c;
 IF (SELECT cooldown_until_owner_turn FROM public.battle_card_skills WHERE id=s1) IS DISTINCT FROM cd THEN RAISE EXCEPTION 'Cooldown reset across zones'; END IF;
 FOR i IN 2..4 LOOP
  -- Real RPCs commit between requests, clearing this transaction-local legacy
  -- flag. Emulate that boundary while retaining rollback-only test fixtures.
  PERFORM set_config('tcg.intra_turn_action','off',true);
  UPDATE public.battle_sessions SET current_turn='p2' WHERE id=b;
  UPDATE public.battle_sessions SET current_turn='p1',player1_action_points=3 WHERE id=b;
  r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s1,'action_id',gen_random_uuid()));
  IF coalesce((r->>'ok')::boolean,false) IS DISTINCT FROM (i=4) THEN RAISE EXCEPTION 'CD2 wrong at owner turn %: %',i,r; END IF;
  IF i<4 AND (SELECT player1_action_points FROM public.battle_sessions WHERE id=b)<>3 THEN RAISE EXCEPTION 'Rejected cooldown debited AP'; END IF;
 END LOOP;
 UPDATE public.battle_card_skills SET disabled=true WHERE id=s2;
 r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s2,'action_id',gen_random_uuid()));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Disabled skill accepted'; END IF;
 UPDATE public.battle_sessions SET status='finished',winner='p1' WHERE id=b;
 r:=public.submit_battle_action(code,'p1',token1,'special_skill',c,jsonb_build_object('skill_id',s2,'action_id',gen_random_uuid()));
 IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Finished battle accepted skill'; END IF;
END $smoke$;
ROLLBACK;
SELECT 'PASS: runtime AP override, real heal, independent skills, receipt/token guards, persistent CD2, rejection rollback, disabled and finished guards. All fixtures rolled back.' AS result;
