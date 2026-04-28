"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { Button } from "./ui/button";
import { ThemeToggle } from "./ThemeToggle";

/**
 * Mobile-only top header. Optional back chevron + parent label
 * (breadcrumb-style) and a theme toggle on the right. Pages may pass
 * `action` for page-specific buttons (rendered before the toggle).
 */
export default function MobileHeader({
  title,
  back,
  action,
}: {
  title: string;
  /** Either a breadcrumb pointing to a parent page, or simply
   * `true`/`false` for the legacy "use router.back()" behaviour. */
  back?: { href: string; label: string } | boolean;
  action?: React.ReactNode;
}) {
  const router = useRouter();

  const showBack = !!back;
  const breadcrumb =
    back && typeof back === "object" ? back : null;

  return (
    <header
      className="md:hidden sticky top-0 z-40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80 border-b border-border flex items-center px-2"
      style={{ paddingTop: "env(safe-area-inset-top)" }}
    >
      <div className="flex items-center gap-1 min-h-[52px] flex-1 min-w-0">
        {showBack ? (
          breadcrumb ? (
            <Link
              href={breadcrumb.href}
              className="group flex items-center gap-1 px-2 -ml-1 min-h-[44px] hover:no-underline"
              aria-label={`返回 ${breadcrumb.label}`}
            >
              <ChevronLeft className="w-5 h-5 text-muted-foreground group-hover:text-foreground transition-colors" />
              <span className="text-sm text-muted-foreground group-hover:text-foreground max-w-[140px] truncate transition-colors">
                {breadcrumb.label}
              </span>
            </Link>
          ) : (
            <Button
              variant="quiet"
              size="icon"
              onClick={() => router.back()}
              aria-label="返回"
            >
              <ChevronLeft className="w-5 h-5" />
            </Button>
          )
        ) : (
          <Link
            href="/"
            className="px-3 min-h-[44px] flex items-center font-semibold text-foreground hover:no-underline"
          >
            Poster.
          </Link>
        )}
        <h1 className="text-base font-semibold truncate ml-1">{title}</h1>
      </div>
      <div className="flex items-center gap-1">
        {action}
        <ThemeToggle />
      </div>
    </header>
  );
}
