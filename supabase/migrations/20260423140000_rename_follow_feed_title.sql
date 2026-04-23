-- ═══════════════════════════════════════════════════════════════════════════
-- Rename the follow_feed home section title from
--   追蹤的人最近在收  →  你可能也喜歡
-- Per user design call: the old phrasing reads too literal ("people you
-- follow recently favorited") — too many hops to parse. "你可能也喜歡"
-- is the Spotify / Netflix framing that users already understand.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

update public.home_sections_config
   set title_zh = '你可能也喜歡',
       updated_at = now()
 where slug = 'follow_feed';

commit;
