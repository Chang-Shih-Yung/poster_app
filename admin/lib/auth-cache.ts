import "server-only";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

/**
 * Per-request memoised Supabase server client + admin user lookup.
 *
 * Why:
 *   Without these, a single page render hit `auth.getUser()` two-to-four
 *   times — once in middleware, once in `<Nav>`, once in the page's own
 *   server component, and (for server actions) once in `requireAdmin`
 *   plus once more in `logAudit`. Each call validates the JWT against
 *   Supabase Auth, costing ~80-150ms apiece.
 *
 *   `cache()` from React 19 memoises the result for the duration of a
 *   single server render. Multiple callers within one request share the
 *   same client + user without re-hitting the Auth API. (Middleware
 *   runs in the Edge runtime so cannot share — that one call is
 *   unavoidable.)
 *
 * Usage: prefer `getCurrentUser()` over `supabase.auth.getUser()` in
 * any server component or server action that needs the user.
 */
export const getServerSupabase = cache(async () => {
  return await createClient();
});

export const getCurrentUser = cache(async () => {
  const supabase = await getServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});
