// Mirrors the Postgres enum values so forms can render dropdowns.
// Keep in sync with supabase/migrations — the DB is the source of truth.
//
// The DB enums still contain legacy values that are no longer offered in
// the admin UI (e.g. `theatrical`, `imax`, `jp_chirashi`). Postgres can't
// DROP enum values without recreating the type, which would cascade through
// ~50 RPC functions. Phase 2 of the partner-spec migration UPDATEd existing
// rows to use the new value sets and orphaned the old ones in the enum.
// Don't add legacy values back here.

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

// region_enum — partner spec: TW, JP, KR, HK, CN, US, UK, FR, IT, PL, BE, OTHER
// (DB has more — DE, CZ, RU, AU, IN, TH, VN, TR, ES, CU — kept for legacy
// rows but admin form only offers partner's 12.)
export const REGIONS = [
  { value: "TW",    label: "台灣" },
  { value: "JP",    label: "日本" },
  { value: "KR",    label: "韓國" },
  { value: "HK",    label: "香港" },
  { value: "CN",    label: "中國" },
  { value: "US",    label: "美國" },
  { value: "UK",    label: "英國" },
  { value: "FR",    label: "法國" },
  { value: "IT",    label: "義大利" },
  { value: "PL",    label: "波蘭" },
  { value: "BE",    label: "比利時" },
  { value: "OTHER", label: "其他" },
] as const;

// release_type_enum — partner's 11-value list (replacing the older 21-value
// hybrid that mixed timing/format/scarcity dimensions).
// Format dimension (IMAX/Dolby/etc.) moved to PREMIUM_FORMATS.
export const RELEASE_TYPES = [
  { value: "first_run",            label: "首映 first run" },
  { value: "re_release",           label: "重映 re-release" },
  { value: "special_screening",    label: "特別放映 special screening" },
  { value: "anniversary",          label: "週年紀念 anniversary" },
  { value: "film_festival",        label: "影展 film festival" },
  { value: "theater_campaign",     label: "影城活動 theater campaign" },
  { value: "distributor_campaign", label: "片商活動 distributor campaign" },
  { value: "retail_release",       label: "零售發行 retail release" },
  { value: "exhibition_release",   label: "展覽發行 exhibition release" },
  { value: "lottery_prize",        label: "抽獎獎品 lottery prize" },
  { value: "other",                label: "其他 other" },
] as const;

// size_type_enum — partner's simplified 11-value set. Non-standard sizes
// go into CUSTOM with custom_width / custom_height / size_unit fields.
// Use UPPERCASE to match partner spec; DB enum stores lowercase 'custom'
// for legacy rows but admin UI normalizes to uppercase 'CUSTOM' string —
// the actual DB enum supports both via legacy values.
export const SIZE_TYPES = [
  { value: "A1",     label: "A1 (594×841mm)" },
  { value: "A2",     label: "A2 (420×594mm)" },
  { value: "A3",     label: "A3 (297×420mm)" },
  { value: "A4",     label: "A4 (210×297mm)" },
  { value: "A5",     label: "A5 (148×210mm)" },
  { value: "B1",     label: "B1 (728×1030mm)" },
  { value: "B2",     label: "B2 (515×728mm)" },
  { value: "B3",     label: "B3 (364×515mm)" },
  { value: "B4",     label: "B4 (257×364mm)" },
  { value: "B5",     label: "B5 (182×257mm)" },
  { value: "custom", label: "自訂尺寸 CUSTOM" }, // lowercase to match DB enum value
] as const;

// size_unit_enum — pairs with custom_width / custom_height when sizeType=custom
export const SIZE_UNITS = [
  { value: "cm",   label: "公分 (cm)" },
  { value: "inch", label: "英吋 (inch)" },
] as const;

// channel_cat_enum — partner's 5-value list
// (DB still has distributor/retail/lottery as orphans for legacy rows.)
export const CHANNEL_CATEGORIES = [
  { value: "cinema",        label: "影城 cinema" },
  { value: "studio_online", label: "片商線上商店 studio online" },
  { value: "ichiban_kuji",  label: "一番賞 ichiban kuji" },
  { value: "exhibition",    label: "展覽 exhibition" },
  { value: "other",         label: "其他 other" },
] as const;

