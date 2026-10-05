-- Per-battle question controls, learning content and server-validated interactive questions.
ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS question_topics text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS question_time_limit_seconds integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS question_bonus_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS question_learning_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE public.coding_questions
  ADD COLUMN IF NOT EXISTS question_type text NOT NULL DEFAULT 'choice',
  ADD COLUMN IF NOT EXISTS blocks jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS correct_sequence jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS code_snippet text,
  ADD COLUMN IF NOT EXISTS bug_line integer,
  ADD COLUMN IF NOT EXISTS hint_1 text,
  ADD COLUMN IF NOT EXISTS hint_2 text,
  ADD COLUMN IF NOT EXISTS learning_topic text,
  ADD COLUMN IF NOT EXISTS learning_url text;
UPDATE public.coding_questions SET learning_topic=category WHERE learning_topic IS NULL;
CREATE INDEX IF NOT EXISTS coding_questions_battle_pool_idx
  ON public.coding_questions (is_active,difficulty,category);

INSERT INTO public.coding_questions (
  id,question,image_url,option_a,option_b,option_c,option_d,
  correct_answer,explanation,category,difficulty,level,is_active,
  question_type,blocks,correct_sequence,code_snippet,bug_line,
  hint_1,hint_2,learning_topic,learning_url
) VALUES
(
  'bb42f4c7-c811-5e32-a492-065020c6c180',
  'Susun blok Scratch agar program dimulai, bergerak, lalu menampilkan sapaan.',
  '/images/questions/scratch-events.svg',
  'Urutan blok tersusun benar','Urutannya belum benar','Blok tidak lengkap','Belum disusun',
  'A','Program dimulai dari blok peristiwa, lalu menjalankan gerak dan tampilan sesuai urutan.',
  'scratch','easy','easy',true,'block_order',
  '["Ketika bendera hijau diklik","Gerak 10 langkah","Katakan Halo"]'::jsonb,
  '[0,1,2]'::jsonb,null,null,
  'Cari blok peristiwa yang memulai skrip.','Setelah itu pikirkan urutan aksi yang ingin terlihat.',
  'Scratch: peristiwa dan urutan blok','https://scratch.mit.edu/ideas'
),
(
  'e3b72c68-c053-502f-a9f1-1b833734280a',
  'Susun blok agar sprite mengulang gerakan maju sebanyak tiga kali.',
  '/images/questions/scratch-loop.svg',
  'Urutan blok tersusun benar','Urutannya belum benar','Blok tidak lengkap','Belum disusun',
  'A','Blok pengulangan harus membungkus gerakan yang ingin dilakukan berulang.',
  'scratch','easy','easy',true,'block_order',
  '["Ketika bendera hijau diklik","Ulangi 3 kali","Gerak 10 langkah"]'::jsonb,
  '[0,1,2]'::jsonb,null,null,
  'Temukan blok yang membuat perintah berulang.','Letakkan perintah gerak di dalam blok tersebut.',
  'Scratch: perulangan','https://scratch.mit.edu/ideas'
),
(
  '93590a63-d33f-5bbb-924a-7420613e0303',
  'Sprite seharusnya bergerak maju. Baris mana yang membuatnya bergerak mundur?',
  '/images/questions/scratch-motion.svg',
  'when green flag clicked','repeat 5','move -10 steps','say "Done"',
  'C','Angka negatif pada langkah gerak membalik arah sehingga sprite bergerak mundur.',
  'scratch','medium','medium',true,'find_bug',
  '[]'::jsonb,'[]'::jsonb,
  'when green flag clicked\nrepeat 5\nmove -10 steps\nsay "Done"',2,
  'Perhatikan tanda pada nilai langkah gerak.','Nilai negatif menggerakkan sprite ke arah berlawanan.',
  'Scratch: arah dan gerak','https://scratch.mit.edu/ideas'
),
(
  '3e41c09d-1a15-5628-aa58-c78f2ad6f29b',
  'Baris mana yang menambahkan 2 poin ke skor saat koin diterima?',
  '/images/questions/score-increment.svg',
  'when I receive coin','change score by 1','change score by 2','say score',
  'C','Baris "change score by 2" menambahkan dua poin pada variabel score setiap kali blok tersebut dijalankan.',
  'block_coding','medium','medium',true,'find_bug',
  '[]'::jsonb,'[]'::jsonb,
  E'when I receive coin\nchange score by 1\nchange score by 2\nsay score',2,
  'Cari perintah yang mengubah variabel score.','Bandingkan angka setelah "change score by" pada setiap baris.',
  'Block coding: variabel dan skor',null
)
ON CONFLICT (id) DO UPDATE SET
  question=excluded.question,image_url=excluded.image_url,
  option_a=excluded.option_a,option_b=excluded.option_b,
  option_c=excluded.option_c,option_d=excluded.option_d,
  correct_answer=excluded.correct_answer,explanation=excluded.explanation,
  category=excluded.category,difficulty=excluded.difficulty,level=excluded.level,
  is_active=excluded.is_active,question_type=excluded.question_type,
  blocks=excluded.blocks,correct_sequence=excluded.correct_sequence,
  code_snippet=excluded.code_snippet,bug_line=excluded.bug_line,
  hint_1=excluded.hint_1,hint_2=excluded.hint_2,
  learning_topic=excluded.learning_topic,learning_url=excluded.learning_url,
  updated_at=now();

