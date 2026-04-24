import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

/**
 * OAuth callback — Supabase Auth hits this after Google redirects back.
 * We exchange the `code` for a session (writes cookie), then redirect
 * to the dashboard. The middleware's admin-whitelist check kicks in on
 * the next request, so if the user isn't whitelisted they'll land at
 * /unauthorized immediately.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  if (code) {
    const supabase = await createClient();
    await supabase.auth.exchangeCodeForSession(code);
  }

  return NextResponse.redirect(`${origin}/`);
}
