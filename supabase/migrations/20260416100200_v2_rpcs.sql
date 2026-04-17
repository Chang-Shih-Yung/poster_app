-- V2 RPCs: 7 functions
-- Review decisions: transaction wrapping (#3), ON CONFLICT + lock (#4),
-- home_sections (#10), list_favorites_with_posters (#11), top_tags (#8)
begin;

-- ─── 1. increment_view_with_dedup ────────────────────────────────────────────
-- Replaces old increment_poster_view_count.
-- Composite PK (user_id, poster_id, viewed_date) deduplicates per day.

create or replace function public.increment_view_with_dedup(p_poster_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted boolean;
begin
  insert into public.poster_views (user_id, poster_id, viewed_date)
  values (auth.uid(), p_poster_id, current_date)
  on conflict do nothing;

  get diagnostics inserted = row_count;

  if inserted then
    update public.posters
       set view_count = view_count + 1
     where id = p_poster_id
       and status = 'approved'
       and deleted_at is null;
  end if;
end;
$$;

-- ─── 2. toggle_favorite (review #4: ON CONFLICT + row lock) ─────────────────

create or replace function public.toggle_favorite(p_poster_id uuid)
returns boolean  -- true = now favorited, false = unfavorited
language plpgsql
security definer
set search_path = public
as $$
declare
  was_fav boolean;
begin
  -- Lock the poster row to prevent race conditions
  perform id from public.posters where id = p_poster_id for update;

  select exists (
    select 1 from public.favorites
    where user_id = auth.uid() and poster_id = p_poster_id
  ) into was_fav;

  if was_fav then
    delete from public.favorites
    where user_id = auth.uid() and poster_id = p_poster_id;

    update public.posters
       set favorite_count = greatest(favorite_count - 1, 0)
     where id = p_poster_id;

    return false;
  else
    insert into public.favorites (user_id, poster_id, created_at)
    values (auth.uid(), p_poster_id, now())
    on conflict do nothing;

    update public.posters
       set favorite_count = favorite_count + 1
     where id = p_poster_id;

    return true;
  end if;
end;
$$;

-- ─── 3. approve_submission (review #3: transaction wrapping) ─────────────────

create or replace function public.approve_submission(
  p_submission_id uuid,
  p_work_id uuid default null
)
returns uuid  -- returns new poster ID
language plpgsql
security definer
set search_path = public
as $$
declare
  sub record;
  v_work_id uuid;
  v_poster_id uuid;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  -- Fetch submission
  select * into sub from public.submissions where id = p_submission_id;
  if sub is null then
    raise exception 'submission not found';
  end if;
  if sub.status != 'pending' then
    raise exception 'submission already reviewed';
  end if;

  -- Resolve or create work
  if p_work_id is not null then
    v_work_id := p_work_id;
  else
    insert into public.works (title_zh, title_en, movie_release_year)
    values (sub.work_title_zh, sub.work_title_en, sub.movie_release_year)
    returning id into v_work_id;
  end if;

  -- Create poster from submission (INSERT...SELECT pattern, review #1)
  insert into public.posters (
    work_id, title, poster_name, region, year,
    poster_release_date, poster_release_type, size_type,
    channel_category, channel_type, channel_name,
    is_exclusive, exclusive_name, material_type, version_label,
    poster_url, thumbnail_url, image_size_bytes,
    source_url, source_platform, source_note,
    uploader_id, status, reviewer_id, reviewed_at, approved_at, tags
  ) values (
    v_work_id, sub.work_title_zh, sub.poster_name, sub.region, sub.movie_release_year,
    sub.poster_release_date, sub.poster_release_type, sub.size_type,
    sub.channel_category, sub.channel_type, sub.channel_name,
    sub.is_exclusive, sub.exclusive_name, sub.material_type, sub.version_label,
    sub.image_url, sub.thumbnail_url, sub.image_size_bytes,
    sub.source_url, sub.source_platform, sub.source_note,
    sub.uploader_id, 'approved', auth.uid(), now(), now(), '{}'
  )
  returning id into v_poster_id;

  -- Update work poster_count
  update public.works
     set poster_count = poster_count + 1,
         updated_at = now()
   where id = v_work_id;

  -- Mark submission approved
  update public.submissions
     set status = 'approved',
         reviewer_id = auth.uid(),
         reviewed_at = now(),
         matched_work_id = v_work_id,
         created_poster_id = v_poster_id
   where id = p_submission_id;

  -- Audit log
  insert into public.audit_logs (actor_id, action, target_table, target_id, after)
  values (
    auth.uid(), 'approve_submission', 'submissions', p_submission_id,
    jsonb_build_object(
      'work_id', v_work_id,
      'poster_id', v_poster_id,
      'title', sub.work_title_zh
    )
  );

  return v_poster_id;
end;
$$;

-- ─── 4. reject_submission ───────────────────────────────────────────────────

create or replace function public.reject_submission(
  p_submission_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  update public.submissions
     set status = 'rejected',
         reviewer_id = auth.uid(),
         review_note = p_note,
         reviewed_at = now()
   where id = p_submission_id
     and status = 'pending';

  insert into public.audit_logs (actor_id, action, target_table, target_id, after)
  values (
    auth.uid(), 'reject_submission', 'submissions', p_submission_id,
    jsonb_build_object('note', p_note)
  );
end;
$$;

-- ─── 5. home_sections (review #10: merge 8 queries into 1) ─────────────────

create or replace function public.home_sections(p_limit int default 10)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb := '[]'::jsonb;
  section_row jsonb;
  cutoff timestamptz;
begin
  cutoff := now() - interval '30 days';

  -- Popular (last 30 days by view_count)
  select jsonb_build_object('key', 'popular', 'items', coalesce(jsonb_agg(row_to_json(t)), '[]'))
  into section_row
  from (
    select id, title, year, director, tags, poster_url, thumbnail_url,
           view_count, favorite_count, created_at
    from public.posters
    where status = 'approved' and deleted_at is null and created_at >= cutoff
    order by view_count desc
    limit p_limit
  ) t;
  result := result || section_row;

  -- Latest
  select jsonb_build_object('key', 'latest', 'items', coalesce(jsonb_agg(row_to_json(t)), '[]'))
  into section_row
  from (
    select id, title, year, director, tags, poster_url, thumbnail_url,
           view_count, favorite_count, created_at
    from public.posters
    where status = 'approved' and deleted_at is null
    order by created_at desc
    limit p_limit
  ) t;
  result := result || section_row;

  -- Tag-based sections
  for section_row in
    select jsonb_build_object('key', tag, 'items', coalesce(jsonb_agg(row_to_json(t)), '[]'))
    from unnest(array['收藏必備','經典','日本','台灣','手繪','大師']) as tag
    cross join lateral (
      select id, title, year, director, tags, poster_url, thumbnail_url,
             view_count, favorite_count, created_at
      from public.posters
      where status = 'approved' and deleted_at is null and tags @> array[tag]
      order by created_at desc
      limit p_limit
    ) t
    group by tag
  loop
    result := result || section_row;
  end loop;

  return result;
end;
$$;

-- ─── 6. list_favorites_with_posters (review #11: replace IN clause) ─────────

create or replace function public.list_favorites_with_posters(
  p_user_id uuid,
  p_offset int default 0,
  p_limit int default 20
)
returns setof public.posters
language sql
security definer
set search_path = public
stable
as $$
  select p.*
  from public.favorites f
  join public.posters p on p.id = f.poster_id
  where f.user_id = p_user_id
    and p.status = 'approved'
    and p.deleted_at is null
  order by f.created_at desc
  limit p_limit offset p_offset;
$$;

-- ─── 7. top_tags (review #8: replace client-side 500-row fetch) ─────────────

create or replace function public.top_tags(p_limit int default 20)
returns table(tag text, cnt bigint)
language sql
security definer
set search_path = public
stable
as $$
  select t.tag, count(*) as cnt
  from public.posters, unnest(tags) as t(tag)
  where status = 'approved' and deleted_at is null
  group by t.tag
  order by cnt desc
  limit p_limit;
$$;

-- ─── GRANTs ─────────────────────────────────────────────────────────────────

grant execute on function public.increment_view_with_dedup(uuid) to authenticated;
grant execute on function public.toggle_favorite(uuid) to authenticated;
grant execute on function public.approve_submission(uuid, uuid) to authenticated;
grant execute on function public.reject_submission(uuid, text) to authenticated;
grant execute on function public.home_sections(int) to anon, authenticated;
grant execute on function public.list_favorites_with_posters(uuid, int, int) to authenticated;
grant execute on function public.top_tags(int) to anon, authenticated;

commit;
