-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 14-5: drop legacy home_sections RPC and the renamed alias
-- ═══════════════════════════════════════════════════════════════════════════
-- home_sections_v2() is now the only home RPC the client calls. Old
-- home_sections() + the recent_approved_feed() standalone are effectively
-- superseded — recent_approved_feed() is still referenced inside
-- home_sections_v2 as a helper so we KEEP it, but drop home_sections().

begin;

drop function if exists public.home_sections(int);

commit;
