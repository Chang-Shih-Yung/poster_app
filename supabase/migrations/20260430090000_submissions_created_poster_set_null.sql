-- ═══════════════════════════════════════════════════════════════════════════
-- submissions.created_poster_id — change FK to ON DELETE SET NULL
--
-- Background:
--   The original v2 schema (20260416100100) declared
--     created_poster_id uuid references public.posters(id)
--   without an ON DELETE clause, so it defaults to NO ACTION. That means
--   any DELETE on a poster row gets blocked the moment ANY approved
--   submission still points at it via created_poster_id.
--
--   In practice this surfaces as the admin "刪除作品 / 刪除分類" buttons
--   sometimes erroring with a Postgres FK violation when the underlying
--   posters originally came from user submissions. The user-facing fix
--   was to manually `update submissions set created_poster_id = null`
--   before each delete — easy to forget, leaks DB schema knowledge into
--   every server action that deletes posters.
--
-- Decision: change the FK to ON DELETE SET NULL.
--
--   - submissions is a historical audit table. The original submission
--     metadata (work_title, image_url, uploader_id, status, reviewer,
--     timestamps, review_note) all remain meaningful after the resulting
--     poster gets deleted. Only the back-pointer becomes stale; setting
--     it to NULL is the honest signal "the poster this approved into has
--     since been deleted."
--   - The two RPCs that read created_poster_id (tag_suggestion_*,
--     similarity_detection) already guard with `where created_poster_id
--     is not null`, so they're SET NULL-safe by construction.
--   - approve_submission writes created_poster_id only on the just-
--     created poster, never on a deleted one — also safe.
--
-- After this migration: deleteWork / deleteStudio / any future poster
-- DELETE just works. No more pre-clearing the FK manually.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.submissions
  drop constraint if exists submissions_created_poster_id_fkey;

alter table public.submissions
  add constraint submissions_created_poster_id_fkey
  foreign key (created_poster_id) references public.posters(id)
  on delete set null;

commit;