// cinema_release_types — multi-select (array<string>) when channelCategory=cinema.
// One poster can be both "premium_format_limited" and "weekly_bonus".
export const CINEMA_RELEASE_TYPES = [
  { value: "weekly_bonus",           label: "週特典 weekly bonus" },
  { value: "special_screening",      label: "特別上映 special screening" },
  { value: "cinema_limited",         label: "影城限定 cinema limited" },
  { value: "premium_format_limited", label: "特殊廳限定 premium format" },
  { value: "ticket_bundle",          label: "票券搭售 ticket bundle" },
] as const;

// premium_format_enum — only used when cinemaReleaseTypes contains
// "premium_format_limited"
export const PREMIUM_FORMATS = [
  { value: "IMAX",     label: "IMAX" },
  { value: "DOLBY",    label: "Dolby Cinema" },
  { value: "DVA",      label: "Dolby Vision + Atmos (DVA)" },
  { value: "4DX",      label: "4DX" },
  { value: "ULTRA_4D", label: "Ultra 4D" },
  { value: "SCREENX",  label: "ScreenX" },
  { value: "D_BOX",    label: "D-Box" },
  { value: "LUXE",     label: "LUXE" },
  { value: "REALD_3D", label: "RealD 3D" },
] as const;

// channel_type — used when channelCategory != cinema.
// Partner's 9-value list (we removed cinema-specific values that now live
// in CINEMA_RELEASE_TYPES).
export const CHANNEL_TYPES = [
  { value: "watch_reward",              label: "觀影特典 watch reward" },
  { value: "special_screening_bundle",  label: "特映會贈品 special screening bundle" },
  { value: "direct_sale",               label: "直售 direct sale" },
  { value: "studio_ticket_bundle",      label: "片商票券搭售" },
  { value: "studio_event_bonus",        label: "片商活動贈品" },
  { value: "ichiban_kuji_prize",        label: "一番賞獎品 ichiban kuji prize" },
  { value: "exhibition_limited_sale",   label: "展覽限定販售" },
  { value: "exhibition_admission_gift", label: "展覽入場贈品" },
  { value: "other",                     label: "其他 other" },
] as const;

// cinema_name_enum — used when channelCategory=cinema.
// MUST stay in sync with the cinema_name_enum DB type — these become
// filter values for end-user push notifications and search.
export const CINEMA_NAMES = [
  { value: "vieshow",          label: "威秀影城" },
  { value: "showtime",         label: "秀泰影城" },
  { value: "miramar",          label: "美麗華影城" },
  { value: "ambassador",       label: "國賓影城" },
  { value: "centuryasia",      label: "喜樂時代" },
  { value: "eslite_art_house", label: "誠品電影院" },
  { value: "star",             label: "星橋影城" },
  { value: "hala",             label: "哈拉影城" },
  { value: "u_cinema",         label: "in89 豪華" },
  { value: "mld",              label: "MLD 台鋁" },
  { value: "other",             label: "其他 other" },
] as const;

// source_platform — partner's 6 values (we drop 'twitter', kept previously)
export const SOURCE_PLATFORMS = [
  { value: "facebook",         label: "Facebook" },
  { value: "instagram",        label: "Instagram" },
  { value: "threads",          label: "Threads" },
  { value: "official_website", label: "官方網站" },
  { value: "online_store",     label: "線上商店" },
  { value: "other",            label: "其他 other" },
] as const;

// material_type — partner's spec
export const MATERIAL_TYPES = [
  { value: "paper",       label: "普通紙 paper" },
  { value: "thick_paper", label: "厚紙板 thick paper" },
  { value: "foil",        label: "金屬箔 foil" },
  { value: "metal",       label: "金屬板 metal" },
  { value: "fabric",      label: "布料 fabric" },
  { value: "other",       label: "其他 other" },
] as const;
