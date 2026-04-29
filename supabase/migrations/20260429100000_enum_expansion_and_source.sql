-- ═══════════════════════════════════════════════════════════════════════════
-- Schema sync: enum expansions + poster source marker
--
-- 1. size_type_enum  — add ISO A/B sizes missing from init (A1/A2/A5/B3/B4/B5)
--                      remove mini (non-standard; existing rows → 'other')
-- 2. release_type_enum — add anniversary (distinct from festival)
-- 3. channel_cat_enum  — add studio_online (collaborator schema)
-- 4. posters.source    — 'admin' | 'submission' marker (text, not enum — easy
--                        to extend later without a migration)
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. size_type_enum additions ────────────────────────────────────────────

alter type public.size_type_enum add value if not exists 'A1';
alter type public.size_type_enum add value if not exists 'A2';
alter type public.size_type_enum add value if not exists 'A5';
alter type public.size_type_enum add value if not exists 'B3';
alter type public.size_type_enum add value if not exists 'B4';
alter type public.size_type_enum add value if not exists 'B5';

-- mini → other migration (non-destructive: existing 'mini' rows become 'other')
-- Only runs if any rows still have 'mini' (safe to run regardless).
update public.posters set size_type = 'other' where size_type = 'mini';
update public.submissions set size_type = 'other' where size_type = 'mini';

-- Postgres does not support DROP VALUE from an enum without recreating the
-- type. We leave 'mini' in the enum so existing data referencing it stays
-- valid, but the UI no longer offers it as an option (enums.ts omits it).
-- A future migration can recreate the enum without 'mini' once all rows
-- are migrated.

-- ─── 2. release_type_enum — add anniversary ─────────────────────────────────
-- 'festival' already exists; 'anniversary' covers studio re-release campaigns
-- (e.g. 30th anniversary of Spirited Away) which is a different concept.

alter type public.release_type_enum add value if not exists 'anniversary';

-- ─── 3. channel_cat_enum — add studio_online ────────────────────────────────
-- Covers purchases directly from studio / distributor online stores
-- (e.g. Ghibli Museum Shop, Toho official store).

alter type public.channel_cat_enum add value if not exists 'studio_online';

-- ─── 4. posters.source — admin vs submission provenance ─────────────────────
-- 'admin'      — created directly by an admin in the admin panel
-- 'submission' — approved from a user submission via approve_submission() RPC
-- NULL         — legacy rows created before this column existed

alter table public.posters
  add column if not exists source text
  check (source in ('admin', 'submission'));

-- Backfill: rows with a matching submissions.created_poster_id are submissions.
-- Rows with no match are assumed to be admin-created.
update public.posters p
set source = 'submission'
where exists (
  select 1 from public.submissions s
  where s.created_poster_id = p.id
);

update public.posters p
set source = 'admin'
where source is null
  and deleted_at is null;

-- Also track source on future approve_submission() calls — the RPC will be
-- updated separately to set source = 'submission' on INSERT.

-- ─── 5. submissions: also add source_platform enum values if not text ────────
-- source_platform is already text (not enum) in V2 schema — no change needed.
-- Listing known values here for documentation only:
-- facebook / instagram / threads / twitter / official_website / online_store / other

commit;
