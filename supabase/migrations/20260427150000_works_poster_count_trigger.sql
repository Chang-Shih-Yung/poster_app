-- ═══════════════════════════════════════════════════════════════════════════
-- works.poster_count auto-maintenance
-- ═══════════════════════════════════════════════════════════════════════════
--
-- The works table has a `poster_count int not null default 0` column that
-- the original v2 migration commented as "RPC-maintained" — but no RPC
-- ever owned it consistently. The v2 backfill set it once at import time,
-- and `approve_submission` keeps it in sync for the user-submission path,
-- but admin-created posters (Phase 2 mobile admin, /tree inline + button)
-- bypass that RPC and the count drifts from reality.
--
-- This migration:
--   1. Adds an AFTER INSERT/UPDATE/DELETE trigger on `posters` that keeps
--      `works.poster_count` in sync no matter who writes (admin, Flutter
--      client RPC, manual SQL).
--   2. Backfills the current count by re-counting from posters.
--
-- Convention: deleted_at IS NULL counts as "alive". Soft-deleted posters
-- don't show up in the catalogue, so they shouldn't show up in the count.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. Trigger function ────────────────────────────────────────────────

create or replace function public.refresh_work_poster_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  old_alive boolean;
  new_alive boolean;
begin
  if tg_op = 'INSERT' then
    if new.work_id is not null and new.deleted_at is null then
      update public.works
        set poster_count = poster_count + 1
        where id = new.work_id;
    end if;
    return new;

  elsif tg_op = 'DELETE' then
    if old.work_id is not null and old.deleted_at is null then
      update public.works
        set poster_count = greatest(poster_count - 1, 0)
        where id = old.work_id;
    end if;
    return old;

  elsif tg_op = 'UPDATE' then
    old_alive := (old.work_id is not null and old.deleted_at is null);
    new_alive := (new.work_id is not null and new.deleted_at is null);

    -- Same work_id, alive→alive: nothing to do.
    -- Same work_id, alive→dead (soft-delete): decrement.
    -- Same work_id, dead→alive (un-delete): increment.
    -- Different work_id: decrement old, increment new (with alive filter).

    if old.work_id is not distinct from new.work_id then
      if old_alive and not new_alive then
        update public.works
          set poster_count = greatest(poster_count - 1, 0)
          where id = old.work_id;
      elsif not old_alive and new_alive then
        update public.works
          set poster_count = poster_count + 1
          where id = new.work_id;
      end if;
    else
      if old_alive then
        update public.works
          set poster_count = greatest(poster_count - 1, 0)
          where id = old.work_id;
      end if;
      if new_alive then
        update public.works
          set poster_count = poster_count + 1
          where id = new.work_id;
      end if;
    end if;
    return new;
  end if;
  return null;
end;
$$;

-- ─── 2. Trigger ─────────────────────────────────────────────────────────

drop trigger if exists trg_posters_refresh_poster_count on public.posters;
create trigger trg_posters_refresh_poster_count
  after insert or update of work_id, deleted_at or delete
  on public.posters
  for each row
  execute function public.refresh_work_poster_count();

-- ─── 3. Backfill ────────────────────────────────────────────────────────
-- Re-derive every work's poster_count from the actual posters rows.
-- Cheap on a small catalogue, and ensures we start from a known-good state.

update public.works w
set poster_count = coalesce((
  select count(*)::int
  from public.posters p
  where p.work_id = w.id
    and p.deleted_at is null
), 0);

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- Verify (run in dashboard after applying):
--
--   select w.title_zh, w.poster_count,
--          (select count(*) from public.posters p
--           where p.work_id = w.id and p.deleted_at is null) as actual
--   from public.works w
--   order by w.created_at desc
--   limit 20;
--
-- The two columns must always match. If they don't after this runs, the
-- trigger isn't firing — check pg_trigger: select * from pg_trigger where
-- tgname = 'trg_posters_refresh_poster_count';
-- ═══════════════════════════════════════════════════════════════════════════
