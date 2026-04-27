-- ═══════════════════════════════════════════════════════════════════════════
-- posters.work_kind always follows works.work_kind
--
-- posters.work_kind is denormalized from works.work_kind for browse-time
-- filtering (idx_posters_work_kind). Until now nothing kept the two in sync
-- after the initial poster insert — so editing the work's kind, or moving a
-- poster to a different work, would leave posters.work_kind stale.
--
-- We install two triggers and a one-time backfill to fix both directions:
--
--   1. works.work_kind UPDATE → bulk-update every poster underneath
--   2. posters.work_id INSERT/UPDATE → inherit work_kind from the new work
--
-- The combination guarantees posters.work_kind == works.work_kind for every
-- live poster, so the admin can treat it as read-only on the poster editor
-- and trust filtering/browsing queries.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. works.work_kind UPDATE → cascade to posters ────────────────────────

create or replace function public.cascade_work_kind_to_posters()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.posters
     set work_kind = new.work_kind
   where work_id = new.id
     and work_kind is distinct from new.work_kind;
  return new;
end;
$$;

drop trigger if exists trg_cascade_work_kind_to_posters on public.works;

create trigger trg_cascade_work_kind_to_posters
after update of work_kind on public.works
for each row
when (old.work_kind is distinct from new.work_kind)
execute function public.cascade_work_kind_to_posters();

-- ─── 2. posters.work_id INSERT/UPDATE → inherit from work ──────────────────

create or replace function public.inherit_poster_work_kind()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.work_id is not null then
    select work_kind
      into new.work_kind
      from public.works
     where id = new.work_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_inherit_poster_work_kind on public.posters;
drop trigger if exists trg_inherit_poster_work_kind_on_reassign on public.posters;

-- BEFORE so we can mutate NEW.work_kind in place (no second UPDATE needed).
-- Fires on insert always, and on update only when work_id actually changes.
create trigger trg_inherit_poster_work_kind
before insert on public.posters
for each row
execute function public.inherit_poster_work_kind();

create trigger trg_inherit_poster_work_kind_on_reassign
before update of work_id on public.posters
for each row
when (old.work_id is distinct from new.work_id)
execute function public.inherit_poster_work_kind();

-- ─── 3. One-time backfill ──────────────────────────────────────────────────
-- Bring every existing poster in line with its work. Safe to re-run.
update public.posters p
   set work_kind = w.work_kind
  from public.works w
 where p.work_id = w.id
   and p.work_kind is distinct from w.work_kind;

commit;
