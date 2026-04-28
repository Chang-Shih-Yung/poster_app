"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * Mobile-style action menu rendered inside a bottom Sheet — each row
 * is icon + label, tappable, with optional destructive styling. Looks
 * like the Drive "三個點 → menu" pattern.
 */
export type SheetMenuItem = {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  destructive?: boolean;
  disabled?: boolean;
  hint?: string;
};

export function SheetMenuList({ items }: { items: SheetMenuItem[] }) {
  return (
    <ul className="divide-y divide-border">
      {items.map((it, i) => (
        <li key={i}>
          <button
            onClick={() => {
              if (it.disabled) return;
              it.onClick();
            }}
            disabled={it.disabled}
            className={cn(
              "w-full flex items-center gap-4 py-3.5 px-1 text-left transition-colors",
              "disabled:opacity-50",
              it.destructive
                ? "text-destructive"
                : "text-foreground hover:text-foreground"
            )}
          >
            <span
              className={cn(
                "w-9 h-9 shrink-0 flex items-center justify-center rounded-md",
                it.destructive
                  ? "bg-destructive/10 text-destructive"
                  : "bg-secondary text-muted-foreground"
              )}
            >
              {it.icon}
            </span>
            <span className="flex-1 min-w-0">
              <span className="block text-sm font-medium truncate">
                {it.label}
              </span>
              {it.hint && (
                <span className="block text-xs text-muted-foreground truncate">
                  {it.hint}
                </span>
              )}
            </span>
          </button>
        </li>
      ))}
    </ul>
  );
}
