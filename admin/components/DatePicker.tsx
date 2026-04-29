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
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          className={cn(
            "w-full justify-start font-normal",
            !date && "text-muted-foreground",
            className
          )}
        >
          <CalendarIcon className="mr-2 h-4 w-4 shrink-0 opacity-70" />
          <span className="flex-1 text-left truncate">
            {date ? formatDisplay(date) : placeholder}
          </span>
          {date && !disabled && (
            <span
              role="button"
              aria-label="清除日期"
              className="ml-2 -mr-1 rounded p-0.5 opacity-60 hover:opacity-100 hover:bg-accent"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                onChange("");
              }}
            >
              <X className="h-3.5 w-3.5" />
            </span>
          )}
        </Button>
      </PopoverTrigger>
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
  );
}

/** "2026-04-29" → Date at local midnight (avoids the timezone-shift
 * pitfall where `new Date("2026-04-29")` parses as UTC and renders one
 * day off in negative-offset timezones). */
function parseLocalDate(s: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  const d = new Date(+m[1], +m[2] - 1, +m[3]);
  return isNaN(d.getTime()) ? null : d;
}

function toIsoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function formatDisplay(d: Date): string {
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`;
}
