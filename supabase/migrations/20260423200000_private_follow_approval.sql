-- ═══════════════════════════════════════════════════════════════════════════
-- #10 · IG-style private follow-approval flow
--
-- Before this migration, `users.is_public = false` hid the profile
-- entirely (user_public_profile returned null). That's too strict —
-- Instagram's model lets anyone SEE the profile exists but requires
-- an approved follow before anything beyond the name is visible.
--
-- This migration:
--   1. adds follows.status enum('accepted', 'pending') default 'accepted'
--      and backfills every existing row to 'accepted'
--   2. teaches toggle_follow to create a pending row when the target
--      is_public = false
--   3. adds approve_follow_request / reject_follow_request RPCs for
--      the target to act on their pending queue
--   4. adds the 'follow_request' notification type + rewires
--      notify_on_follow to fire follow_request on pending insert and
--      follow on pending→accepted update (or direct insert)
--   5. reworks user_relationship_stats to count only accepted edges
--      and expose viewer_follow_status = 'none' | 'pending' | 'accepted'
--   6. reworks user_public_profile to always return the profile row
--      (respecting avatar_status) plus is_public + viewer_follow_status
--      so the client can render the "僅限追蹤者查看" gate without
--      a second round-trip
--   7. teaches follow_feed to skip pending rows
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- 1. ENUM + column ---------------------------------------------------

do $$ begin
  create type public.follow_status as enum ('accepted', 'pending');
exception when duplicate_object then null;
end $$;

alter table public.follows
  add column if not exists status public.follow_status not null default 'accepted';

-- Backfill — every existing row is treated as accepted (the product
-- had no request flow before this migration).
update public.follows set status = 'accepted' where status is distinct from 'accepted';

-- Partial index so the target's "incoming pending requests" query stays fast
-- even after the follows table grows. Public reads still gated by RLS.
create index if not exists follows_pending_incoming_idx
  on public.follows (followee_id, created_at desc)
  where status = 'pending';


-- 2. toggle_follow ---------------------------------------------------
-- Creates pending when target is private, accepted otherwise.
-- Returns jsonb { following: bool, pending: bool } so the client
-- knows which of the two outbound states to render on the pill.

drop function if exists public.toggle_follow(uuid);

