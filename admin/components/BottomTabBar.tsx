"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, FolderTree, Upload, MoreHorizontal } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * Mobile-only bottom tab bar. Hidden on md+ (desktop uses the top Nav
 * instead). Fixed to bottom with safe-area padding so it sits above the
 * iPhone home indicator.
 */
export default function BottomTabBar() {
  const pathname = usePathname();

  const tabs: { href: string; label: string; icon: LucideIcon }[] = [
    { href: "/", label: "總覽", icon: Home },
    { href: "/tree", label: "目錄", icon: FolderTree },
    { href: "/upload-queue", label: "待補圖", icon: Upload },
    { href: "/more", label: "更多", icon: MoreHorizontal },
  ];

  return (
    <nav
      className="md:hidden fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <div className="flex justify-around">
        {tabs.map((t) => {
          const active =
            t.href === "/" ? pathname === "/" : pathname.startsWith(t.href);
          const Icon = t.icon;
          return (
            <Link
              key={t.href}
              href={t.href}
              className={cn(
                "flex flex-col items-center justify-center py-2 px-3 min-w-[60px] min-h-[56px] transition-colors hover:no-underline",
                active
                  ? "text-foreground"
                  : "text-muted-foreground hover:text-foreground"
              )}
            >
              <Icon className="w-5 h-5 mb-0.5" />
              <span className="text-[10px] font-medium">{t.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
