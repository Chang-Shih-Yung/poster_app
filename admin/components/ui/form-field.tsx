import * as React from "react";
import { Label } from "./label";
import { cn } from "@/lib/utils";

/**
 * Single source of truth for "label + control + helper / error" rows.
 *
 * Conventions enforced here so individual forms can't drift:
 *   - Required: pass `required` → red asterisk auto-rendered after label
 *   - Optional: just leave `required` off — DO NOT write 「（選填）」
 *     in the label string. Absence of the asterisk is the convention.
 *   - Helper text: pass `helper` → muted hint below the control.
 *     Hidden when `error` is set (errors win the slot).
 *   - Errors: pass `error` → destructive-coloured message below.
 *
 * Density:
 *   - Default size matches PosterForm (full /posters/new page).
 *   - `size="compact"` matches DraftCard (batch grid, tighter rows).
 *
 * If you find yourself wanting another size or another slot, prefer
 * extending this component over inlining a parallel implementation.
 */
export type FormFieldProps = {
  /** The label text. Don't include 「（選填）」 — set `required` for *. */
  label: string;
  /** Required flag — adds a red `*` after the label. */
  required?: boolean;
  /** Optional muted hint shown when `error` is empty. */
  helper?: React.ReactNode;
  /** Validation error. Wins the helper slot when set. */
  error?: string;
  /** Pass-through className for the wrapper. */
  className?: string;
  /** "default" for full pages, "compact" for the batch grid. */
  size?: "default" | "compact";
  /** htmlFor on the label — wire up controls' id for a11y. */
  htmlFor?: string;
  children: React.ReactNode;
};

export function FormField({
  label,
  required,
  helper,
  error,
  className,
  size = "default",
  htmlFor,
  children,
}: FormFieldProps) {
  const labelClass = size === "compact" ? "text-xs" : undefined;
  const wrapperClass =
    size === "compact" ? "space-y-1" : "space-y-1.5";

  return (
    <div className={cn(wrapperClass, className)}>
      <Label htmlFor={htmlFor} className={labelClass}>
        {label}
        {required && (
          <span className="text-destructive ml-0.5" aria-hidden="true">
            *
          </span>
        )}
      </Label>
      {children}
      {error ? (
        <p className="text-xs text-destructive">{error}</p>
      ) : helper ? (
        <p className="text-xs text-muted-foreground">{helper}</p>
      ) : null}
    </div>
  );
}
