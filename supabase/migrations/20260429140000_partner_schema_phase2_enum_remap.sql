-- ═══════════════════════════════════════════════════════════════════════════
-- Partner schema — Phase 2: enum value reshape (additive only)
--
-- Adds the new enum values from collaborator's spec, then UPDATEs existing
-- rows to use the new values. Does NOT drop or recreate enum types — that
-- avoids cascading recompilation through ~50 RPC functions and views that
-- reference these enum columns.
--
-- Old enum values remain in the type as orphans (no row uses them, but
-- they're not removable without full type recreation, same pattern as
-- 'mini' in 20260429120000_drop_mini_from_size_type_enum.sql which DID
-- recreate but only because nothing else referenced it).
--
-- Flutter app coordination: Flutter has its own Dart enums for these
-- columns. After this migration, rows will return new string values that
-- Flutter's old Dart enums won't recognize — Flutter's `fromString`
-- fallback returns the raw string, which renders ugly but doesn't crash.
-- Schedule a Flutter update to mirror the new values.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. Sanity check: no pending submissions ───────────────────────────
-- Pending submissions hold enum values too. After this migration, their
-- enum fields would still be the old string (until admin opens + reviews
-- them). We require zero pending so the enum-remap is clean.
do $$
declare
  v_pending int;
begin
  select count(*) into v_pending from public.submissions where status = 'pending';
  if v_pending > 0 then
    raise exception
      'Refusing to remap enums: % pending submission(s) exist. Process them first (approve/reject) or set their enum fields to NULL.',
      v_pending;
  end if;
end $$;

-- ─── 2. Add new release_type_enum values ───────────────────────────────
-- Collaborator's new list:
--   first_run, re_release, special_screening, anniversary, film_festival,
--   theater_campaign, distributor_campaign, retail_release,
--   exhibition_release, lottery_prize, other
--
-- Already exist: anniversary, other
-- New: 9 values
alter type public.release_type_enum add value if not exists 'first_run';
alter type public.release_type_enum add value if not exists 're_release';
alter type public.release_type_enum add value if not exists 'special_screening';
alter type public.release_type_enum add value if not exists 'film_festival';
alter type public.release_type_enum add value if not exists 'theater_campaign';
alter type public.release_type_enum add value if not exists 'distributor_campaign';
alter type public.release_type_enum add value if not exists 'retail_release';
alter type public.release_type_enum add value if not exists 'exhibition_release';
alter type public.release_type_enum add value if not exists 'lottery_prize';

-- ─── 3. Add new channel_cat_enum value ─────────────────────────────────
-- Collaborator's new list: cinema, studio_online, ichiban_kuji, exhibition, other
-- Already exist: cinema, studio_online, exhibition, other
-- New: ichiban_kuji
-- Orphaned (still in enum, no row will use): distributor, retail, lottery
alter type public.channel_cat_enum add value if not exists 'ichiban_kuji';

-- ─── 4. size_type_enum: collaborator wants only A1-A5, B1-B5, CUSTOM ───
-- All A/B values already exist. 'custom' lowercase already exists.
-- We DON'T change the lowercase 'custom' to uppercase — TS layer maps it.
-- Orphaned: ~30 international/regional sizes (jp_*, tw_*, us_*, etc.)
-- These stay in the enum but admin form will only show the 11 partner values.
-- (No new values to add for size_type_enum.)

commit;

-- ─── 5. UPDATE rows to use new enum values ─────────────────────────────
-- Postgres requires the ADD VALUE to be committed BEFORE we can use the
-- new value in an UPDATE. Hence the explicit commit above + new
-- transaction below.
begin;

-- 5a. release_type — direct renames
update public.posters
  set poster_release_type = 'first_run'
  where poster_release_type::text = 'theatrical';

update public.submissions
  set poster_release_type = 'first_run'
  where poster_release_type::text = 'theatrical';

