-- The legacy dispatcher accepted special_skill but fell through to generic
-- success without calling its executor. Restore the branch inside the existing
-- token/turn/status guards; retain the outer AP and idempotency transaction.
BEGIN;
DO $patch$
DECLARE source text; patched text; needle text;
BEGIN
 source:=pg_get_functiondef('public.submit_battle_action_core_3d15(text,text,text,text,uuid,jsonb)'::regprocedure);
 IF strpos(source,'public.process_special_skill(')=0 THEN
   needle:=E'  if p_action =\n    ''attack''\n  then';
   IF strpos(source,needle)=0 THEN RAISE EXCEPTION 'Unrecognized battle action dispatcher; no patch applied.'; END IF;
   patched:=replace(source,needle,$branch$
  if p_action = 'special_skill' then
    v_special_result := public.process_special_skill(v_battle.id,p_player,p_card_id,coalesce(p_payload,'{}'::jsonb));
    if not coalesce((v_special_result->>'ok')::boolean,false) then return v_special_result; end if;
    v_special_ends_turn := coalesce((v_special_result->>'ends_turn')::boolean,true);
    -- The AP wrapper owns turn transitions; return the actual effect result.
    if not v_special_ends_turn or coalesce(current_setting('tcg.intra_turn_action',true),'off')='on' then return v_special_result; end if;
    select * into v_battle from public.battle_sessions where id=v_battle.id;
    v_damage:=coalesce((v_special_result->>'damage')::integer,0);
    v_actual_heal:=coalesce((v_special_result->>'heal')::integer,0);
  elsif p_action = 'attack' then$branch$);
   needle:='  if p_action = ''fusion'' then';
   IF strpos(patched,needle)=0 THEN RAISE EXCEPTION 'Unrecognized battle response; no patch applied.'; END IF;
   patched:=replace(patched,needle,$response$
  if p_action = 'special_skill' then
    return v_special_result || jsonb_build_object('next_turn',v_next_player,'round',v_next_round,'question_active',v_battle.question_active);
  end if;
  if p_action = 'fusion' then$response$);
   EXECUTE patched;
 END IF;
 source:=pg_get_functiondef('public.tcg_submit_battle_action_core_v2(text,text,text,text,uuid,jsonb)'::regprocedure);
 IF strpos(source,'Special skills can explicitly end a turn')=0 THEN
   needle:='  PERFORM public.tcg_sync_legacy_card_visual_status(v_battle.id, v_player, v_action, p_card_id);';
   IF strpos(source,needle)=0 THEN RAISE EXCEPTION 'Unrecognized AP finalization; no patch applied.'; END IF;
   source:=replace(source,needle,$ap$
  -- Special skills can explicitly end a turn while AP remain.
  IF v_action='special_skill' AND coalesce((v_response->>'ends_turn')::boolean,false) THEN v_ap_after:=0; END IF;
$ap$||needle);
   EXECUTE source;
 END IF;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
