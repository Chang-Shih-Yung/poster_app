-- ═══════════════════════════════════════════════════════════════════════════
-- Partner schema spec — Phase 1: pure additions (zero breakage)
--
-- Aligns the DB with collaborator's poster metadata spec. Phase 1 ONLY adds
-- new enums + new columns. No drops, no enum reshape, no NOT NULL.
-- Flutter app + admin both keep working through this migration.
--
-- Phase 2 (separate migration) will:
--   - DROP unused collector flags (signed/numbered/edition_number/linen_backed/licensed)
--   - Recreate release_type / channel_category / size_type enums with the new
--     value sets
--   - Tighten NOT NULL on required fields
--   - Add (work_id, lower(poster_name)) unique index for dup-name prevention
--   - Update approve_submission() RPC
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. New enum types ──────────────────────────────────────────────────

-- premium_format_enum: special-format cinema halls (IMAX, Dolby, 4DX, etc.)
-- Replaces the old `imax`/`dolby` values that lived under release_type_enum.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'premium_format_enum') then
    create type public.premium_format_enum as enum (
      'IMAX',
      'DOLBY',
      'DVA',
      '4DX',
      'ULTRA_4D',
      'SCREENX',
      'D_BOX',
      'LUXE',
      'REALD_3D'
    );
  end if;
end $$;

-- size_unit_enum: pairs with custom_width/custom_height when sizeType=CUSTOM
do $$
begin
  if not exists (select 1 from pg_type where typname = 'size_unit_enum') then
    create type public.size_unit_enum as enum (
      'cm',
      'inch'
    );
  end if;
end $$;

-- cinema_name_enum: Taiwan cinema chains. Replaces the existing free-text
-- `channel_name` field for cinema posters specifically. The Chinese names
-- below MUST match exactly what the Flutter app and the admin form display
-- (these become filter values for end-user push notifications and search).
--
-- Mapping (admin/lib/enums.ts CINEMA_NAMES):
--   vieshow         威秀影城
--   showtime        秀泰影城
--   miramar         美麗華影城
--   ambassador      國賓影城
--   centuryasia     喜樂時代
--   eslite_art_house 誠品電影院
--   star            星橋影城
--   hala            哈拉影城
--   u_cinema        in89 豪華
--   mld             MLD 台鋁
--   other           其他
do $$
begin
  if not exists (select 1 from pg_type where typname = 'cinema_name_enum') then
    create type public.cinema_name_enum as enum (
      'vieshow',
      'showtime',
      'miramar',
      'ambassador',
      'centuryasia',
      'eslite_art_house',
      'star',
      'hala',
      'u_cinema',
      'mld',
      'other'
    );
  end if;
end $$;

-- ─── 2. New columns on `works` ──────────────────────────────────────────

-- work_key: reserved for future cross-source dedup (auto-import from
-- IMDB/TMDB, multi-admin, public API). Currently nullable, no auto-fill,
-- no UNIQUE constraint. Enable later by adding trigger + index.
alter table public.works
  add column if not exists work_key text;

comment on column public.works.work_key is
  'Reserved for cross-source dedup. Currently no auto-fill, no UNIQUE constraint. Add trigger + UNIQUE when multi-admin or auto-import is enabled.';

-- works.movie_release_date and movie_release_year already exist as plain
-- columns since 20260416100100. No changes needed in Phase 1.

-- ─── 3. New columns on `posters` ────────────────────────────────────────

-- cinema_release_types: multi-select of CINEMA_RELEASE_TYPES. Only used
-- when channel_category='cinema'. text[] (free string array) rather than
-- enum[] so we can extend the suggestion list without a migration each
-- time. Validation lives in the admin form.
alter table public.posters
  add column if not exists cinema_release_types text[] default '{}';

-- premium_format: only used when cinema_release_types contains
-- 'premium_format_limited'.
alter table public.posters
  add column if not exists premium_format public.premium_format_enum;

-- cinema_name: only used when channel_category='cinema'. NOT replacing
-- channel_name (which stays as free-text fallback for non-cinema channels).
alter table public.posters
  add column if not exists cinema_name public.cinema_name_enum;

-- custom_width/height/unit: only used when size_type='custom' (or 'CUSTOM'
-- after Phase 2 enum reshape).
alter table public.posters
  add column if not exists custom_width numeric;

alter table public.posters
  add column if not exists custom_height numeric;

alter table public.posters
  add column if not exists size_unit public.size_unit_enum;

-- channel_note: separate from source_note. channel_note describes the
-- channel/cinema/distributor specifics ("威秀獨家加贈卡套"); source_note
-- describes the data source ("see Facebook post 2024-03-15").
alter table public.posters
  add column if not exists channel_note text;

-- batch_id: traces posters created via /posters/batch flow. Lets admin
-- find "all 12 posters from that one batch upload last Tuesday" if a
-- mistake needs unwinding.
alter table public.posters
  add column if not exists batch_id text;

-- updated_by: existing posters has updated_at trigger; add who-did-it
-- so audit log isn't the only place the actor is tracked.
alter table public.posters
  add column if not exists updated_by uuid references auth.users(id);

-- ─── 4. Comments for future-readers ─────────────────────────────────────

comment on column public.posters.cinema_release_types is
  'Multi-select of cinema-specific release types (weekly_bonus, premium_format_limited, etc.). Only meaningful when channel_category=cinema.';

comment on column public.posters.premium_format is
  'IMAX / Dolby / 4DX / etc. Only meaningful when cinema_release_types contains premium_format_limited.';

comment on column public.posters.cinema_name is
  'Cinema chain enum. Only meaningful when channel_category=cinema. End-user push notifications and search filter on this value.';

comment on column public.posters.batch_id is
  'Set by /posters/batch flow. Lets admin trace all posters from a single batch upload.';

commit;
