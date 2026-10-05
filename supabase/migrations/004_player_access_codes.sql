-- Short, human-friendly player codes that resolve to the existing private tokens.
alter table public.battle_sessions
  add column if not exists player1_access_code text,
  add column if not exists player2_access_code text;

update public.battle_sessions
set player1_access_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))
where player1_access_code is null or player1_access_code = '';

update public.battle_sessions
set player2_access_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))
where player2_access_code is null or player2_access_code = '';

create unique index if not exists battle_sessions_player1_access_code_key
  on public.battle_sessions (player1_access_code)
  where player1_access_code is not null;

create unique index if not exists battle_sessions_player2_access_code_key
  on public.battle_sessions (player2_access_code)
  where player2_access_code is not null;
