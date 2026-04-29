-- ═══════════════════════════════════════════════════════════════════════════
-- Partner schema — Phase 2b: drops + constraints
--
-- Runs AFTER Phase 2a (enum remap). Three things:
--   1. DROP collector flag columns (signed/numbered/edition_number/
--      linen_backed/licensed) — verified Flutter doesn't use them
--   2. Add unique index on (work_id, lower(poster_name)) to prevent
--      duplicate posters with the same name within the same work
--   3. Future-proofing: this migration does NOT add NOT NULL yet.
--      Tightening constraints requires backfilling existing NULLs first,
--      and admin form must pre-validate. We'll do that in Phase 2c after
--      the form is updated to enforce required fields.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. DROP collector flag columns ────────────────────────────────────
-- Flutter audit (grep -rn "signed|numbered|linen_backed|licensed|edition_number"
-- in lib/*.dart) returned only auth-related "signed in" matches — no Flutter
-- code reads these poster columns. Safe to drop.
--
-- Admin code: server actions, PosterForm, DraftCard, _shared.ts all reference
-- these and will be updated in Phase 3. After that, no app code touches them.
alter table public.posters drop column if exists signed;
alter table public.posters drop column if exists numbered;
alter table public.posters drop column if exists edition_number;
alter table public.posters drop column if exists linen_backed;
alter table public.posters drop column if exists licensed;

-- ─── 2. Unique index: no duplicate poster names within a work ──────────
-- Sanity check first: refuse if duplicates already exist.
do $$
declare
  v_dup_count int;
begin
  select count(*) into v_dup_count
  from (
    select work_id, lower(poster_name)
    from public.posters
    where deleted_at is null
      and poster_name is not null
      and work_id is not null
    group by 1, 2
    having count(*) > 1
  ) t;

  if v_dup_count > 0 then
    raise exception
      'Refusing to add unique index: % duplicate (work_id, lower(poster_name)) pair(s) exist. Run cleanup first.',
      v_dup_count;
  end if;
end $$;

-- Partial index excludes soft-deleted rows. Allows admin to re-create
-- a poster with the same name after deleting the old one.
-- lower() catches case variations ('B1 原版' = 'b1 原版').
create unique index if not exists posters_work_id_name_unique
  on public.posters (work_id, lower(poster_name))
  where deleted_at is null and poster_name is not null;

comment on index public.posters_work_id_name_unique is
  'Prevents two non-deleted posters in the same work from having the same name (case-insensitive). Server action createPoster + updatePoster also pre-checks for friendly error message; this index is the race-condition safety net.';

commit;
