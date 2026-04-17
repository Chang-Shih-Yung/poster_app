-- ═══════════════════════════════════════════════════════════════════════════
-- Index cleanup + performance indexes (EPIC 10 audit)
-- ═══════════════════════════════════════════════════════════════════════════
-- After building Work page, user profile, and batch upload, these queries
-- need indexes to avoid full-table scans as the table grows:
--
--   - posters.uploader_id: PublicProfilePage uses `WHERE uploader_id = ?`
--   - posters.work_id: WorkPage uses `WHERE work_id = ?`
--   - submissions.batch_id: admin batch grouping uses `WHERE batch_id = ?`
--   - submissions.uploader_id: rate-limit trigger uses it N times per insert

begin;

create index if not exists idx_posters_uploader_id
  on public.posters (uploader_id)
  where deleted_at is null;

create index if not exists idx_posters_work_id
  on public.posters (work_id)
  where work_id is not null and deleted_at is null;

create index if not exists idx_submissions_batch_id
  on public.submissions (batch_id)
  where batch_id is not null;

create index if not exists idx_submissions_uploader_created
  on public.submissions (uploader_id, created_at desc);

commit;
