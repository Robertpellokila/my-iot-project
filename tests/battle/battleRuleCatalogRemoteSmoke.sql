-- Linked-project integration: fixtures and admin edits are always rolled back.
BEGIN;
CREATE FUNCTION pg_temp.tbc_rule_fixture(p_type text,p_count integer) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE b uuid:=gen_random_uuid();i integer;
BEGIN
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,
  player1_skill,player2_skill,question_enabled,question_active,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,
  player1_deck_remaining,player2_deck_remaining,turn_index,max_active,max_bench,turn_duration_seconds,turn_started_at,turn_deadline_at,is_active,active_until,action_costs)
 VALUES(b,'QA43-'||b,'tcg_v1','battle','p1',1,100,'qa43-one','qa43-two',50,200,200,200,0,0,false,false,true,3,3,0,20,20,1,4,4,60,now(),now()+interval '1 minute',true,now()+interval '1 hour','{"synergy":1}');
 UPDATE battle_sessions SET player1_hp=50,player2_hp=200 WHERE id=b;
 FOR i IN 1..p_count LOOP
  INSERT INTO battle_cards(battle_id,player,zone,slot,uid,name,element,attack,defense,hp,base_hp,current_hp,exhausted)
  VALUES(b,'p1','active',i,'QA43-'||gen_random_uuid(),'QA43 card '||i,p_type,40,10,100,100,100,false);
 END LOOP;RETURN b;
