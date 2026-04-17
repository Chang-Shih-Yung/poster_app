-- ═══════════════════════════════════════════════════════════════════════════
-- Search upgrade: pg_trgm + GIN indexes + unified search RPC (EPIC 9)
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Enable pg_trgm.
-- 2. Add GIN indexes for fuzzy ILIKE on works and posters.
-- 3. unified_search() RPC: search works, posters, users in 1 round-trip.

begin;

create extension if not exists pg_trgm;

-- ─── 2. Indexes ─────────────────────────────────────────────────────────────

create index if not exists idx_works_title_zh_trgm
  on public.works using gin (title_zh gin_trgm_ops);

create index if not exists idx_works_title_en_trgm
  on public.works using gin (title_en gin_trgm_ops);

create index if not exists idx_posters_title_trgm
  on public.posters using gin (title gin_trgm_ops);

create index if not exists idx_posters_poster_name_trgm
  on public.posters using gin (poster_name gin_trgm_ops);

create index if not exists idx_posters_channel_name_trgm
  on public.posters using gin (channel_name gin_trgm_ops);

create index if not exists idx_users_display_name_trgm
  on public.users using gin (display_name gin_trgm_ops);

-- ─── 3. unified_search() RPC ────────────────────────────────────────────────

create or replace function public.unified_search(
  p_query text,
  p_limit int default 8
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q text;
  works_json jsonb;
  posters_json jsonb;
  users_json jsonb;
begin
  q := trim(p_query);
  if q = '' then
    return jsonb_build_object('works', '[]'::jsonb, 'posters', '[]'::jsonb, 'users', '[]'::jsonb);
  end if;

  -- Works: match title_zh OR title_en, rank by poster_count desc.
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into works_json
  from (
    select id, title_zh, title_en, movie_release_year, poster_count
    from public.works
    where title_zh ilike '%' || q || '%'
       or title_en ilike '%' || q || '%'
    order by poster_count desc, title_zh
    limit p_limit
  ) t;

  -- Posters: match title, poster_name, channel_name. Only approved.
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into posters_json
  from (
    select id, title, year, director, tags,
           poster_url, thumbnail_url, uploader_id, status,
           view_count, favorite_count, created_at,
           work_id, poster_name, region, channel_name
    from public.posters
    where status = 'approved'
      and deleted_at is null
      and (
        title ilike '%' || q || '%'
        or poster_name ilike '%' || q || '%'
        or channel_name ilike '%' || q || '%'
      )
    order by favorite_count desc nulls last, view_count desc nulls last
    limit p_limit
  ) t;

  -- Users: public profiles only, match display_name.
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into users_json
  from (
    select id, display_name, avatar_url, bio, submission_count
    from public.users
    where is_public = true
      and display_name ilike '%' || q || '%'
    order by submission_count desc
    limit p_limit
  ) t;

  return jsonb_build_object(
    'works', works_json,
    'posters', posters_json,
    'users', users_json
  );
end;
$$;

grant execute on function public.unified_search(text, int) to authenticated;

commit;
