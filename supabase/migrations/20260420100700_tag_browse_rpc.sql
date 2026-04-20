-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18-13: browse posters by tag slug
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.browse_posters_by_tag(
  p_tag_slug text,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tag record;
  posters_json jsonb;
begin
  select id, slug, label_zh, label_en, category_id, poster_count
    into v_tag from public.tags
    where slug = p_tag_slug and deprecated = false;

  if not found then
    return jsonb_build_object('tag', null, 'posters', '[]'::jsonb);
  end if;

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into posters_json
  from (
    select p.id, p.title, p.year, p.director, p.tags,
           p.poster_url, p.thumbnail_url,
           p.uploader_id, p.status, p.view_count, p.favorite_count,
           p.created_at, p.work_id, p.work_kind, p.poster_name,
           u.display_name as uploader_name,
           u.avatar_url as uploader_avatar
    from public.poster_tags pt
    join public.posters p on p.id = pt.poster_id
      and p.status = 'approved' and p.deleted_at is null
    join public.users u on u.id = p.uploader_id
    where pt.tag_id = v_tag.id
    order by p.favorite_count desc nulls last, p.view_count desc nulls last, p.created_at desc
    limit p_limit offset p_offset
  ) t;

  return jsonb_build_object(
    'tag', row_to_json(v_tag),
    'posters', posters_json
  );
end $$;

grant execute on function public.browse_posters_by_tag(text, int, int) to authenticated;

commit;
