-- Run after the proposed F12 repair inside a rollback-only transaction.
-- Uses copies of the reported field; never submits an action on the real battle.
DO $smoke$
DECLARE
  b uuid:=gen_random_uuid(); qcode text:='QA-F12-'||gen_random_uuid();
  rid uuid; result_id uuid; card public.battle_cards; material_id uuid;
  r jsonb; runtime public.battle_cards; n integer;
BEGIN
  SELECT id,result_game_card_id INTO STRICT rid,result_id FROM public.fusion_recipes
  WHERE code='studio_f12_academy_nexus' AND is_active;
  INSERT INTO public.battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,
    player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,
    question_enabled,question_active,special_card_skills_enabled,fusion_enabled,
    action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,
    player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,
    turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card)
  VALUES(b,qcode,'tcg_v1','battle','p2',2,50,'qa-f12-p1','qa-f12-p2',200,200,200,200,
    false,false,true,true,true,3,0,3,20,16,4,60,now(),now()+interval '1 minute',4,4,1);
  FOR card IN SELECT bc.* FROM public.battle_cards bc
    JOIN public.battle_sessions bs ON bs.id=bc.battle_id
    WHERE bs.code='9N3BTE' AND bc.player='p2' AND bc.zone='active'
      AND bc.card_code IN ('PAN_007','COB_008','TOC_008','OTT_008')
  LOOP
    card.id:=gen_random_uuid();card.battle_id:=b;card.uid:='QA-F12-'||card.id;
    INSERT INTO public.battle_cards SELECT (card).*;
    IF card.card_code='OTT_008' THEN material_id:=card.id; END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.battle_cards WHERE battle_id=b)<>4 OR material_id IS NULL THEN
    RAISE EXCEPTION 'Reported field changed; refresh the reproduction fixture.';
  END IF;
  r:=public.get_player_fusions(qcode,'p2','qa-f12-p2');
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'recipes') f
    WHERE f->>'recipe_id'=rid::text AND (f->>'available')::boolean
      AND f->'calculated_stats' @> '{"hp":195,"attack":48,"defense":24}'::jsonb) THEN
    RAISE EXCEPTION 'Full field must offer F12 with Studio stats: %',r;
  END IF;
  UPDATE public.battle_cards SET zone='graveyard',slot=NULL WHERE id=material_id;
  IF (public.tcg_match_fusion_recipe(b,'p2',rid)->>'available')::boolean THEN
    RAISE EXCEPTION 'Missing/live-ineligible material accepted'; END IF;
  UPDATE public.battle_cards SET zone='bench' WHERE id=material_id;
  IF NOT (public.tcg_match_fusion_recipe(b,'p2',rid)->>'available')::boolean THEN
    RAISE EXCEPTION 'Legal Bench material rejected'; END IF;
  UPDATE public.battle_cards SET player='p1' WHERE id=material_id;
  IF (public.tcg_match_fusion_recipe(b,'p2',rid)->>'available')::boolean THEN
    RAISE EXCEPTION 'Opponent material accepted'; END IF;
  UPDATE public.battle_cards SET player='p2',zone='active',slot=3 WHERE id=material_id;
  UPDATE public.battle_sessions SET player2_action_points=1 WHERE id=b;
  r:=public.submit_battle_action(qcode,'p2','qa-f12-p2','fusion',NULL,jsonb_build_object('recipe_id',rid,'request_id',gen_random_uuid()));
  IF coalesce((r->>'ok')::boolean,false) OR (SELECT player2_action_points FROM public.battle_sessions WHERE id=b)<>1 THEN
    RAISE EXCEPTION 'Insufficient AP not rejected atomically: %',r; END IF;
  UPDATE public.battle_sessions SET player2_action_points=3 WHERE id=b;
  r:=public.submit_battle_action(qcode,'p2','qa-f12-p2','fusion',NULL,jsonb_build_object('recipe_id',rid,'request_id',gen_random_uuid()));
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Full-field Fusion failed: %',r; END IF;
  SELECT * INTO STRICT runtime FROM public.battle_cards WHERE battle_id=b AND game_card_id=result_id AND zone='active';
  -- TCG uses base_hp/current_hp; the old Classic hp column is not populated by Fusion.
  IF (runtime.base_hp,runtime.current_hp,runtime.attack,runtime.defense) IS DISTINCT FROM (195,195,48,24) THEN
    RAISE EXCEPTION 'Studio result stats mismatch'; END IF;
  IF (SELECT count(*) FROM public.battle_card_skills WHERE battle_card_id=runtime.id AND NOT disabled)<>2 THEN
    RAISE EXCEPTION 'Result did not inherit both saved skills'; END IF;
  IF (SELECT player2_action_points FROM public.battle_sessions WHERE id=b)<>1
     OR (SELECT current_turn FROM public.battle_sessions WHERE id=b)<>'p2' THEN
    RAISE EXCEPTION 'Fusion must cost 2 AP and preserve the remaining turn'; END IF;
  SELECT count(*) INTO n FROM public.battle_cards WHERE battle_id=b AND player='p2' AND zone='graveyard'
    AND card_code IN ('COB_008','TOC_008','OTT_008') AND fusion_consumed AND field_fusion_used;
  IF n<>3 OR (SELECT count(*) FROM public.battle_cards WHERE battle_id=b AND zone='active')<>2 THEN
    RAISE EXCEPTION 'Materials were not consumed or unrelated Active card was changed'; END IF;
  r:=public.submit_battle_action(qcode,'p2','qa-f12-p2','fusion',NULL,jsonb_build_object('recipe_id',rid,'request_id',gen_random_uuid()));
  IF coalesce((r->>'ok')::boolean,false) OR (SELECT player2_action_points FROM public.battle_sessions WHERE id=b)<>1 THEN
    RAISE EXCEPTION 'Repeated Fusion must not spend AP'; END IF;
  r:=public.get_player_fusions(qcode,'p2','qa-f12-p2');
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'recipes') f WHERE f->>'recipe_id'=rid::text
    AND NOT (f->>'available')::boolean AND (f->>'limit_reached')::boolean) THEN
    RAISE EXCEPTION 'Once-per-battle usage not reflected in preview'; END IF;
END $smoke$;
