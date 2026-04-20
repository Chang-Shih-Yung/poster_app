-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 15-4 → 15-7: collaborative filtering infrastructure
-- ═══════════════════════════════════════════════════════════════════════════
-- "People who favorited what you favorited also favorited X"
--
-- Pre-computed nightly via pg_cron. Each user gets a row in
-- user_recommendations per recommended poster. Home page reads from
-- the table at request time (O(1) per user).
--
-- Cold start: same fallback as v1 — < 3 favorites → trending.
-- Stale-data tolerance: results refresh nightly, that's enough for now.

begin;

-- ─── pg_cron extension ────────────────────────────────────────────────────
-- Supabase ships pg_cron; need to be enabled per project.
create extension if not exists pg_cron with schema extensions;

-- ─── Tables ───────────────────────────────────────────────────────────────

create table if not exists public.user_recommendations (
  user_id uuid not null references public.users(id) on delete cascade,
  poster_id uuid not null references public.posters(id) on delete cascade,
  score float not null,
  reason text,                      -- 'similar_favorites' | 'tag_match:slug'
  job_slug text not null,           -- which job produced this row
  computed_at timestamptz not null default now(),
  primary key (user_id, poster_id, job_slug)
);

create index if not exists idx_user_recs_user
  on public.user_recommendations (user_id, score desc);

alter table public.user_recommendations enable row level security;
create policy user_recs_read_own on public.user_recommendations
  for select using (user_id = auth.uid() or public.is_admin());
-- writes are batch-job only (security definer functions); deny direct
create policy user_recs_admin_write on public.user_recommendations
  for all using (public.is_admin()) with check (public.is_admin());


create table if not exists public.recommendation_jobs (
  slug text primary key,
  algorithm text not null,
  params jsonb not null default '{}',
  cron_expr text,                   -- e.g. '0 3 * * *' (daily 03:00 UTC)
  enabled boolean not null default true,
  last_run_at timestamptz,
  last_user_count int,
  last_row_count int,
  last_duration_ms int,
  created_at timestamptz not null default now()
);

alter table public.recommendation_jobs enable row level security;
create policy recommendation_jobs_read_admin on public.recommendation_jobs
  for select using (public.is_admin());
create policy recommendation_jobs_admin_write on public.recommendation_jobs
  for all using (public.is_admin()) with check (public.is_admin());


-- ─── 15-6: collaborative filter compute function ──────────────────────────
-- Runs nightly. For every user with ≥ 5 favorites:
--   1. Find top-50 similar users (≥ 3 common favorites)
--   2. Their favorites I haven't seen → score by overlap weight
--   3. Cap top-30 per user, replace previous nightly run

create or replace function public.compute_collaborative_recommendations()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  job_started timestamptz := clock_timestamp();
  user_count int := 0;
  row_count int := 0;
begin
  -- Wipe previous nightly results (fresh recompute).
  delete from public.user_recommendations where job_slug = 'cf_nightly';

  -- For each active user with enough signal:
  insert into public.user_recommendations
    (user_id, poster_id, score, reason, job_slug, computed_at)
  with active_users as (
    select user_id
    from public.favorites
    group by user_id
    having count(*) >= 5
  ),
  similar_users as (
    select me.user_id as me_id, them.user_id as them_id,
           count(*) as overlap
    from public.favorites me
    join public.favorites them
      on them.poster_id = me.poster_id
     and them.user_id != me.user_id
    where me.user_id in (select user_id from active_users)
    group by me.user_id, them.user_id
    having count(*) >= 3
  ),
  ranked_similar as (
    -- Cap at 50 most-similar-users per me_id
    select me_id, them_id, overlap,
           row_number() over (partition by me_id order by overlap desc) as rn
    from similar_users
  ),
  candidate_recs as (
    select rs.me_id as user_id,
           f.poster_id,
           sum(rs.overlap)::float as score
    from ranked_similar rs
    join public.favorites f on f.user_id = rs.them_id
    where rs.rn <= 50
      and not exists (
        select 1 from public.favorites mf
        where mf.user_id = rs.me_id and mf.poster_id = f.poster_id
      )
    group by rs.me_id, f.poster_id
  ),
  ranked_recs as (
    select user_id, poster_id, score,
           row_number() over (partition by user_id order by score desc) as rank_pos
    from candidate_recs
  )
  select rr.user_id,
         rr.poster_id,
         rr.score,
         'similar_favorites'::text,
         'cf_nightly'::text,
         now()
  from ranked_recs rr
  join public.posters p on p.id = rr.poster_id
    and p.status = 'approved'
    and p.deleted_at is null
  where rr.rank_pos <= 30;

  get diagnostics row_count = row_count;

  select count(distinct user_id) into user_count
  from public.user_recommendations
  where job_slug = 'cf_nightly';

  update public.recommendation_jobs
  set last_run_at = now(),
      last_user_count = user_count,
      last_row_count = row_count,
      last_duration_ms = (extract(epoch from clock_timestamp() - job_started) * 1000)::int
  where slug = 'cf_nightly';
end $$;

grant execute on function public.compute_collaborative_recommendations() to authenticated;

-- Register the job
insert into public.recommendation_jobs (slug, algorithm, params, cron_expr)
values ('cf_nightly', 'collaborative_filter',
        '{"min_favs": 5, "min_overlap": 3, "top_similar_users": 50, "top_recs": 30}'::jsonb,
        '0 19 * * *')  -- 03:00 Asia/Taipei = 19:00 UTC previous day
on conflict (slug) do nothing;

-- ─── 15-7: for_you_feed_cf RPC reads pre-computed table ───────────────────
-- Used when user has CF data. Fast O(1) per user.

create or replace function public.for_you_feed_cf(p_limit int default 12)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  result jsonb;
begin
  uid := auth.uid();
  if uid is null then
    return public.trending_favorites(7, p_limit);
  end if;

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into result
  from (
    select p.id, p.title, p.year, p.director, p.tags,
           p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
           p.view_count, p.favorite_count, p.created_at,
           ur.score as recommendation_score
    from public.user_recommendations ur
    join public.posters p on p.id = ur.poster_id
      and p.status = 'approved' and p.deleted_at is null
    where ur.user_id = uid
      and ur.job_slug = 'cf_nightly'
    order by ur.score desc
    limit p_limit
  ) t;

  -- Empty (cold start / stale) → fall back to v1 (which itself falls
  -- back to trending if the user is new)
  if jsonb_array_length(result) = 0 then
    return public.for_you_feed_v1(p_limit);
  end if;

  return result;
end $$;

grant execute on function public.for_you_feed_cf(int) to authenticated;

-- ─── 15-5: schedule the cron job ──────────────────────────────────────────
-- Cron syntax: minute hour day month dow (UTC)
-- 0 19 * * * = 03:00 Asia/Taipei (UTC+8)
-- Wrapped in DO so re-runs don't double-schedule.
do $$
begin
  if not exists(select 1 from cron.job where jobname = 'cf_nightly') then
    perform cron.schedule(
      'cf_nightly',
      '0 19 * * *',
      $cron$ select public.compute_collaborative_recommendations(); $cron$
    );
  end if;
end $$;

commit;
