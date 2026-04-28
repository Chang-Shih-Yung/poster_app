import "server-only";

import { createClient } from "@/lib/supabase/server";
import { isAdminEmail } from "@/lib/auth";
import { describeError } from "@/lib/errors";

/**
 * Discriminated union for every server action's return value. Server
 * actions never throw to the client — they catch internally and surface
 * `{ ok: false, error }` so the caller can render the message inline
 * (in a Sheet, on a row, etc.) without wrestling with thrown errors
 * crossing the RSC boundary.
 */
export type ActionResult<T = void> =
  | { ok: true; data: T }
  | { ok: false; error: string };

/**
 * Authorize + return a server-side Supabase client. Every mutation
 * action calls this first so RLS isn't the only line of defense:
 *
 *   1. Read the auth cookie via the server client.
 *   2. Confirm the user's email is in ADMIN_EMAILS.
 *   3. Return the same client so the caller can run queries on it.
 *
 * If either check fails we throw — the caller's try/catch turns it
 * into `{ ok: false }`. We deliberately do NOT swallow the error here;
 * each action should report a useful message at its call site.
 */
export async function requireAdmin() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("尚未登入或 session 已失效");
  if (!isAdminEmail(user.email)) throw new Error("沒有管理權限");
  return { supabase, user };
}

export function ok<T>(data: T): ActionResult<T> {
  return { ok: true, data };
}

export function fail(e: unknown): ActionResult<never> {
  return { ok: false, error: describeError(e) };
}
