"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import {
  REGIONS,
  RELEASE_TYPES,
  SIZE_TYPES,
  CHANNEL_CATEGORIES,
  WORK_KINDS,
} from "@/lib/enums";
import { flattenGroupTree } from "@/lib/groupTree";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { AlertTriangle, Loader2 } from "lucide-react";

type WorkOption = { id: string; title_zh: string; studio: string | null };

type PosterFormProps = {
  mode: "create" | "edit";
  works: WorkOption[];
  initial?: {
    id: string;
    work_id: string | null;
    work_kind?: string | null;
    poster_name: string | null;
    region: string | null;
    year: number | null;
    poster_release_type: string | null;
    size_type: string | null;
    channel_category: string | null;
    channel_name: string | null;
    is_exclusive: boolean;
    exclusive_name: string | null;
    material_type: string | null;
    version_label: string | null;
    source_url: string | null;
    source_note: string | null;
    is_placeholder: boolean;
    parent_group_id?: string | null;
  };
  defaultWorkId?: string;
};

// Sentinel "no value" for shadcn Select (Radix Select rejects an empty
// string as an item value). Translated back to null on submit.
const NONE = "__none__";

export default function PosterForm({
  mode,
  works,
  initial,
  defaultWorkId,
}: PosterFormProps) {
  const router = useRouter();
  const [workId, setWorkId] = useState(initial?.work_id ?? defaultWorkId ?? "");
  const [parentGroupId, setParentGroupId] = useState<string>(
    initial?.parent_group_id ?? ""
  );
  const [groupOptions, setGroupOptions] = useState<
    { id: string; label: string }[]
  >([]);
  const [posterName, setPosterName] = useState(initial?.poster_name ?? "");
  const [year, setYear] = useState<string>(
    initial?.year != null ? String(initial.year) : ""
  );
  const [region, setRegion] = useState(initial?.region ?? "TW");
  const [releaseType, setReleaseType] = useState(
    initial?.poster_release_type ?? ""
  );
  const [sizeType, setSizeType] = useState(initial?.size_type ?? "");
  const [channelCat, setChannelCat] = useState(initial?.channel_category ?? "");
  const [channelName, setChannelName] = useState(initial?.channel_name ?? "");
  const [isExclusive, setIsExclusive] = useState(initial?.is_exclusive ?? false);
  const [exclusiveName, setExclusiveName] = useState(
    initial?.exclusive_name ?? ""
  );
  const [materialType, setMaterialType] = useState(initial?.material_type ?? "");
  const [versionLabel, setVersionLabel] = useState(initial?.version_label ?? "");
  const [sourceUrl, setSourceUrl] = useState(initial?.source_url ?? "");
  const [sourceNote, setSourceNote] = useState(initial?.source_note ?? "");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!workId) {
      setGroupOptions([]);
      return;
    }
    const supabase = createClient();
    (async () => {
      const { data } = await supabase
        .from("poster_groups")
        .select("id, name, parent_group_id, display_order")
        .eq("work_id", workId)
        .order("display_order")
        .order("name");
      const flat = flattenGroupTree(data ?? []);
      setGroupOptions(flat);
    })();
  }, [workId]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!workId) {
      setError("必須指定作品");
      return;
    }
    setSubmitting(true);
    const supabase = createClient();

    const yearTrimmed = year.trim();
    const yearInt = yearTrimmed ? parseInt(yearTrimmed, 10) : null;
    if (
      yearTrimmed &&
      (Number.isNaN(yearInt!) || yearInt! < 1900 || yearInt! > 2100)
    ) {
      setError("年份格式錯誤（1900-2100 整數）");
      setSubmitting(false);
      return;
    }

    const row: Record<string, unknown> = {
      work_id: workId,
      parent_group_id: parentGroupId || null,
      poster_name: posterName.trim() || null,
      year: yearInt,
      region: region || "TW",
      poster_release_type: releaseType || null,
      size_type: sizeType || null,
      channel_category: channelCat || null,
      channel_name: channelName.trim() || null,
      is_exclusive: isExclusive,
      exclusive_name: isExclusive ? exclusiveName.trim() || null : null,
      material_type: materialType.trim() || null,
      version_label: versionLabel.trim() || null,
      source_url: sourceUrl.trim() || null,
      source_note: sourceNote.trim() || null,
    };

    if (mode === "create") {
      row.title = posterName.trim() || "(待命名)";
      row.status = "approved";
      row.poster_url = "";
      const { data: userData } = await supabase.auth.getUser();
      const uid = userData.user?.id;
      if (!uid) {
        setError("尚未登入或 session 已失效");
        setSubmitting(false);
        return;
      }
      row.uploader_id = uid;
    }

    const { error } =
      mode === "create"
        ? await supabase.from("posters").insert(row)
        : await supabase.from("posters").update(row).eq("id", initial!.id);

    setSubmitting(false);
    if (error) {
      setError(error.message);
      return;
    }

    router.push("/posters");
    router.refresh();
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
        <Label htmlFor="work_id">作品 *</Label>
        <Select value={workId} onValueChange={setWorkId}>
          <SelectTrigger id="work_id">
            <SelectValue placeholder="── 選擇作品 ──" />
          </SelectTrigger>
          <SelectContent>
            {works.map((w) => (
              <SelectItem key={w.id} value={w.id}>
                {w.studio ? `[${w.studio}] ` : ""}
                {w.title_zh}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {initial?.work_kind && workId && (
        <WorkKindReadOnly workKind={initial.work_kind} />
      )}

      <div className="space-y-1.5">
        <Label htmlFor="group">所屬群組</Label>
        <Select
          value={parentGroupId || NONE}
          onValueChange={(v) => setParentGroupId(v === NONE ? "" : v)}
          disabled={!workId}
        >
          <SelectTrigger id="group">
            <SelectValue placeholder="── 不屬於任何群組 ──" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={NONE}>── 不屬於任何群組 ──</SelectItem>
            {groupOptions.map((g) => (
              <SelectItem key={g.id} value={g.id}>
                {g.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {!workId && (
          <p className="text-xs text-muted-foreground">
            先選作品才能看到該作品的群組
          </p>
        )}
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="poster_name">海報名稱</Label>
        <Input
          id="poster_name"
          value={posterName}
          onChange={(e) => setPosterName(e.target.value)}
          placeholder="例：B1 原版 / IMAX 威秀獨家"
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="year">發行年份</Label>
          <Input
            id="year"
            type="number"
            min={1900}
            max={2100}
            value={year}
            onChange={(e) => setYear(e.target.value)}
            placeholder="例：2026"
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="region">地區</Label>
          <Select value={region} onValueChange={setRegion}>
            <SelectTrigger id="region">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {REGIONS.map((r) => (
                <SelectItem key={r.value} value={r.value}>
                  {r.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="release_type">發行類型</Label>
          <Select
            value={releaseType || NONE}
            onValueChange={(v) => setReleaseType(v === NONE ? "" : v)}
          >
            <SelectTrigger id="release_type">
              <SelectValue placeholder="—" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NONE}>—</SelectItem>
              {RELEASE_TYPES.map((r) => (
                <SelectItem key={r.value} value={r.value}>
                  {r.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="size_type">尺寸</Label>
          <Select
            value={sizeType || NONE}
            onValueChange={(v) => setSizeType(v === NONE ? "" : v)}
          >
            <SelectTrigger id="size_type">
              <SelectValue placeholder="—" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NONE}>—</SelectItem>
              {SIZE_TYPES.map((r) => (
                <SelectItem key={r.value} value={r.value}>
                  {r.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="channel_cat">通路類型</Label>
          <Select
            value={channelCat || NONE}
            onValueChange={(v) => setChannelCat(v === NONE ? "" : v)}
          >
            <SelectTrigger id="channel_cat">
              <SelectValue placeholder="—" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NONE}>—</SelectItem>
              {CHANNEL_CATEGORIES.map((r) => (
                <SelectItem key={r.value} value={r.value}>
                  {r.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="channel_name">通路名稱</Label>
          <Input
            id="channel_name"
            value={channelName}
            onChange={(e) => setChannelName(e.target.value)}
            placeholder="例：威秀影城、東寶"
          />
        </div>
      </div>

      <label className="flex items-center gap-2 text-sm text-foreground">
        <input
          type="checkbox"
          checked={isExclusive}
          onChange={(e) => setIsExclusive(e.target.checked)}
          className="h-4 w-4 rounded border-input"
        />
        <span>獨家</span>
      </label>

      {isExclusive && (
        <div className="space-y-1.5">
          <Label htmlFor="exclusive_name">獨家名稱</Label>
          <Input
            id="exclusive_name"
            value={exclusiveName}
            onChange={(e) => setExclusiveName(e.target.value)}
            placeholder="例：威秀影城"
          />
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="material">材質</Label>
          <Input
            id="material"
            value={materialType}
            onChange={(e) => setMaterialType(e.target.value)}
            placeholder="例：霧面紙 / 金箔紙"
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="version">版本標記</Label>
          <Input
            id="version"
            value={versionLabel}
            onChange={(e) => setVersionLabel(e.target.value)}
            placeholder="例：v2、25 週年"
          />
        </div>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="source_url">來源網址</Label>
        <Input
          id="source_url"
          type="url"
          value={sourceUrl}
          onChange={(e) => setSourceUrl(e.target.value)}
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="source_note">備註</Label>
        <Textarea
          id="source_note"
          value={sourceNote}
          onChange={(e) => setSourceNote(e.target.value)}
        />
      </div>

      <div className="pt-4 flex gap-3">
        <Button type="submit" disabled={submitting}>
          {submitting && <Loader2 className="animate-spin" />}
          {submitting ? "儲存中…" : mode === "create" ? "建立" : "儲存"}
        </Button>
        <Button type="button" variant="outline" onClick={() => router.back()}>
          取消
        </Button>
      </div>

      <p className="text-xs text-muted-foreground pt-2">
        新建海報預設 is_placeholder = true（先用通用剪影顯示）。
      </p>
    </form>
  );
}

/**
 * Read-only display of work_kind. The value lives on posters.work_kind
 * (denormalized from works.work_kind for filtering); source of truth is
 * the work — DB triggers keep them in lock-step.
 */
function WorkKindReadOnly({ workKind }: { workKind: string }) {
  const label = WORK_KINDS.find((k) => k.value === workKind)?.label ?? workKind;
  return (
    <div className="flex items-center gap-2">
      <span className="text-xs uppercase tracking-wider text-muted-foreground">
        類型
      </span>
      <Badge variant="muted">{label}</Badge>
    </div>
  );
}