CREATE OR REPLACE FUNCTION public.tcg_expire_battle_question(p_battle_id uuid,p_question_round_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_round public.battle_question_rounds%rowtype;
  v_seconds integer;
begin
  select * into v_battle from public.battle_sessions where id=p_battle_id for update;
  if not found or not coalesce(v_battle.question_active,false) then
    return jsonb_build_object('ok',false,'timed_out',false,'message','Question sudah tidak aktif.');
  end if;
  select * into v_round from public.battle_question_rounds
   where id=p_question_round_id and battle_id=p_battle_id for update;
  if not found or v_round.winner_player is not null then
    return jsonb_build_object('ok',false,'timed_out',false,'message','Question round sudah selesai.');
  end if;
  v_seconds := greatest(0,coalesce(v_battle.question_time_limit_seconds,0));
  if v_seconds=0 or v_round.created_at is null
     or now() < v_round.created_at + make_interval(secs=>v_seconds) then
    return jsonb_build_object('ok',false,'timed_out',false,'message','Waktu menjawab masih tersedia.');
  end if;
  update public.battle_question_rounds set status='timed_out' where id=v_round.id;
  update public.battle_sessions set question_active=false,status='battle',
    current_question_id=null,current_question_round_id=null where id=v_battle.id;
  insert into public.battle_events(battle_id,type,payload) values (
    v_battle.id,'question_timeout',jsonb_build_object('question_round_id',v_round.id,'message','Waktu menjawab habis.')
  );
  return jsonb_build_object('ok',true,'timed_out',true,'message','Waktu menjawab habis. Battle dilanjutkan.');
end;
$function$;
REVOKE ALL ON FUNCTION public.tcg_expire_battle_question(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.finish_battle_question_timeout(
  p_code text,p_player text,p_token text,p_question_round_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_expected_token text;
begin
  if lower(coalesce(p_player,'')) not in ('p1','p2') then
    return jsonb_build_object('ok',false,'message','Player tidak valid.');
  end if;
  select * into v_battle from public.battle_sessions
   where upper(code)=upper(trim(coalesce(p_code,''))) for update;
  if not found then return jsonb_build_object('ok',false,'message','Battle tidak ditemukan.'); end if;
  v_expected_token := case when lower(p_player)='p1' then v_battle.player1_token else v_battle.player2_token end;
  if v_expected_token is null or p_token is null or p_token<>v_expected_token then
    return jsonb_build_object('ok',false,'message','Player token tidak valid.');
  end if;
  return public.tcg_expire_battle_question(v_battle.id,p_question_round_id);
end;
$function$;
GRANT EXECUTE ON FUNCTION public.finish_battle_question_timeout(text,text,text,uuid) TO anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.submit_battle_interactive_question_answer(
  p_code text,p_player text,p_token text,p_question_round_id uuid,p_interactive_answer jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
declare
  v_battle public.battle_sessions%rowtype;
  v_round public.battle_question_rounds%rowtype;
  v_question public.coding_questions%rowtype;
  v_answer_index integer;
  v_order jsonb;
begin
  select * into v_battle from public.battle_sessions
   where upper(code)=upper(trim(coalesce(p_code,'')));
  if not found then return jsonb_build_object('ok',false,'message','Battle tidak ditemukan.'); end if;
  select * into v_round from public.battle_question_rounds
   where id=p_question_round_id and battle_id=v_battle.id;
  if not found then return jsonb_build_object('ok',false,'message','Question round tidak ditemukan.'); end if;
  select * into v_question from public.coding_questions where id=v_round.question_id;
  if not found then return jsonb_build_object('ok',false,'message','Question tidak ditemukan.'); end if;

  if lower(coalesce(v_question.question_type,'choice'))='block_order' then
    v_order := p_interactive_answer->'order';
    if jsonb_typeof(v_order)<>'array' then
      return jsonb_build_object('ok',false,'message','Urutan blok belum dikirim.');
    end if;
    v_answer_index := case when v_order=v_question.correct_sequence then 0 else 1 end;
  elsif lower(coalesce(v_question.question_type,'choice'))='find_bug' then
    begin v_answer_index := (p_interactive_answer->>'line_index')::integer;
    exception when others then v_answer_index := -1; end;
    if v_answer_index<0 or v_answer_index>3 then
      return jsonb_build_object('ok',false,'message','Pilih baris kode yang bermasalah.');
    end if;
  else
    return jsonb_build_object('ok',false,'message','Soal ini memakai pilihan jawaban biasa.');
  end if;
  return public.submit_battle_question_answer(p_code,p_player,p_token,p_question_round_id,v_answer_index);
end;
$function$;
GRANT EXECUTE ON FUNCTION public.submit_battle_interactive_question_answer(text,text,text,uuid,jsonb) TO anon,authenticated,service_role;

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
    'reward', v_reward,
    'message', 'Correct! Kamu memenangkan coding challenge.'
  );

end;
$function$
;

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
  v_question_candidate uuid := null;
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

  -- Enforce the selected topic filters after the legacy scheduler creates a
  -- question. The chosen difficulty is kept; mixed allows every level.
  if coalesce(v_after.question_active,false)
     and coalesce(cardinality(v_before.question_topics),0) > 0
     and v_after.current_question_round_id is not null then
    select cq.id into v_question_candidate
      from public.coding_questions cq
     where coalesce(cq.is_active,true)
       and lower(coalesce(cq.category,'')) = any(v_before.question_topics)
       and (
         lower(coalesce(v_before.question_level,'medium')) = 'mixed'
         or lower(coalesce(cq.difficulty,'medium')) = lower(coalesce(v_before.question_level,'medium'))
       )
     order by random()
     limit 1;

    if v_question_candidate is not null then
      update public.battle_question_rounds
         set question_id = v_question_candidate
       where id = v_after.current_question_round_id
         and battle_id = v_before.id
         and status = 'active';
      update public.battle_sessions
         set current_question_id = v_question_candidate
       where id = v_before.id;
      select * into v_after from public.battle_sessions where id = v_before.id;
    end if;
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
