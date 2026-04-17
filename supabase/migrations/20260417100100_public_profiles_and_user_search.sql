-- ═══════════════════════════════════════════════════════════════════════════
-- Public profiles + user search (EPIC 7)
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. RLS: allow reading any user with is_public = true.
-- 2. RPC: search_users() for display_name ILIKE with is_public filter.
-- 3. RPC: user_public_profile() with contribution stats.
-- 4. RPC: social_activity_feed() for "社群動態" home section.

begin;

-- ─── 1. Public read policy on users ─────────────────────────────────────────

drop policy if exists users_read_public on public.users;
create policy users_read_public on public.users
  for select using (is_public = true);

-- ─── 2. search_users(): find public users by display_name ──────────────────

create or replace function public.search_users(
  p_query text,
  p_limit int default 20
)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  bio text,
  submission_count int
)
language sql
security definer
set search_path = public
as $$
  select u.id, u.display_name, u.avatar_url, u.bio, u.submission_count
  from public.users u
  where u.is_public = true
    and u.display_name ilike '%' || p_query || '%'
  order by u.submission_count desc, u.display_name asc
  limit p_limit;
$$;

grant execute on function public.search_users(text, int) to authenticated;

-- ─── 3. user_public_profile(): profile + approved-poster count ─────────────

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
begin
  select * into u_row from public.users where id = p_user_id;
  if not found or u_row.is_public = false then
    return null;
  end if;

  select count(*) into approved_count
  from public.posters
  where uploader_id = p_user_id
    and status = 'approved'
    and deleted_at is null;

  result := jsonb_build_object(
    'id', u_row.id,
    'display_name', u_row.display_name,
    'avatar_url', u_row.avatar_url,
    'bio', u_row.bio,
    'submission_count', u_row.submission_count,
    'approved_poster_count', approved_count,
    'is_public', u_row.is_public
  );
  return result;
end;
$$;

grant execute on function public.user_public_profile(uuid) to authenticated;

-- ─── 4. social_activity_feed(): recent approved posters from public users ──

create or replace function public.social_activity_feed(p_limit int default 12)
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

grant execute on function public.social_activity_feed(int) to authenticated;

commit;
