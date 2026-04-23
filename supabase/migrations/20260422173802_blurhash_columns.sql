-- ═══════════════════════════════════════════════════════════════════════════
-- v19 Phase 3 — BlurHash placeholder strings on posters
-- ═══════════════════════════════════════════════════════════════════════════
-- BlurHash is a ~30-byte representation of a blurred image (Wolt's
-- algorithm — https://blurha.sh). The front-end can paint it as a
-- pixel-perfect blurred placeholder *before* the real image is
-- fetched, then fade in. Pinterest / Mastodon / Wolt do this — it
-- removes the "grey square then pop" effect for image-heavy feeds.
--
-- Schema: nullable text column on posters. Compute happens later in
-- a Supabase Edge Function (or backfill job) — see
-- supabase/functions/poster-blurhash/. Front-end gracefully falls
-- back to ShimmerPlaceholder when the column is null.

begin;

alter table public.posters
  add column if not exists blurhash text;

-- No CHECK constraint on shape — BlurHash strings are 6-40 chars in
-- a base83 alphabet, but we trust the producer (our Edge Function).
-- A future malicious-input check could land here.

commit;
