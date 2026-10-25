-- Tests the saved Studio cards with the real summon snapshot and action API.
-- Fixture battles, RFID copies, effects and events are rolled back inside a
-- subtransaction. Only a connection-local report remains for the final SELECT.
CREATE TEMP TABLE studio_skill_audit_output(report jsonb);
DO $audit$
DECLARE
 c record; printed record; b uuid; source_card uuid; copy_card uuid; copy_master uuid;
 token1 text; token2 text; battle_code text; result jsonb; runtime_count integer; copied_count integer;
 output jsonb:='[]'::jsonb; before_ap integer; after_ap integer; before_turn text; before_events bigint;
BEGIN
 BEGIN
  FOR c IN SELECT * FROM public.game_cards WHERE metadata ? 'studio_card' ORDER BY name,id LOOP
   b:=gen_random_uuid();source_card:=gen_random_uuid();copy_card:=gen_random_uuid();copy_master:=gen_random_uuid();
   token1:=gen_random_uuid()::text;token2:=gen_random_uuid()::text;battle_code:='STUDIO-QA-'||gen_random_uuid()::text;
   INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at)
   VALUES(b,battle_code,'tcg_v1','battle','p1',1,20,token1,token2,200,200,200,200,false,false,true,true,3,3,0,20,20,1,60,now(),now()+interval '1 minute');
   INSERT INTO public.battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element,origin_type)
   VALUES(source_card,b,'p1',c.id,CASE WHEN c.fusion_only THEN NULL ELSE gen_random_uuid()::text END,c.name,'active',1,c.hp,c.hp,c.hp,c.attack,c.defense,c.element,CASE WHEN c.fusion_only THEN 'fusion' ELSE 'rfid' END),
    (gen_random_uuid(),b,'p2',NULL,gen_random_uuid()::text,'QA target','active',1,200,200,200,30,10,'Water','rfid');
   SELECT count(*) INTO runtime_count FROM public.battle_card_skills WHERE battle_card_id=source_card;
   copied_count:=NULL;
   IF NOT c.fusion_only THEN
    -- Reproduce the registration copy projection and carry every source binding.
    INSERT INTO public.game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled,metadata,tags)
    VALUES(copy_master,gen_random_uuid()::text,c.name,c.card_code,c.element,c.hp,c.attack,c.defense,c.rarity,'normal',false,true,c.metadata-'timedoor_seed_key',c.tags);
    INSERT INTO public.game_card_special_skills(game_card_id,special_skill_id,enabled,sort_order,overrides)
    SELECT copy_master,special_skill_id,enabled,sort_order,overrides FROM public.game_card_special_skills WHERE game_card_id=c.id;
    INSERT INTO public.battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element)
    VALUES(copy_card,b,'p1',copy_master,gen_random_uuid()::text,c.name,'active',2,c.hp,c.hp,c.hp,c.attack,c.defense,c.element);
    SELECT count(*) INTO copied_count FROM public.battle_card_skills WHERE battle_card_id=copy_card;
   END IF;
   FOR printed IN SELECT value skill,ordinality slot FROM jsonb_array_elements(coalesce(c.metadata->'skills','[]')) WITH ORDINALITY LOOP
    SELECT player1_action_points,current_turn INTO before_ap,before_turn FROM public.battle_sessions WHERE id=b;
    SELECT count(*) INTO before_events FROM public.battle_events WHERE battle_id=b;
    -- Without a runtime binding, the action must fail without consuming resources.
    IF runtime_count=0 THEN
     result:=public.submit_battle_action(battle_code,'p1',token1,'special_skill',source_card,jsonb_build_object('skill_id',gen_random_uuid(),'action_id',gen_random_uuid()));
     SELECT player1_action_points INTO after_ap FROM public.battle_sessions WHERE id=b;
     IF coalesce((result->>'ok')::boolean,false) OR after_ap<>before_ap
      OR (SELECT current_turn FROM public.battle_sessions WHERE id=b)<>before_turn
      OR (SELECT count(*) FROM public.battle_events WHERE battle_id=b)<>before_events
      OR (SELECT current_hp FROM public.battle_cards WHERE id=source_card)<>c.hp THEN
      RAISE EXCEPTION 'Missing skill was accepted or changed AP/turn/events/HP for % slot %',c.name,printed.slot;
     END IF;
    ELSE result:=jsonb_build_object('message','Runtime exists; effect-specific verification required');END IF;
    output:=output||jsonb_build_array(jsonb_build_object('card_id',c.id,'card_code',c.metadata#>>'{studio_card,display_code}','name',c.name,'slot',printed.slot,'skill',printed.skill->>'name','description',printed.skill->>'description','runtime_skills',runtime_count,'copied_rfid_runtime_skills',copied_count,'status',CASE WHEN runtime_count=0 THEN 'BLOCKED_NO_BATTLE_BINDING' ELSE 'NEEDS_EFFECT_VERIFICATION' END,'action_message',result->>'message','rejection_preserves_resources',runtime_count=0));
   END LOOP;
  END LOOP;
  RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='Rollback audit fixtures';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
 END;
 INSERT INTO studio_skill_audit_output VALUES(jsonb_build_object('results',output,'checked_slots',jsonb_array_length(output),'fixtures_rolled_back',true));
END $audit$;
SELECT report FROM studio_skill_audit_output;
