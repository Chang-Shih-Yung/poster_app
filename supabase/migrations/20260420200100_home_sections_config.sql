-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 14: Dynamic Home Sections (simplified — no schedule, no A/B)
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: home page section config was split across hardcoded SQL
-- (home_sections RPC had 6 tag labels baked in) and Dart provider wiring.
-- To add or reorder a section needed code + migration + deploy.
--
-- Solution: DB-driven config. Admin can add/reorder/toggle a section by
-- inserting or updating rows in `home_sections_config`. No deploy.
--
-- Also deletes "最新上架" — duplicate of "剛上架" because approved_at and
-- created_at share the same now() at approval time.

begin;

create table if not exists public.home_sections_config (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,                  -- 'popular', 'trending', 'japan_tag'
  title_zh text not null,
  title_en text not null,
  icon text,                                  -- lucide icon name (e.g. 'flame')
  source_type text not null,                  -- see comment below
  source_params jsonb not null default '{}',  -- {"tag": "日本"} / {"days": 7, "limit": 10}
  position int not null default 0,
  enabled boolean not null default true,
  visibility text not null default 'always',  -- 'always' | 'signed_in' | 'has_follows'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.home_sections_config.source_type is
  'Which RPC / dataset backs this section. One of:
   popular, trending_favorites, active_collectors, follow_feed,
   recent_approved, latest_all, for_you, tag_slug';

create index if not exists idx_home_sections_enabled_pos
  on public.home_sections_config (enabled, position)
  where enabled = true;

alter table public.home_sections_config enable row level security;
create policy home_sections_read_all on public.home_sections_config
  for select using (true);
create policy home_sections_admin_write on public.home_sections_config
  for all using (public.is_admin()) with check (public.is_admin());

-- ─── Seed: migrate existing hardcoded sections to config rows ─────────────
-- Same ordering as current home_page.dart:
--   1. popular
--   2. (follow feed + trending + collectors inserted dynamically by client)
--   3. editorial tag sections
--   4. recent_approved ("剛上架")
-- NOTE: we intentionally DROP 最新上架 (see migration header).

insert into public.home_sections_config
  (slug, title_zh, title_en, icon, source_type, source_params, position, visibility)
values
  ('popular',           '熱門',           'Popular',             'flame',       'popular',            '{"days": 30, "limit": 10}'::jsonb, 10,  'always'),
  ('follow_feed',       '追蹤的人最近在收', 'From people you follow', 'user-check', 'follow_feed',        '{"limit": 20}'::jsonb,              20,  'has_follows'),
  ('trending_week',     '本週最多人收藏',  'Trending this week',   'trending-up', 'trending_favorites', '{"days": 7, "limit": 10}'::jsonb,   30,  'always'),
  ('active_collectors', '活躍收藏家',      'Active collectors',    'users',       'active_collectors',  '{"days": 7, "limit": 12}'::jsonb,   40,  'always'),
  -- Editorial tag sections migrated from old home_sections hardcoded array
  ('tag_must_have',     '收藏必備',        'Collector''s Choice',  'star',        'tag_slug',           '{"tag": "curation-must-have", "limit": 10}'::jsonb, 50, 'always'),
  ('tag_classic',       '經典',           'Classic',             'medal',       'tag_slug',           '{"tag": "curation-classic", "limit": 10}'::jsonb, 60, 'always'),
  ('tag_japan',         '日版海報',        'Japanese Posters',     'flag',        'tag_slug',           '{"tag": "country-jp", "limit": 10}'::jsonb, 70, 'always'),
  ('tag_taiwan',        '台版海報',        'Taiwanese Posters',    'flag',        'tag_slug',           '{"tag": "country-tw", "limit": 10}'::jsonb, 80, 'always'),
  ('tag_hand_painted',  '手繪插畫',        'Hand-painted',         'palette',     'tag_slug',           '{"tag": "medium-hand-painted", "limit": 10}'::jsonb, 90, 'always'),
  ('tag_master',        '大師級',          'Master-level',         'award',       'tag_slug',           '{"tag": "curation-master", "limit": 10}'::jsonb, 100, 'always'),
  ('recent_approved',   '剛上架',          'Just approved',        'sparkle',     'recent_approved',    '{"limit": 12}'::jsonb,              200, 'always')
on conflict (slug) do nothing;

commit;
