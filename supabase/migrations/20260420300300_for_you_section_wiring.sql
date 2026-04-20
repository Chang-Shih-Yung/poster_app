-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 15-2 + 15-3: wire 為你推薦 into home_sections_v2 + config row
-- ═══════════════════════════════════════════════════════════════════════════
-- Two new source_types in the dispatcher:
--   for_you         → for_you_feed_v1 (real-time tag affinity, default)
--   for_you_cf      → for_you_feed_cf (pre-computed CF, opt-in)
--
-- We seed the config with for_you (v1) which has v1's own internal
-- fallbacks. Later, swap source_type='for_you_cf' on this row to switch
-- to CF — no Dart change.

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
  if uid is not null then
    select exists(select 1 from public.follows where follower_id = uid)
      into has_follows;
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
    if r.visibility = 'signed_in' and uid is null then continue; end if;
    if r.visibility = 'has_follows' and (uid is null or not has_follows) then
      continue;
    end if;

    section_items := '[]'::jsonb;

    if r.source_type = 'popular' then
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
        coalesce((r.source_params->>'limit')::int, 10));

    elsif r.source_type = 'active_collectors' then
      section_items := public.active_collectors(
        coalesce((r.source_params->>'days')::int, 7),
        coalesce((r.source_params->>'limit')::int, 12));

    elsif r.source_type = 'follow_feed' then
      section_items := public.follow_feed(
        coalesce((r.source_params->>'limit')::int, 20));

    elsif r.source_type = 'recent_approved' then
      section_items := public.recent_approved_feed(
        coalesce((r.source_params->>'limit')::int, 12));

    elsif r.source_type = 'for_you' then
      section_items := public.for_you_feed_v1(
        coalesce((r.source_params->>'limit')::int, 12));

    elsif r.source_type = 'for_you_cf' then
      section_items := public.for_you_feed_cf(
        coalesce((r.source_params->>'limit')::int, 12));

    elsif r.source_type = 'tag_slug' then
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

-- ─── Add 為你推薦 section to config ──────────────────────────────────────
-- Position 15 puts it between 熱門 (10) and 追蹤動態 (20).
-- Visibility 'signed_in' — the for_you RPC needs auth.uid() to compute
-- affinity. Anonymous users see one fewer section instead of a useless
-- duplicated trending row.

insert into public.home_sections_config
  (slug, title_zh, title_en, icon, source_type, source_params, position, visibility)
values
  ('for_you', '為你推薦', 'For You', 'sparkles',
   'for_you', '{"limit": 12}'::jsonb, 15, 'signed_in')
on conflict (slug) do nothing;

commit;
