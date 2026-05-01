import Link from "next/link";
import { getCurrentUser } from "@/lib/auth-cache";
import LogoutButton from "./LogoutButton";
import { ThemeToggle } from "./ThemeToggle";
import { Separator } from "./ui/separator";
import GlobalSearch from "./GlobalSearch";

export default async function Nav() {
  // Memoised per-request via lib/auth-cache. The page server component
  // and any sibling that also calls getCurrentUser share this result —
  // one JWT validation per render, not one per caller.
  const user = await getCurrentUser();

  return (
    <nav className="hidden md:flex items-center justify-between px-6 py-3 border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80 sticky top-0 z-30">
      <div className="flex items-center gap-4">
        <GlobalSearch />
        <Separator orientation="vertical" className="h-4" />
        <NavLink href="/tree">目錄</NavLink>
        <NavLink href="/works">所有作品</NavLink>
        <NavLink href="/posters">所有海報</NavLink>
        <NavLink href="/sets">套票</NavLink>
        <NavLink href="/upload-queue">待補圖</NavLink>
      </div>
      <div className="flex items-center gap-3">
        {user && (
          <span className="text-sm text-muted-foreground">{user.email}</span>
        )}
        <ThemeToggle />
        <LogoutButton variant="outline" withIcon={false} />
      </div>
    </nav>
  );
}

function NavLink({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className="text-sm text-muted-foreground hover:text-foreground hover:no-underline transition-colors"
    >
      {children}
    </Link>
  );
}
