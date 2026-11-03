-- Diwali Triathlon leaderboard.
-- Run this once in Supabase: Dashboard > SQL Editor > New query > paste > Run.
-- Safe to run again; it replaces the functions and keeps existing scores.
--
-- Design: the browser never reads or writes the table directly. It can only call
-- the four functions at the bottom, which validate input, add up the total on the
-- server, and never reveal anyone's device id.

create schema if not exists private;

create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  device_id  uuid        not null,
  name       text        not null check (char_length(name) between 1 and 24),
  diya       integer     not null check (diya    between 0 and 5000),
  fire       integer     not null check (fire    between 0 and 5000),
  rangoli    integer     not null check (rangoli between 0 and 5000),
  total      integer     generated always as (diya + fire + rangoli) stored,
  created_at timestamptz not null default now()
);

create index if not exists scores_device_idx on public.scores (device_id);
create index if not exists scores_total_idx  on public.scores (total desc, created_at asc);

-- Row level security on, with no policies: the public API key cannot select,
-- insert, update or delete rows directly.
alter table public.scores enable row level security;
revoke all on public.scores from anon, authenticated;

-- Each player's best run, ranked. Lives in a schema the API doesn't expose.
create or replace view private.leaderboard as
select
  b.device_id, b.name, b.total, b.diya, b.fire, b.rangoli, b.created_at,
  row_number() over (order by b.total desc, b.created_at asc) as rank
from (
  select distinct on (device_id) device_id, name, total, diya, fire, rangoli, created_at
  from public.scores
  order by device_id, total desc, created_at asc
) b;

-- Top N players for the board.
create or replace function public.top_scores(p_limit integer default 5)
returns table (rank bigint, name text, total integer, diya integer, fire integer, rangoli integer)
language sql stable security definer set search_path = public, private
as $$
  select l.rank, l.name, l.total, l.diya, l.fire, l.rangoli
  from private.leaderboard l
  order by l.rank
  limit least(greatest(coalesce(p_limit, 5), 1), 50);
$$;

-- One player's standing, plus how many players are on the board.
create or replace function public.my_standing(p_device uuid)
returns table (rank bigint, name text, total integer, diya integer, fire integer, rangoli integer, players bigint)
language sql stable security definer set search_path = public, private
as $$
  select l.rank, l.name, l.total, l.diya, l.fire, l.rangoli,
         (select count(*) from private.leaderboard)
  from private.leaderboard l
  where l.device_id = p_device;
$$;

-- Post a run. The server adds the three games into the total.
create or replace function public.post_score(p_device uuid, p_name text, p_diya integer, p_fire integer, p_rangoli integer)
returns table (rank bigint, total integer)
language plpgsql security definer set search_path = public, private
as $$
declare
  clean text := left(regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g'), 24);
begin
  if clean = '' then
    raise exception 'Type a name first' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.scores
    where device_id = p_device and created_at > now() - interval '15 seconds'
  ) then
    raise exception 'Please wait a few seconds before posting again' using errcode = '22023';
  end if;

  insert into public.scores (device_id, name, diya, fire, rangoli)
  values (p_device, clean, p_diya, p_fire, p_rangoli);

  -- Keep one name per player across all their runs.
  update public.scores set name = clean where device_id = p_device and name <> clean;

  return query
    select l.rank, l.total from private.leaderboard l where l.device_id = p_device;
end;
$$;

-- Change the name on all of a player's runs.
create or replace function public.rename_player(p_device uuid, p_name text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  clean text := left(regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g'), 24);
begin
  if clean = '' then
    raise exception 'Type a name first' using errcode = '22023';
  end if;
  update public.scores set name = clean where device_id = p_device;
end;
$$;

revoke all on function public.top_scores(integer)                                  from public;
revoke all on function public.my_standing(uuid)                                    from public;
revoke all on function public.post_score(uuid, text, integer, integer, integer)    from public;
revoke all on function public.rename_player(uuid, text)                            from public;
grant execute on function public.top_scores(integer)                               to anon, authenticated;
grant execute on function public.my_standing(uuid)                                 to anon, authenticated;
grant execute on function public.post_score(uuid, text, integer, integer, integer) to anon, authenticated;
grant execute on function public.rename_player(uuid, text)                         to anon, authenticated;
