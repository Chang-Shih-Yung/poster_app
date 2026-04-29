// Mirrors the Postgres enum values so forms can render dropdowns.
// Keep in sync with supabase/migrations — the DB is the source of truth.

export const WORK_KINDS = [
  { value: "movie", label: "電影" },
  { value: "concert", label: "演唱會" },
  { value: "theatre", label: "戲劇" },
  { value: "exhibition", label: "展覽" },
  { value: "event", label: "活動" },
  { value: "original_art", label: "原創作品" },
  { value: "advertisement", label: "商業廣告" },
  { value: "other", label: "其他" },
] as const;

export const REGIONS = [
  { value: "TW", label: "台灣" },
  { value: "JP", label: "日本" },
  { value: "HK", label: "香港" },
  { value: "CN", label: "中國" },
  { value: "KR", label: "韓國" },
  { value: "US", label: "美國" },
  { value: "UK", label: "英國" },
  { value: "FR", label: "法國" },
  { value: "IT", label: "義大利" },
  { value: "PL", label: "波蘭" },
  { value: "BE", label: "比利時" },
  // Added in enum_expansion_and_flags migration
  { value: "DE", label: "德國" },
  { value: "CZ", label: "捷克" },
  { value: "RU", label: "俄羅斯" },
  { value: "AU", label: "澳洲" },
  { value: "IN", label: "印度" },
  { value: "TH", label: "泰國" },
  { value: "VN", label: "越南" },
  { value: "TR", label: "土耳其" },
  { value: "ES", label: "西班牙" },
  { value: "CU", label: "古巴" },
  { value: "OTHER", label: "其他" },
] as const;

// release_type_enum — full list as of enum_expansion_and_flags + new migration
export const RELEASE_TYPES = [
  // ── 發行時序 ──────────────────────────────────────────────────────
  { value: "theatrical",     label: "首映 theatrical" },
  { value: "reissue",        label: "重映 reissue" },
  { value: "anniversary",    label: "週年紀念 anniversary" },
  { value: "teaser",         label: "前導 teaser" },
  // ── 場合 / 版本類型 ───────────────────────────────────────────────
  { value: "special",        label: "特別版 special" },
  { value: "limited",        label: "限定 limited" },
  { value: "international",  label: "國際版 international" },
  { value: "festival",       label: "影展 festival" },
  { value: "character",      label: "角色版 character" },
  { value: "style_a",        label: "Style A" },
  { value: "style_b",        label: "Style B" },
  // ── 放映格式 ──────────────────────────────────────────────────────
  { value: "imax",           label: "IMAX" },
  { value: "dolby",          label: "Dolby" },
  // ── 版本稀缺性 ────────────────────────────────────────────────────
  { value: "variant",        label: "Variant" },
  { value: "timed_release",  label: "限時發行 timed release" },
  { value: "artist_proof",   label: "藝術家校樣 AP" },
  { value: "printer_proof",  label: "印刷校樣 PP" },
  // ── 非官方 ────────────────────────────────────────────────────────
  { value: "unused_concept", label: "未採用稿 unused concept" },
  { value: "bootleg",        label: "非官方 bootleg" },
  { value: "fan_art",        label: "同人 fan art" },
  { value: "other",          label: "其他 other" },
] as const;

// size_type_enum — ISO / regional / collector formats
export const SIZE_TYPES = [
  // ── ISO A 系列 ────────────────────────────────────────────────────
  { value: "A1",              label: "A1 (594×841mm)" },
  { value: "A2",              label: "A2 (420×594mm)" },
  { value: "A3",              label: "A3 (297×420mm)" },
  { value: "A4",              label: "A4 (210×297mm)" },
  { value: "A5",              label: "A5 (148×210mm)" },
  // ── ISO B 系列 ────────────────────────────────────────────────────
  { value: "B1",              label: "B1 (728×1030mm)" },
  { value: "B2",              label: "B2 (515×728mm)" },
  { value: "B3",              label: "B3 (364×515mm)" },
  { value: "B4",              label: "B4 (257×364mm)" },
  { value: "B5",              label: "B5 (182×257mm)" },
  // ── 日本規格 ──────────────────────────────────────────────────────
  { value: "jp_b0",           label: "JP B0 (1030×1456mm)" },
  { value: "jp_chirashi",     label: "日本チラシ chirashi (B5/A4)" },
  { value: "jp_tatekan",      label: "日本立看 tatekan" },
  // ── 台灣傳統 ──────────────────────────────────────────────────────
  { value: "tw_quan_kai",     label: "全開 (TW)" },
  { value: "tw_dui_kai",      label: "對開 (TW)" },
  { value: "tw_si_kai",       label: "四開 (TW)" },
  // ── 香港 ─────────────────────────────────────────────────────────
  { value: "hk_mini",         label: "HK Mini" },
  // ── 美規 ──────────────────────────────────────────────────────────
  { value: "us_one_sheet",    label: "US One Sheet (27×41\")" },
  { value: "us_half_sheet",   label: "US Half Sheet (22×28\")" },
  { value: "us_insert",       label: "US Insert (14×36\")" },
  { value: "us_subway",       label: "US Subway (45×59\")" },
  { value: "us_three_sheet",  label: "US Three Sheet (41×81\")" },
  { value: "us_window_card",  label: "US Window Card (14×22\")" },
  // ── 英規 ──────────────────────────────────────────────────────────
  { value: "uk_quad",         label: "UK Quad (30×40\" landscape)" },
  { value: "uk_double_crown", label: "UK Double Crown (20×30\")" },
  // ── 法規 ──────────────────────────────────────────────────────────
  { value: "fr_grande",       label: "FR Grande (47×63\")" },
  { value: "fr_petite",       label: "FR Petite (16×24\")" },
  // ── 義大利 ────────────────────────────────────────────────────────
  { value: "it_due_fogli",     label: "IT Due Fogli (39×55\")" },
  { value: "it_quattro_fogli", label: "IT Quattro Fogli (55×78\")" },
  { value: "it_locandina",     label: "IT Locandina (13×28\")" },
  { value: "it_fotobusta",     label: "IT Fotobusta (lobby card)" },
  // ── 波蘭 ──────────────────────────────────────────────────────────
  { value: "pl_a1",           label: "PL A1 (23×33\")" },
  // ── 澳洲 ──────────────────────────────────────────────────────────
  { value: "au_daybill",      label: "AU Daybill (13×30\")" },
  // ── Mondo / 收藏格式 ──────────────────────────────────────────────
  { value: "mondo_standard",  label: "Mondo Standard (24×36\")" },
  { value: "lobby_card",      label: "Lobby Card" },
  { value: "press_kit",       label: "Press Kit" },
  // ── 其他 ──────────────────────────────────────────────────────────
  { value: "custom",          label: "自訂尺寸 custom" },
  { value: "other",           label: "其他 other" },
] as const;

