-- Delete all 10 bot seed users + every row they touched.
-- Paste into Supabase Dashboard SQL editor (needs service role to
-- bypass RLS). Safe to re-run — every DELETE is idempotent.
--
-- Scope:
--   * 10 bot profiles (uuid 00000000-...-010{0..9})
--   * every follow where either side is a bot
--   * every favorite by a bot
--   * every notification where the actor or recipient is a bot
--   * every avatar_report filed by a bot (if any)
--
-- Leaves intact: real users (Henry, BIU), posters, submissions, works,
-- tags — bots never uploaded, so the content graph is unaffected.

BEGIN;

WITH bots AS (
  SELECT unnest(ARRAY[
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    '00000000-0000-0000-0000-000000000107',
    '00000000-0000-0000-0000-000000000108',
    '00000000-0000-0000-0000-000000000109'
  ]::uuid[]) AS id
)
-- 1. Follows — both directions
DELETE FROM public.follows
  WHERE follower_id IN (SELECT id FROM bots)
     OR following_id IN (SELECT id FROM bots);

WITH bots AS (
  SELECT unnest(ARRAY[
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    '00000000-0000-0000-0000-000000000107',
    '00000000-0000-0000-0000-000000000108',
    '00000000-0000-0000-0000-000000000109'
  ]::uuid[]) AS id
)
-- 2. Favorites
DELETE FROM public.favorites
  WHERE user_id IN (SELECT id FROM bots);

WITH bots AS (
  SELECT unnest(ARRAY[
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    '00000000-0000-0000-0000-000000000107',
    '00000000-0000-0000-0000-000000000108',
    '00000000-0000-0000-0000-000000000109'
  ]::uuid[]) AS id
)
-- 3. Notifications (actor OR recipient)
DELETE FROM public.notifications
  WHERE actor_id IN (SELECT id FROM bots)
     OR recipient_id IN (SELECT id FROM bots);

WITH bots AS (
  SELECT unnest(ARRAY[
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    '00000000-0000-0000-0000-000000000107',
    '00000000-0000-0000-0000-000000000108',
    '00000000-0000-0000-0000-000000000109'
  ]::uuid[]) AS id
)
-- 4. Avatar reports (defensive — bots probably never reported anything)
DELETE FROM public.avatar_reports
  WHERE reporter_id IN (SELECT id FROM bots)
     OR target_user_id IN (SELECT id FROM bots);

-- 5. Finally, the bot profiles themselves
DELETE FROM public.users
  WHERE id = ANY(ARRAY[
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    '00000000-0000-0000-0000-000000000107',
    '00000000-0000-0000-0000-000000000108',
    '00000000-0000-0000-0000-000000000109'
  ]::uuid[]);

-- Post-delete sanity: Henry/BIU follower counts should drop.
SELECT display_name, handle, follower_count
  FROM public.users
  WHERE handle IN ('henry', 'biu');

-- Verify zero bots remain
SELECT count(*) AS bots_remaining
  FROM public.users
  WHERE handle LIKE 'bot%';

COMMIT;
