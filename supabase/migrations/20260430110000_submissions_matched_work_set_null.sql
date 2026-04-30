-- ═══════════════════════════════════════════════════════════════════════════
-- submissions.matched_work_id — change FK to ON DELETE SET NULL
--
-- This is the second half of the fix started in 20260430090000
-- (created_poster_id). The submissions table has TWO leaky FKs that
-- block delete-cascade chains:
--   - submissions.created_poster_id → posters(id)   [fixed last patch]
--   - submissions.matched_work_id   → works(id)     [this patch]
--
-- The original v2 migration (20260416100100) declared matched_work_id
-- without an ON DELETE clause → defaults to NO ACTION. Effect: any
-- DELETE on a `works` row gets blocked the moment ANY approved
-- submission still has matched_work_id pointing at it. The admin's
-- "刪除整個分類" button reproduces this exactly — 23503 FK violation,
-- transaction rolls back.
--
-- Same rationale as the previous patch: submissions is an audit table.
-- The original submission metadata stays meaningful after the matched
-- work is deleted; matched_work_id becoming NULL is the honest "the
-- work this was approved into has since been deleted" signal.
--
-- approve_submission writes matched_work_id only on the RPC path that
-- creates/finds a work in the same statement, so it never operates on
-- a deleted work — SET NULL is safe.
--
-- After this migration: deleteWork / deleteStudio just work end to end.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.submissions
  drop constraint if exists submissions_matched_work_id_fkey;

alter table public.submissions
  add constraint submissions_matched_work_id_fkey
  foreign key (matched_work_id) references public.works(id)
  on delete set null;

commit;
