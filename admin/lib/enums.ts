// Mirrors the Postgres enum values so forms can render dropdowns.

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
  { value: "OTHER", label: "其他" },
] as const;

export const RELEASE_TYPES = [
  { value: "theatrical", label: "首映 theatrical" },
  { value: "reissue", label: "重映 reissue" },
  { value: "special", label: "特別版 special" },
  { value: "limited", label: "限定 limited" },
  { value: "other", label: "其他 other" },
] as const;

export const SIZE_TYPES = [
  { value: "B1", label: "B1" },
  { value: "B2", label: "B2" },
  { value: "A3", label: "A3" },
  { value: "A4", label: "A4" },
  { value: "mini", label: "mini" },
  { value: "custom", label: "custom" },
  { value: "other", label: "other" },
] as const;

export const CHANNEL_CATEGORIES = [
  { value: "cinema", label: "影城 cinema" },
  { value: "distributor", label: "發行商 distributor" },
  { value: "lottery", label: "抽獎 lottery" },
  { value: "exhibition", label: "展覽 exhibition" },
  { value: "retail", label: "零售 retail" },
  { value: "other", label: "其他 other" },
] as const;
