"use client";

import { createBrowserClient } from "@supabase/ssr";

/**
 * Supabase client for browser components. Uses the anon key — every write
 * still goes through RLS, so the admin's users.role + email whitelist both
 * gate operations.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
