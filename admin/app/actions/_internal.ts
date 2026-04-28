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

/**
 * Append a row to admin_audit_log. Designed to be cheap fire-and-forget
 * so a slow audit insert never delays the actual mutation result. We
 * deliberately swallow audit errors (logged to server console) rather
 * than fail the user-visible action: the migration just landed, the
 * user changed the studio name, that's the important part.
 *
 * Call this from inside server actions for destructive / inspectable
 * operations (deletes, renames, schema-bulk updates, image attaches).
 * The server console gets the trail too in case the table write fails.
 */
export async function logAudit(opts: {
  action: string;
  target_kind: "work" | "poster" | "group" | "studio" | "image";
  target_id?: string | null;
  payload?: Record<string, unknown> | null;
}) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error } = await supabase.from("admin_audit_log").insert({
      admin_user_id: user.id,
      admin_email: user.email ?? null,
      action: opts.action,
      target_kind: opts.target_kind,
      target_id: opts.target_id ?? null,
      payload: opts.payload ?? null,
    });
    if (error) {
      // Don't fail the calling action — log + move on.
      console.warn("[audit] failed to write log:", error.message);
    }
  } catch (e) {
    console.warn("[audit] threw:", e);
  }
}
