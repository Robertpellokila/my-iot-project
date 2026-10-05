-- Apply the existing TCG status rules as passives on successful targeted attacks.
-- Fire keeps its dedicated round-end damage/expiry handler. Water, Ice,
-- Electric and Grass use the existing turn-status settlement pipeline.

create or replace function public.tcg_apply_elemental_basic_passive(
  p_battle_id uuid,
  p_source_card_id uuid,
  p_target_card_id uuid,
  p_applied_round integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_source public.battle_cards%rowtype;
  v_target public.battle_cards%rowtype;
  v_element text := '';
  v_status_key text := '';
  v_rule jsonb := '{}'::jsonb;
  v_duration integer := 1;
  v_tick_damage integer := 0;
begin
  select * into v_battle from public.battle_sessions where id = p_battle_id;
  if not found or lower(coalesce(v_battle.ruleset,'')) <> 'tcg_v1'
     or lower(coalesce(v_battle.status,'')) = 'finished' then
    return jsonb_build_object('applied',false,'reason','not_running_tcg_v1');
  end if;

  select * into v_source from public.battle_cards
   where id = p_source_card_id and battle_id = p_battle_id;
  if not found then
    return jsonb_build_object('applied',false,'reason','source_not_found');
  end if;

  -- Card snapshots are preferred; older cards fall back to game_cards.element.
  v_element := lower(trim(coalesce(to_jsonb(v_source)->>'element','')));
  if v_element = '' and nullif(to_jsonb(v_source)->>'game_card_id','') is not null then
    select lower(trim(coalesce(gc.element,''))) into v_element
      from public.game_cards gc
     where gc.id = (to_jsonb(v_source)->>'game_card_id')::uuid;
  end if;

  if v_element = 'fire' then
    return public.tcg_apply_fire_basic_passive(
      p_battle_id,p_source_card_id,p_target_card_id,p_applied_round
    );
  end if;

  v_status_key := case v_element
    when 'water' then 'freeze'
    when 'ice' then 'freeze'
    when 'electric' then 'stun'
    when 'grass' then 'poison'
    else null
  end;

  if v_status_key is null then
    return jsonb_build_object('applied',false,'reason','no_passive_for_element','element',v_element);
  end if;

  v_rule := public.tcg_status_rule(v_status_key);
  v_duration := greatest(1,coalesce((v_rule->>'duration_turns')::integer,1));
  v_tick_damage := greatest(0,coalesce((v_rule->>'tick_damage')::integer,0));

  select * into v_target from public.battle_cards
   where id = p_target_card_id
     and battle_id = p_battle_id
     and player <> v_source.player
   for update;
  if not found or lower(coalesce(v_target.zone,'')) <> 'active'
     or coalesce(v_target.current_hp,0) <= 0 then
    return jsonb_build_object('applied',false,'reason','no_living_enemy_active_target');
  end if;

  if exists (
    select 1 from public.battle_status_effects s
     where s.battle_id = p_battle_id
       and s.target_card_id = p_target_card_id
       and lower(s.status_key) = v_status_key
       and coalesce(s.active,false)
  ) then
    return jsonb_build_object('applied',false,'reason','status_already_active','status_key',v_status_key);
  end if;

  insert into public.battle_status_effects (
    battle_id,source_player,source_card_id,target_player,target_card_id,
    scope,status_key,value,stacks,max_stacks,remaining_turns,remaining_rounds,
    consume_on,active,metadata
  ) values (
    p_battle_id,v_source.player,p_source_card_id,v_target.player,p_target_card_id,
    'card',v_status_key,to_jsonb(v_tick_damage),1,
    greatest(1,coalesce((v_rule->>'max_stacks')::integer,1)),
    v_duration,null,array[]::text[],true,
    v_rule || jsonb_build_object(
      'element',v_element,
      'source_trigger','elemental_passive',
      'applied_round',coalesce(p_applied_round,1)
    )
  );

  insert into public.battle_events (
    battle_id,type,source_player,target_player,card_id,payload
  ) values (
    p_battle_id,'status_applied',v_source.player,v_target.player,p_source_card_id,
    jsonb_build_object(
      'event_family','elemental',
      'effect_type','add_status',
      'source_trigger','elemental_passive',
      'status_key',v_status_key,
      'source_card_id',p_source_card_id,
      'target_card_id',p_target_card_id,
      'element',v_element,
      'remaining_turns',v_duration,
      'message',coalesce(v_rule->>'icon','✦') || ' ' || upper(v_status_key) || ' applied'
    )
  );

  return jsonb_build_object(
    'applied',true,'element',v_element,'status_key',v_status_key,
    'target_card_id',p_target_card_id,'remaining_turns',v_duration,
    'tick_damage',v_tick_damage
  );
end;
$function$;

revoke all on function public.tcg_apply_elemental_basic_passive(uuid,uuid,uuid,integer) from public, anon, authenticated;

create or replace function public.submit_battle_action(
  p_code text,
  p_player text,
  p_token text,
  p_action text,
  p_card_id uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_action text := lower(trim(coalesce(p_action,'')));
  v_player text := lower(trim(coalesce(p_player,'')));
  v_before public.battle_sessions%rowtype;
  v_after public.battle_sessions%rowtype;
  v_target_id uuid;
  v_target_before_hp integer;
  v_target_after public.battle_cards%rowtype;
  v_response jsonb;
  v_round_settlement jsonb := '{}'::jsonb;
  v_passive jsonb := '{}'::jsonb;
  v_round_completed boolean := false;
begin
  -- Snapshot only for comparison. The existing validated core remains the
  -- sole authority for accepting an action and applying its combat damage.
  select * into v_before
    from public.battle_sessions
   where upper(code) = upper(trim(coalesce(p_code,'')))
   limit 1;

  if v_action = 'attack' and v_before.id is not null and p_card_id is not null then
    begin
      v_target_id := nullif(trim(coalesce(p_payload->>'target_card_id','')),'')::uuid;
    exception when invalid_text_representation then
      v_target_id := null;
    end;

    if v_target_id is not null then
      select c.current_hp into v_target_before_hp
        from public.battle_cards c
       where c.id = v_target_id
         and c.battle_id = v_before.id
         and c.player <> v_player
         and c.zone = 'active';
    end if;
  end if;

  v_response := public.submit_battle_action_phase3d21_fire_core(
    p_code,p_player,p_token,p_action,p_card_id,coalesce(p_payload,'{}'::jsonb)
  );

  if not coalesce((v_response->>'ok')::boolean,false) or v_before.id is null then
    return v_response;
  end if;

  select * into v_after from public.battle_sessions where id = v_before.id;

  v_round_completed :=
    coalesce(v_after.round,1) > coalesce(v_before.round,1)
    or (
      v_player = 'p2' and v_before.current_turn = 'p2'
      and lower(coalesce(v_before.status,'')) <> 'finished'
      and lower(coalesce(v_after.status,'')) = 'finished'
    );

  -- Settle effects from the completed round before applying the P2 attack's
  -- new effect, so a new P2 burn survives until the next round end.
  if v_round_completed then
    v_round_settlement := public.tcg_settle_fire_round(
      v_before.id,coalesce(v_before.round,1)
    );
  end if;

  if lower(coalesce(v_after.status,'')) = 'finished' and not v_round_completed then
    update public.battle_status_effects
       set active = false, remaining_turns = 0, remaining_rounds = 0
     where battle_id = v_before.id and coalesce(active,false);
  end if;

  -- A passive only follows a successful targeted attack that damaged and did
  -- not destroy the opponent's active card. Direct attacks never apply one.
  if v_action = 'attack'
     and v_target_id is not null
     and v_target_before_hp is not null
     and lower(coalesce(v_after.status,'')) <> 'finished' then
    select * into v_target_after
      from public.battle_cards
     where id = v_target_id and battle_id = v_before.id;

    if found and v_target_after.zone = 'active'
       and coalesce(v_target_after.current_hp,0) > 0
       and v_target_after.current_hp < v_target_before_hp then
      v_passive := public.tcg_apply_elemental_basic_passive(
        v_before.id,p_card_id,v_target_id,coalesce(v_before.round,1)
      );
    end if;
  end if;

  return v_response || jsonb_build_object(
    'elemental_passive',v_passive,
    'elemental_round_settlement',v_round_settlement
  );
end;
$function$;