update public.posters
  set poster_release_type = 're_release'
  where poster_release_type::text = 'reissue';

update public.submissions
  set poster_release_type = 're_release'
  where poster_release_type::text = 'reissue';

update public.posters
  set poster_release_type = 'film_festival'
  where poster_release_type::text = 'festival';

update public.submissions
  set poster_release_type = 'film_festival'
  where poster_release_type::text = 'festival';

-- 5b. release_type imax/dolby — move to new premium_format column
update public.posters
  set premium_format = 'IMAX'::premium_format_enum,
      poster_release_type = NULL
  where poster_release_type::text = 'imax';

update public.posters
  set premium_format = 'DOLBY'::premium_format_enum,
      poster_release_type = NULL
  where poster_release_type::text = 'dolby';

-- submissions table doesn't have premium_format column (it's the
-- pre-approval staging area; if needed, partner can add later). For
-- now, just NULL out imax/dolby on submissions so the value isn't lost
-- but doesn't auto-flow to approved poster either.
update public.submissions
  set poster_release_type = NULL
  where poster_release_type::text in ('imax', 'dolby');

-- 5c. release_type — values that have no clean mapping → 'other' (we
-- preserve "this row had a special release type set" intent without
-- losing it entirely)
update public.posters
  set poster_release_type = 'other'
  where poster_release_type::text in (
    'special', 'limited', 'international', 'character',
    'style_a', 'style_b', 'teaser',
    'variant', 'timed_release', 'artist_proof', 'printer_proof',
    'unused_concept', 'bootleg', 'fan_art'
  );

update public.submissions
  set poster_release_type = 'other'
  where poster_release_type::text in (
    'special', 'limited', 'international', 'character',
    'style_a', 'style_b', 'teaser',
    'variant', 'timed_release', 'artist_proof', 'printer_proof',
    'unused_concept', 'bootleg', 'fan_art'
  );

-- 5d. channel_category remappings
update public.posters
  set channel_category = 'other'
  where channel_category::text in ('distributor', 'retail');

update public.submissions
  set channel_category = 'other'
  where channel_category::text in ('distributor', 'retail');

update public.posters
  set channel_category = 'ichiban_kuji'
  where channel_category::text = 'lottery';

update public.submissions
  set channel_category = 'ichiban_kuji'
  where channel_category::text = 'lottery';

-- 5e. size_type — collapse non-A/B sizes to 'custom' (existing enum
-- value, lowercase). Admin can re-edit those rows to add custom_width/
-- custom_height/size_unit if accuracy matters.
update public.posters
  set size_type = 'custom'
  where size_type::text in (
    'jp_b0', 'jp_chirashi', 'jp_tatekan',
    'tw_quan_kai', 'tw_dui_kai', 'tw_si_kai',
    'hk_mini',
    'us_one_sheet', 'us_half_sheet', 'us_insert', 'us_subway',
    'us_three_sheet', 'us_window_card',
    'uk_quad', 'uk_double_crown',
    'fr_grande', 'fr_petite',
    'it_due_fogli', 'it_quattro_fogli', 'it_locandina', 'it_fotobusta',
    'pl_a1',
    'au_daybill',
    'mondo_standard', 'lobby_card', 'press_kit',
    'other'
  );

update public.submissions
  set size_type = 'custom'
  where size_type::text in (
    'jp_b0', 'jp_chirashi', 'jp_tatekan',
    'tw_quan_kai', 'tw_dui_kai', 'tw_si_kai',
    'hk_mini',
    'us_one_sheet', 'us_half_sheet', 'us_insert', 'us_subway',
    'us_three_sheet', 'us_window_card',
    'uk_quad', 'uk_double_crown',
    'fr_grande', 'fr_petite',
    'it_due_fogli', 'it_quattro_fogli', 'it_locandina', 'it_fotobusta',
    'pl_a1',
    'au_daybill',
    'mondo_standard', 'lobby_card', 'press_kit',
    'other'
  );

commit;
