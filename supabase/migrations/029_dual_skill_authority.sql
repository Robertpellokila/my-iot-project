-- Keep legacy round cooldowns. Explicit cooldown_turns uses persistent owner turns.
ALTER TABLE public.battle_sessions ADD COLUMN IF NOT EXISTS player1_owner_turn integer NOT NULL DEFAULT 0;
ALTER TABLE public.battle_sessions ADD COLUMN IF NOT EXISTS player2_owner_turn integer NOT NULL DEFAULT 0;
UPDATE public.battle_sessions SET player1_owner_turn = greatest(1,coalesce(round,1)),
 player2_owner_turn = greatest(0,coalesce(round,1)-CASE WHEN current_turn='p1' THEN 1 ELSE 0 END)
 WHERE player1_owner_turn=0 AND player2_owner_turn=0;
ALTER TABLE public.battle_card_skills ADD COLUMN IF NOT EXISTS cooldown_until_owner_turn integer;
CREATE OR REPLACE FUNCTION public.tcg_owner_turn_clock() RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF current_setting('tcg.intra_turn_action',true)='on' THEN RETURN NEW; END IF;
 IF NEW.status='finished' THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' THEN
  NEW.player1_owner_turn:=CASE WHEN NEW.current_turn='p1' THEN 1 ELSE 0 END;
  NEW.player2_owner_turn:=CASE WHEN NEW.current_turn='p2' THEN 1 ELSE 0 END;
 ELSIF NEW.current_turn IS DISTINCT FROM OLD.current_turn THEN
  IF NEW.current_turn='p1' THEN NEW.player1_owner_turn:=OLD.player1_owner_turn+1; END IF;
  IF NEW.current_turn='p2' THEN NEW.player2_owner_turn:=OLD.player2_owner_turn+1; END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tcg_owner_turn_clock ON public.battle_sessions;
CREATE TRIGGER tcg_owner_turn_clock BEFORE INSERT OR UPDATE ON public.battle_sessions FOR EACH ROW EXECUTE FUNCTION public.tcg_owner_turn_clock();

CREATE TABLE IF NOT EXISTS public.battle_action_receipts (
 battle_id uuid NOT NULL REFERENCES public.battle_sessions(id) ON DELETE CASCADE,
 player text NOT NULL CHECK(player IN ('p1','p2')), request_id uuid NOT NULL,
 request jsonb NOT NULL, response jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(battle_id,player,request_id));