create or replace function public.toggle_follow(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  existing public.follows%rowtype;
  target_is_public boolean;
begin
  uid := auth.uid();
  if uid is null then raise exception 'auth required'; end if;
  if uid = p_user_id then raise exception 'cannot follow yourself'; end if;

  select * into existing from public.follows
   where follower_id = uid and followee_id = p_user_id;

  if found then
    -- Any existing row (pending or accepted) → tapping again undoes.
    delete from public.follows
     where follower_id = uid and followee_id = p_user_id;
    -- Clean up the related follow / follow_request notification(s) too.
    delete from public.notifications
     where actor_id = uid and user_id = p_user_id
       and type in ('follow', 'follow_request');
    return jsonb_build_object('following', false, 'pending', false);
  end if;

  select is_public into target_is_public from public.users where id = p_user_id;
  if target_is_public is null then
    raise exception 'target user not found';
  end if;

  if target_is_public then
    insert into public.follows (follower_id, followee_id, status)
    values (uid, p_user_id, 'accepted');
    return jsonb_build_object('following', true, 'pending', false);
  else
    insert into public.follows (follower_id, followee_id, status)
    values (uid, p_user_id, 'pending');
    return jsonb_build_object('following', false, 'pending', true);
  end if;
end;
$$;

grant execute on function public.toggle_follow(uuid) to authenticated;


-- 3. approve / reject follow request --------------------------------

create or replace function public.approve_follow_request(p_follower_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
begin
  uid := auth.uid();
  if uid is null then raise exception 'auth required'; end if;
  update public.follows
     set status = 'accepted'
   where follower_id = p_follower_id
     and followee_id = uid
     and status = 'pending';
  if not found then
    raise exception 'no pending request from that user';
  end if;
  -- The original notification inserted at pending time was a
  -- follow_request row for the target. Drop it so the target's
  -- inbox doesn't keep showing "pending" after they've decided.
  delete from public.notifications
   where actor_id = p_follower_id and user_id = uid
     and type = 'follow_request';
  -- The `notify_on_follow` trigger catches the accepted status
  -- transition and inserts a 'follow' notification for the target
  -- (so they see '{name} 開始追蹤你' after approving).
end;
$$;

grant execute on function public.approve_follow_request(uuid) to authenticated;


create or replace function public.reject_follow_request(p_follower_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
begin
  uid := auth.uid();
  if uid is null then raise exception 'auth required'; end if;
  delete from public.follows
   where follower_id = p_follower_id
     and followee_id = uid
     and status = 'pending';
  -- Also clear the follow_request notification on the target's
  -- inbox so it doesn't linger after the decision.
  delete from public.notifications
   where actor_id = p_follower_id and user_id = uid
     and type = 'follow_request';
end;
$$;

grant execute on function public.reject_follow_request(uuid) to authenticated;


-- 4. Notification type + trigger ------------------------------------

do $$ begin
  alter type public.notification_type add value if not exists 'follow_request';
exception when duplicate_object then null;
end $$;

-- Rewrite the follow-insert trigger to dispatch based on status,
-- and add an UPDATE trigger for pending→accepted that emits the
-- delayed 'follow' notification.

create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.follower_id = new.followee_id then return new; end if;
  if new.status = 'accepted' then
    insert into public.notifications (user_id, type, actor_id, target_id, target_kind)
    values (new.followee_id, 'follow', new.follower_id, new.follower_id, 'user');
  elsif new.status = 'pending' then
    insert into public.notifications (user_id, type, actor_id, target_id, target_kind)
    values (new.followee_id, 'follow_request', new.follower_id, new.follower_id, 'user');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_follow on public.follows;
create trigger trg_notify_on_follow
  after insert on public.follows
  for each row execute function public.notify_on_follow();


create or replace function public.notify_on_follow_accept()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'pending' and new.status = 'accepted' then
    insert into public.notifications (user_id, type, actor_id, target_id, target_kind)
    values (new.followee_id, 'follow', new.follower_id, new.follower_id, 'user');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_follow_accept on public.follows;
create trigger trg_notify_on_follow_accept
  after update on public.follows
  for each row execute function public.notify_on_follow_accept();


-- 5. user_relationship_stats ----------------------------------------
-- Only count accepted edges. Expose viewer_follow_status so the
-- client pill can render 追蹤 / 等待確認 / 追蹤中.

create or replace function public.user_relationship_stats(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  follower_count int;
  following_count int;
  is_following boolean := false;
  is_following_me boolean := false;
  viewer_status text := 'none';
begin
  select count(*) into follower_count from public.follows
   where followee_id = p_user_id and status = 'accepted';
  select count(*) into following_count from public.follows
   where follower_id = p_user_id and status = 'accepted';

  uid := auth.uid();
  if uid is not null and uid <> p_user_id then
    select status::text into viewer_status
      from public.follows
     where follower_id = uid and followee_id = p_user_id;
    if viewer_status is null then viewer_status := 'none'; end if;
    is_following := (viewer_status = 'accepted');
    select exists(select 1 from public.follows
                   where follower_id = p_user_id and followee_id = uid
                     and status = 'accepted')
      into is_following_me;
  end if;

  return jsonb_build_object(
    'follower_count', follower_count,
    'following_count', following_count,
    'is_following', is_following,
    'is_following_me', is_following_me,
    'viewer_follow_status', viewer_status  -- 'none' | 'pending' | 'accepted'
  );
end;
$$;

grant execute on function public.user_relationship_stats(uuid) to authenticated;


-- 6. user_public_profile --------------------------------------------
-- Always returns the profile shell (id, name, handle, avatar, bio)
-- plus flags so the client can gate the grids client-side.

create or replace function public.user_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u_row public.users%rowtype;
  approved_count int;
  visible_avatar text;
  viewer uuid;
  viewer_reported boolean := false;
  viewer_status text := 'none';
begin
  select * into u_row from public.users where id = p_user_id;
  if not found then return null; end if;

  visible_avatar := case
    when u_row.avatar_status = 'ok' then u_row.avatar_url
    else null
  end;

  select count(*) into approved_count
  from public.posters
  where uploader_id = p_user_id
    and status = 'approved'
    and deleted_at is null;

  viewer := auth.uid();
  if viewer is not null and viewer <> p_user_id then
    select exists (
      select 1 from public.avatar_reports
      where target_user_id = p_user_id and reporter_id = viewer
    ) into viewer_reported;
    select status::text into viewer_status
      from public.follows
     where follower_id = viewer and followee_id = p_user_id;
    if viewer_status is null then viewer_status := 'none'; end if;
  elsif viewer is not null and viewer = p_user_id then
    -- Own profile always reads as "self" — no follow concept.
    viewer_status := 'self';
  end if;

  return jsonb_build_object(
    'id', u_row.id,
    'display_name', u_row.display_name,
    'handle', u_row.handle,
    'avatar_url', visible_avatar,
    'bio', u_row.bio,
    'submission_count', u_row.submission_count,
    'approved_poster_count', approved_count,
    'is_public', u_row.is_public,
    'viewer_reported', viewer_reported,
    -- 'none' | 'pending' | 'accepted' | 'self'
    'viewer_follow_status', viewer_status
  );
end;
$$;


-- 7. follow_feed — only accepted follows ----------------------------
-- The follow_feed RPC joins `public.follows` where follower=viewer.
-- After this migration a follower_id=me row can be status='pending',
-- which we must NOT treat as a follow. Patch the RPC to filter.

create or replace function public.follow_feed(p_limit int default 20)
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
  if uid is null then return '[]'::jsonb; end if;

  select coalesce(jsonb_agg(row_to_json(a) order by a.action_at desc), '[]'::jsonb)
    into result
  from (
    select
      p.id, p.title, p.year, p.director, p.tags,
      p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
      p.view_count, p.favorite_count, p.created_at,
      f.created_at as action_at,
      f.user_id as actor_id,
      u.display_name as actor_name,
      u.avatar_url as actor_avatar,
      'favorite' as action_type
    from public.favorites f
    join public.follows fl
      on fl.followee_id = f.user_id and fl.follower_id = uid
      and fl.status = 'accepted'
    join public.users u
      on u.id = f.user_id and u.is_public = true
    join public.posters p
      on p.id = f.poster_id
      and p.status = 'approved'
      and p.deleted_at is null
    order by f.created_at desc
    limit p_limit
  ) a;

  return result;
end;
$$;

grant execute on function public.follow_feed(int) to authenticated;


-- 8. List pending requests (for the notification tab's action RPC) --

create or replace function public.list_pending_follow_requests()
returns table (
  follower_id uuid,
  follower_name text,
  follower_handle text,
  follower_avatar_url text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    f.follower_id,
    u.display_name,
    u.handle,
    case when u.avatar_status = 'ok' then u.avatar_url else null end,
    f.created_at
  from public.follows f
  join public.users u on u.id = f.follower_id
  where f.followee_id = auth.uid()
    and f.status = 'pending'
  order by f.created_at desc;
$$;

grant execute on function public.list_pending_follow_requests() to authenticated;

commit;
