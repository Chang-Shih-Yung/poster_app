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
export type DraftPoster = {
  localId: string;
  file: File;
  previewUrl: string;
  name: string;
  work_id: string;
  parent_group_id: string;
  year: string;
  poster_release_date: string;
  region: string;
  poster_release_type: string;
  size_type: string;
  channel_category: string;
  channel_type: string;
  channel_name: string;
  is_exclusive: boolean;
  exclusive_name: string;
  material_type: string;
  version_label: string;
  source_url: string;
  source_platform: string;
  source_note: string;
  signed: boolean;
  numbered: boolean;
  edition_number: string;
  linen_backed: boolean;
  licensed: boolean;
  status: DraftStatus;
  errorMsg?: string;
  /** Set when status === "image_failed" so the user can be told the
   * row exists and pointed to /posters to retry the upload. */
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
    is_exclusive: false,
    exclusive_name: "",
    material_type: NONE,
    version_label: "",
    source_url: "",
    source_platform: NONE,
    source_note: "",
    signed: false,
    numbered: false,
    edition_number: "",
    linen_backed: false,
    licensed: true,
    status: "idle",
  };
}

/** Translate a Select sentinel back to null/string for DB insert. */
export function fromSentinel(v: string): string | null {
  return v === NONE ? null : v || null;
}

/** Mirror of the validation rule used by the UI: a draft is "ready"
 * when it's idle and has the two required fields filled in. */
export function isReady(d: DraftPoster): boolean {
  return d.status === "idle" && !!d.name.trim() && !!d.work_id;
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
