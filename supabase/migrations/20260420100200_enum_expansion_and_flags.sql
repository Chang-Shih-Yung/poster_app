-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18: enum expansions + work_kind + poster collector flags
-- ═══════════════════════════════════════════════════════════════════════════
-- PG15+ allows ALTER TYPE ADD VALUE in transaction.

begin;

-- ─── 18-2a: region_enum expansion ──────────────────────────────────────────
-- Current: TW/KR/HK/CN/JP/US/UK/FR/IT/PL/BE/OTHER
-- Adding: DE (Germany), CZ (Czech), RU (USSR), AU (Australia), IN (India),
--         TH (Thailand), VN (Vietnam), TR (Turkey), ES (Spain), CU (Cuba)

alter type public.region_enum add value if not exists 'DE';
alter type public.region_enum add value if not exists 'CZ';
alter type public.region_enum add value if not exists 'RU';
alter type public.region_enum add value if not exists 'AU';
alter type public.region_enum add value if not exists 'IN';
alter type public.region_enum add value if not exists 'TH';
alter type public.region_enum add value if not exists 'VN';
alter type public.region_enum add value if not exists 'TR';
alter type public.region_enum add value if not exists 'ES';
alter type public.region_enum add value if not exists 'CU';

-- ─── 18-2b: release_type_enum expansion ───────────────────────────────────
-- Current: theatrical/reissue/special/limited/other
-- Adding collector-relevant editions

alter type public.release_type_enum add value if not exists 'teaser';         -- 前導
alter type public.release_type_enum add value if not exists 'international';  -- 國際版
alter type public.release_type_enum add value if not exists 'festival';       -- 影展版
alter type public.release_type_enum add value if not exists 'character';      -- 角色版
alter type public.release_type_enum add value if not exists 'style_a';        -- Style A
alter type public.release_type_enum add value if not exists 'style_b';        -- Style B
alter type public.release_type_enum add value if not exists 'imax';           -- IMAX
alter type public.release_type_enum add value if not exists 'dolby';          -- Dolby
alter type public.release_type_enum add value if not exists 'artist_proof';   -- AP
alter type public.release_type_enum add value if not exists 'printer_proof';  -- PP
alter type public.release_type_enum add value if not exists 'variant';        -- variant
alter type public.release_type_enum add value if not exists 'timed_release';  -- Mondo
alter type public.release_type_enum add value if not exists 'unused_concept'; -- 未採用稿
alter type public.release_type_enum add value if not exists 'bootleg';        -- 非官方
alter type public.release_type_enum add value if not exists 'fan_art';        -- 同人

-- ─── 18-2c: size_type_enum expansion ───────────────────────────────────────
-- Current: B1/B2/A3/A4/mini/custom/other
-- Adding collector-standard formats

-- US formats
alter type public.size_type_enum add value if not exists 'us_one_sheet';        -- 27×41
alter type public.size_type_enum add value if not exists 'us_half_sheet';       -- 22×28
alter type public.size_type_enum add value if not exists 'us_insert';           -- 14×36
alter type public.size_type_enum add value if not exists 'us_subway';           -- 45×59
alter type public.size_type_enum add value if not exists 'us_three_sheet';      -- 41×81
alter type public.size_type_enum add value if not exists 'us_window_card';      -- 14×22
-- UK
alter type public.size_type_enum add value if not exists 'uk_quad';             -- 30×40 landscape
alter type public.size_type_enum add value if not exists 'uk_double_crown';     -- 20×30
-- French
alter type public.size_type_enum add value if not exists 'fr_grande';           -- 47×63
alter type public.size_type_enum add value if not exists 'fr_petite';           -- 16×24
-- Italian
alter type public.size_type_enum add value if not exists 'it_due_fogli';        -- 39×55
alter type public.size_type_enum add value if not exists 'it_quattro_fogli';    -- 55×78
alter type public.size_type_enum add value if not exists 'it_locandina';        -- 13×28
alter type public.size_type_enum add value if not exists 'it_fotobusta';        -- lobby-card class
-- Polish
alter type public.size_type_enum add value if not exists 'pl_a1';               -- 23×33
-- Japanese (already have B1/B2; add B0 + chirashi + tatekan)
alter type public.size_type_enum add value if not exists 'jp_b0';               -- 1030×1456
alter type public.size_type_enum add value if not exists 'jp_chirashi';         -- B5/A4 flyer
alter type public.size_type_enum add value if not exists 'jp_tatekan';          -- standee
-- Australian
alter type public.size_type_enum add value if not exists 'au_daybill';          -- 13×30
-- Taiwan traditional
alter type public.size_type_enum add value if not exists 'tw_quan_kai';         -- 全開
alter type public.size_type_enum add value if not exists 'tw_dui_kai';          -- 對開
alter type public.size_type_enum add value if not exists 'tw_si_kai';           -- 四開
-- HK
alter type public.size_type_enum add value if not exists 'hk_mini';
-- Mondo
alter type public.size_type_enum add value if not exists 'mondo_standard';      -- 24×36
-- Misc collector formats
alter type public.size_type_enum add value if not exists 'lobby_card';
alter type public.size_type_enum add value if not exists 'press_kit';

-- ─── 18-3: work_kind_enum ──────────────────────────────────────────────────
-- Open platform: not every poster is for a movie. Circus, concerts, original
-- art, advertisements all need a home.

create type public.work_kind_enum as enum (
  'movie',          -- 電影（最多）
  'concert',        -- 演唱會 / 音樂會
  'theatre',        -- 戲劇 / 舞台劇
  'exhibition',     -- 展覽
  'event',          -- 活動（馬戲團、馬拉松、節慶 ...）
  'original_art',   -- 原創作品（無外部 reference）
  'advertisement',  -- 商業廣告
  'other'
);

alter table public.works
  add column if not exists work_kind public.work_kind_enum not null default 'movie';

create index if not exists idx_works_work_kind on public.works(work_kind);

-- ─── 18-4: poster boolean flags ────────────────────────────────────────────
-- Collector-relevant per-poster physical / provenance flags.

alter table public.posters
  add column if not exists signed boolean not null default false,
  add column if not exists numbered boolean not null default false,
  add column if not exists edition_number text,          -- e.g. '42/325'
  add column if not exists linen_backed boolean not null default false,
  add column if not exists licensed boolean not null default true; -- assume licensed by default

alter table public.submissions
  add column if not exists signed boolean not null default false,
  add column if not exists numbered boolean not null default false,
  add column if not exists edition_number text,
  add column if not exists linen_backed boolean not null default false,
  add column if not exists licensed boolean not null default true;

commit;
