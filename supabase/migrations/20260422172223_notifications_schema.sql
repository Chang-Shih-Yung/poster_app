-- ═══════════════════════════════════════════════════════════════════════════
-- Notifications: real backend (was a UI-only shell pre-v19)
-- ═══════════════════════════════════════════════════════════════════════════
-- The notifications page in the front-end has been a demo since launch:
-- empty list, fake categories, always-on red dot in the bottom nav.
-- This migration adds the real plumbing: a notifications table, triggers
-- on the events that should generate one (follow / favorite /
-- submission decision), and three RPCs the front-end consumes
-- (unread count, list, mark read).

begin;

-- 1. Type enum — categorisation lives in the schema so the front-end
--    filter tabs (全部 / 社交 / 系統) stay consistent with the
--    insert-side. Adding a new type later: ALTER TYPE ... ADD VALUE.
do $$ begin
  create type public.notification_type as enum (
    'follow',         -- someone followed you
    'favorite',       -- someone favorited a poster you uploaded
    'submission_approved',
    'submission_rejected'
  );
exception when duplicate_object then null;
end $$;

-- 2. Table.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  -- Recipient — the user who sees this notification.
  user_id uuid not null references public.users(id) on delete cascade,
  type public.notification_type not null,
  -- Actor — the user who triggered the event (null for system events
  -- like submission decisions).
  actor_id uuid references public.users(id) on delete set null,
  -- Target — the thing the notification is about (poster id for
  -- favorite / approval, user id for follow).
  target_id uuid,
  target_kind text, -- 'poster' | 'user' | 'submission'
  -- Free-form payload, e.g. {"title":"花樣年華","note":"..."}.
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- Indexes — list-by-recipient (newest first) is the dominant query;
-- unread-count is a partial scan over the same composite.
create index if not exists notifications_user_recent
  on public.notifications (user_id, created_at desc);
create index if not exists notifications_user_unread
  on public.notifications (user_id)
  where read_at is null;

-- 3. RLS — recipient can only see their own notifications.
alter table public.notifications enable row level security;

drop policy if exists notifications_self_read on public.notifications;
create policy notifications_self_read
  on public.notifications for select
  using (user_id = auth.uid());

drop policy if exists notifications_self_update on public.notifications;
create policy notifications_self_update
  on public.notifications for update
  using (user_id = auth.uid());

-- Inserts come from triggers (running as security-definer functions),
-- so no public INSERT policy.

-- 4. Trigger on follows — followee gets notified.
create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Don't notify self-follows (CHECK constraint prevents this anyway,
  -- but defending in depth).
  if new.follower_id = new.followee_id then
    return new;
  end if;
  insert into public.notifications (user_id, type, actor_id, target_id, target_kind)
  values (new.followee_id, 'follow', new.follower_id, new.follower_id, 'user');
  return new;
end;
$$;

drop trigger if exists trg_notify_on_follow on public.follows;
create trigger trg_notify_on_follow
  after insert on public.follows
  for each row execute function public.notify_on_follow();

-- 5. Trigger on favorites — uploader gets notified (skip self-fav).
create or replace function public.notify_on_favorite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uploader uuid;
  poster_title text;
begin
  select uploader_id, title into uploader, poster_title
  from public.posters where id = new.poster_id;
  if uploader is null or uploader = new.user_id then
    return new;
  end if;
  insert into public.notifications
    (user_id, type, actor_id, target_id, target_kind, payload)
  values (
    uploader, 'favorite', new.user_id, new.poster_id, 'poster',
    jsonb_build_object('title', poster_title)
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_on_favorite on public.favorites;
create trigger trg_notify_on_favorite
  after insert on public.favorites
  for each row execute function public.notify_on_favorite();

-- 6. Trigger on submission status change — only fire when status
--    transitions into 'approved' or 'rejected' (skip pending churn).
create or replace function public.notify_on_submission_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ntype public.notification_type;
begin
  if new.status = old.status then return new; end if;
  if new.status = 'approved' then
    ntype := 'submission_approved';
  elsif new.status = 'rejected' then
    ntype := 'submission_rejected';
  else
    return new;
  end if;
  insert into public.notifications
    (user_id, type, target_id, target_kind, payload)
  values (
    new.uploader_id, ntype, new.id, 'submission',
    jsonb_build_object(
      'title', coalesce(new.title, '未命名投稿'),
      'note', coalesce(new.review_note, '')
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_on_submission_decision on public.submissions;
create trigger trg_notify_on_submission_decision
  after update on public.submissions
  for each row execute function public.notify_on_submission_decision();

-- 7. RPCs the front-end calls.
--    list_notifications: paged list newest-first, optional unread-only.
--    unread_notifications_count: quick single-int for the nav badge.
--    mark_notifications_read: array of ids, set read_at = now().

create or replace function public.list_notifications(
  p_offset int default 0,
  p_limit int default 30,
  p_unread_only boolean default false
)
returns setof public.notifications
language sql
security definer
set search_path = public
as $$
  select *
  from public.notifications
  where user_id = auth.uid()
    and (not p_unread_only or read_at is null)
  order by created_at desc
  offset p_offset
  limit p_limit;
$$;

create or replace function public.unread_notifications_count()
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
  from public.notifications
  where user_id = auth.uid()
    and read_at is null;
$$;

create or replace function public.mark_notifications_read(
  p_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
     set read_at = now()
   where user_id = auth.uid()
     and id = any(p_ids)
     and read_at is null;
end;
$$;

grant execute on function public.list_notifications(int, int, boolean) to authenticated;
grant execute on function public.unread_notifications_count() to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

commit;