ALTER TABLE public.battle_action_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.battle_action_receipts FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.process_special_skill(p_battle_id uuid, p_player text, p_card_id uuid, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_source_card public.battle_cards%rowtype;
  v_target_card public.battle_cards%rowtype;
  v_card_skill public.battle_card_skills%rowtype;
  v_enemy text;
  v_target_player text := null;
  v_skill_id uuid := null;
  v_target_card_id uuid := null;
  v_target_spec jsonb := '{}'::jsonb;
  v_cost_spec jsonb := '{}'::jsonb;
  v_limits jsonb := '{}'::jsonb;
  v_effects jsonb := '[]'::jsonb;
  v_source_zones jsonb := '[]'::jsonb;
  v_target_type text := '';
  v_target_required boolean := false;
  v_once_per_battle boolean := false;
  v_max_uses integer := null;
  v_cooldown_rounds integer := 0;
  v_owner_cd integer;
  v_owner_turn integer;
  v_uses_count integer := 0;
  v_usage_number integer := 1;
  v_cost_type text := 'none';
  v_cost_value integer := 0;
  v_current_gauge integer := 0;
  v_effect_result jsonb := '{}'::jsonb;
  v_damage integer := 0;
  v_heal integer := 0;
  v_ends_turn boolean := true;
  v_zone_allowed boolean := false;
begin
  p_player :=
    lower(
      trim(
        coalesce(
          p_player,
          ''
        )
      )
    );
  if p_player not in ('p1', 'p2') then
    return jsonb_build_object(
      'ok', false,
      'message', 'Invalid player.'
    );
  end if;
  v_enemy :=
    case
      when p_player = 'p1'
        then 'p2'
      else 'p1'
    end;
  select *
  into v_battle
  from public.battle_sessions
  where id = p_battle_id
  for update;
  if not found then
    return jsonb_build_object(
      'ok', false,
      'message', 'Battle tidak ditemukan.'
    );
  end if;
  if lower(
    coalesce(
      v_battle.ruleset,
      'classic'
    )
  ) <> 'tcg_v1'
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Special Skill hanya tersedia pada TCG V1.'
    );
  end if;
  if not coalesce(
    v_battle.special_card_skills_enabled,
    false
  )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Special Skill sedang dinonaktifkan.'
    );
  end if;
  if
    v_battle.status <> 'battle'
    or
    v_battle.winner is not null
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Battle sedang tidak menerima action.'
    );
  end if;
  if coalesce(
    v_battle.question_active,
    false
  )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Coding Challenge sedang aktif.'
    );
  end if;
  if v_battle.current_turn <> p_player then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Belum giliran kamu.'
    );
  end if;
  v_skill_id :=
    coalesce(
      public.tcg_try_uuid(
        p_payload
          ->> 'battle_card_skill_id'
      ),
      public.tcg_try_uuid(
        p_payload
          ->> 'skill_id'
      )
    );
  if v_skill_id is null then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Battle Card Skill ID tidak valid.'
    );
  end if;
  v_target_card_id :=
    public.tcg_try_uuid(
      p_payload
        ->> 'target_card_id'
    );
  select *
  into v_source_card
  from public.battle_cards
  where id = p_card_id
    and battle_id = p_battle_id
    and player = p_player
  for update;
  if not found then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Source Card tidak ditemukan.'
    );
  end if;
  if coalesce(
    v_source_card.current_hp,
    v_source_card.base_hp,
    v_source_card.hp,
    0
  ) <= 0
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Source Card sudah tidak memiliki HP.'
    );
  end if;
  select *
  into v_card_skill
  from public.battle_card_skills
  where id = v_skill_id
    and battle_id = p_battle_id
    and battle_card_id = p_card_id
    and player = p_player
  for update;
  if not found then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Special Skill tidak ditemukan pada Card ini.'
    );
  end if;
  IF v_card_skill.disabled OR v_card_skill.activation_timing <> 'main_phase' THEN
    RETURN jsonb_build_object('ok',false,'message','Skill sedang dinonaktifkan.');
  END IF;
  v_owner_turn := CASE WHEN p_player='p1' THEN v_battle.player1_owner_turn ELSE v_battle.player2_owner_turn END;
  IF v_card_skill.limits ? 'cooldown_turns' THEN
    IF coalesce(v_card_skill.limits->>'cooldown_turns','') !~ '^\d{1,3}$' THEN
      RETURN jsonb_build_object('ok',false,'message','Cooldown skill tidak valid.');
    END IF;
    v_owner_cd := (v_card_skill.limits->>'cooldown_turns')::integer;
    IF v_owner_turn <= v_card_skill.cooldown_until_owner_turn THEN
      RETURN jsonb_build_object('ok',false,'code','SKILL_COOLDOWN','message','Skill masih cooldown.',
        'cooldown_remaining',v_card_skill.cooldown_until_owner_turn-v_owner_turn+1);
    END IF;
  END IF;
  v_target_spec :=
    coalesce(
      v_card_skill.target_spec,
      '{}'::jsonb
    );
  v_cost_spec :=
    coalesce(
      v_card_skill.cost_spec,
      '{}'::jsonb
    );
  v_limits :=
    coalesce(
      v_card_skill.limits,
      '{}'::jsonb
    );
  v_effects :=
    coalesce(
      v_card_skill.effects,
      '[]'::jsonb
    );
  v_source_zones :=
    coalesce(
      to_jsonb(
        v_card_skill.source_zones
      ),
      '[]'::jsonb
    );
  v_ends_turn :=
    coalesce(
      v_card_skill.consumes_turn,
      true
    );
  if
    jsonb_typeof(v_source_zones) = 'array'
    and
    jsonb_array_length(v_source_zones) > 0
  then
    select exists (
      select 1
      from jsonb_array_elements_text(
        v_source_zones
      ) as zone_value
      where lower(zone_value) =
        lower(v_source_card.zone)
    )
    into v_zone_allowed;
    if not v_zone_allowed then
      return jsonb_build_object(
        'ok', false,
        'source_zone',
        v_source_card.zone,
        'message',
        'Special Skill tidak dapat digunakan dari zone ini.'
      );
    end if;
  else
    if v_source_card.zone <> 'active' then
      return jsonb_build_object(
        'ok', false,
        'message',
        'Special Skill hanya dapat digunakan oleh Active Card.'
      );
    end if;
  end if;
  if coalesce(
    v_source_card.exhausted,
    false
  )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Source Card sudah exhausted.'
    );
  end if;
  if
    jsonb_typeof(v_effects) <> 'array'
    or
    jsonb_array_length(v_effects) = 0
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Special Skill belum memiliki effect.'
    );
  end if;
  begin
    v_once_per_battle :=
      coalesce(
        (
          v_limits
            ->> 'once_per_battle'
        )::boolean,
        false
      );
    v_max_uses :=
      nullif(
        greatest(
          0,
          coalesce(
            (
              v_limits
                ->> 'max_uses'
            )::integer,
            0
          )
        ),
        0
      );
    v_cooldown_rounds :=
      greatest(
        0,
        coalesce(
          (
            v_limits
              ->> 'cooldown_rounds'
          )::integer,
          (
            v_limits
              ->> 'cooldown'
          )::integer,
          0
        )
      );
  exception
    when others then
      return jsonb_build_object(
        'ok', false,
        'message',
        'Konfigurasi limits Special Skill tidak valid.'
      );
  end;
  IF v_owner_cd IS NOT NULL THEN v_cooldown_rounds := 0; END IF;
  if v_once_per_battle then
    v_max_uses := 1;
  end if;
  select count(*)
  into v_uses_count
  from public.battle_special_skill_uses
  where battle_id = p_battle_id
    and battle_card_skill_id =
      v_card_skill.id;
  v_usage_number :=
    v_uses_count + 1;
  if
    v_max_uses is not null
    and
    v_uses_count >= v_max_uses
  then
    return jsonb_build_object(
      'ok', false,
      'uses_count',
      v_uses_count,
      'max_uses',
      v_max_uses,
      'message',
      case
        when v_once_per_battle
          then 'Special Skill ini hanya dapat digunakan sekali dalam battle.'
        else 'Batas penggunaan Special Skill sudah tercapai.'
      end
    );
  end if;
  if
    v_owner_cd IS NULL AND v_card_skill.cooldown_until_round
      is not null
    and
    coalesce(
      v_battle.round,
      1
    )
    <=
    v_card_skill.cooldown_until_round
  then
    return jsonb_build_object(
      'ok', false,
      'cooldown',
      true,
      'cooldown_until_round',
      v_card_skill.cooldown_until_round,
      'available_round',
      v_card_skill.cooldown_until_round + 1,
      'message',
      'Special Skill masih cooldown.'
    );
  end if;
  v_target_type :=
    lower(
      trim(
        coalesce(
          v_target_spec ->> 'type',
          v_target_spec ->> 'target',
          v_target_spec ->> 'mode',
          ''
        )
      )
    );
  begin
    v_target_required :=
      coalesce(
        (
          v_target_spec
            ->> 'required'
        )::boolean,
        false
      );
  exception
    when others then
      v_target_required := false;
  end;
  if v_target_type in (
    'enemy_active',
    'ally_active',
    'any_active',
    'enemy_graveyard',
    'ally_graveyard',
    'any_card'
  )
  then
    v_target_required := true;
  end if;
  if v_target_type in (
    'self',
    'self_card',
    'source_card'
  )
  then
    v_target_card_id :=
      v_source_card.id;
    v_target_player :=
      p_player;
    v_target_card :=
      v_source_card;
  elsif v_target_type in (
    'self_player',
    'source_player'
  )
  then
    v_target_card_id := null;
    v_target_player :=
      p_player;
  elsif v_target_type in (
    'enemy_player',
    'opponent_player'
  )
  then
    v_target_card_id := null;
    v_target_player :=
      v_enemy;
  else
    if
      v_target_required
      and
      v_target_card_id is null
    then
      return jsonb_build_object(
        'ok', false,
        'requires_target',
        true,
        'target_type',
        v_target_type,
        'message',
        'Pilih Target Card terlebih dahulu.'
      );
    end if;
    if v_target_card_id is not null then
      select *
      into v_target_card
      from public.battle_cards
      where id =
        v_target_card_id
        and battle_id =
          p_battle_id
      for update;
      if not found then
        return jsonb_build_object(
          'ok', false,
          'message',
          'Target Card tidak ditemukan.'
        );
      end if;
      v_target_player :=
        v_target_card.player;
    end if;
  end if;
  if
    v_target_type = 'enemy_active'
    and
    (
      v_target_card.player <> v_enemy
      or
      v_target_card.zone <> 'active'
      or
      coalesce(
        v_target_card.current_hp,
        v_target_card.base_hp,
        v_target_card.hp,
        0
      ) <= 0
    )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Target harus Enemy Active Card.'
    );
  end if;
  if
    v_target_type = 'ally_active'
    and
    (
      v_target_card.player <> p_player
      or
      v_target_card.zone <> 'active'
      or
      coalesce(
        v_target_card.current_hp,
        v_target_card.base_hp,
        v_target_card.hp,
        0
      ) <= 0
    )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Target harus Ally Active Card.'
    );
  end if;
  if
    v_target_type = 'any_active'
    and
    (
      v_target_card.zone <> 'active'
      or
      coalesce(
        v_target_card.current_hp,
        v_target_card.base_hp,
        v_target_card.hp,
        0
      ) <= 0
    )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Target harus Active Card.'
    );
  end if;
  if
    v_target_type = 'enemy_graveyard'
    and
    (
      v_target_card.player <> v_enemy
      or
      v_target_card.zone <> 'graveyard'
    )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Target harus Card lawan di Graveyard.'
    );
  end if;
  if
    v_target_type = 'ally_graveyard'
    and
    (
      v_target_card.player <> p_player
      or
      v_target_card.zone <> 'graveyard'
    )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      'Target harus Card sendiri di Graveyard.'
    );
  end if;
  v_cost_type :=
    lower(
      trim(
        coalesce(
          v_cost_spec
            ->> 'type',
          'none'
        )
      )
    );
  begin
    v_cost_value :=
      greatest(
        0,
        coalesce(
          (
            v_cost_spec
              ->> 'value'
          )::integer,
          (
            v_cost_spec
              ->> 'amount'
          )::integer,
          0
        )
      );
  exception
    when others then
      return jsonb_build_object(
        'ok', false,
        'message',
        'Konfigurasi cost Special Skill tidak valid.'
      );
  end;
  if v_cost_type in (
    '',
    'none',
    'free'
  )
  then
    v_cost_value := 0;
  elsif v_cost_type in (
    'skill_gauge',
    'ultimate_gauge'
  )
  then
    v_current_gauge :=
      case
        when p_player = 'p1'
          then coalesce(
            v_battle.player1_skill,
            0
          )
        else coalesce(
          v_battle.player2_skill,
          0
        )
      end;
    if
      v_current_gauge <
      v_cost_value
    then
      return jsonb_build_object(
        'ok', false,
        'cost_type',
        v_cost_type,
        'required',
        v_cost_value,
        'available',
        v_current_gauge,
        'message',
        'Skill Gauge tidak cukup.'
      );
    end if;
  else
    return jsonb_build_object(
      'ok', false,
      'cost_type',
      v_cost_type,
      'message',
      'Cost type Special Skill belum didukung.'
    );
  end if;
  v_effect_result :=
    public.tcg_apply_effects(
      p_battle_id,
      p_player,
      p_card_id,
      v_effects,
      jsonb_build_object(
        'action',
        'special_skill',
        'battle_card_skill_id',
        v_card_skill.id,
        'special_skill_id',
        v_card_skill.special_skill_id,
        'skill_code',
        v_card_skill.skill_code,
        'target_card_id',
        v_target_card_id,
        'target_player',
        v_target_player
      )
    );
  if not coalesce(
    (
      v_effect_result
        ->> 'ok'
    )::boolean,
    false
  )
  then
    return jsonb_build_object(
      'ok', false,
      'message',
      coalesce(
        v_effect_result
          ->> 'message',
        'Special Skill gagal dijalankan.'
      ),
      'effect_result',
      v_effect_result
    );
  end if;
  select
    coalesce(
      sum(
        coalesce(
          (
            effect_item
              -> 'result'
              ->> 'actual_damage'
          )::integer,
          0
        )
      ),
      0
    )
  into v_damage
  from jsonb_array_elements(
    coalesce(
      v_effect_result
        -> 'results',
      '[]'::jsonb
    )
  ) as effect_item;
  select
    coalesce(
      sum(
        coalesce(
          (
            effect_item
              -> 'result'
              ->> 'actual_heal'
          )::integer,
          0
        )
      ),
      0
    )
  into v_heal
  from jsonb_array_elements(
    coalesce(
      v_effect_result
        -> 'results',
      '[]'::jsonb
    )
  ) as effect_item;
  if
    v_cost_type in (
      'skill_gauge',
      'ultimate_gauge'
    )
    and
    v_cost_value > 0
  then
    if p_player = 'p1' then
      update public.battle_sessions
      set
        player1_skill =
          greatest(
            0,
            coalesce(
              player1_skill,
              0
            )
            -
            v_cost_value
          )
      where id =
        p_battle_id;
    else
      update public.battle_sessions
      set
        player2_skill =
          greatest(
            0,
            coalesce(
              player2_skill,
              0
            )
            -
            v_cost_value
          )
      where id =
        p_battle_id;
    end if;
  end if;
  update public.battle_card_skills
  set
    cooldown_until_owner_turn = CASE WHEN v_owner_cd > 0 THEN v_owner_turn+v_owner_cd ELSE NULL END,
    cooldown_until_round =
      case
        when v_cooldown_rounds > 0
        then
          coalesce(
            v_battle.round,
            1
          )
          +
          v_cooldown_rounds
        else null
      end
  where id =
    v_card_skill.id;
  insert into public.battle_special_skill_uses (
    battle_id,
    player,
    battle_card_id,
    battle_card_skill_id,
    special_skill_id,
    skill_code,
    target_payload,
    resolved_effects,
    result,
    usage_number
  )
  values (
    p_battle_id,
    p_player,
    p_card_id,
    v_card_skill.id,
    v_card_skill.special_skill_id,
    v_card_skill.skill_code,
    jsonb_build_object(
      'request',
      coalesce(
        p_payload,
        '{}'::jsonb
      ),
      'target_card_id',
      v_target_card_id,
      'target_player',
      v_target_player,
      'target_type',
      v_target_type
    ),
    coalesce(
      v_effect_result
        -> 'results',
      '[]'::jsonb
    ),
    v_effect_result,
    v_usage_number
  );
  insert into public.battle_events (
    battle_id,
    type,
    source_player,
    target_player,
    card_id,
    payload
  )
  values (
    p_battle_id,
    'special_skill',
    p_player,
    v_target_player,
    p_card_id,
    jsonb_build_object(
      'battle_card_skill_id',
      v_card_skill.id,
      'special_skill_id',
      v_card_skill.special_skill_id,
      'skill_code',
      v_card_skill.skill_code,
      'skill_name',
      v_card_skill.name,
      'source_card_id',
      p_card_id,
      'target_card_id',
      v_target_card_id,
      'target_player',
      v_target_player,
      'usage_number',
      v_usage_number,
      'damage',
      v_damage,
      'heal',
      v_heal,
      'cost_type',
      v_cost_type,
      'cost_value',
      v_cost_value,
      'cooldown_rounds',
      v_cooldown_rounds,
      'cooldown_until_round',
      case
        when v_cooldown_rounds > 0
        then
          coalesce(
            v_battle.round,
            1
          )
          +
          v_cooldown_rounds
        else null
      end,
      'consumes_turn',
      v_ends_turn,
      'effect_result',
      v_effect_result,
      'message',
      upper(
        coalesce(
          v_card_skill.name,
          v_card_skill.skill_code,
          'SPECIAL SKILL'
        )
      )
      || ' ACTIVATED'
    )
  );
  select *
  into v_battle
  from public.battle_sessions
  where id =
    p_battle_id;
  return jsonb_build_object(
    'ok',
    true,
    'action',
    'special_skill',
    'battle_card_skill_id',
    v_card_skill.id,
    'special_skill_id',
    v_card_skill.special_skill_id,
    'skill_code',
    v_card_skill.skill_code,
    'skill_name',
    v_card_skill.name,
    'source_card_id',
    p_card_id,
    'target_card_id',
    v_target_card_id,
    'target_player',
    v_target_player,
    'usage_number',
    v_usage_number,
    'damage',
    v_damage,
    'heal',
    v_heal,
    'cost_type',
    v_cost_type,
    'cost_value',
    v_cost_value,
    'cooldown_rounds',
    v_cooldown_rounds,
    'cooldown_until_round',
    case
      when v_cooldown_rounds > 0
      then
        coalesce(
          v_battle.round,
          1
        )
        +
        v_cooldown_rounds
      else null
    end,
    'ends_turn',
    v_ends_turn,
    'effect_result',
    v_effect_result,
    'winner',
    v_battle.winner,
    'finished',
    (
      v_battle.status = 'finished'
    ),
    'message',
    coalesce(
      v_card_skill.name,
      v_card_skill.skill_code,
      'Special Skill'
    )
    || ' activated.'
  );
