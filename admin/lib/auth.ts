/**
 * Email-whitelist check shared between the page-level middleware and
 * server actions. Source of truth is the comma-separated `ADMIN_EMAILS`
 * environment variable. Comparison is lower-cased + trimmed so
 * `"Henry@gmail.com"` matches `"henry@gmail.com"`.
 */
export function isAdminEmail(email: string | undefined | null): boolean {
  if (!email) return false;
  const whitelist = (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return whitelist.includes(email.toLowerCase());
}
