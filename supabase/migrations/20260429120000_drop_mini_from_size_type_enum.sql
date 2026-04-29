-- ═══════════════════════════════════════════════════════════════════════════
-- Drop 'mini' from size_type_enum (the proper enum-recreation dance).
--
-- Background:
-- Migration 20260429100000 migrated all `posters.size_type = 'mini'` rows to
-- 'other' but left the enum value in place because Postgres doesn't support
-- DROP VALUE on an enum. The result was that 'mini' was unselectable from
-- the admin UI but technically still INSERTable via raw SQL.
--
-- The dance:
--   1. Build a new enum (size_type_enum_new) containing every value of the
--      current enum EXCEPT 'mini'. Use a DO block + pg_enum so we don't have
--      to hard-code the value list (which could drift from reality if a
--      collaborator added a value via raw SQL).
--   2. ALTER each table.column that uses size_type_enum to use the new type,
--      casting via text. Any row with size_type = 'mini' would fail this
--      cast — but the previous migration already moved them all to 'other'.
--   3. DROP the old enum, RENAME the new one to take its place.
--
-- Tables touched: posters, submissions (the only two columns using this enum
-- as of today). If a future migration adds another column with size_type_enum,
-- it must be added to step 2 here and back-ported to wherever this is run.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- Safety: refuse to proceed if any row still has 'mini'. The previous
-- migration should have cleaned these up; this is a sanity check.
do $$
declare
  v_remaining int;
begin
  select count(*) into v_remaining from public.posters where size_type = 'mini';
  if v_remaining > 0 then
    raise exception 'Refusing to drop mini: % poster row(s) still use it. Migrate them first.', v_remaining;
  end if;
  select count(*) into v_remaining from public.submissions where size_type = 'mini';
  if v_remaining > 0 then
    raise exception 'Refusing to drop mini: % submission row(s) still use it. Migrate them first.', v_remaining;
  end if;
end $$;

-- ─── 1. Build size_type_enum_new dynamically ─────────────────────────────
-- Read every label of the current enum (in sort order), filter out 'mini',
-- and build a CREATE TYPE statement.
do $$
declare
  v_values text;
begin
  select string_agg(quote_literal(enumlabel), ', ' order by enumsortorder)
  into v_values
  from pg_enum
  where enumtypid = 'public.size_type_enum'::regtype
    and enumlabel <> 'mini';

  if v_values is null then
    raise exception 'No enum values found for size_type_enum — aborting.';
  end if;

  execute format(
    'create type public.size_type_enum_new as enum (%s)',
    v_values
  );
end $$;

-- ─── 2. Switch columns over ──────────────────────────────────────────────
-- The cast via text works because every remaining label exists in the new
-- enum (we only removed 'mini', and step 0 above guarantees no rows use it).
alter table public.posters
  alter column size_type type public.size_type_enum_new
  using size_type::text::public.size_type_enum_new;

alter table public.submissions
  alter column size_type type public.size_type_enum_new
  using size_type::text::public.size_type_enum_new;

-- ─── 3. Drop the old type, rename the new one to take its place ──────────
drop type public.size_type_enum;
alter type public.size_type_enum_new rename to size_type_enum;

commit;
