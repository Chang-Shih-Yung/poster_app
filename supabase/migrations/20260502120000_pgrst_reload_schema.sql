-- Force PostgREST to reload its schema cache. After multiple ALTER TABLE
-- adds in the past 2 days (promo_image_url / price_type / price_amount /
-- set_id / is_public), the cache may be stale and SELECTs that name new
-- columns return PGRST204 even though the column physically exists.
--
-- NOTIFY is idempotent and instantaneous; this migration is safe to run
-- as many times as needed.

notify pgrst, 'reload schema';
