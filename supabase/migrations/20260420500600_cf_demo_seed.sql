-- ═══════════════════════════════════════════════════════════════════════════
-- CF demo: give 張十墉 3 more favorites that BIU hasn't collected,
-- so the collaborative filter has something novel to recommend to BIU.
-- ═══════════════════════════════════════════════════════════════════════════
-- 張十墉 currently has 4 favorites, all overlapping with BIU's 8.
-- After this migration: 張十墉 has 7 — 4 overlap + 3 new. CF will then
-- recommend those 3 "new-to-BIU" posters (花樣年華 / 你的名字 / 龍貓)
-- with weight = overlap (4).
--
-- These happen to match BIU's top tags (愛情/動畫/經典) so the result
-- will feel real, not random.

begin;

do $$
declare
  admin_uid uuid := 'a1cb9f23-6423-4735-83ea-d10d29693a88'; -- 張十墉
  r record;
  added_count int := 0;
begin
  -- Add favorites for approved posters with these titles, if admin hasn't already
  for r in
    select p.id, p.title
    from public.posters p
    where p.status = 'approved'
      and p.deleted_at is null
      and p.title in ('花樣年華', '你的名字', '龍貓')
      and not exists (
        select 1 from public.favorites f
        where f.user_id = admin_uid and f.poster_id = p.id
      )
  loop
    insert into public.favorites (user_id, poster_id, created_at)
    values (admin_uid, r.id, now())
    on conflict do nothing;

    -- Also bump poster favorite_count (mirrors toggle_favorite behaviour)
    update public.posters
    set favorite_count = favorite_count + 1
    where id = r.id;

    added_count := added_count + 1;
    raise notice 'Added favorite for admin: %', r.title;
  end loop;

  raise notice '=== CF demo seed: added % favorites for 張十墉 ===', added_count;
end $$;

-- 重跑 CF 批次
select public.compute_collaborative_recommendations();

-- 確認切到 CF 路徑
update public.home_sections_config
set source_type = 'for_you_cf', updated_at = now()
where slug = 'for_you';

-- 列印 BIU 的 CF 推薦結果
do $$
declare
  r record;
  biu_uid uuid := '964d16f7-f449-4b8c-a69b-bc462cb43629';
begin
  raise notice '=== CF recommendations for BIU (post-seed) ===';
  for r in
    select p.title, ur.score, ur.reason
    from public.user_recommendations ur
    join public.posters p on p.id = ur.poster_id
    where ur.user_id = biu_uid and ur.job_slug = 'cf_nightly'
    order by ur.score desc
  loop
    raise notice 'CF REC: score=% [%] %', r.score, r.reason, r.title;
  end loop;
end $$;

commit;