// channel_cat_enum — merged with collaborator schema
export const CHANNEL_CATEGORIES = [
  { value: "cinema",        label: "影城 cinema" },
  { value: "distributor",   label: "發行商 distributor" },
  { value: "studio_online", label: "片商線上商店 studio online" },
  { value: "exhibition",    label: "展覽 exhibition" },
  { value: "retail",        label: "零售 retail" },
  { value: "lottery",       label: "抽獎 lottery" },
  { value: "other",         label: "其他 other" },
] as const;

// channel_type — free text in DB; these are UI suggestions only
// (cinema sub-types)
export const CINEMA_RELEASE_TYPES = [
  { value: "weekly_bonus",           label: "週特典 weekly bonus" },
  { value: "special_screening",      label: "特別上映 special screening" },
  { value: "cinema_limited",         label: "影城限定 cinema limited" },
  { value: "premium_format_limited", label: "特殊廳限定 premium format" },
  { value: "ticket_bundle",          label: "票券搭售 ticket bundle" },
] as const;

// channel_type suggestions for other categories
export const CHANNEL_TYPES = [
  { value: "watch_reward",             label: "觀影特典 watch reward" },
  { value: "special_screening_bundle", label: "特映會贈品" },
  { value: "direct_sale",              label: "直售 direct sale" },
  { value: "studio_ticket_bundle",     label: "片商票券搭售" },
  { value: "studio_event_bonus",       label: "片商活動贈品" },
  { value: "ichiban_kuji_prize",       label: "一番賞 ichiban kuji" },
  { value: "exhibition_limited_sale",  label: "展覽限定販售" },
  { value: "exhibition_admission_gift",label: "展覽入場贈品" },
  { value: "lottery_prize",            label: "抽獎獎品" },
  { value: "other",                    label: "其他 other" },
] as const;

// source_platform — structured enum for sourcePlatform field
export const SOURCE_PLATFORMS = [
  { value: "facebook",         label: "Facebook" },
  { value: "instagram",        label: "Instagram" },
  { value: "threads",          label: "Threads" },
  { value: "official_website", label: "官方網站" },
  { value: "online_store",     label: "線上商店" },
  { value: "twitter",          label: "X (Twitter)" },
  { value: "other",            label: "其他 other" },
] as const;

// Cinema name enum for structured cinema selection
export const CINEMA_NAMES = [
  { value: "vieshow",      label: "威秀影城" },
  { value: "showtime",     label: "秀泰影城" },
  { value: "miramar",      label: "美麗華影城" },
  { value: "ambassador",   label: "國賓影城" },
  { value: "centuryasia",  label: "喜樂時代" },
  { value: "eslite_art_house", label: "誠品電影院" },
  { value: "star",         label: "星橋影城" },
  { value: "hala",         label: "哈拉影城" },
  { value: "u_cinema",     label: "in89 豪華" },
  { value: "mld",          label: "MLD 台鋁" },
  { value: "other",        label: "其他 other" },
] as const;

// Material type — enum replacing old free text
export const MATERIAL_TYPES = [
  { value: "paper",       label: "普通紙 paper" },
  { value: "thick_paper", label: "厚紙板 thick paper" },
  { value: "foil",        label: "金屬箔 foil" },
  { value: "metal",       label: "金屬板 metal" },
  { value: "fabric",      label: "布料 fabric" },
  { value: "other",       label: "其他 other" },
] as const;
