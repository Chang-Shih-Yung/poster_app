"use client";

import * as React from "react";
import { CalendarIcon, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

/**
 * Date picker that talks in `YYYY-MM-DD` strings (Postgres-friendly,
 * matches the DB `date` columns) but shows a localized human format in
 * the trigger.
 *
 * Why not just `<input type="date">`?
 *   - On desktop browsers it's an inconsistent native widget that
 *     doesn't match the theme (light dropdown on a dark form is ugly,
 *     see screenshot).
 *   - No way to put a "clear" button in the native widget — admins had
 *     to clear the field manually.
 *
 * The trigger button is meant to drop into the same `h-9` slot as our
 * other form inputs.
 */
export function DatePicker({
  value,
  onChange,
  placeholder = "年 / 月 / 日",
  disabled,
  className,
}: {
  /** YYYY-MM-DD or "" (empty means no date selected). */
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}) {
  const [open, setOpen] = React.useState(false);
  const date = parseLocalDate(value);

  return (
    // The trigger and the clear button are siblings, not nested — a
    // <button> inside a <button> is invalid HTML and breaks keyboard
    // a11y in some screen readers. We use `relative` on the wrapper +
    // `absolute` on the clear button so the layout looks the same.
    <div className={cn("relative w-full", className)}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            type="button"
            variant="outline"
            disabled={disabled}
            className={cn(
              "w-full justify-start font-normal",
              !date && "text-muted-foreground",
              date && !disabled && "pr-9" // leave room for the X button
            )}
          >
            <CalendarIcon className="mr-2 h-4 w-4 shrink-0 opacity-70" />
            <span className="flex-1 text-left truncate">
              {date ? formatDisplay(date) : placeholder}
            </span>
          </Button>
        </PopoverTrigger>
        {date && !disabled && (
          <button
            type="button"
            aria-label="清除日期"
            onClick={() => onChange("")}
            className="absolute right-1 top-1/2 -translate-y-1/2 rounded p-1 opacity-60 hover:opacity-100 hover:bg-accent z-10"
          >
            <X className="h-3.5 w-3.5" />
          </button>
        )}
        <PopoverContent align="start" className="p-0 w-auto">
          <Calendar
            mode="single"
            selected={date ?? undefined}
            captionLayout="dropdown"
            startMonth={new Date(1900, 0)}
            endMonth={new Date(2100, 11)}
            defaultMonth={date ?? new Date()}
            onSelect={(d) => {
              if (d) {
                onChange(toIsoDate(d));
                setOpen(false);
              } else {
                onChange("");
              }
            }}
            autoFocus
          />
        </PopoverContent>
      </Popover>
    </div>
  );
}

/**
 * "2026-04-29" → Date at LOCAL midnight.
 *
 * Why: `new Date("2026-04-29")` is parsed as UTC midnight by the JS
 * engine. In any timezone west of UTC the resulting Date renders as
 * the day BEFORE (e.g. Apr 28 in PT). Splitting the string and using
 * the `Date(y, m, d)` constructor guarantees local midnight regardless
 * of timezone. This is the timezone-shift bug that bites every
 * `<input type="date">` migration.
 *
 * Returns `null` for empty / malformed / out-of-range inputs.
 *
 * Exported for testing — see DatePicker.test.tsx.
 */
export function parseLocalDate(s: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  const year = +m[1];
  const month = +m[2];
  const day = +m[3];
  // Reject obviously invalid components (e.g. month 13, day 32) — the
  // Date constructor would silently roll over otherwise.
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const d = new Date(year, month - 1, day);
  // Catch the rollover case (e.g. Feb 30 → Mar 2).
  if (
    d.getFullYear() !== year ||
    d.getMonth() !== month - 1 ||
    d.getDate() !== day
  ) {
    return null;
  }
  return d;
}

/** Date → "YYYY-MM-DD" using the LOCAL date components (mirrors
 * `parseLocalDate` so a roundtrip is identity). Exported for testing. */
export function toIsoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function formatDisplay(d: Date): string {
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`;
}
