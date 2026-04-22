-- ═══════════════════════════════════════════════════════════════════════════
-- Avatar moderation: report queue + NSFW flagged queue
-- ═══════════════════════════════════════════════════════════════════════════
-- Strategy (free, hybrid):
--   1. Front-end runs NSFWJS / TFLite inference on the avatar bytes
--      BEFORE upload. Porn/Hentai > 0.7 → reject. Sexy > 0.5 → upload
--      but mark `users.avatar_status = 'pending_review'` so the avatar
--      doesn't show until an admin clears it.
--   2. Any user can report another user's avatar (front-end "..." menu).
--      A row in `avatar_reports` is created. When reports >= 3 the
--      avatar auto-flips to 'pending_review' (server-side guard against
--      a malicious user bypassing the front-end check).
--   3. (Future) Supabase Edge Function on storage.objects insert runs
--      a server-side NSFW model — defends against the user disabling
--      their JS. Out of scope for this migration; the schema is ready.

begin;

-- 1. Avatar status enum.
do $$ begin
  create type public.avatar_status as enum (
    'ok',                 -- visible normally
    'pending_review',     -- hidden from public surfaces until admin clears
    'rejected'            -- replaced with placeholder; user can re-upload
  );
exception when duplicate_object then null;
end $$;

alter table public.users
  add column if not exists avatar_status public.avatar_status
    not null default 'ok';

-- Reports threshold helper (read from a settings row would be nicer
-- long-term; hard-coded constant is fine for now).
create or replace function public._avatar_auto_flag_threshold()
returns int
language sql
immutable
as $$ select 3; $$;

-- 2. Reports table.
create table if not exists public.avatar_reports (
  id uuid primary key default gen_random_uuid(),
  -- Whose avatar is being reported.
  target_user_id uuid not null references public.users(id) on delete cascade,
  -- Who reported.
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text,                                 -- free-form short note
  created_at timestamptz not null default now(),
  -- One report per (reporter, target) — re-tapping does nothing.
  unique (target_user_id, reporter_id)
);

create index if not exists avatar_reports_target
  on public.avatar_reports (target_user_id, created_at desc);

-- RLS: anyone signed-in can INSERT a report (against anyone but self).
-- Reads restricted to admins via the existing `users.role` check
-- (admin / owner). Reporters cannot list other reports.
alter table public.avatar_reports enable row level security;

drop policy if exists avatar_reports_insert_self on public.avatar_reports;
create policy avatar_reports_insert_self
  on public.avatar_reports for insert
  with check (
    reporter_id = auth.uid()
    and target_user_id <> auth.uid()
  );

drop policy if exists avatar_reports_admin_read on public.avatar_reports;
create policy avatar_reports_admin_read
  on public.avatar_reports for select
  using (
    exists (
      select 1 from public.users
      where id = auth.uid() and role in ('admin', 'owner')
    )
  );

-- 3. Auto-flag trigger — when distinct reports for one user reach the
--    threshold, push avatar_status → 'pending_review'.
create or replace function public.maybe_flag_avatar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cnt int;
begin
  select count(*) into cnt
  from public.avatar_reports
  where target_user_id = new.target_user_id;

  if cnt >= public._avatar_auto_flag_threshold() then
    update public.users
       set avatar_status = 'pending_review'
     where id = new.target_user_id
       and avatar_status = 'ok';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_maybe_flag_avatar on public.avatar_reports;
create trigger trg_maybe_flag_avatar
  after insert on public.avatar_reports
  for each row execute function public.maybe_flag_avatar();

-- 4. Front-end facing RPCs.
--    report_avatar(p_target_user_id, p_reason text)
--    admin_avatar_queue() returns pending_review users
--    admin_clear_avatar(p_user_id) → 'ok'
--    admin_reject_avatar(p_user_id) → 'rejected', avatar_url := null

create or replace function public.report_avatar(
  p_target_user_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'auth required';
  end if;
  if auth.uid() = p_target_user_id then
    raise exception 'cannot report self';
  end if;
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (p_target_user_id, auth.uid(), p_reason)
  on conflict (target_user_id, reporter_id) do nothing;
end;
$$;

grant execute on function public.report_avatar(uuid, text) to authenticated;

create or replace function public.admin_avatar_queue()
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  report_count int,
  flagged_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    u.id,
    u.display_name,
    u.avatar_url,
    coalesce((select count(*) from public.avatar_reports where target_user_id = u.id), 0)::int,
    (select max(created_at) from public.avatar_reports where target_user_id = u.id)
  from public.users u
  where u.avatar_status = 'pending_review'
    and exists (
      select 1 from public.users me
      where me.id = auth.uid() and me.role in ('admin', 'owner')
    )
  order by 5 desc;
$$;

grant execute on function public.admin_avatar_queue() to authenticated;

create or replace function public.admin_clear_avatar(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.users
    where id = auth.uid() and role in ('admin', 'owner')
  ) then
    raise exception 'admin only';
  end if;
  update public.users set avatar_status = 'ok' where id = p_user_id;
  -- Wipe historical reports for this user — they've been adjudicated.
  delete from public.avatar_reports where target_user_id = p_user_id;
end;
$$;

grant execute on function public.admin_clear_avatar(uuid) to authenticated;

create or replace function public.admin_reject_avatar(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.users
    where id = auth.uid() and role in ('admin', 'owner')
  ) then
    raise exception 'admin only';
  end if;
  update public.users
     set avatar_status = 'rejected', avatar_url = null
   where id = p_user_id;
  delete from public.avatar_reports where target_user_id = p_user_id;
end;
$$;

grant execute on function public.admin_reject_avatar(uuid) to authenticated;

-- 5. Public profile RPC update — when avatar_status != 'ok', return
--    null avatar_url so consumers render the placeholder.
create or replace function public.user_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u_row public.users%rowtype;
  approved_count int;
  result jsonb;
  visible_avatar text;
begin
  select * into u_row from public.users where id = p_user_id;
  if not found or u_row.is_public = false then
    return null;
  end if;

  visible_avatar := case
    when u_row.avatar_status = 'ok' then u_row.avatar_url
    else null
  end;

  select count(*) into approved_count
  from public.posters
  where uploader_id = p_user_id
    and status = 'approved'
    and deleted_at is null;

  result := jsonb_build_object(
    'id', u_row.id,
    'display_name', u_row.display_name,
    'handle', u_row.handle,
    'avatar_url', visible_avatar,
    'bio', u_row.bio,
    'submission_count', u_row.submission_count,
    'approved_poster_count', approved_count,
    'is_public', u_row.is_public
  );
  return result;
end;
$$;

commit;
