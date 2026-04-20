-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 14-2: home_sections_v2() — config-driven section dispatcher
-- ═══════════════════════════════════════════════════════════════════════════
-- Client calls this ONCE per home page load. Returns an ordered JSON array:
--   [{config: {slug, title_zh, title_en, icon, source_type}, items: [...]}, ...]
--
-- For each enabled config row (ordered by position), fetch the backing
-- data by source_type. Sections where caller has no data (e.g. follow_feed
-- for a user with 0 follows) return items=[] — client can filter/hide.
--
-- Visibility filtering is done server-side:
--   - always       → always include
--   - signed_in    → include only if auth.uid() is not null
--   - has_follows  → include only if caller follows ≥ 1 user
--
-- Payload is shaped so Dart side can dispatch by source_type when rendering
-- (different card layouts: _FeedCard / _TrendingCard / _CollectorCard).

begin;

create or replace function public.home_sections_v2()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  has_follows boolean;
  r record;
  result jsonb := '[]'::jsonb;
  section_items jsonb;
  section_entry jsonb;
begin
  uid := auth.uid();

  -- Precompute visibility context
  if uid is not null then
    select exists(
      select 1 from public.follows where follower_id = uid
    ) into has_follows;
  else
    has_follows := false;
  end if;

  for r in
    select slug, title_zh, title_en, icon, source_type, source_params,
           visibility, position
    from public.home_sections_config
    where enabled = true
    order by position asc, slug asc
  loop
    -- Visibility gate
    if r.visibility = 'signed_in' and uid is null then continue; end if;
    if r.visibility = 'has_follows' and (uid is null or not has_follows) then
      continue;
    end if;

    -- Dispatch by source_type
    section_items := '[]'::jsonb;

    if r.source_type = 'popular' then
      -- Last N days by view_count, approved only
      select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into section_items
      from (
        select p.id, p.title, p.year, p.director, p.tags,
               p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
               p.view_count, p.favorite_count, p.created_at
        from public.posters p
        where p.status = 'approved'
          and p.deleted_at is null
          and p.created_at >= now() -
              (coalesce((r.source_params->>'days')::int, 30) || ' days')::interval
        order by p.view_count desc
        limit coalesce((r.source_params->>'limit')::int, 10)
      ) t;

    elsif r.source_type = 'trending_favorites' then
      section_items := public.trending_favorites(
        coalesce((r.source_params->>'days')::int, 7),
        coalesce((r.source_params->>'limit')::int, 10)
      );

    elsif r.source_type = 'active_collectors' then
      section_items := public.active_collectors(
        coalesce((r.source_params->>'days')::int, 7),
        coalesce((r.source_params->>'limit')::int, 12)
      );

    elsif r.source_type = 'follow_feed' then
      section_items := public.follow_feed(
        coalesce((r.source_params->>'limit')::int, 20)
      );

    elsif r.source_type = 'recent_approved' then
      section_items := public.recent_approved_feed(
        coalesce((r.source_params->>'limit')::int, 12)
      );

    elsif r.source_type = 'tag_slug' then
      -- Posters tagged with a specific canonical tag slug
      declare
        v_tag_slug text := r.source_params->>'tag';
        v_limit int := coalesce((r.source_params->>'limit')::int, 10);
      begin
        if v_tag_slug is null then
          section_items := '[]'::jsonb;
        else
          select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into section_items
          from (
            select p.id, p.title, p.year, p.director, p.tags,
                   p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
                   p.view_count, p.favorite_count, p.created_at
            from public.poster_tags pt
            join public.tags tg on tg.id = pt.tag_id and tg.slug = v_tag_slug
            join public.posters p on p.id = pt.poster_id
              and p.status = 'approved' and p.deleted_at is null
            order by p.favorite_count desc nulls last, p.view_count desc nulls last, p.created_at desc
            limit v_limit
          ) t;
        end if;
      end;

    else
      -- Unknown source_type → skip
      continue;
    end if;

    section_entry := jsonb_build_object(
      'slug', r.slug,
      'title_zh', r.title_zh,
      'title_en', r.title_en,
      'icon', r.icon,
      'source_type', r.source_type,
      'source_params', r.source_params,
      'items', section_items
    );
    result := result || jsonb_build_array(section_entry);
  end loop;

  return result;
end $$;

grant execute on function public.home_sections_v2() to authenticated;

-- Drop the old home_sections() (single-RPC editorial)
-- We keep the old name as an alias for backwards compat until Dart migrates.
-- Actually simpler: rename carefully. Keep old one but mark deprecated.
-- For now, DO NOT DROP — Dart code still uses it in some places during
-- transition. EPIC 14-4 will re-wire and then we can drop.

commit;
