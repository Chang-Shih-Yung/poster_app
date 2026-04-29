/**
 * Types and helpers shared between BatchImport and DraftCard.
 * Lives outside the React component file so unit tests can import
 * `newDraft` / `fromSentinel` without dragging the whole UI tree in.
 */

import { DEFAULT_REGION } from "@/lib/keys";

/** Sentinel for "no value" — Radix Select rejects empty-string values
 * so we use this token in form state and translate to null on submit. */
export const NONE = "__none__";

export type DraftStatus =
  | "idle"
  | "creating"
  | "uploading"
  | "done"
  | "error"
  | "image_failed"; // poster row created, image attach failed — important to surface

/**
 * Local-only representation of one card in the batch import grid.
 * Becomes a posters row + Storage upload on submit.
 */
/**
 * Aligned with collaborator's poster spec (2026-04-29). Changes vs old shape:
 *   - Removed: signed, numbered, edition_number, linen_backed, licensed
 *     (DB columns dropped in 20260429150000)
 *   - Added: cinema_release_types[], premium_format, cinema_name,
 *     custom_width, custom_height, size_unit, channel_note
 *   - poster_release_year (formerly `year`) is now REQUIRED — but DB column
 *     name stays `year` because Flutter app reads it
 */
export type DraftPoster = {
  localId: string;
  file: File;
  previewUrl: string;
  name: string;
  work_id: string;
  parent_group_id: string;
  year: string; // REQUIRED at submit (zod), maps to posters.year column
  poster_release_date: string;
  region: string; // REQUIRED — was sentinel-allowed, now defaults to TW
  poster_release_type: string;
  size_type: string; // REQUIRED
  channel_category: string; // REQUIRED
  channel_type: string;
  channel_name: string;
  // ── cinema-specific (channel_category=cinema) ─────────
  cinema_release_types: string[]; // multi-select array
  premium_format: string; // sentinel/value, only when cinema_release_types includes premium_format_limited
  cinema_name: string; // sentinel/value, only when channel_category=cinema
  // ── size CUSTOM-specific (size_type=custom) ───────────
  custom_width: string;  // numeric string, parsed at submit
  custom_height: string;
  size_unit: string; // sentinel/value
  // ── other ─────────────────────────────────────────────
  is_exclusive: boolean;
  exclusive_name: string;
  material_type: string;
  version_label: string;
  source_url: string;
  source_platform: string;
  source_note: string;
  channel_note: string;
  status: DraftStatus;
  errorMsg?: string;
  createdPosterId?: string;
};

export function newDraft(
  file: File,
  defaults: Partial<DraftPoster> = {}
): DraftPoster {
  return {
    localId: Math.random().toString(36).slice(2),
    file,
    previewUrl: URL.createObjectURL(file),
    name: "",
    work_id: defaults.work_id ?? "",
    parent_group_id: defaults.parent_group_id ?? NONE,
    year: defaults.year ?? "",
    poster_release_date: "",
    region: defaults.region ?? DEFAULT_REGION,
    poster_release_type: NONE,
    size_type: defaults.size_type ?? NONE,
    channel_category: defaults.channel_category ?? NONE,
    channel_type: NONE,
    channel_name: "",
    cinema_release_types: [],
    premium_format: NONE,
    cinema_name: NONE,
    custom_width: "",
    custom_height: "",
    size_unit: NONE,
    is_exclusive: false,
    exclusive_name: "",
    material_type: NONE,
    version_label: "",
    source_url: "",
    source_platform: NONE,
    source_note: "",
    channel_note: "",
    status: "idle",
  };
}

/** Translate a Select sentinel back to null/string for DB insert. */
export function fromSentinel(v: string): string | null {
  return v === NONE ? null : v || null;
}

/** Mirror of the validation rule used by the UI. Required per collaborator's
 * spec: name, work, year, region, size_type, channel_category. CUSTOM size
 * additionally requires width + height + unit; that detailed check lives in
 * the form's zod schema, not here — this gate is the coarser "card is
 * submittable" filter for the batch-submit flow. */
export function isReady(d: DraftPoster): boolean {
  if (d.status !== "idle") return false;
  if (!d.name.trim() || !d.work_id) return false;
  // year must be a 1900-2100 integer string
  const yearOk = /^\d+$/.test(d.year.trim()) && +d.year >= 1900 && +d.year <= 2100;
  if (!yearOk) return false;
  if (!d.region) return false;
  if (!d.size_type || d.size_type === NONE) return false;
  if (!d.channel_category || d.channel_category === NONE) return false;
  // CUSTOM size needs the trio
  if (d.size_type === "custom") {
    if (!d.custom_width.trim() || !d.custom_height.trim()) return false;
    if (!d.size_unit || d.size_unit === NONE) return false;
  }
  return true;
}

/** Detect HEIC/HEIF input (mime, mime variant, or extension fallback for
 * browsers that don't set type). HEIC is iPhone's default still format. */
export function isHeic(file: File): boolean {
  return (
    file.type === "image/heic" ||
    file.type === "image/heif" ||
    /\.(heic|heif)$/i.test(file.name)
  );
}

/** Hard rejections at file-pick time. HEIC is no longer here — we now
 * convert it client-side via heic2any (see BatchImport.addFiles). */
export function rejectionReason(file: File): string | null {
  if (file.size === 0) return "檔案大小為 0，無法上傳";
  if (file.size > 50 * 1024 * 1024) {
    return `檔案太大（${Math.round(file.size / 1024 / 1024)}MB），上限 50MB`;
  }
  // HEIC bypasses the type check below — it'll be converted to JPEG.
  if (isHeic(file)) return null;
  if (!file.type.startsWith("image/")) {
    return `不支援的檔案類型：${file.type || "未知"}`;
  }
  return null;
}

/**
 * Promise.all with a concurrency limit. Useful for batch uploads where
 * 60 parallel requests would (a) saturate the user's bandwidth and
 * (b) trip Supabase rate limits.
 *
 * Mapper is expected to handle its own errors — exceptions propagate
 * and abort the whole batch, which is usually NOT what callers want.
 * BatchImport's submit logic wraps each mapper invocation in try/catch.
 */
export async function pMap<T, R>(
  items: readonly T[],
  mapper: (item: T, index: number) => Promise<R>,
  concurrency: number
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  if (items.length === 0) return results;
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const i = cursor++;
      results[i] = await mapper(items[i], i);
    }
  }
  const workers = Array.from(
    { length: Math.min(Math.max(1, concurrency), items.length) },
    () => worker()
  );
  await Promise.all(workers);
  return results;
}
