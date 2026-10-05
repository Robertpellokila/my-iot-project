-- Battle sessions are joinable for 24 hours by default. Admins may reactivate
-- an expired battle, which starts a fresh 24-hour window. A declared winner
-- always locks the battle as inactive.

create extension if not exists pg_cron with schema pg_catalog;

alter table public.battle_sessions
  add column if not exists is_active boolean not null default true,
  add column if not exists active_until timestamptz;

update public.battle_sessions
set
  is_active = (
    nullif(trim(coalesce(winner::text, '')), '') is null
    and created_at > now() - interval '24 hours'
  ),
  active_until = case
    when nullif(trim(coalesce(winner::text, '')), '') is not null then null
    when created_at > now() - interval '24 hours' then created_at + interval '24 hours'
    else null
  end
where active_until is null
  and (
    is_active = true
    or nullif(trim(coalesce(winner::text, '')), '') is not null
  );

create or replace function public.enforce_battle_activation_window()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if nullif(trim(coalesce(new.winner::text, '')), '') is not null then
    new.is_active := false;
    new.active_until := null;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.is_active then
      new.active_until := coalesce(
        new.active_until,
        coalesce(new.created_at, now()) + interval '24 hours'
      );
      if new.active_until <= now() then
        new.is_active := false;
        new.active_until := null;
      end if;
    else
      new.active_until := null;
    end if;
    return new;
  end if;

  if new.is_active is distinct from old.is_active then
    if new.is_active then
      new.active_until := now() + interval '24 hours';
    else
      new.active_until := null;
    end if;
  elsif new.is_active then
    if coalesce(new.active_until, old.active_until) <= now() then
      new.is_active := false;
      new.active_until := null;
    else
      new.active_until := coalesce(new.active_until, old.active_until);
    end if;
  else
    new.active_until := null;
  end if;

  return new;
end;
$$;

drop trigger if exists battle_sessions_activation_window on public.battle_sessions;
create trigger battle_sessions_activation_window
before insert or update of is_active, active_until, winner
on public.battle_sessions
for each row
execute function public.enforce_battle_activation_window();

create index if not exists battle_sessions_active_expiry_idx
  on public.battle_sessions (active_until)
  where is_active = true and active_until is not null;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'expire-inactive-battles';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-inactive-battles',
    '* * * * *',
    $job$
      update public.battle_sessions
      set is_active = false
      where is_active = true
        and active_until is not null
        and active_until <= now()
        and nullif(trim(coalesce(winner::text, '')), '') is null;
    $job$
  );
end;
$$;