END $$;
DO $smoke$
DECLARE b uuid;c uuid;q uuid:=gen_random_uuid();qr uuid;bid uuid;account_id uuid;rule jsonb;before_rule jsonb;r jsonb;projected jsonb;row battle_sessions;v_kind text;tier integer;n integer;counter integer:=0;count_bonus integer;types text[]:=ARRAY['Knight','Fire','Water','Forest','Thunder','Light','Dark','Ice'];value numeric;expected integer;
BEGIN
 SELECT id INTO account_id FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1;
 IF account_id IS NULL THEN RAISE EXCEPTION 'Admin fixture identity unavailable';END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',account_id,'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',account_id::text,true);
 FOREACH v_kind IN ARRAY types LOOP FOR tier IN 2..4 LOOP
  b:=pg_temp.tbc_rule_fixture(v_kind,tier);SELECT id INTO c FROM battle_cards WHERE battle_id=b ORDER BY slot LIMIT 1;
  r:=submit_battle_action('QA43-'||b,'p1','qa43-one','synergy',c,'{}');
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Full engine % tier % failed: %',v_kind,tier,r;END IF;
  SELECT * INTO row FROM battle_sessions WHERE id=b;SELECT to_jsonb(r0) INTO rule FROM battle_effect_catalog r0 WHERE element=lower(v_kind);
  value:=(rule->'effect_values'->>tier::text)::numeric;
  IF row.current_turn<>'p1' OR row.player1_action_points<>2 THEN RAISE EXCEPTION 'Synergy AP/turn mismatch %',r;END IF;
  CASE rule->>'effect_type'
   WHEN 'heal_percent' THEN IF row.player1_hp<>least(200,50+round(200*value/100)) THEN RAISE EXCEPTION 'Wrong healing % tier %, hp %, max %, result %',v_kind,tier,row.player1_hp,row.player1_max_hp,r;END IF;
   WHEN 'add_gauge' THEN IF row.player1_skill<>value THEN RAISE EXCEPTION 'Wrong gauge';END IF;
   WHEN 'shield_percent' THEN IF row.player1_synergy_shield<>value/100 THEN RAISE EXCEPTION 'Wrong shield';END IF;
   WHEN 'attack_debuff_percent' THEN IF row.player2_attack_debuff<>value/100 THEN RAISE EXCEPTION 'Wrong debuff';END IF;
   ELSE IF row.player2_hp<>200-round(40*value/100) THEN RAISE EXCEPTION 'Wrong burst: %',row.player2_hp;END IF;
  END CASE;
  IF coalesce((submit_battle_action('QA43-'||b,'p1','qa43-one','synergy',c,'{}')->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Duplicate Synergy succeeded';END IF;
  counter:=counter+1;
 END LOOP;END LOOP;
 -- A changed admin rule applies to future matches only; the full engine reads the frozen rule.
 b:=pg_temp.tbc_rule_fixture('Forest',2);SELECT id INTO c FROM battle_cards WHERE battle_id=b LIMIT 1;
 SELECT to_jsonb(r0) INTO before_rule FROM battle_effect_catalog r0 WHERE code='synergy_forest';
 PERFORM save_battle_effect_rule(before_rule||'{"name":"QA43 temporary rule","effect_values":{"2":10,"3":20,"4":30}}');
 r:=submit_battle_action('QA43-'||b,'p1','qa43-one','synergy',c,'{}');
 SELECT * INTO row FROM battle_sessions WHERE id=b;IF row.player1_hp<>110 THEN RAISE EXCEPTION 'Old match changed with admin edits';END IF;
 b:=pg_temp.tbc_rule_fixture('Forest',2);SELECT id INTO c FROM battle_cards WHERE battle_id=b LIMIT 1;
 r:=submit_battle_action('QA43-'||b,'p1','qa43-one','synergy',c,'{}');SELECT * INTO row FROM battle_sessions WHERE id=b;
 IF row.player1_hp<>70 THEN RAISE EXCEPTION 'New match did not use new rule';END IF;
 PERFORM save_battle_effect_rule('{"code":"qa43_patch","kind":"quiz_bonus","name":"QA43 Patch","effect_type":"heal_flat","effect_values":{"1":22},"enabled":true}');
 INSERT INTO coding_questions(id,question,option_a,option_b,option_c,option_d,correct_answer,duration_seconds) VALUES(q,'QA43 rollback quiz','Right','Wrong','Other','None','A',60);
 FOR n IN 1..6 LOOP
  PERFORM save_battle_reward_settings(n,(SELECT updated_at FROM battle_reward_settings WHERE id=1));
  b:=pg_temp.tbc_rule_fixture('Knight',2);qr:=gen_random_uuid();
  INSERT INTO battle_question_rounds(id,battle_id,question_id,round_number,status,started_at) VALUES(qr,b,q,1,'active',now());
  UPDATE battle_sessions SET status='question',question_active=true,question_bonus_enabled=true,current_question_id=q,current_question_round_id=qr WHERE id=b;
  r:=submit_battle_question_answer('QA43-'||b,'p1','qa43-one',qr,0);
  IF NOT coalesce((r->>'correct')::boolean,false) OR jsonb_array_length(r->'reward_choices')<>n THEN RAISE EXCEPTION 'Quiz reward % failed: %',n,r;END IF;
  projected:=get_public_battle_bonus_choice('QA43-'||b);
  IF jsonb_array_length(projected->'options')<>n OR projected->>'player'<>'p1' OR projected?'correct_answer' OR projected?'token' THEN RAISE EXCEPTION 'Public projection failed';END IF;
  IF coalesce((choose_battle_question_bonus('QA43-'||b,'p2','qa43-two',qr,r->'reward_choices'->>0)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Loser chose reward';END IF;
  v_kind:=CASE WHEN n=6 THEN 'qa43_patch' ELSE r->'reward_choices'->>0 END;
  r:=choose_battle_question_bonus('QA43-'||b,'p1','qa43-one',qr,v_kind);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Choose reward failed: %',r;END IF;
  SELECT id INTO bid FROM battle_bonus_skills WHERE battle_id=b AND player='p1';
  r:=use_battle_bonus_skill('QA43-'||b,'p1','qa43-one',bid);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Use reward failed: %',r;END IF;
  SELECT * INTO row FROM battle_sessions WHERE id=b;
  IF row.player1_action_points<>3 OR row.current_turn<>'p1' THEN RAISE EXCEPTION 'Bonus spent AP/turn';END IF;
  IF n=6 AND row.player1_hp<>72 THEN RAISE EXCEPTION 'Custom bonus healing mismatch';END IF;
  IF coalesce((use_battle_bonus_skill('QA43-'||b,'p1','qa43-one',bid)->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Bonus replayed';END IF;
 END LOOP;
 -- Every seeded quiz effect is executable through the guarded public RPC.
 FOREACH v_kind IN ARRAY ARRAY['power_strike','iron_guard','recovery','overcharge','cleanse'] LOOP
  b:=pg_temp.tbc_rule_fixture('Knight',2);UPDATE battle_sessions SET player1_attack_debuff=.4 WHERE id=b;
  INSERT INTO battle_bonus_skills(battle_id,player,skill_type,source) VALUES(b,'p1',v_kind,'quiz') RETURNING id INTO bid;
  r:=use_battle_bonus_skill('QA43-'||b,'p1','qa43-one',bid);SELECT * INTO row FROM battle_sessions WHERE id=b;
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Seeded bonus % failed: %',v_kind,r;END IF;
  IF (v_kind='power_strike' AND NOT row.player1_power_strike_ready) OR (v_kind='iron_guard' AND NOT row.player1_defending) OR (v_kind='recovery' AND row.player1_hp<>100) OR (v_kind='overcharge' AND row.player1_skill<>50) OR (v_kind='cleanse' AND row.player1_attack_debuff<>0) THEN RAISE EXCEPTION 'Seeded bonus % effect mismatch',v_kind;END IF;
 END LOOP;
 IF counter<>24 THEN RAISE EXCEPTION 'Tier coverage incomplete';END IF;
END $smoke$;
SELECT '24 full-engine Synergy tiers, AP/once guard, frozen admin edits, all 1–6 quiz offers, winner-only selection, public projection, custom and five default bonus effects passed' AS checks;
ROLLBACK;
