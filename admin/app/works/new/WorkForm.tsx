"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { WORK_KINDS } from "@/lib/enums";
import { createWork, updateWork } from "@/app/actions/works";
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
import { Card, CardContent } from "@/components/ui/card";
import { AlertTriangle, Loader2 } from "lucide-react";

type WorkFormProps = {
  mode: "create" | "edit";
  initial?: {
    id: string;
    studio: string | null;
    title_zh: string;
    title_en: string | null;
    work_kind: string;
    movie_release_year: number | null;
  };
};

export default function WorkForm({ mode, initial }: WorkFormProps) {
  const router = useRouter();
  const [studio, setStudio] = useState(initial?.studio ?? "");
  const [titleZh, setTitleZh] = useState(initial?.title_zh ?? "");
  const [titleEn, setTitleEn] = useState(initial?.title_en ?? "");
  const [workKind, setWorkKind] = useState(initial?.work_kind ?? "movie");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!titleZh.trim()) {
      setError("群組名稱必填");
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

      <div className="space-y-1.5">
        <Label htmlFor="studio">Studio / IP 持有者</Label>
        <Input
          id="studio"
          value={studio}
          onChange={(e) => setStudio(e.target.value)}
          placeholder="例：漫威 / 吉卜力 / 新海誠 作品"
          disabled={pending}
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="title_zh">群組名稱 *</Label>
        <Input
          id="title_zh"
          value={titleZh}
          onChange={(e) => setTitleZh(e.target.value)}
          placeholder="例：復仇者系列 / 神隱少女"
          required
          disabled={pending}
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="title_en">英文名</Label>
        <Input
          id="title_en"
          value={titleEn}
          onChange={(e) => setTitleEn(e.target.value)}
          placeholder="例：Avengers / Spirited Away"
          disabled={pending}
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="work_kind">類型</Label>
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
      </div>

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
