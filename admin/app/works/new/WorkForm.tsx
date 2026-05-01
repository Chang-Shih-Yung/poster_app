"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { WORK_KINDS } from "@/lib/enums";
import { createWork, updateWork } from "@/app/actions/works";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent } from "@/components/ui/card";
import { AlertTriangle, Loader2 } from "lucide-react";

const CUSTOM_VALUE = "__custom__";
// Sentinel for "no studio" — Radix Select rejects SelectItem with empty
// string value (it's reserved for clearing). We render the trigger with
// this sentinel when studio is "" so the dropdown doesn't crash on works
// with null studio.
const NONE_VALUE = "__none__";

type WorkFormProps = {
  mode: "create" | "edit";
  /** Existing studio names for the dropdown. */
  studios?: string[];
  initial?: {
    id: string;
    studio: string | null;
    title_zh: string;
    title_en: string | null;
    work_kind: string;
    movie_release_year: number | null;
  };
};

export default function WorkForm({ mode, initial, studios = [] }: WorkFormProps) {
  const router = useRouter();
  // If the initial studio is not in the list (rare edge case), start in
  // custom-text mode so the value isn't lost.
  const initialInList =
    !initial?.studio || studios.includes(initial.studio);
  const [studio, setStudio] = useState(initial?.studio ?? "");
  const [studioMode, setStudioMode] = useState<"select" | "custom">(
    initialInList ? "select" : "custom"
  );
  const [titleZh, setTitleZh] = useState(initial?.title_zh ?? "");
  const [titleEn, setTitleEn] = useState(initial?.title_en ?? "");
  const [workKind, setWorkKind] = useState(initial?.work_kind ?? "movie");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!titleZh.trim()) {
      setError("作品台灣官方名稱必填");
      return;
    }
    if (!titleEn.trim()) {
      setError("作品英文官方名稱必填");
      return;
    }
    startTransition(async () => {
      const payload = {
        studio: studio.trim() || null,
        title_zh: titleZh.trim(),
        title_en: titleEn.trim() || null,
        work_kind: workKind,
      };
      const r =
        mode === "create"
          ? await createWork(payload)
          : await updateWork(initial!.id, payload);
      if (!r.ok) {
        setError(r.error);
        return;
      }
      router.push("/works");
    });
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      {error && (
        <Card className="border-destructive/40 bg-destructive/10">
          <CardContent className="p-3 flex items-start gap-2 text-sm text-destructive">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </CardContent>
        </Card>
      )}

      <FormField label="Studio / IP 持有者" htmlFor="studio">
        {studioMode === "select" ? (
          <Select
            value={studio === "" ? NONE_VALUE : studio}
            onValueChange={(v) => {
              if (v === CUSTOM_VALUE) {
                setStudioMode("custom");
                setStudio("");
              } else if (v === NONE_VALUE) {
                setStudio("");
              } else {
                setStudio(v);
              }
            }}
            disabled={pending}
          >
            <SelectTrigger id="studio">
              <SelectValue placeholder="請選擇分類" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NONE_VALUE}>（未分類）</SelectItem>
              {studios.map((s) => (
                <SelectItem key={s} value={s}>
                  {s}
                </SelectItem>
              ))}
              <SelectItem value={CUSTOM_VALUE}>其他（輸入新分類）…</SelectItem>
            </SelectContent>
          </Select>
        ) : (
          <div className="flex gap-2">
            <Input
              id="studio"
              autoFocus
              value={studio}
              onChange={(e) => setStudio(e.target.value)}
              placeholder="新分類名稱"
              disabled={pending}
            />
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="shrink-0"
              onClick={() => {
                setStudioMode("select");
                // If the typed value exists in the list keep it,
                // otherwise clear so the Select shows its placeholder.
                if (!studios.includes(studio)) setStudio("");
              }}
              disabled={pending}
            >
              取消
            </Button>
          </div>
        )}
      </FormField>

      <FormField label="作品台灣官方名稱" required htmlFor="title_zh">
        <Input
          id="title_zh"
          value={titleZh}
          onChange={(e) => setTitleZh(e.target.value)}
          placeholder="例：復仇者系列 / 神隱少女"
          required
          disabled={pending}
        />
      </FormField>

      <FormField label="作品英文官方名稱" required htmlFor="title_en">
        <Input
          id="title_en"
          value={titleEn}
          onChange={(e) => setTitleEn(e.target.value)}
          placeholder="例：Avengers / Spirited Away"
          required
          disabled={pending}
        />
      </FormField>

      <FormField label="類型" htmlFor="work_kind">
        <Select value={workKind} onValueChange={setWorkKind} disabled={pending}>
          <SelectTrigger id="work_kind">
            <SelectValue placeholder="請選擇" />
          </SelectTrigger>
          <SelectContent>
            {WORK_KINDS.map((k) => (
              <SelectItem key={k.value} value={k.value}>
                {k.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </FormField>

      <p className="text-xs text-muted-foreground">
        年份、地區、通路等資訊請在每張海報單獨設定（每張海報可能對應不同
        重映、版本、通路）。
      </p>

      <div className="pt-4 flex gap-3">
        <Button type="submit" disabled={pending}>
          {pending && <Loader2 className="animate-spin" />}
          {pending ? "儲存中…" : mode === "create" ? "建立" : "儲存"}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={() => router.back()}
          disabled={pending}
        >
          取消
        </Button>
      </div>
    </form>
  );
}
