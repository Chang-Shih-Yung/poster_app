import "server-only";

import type { SupabaseClient, User } from "@supabase/supabase-js";
import { getServerSupabase, getCurrentUser } from "@/lib/auth-cache";
import { isAdminEmail } from "@/lib/auth";
import { describeError } from "@/lib/errors";

export type ActionResult<T = void> =
  | { ok: true; data: T }
  | { ok: false; error: string };

/**
 * Authorize + return a server-side Supabase client. Every mutation
 * action calls this first so RLS isn't the only line of defense.
 *
 * Both `getServerSupabase` and `getCurrentUser` are wrapped in React
 * `cache()`, so within a single request `requireAdmin` and any sibling
 * caller (`logAudit`, etc.) share the same client + user. One JWT
 * validation per action invocation, not one per helper.
 */
export async function requireAdmin(): Promise<{
  supabase: SupabaseClient;
  user: User;
}> {
  const supabase = await getServerSupabase();
  const user = await getCurrentUser();
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
 * Append a row to admin_audit_log. Takes the supabase client and user
 * from the calling action's `requireAdmin` so the audit write doesn't
 * trigger a second JWT validation round-trip — that used to add
 * ~100ms to every mutation.
 *
 * Audit failures are swallowed: a slow audit insert never blocks the
 * user-visible action. Failures still log to the server console for
 * debugging.
 *
 * Call this from inside server actions for destructive / inspectable
 * operations (deletes, renames, kind-changes, image attaches, bulk
 * studio updates).
 */
export async function logAudit(
  supabase: SupabaseClient,
  user: User | null,
  opts: {
    action: string;
    target_kind: "work" | "poster" | "group" | "studio" | "image" | "poster_set";
    target_id?: string | null;
    payload?: Record<string, unknown> | null;
  }
) {
  if (!user) return;
  try {
    const { error } = await supabase.from("admin_audit_log").insert({
      admin_user_id: user.id,
      admin_email: user.email ?? null,
      action: opts.action,
      target_kind: opts.target_kind,
      target_id: opts.target_id ?? null,
      payload: opts.payload ?? null,
    });
    if (error) {
      console.warn("[audit] failed to write log:", error.message);
    }
  } catch (e) {
    console.warn("[audit] threw:", e);
  }
}
