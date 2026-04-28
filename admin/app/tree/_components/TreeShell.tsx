"use client";

import Link from "next/link";
import { ChevronLeft } from "lucide-react";
import { ThemeToggle } from "@/components/ThemeToggle";
import BottomTabBar from "@/components/BottomTabBar";

/**
 * Shell for /tree pages — handles theme tokens, the breadcrumb-back
 * header, and the bottom tab bar. Each page passes its own list body
 * + FAB. Distinct from PageShell because tree pages need a parent-
 * folder breadcrumb in the back button instead of a static title.
 */
export default function TreeShell({
  nav,
  back,
  title,
  subtitle,
  fab,
  children,
}: {
  /** Server-rendered desktop Nav, passed in by the page. Hidden on
   * mobile via Nav's own classes. */
  nav?: React.ReactNode;
  /** Where the back chevron points to. `null` means we're at the root
   * and no back arrow is shown. */
  back: { href: string; label: string } | null;
  /** Current folder name. */
  title: string;
  /** Optional second line — e.g. English title, work kind, or an item
   * count summary. */
  subtitle?: string;
  /** Floating Action Button — usually a + that opens an add-item sheet.
   * Rendered fixed bottom-right above the tab bar. */
  fab?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background text-foreground">
      {nav}
      <header
        className="md:hidden sticky top-0 z-40 bg-background/95 backdrop-blur border-b border-border"
        style={{ paddingTop: "env(safe-area-inset-top)" }}
      >
        <div className="flex items-center gap-1 px-2 py-2 max-w-3xl mx-auto">
          {back ? (
            <Link
              href={back.href}
              className="flex items-center gap-1 min-h-[44px] px-2 -ml-1 rounded-md text-foreground hover:no-underline group"
              aria-label={`返回 ${back.label}`}
            >
              <ChevronLeft className="w-5 h-5 text-muted-foreground group-hover:text-foreground transition-colors" />
              <span className="text-sm text-muted-foreground group-hover:text-foreground max-w-[180px] truncate transition-colors">
                {back.label}
              </span>
            </Link>
          ) : (
            // Match every other mobile header: when there's no parent
            // to go back to, the leading slot is the brand mark linking
            // home, not a redundant "目錄" label (the page H1 already
            // says "目錄").
            <Link
              href="/"
              className="px-3 min-h-[44px] flex items-center font-semibold text-foreground hover:no-underline"
            >
              Poster.
            </Link>
          )}
          <div className="flex-1" />
          <ThemeToggle />
        </div>
        <div className="px-4 pt-1 pb-3 max-w-3xl mx-auto">
          <h1 className="text-2xl font-semibold tracking-tight truncate">
            {title}
          </h1>
          {subtitle && (
            <p className="text-sm text-muted-foreground mt-0.5 truncate">
              {subtitle}
            </p>
          )}
        </div>
      </header>

      {/* Desktop title block — Nav already handles the breadcrumb back
       * via its link bar, so we only need the page heading here. */}
      <div className="hidden md:block max-w-3xl mx-auto px-6 pt-8 pb-4">
        {back && (
          <Link
            href={back.href}
            className="group inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground hover:no-underline mb-2 transition-colors"
          >
            <ChevronLeft className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
            {back.label}
          </Link>
        )}
        <h1 className="text-2xl font-semibold tracking-tight truncate">
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm text-muted-foreground mt-1 truncate">
            {subtitle}
          </p>
        )}
      </div>

      <main className="max-w-3xl mx-auto px-3 sm:px-4 py-3 pb-32 md:px-6">
        {children}
      </main>

      {fab && (
        <div
          className="fixed right-4 z-40 md:right-8"
          style={{ bottom: "calc(env(safe-area-inset-bottom) + 80px)" }}
        >
          {fab}
        </div>
      )}

      <BottomTabBar />
    </div>
  );
}
