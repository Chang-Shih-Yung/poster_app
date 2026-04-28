/**
 * Supabase / Postgrest errors are NOT Error instances — they're plain
 * objects with `.message`, `.code`, `.details`, `.hint`. Naively calling
 * String() on them produces "[object Object]". This pulls out the most
 * useful human-readable string we can find. Used in every mutation site
 * (forms, action sheets, server actions) so failures surface uniformly.
 */
export function describeError(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === "string") return e;
  if (e && typeof e === "object") {
    const obj = e as Record<string, unknown>;
    const parts: string[] = [];
    if (typeof obj.message === "string") parts.push(obj.message);
    if (typeof obj.details === "string") parts.push(obj.details);
    if (typeof obj.hint === "string") parts.push(`hint: ${obj.hint}`);
    if (typeof obj.code === "string") parts.push(`code: ${obj.code}`);
    if (parts.length > 0) return parts.join(" · ");
    try {
      return JSON.stringify(e);
    } catch {
      return "(unknown error)";
    }
  }
  return String(e);
}
