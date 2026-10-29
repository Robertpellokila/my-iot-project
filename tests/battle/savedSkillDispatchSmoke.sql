-- Run inside a rollback transaction after migration 051. Inactive definitions
-- remain explicit audit findings; they are not silently activated here.
CREATE TEMP TABLE skill_dispatch_audit_results(activations integer);
DO $smoke$
DECLARE c record; skill record; option_item jsonb; choice_id text; b uuid; src uuid; enemy uuid; ally uuid; bench uuid; dead uuid; s uuid; tid uuid; r jsonb; count_ok integer:=0; program jsonb; original_hp integer; expected integer; actual integer; copy_master uuid; copy_runtime uuid;
BEGIN
 FOR c IN SELECT * FROM game_cards WHERE metadata#>>'{studio_card,source_pilot_code}' IS NOT NULL AND archived_at IS NULL AND uid IS NULL ORDER BY id LOOP
  FOR skill IN SELECT ss.*,g.sort_order FROM game_card_special_skills g JOIN special_skills ss ON ss.id=g.special_skill_id WHERE g.game_card_id=c.id AND ss.metadata->>'studio_generated'='true' ORDER BY g.sort_order LOOP
   IF NOT skill.is_active THEN CONTINUE; END IF;
   program:=skill.effects#>'{0,program}';
   FOR option_item IN SELECT value FROM jsonb_array_elements(CASE WHEN jsonb_array_length(program->'choices')>0 THEN program->'choices' ELSE '[{"id":""}]' END) LOOP
    PERFORM set_config('tcg.intra_turn_action','off',true);
    b:=gen_random_uuid();src:=gen_random_uuid();enemy:=gen_random_uuid();ally:=gen_random_uuid();bench:=gen_random_uuid();dead:=gen_random_uuid();
    INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,total_rounds,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,question_enabled,question_active,special_card_skills_enabled,action_points_enabled,action_points_per_turn,player1_action_points,player2_action_points,player1_deck_remaining,player2_deck_remaining,turn_index,turn_duration_seconds,turn_started_at,turn_deadline_at,max_active,max_bench,max_attacks_per_card,destruction_damage_enabled)
    VALUES(b,'SKILL-QA-'||b,'tcg_v1','battle','p1',1,50,'qa-p1-'||b::text,'qa-p2-'||b::text,200,200,200,200,false,false,true,true,10,10,0,20,20,1,60,now(),now()+interval '1 minute',4,4,1,true);
    INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element,origin_type,card_kind)
    VALUES(src,b,'p1',c.id,CASE WHEN c.fusion_only THEN NULL ELSE gen_random_uuid()::text END,c.name,'active',1,c.hp,c.hp,greatest(1,round(c.hp*.75)::integer),c.attack,c.defense,c.element,CASE WHEN c.fusion_only THEN 'fusion' ELSE 'rfid' END,CASE WHEN c.fusion_only THEN 'fusion' ELSE 'normal' END),
      (enemy,b,'p2',NULL,gen_random_uuid()::text,'Enemy','active',1,300,300,300,30,10,'Water','rfid','normal'),
      (ally,b,'p1',NULL,gen_random_uuid()::text,'Ally','active',2,200,200,50,30,10,'Water','rfid','normal'),
      (bench,b,'p1',NULL,gen_random_uuid()::text,'Bench','bench',NULL,200,200,100,30,10,'Water','rfid','normal'),
      (dead,b,'p1',NULL,gen_random_uuid()::text,'Base in graveyard','graveyard',NULL,100,100,0,30,10,'Water','rfid','normal');
    IF (SELECT count(*) FROM battle_card_skills WHERE battle_card_id=src)<>(SELECT count(*) FROM game_card_special_skills g JOIN special_skills ss ON ss.id=g.special_skill_id WHERE g.game_card_id=c.id AND g.enabled AND ss.is_active) THEN RAISE EXCEPTION 'Active binding/runtime mismatch for %',c.name; END IF;
    SELECT id INTO s FROM battle_card_skills WHERE battle_card_id=src AND special_skill_id=skill.id;
    tid:=CASE program->>'target' WHEN 'enemy_active' THEN enemy WHEN 'self_card' THEN src WHEN 'ally_graveyard' THEN dead ELSE ally END;
    -- Set a debuff for cleanse and conditional attacks, without impacting DEF.
    PERFORM public.tcg_studio_status(b,src,enemy,'root',1,'next_end');
    PERFORM public.tcg_apply_combo_status(b,'p1',src,enemy,'burn',0,'{"tick_damage":10}');
    PERFORM public.tcg_apply_combo_status(b,'p2',enemy,ally,'burn',0,'{"tick_damage":10}');
    IF program#>>'{operations,0,condition}'='self_shield' THEN PERFORM public.tcg_studio_status(b,src,src,'studio_shield',5); END IF;
    IF program#>>'{operations,0,condition}'='self_switched' THEN UPDATE battle_cards SET battle_metadata=battle_metadata||'{"studio_switched_turn":1}' WHERE id=src; END IF;
    IF program#>>'{operations,0,condition}'='ally_switched' THEN UPDATE battle_cards SET battle_metadata=battle_metadata||'{"studio_switched_turn":1}' WHERE id=ally; END IF;
    r:=public.submit_battle_action('SKILL-QA-'||b,'p1','qa-p1-'||b::text,'special_skill',src,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid(),'target_card_id',tid,'bench_card_id',bench,'skill_option',option_item->>'id','target_card_ids',CASE WHEN (program->>'max_targets')::integer=2 THEN jsonb_build_array(enemy) ELSE '[]'::jsonb END));
    IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION '% / % / % rejected: %',c.name,skill.name,option_item->>'id',r; END IF;
    IF (SELECT player1_action_points FROM battle_sessions WHERE id=b)<>10-coalesce((skill.limits->>'action_points')::integer,1) THEN RAISE EXCEPTION 'AP mismatch % %',c.name,skill.name; END IF;
    IF (SELECT count(*) FROM battle_special_skill_uses WHERE battle_card_skill_id=s)<>1 THEN RAISE EXCEPTION 'Usage missing'; END IF;
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(program->'operations') item WHERE item->>'type'='attack') THEN
      expected:=greatest(1,round(c.attack*coalesce((program#>>'{operations,0,multiplier}')::numeric,1))::integer+coalesce((program#>>'{operations,0,amount}')::integer,0)-10);
      IF (SELECT 300-current_hp FROM battle_cards WHERE id=enemy)<>expected THEN RAISE EXCEPTION 'Actual damage mismatch % % expected % response %',c.name,skill.name,expected,r; END IF;
    END IF;
    IF program#>>'{operations,0,type}'='heal' OR option_item->>'id'='heal' THEN
      expected:=coalesce((option_item#>>'{operations,0,amount}')::integer,(program#>>'{operations,0,amount}')::integer);
      IF (SELECT current_hp FROM battle_cards WHERE id=tid)<>50+expected THEN RAISE EXCEPTION 'Heal mismatch %',skill.name; END IF;
    END IF;
    IF program#>>'{operations,0,type}'='revive' THEN
      IF (SELECT current_hp FROM battle_cards WHERE id=dead)<>40 OR (SELECT zone FROM battle_cards WHERE id=dead)<>'bench' THEN RAISE EXCEPTION 'Revive HP/zone mismatch'; END IF;
      IF public.tcg_card_action_block_reason(b,dead,'attack') IS NULL THEN RAISE EXCEPTION 'Revived card not blocked'; END IF;
    END IF;
    IF program#>>'{operations,0,type}'='switch' AND (SELECT zone FROM battle_cards WHERE id=bench)<>'active' THEN RAISE EXCEPTION 'Switch failed'; END IF;
    IF skill.limits->>'once_per_battle'='true' THEN
      r:=public.submit_battle_action('SKILL-QA-'||b,'p1','qa-p1-'||b::text,'special_skill',src,jsonb_build_object('skill_id',s,'action_id',gen_random_uuid(),'target_card_id',tid,'skill_option',option_item->>'id'));
      IF coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Once per battle bypass'; END IF;
    END IF;
    count_ok:=count_ok+1;
   END LOOP;
  END LOOP;
  -- A real RFID instance needs only its UID and source data; the save trigger
  -- creates bindings before the battle snapshot sees the card. Draft skills
  -- must remain excluded on the copy just as they are on the source.
  IF NOT c.fusion_only THEN
    copy_master:=gen_random_uuid();copy_runtime:=gen_random_uuid();
    INSERT INTO game_cards(id,uid,name,card_code,element,hp,attack,defense,rarity,card_kind,fusion_only,physical_scan_enabled,metadata,tags) VALUES(copy_master,gen_random_uuid()::text,c.name,c.card_code,c.element,c.hp,c.attack,c.defense,c.rarity,'normal',false,true,(c.metadata-'timedoor_seed_key')||jsonb_build_object('catalog_source_id',c.id),c.tags);
    INSERT INTO battle_cards(id,battle_id,player,game_card_id,uid,name,zone,slot,hp,base_hp,current_hp,attack,defense,element) VALUES(copy_runtime,b,'p1',copy_master,gen_random_uuid()::text,c.name,'bench',NULL,c.hp,c.hp,c.hp,c.attack,c.defense,c.element);
    IF (SELECT count(*) FROM battle_card_skills WHERE battle_card_id=copy_runtime)<>(SELECT count(*) FROM battle_card_skills WHERE battle_card_id=src) THEN RAISE EXCEPTION 'RFID copy lost active skill %',c.name; END IF;
  END IF;
 END LOOP;
 IF count_ok<88 THEN RAISE EXCEPTION 'Expected at least 88 skill/choice activations, got %',count_ok; END IF;
 INSERT INTO skill_dispatch_audit_results VALUES(count_ok);
END $smoke$;
