import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { isAdminEmail } from "@/lib/auth";

/**
 * Session refresh + admin gate for every request.
 *
 * Steps:
 *   1. Refresh the Supabase auth session (cookie rotation).
 *   2. If there's no user, redirect anything except /login and /auth/callback
 *      to /login.
 *   3. If there IS a user but their email isn't in the admin whitelist,
 *      kick to /unauthorized.
 *
 * The whitelist is a belt-and-braces check. RLS on the DB is the real gate;
 * this is just so random Google-logged-in people don't see the admin UI.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // IMPORTANT: do not run any logic between `createServerClient` and
  // `getUser()`. See Supabase SSR docs.
  const { data: { user } } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const isPublic =
    pathname.startsWith("/login") ||
    pathname.startsWith("/auth") ||
    pathname.startsWith("/unauthorized") ||
    pathname.startsWith("/_next") ||
    pathname === "/favicon.ico";

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && !isAdminEmail(user.email)) {
    // Logged in but not whitelisted.
    if (!pathname.startsWith("/unauthorized") && !pathname.startsWith("/auth")) {
      const url = request.nextUrl.clone();
      url.pathname = "/unauthorized";
      return NextResponse.redirect(url);
    }
  }

  return response;
}
