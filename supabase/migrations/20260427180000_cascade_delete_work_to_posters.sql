-- ═══════════════════════════════════════════════════════════════════════════
-- Cascade DELETE from works → posters
--
-- The original v2 migration (20260416100100) added posters.work_id with no
-- `on delete` clause, so the FK falls back to NO ACTION. That made the
-- admin's "delete work" button silently fail whenever the work had any
-- posters underneath — Postgres refuses the delete to keep referential
-- integrity, and the error gets surfaced to the user as "can't delete".
--
-- The user's mental model is Google Drive: deleting the outer folder
-- deletes everything inside. To match, we drop the existing FK and
-- recreate it with ON DELETE CASCADE. poster_groups.work_id already
-- cascades (added in 20260424120000), so once posters do too, deleting
-- a work cleanly tears down its whole subtree in one statement.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.posters
  drop constraint if exists posters_work_id_fkey;

alter table public.posters
  add constraint posters_work_id_fkey
  foreign key (work_id) references public.works(id)
  on delete cascade;

commit;
