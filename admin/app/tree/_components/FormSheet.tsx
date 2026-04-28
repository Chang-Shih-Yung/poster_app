"use client";

import * as React from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2, AlertTriangle } from "lucide-react";
import { describeError } from "@/lib/errors";

/**
 * Reusable bottom-sheet form. Handles the visual chrome (header, fields,
 * submit / cancel) so each level only specifies its own fields. The
 * sheet auto-focuses the first input on open.
 */
export type FormField =
  | {
      key: string;
      kind: "text";
      label: string;
      placeholder?: string;
      initialValue?: string;
      required?: boolean;
      helper?: string;
    }
  | {
      key: string;
      kind: "select";
      label: string;
      options: { value: string; label: string }[];
      initialValue?: string;
    };

export function FormSheet({
  open,
  onOpenChange,
  title,
  description,
  fields,
  submitLabel = "確認",
  onSubmit,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: string;
  description?: string;
  fields: FormField[];
  submitLabel?: string;
  onSubmit: (values: Record<string, string>) => Promise<void> | void;
}) {
  const [values, setValues] = React.useState<Record<string, string>>({});
  const [busy, setBusy] = React.useState(false);
  const [errorMsg, setErrorMsg] = React.useState<string | null>(null);

  // Re-seed defaults whenever the sheet opens (different rows reuse the
  // same component instance).
  React.useEffect(() => {
    if (open) {
      const next: Record<string, string> = {};
      for (const f of fields) {
        next[f.key] = f.initialValue ?? "";
      }
      setValues(next);
      setErrorMsg(null);
    }
  }, [open, fields]);

  function update(key: string, v: string) {
    setValues((prev) => ({ ...prev, [key]: v }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    // Trim text fields and reject if any required text field is empty.
    for (const f of fields) {
      if (f.kind === "text" && f.required && !values[f.key]?.trim()) return;
    }
    setBusy(true);
    setErrorMsg(null);
    try {
      const trimmed: Record<string, string> = {};
      for (const f of fields) {
        const raw = values[f.key] ?? "";
        trimmed[f.key] = f.kind === "text" ? raw.trim() : raw;
      }
      await onSubmit(trimmed);
      onOpenChange(false);
    } catch (e) {
      setErrorMsg(describeError(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        className="max-h-[85vh] overflow-y-auto"
        // Radix Dialog warns when neither a Description child nor an
        // explicit aria-describedby is set. Forms without a description
        // (e.g. simple rename) opt out by passing undefined explicitly.
        {...(description ? {} : { "aria-describedby": undefined })}
      >
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>
        <form onSubmit={handleSubmit} className="mt-4 space-y-4">
          {fields.map((f) => (
            <div key={f.key} className="space-y-1.5">
              <Label htmlFor={f.key}>{f.label}</Label>
              {f.kind === "text" ? (
                <Input
                  id={f.key}
                  // First text field gets autofocus.
                  autoFocus={fields.find((x) => x.kind === "text")?.key === f.key}
                  placeholder={f.placeholder}
                  value={values[f.key] ?? ""}
                  onChange={(e) => update(f.key, e.target.value)}
                  disabled={busy}
                />
              ) : (
                <Select
                  value={values[f.key] ?? ""}
                  onValueChange={(v) => update(f.key, v)}
                  disabled={busy}
                >
                  <SelectTrigger id={f.key}>
                    <SelectValue placeholder="請選擇" />
                  </SelectTrigger>
                  <SelectContent>
                    {f.options.map((o) => (
                      <SelectItem key={o.value} value={o.value}>
                        {o.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
              {f.kind === "text" && f.helper && (
                <p className="text-xs text-muted-foreground">{f.helper}</p>
              )}
            </div>
          ))}
          {errorMsg && (
            <div className="flex items-start gap-2 rounded-md bg-destructive/10 border border-destructive/30 p-3 text-sm text-destructive">
              <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
              <span className="flex-1">{errorMsg}</span>
            </div>
          )}
          <div className="pt-1">
            <Button
              type="submit"
              className="w-full"
              disabled={busy || !formValid(fields, values)}
            >
              {busy && <Loader2 className="w-4 h-4 animate-spin" />}
              {busy ? "處理中…" : submitLabel}
            </Button>
          </div>
        </form>
      </SheetContent>
    </Sheet>
  );
}

function formValid(fields: FormField[], values: Record<string, string>) {
  for (const f of fields) {
    if (f.kind === "text" && f.required && !values[f.key]?.trim()) return false;
  }
  return true;
}

