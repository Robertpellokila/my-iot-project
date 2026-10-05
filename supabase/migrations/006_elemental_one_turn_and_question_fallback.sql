-- All elemental attack effects last for exactly one target turn.
-- Dark applies Curse; Fire now uses the standard turn tick/expiry pipeline.
CREATE OR REPLACE FUNCTION public.tcg_status_rule(p_status_key text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(trim(coalesce(p_status_key, '')))
    when 'defense' then jsonb_build_object(
      'status_key','defense',
      'kind','buff',
      'source','action_or_skill',
      'effect','incoming_damage_percent',
      'value',0.50,
      'duration','consume_on_hit',
      'max_stacks',1,
      'icon','🛡',
      'tone','defense'
    )
    when 'water_shield' then jsonb_build_object(
      'status_key','water_shield',
      'kind','buff',
      'source','synergy_or_skill',
      'effect','incoming_damage_percent',
      'duration','consume_on_hit',
      'max_stacks',1,
      'icon','💧',
      'tone','water'
    )
    when 'shield' then jsonb_build_object(
      'status_key','shield',
      'kind','buff',
      'source','skill_or_passive',
      'effect','shield',
      'duration','configured',
      'max_stacks',1,
      'icon','💧',
      'tone','water'
    )
    when 'burn' then jsonb_build_object(
      'status_key','burn',
      'kind','debuff',
      'recommended_source','fire_special_or_ultimate',
      'tick_phase','end_owner_turn',
      'tick_damage',10,
      'duration_turns',1,
      'max_stacks',3,
      'blocks_actions','[]'::jsonb,
      'icon','🔥',
      'tone','burn'
    )
    when 'freeze' then jsonb_build_object(
      'status_key','freeze',
      'kind','control',
      'recommended_source','water_or_ice_special',
      'tick_phase','end_owner_turn',
      'tick_damage',0,
      'duration_turns',1,
      'max_stacks',1,
      'blocks_actions',jsonb_build_array('attack','ultimate'),
      'icon','🧊',
      'tone','freeze'
    )
    when 'poison' then jsonb_build_object(
      'status_key','poison',
      'kind','debuff',
      'recommended_source','grass_or_necro_special',
      'tick_phase','end_owner_turn',
      'tick_damage',8,
      'duration_turns',1,
      'max_stacks',3,
      'blocks_actions','[]'::jsonb,
      'icon','☠',
      'tone','poison'
    )
    when 'stun' then jsonb_build_object(
      'status_key','stun',
      'kind','control',
      'recommended_source','electric_special',
      'tick_phase','end_owner_turn',
      'tick_damage',0,
      'duration_turns',1,
      'max_stacks',1,
      'blocks_actions',jsonb_build_array('attack','defense','ultimate','heal','synergy','special_skill'),
      'icon','💫',
      'tone','stun'
    )
    when 'curse' then jsonb_build_object(
      'status_key','curse',
      'kind','debuff',
      'recommended_source','dark_basic_attack',
      'tick_phase','end_owner_turn',
      'tick_damage',8,
      'duration_turns',1,
      'max_stacks',1,
      'blocks_actions','[]'::jsonb,
      'icon','🌑',
      'tone','curse'
    )
    when 'necro' then jsonb_build_object(
      'status_key','necro',
      'kind','identity',
      'source','card_tag_or_element',
      'effect','graveyard_archetype',
      'icon','☠',
      'tone','necro'
    )
    when 'fusion' then jsonb_build_object(
      'status_key','fusion',
      'kind','identity',
      'source','is_fusion_result',
      'effect','fusion_identity',
      'icon','🧬',
      'tone','fusion'
    )
    else jsonb_build_object(
      'status_key',lower(trim(coalesce(p_status_key,''))),
      'kind','generic',
      'icon','✦',
      'tone','buff'
    )
  end;
$function$
;

CREATE OR REPLACE FUNCTION public.tcg_tick_statuses_for_player(p_battle_id uuid, p_player text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_player text := lower(trim(coalesce(p_player,'')));
  v_row record;
  v_card public.battle_cards%rowtype;
  v_key text;
  v_rule jsonb;
  v_tick_damage integer := 0;
  v_stacks integer := 1;
  v_hp_before integer := 0;
  v_hp_after integer := 0;
  v_total_damage integer := 0;
  v_destroyed_count integer := 0;
  v_ticked integer := 0;
  v_expired integer := 0;
  v_previous_zone text;
begin
  if v_player not in ('p1','p2') then
    return jsonb_build_object('ok',false,'message','Invalid player.');
  end if;

  for v_row in
    select s.*
    from public.battle_status_effects s
    join public.battle_cards c
      on c.id = s.target_card_id
     and c.battle_id = s.battle_id
    where s.battle_id = p_battle_id
      and c.player = v_player
      and coalesce(s.active,false) = true
      and lower(s.scope) = 'card'
      and lower(s.status_key) in ('burn','poison','freeze','frozen','stun','curse')
    for update of s
  loop
    v_key := case lower(v_row.status_key)
      when 'frozen' then 'freeze'
      else lower(v_row.status_key)
    end;

    select * into v_card
    from public.battle_cards
    where id = v_row.target_card_id
      and battle_id = p_battle_id
    for update;

    if not found or lower(coalesce(v_card.zone,'')) = 'graveyard' then
      update public.battle_status_effects
      set active = false
      where battle_id = p_battle_id
        and target_card_id = v_row.target_card_id
        and lower(status_key) = lower(v_row.status_key)
        and coalesce(active,false) = true;
      continue;
    end if;

    v_rule := public.tcg_status_rule(v_key);
    v_stacks := greatest(1,least(
      coalesce((v_rule ->> 'max_stacks')::integer,1),
      coalesce(v_row.stacks,1)
    ));
    v_tick_damage := greatest(
      0,
      coalesce(
        (v_row.metadata ->> 'tick_damage')::integer,
        (v_rule ->> 'tick_damage')::integer,
        0
      ) * v_stacks
    );

    if v_tick_damage > 0 then
      v_hp_before := greatest(0,coalesce(v_card.current_hp,v_card.base_hp,0));
      v_hp_after := greatest(0,v_hp_before - v_tick_damage);
      v_previous_zone := v_card.zone;

      if v_hp_after <= 0 then
        update public.battle_cards
        set current_hp = 0,
            zone = 'graveyard',
            exhausted = true,
            destroyed_at = now(),
            graveyard_at = now(),
            graveyard_reason = v_key
        where id = v_card.id;

        update public.battle_status_effects
        set active = false
        where battle_id = p_battle_id
          and target_card_id = v_card.id
          and coalesce(active,false) = true;

        v_destroyed_count := v_destroyed_count + 1;

        insert into public.battle_events(
          battle_id,type,source_player,target_player,card_id,payload
        ) values (
          p_battle_id,
          'card_destroyed',
          v_row.source_player,
          v_player,
          v_card.id,
          jsonb_build_object(
            'reason',v_key,
            'target_card_id',v_card.id,
            'previous_zone',v_previous_zone,
            'zone','graveyard',
            'effective_damage',least(v_hp_before,v_tick_damage),
            'final_damage',v_tick_damage,
            'player_damage',0,
            'status_key',v_key,
            'message',upper(v_key) || ' destroyed the Card'
          )
        );
      else
        update public.battle_cards
        set current_hp = v_hp_after
        where id = v_card.id;
      end if;

      v_total_damage := v_total_damage + least(v_hp_before,v_tick_damage);

      insert into public.battle_events(
        battle_id,type,source_player,target_player,card_id,payload
      ) values (
        p_battle_id,
        'status_tick',
        v_row.source_player,
        v_player,
        v_card.id,
        jsonb_build_object(
          'event_family','skill',
          'effect_type','status_tick',
          'status_key',v_key,
          'target_card_id',v_card.id,
          'stacks',v_stacks,
          'damage',least(v_hp_before,v_tick_damage),
          'target_hp_before',v_hp_before,
          'target_hp_after',v_hp_after,
          'destroyed',v_hp_after <= 0,
          'message',upper(v_key) || ' -' || least(v_hp_before,v_tick_damage) || ' HP'
        )
      );

      if v_hp_after <= 0 then
        v_ticked := v_ticked + 1;
        continue;
      end if;
    end if;

    v_ticked := v_ticked + 1;

    if coalesce(v_row.remaining_turns,0) > 0 then
      if v_row.remaining_turns <= 1 then
        update public.battle_status_effects
        set active = false,
            remaining_turns = 0
        where battle_id = p_battle_id
          and target_card_id = v_row.target_card_id
          and lower(status_key) = lower(v_row.status_key)
          and coalesce(active,false) = true;

        v_expired := v_expired + 1;

        insert into public.battle_events(
          battle_id,type,source_player,target_player,card_id,payload
        ) values (
          p_battle_id,
          'status_expired',
          v_row.source_player,
          v_player,
          v_row.target_card_id,
          jsonb_build_object(
            'event_family','skill',
            'status_key',v_key,
            'target_card_id',v_row.target_card_id,
            'message',upper(v_key) || ' expired'
          )
        );
      else
        update public.battle_status_effects
        set remaining_turns = remaining_turns - 1
        where battle_id = p_battle_id
          and target_card_id = v_row.target_card_id
          and lower(status_key) = lower(v_row.status_key)
          and coalesce(active,false) = true;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'player',v_player,
    'ticked_statuses',v_ticked,
    'expired_statuses',v_expired,
    'damage',v_total_damage,
    'destroyed',v_destroyed_count
  );
end;
$function$
;

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

  v_status_key := case v_element
    when 'water' then 'freeze'
    when 'ice' then 'freeze'
    when 'electric' then 'stun'
    when 'grass' then 'poison'
    when 'dark' then 'curse'
    else null
  end;

  if v_status_key is null then
    return jsonb_build_object('applied',false,'reason','no_passive_for_element','element',v_element);
  end if;

  v_rule := public.tcg_status_rule(v_status_key);
  -- Every attack passive expires after the target completes one turn.
  v_duration := 1;
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
      'icon',case v_status_key when 'burn' then '🔥' when 'freeze' then '🧊' when 'stun' then '💫' when 'poison' then '☠' else '🌑' end,
      'label',case v_status_key when 'burn' then 'BURN' when 'freeze' then 'FREEZE' when 'stun' then 'STUN' when 'poison' then 'POISON' else 'CURSE' end,
      'tone',v_status_key,
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
  v_question_fallback jsonb := '{}'::jsonb;
  v_question_interval integer := 0;
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

  -- The legacy core silently skips a scheduled question if the selected
  -- difficulty has no active rows. Retry through the guarded public helper,
  -- which honors the configured level and falls back only when that level is empty.
  v_question_interval := greatest(0,coalesce(v_before.question_every_rounds,0));
  if v_round_completed
     and coalesce(v_before.question_enabled,false)
     and v_question_interval > 0
     and mod(greatest(1,coalesce(v_before.round,1)),v_question_interval) = 0
     and not coalesce(v_after.question_active,false)
     and lower(coalesce(v_after.status,'')) <> 'finished' then
    v_question_fallback := public.start_battle_question(
      v_before.id,greatest(1,coalesce(v_before.round,1))
    );
    select * into v_after from public.battle_sessions where id = v_before.id;
  end if;

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
    'elemental_round_settlement',v_round_settlement,
    'question_fallback',v_question_fallback
  );
end;
$function$;
