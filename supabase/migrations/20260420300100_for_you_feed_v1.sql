-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 15-1: for_you_feed_v1 — real-time tag-affinity recommendations
-- ═══════════════════════════════════════════════════════════════════════════
-- Cheap personalisation, no batch infra, no ML:
--   1. Compute caller's top-N tags by favorite count
--   2. Score un-favorited posters by sum of their matching-tag affinities
--   3. Cold start (< 3 favorites) → fall back to trending_favorites
--   4. Not signed in → also fall back to trending_favorites
--
-- Always returns jsonb array of poster rows (matches the shape other
-- home sources return, so home_sections_v2 dispatcher can plug it in
-- with sourceType='for_you' alongside popular / tag_slug etc.)
--
-- Performance: with poster_tags indexed on tag_id and ~10k posters, this
-- runs sub-100ms. When it doesn't, EPIC 15-7 (collaborative filter,
-- pre-computed) takes over.

begin;

create or replace function public.for_you_feed_v1(p_limit int default 12)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  fav_count int;
  result jsonb;
begin
  uid := auth.uid();

  -- Not signed in: pure trending fallback
  if uid is null then
    return public.trending_favorites(7, p_limit);
  end if;

  -- Cold start: fewer than 3 favorites = no signal yet → trending
  select count(*) into fav_count
  from public.favorites
  where user_id = uid;

  if fav_count < 3 then
    return public.trending_favorites(7, p_limit);
  end if;

  -- Tag affinity: weight tags by how often they appear in my favorites,
  -- score candidate posters by sum of affinities, exclude already-fav.
  with my_tags as (
    select pt.tag_id, count(*) as affinity
    from public.favorites f
    join public.poster_tags pt on pt.poster_id = f.poster_id
    where f.user_id = uid
    group by pt.tag_id
    order by count(*) desc
    limit 5
  ),
  my_favs as (
    select poster_id from public.favorites where user_id = uid
  ),
  candidates as (
    select pt.poster_id, sum(mt.affinity)::int as score
    from public.poster_tags pt
    join my_tags mt on mt.tag_id = pt.tag_id
    where pt.poster_id not in (select poster_id from my_favs)
    group by pt.poster_id
  )
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into result
  from (
    select p.id, p.title, p.year, p.director, p.tags,
           p.poster_url, p.thumbnail_url, p.uploader_id, p.status,
           p.view_count, p.favorite_count, p.created_at,
           c.score as recommendation_score
    from candidates c
    join public.posters p on p.id = c.poster_id
      and p.status = 'approved'
      and p.deleted_at is null
    order by c.score desc, p.favorite_count desc nulls last
    limit p_limit
  ) t;

  -- If user's tags happen to have no overlap with other posters, fall
  -- back to trending so the section never looks empty.
  if jsonb_array_length(result) = 0 then
    return public.trending_favorites(7, p_limit);
  end if;

  return result;
end $$;

grant execute on function public.for_you_feed_v1(int) to authenticated;

commit;