end;
$function$;
REVOKE ALL ON FUNCTION public.process_special_skill(uuid,text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.tcg_submit_battle_action_core_v2(p_code text, p_player text, p_token text, p_action text, p_card_id uuid DEFAULT NULL::uuid, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_player text := lower(trim(coalesce(p_player, '')));
  v_action text := lower(trim(coalesce(p_action, '')));
  v_guard jsonb;
  v_battle public.battle_sessions%ROWTYPE;
  v_card public.battle_cards%ROWTYPE;
  v_bench public.battle_cards%ROWTYPE;
  v_target public.battle_cards%ROWTYPE;
  v_response jsonb;
  v_finish jsonb := '{}'::jsonb;
  v_deck_out jsonb := '{}'::jsonb;
  v_cost integer := 1;
  v_ap integer := 0;
  v_ap_after integer := 0;
  v_old_round integer := 1;
  v_old_total_rounds integer := 10;
  v_old_question_enabled boolean := false;
  v_old_question_active boolean := false;
  v_old_question_id uuid;
  v_old_question_round_id uuid;
  v_old_status text;
  v_expected_token text;
  v_target_id uuid;
  v_bench_id uuid;
  v_skill_id uuid;
  v_target_hp_before integer;
  v_target_hp_after integer;
  v_active_attack integer;
  v_bench_attack integer;
  v_target_defense integer;
  v_effective_defense integer;
  v_damage integer;
  v_player_damage integer := 0;
  v_bonus integer := 0;
  v_heal integer := 0;
  v_defense_ignore numeric := 0;
  v_combo_name text := 'Assist Attack';
  v_element_a text;
  v_element_b text;
  v_enemy text;
  v_enemy_active_count integer := 0;
  v_bench_count integer := 0;
  v_active_slot integer;
  v_destroyed boolean := false;
  v_effective_damage integer := 0;
  v_destruction_pct numeric := 0;
  v_turn_completed boolean := false;
  v_pending_summon boolean := false;
  v_action_block text;
BEGIN
  v_guard := public.tcg_sync_battle_turn(p_code, p_player, p_token);
  IF NOT coalesce((v_guard->>'ok')::boolean, false) THEN
    RETURN v_guard;
  END IF;

  SELECT * INTO v_battle
    FROM public.battle_sessions
   WHERE upper(code) = upper(trim(coalesce(p_code, '')))
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle tidak ditemukan.');
  END IF;

  IF v_battle.winner IS NOT NULL OR lower(coalesce(v_battle.status, '')) = 'finished' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Battle sudah selesai.');
  END IF;
  IF v_player NOT IN ('p1', 'p2') OR lower(coalesce(v_battle.current_turn, '')) <> v_player THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Belum giliran kamu.');
  END IF;

  IF NOT coalesce(v_battle.action_points_enabled, false)
     OR lower(coalesce(v_battle.ruleset, '')) <> 'tcg_v1' THEN
    v_response := public.submit_battle_action_pre_turn_clock(
      p_code, p_player, p_token, p_action, p_card_id, coalesce(p_payload, '{}'::jsonb)
    );
    IF NOT coalesce((v_response->>'ok')::boolean, false) THEN RETURN v_response; END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN v_response || jsonb_build_object(
      'deck_out', v_deck_out,
      'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
      'finished', lower(coalesce(v_battle.status, '')) = 'finished'
    );
  END IF;

  IF coalesce(v_battle.question_active, false) OR lower(coalesce(v_battle.status, '')) = 'question' THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Selesaikan kuis sebelum melanjutkan turn.');
  END IF;

  v_expected_token := CASE WHEN v_player = 'p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_expected_token IS NULL OR p_token IS NULL OR p_token <> v_expected_token THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Player token tidak valid.');
  END IF;

  v_ap := CASE WHEN v_player = 'p1' THEN coalesce(v_battle.player1_action_points, 0)
               ELSE coalesce(v_battle.player2_action_points, 0) END;

  IF v_action IN ('end_turn', 'pass_turn') THEN
    v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    RETURN v_finish || jsonb_build_object(
      'action', 'end_turn',
      'action_points', 0,
      'message', CASE WHEN coalesce((v_finish->>'ok')::boolean, false) THEN 'Turn diakhiri.' ELSE v_finish->>'message' END
    );
  END IF;

  IF v_action = 'defense' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'DEFENSE_IS_PASSIVE',
      'message', 'Defense berasal dari stat DEF dan efek Shield pada kartu; tidak memakai AP sebagai aksi biasa.');
  END IF;

  v_cost := public.tcg_resolve_action_point_cost(v_action, v_battle.action_costs);
  IF v_action = 'special_skill' THEN
    BEGIN
      v_skill_id := nullif(trim(coalesce(p_payload->>'skill_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      v_skill_id := NULL;
    END;
    v_cost := public.tcg_resolve_action_point_cost('special_skill',v_battle.action_costs);
    IF v_skill_id IS NOT NULL THEN
      SELECT CASE
          WHEN coalesce(skill.limits->>'action_points', '') ~ '^(0|[1-9]|10)$'
            THEN (skill.limits->>'action_points')::integer
          ELSE public.tcg_resolve_action_point_cost('special_skill',v_battle.action_costs)
        END
        INTO v_cost
        FROM public.battle_card_skills skill
       WHERE skill.id = v_skill_id AND skill.battle_card_id = p_card_id
         AND skill.battle_id = v_battle.id AND skill.player = v_player AND NOT skill.disabled;
      IF NOT FOUND THEN v_cost := public.tcg_resolve_action_point_cost('special_skill',v_battle.action_costs); END IF;
    END IF;
  END IF;
  IF v_cost = 0 AND v_action NOT IN ('attack','heal','synergy','summon','move_to_bench','return_from_bench','switch_active','fusion','ultimate','combo_attack','special_skill') THEN
    RETURN jsonb_build_object('ok', false, 'message', 'Aksi tidak dikenal.');
  END IF;
  IF v_ap < v_cost THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_ENOUGH_ACTION_POINTS',
      'message', format('Aksi ini membutuhkan %s AP; tersisa %s AP.', v_cost, v_ap), 'action_points', v_ap);
  END IF;

  v_ap_after := v_ap - v_cost;
  v_enemy := CASE WHEN v_player = 'p1' THEN 'p2' ELSE 'p1' END;

  -- Position changes are resolved here so a TCG action consumes AP without
  -- invoking the legacy one-action turn transition.
  IF v_action IN ('move_to_bench', 'return_from_bench', 'switch_active') THEN
    IF p_card_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu yang akan dipindahkan.');
    END IF;

    IF v_action = 'move_to_bench' THEN
      SELECT * INTO v_card FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_card.id IS NULL OR v_card.zone <> 'active'
         OR coalesce(v_card.current_hp, v_card.base_hp, v_card.hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu Active yang masih dapat bertarung.');
      END IF;
      SELECT count(*) INTO v_bench_count FROM public.battle_cards
       WHERE battle_id = v_battle.id AND player = v_player AND zone = 'bench'
         AND coalesce(current_hp, base_hp, hp, 0) > 0;
      IF v_bench_count >= greatest(0, coalesce(v_battle.max_bench, 2)) THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Bench penuh.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_card.id, 'move_to_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'bench', slot = NULL
       WHERE id = v_card.id;
      v_response := jsonb_build_object('action', v_action, 'message', v_card.name || ' dipindahkan ke Bench.');

    ELSIF v_action = 'return_from_bench' THEN
      SELECT * INTO v_bench FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_bench.id IS NULL OR v_bench.zone <> 'bench'
         OR coalesce(v_bench.current_hp, v_bench.base_hp, v_bench.hp, 0) <= 0
         OR coalesce(v_bench.exhausted, false) THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Kartu Bench ini sudah tidak dapat kembali ke Active.');
      END IF;
      SELECT min(slots.slot_number) INTO v_active_slot
        FROM generate_series(1,greatest(1,coalesce(v_battle.max_active,1))) AS slots(slot_number)
       WHERE NOT EXISTS (
         SELECT 1 FROM public.battle_cards c
          WHERE c.battle_id=v_battle.id AND c.player=v_player AND c.zone='active'
            AND c.slot=slots.slot_number AND coalesce(c.current_hp,c.base_hp,c.hp,0)>0
       );
      IF v_active_slot IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code','ACTIVE_ZONE_FULL', 'message', 'Active penuh. Tukar posisi dengan kartu Active yang ingin dipindahkan ke Bench.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench.id, 'return_from_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'active', slot = v_active_slot
       WHERE id = v_bench.id;
      v_response := jsonb_build_object('action', v_action, 'message', v_bench.name || ' kembali ke Active.');

    ELSE
      BEGIN
        v_target_id := nullif(trim(coalesce(p_payload->>'active_card_id', '')), '')::uuid;
      EXCEPTION WHEN invalid_text_representation THEN
        v_target_id := NULL;
      END;
      IF v_target_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Pilih kartu Active dan Bench untuk bertukar posisi.');
      END IF;
      SELECT * INTO v_bench FROM public.battle_cards
       WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      SELECT * INTO v_card FROM public.battle_cards
       WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
      IF v_bench.id IS NULL OR v_bench.zone <> 'bench'
         OR coalesce(v_bench.current_hp, v_bench.base_hp, v_bench.hp, 0) <= 0
         OR coalesce(v_bench.exhausted, false)
         OR v_card.id IS NULL OR v_card.zone <> 'active'
         OR coalesce(v_card.current_hp, v_card.base_hp, v_card.hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Kartu Active atau Bench sudah berubah atau tidak dapat bertarung.');
      END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_card.id, 'move_to_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;
      v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench.id, 'return_from_bench');
      IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

      UPDATE public.battle_cards
         SET zone = 'bench', slot = NULL
       WHERE id = v_card.id;
      UPDATE public.battle_cards
         SET zone = 'active', slot = v_card.slot
       WHERE id = v_bench.id;
      v_response := jsonb_build_object('action', v_action,
        'message', v_bench.name || ' bertukar posisi dengan ' || v_card.name);
    END IF;

    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, card_id, payload)
    VALUES (v_battle.id, 'card_move', v_player, p_card_id,
      coalesce(v_response, '{}'::jsonb) || jsonb_build_object('action_points_spent', v_cost));
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    IF v_ap_after = 0 AND lower(coalesce(v_battle.status, '')) <> 'finished' THEN
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN coalesce(v_response, '{}'::jsonb) || jsonb_build_object(
      'ok', true,
      'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
      'next_turn', v_battle.current_turn, 'round', v_battle.round,
      'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
      'deck_out', v_deck_out, 'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
      'finished', lower(coalesce(v_battle.status, '')) = 'finished');
  END IF;

  -- Summon is completed by the RFID scan pipeline. Charge its AP now and
  -- keep the current turn locked until the physical card is scanned.
  IF v_action = 'summon' THEN
    IF coalesce(v_battle.pending_action, '') <> '' THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Selesaikan aksi RFID yang tertunda terlebih dahulu.');
    END IF;
    IF (CASE WHEN v_player = 'p1' THEN coalesce(v_battle.player1_deck_remaining, 0)
             ELSE coalesce(v_battle.player2_deck_remaining, 0) END) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'message', 'DECK EMPTY');
    END IF;
    IF (SELECT count(*) FROM public.battle_cards c WHERE c.battle_id = v_battle.id
          AND c.player = v_player AND c.zone IN ('active', 'bench') AND coalesce(c.current_hp, c.base_hp, c.hp, 0) > 0)
       >= coalesce(v_battle.max_active, 1) + coalesce(v_battle.max_bench, 2) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'ACTIVE DECK + BENCH FULL');
    END IF;
    UPDATE public.battle_sessions
       SET pending_action = 'summon', pending_action_player = v_player,
           player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, payload)
    VALUES (v_battle.id, 'action_request', v_player,
      jsonb_build_object('action', 'summon', 'action_points_spent', v_cost,
        'message', 'SCAN RFID TO SUMMON; card enters Active only'));
    RETURN jsonb_build_object('ok', true, 'action', 'summon', 'waiting_rfid', true,
      'action_points', v_ap_after, 'message', 'Summon siap. Scan RFID untuk mengambil kartu ke arena.');
  END IF;

  IF v_action = 'combo_attack' THEN
    RETURN public.tcg_submit_active_combo_attack(p_code,p_player,p_token,p_card_id,
      ARRAY(SELECT jsonb_array_elements_text(coalesce(p_payload->'participant_card_ids','[]'::jsonb))::uuid),
      nullif(trim(coalesce(p_payload->>'target_card_id','')),'')::uuid);
    IF NOT coalesce(v_battle.combo_enabled, true) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Combo Attack dinonaktifkan untuk battle ini.');
    END IF;
    BEGIN
      v_bench_id := nullif(trim(coalesce(p_payload->>'bench_card_id', '')), '')::uuid;
      v_target_id := nullif(trim(coalesce(p_payload->>'target_card_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilihan kartu combo tidak valid.');
    END;
    IF p_card_id IS NULL OR v_bench_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Pilih satu Active Card dan satu Bench Card.');
    END IF;
    SELECT * INTO v_card FROM public.battle_cards WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
    SELECT * INTO v_bench FROM public.battle_cards WHERE id = v_bench_id AND battle_id = v_battle.id AND player = v_player FOR UPDATE;
    IF v_card.id IS NULL OR v_bench.id IS NULL
       OR v_card.zone <> 'active' OR v_bench.zone <> 'bench'
       OR coalesce(v_card.current_hp, v_card.base_hp, 0) <= 0
       OR coalesce(v_bench.current_hp, v_bench.base_hp, 0) <= 0
       OR coalesce(v_card.exhausted, false) OR coalesce(v_bench.exhausted, false) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Combo membutuhkan Active Card dan Bench Card yang masih dapat bertarung.');
    END IF;
    IF NOT public.tcg_battle_card_can_attack(v_card.id,v_battle.turn_index,v_battle.max_attacks_per_card) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Active Card ini sudah menyerang pada turn ini.');
    END IF;
    IF coalesce(v_bench.combo_assist_turn, -1) = coalesce(v_battle.turn_index, 1) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Bench Card ini sudah membantu combo pada turn ini.');
    END IF;
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, p_card_id, 'combo_attack');
    IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, v_bench_id, 'combo_attack');
    IF v_action_block IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'message', v_action_block); END IF;

    SELECT count(*) INTO v_enemy_active_count FROM public.battle_cards c
      WHERE c.battle_id = v_battle.id AND c.player = v_enemy AND c.zone = 'active'
        AND NOT coalesce(c.exhausted, false) AND coalesce(c.current_hp, c.base_hp, 0) > 0;
    IF v_target_id IS NULL AND v_enemy_active_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'requires_target', true, 'message', 'Pilih Active Card lawan sebagai target combo.');
    END IF;
    IF v_target_id IS NULL AND (NOT coalesce(v_battle.direct_attack_enabled, true)) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Direct Attack dinonaktifkan.');
    END IF;
    IF v_target_id IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_enemy FOR UPDATE;
      IF NOT FOUND OR v_target.zone <> 'active' OR coalesce(v_target.exhausted, false)
         OR coalesce(v_target.current_hp, v_target.base_hp, 0) <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Target harus Active Card lawan yang masih bertarung.');
      END IF;
    END IF;

    v_element_a := lower(trim(coalesce(v_card.element, '')));
    v_element_b := lower(trim(coalesce(v_bench.element, '')));
    SELECT r.combo_name, r.bonus_damage, r.defense_ignore_pct, r.heal_after
      INTO v_combo_name, v_bonus, v_defense_ignore, v_heal
      FROM public.tcg_type_combo_rules r
     WHERE r.element_a = least(v_element_a, v_element_b)
       AND r.element_b = greatest(v_element_a, v_element_b);
    v_combo_name := coalesce(v_combo_name, 'Assist Attack');
    v_bonus := coalesce(v_bonus, 0);
    v_defense_ignore := coalesce(v_defense_ignore, 0);
    v_heal := coalesce(v_heal, 0);

    v_active_attack := greatest(0, coalesce(v_card.attack, 0));
    v_bench_attack := greatest(0, coalesce(v_bench.attack, 0));
    IF v_target_id IS NULL THEN
      v_damage := greatest(1, round((v_active_attack + floor(v_bench_attack * 0.5) + v_bonus) * 0.5)::integer);
      IF v_enemy = 'p1' THEN
        UPDATE public.battle_sessions SET player1_hp = greatest(0, player1_hp - v_damage),
          player1_skill = least(100, coalesce(player1_skill, 0) + 5),
          player2_skill = least(100, coalesce(player2_skill, 0) + 10) WHERE id = v_battle.id;
      ELSE
        UPDATE public.battle_sessions SET player2_hp = greatest(0, player2_hp - v_damage),
          player2_skill = least(100, coalesce(player2_skill, 0) + 5),
          player1_skill = least(100, coalesce(player1_skill, 0) + 10) WHERE id = v_battle.id;
      END IF;
      UPDATE public.battle_sessions
         SET winner = CASE
               WHEN player1_hp <= 0 AND player2_hp <= 0 THEN 'draw'
               WHEN player1_hp <= 0 THEN 'p2'
               WHEN player2_hp <= 0 THEN 'p1'
               ELSE winner
             END,
             status = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN 'finished' ELSE status END,
             finished_at = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN now() ELSE finished_at END
       WHERE id = v_battle.id;
    ELSE
      v_target_hp_before := greatest(0, coalesce(v_target.current_hp, v_target.base_hp, v_target.hp, 0));
      v_target_defense := greatest(0, coalesce(v_target.defense, 0));
      v_effective_defense := greatest(0, v_target_defense - round(v_target_defense * v_defense_ignore)::integer);
      v_damage := greatest(1, v_active_attack + floor(v_bench_attack * 0.5)::integer + v_bonus - v_effective_defense);
      v_target_hp_after := greatest(0, v_target_hp_before - v_damage);
      v_destroyed := v_target_hp_after = 0;
      v_effective_damage := least(v_target_hp_before, v_damage);
      IF v_destroyed THEN
        UPDATE public.battle_cards SET current_hp = 0, zone = 'graveyard', exhausted = true,
          destroyed_at = now(), graveyard_at = now(), graveyard_reason = 'combo_destroyed'
         WHERE id = v_target.id;
        IF coalesce(v_battle.destruction_damage_enabled, true) THEN
          v_destruction_pct := greatest(0, least(1, coalesce(v_battle.destruction_damage_percent, 0.30)));
          IF coalesce(v_battle.destruction_damage_mode, 'final_damage_percent') = 'final_damage_percent' THEN
            v_player_damage := round(v_effective_damage * v_destruction_pct)::integer;
          ELSIF coalesce(v_battle.destruction_damage_mode, '') = 'overflow_percent' THEN
            v_player_damage := round(greatest(0, v_damage - v_target_hp_before) * v_destruction_pct)::integer;
          END IF;
        END IF;
        IF v_enemy = 'p1' THEN
          UPDATE public.battle_sessions SET player1_hp = greatest(0, player1_hp - v_player_damage) WHERE id = v_battle.id;
        ELSE
          UPDATE public.battle_sessions SET player2_hp = greatest(0, player2_hp - v_player_damage) WHERE id = v_battle.id;
        END IF;
      ELSE
        UPDATE public.battle_cards SET current_hp = v_target_hp_after WHERE id = v_target.id;
      END IF;
      IF v_enemy = 'p1' THEN
        UPDATE public.battle_sessions SET player1_skill = least(100, coalesce(player1_skill, 0) + 5),
          player2_skill = least(100, coalesce(player2_skill, 0) + 10) WHERE id = v_battle.id;
      ELSE
        UPDATE public.battle_sessions SET player2_skill = least(100, coalesce(player2_skill, 0) + 5),
          player1_skill = least(100, coalesce(player1_skill, 0) + 10) WHERE id = v_battle.id;
      END IF;
    END IF;

    IF v_heal > 0 THEN
      UPDATE public.battle_cards SET current_hp = least(coalesce(base_hp, hp), coalesce(current_hp, 0) + v_heal)
       WHERE id = v_card.id;
    END IF;
    UPDATE public.battle_sessions
       SET winner = CASE
             WHEN player1_hp <= 0 AND player2_hp <= 0 THEN 'draw'
             WHEN player1_hp <= 0 THEN 'p2'
             WHEN player2_hp <= 0 THEN 'p1'
             ELSE winner
           END,
           status = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN 'finished' ELSE status END,
           finished_at = CASE WHEN player1_hp <= 0 OR player2_hp <= 0 THEN now() ELSE finished_at END
     WHERE id = v_battle.id;
    UPDATE public.battle_cards SET last_attacked_turn = coalesce(v_battle.turn_index, 1) WHERE id = v_card.id;
    UPDATE public.battle_cards SET combo_assist_turn = coalesce(v_battle.turn_index, 1) WHERE id = v_bench.id;
    INSERT INTO public.battle_events (battle_id, type, source_player, target_player, card_id, payload)
    VALUES (v_battle.id, 'attack', v_player, v_enemy, v_card.id,
      jsonb_build_object('ruleset', 'tcg_v1', 'attack_mode', 'assist_combo',
        'attacker_card_id', v_card.id, 'bench_card_id', v_bench.id,
        'target_card_id', v_target_id, 'combo_name', v_combo_name,
        'attacker_element', v_card.element, 'bench_element', v_bench.element,
        'active_attack', v_active_attack, 'bench_assist_attack', floor(v_bench_attack * 0.5)::integer,
        'bonus_damage', v_bonus, 'defense_ignore_pct', v_defense_ignore,
        'damage', v_damage, 'target_hp_before', v_target_hp_before,
        'target_hp_after', v_target_hp_after, 'destroyed', v_destroyed,
        'player_damage', v_player_damage, 'healing', v_heal,
        'message', v_combo_name || ' • ' || v_damage || ' damage'));
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    IF v_ap_after = 0 AND lower(coalesce(v_battle.status, '')) <> 'finished' THEN
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
    v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
    SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
    RETURN jsonb_build_object('ok', true, 'action', 'combo_attack', 'combo_name', v_combo_name,
      'damage', v_damage, 'destroyed', v_destroyed, 'player_damage', v_player_damage,
      'healing', v_heal, 'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
      'next_turn', v_battle.current_turn, 'round', v_battle.round,
      'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
      'message', v_combo_name || ' berhasil: ' || v_damage || ' damage.');
  END IF;

  v_old_round := greatest(1, coalesce(v_battle.round, 1));
  v_old_total_rounds := coalesce(v_battle.total_rounds, 10);
  v_old_question_enabled := coalesce(v_battle.question_enabled, false);
  v_old_question_active := coalesce(v_battle.question_active, false);
  v_old_question_id := v_battle.current_question_id;
  v_old_question_round_id := v_battle.current_question_round_id;
  v_old_status := coalesce(v_battle.status, 'battle');

  IF p_card_id IS NOT NULL THEN
    v_action_block := public.tcg_card_action_block_reason(v_battle.id, p_card_id, v_action);
    IF v_action_block IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'STATUS_ACTION_BLOCKED', 'status_blocked', true, 'message', v_action_block);
    END IF;
  END IF;
  IF v_action = 'attack' THEN
    SELECT * INTO v_card FROM public.battle_cards WHERE id = p_card_id AND battle_id = v_battle.id AND player = v_player;
    IF NOT FOUND OR v_card.zone <> 'active' THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Serangan membutuhkan Active Card.');
    END IF;
    IF NOT public.tcg_battle_card_can_attack(v_card.id,v_battle.turn_index,v_battle.max_attacks_per_card) THEN
      RETURN jsonb_build_object('ok', false, 'message', 'Active Card ini sudah menyerang pada turn ini.');
    END IF;
    BEGIN
      v_target_id := nullif(trim(coalesce(p_payload->>'target_card_id', '')), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN v_target_id := NULL;
    END;
    IF v_target_id IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id AND player = v_enemy AND zone = 'active';
      IF FOUND THEN v_target_hp_before := greatest(0, coalesce(v_target.current_hp, v_target.base_hp, v_target.hp, 0)); END IF;
    END IF;
  END IF;

  -- Suppress the legacy one-action turn transition while the validated core
  -- applies exactly one chosen card action. The transaction then restores the
  -- same round/turn and advances only when AP is exhausted.
  PERFORM set_config('tcg.intra_turn_action', 'on', true);
  UPDATE public.battle_sessions
     SET question_enabled = false,
         total_rounds = greatest(coalesce(total_rounds, 10), coalesce(round, 1) + 1)
   WHERE id = v_battle.id;

  v_response := public.submit_battle_action_phase3d19_core(
    p_code, p_player, p_token, p_action, p_card_id, coalesce(p_payload, '{}'::jsonb)
  );

  IF NOT coalesce((v_response->>'ok')::boolean, false) THEN
    UPDATE public.battle_sessions SET current_turn = v_player, round = v_old_round,
      question_active = v_old_question_active, current_question_id = v_old_question_id,
      current_question_round_id = v_old_question_round_id, status = v_old_status
    WHERE id = v_battle.id;
    PERFORM set_config('tcg.intra_turn_action', 'off', true);
    RETURN v_response;
  END IF;

  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id FOR UPDATE;
  UPDATE public.battle_sessions
     SET question_enabled = v_old_question_enabled,
         total_rounds = v_old_total_rounds
   WHERE id = v_battle.id;
  IF lower(coalesce(v_battle.status, '')) <> 'finished' AND v_battle.winner IS NULL THEN
    UPDATE public.battle_sessions SET question_enabled = v_old_question_enabled,
      total_rounds = v_old_total_rounds, current_turn = v_player, round = v_old_round,
      question_active = v_old_question_active, current_question_id = v_old_question_id,
      current_question_round_id = v_old_question_round_id, status = v_old_status
    WHERE id = v_battle.id;
  END IF;

  IF p_action = 'attack' THEN
    UPDATE public.battle_cards
       SET last_attacked_turn=coalesce(v_battle.turn_index,1),
           attacks_this_turn=CASE WHEN coalesce(attack_turn_index,-1)=coalesce(v_battle.turn_index,1)
             THEN coalesce(attacks_this_turn,0)+1 ELSE 1 END,
           attack_turn_index=coalesce(v_battle.turn_index,1)
     WHERE id=p_card_id;
    IF v_target_id IS NOT NULL AND v_target_hp_before IS NOT NULL THEN
      SELECT * INTO v_target FROM public.battle_cards WHERE id = v_target_id AND battle_id = v_battle.id;
      IF FOUND AND v_target.zone = 'active' AND coalesce(v_target.current_hp, 0) > 0
         AND v_target.current_hp < v_target_hp_before THEN
        IF coalesce(v_battle.status_effects_enabled,true) THEN
          PERFORM public.tcg_apply_elemental_basic_passive(v_battle.id, p_card_id, v_target_id, v_old_round);
        END IF;
      END IF;
    END IF;
  END IF;

  PERFORM public.tcg_sync_legacy_card_visual_status(v_battle.id, v_player, v_action, p_card_id);
  IF v_action IN ('attack', 'ultimate') THEN
    PERFORM public.tcg_sync_legacy_card_visual_status(v_battle.id, v_enemy, '', NULL);
  END IF;

  IF lower(coalesce(v_battle.status, '')) = 'finished' OR v_battle.winner IS NOT NULL THEN
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
  ELSE
    UPDATE public.battle_sessions
       SET player1_action_points = CASE WHEN v_player = 'p1' THEN v_ap_after ELSE player1_action_points END,
           player2_action_points = CASE WHEN v_player = 'p2' THEN v_ap_after ELSE player2_action_points END
     WHERE id = v_battle.id;
    IF v_ap_after = 0 THEN
      PERFORM set_config('tcg.intra_turn_action', 'off', true);
      v_finish := public.tcg_finish_action_point_turn(v_battle.id, v_player);
    END IF;
  END IF;

  v_deck_out := public.tcg_check_battle_deck_out(v_battle.id);
  SELECT * INTO v_battle FROM public.battle_sessions WHERE id = v_battle.id;
  RETURN v_response || jsonb_build_object(
    'action_points', CASE WHEN v_player = 'p1' THEN v_battle.player1_action_points ELSE v_battle.player2_action_points END,
    'next_turn', v_battle.current_turn,
    'round', v_battle.round,
    'turn_completed', coalesce((v_finish->>'turn_completed')::boolean, false),
    'question_active', coalesce(v_battle.question_active, false),
    'deck_out', v_deck_out,
    'winner', coalesce(v_deck_out->>'winner', v_battle.winner),
    'finished', lower(coalesce(v_battle.status, '')) = 'finished'
  );
END;
$function$
;
REVOKE ALL ON FUNCTION public.tcg_submit_battle_action_core_v2(text,text,text,text,uuid,jsonb) FROM PUBLIC,anon,authenticated;

-- One transaction and idempotency key protect AP, usage, effects and event emission.
CREATE OR REPLACE FUNCTION public.submit_battle_action(p_code text,p_player text,p_token text,p_action text,p_card_id uuid DEFAULT NULL,p_payload jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
<<action_guard>>
DECLARE b public.battle_sessions%rowtype; s public.battle_card_skills%rowtype; r jsonb;
 request_id uuid; request jsonb; receipt public.battle_action_receipts%rowtype;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 p_player:=lower(trim(p_player));
 IF b.id IS NULL OR p_player NOT IN ('p1','p2') OR p_token IS NULL OR
 p_token IS DISTINCT FROM (CASE WHEN p_player='p1' THEN b.player1_token ELSE b.player2_token END) THEN
  RETURN jsonb_build_object('ok',false,'message','Battle atau token tidak valid.');
 END IF;
 request_id:=public.tcg_try_uuid(p_payload->>'action_id');
 request:=jsonb_build_object('action',p_action,'card_id',p_card_id,'payload',p_payload-'action_id');
 IF lower(p_action)='special_skill' AND request_id IS NULL THEN
  RETURN jsonb_build_object('ok',false,'message','ID aksi skill diperlukan. Muat ulang halaman.');
 END IF;
 IF request_id IS NOT NULL THEN
  SELECT * INTO receipt FROM public.battle_action_receipts WHERE battle_id=b.id AND player=p_player AND battle_action_receipts.request_id=action_guard.request_id;
  IF FOUND THEN
   IF receipt.request IS DISTINCT FROM request THEN RETURN jsonb_build_object('ok',false,'message','ID aksi sudah digunakan.'); END IF;
   RETURN receipt.response || jsonb_build_object('replayed',true);
  END IF;
 END IF;
 -- A failed legacy effect can return ok:false after writes; subtransaction rolls all of them back.
 BEGIN
  r:=public.tcg_submit_battle_action_core_v2(p_code,p_player,p_token,p_action,p_card_id,p_payload);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION USING ERRCODE='P0290',MESSAGE=r::text; END IF;
 EXCEPTION WHEN SQLSTATE 'P0290' THEN RETURN SQLERRM::jsonb;
 END;
 IF request_id IS NOT NULL THEN
  r:=r||jsonb_build_object('action_id',request_id);
  INSERT INTO public.battle_action_receipts(battle_id,player,request_id,request,response) VALUES(b.id,p_player,request_id,request,r);
 END IF;
 RETURN r;
END $$;
GRANT EXECUTE ON FUNCTION public.submit_battle_action(text,text,text,text,uuid,jsonb) TO anon,authenticated;

-- Card mapping order is the Skill 1/2 order, independent of catalog priority.
DO $patch$ DECLARE s text; BEGIN
 s:=pg_get_functiondef('public.tcg_snapshot_battle_card_special_skills()'::regprocedure);
 IF position('ss.priority' IN s)=0 THEN RAISE EXCEPTION 'Unrecognized skill snapshot function'; END IF;
 s:=replace(s,'ss.priority','gcss.sort_order');
 EXECUTE s;
END $patch$;
NOTIFY pgrst, 'reload schema';
