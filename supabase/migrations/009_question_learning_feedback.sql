-- Return the correct choice only after a player submits an answer.
CREATE OR REPLACE FUNCTION public.submit_battle_question_answer(p_code text, p_player text, p_token text, p_question_round_id uuid, p_answer_index integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_round public.battle_question_rounds%rowtype;

  v_expected_token text;

  v_correct_answer text;
  v_correct_option text;
  v_answer_letter text;

  v_is_correct boolean := false;

  v_reward text;
  v_timeout jsonb := '{}'::jsonb;
begin

  -- =======================================================
  -- VALIDATE PLAYER
  -- =======================================================

  if p_player not in ('p1', 'p2') then
    return jsonb_build_object(
      'ok', false,
      'message', 'Invalid player.'
    );
  end if;


  -- =======================================================
  -- VALIDATE ANSWER
  -- 0 = A
  -- 1 = B
  -- 2 = C
  -- 3 = D
  -- =======================================================

  if p_answer_index < 0
     or p_answer_index > 3
  then
    return jsonb_build_object(
      'ok', false,
      'message', 'Invalid answer.'
    );
  end if;


  -- =======================================================
  -- LOCK BATTLE
  -- =======================================================

  select *
  into v_battle
  from public.battle_sessions
  where upper(code) = upper(p_code)
  for update;


  if not found then
    return jsonb_build_object(
      'ok', false,
      'message', 'Battle tidak ditemukan.'
    );
  end if;


  -- =======================================================
  -- TOKEN
  -- =======================================================

  v_expected_token :=
    case
      when p_player = 'p1'
        then v_battle.player1_token
      else
        v_battle.player2_token
    end;


  if v_expected_token is null
     or p_token is null
     or p_token <> v_expected_token
  then

    return jsonb_build_object(
      'ok', false,
      'message', 'Player token tidak valid.'
    );

  end if;


  -- =======================================================
  -- QUESTION MUST BE ACTIVE
  -- =======================================================

  if not coalesce(
    v_battle.question_active,
    false
  )
  then

    return jsonb_build_object(
      'ok', false,
      'message', 'Coding challenge tidak sedang aktif.'
    );

  end if;


  -- =======================================================
  -- LOCK QUESTION ROUND
  -- =======================================================

  select *
  into v_round
  from public.battle_question_rounds
  where id = p_question_round_id
    and battle_id = v_battle.id
  for update;


  if not found then
    return jsonb_build_object(
      'ok', false,
      'message', 'Question round tidak ditemukan.'
    );
  end if;


  -- Enforce the configured deadline on the server, even if a client timer drifts.
  v_timeout := public.tcg_expire_battle_question(v_battle.id,p_question_round_id);
  if coalesce((v_timeout->>'timed_out')::boolean,false) then
    return v_timeout;
  end if;

  -- =======================================================
  -- QUESTION ALREADY HAS WINNER
  -- =======================================================

  if v_round.winner_player is not null then

    return jsonb_build_object(
      'ok', true,
      'correct', false,
      'already_finished', true,
      'winner', v_round.winner_player,
      'message', 'Challenge sudah memiliki pemenang.'
    );

  end if;


  -- =======================================================
  -- PLAYER CAN ANSWER ONCE
  -- =======================================================

  if exists (
    select 1
    from public.battle_question_answers
    where battle_question_id =
      p_question_round_id
      and player = p_player
  )
  then

    return jsonb_build_object(
      'ok', false,
      'message', 'Kamu sudah menjawab question ini.'
    );

  end if;


  -- =======================================================
  -- CORRECT ANSWER
  -- =======================================================

  select upper(
    trim(correct_answer)
  )
  into v_correct_answer
  from public.coding_questions
  where id = v_round.question_id;


  select case v_correct_answer
    when 'A' then option_a
    when 'B' then option_b
    when 'C' then option_c
    when 'D' then option_d
    else null
  end into v_correct_option
  from public.coding_questions
  where id = v_round.question_id;

  if v_correct_answer is null then

    return jsonb_build_object(
      'ok', false,
      'message', 'Correct answer tidak ditemukan.'
    );

  end if;


  v_answer_letter :=
    chr(
      65 + p_answer_index
    );


  v_is_correct :=
    v_answer_letter =
    v_correct_answer;


  -- =======================================================
  -- SAVE ANSWER
  -- =======================================================

  insert into public.battle_question_answers (
    battle_question_id,
    player,
    answer_index,
    is_correct,
    answered_at
  )
  values (
    p_question_round_id,
    p_player,
    p_answer_index,
    v_is_correct,
    now()
  );


  -- =======================================================
  -- WRONG ANSWER
  -- =======================================================

  if not v_is_correct then

    insert into public.battle_events (
      battle_id,
      type,
      source_player,
      payload
    )
    values (
      v_battle.id,
      'question_wrong',
      p_player,
      jsonb_build_object(
        'message',
        'Wrong answer'
      )
    );


    return jsonb_build_object(
      'ok', true,
      'correct', false,
      'winner', null,
      'correct_answer',v_correct_answer,
      'correct_option',v_correct_option,
      'message', 'Jawaban salah.'
    );

  end if;


  -- =======================================================
  -- RANDOM REWARD
  -- =======================================================

  if coalesce(v_battle.question_bonus_enabled,true) then
    v_reward :=
      (
        array[
          'power_strike',
          'iron_guard',
          'recovery',
          'overcharge',
          'cleanse'
        ]
      )[
        1 + floor(random() * 5)::integer
      ];
  else
    v_reward := null;
  end if;


  -- =======================================================
  -- WIN QUESTION
  -- =======================================================

  update public.battle_question_rounds
  set
    winner_player =
      p_player,

    winner_answer =
      p_answer_index,

    won_at =
      now(),

    status =
      'won'
  where id =
    p_question_round_id;


  -- =======================================================
  -- GIVE BONUS
  -- =======================================================

  if v_reward is not null then
    insert into public.battle_bonus_skills (
      battle_id,
      player,
      skill_type,
      used,
      source
    )
    values (
      v_battle.id,
      p_player,
      v_reward,
      false,
      'question'
    );


  end if;


  -- =======================================================
  -- RESUME BATTLE
  -- =======================================================

  update public.battle_sessions
  set
    question_active =
      false,

    status =
      'battle'
  where id =
    v_battle.id;


  -- =======================================================
  -- EVENT
  -- =======================================================

  insert into public.battle_events (
    battle_id,
    type,
    source_player,
    payload
  )
  values (
    v_battle.id,
    'question_winner',
    p_player,
    jsonb_build_object(
      'reward',
      v_reward,
      'message',
      upper(p_player)
      || ' wins coding challenge'
    )
  );


  return jsonb_build_object(
    'ok', true,
    'correct', true,
    'winner', p_player,
    'correct_answer',v_correct_answer,
    'correct_option',v_correct_option,
    'reward', v_reward,
    'message', 'Correct! Kamu memenangkan coding challenge.'
  );

end;
$function$
;
