-- ═══════════════════════════════════════════════════════════════════════════
-- V2 Data Backfill + Old RPC Cleanup
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. Backfill: Create works from existing approved posters (title+year groups)
-- 2. Backfill: Set work_id on existing posters
-- 3. Backfill: Move pending posters → submissions table
-- 4. Drop old RPC: increment_poster_view_count

begin;

-- ─── 1. Create works from distinct (title, year) of approved posters ────────

insert into public.works (title_zh, movie_release_year, poster_count, created_at, updated_at)
select
  p.title,
  p.year,
  count(*),
  min(p.created_at),
  now()
from public.posters p
where p.status = 'approved'
  and p.deleted_at is null
  and p.work_id is null
group by p.title, p.year
on conflict do nothing;

-- ─── 2. Set work_id on posters that don't have one ─────────────────────────

update public.posters p
set work_id = w.id
from public.works w
where p.work_id is null
  and p.status = 'approved'
  and p.deleted_at is null
  and w.title_zh = p.title
  and (
    (w.movie_release_year is null and p.year is null)
    or w.movie_release_year = p.year
  );

-- ─── 3. Move pending posters → submissions ─────────────────────────────────
-- Only move rows that haven't already been migrated.

insert into public.submissions (
  work_title_zh, movie_release_year,
  image_url, thumbnail_url,
  uploader_id, status, created_at,
  region
)
select
  p.title,
  p.year,
  p.poster_url,
  p.thumbnail_url,
  p.uploader_id,
  (case p.status
    when 'rejected' then 'rejected'
    else 'pending'
  end)::submission_status,
  p.created_at,
  'TW'::region_enum
from public.posters p
where p.status in ('pending', 'rejected')
  and p.deleted_at is null
  and not exists (
    select 1 from public.submissions s
    where s.image_url = p.poster_url
      and s.uploader_id = p.uploader_id
  );

-- Mark old pending/rejected posters as soft-deleted so they don't show up
-- in the old V1 queries. Their data is now in submissions.
update public.posters
set deleted_at = now()
where status in ('pending', 'rejected')
  and deleted_at is null;

-- ─── 4. Drop old increment_poster_view_count RPC ───────────────────────────

drop function if exists public.increment_poster_view_count(uuid);

-- ─── 5. Drop old review_poster RPC (replaced by approve/reject_submission) ──

drop function if exists public.review_poster(uuid, text, text);

commit;
