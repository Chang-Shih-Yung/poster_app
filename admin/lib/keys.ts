/**
 * App-wide string sentinels and default values that have to match
 * across multiple call sites (`/works`, `/posters`, `/tree`, server
 * actions, audit log payload). Centralising them here is the single
 * source of truth — change once, not seven times.
 */

/**
 * Pseudo-studio for works whose `studio` column is NULL. Used in the
 * UI bucket grouping and in URLs (`/tree/studio/(未分類)`). The
 * server actions translate this back to NULL on the way to the DB.
 */
export const NULL_STUDIO_KEY = "(未分類)";

/**
 * Display label for a poster row that has no `poster_name`. Shown in
 * lists, action sheet titles, and confirm() messages.
 */
export const UNNAMED_POSTER = "(未命名)";

/**
 * Display label for a work's poster slot that has no real image
 * uploaded yet (poster_url IS NULL or is_placeholder=true).
 */
export const PLACEHOLDER_LABEL = "待補圖";

/**
 * Default region for new posters. Most of the catalogue is Taiwan
 * theatrical releases, so TW is the right starting point. Override
 * via the form's region select per poster.
 */
export const DEFAULT_REGION = "TW";

/* ─────────────── URL param helpers ─────────────── */

export function encodeStudioParam(studio: string) {
  return encodeURIComponent(studio);
}

export function decodeStudioParam(param: string) {
  return decodeURIComponent(param);
}
