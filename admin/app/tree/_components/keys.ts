/**
 * "未分類" is a UI-only bucket — it represents works whose `studio`
 * column is NULL. We use this sentinel string everywhere outside the
 * database; whoever talks to Supabase translates it back to NULL.
 */
export const NULL_STUDIO_KEY = "(未分類)";

export function encodeStudioParam(studio: string) {
  return encodeURIComponent(studio);
}

export function decodeStudioParam(param: string) {
  return decodeURIComponent(param);
}
