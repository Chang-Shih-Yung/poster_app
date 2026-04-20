-- ═══════════════════════════════════════════════════════════════════════════
-- 手動觸發 CF 批次 + 切換首頁「為你推薦」section 到 for_you_cf
-- ═══════════════════════════════════════════════════════════════════════════
-- 用途：admin 想立刻測試 CF 路徑，不等明早 03:00 排程。
--
-- 注意：當前資料量很小（active users 寡、favorites overlap 少），
-- compute_collaborative_recommendations() 算完 user_recommendations
-- 表可能仍是空的。這時 for_you_feed_cf RPC 會自動 fall back 到 v1
-- (tag affinity)，使用者看不到差異——但 CF pipeline 已 live，等資料夠
-- 自然生效。

begin;

-- 1. 立刻手動跑一次批次
select public.compute_collaborative_recommendations();

-- 2. 切換首頁 section 走 CF 路徑
update public.home_sections_config
set source_type = 'for_you_cf',
    updated_at = now()
where slug = 'for_you';

-- 3. 印出 CF 結果規模供 admin 觀察
do $$
declare
  total_recs int;
  user_count int;
  job_info record;
begin
  select count(*) into total_recs
    from public.user_recommendations
    where job_slug = 'cf_nightly';
  select count(distinct user_id) into user_count
    from public.user_recommendations
    where job_slug = 'cf_nightly';
  select last_run_at, last_user_count, last_row_count, last_duration_ms
    into job_info
    from public.recommendation_jobs
    where slug = 'cf_nightly';

  raise notice 'CF batch finished: % recs across % users, took % ms',
    total_recs, user_count, job_info.last_duration_ms;
  if total_recs = 0 then
    raise notice 'CF result empty — likely no users with ≥5 favorites + ≥3 overlap yet. for_you_feed_cf will internal-fallback to v1.';
  end if;
end $$;

commit;
