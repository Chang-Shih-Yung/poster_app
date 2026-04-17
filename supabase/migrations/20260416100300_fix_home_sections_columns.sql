-- Fix: home_sections RPC was missing uploader_id and status columns,
-- causing Poster.fromRow() to throw "Null is not a subtype of String".

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
           uploader_id, status, view_count, favorite_count, created_at
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
           uploader_id, status, view_count, favorite_count, created_at
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
             uploader_id, status, view_count, favorite_count, created_at
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
