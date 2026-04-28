"use client";

import Link from "next/link";
import { Folder, FileImage, MoreVertical, GripVertical } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * One Drive-style row. Body is a navigation link (or a plain div for
 * leaf posters that route elsewhere), the trailing ⋯ button is a
 * separate clickable element so it doesn't trigger navigation.
 *
 * Optional drag-and-drop props let the parent (WorkClient / GroupClient)
 * attach @dnd-kit handles without duplicating layout logic.
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
  // DnD support
  innerRef,
  dragListeners,
  dragAttributes,
  isDragging,
  isDropTarget,
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
  // Optional DnD props
  /** Callback ref from useDraggable/useDroppable to attach to the <li>. */
  innerRef?: (node: HTMLLIElement | null) => void;
  /** Event listeners from useDraggable – spread on the drag handle button. */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  dragListeners?: Record<string, any>;
  /** Aria/data attributes from useDraggable. */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  dragAttributes?: Record<string, any>;
  /** True while this item is being dragged — dims the row. */
  isDragging?: boolean;
  /** True when another item is being dragged over this row. */
  isDropTarget?: boolean;
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
    <li
      ref={innerRef}
      className={cn(
        "rounded-xl border bg-card transition-all duration-150",
        isDragging
          ? "opacity-30 border-border"
          : isDropTarget
          ? "border-primary ring-2 ring-primary ring-offset-1 bg-primary/5"
          : "border-border"
      )}
    >
      <div className="flex items-center pr-1">
        {/* Drag handle — only rendered when dragListeners are provided */}
        {dragListeners && (
          <button
            {...dragListeners}
            {...dragAttributes}
            className="shrink-0 w-8 h-12 flex items-center justify-center text-muted-foreground/40 hover:text-muted-foreground touch-none cursor-grab active:cursor-grabbing transition-colors"
            aria-label="拖移"
            tabIndex={-1}
            onClick={(e) => e.stopPropagation()}
          >
            <GripVertical className="w-4 h-4" />
          </button>
        )}
        <Link
          href={href}
          className="flex-1 min-w-0 flex items-center gap-2 px-3 py-3 hover:no-underline"
          style={{ paddingLeft: dragListeners ? "4px" : undefined }}
        >
          {Body}
        </Link>
        <button
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            onMore();
          }}
          className="shrink-0 w-11 h-11 flex items-center justify-center rounded-md text-muted-foreground hover:text-foreground transition-colors"
          title="更多選項"
          aria-label="更多選項"
        >
          <MoreVertical className="w-5 h-5" />
        </button>
      </div>
    </li>
  );
}
