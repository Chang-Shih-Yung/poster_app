"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";

/**
 * Mobile-only top header. Larger touch targets, single title, optional
 * back button + actions. Hidden on md+ screens (desktop uses the
 * existing Nav component).
 */
export default function MobileHeader({
  title,
  showBack = false,
  action,
}: {
  title: string;
  showBack?: boolean;
  action?: React.ReactNode;
}) {
  const router = useRouter();

  return (
    <header
      className="md:hidden sticky top-0 z-40 bg-bg border-b border-line1 flex items-center justify-between px-3"
      style={{ paddingTop: "env(safe-area-inset-top)" }}
    >
      <div className="flex items-center gap-2 min-h-[52px] flex-1">
        {showBack ? (
          <button
            onClick={() => router.back()}
            className="p-2 -ml-2 min-w-[44px] min-h-[44px] flex items-center justify-center text-text"
            aria-label="返回"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
        ) : (
          <Link href="/" className="p-2 -ml-2 min-w-[44px] min-h-[44px] flex items-center font-semibold text-text hover:no-underline">
            Poster.
          </Link>
        )}
        <h1 className="text-base font-semibold truncate">{title}</h1>
      </div>
      {action && <div className="flex items-center">{action}</div>}
    </header>
  );
}
