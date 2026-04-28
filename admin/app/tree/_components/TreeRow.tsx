"use client";

import Link from "next/link";
import { Folder, FileImage, MoreVertical, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * One Drive-style row. Body is a navigation link (or a plain div for
 * leaf posters that route elsewhere), the trailing ⋯ button is a
 * separate clickable element so it doesn't trigger navigation.
 *
 * The kind chip + count line keeps text dense without hiding info.
 */
export default function TreeRow({
  href,
  thumbnailUrl,
  kind,
  title,
  subtitle,
  count,
  countLabel,
  badge,
  placeholder,
  onMore,
}: {
  /** Where tapping the row body navigates. */
  href: string;
  /** Folder rows show a folder icon; poster rows show a thumbnail (or
   * a generic image icon when no thumbnail yet). */
  kind: "folder" | "poster";
  thumbnailUrl?: string | null;
  title: string;
  subtitle?: string;
  /** Item count for folders; omit for posters. */
  count?: number;
  countLabel?: string;
  /** Small chip after the title — work kind, group type etc. */
  badge?: string;
  /** Amber "待補圖" hint for placeholder posters. */
  placeholder?: boolean;
  /** Click handler for the trailing ⋯ button. Stops propagation so the
   * row's link doesn't fire. */
  onMore: () => void;
}) {
  const Body = (
    <div className="flex items-center gap-3 flex-1 min-w-0">
      <span className="shrink-0 flex items-center justify-center">
        {kind === "folder" ? (
          <span className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-muted-foreground">
            <Folder className="w-5 h-5" strokeWidth={1.75} />
          </span>
        ) : thumbnailUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={thumbnailUrl}
            alt=""
            className="w-10 h-12 rounded object-cover border border-border"
          />
        ) : (
          <span className="w-10 h-12 rounded bg-secondary flex items-center justify-center text-muted-foreground border border-border">
            <FileImage className="w-5 h-5" strokeWidth={1.75} />
          </span>
        )}
      </span>
      <span className="flex-1 min-w-0">
        <span className="flex items-center gap-2">
          <span className="text-base text-foreground truncate">{title}</span>
          {badge && (
            <span className="shrink-0 text-[10px] tracking-wide px-1.5 py-0.5 rounded bg-secondary text-muted-foreground">
              {badge}
            </span>
          )}
        </span>
        {(subtitle || count != null || placeholder) && (
          <span
            className={cn(
              "block text-xs truncate mt-0.5",
              placeholder ? "text-amber-500 dark:text-amber-400" : "text-muted-foreground"
            )}
          >
            {subtitle && <span>{subtitle}</span>}
            {subtitle && count != null && <span> · </span>}
            {count != null && (
              <span>
                {count} {countLabel ?? "項"}
              </span>
            )}
            {placeholder && (subtitle || count != null) && <span> · </span>}
            {placeholder && <span>待補圖</span>}
          </span>
        )}
      </span>
    </div>
  );

  return (
    <li className="rounded-xl border border-border bg-card hover:bg-secondary/50 transition-colors">
      <div className="flex items-center pr-1">
        <Link
          href={href}
          className="flex-1 min-w-0 flex items-center gap-2 px-3 py-3 hover:no-underline"
        >
          {Body}
          {kind === "folder" && (
            <ChevronRight className="w-4 h-4 shrink-0 text-muted-foreground" />
          )}
        </Link>
        <button
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            onMore();
          }}
          className="shrink-0 w-10 h-10 flex items-center justify-center rounded-md text-muted-foreground hover:text-foreground hover:bg-secondary"
          title="更多選項"
          aria-label="更多選項"
        >
          <MoreVertical className="w-5 h-5" />
        </button>
      </div>
    </li>
  );
}
