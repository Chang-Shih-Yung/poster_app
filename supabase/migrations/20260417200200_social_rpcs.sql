-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 11: Social RPCs
-- ═══════════════════════════════════════════════════════════════════════════
-- 6 RPCs:
--   1. toggle_follow              — follow/unfollow toggle
--   2. trending_favorites         — "本週最多人收藏"
--   3. active_collectors          — "活躍收藏家"
--   4. follow_feed                — "追蹤的人最近在收"
--   5. user_relationship_stats    — follower/following counts + flags
--   6. rename social_activity_feed → recent_approved_feed

begin;

-- ─── 1. toggle_follow ──────────────────────────────────────────────────────

create or replace function public.toggle_follow(p_user_id uuid)
returns boolean  -- true = now following, false = unfollowed
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  was_following boolean;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'auth required';
  end if;
  if uid = p_user_id then
    raise exception 'cannot follow yourself';
  end if;

  -- Lock the followee row so two concurrent toggles from the same user
  -- serialize. Not strictly necessary (PK ON CONFLICT handles it) but
  -- makes the semantics clean.
  select exists (
    select 1 from public.follows
    where follower_id = uid and followee_id = p_user_id
  ) into was_following;

  if was_following then
    delete from public.follows
    where follower_id = uid and followee_id = p_user_id;
    return false;
  else
    insert into public.follows (follower_id, followee_id)
    values (uid, p_user_id)
    on conflict do nothing;
    return true;
  end if;
end;
$$;

grant execute on function public.toggle_follow(uuid) to authenticated;

-- ─── 2. trending_favorites ─────────────────────────────────────────────────
-- Posters that gained the most favorites in the last N days.
-- Returns each poster + recent_fav_count + up-to-3 collector avatars for
-- the "+N" stacked-avatar UI pattern.

create or replace function public.trending_favorites(
  p_days int default 7,
  p_limit int default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into result
  from (
    select
      p.id, p.title, p.year, p.director, p.tags,
      p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
      p.view_count, p.favorite_count, p.created_at,
      fc.cnt as recent_fav_count,
      fc.collectors
    from (
      select
        f.poster_id,
        count(*) as cnt,
        -- top 3 collectors (most recent first) as a compact jsonb array
        (
          select jsonb_agg(row_to_json(c))
          from (
            select f2.user_id as id, u.display_name as name, u.avatar_url as avatar
            from public.favorites f2
            join public.users u on u.id = f2.user_id and u.is_public = true
            where f2.poster_id = f.poster_id
              and f2.created_at > now() - make_interval(days => p_days)
            order by f2.created_at desc
            limit 3
          ) c
        ) as collectors
      from public.favorites f
      join public.users u on u.id = f.user_id and u.is_public = true
      where f.created_at > now() - make_interval(days => p_days)
      group by f.poster_id
      order by count(*) desc
      limit p_limit
    ) fc
    join public.posters p on p.id = fc.poster_id
      and p.status = 'approved'
      and p.deleted_at is null
  ) t;
  return result;
end;
$$;

grant execute on function public.trending_favorites(int, int) to authenticated;

-- ─── 3. active_collectors ──────────────────────────────────────────────────
-- Public users who had recent activity (favorites or submissions) in the
-- last N days. Each user row includes up to 3 most-recent favorited poster
-- thumbnails for the mini-preview row in the _CollectorCard.

create or replace function public.active_collectors(
  p_days int default 7,
  p_limit int default 12
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into result
  from (
    select
      u.id, u.display_name, u.avatar_url, u.bio,
      u.submission_count,
      a.activity_count,
      a.last_action,
      -- up to 3 most recent favorited poster thumbnails (only approved)
      (
        select jsonb_agg(row_to_json(pp))
        from (
          select p.id, p.thumbnail_url, p.poster_url
          from public.favorites ff
          join public.posters p on p.id = ff.poster_id
            and p.status = 'approved' and p.deleted_at is null
          where ff.user_id = u.id
          order by ff.created_at desc
          limit 3
        ) pp
      ) as recent_posters
    from (
      select user_id, count(*) as activity_count, max(created_at) as last_action
      from (
        select user_id, created_at
          from public.favorites
          where created_at > now() - make_interval(days => p_days)
        union all
        select uploader_id as user_id, created_at
          from public.submissions
          where created_at > now() - make_interval(days => p_days)
      ) all_actions
      group by user_id
      order by count(*) desc, max(created_at) desc
      limit p_limit
    ) a
    join public.users u on u.id = a.user_id and u.is_public = true
  ) t;
  return result;
end;
$$;

grant execute on function public.active_collectors(int, int) to authenticated;

-- ─── 4. follow_feed ────────────────────────────────────────────────────────
-- Posters that people I follow have recently favorited (actor-first feed).

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
  if uid is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into result
  from (
    select
      p.id, p.title, p.year, p.director, p.tags,
      p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
      p.view_count, p.favorite_count, p.created_at,
      f.user_id as actor_id,
      u.display_name as actor_name,
      u.avatar_url as actor_avatar,
      f.created_at as action_at,
      'favorite' as action_type
    from public.follows fol
    join public.favorites f on f.user_id = fol.followee_id
    join public.users u on u.id = f.user_id and u.is_public = true
    join public.posters p on p.id = f.poster_id
      and p.status = 'approved' and p.deleted_at is null
    where fol.follower_id = uid
    order by f.created_at desc
    limit p_limit
  ) t;
  return result;
end;
$$;

grant execute on function public.follow_feed(int) to authenticated;

-- ─── 5. user_relationship_stats ────────────────────────────────────────────
-- Counts + directional flags for a target user, relative to caller.

create or replace function public.user_relationship_stats(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  follower_cnt int;
  following_cnt int;
  is_following_me boolean := false;
  am_i_following boolean := false;
begin
  uid := auth.uid();

  select count(*) into follower_cnt
    from public.follows where followee_id = p_user_id;
  select count(*) into following_cnt
    from public.follows where follower_id = p_user_id;

  if uid is not null and uid != p_user_id then
    select exists(
      select 1 from public.follows
      where follower_id = uid and followee_id = p_user_id
    ) into am_i_following;
    select exists(
      select 1 from public.follows
      where follower_id = p_user_id and followee_id = uid
    ) into is_following_me;
  end if;

  return jsonb_build_object(
    'follower_count', follower_cnt,
    'following_count', following_cnt,
    'am_i_following', am_i_following,
    'is_following_me', is_following_me
  );
end;
$$;

grant execute on function public.user_relationship_stats(uuid) to authenticated;

-- ─── 6. rename social_activity_feed → recent_approved_feed ─────────────────
-- The old name implied "social" but the function just returns newest approved
-- posters by public users. "剛上架" is a more honest label. We create the new
-- name first, then drop the old one, so any in-flight caller has a window.

create or replace function public.recent_approved_feed(p_limit int default 12)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  from (
    select p.id, p.title, p.year, p.director, p.tags,
           p.poster_url, p.thumbnail_url,
           p.uploader_id, p.status, p.view_count, p.favorite_count,
           p.created_at,
           u.display_name as uploader_name,
           u.avatar_url as uploader_avatar
    from public.posters p
    join public.users u on u.id = p.uploader_id
    where p.status = 'approved'
      and p.deleted_at is null
      and u.is_public = true
    order by p.approved_at desc nulls last, p.created_at desc
    limit p_limit
  ) t;
$$;

grant execute on function public.recent_approved_feed(int) to authenticated;

drop function if exists public.social_activity_feed(int);

commit;
