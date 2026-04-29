"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { flattenGroupTree, type FlattenedGroup } from "@/lib/groupTree";
import {
  REGIONS,
  SIZE_TYPES,
  CHANNEL_CATEGORIES,
  CHANNEL_TYPES,
  RELEASE_TYPES,
  MATERIAL_TYPES,
  SOURCE_PLATFORMS,
} from "@/lib/enums";
import { DEFAULT_REGION } from "@/lib/keys";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { createPoster, attachImage } from "@/app/actions/posters";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { WorkPicker, type WorkOption } from "@/components/WorkPicker";
import { GroupPicker } from "@/components/GroupPicker";
import { DatePicker } from "@/components/DatePicker";
import {
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  ImagePlus,
  Loader2,
  Trash2,
  AlertTriangle,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────

type GroupOption = FlattenedGroup;
type DraftStatus = "idle" | "creating" | "uploading" | "done" | "error";
const NONE = "__none__";

type DraftPoster = {
  localId: string;
  file: File;
  previewUrl: string;
  name: string;
  work_id: string;
  parent_group_id: string;
  year: string;
  poster_release_date: string;
  region: string;
  poster_release_type: string;
  size_type: string;
  channel_category: string;
  channel_type: string;
  channel_name: string;
  is_exclusive: boolean;
  exclusive_name: string;
  material_type: string;
  version_label: string;
  source_url: string;
  source_platform: string;
  source_note: string;
  signed: boolean;
  numbered: boolean;
  edition_number: string;
  linen_backed: boolean;
  licensed: boolean;
  status: DraftStatus;
  errorMsg?: string;
};

function newDraft(file: File, defaults: Partial<DraftPoster> = {}): DraftPoster {
  return {
    localId: Math.random().toString(36).slice(2),
    file,
    previewUrl: URL.createObjectURL(file),
    name: "",
    work_id: defaults.work_id ?? "",
    parent_group_id: defaults.parent_group_id ?? NONE,
    year: defaults.year ?? "",
    poster_release_date: "",
    region: defaults.region ?? DEFAULT_REGION,
    poster_release_type: NONE,
    size_type: defaults.size_type ?? NONE,
    channel_category: defaults.channel_category ?? NONE,
    channel_type: NONE,
    channel_name: "",
    is_exclusive: false,
    exclusive_name: "",
    material_type: NONE,
    version_label: "",
    source_url: "",
    source_platform: NONE,
    source_note: "",
    signed: false,
    numbered: false,
    edition_number: "",
    linen_backed: false,
    licensed: true,
    status: "idle",
  };
}

// ─── Main component ───────────────────────────────────────────────────────────

export default function BatchImport({
  works,
  defaultWorkId,
  defaultGroupId,
}: {
  works: WorkOption[];
  defaultWorkId?: string;
  defaultGroupId?: string;
}) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const addMoreRef = useRef<HTMLInputElement>(null);

  const [drafts, setDrafts] = useState<DraftPoster[]>([]);
  const [submitting, setSubmitting] = useState(false);

  // Apply-bar state — prefilled from query params if present
  const [applyWorkId, setApplyWorkId] = useState(defaultWorkId ?? "");
  const [applyGroupId, setApplyGroupId] = useState(defaultGroupId ?? NONE);
  const [applyRegion, setApplyRegion] = useState(DEFAULT_REGION);
  const [applyYear, setApplyYear] = useState("");
  const [applySizeType, setApplySizeType] = useState(NONE);
  const [applyChannelCat, setApplyChannelCat] = useState(NONE);
  const [applyGroupOptions, setApplyGroupOptions] = useState<GroupOption[]>([]);

  // Load groups for the apply-bar work. Extracted so GroupPicker's
  // "+ 新增頂層群組" can re-fetch after creating a new group.
  async function refetchApplyGroups(forWorkId: string) {
    const supabase = createClient();
    const { data } = await supabase
      .from("poster_groups")
      .select("id, name, parent_group_id, display_order")
      .eq("work_id", forWorkId)
      .order("display_order")
      .order("name");
    setApplyGroupOptions(flattenGroupTree(data ?? []));
  }

  // Preserve `defaultGroupId` on the *first* load (deep-link from a
  // group page); subsequent work changes reset the group.
  const initialGroupRef = useRef(defaultGroupId ?? NONE);
  useEffect(() => {
    if (!applyWorkId) { setApplyGroupOptions([]); setApplyGroupId(NONE); return; }
    (async () => {
      await refetchApplyGroups(applyWorkId);
      const initial = initialGroupRef.current;
      if (initial && initial !== NONE) {
        setApplyGroupId(initial);
        initialGroupRef.current = NONE; // consume — only used once
      } else {
        setApplyGroupId(NONE);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [applyWorkId]);

  function updateDraft(localId: string, patch: Partial<DraftPoster>) {
    setDrafts((prev) =>
      prev.map((d) => (d.localId === localId ? { ...d, ...patch } : d))
    );
  }

  function removeDraft(localId: string) {
    setDrafts((prev) => {
      const d = prev.find((d) => d.localId === localId);
      if (d) URL.revokeObjectURL(d.previewUrl);
      return prev.filter((d) => d.localId !== localId);
    });
  }

  function addFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    const defaults: Partial<DraftPoster> = {
      work_id: applyWorkId,
      parent_group_id: applyGroupId,
      region: applyRegion,
      year: applyYear,
      size_type: applySizeType !== NONE ? applySizeType : NONE,
      channel_category: applyChannelCat !== NONE ? applyChannelCat : NONE,
    };
    setDrafts((prev) => [...prev, ...Array.from(files).map((f) => newDraft(f, defaults))]);
  }

  function applyAll() {
    const hasAny =
      applyWorkId ||
      applyRegion !== DEFAULT_REGION ||
      applyYear ||
      applySizeType !== NONE ||
      applyChannelCat !== NONE;
    if (!hasAny) { toast.error("請先在套用欄設定至少一個值"); return; }
    setDrafts((prev) =>
      prev.map((d) => {
        if (d.status !== "idle") return d;
        const patch: Partial<DraftPoster> = {};
        if (applyWorkId) { patch.work_id = applyWorkId; patch.parent_group_id = applyGroupId; }
        if (applyRegion) patch.region = applyRegion;
        if (applyYear) patch.year = applyYear;
        if (applySizeType !== NONE) patch.size_type = applySizeType;
        if (applyChannelCat !== NONE) patch.channel_category = applyChannelCat;
        return { ...d, ...patch };
      })
    );
    toast.success("已套用到全部卡片");
  }

  async function submitAll() {
    const toSubmit = drafts.filter(
      (d) => d.status === "idle" && d.name.trim() && d.work_id
    );
    if (toSubmit.length === 0) {
      toast.error("至少需要一張填了「名稱」和「作品」的卡片");
      return;
    }
    setSubmitting(true);
    const tid = toast.loading(`建立 ${toSubmit.length} 張海報中…`);

    const fromSentinel = (v: string) => (v === NONE ? null : v || null);
    let successCount = 0;
    let failCount = 0;

    await Promise.all(
      toSubmit.map(async (draft) => {
        try {
          updateDraft(draft.localId, { status: "creating" });
          const r = await createPoster({
            work_id: draft.work_id,
            parent_group_id: fromSentinel(draft.parent_group_id),
            poster_name: draft.name.trim(),
            year: draft.year ? parseInt(draft.year, 10) : null,
            poster_release_date: draft.poster_release_date || null,
            region: draft.region || DEFAULT_REGION,
            poster_release_type: fromSentinel(draft.poster_release_type),
            size_type: fromSentinel(draft.size_type),
            channel_category: fromSentinel(draft.channel_category),
            channel_type: fromSentinel(draft.channel_type),
            channel_name: draft.channel_name.trim() || null,
            is_exclusive: draft.is_exclusive,
            exclusive_name: draft.is_exclusive ? draft.exclusive_name.trim() || null : null,
            material_type: fromSentinel(draft.material_type),
            version_label: draft.version_label.trim() || null,
            source_url: draft.source_url.trim() || null,
            source_platform: fromSentinel(draft.source_platform),
            source_note: draft.source_note.trim() || null,
            signed: draft.signed,
            numbered: draft.numbered,
            edition_number: draft.numbered ? draft.edition_number.trim() || null : null,
            linen_backed: draft.linen_backed,
            licensed: draft.licensed,
          });
          if (!r.ok) throw new Error(r.error);

          updateDraft(draft.localId, { status: "uploading" });
          const uploaded = await uploadPosterImage(draft.file, r.data.id);
          const ar = await attachImage(r.data.id, {
            poster_url: uploaded.posterUrl,
            thumbnail_url: uploaded.thumbnailUrl,
            blurhash: uploaded.blurhash,
            image_size_bytes: uploaded.imageSizeBytes,
          });
          if (!ar.ok) throw new Error(ar.error);

          updateDraft(draft.localId, { status: "done" });
          successCount++;
        } catch (e) {
          updateDraft(draft.localId, { status: "error", errorMsg: describeError(e) });
          failCount++;
        }
      })
    );

    toast.dismiss(tid);
    setSubmitting(false);

    if (failCount === 0) {
      toast.success(`${successCount} 張海報已建立！`);
      setTimeout(() => router.push("/posters"), 1200);
    } else {
      toast.error(`${successCount} 張成功，${failCount} 張失敗（請查看標紅卡片）`);
    }
  }

  const readyCount = drafts.filter(
    (d) => d.status === "idle" && d.name.trim() && d.work_id
  ).length;
  const doneCount = drafts.filter((d) => d.status === "done").length;
  const errorCount = drafts.filter((d) => d.status === "error").length;
  const busyCount = drafts.filter(
    (d) => d.status === "creating" || d.status === "uploading"
  ).length;

  // ── Empty state ────────────────────────────────────────────────────────────
  if (drafts.length === 0) {
    return (
      <div className="space-y-3">
        <p className="text-sm text-muted-foreground">
          先選照片，再批量填 metadata。
          <Link href="/posters/new" className="ml-2 underline-offset-2 hover:underline">
            只要新增單張？
          </Link>
        </p>
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/*"
          className="hidden"
          onChange={(e) => addFiles(e.target.files)}
        />
        <button
          onClick={() => fileInputRef.current?.click()}
          className="w-full border-2 border-dashed border-border rounded-xl py-14 flex flex-col items-center gap-3 text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
        >
          <ImagePlus className="w-10 h-10" />
          <span className="text-sm font-medium">點此選擇照片（可多選）</span>
          <span className="text-xs">支援 JPG、PNG、HEIC</span>
        </button>
      </div>
    );
  }

  // ── Main layout ────────────────────────────────────────────────────────────
  return (
    <div className="space-y-4 pb-6">
      {/* Hidden file inputs */}
      <input
        ref={fileInputRef}
        type="file"
        multiple
        accept="image/*"
        className="hidden"
        onChange={(e) => addFiles(e.target.files)}
      />
      <input
        ref={addMoreRef}
        type="file"
        multiple
        accept="image/*"
        className="hidden"
        onChange={(e) => addFiles(e.target.files)}
      />

      {/* ── Apply bar ───────────────────────────────────────────────────── */}
      <Card>
        <CardContent className="p-3 space-y-3">
          <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            套用到全部卡片
          </p>

          {/* Work — searchable */}
          <div className="space-y-1">
            <Label className="text-xs">作品</Label>
            <WorkPicker
              works={works}
              value={applyWorkId}
              onChange={setApplyWorkId}
              triggerClassName="h-9"
            />
          </div>

          {/* Group — searchable + "+ 新增" (only shown when work selected) */}
          {applyWorkId && (
            <div className="space-y-1">
              <Label className="text-xs">群組</Label>
              <GroupPicker
                workId={applyWorkId}
                workName={works.find((w) => w.id === applyWorkId)?.title_zh}
                groups={applyGroupOptions}
                value={applyGroupId}
                onChange={setApplyGroupId}
                onGroupCreated={() => refetchApplyGroups(applyWorkId)}
              />
            </div>
          )}

          {/* 2-col: 地區 + 尺寸 */}
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <Label className="text-xs">地區</Label>
              <Select value={applyRegion} onValueChange={setApplyRegion}>
                <SelectTrigger className="h-9"><SelectValue /></SelectTrigger>
                <SelectContent>
                  {REGIONS.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label className="text-xs">尺寸</Label>
              <Select value={applySizeType} onValueChange={setApplySizeType}>
                <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {SIZE_TYPES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* 2-col: 發行年份 + 通路類型 */}
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <Label className="text-xs">發行年份</Label>
              <Input
                type="number"
                min={1900}
                max={2100}
                value={applyYear}
                onChange={(e) => setApplyYear(e.target.value)}
                placeholder="例：2026"
                className="h-9"
              />
            </div>
            <div className="space-y-1">
              <Label className="text-xs">通路類型</Label>
              <Select value={applyChannelCat} onValueChange={setApplyChannelCat}>
                <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {CHANNEL_CATEGORIES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <Button
            type="button"
            variant="secondary"
            className="w-full"
            onClick={applyAll}
            disabled={submitting}
          >
            套用到全部 {drafts.filter((d) => d.status === "idle").length} 張卡片
          </Button>
        </CardContent>
      </Card>

      {/* ── Cards ───────────────────────────────────────────────────────── */}
      <div className="space-y-2">
        {drafts.map((draft) => (
          <DraftCard
            key={draft.localId}
            draft={draft}
            works={works}
            onChange={(patch) => updateDraft(draft.localId, patch)}
            onRemove={() => removeDraft(draft.localId)}
            disabled={submitting || draft.status !== "idle"}
          />
        ))}
      </div>

      {/* ── Footer ──────────────────────────────────────────────────────── */}
      <div className="space-y-3 pt-2">
        {/* Status summary */}
        {(doneCount > 0 || errorCount > 0 || busyCount > 0) && (
          <div className="flex gap-3 text-sm flex-wrap">
            {busyCount > 0 && (
              <span className="flex items-center gap-1 text-muted-foreground">
                <Loader2 className="w-3.5 h-3.5 animate-spin" /> {busyCount} 張處理中
              </span>
            )}
            {doneCount > 0 && (
              <span className="flex items-center gap-1 text-green-600">
                <CheckCircle2 className="w-3.5 h-3.5" /> {doneCount} 張完成
              </span>
            )}
            {errorCount > 0 && (
              <span className="flex items-center gap-1 text-destructive">
                <AlertTriangle className="w-3.5 h-3.5" /> {errorCount} 張失敗
              </span>
            )}
          </div>
        )}

        <div className="flex gap-2 flex-wrap">
          <Button
            onClick={submitAll}
            disabled={submitting || readyCount === 0}
            className="flex-1"
          >
            {submitting && <Loader2 className="animate-spin" />}
            {submitting ? "建立中…" : `建立全部 (${readyCount} 張)`}
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={() => addMoreRef.current?.click()}
            disabled={submitting}
          >
            繼續新增照片
          </Button>
        </div>

        {readyCount < drafts.length && readyCount > 0 && (
          <p className="text-xs text-muted-foreground">
            {drafts.length - readyCount} 張缺少「名稱」或「作品」將被跳過
          </p>
        )}
        {readyCount === 0 && drafts.some((d) => d.status === "idle") && (
          <p className="text-xs text-destructive">
            每張卡片至少需填寫「海報名稱」和「作品」才能建立
          </p>
        )}
      </div>
    </div>
  );
}

// ─── Draft Card ───────────────────────────────────────────────────────────────

function DraftCard({
  draft,
  works,
  onChange,
  onRemove,
  disabled,
}: {
  draft: DraftPoster;
  works: WorkOption[];
  onChange: (patch: Partial<DraftPoster>) => void;
  onRemove: () => void;
  disabled: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const [groupOptions, setGroupOptions] = useState<GroupOption[]>([]);
  const [previewBroken, setPreviewBroken] = useState(false);
  const replaceInputRef = useRef<HTMLInputElement>(null);

  function handleReplaceFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    // Free the old object URL so we don't accumulate them while the
    // user replaces a card multiple times in one session.
    URL.revokeObjectURL(draft.previewUrl);
    onChange({
      file,
      previewUrl: URL.createObjectURL(file),
    });
    setPreviewBroken(false);
    e.target.value = ""; // allow re-selecting the same filename later
  }

  async function refetchGroups(forWorkId: string) {
    const supabase = createClient();
    const { data } = await supabase
      .from("poster_groups")
      .select("id, name, parent_group_id, display_order")
      .eq("work_id", forWorkId)
      .order("display_order")
      .order("name");
    setGroupOptions(flattenGroupTree(data ?? []));
  }

  useEffect(() => {
    if (!draft.work_id) { setGroupOptions([]); return; }
    refetchGroups(draft.work_id);
  }, [draft.work_id]);

  const statusIcon =
    draft.status === "creating" || draft.status === "uploading" ? (
      <Loader2 className="w-4 h-4 animate-spin text-muted-foreground shrink-0" />
    ) : draft.status === "done" ? (
      <CheckCircle2 className="w-4 h-4 text-green-600 shrink-0" />
    ) : draft.status === "error" ? (
      <AlertTriangle className="w-4 h-4 text-destructive shrink-0" />
    ) : null;

  const statusLabel =
    draft.status === "creating"
      ? "建立中…"
      : draft.status === "uploading"
      ? "上傳中…"
      : null;

  return (
    <Card
      className={cn(
        "transition-colors",
        draft.status === "done" && "border-green-500/40 bg-green-500/5",
        draft.status === "error" && "border-destructive/40 bg-destructive/5"
      )}
    >
      <CardContent className="p-3 space-y-2">
        {/* Hidden file input for replacing this card's photo */}
        <input
          ref={replaceInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleReplaceFile}
        />

        {/* ── Header row ────────────────────────────────────────────── */}
        <div className="flex items-start gap-2.5">
          {/* Clickable thumbnail — click to replace photo (preserves
              all metadata that's already filled in). Falls back to a
              placeholder when the browser can't decode the file
              (HEIC on Chrome desktop is the common case). */}
          <button
            type="button"
            onClick={() => !disabled && replaceInputRef.current?.click()}
            disabled={disabled}
            className={cn(
              "relative w-10 h-14 rounded border border-border shrink-0 mt-0.5 overflow-hidden group",
              !disabled && "hover:border-primary cursor-pointer",
              disabled && "cursor-default"
            )}
            title={disabled ? undefined : "點擊更換照片"}
          >
            {previewBroken ? (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-secondary/40 text-muted-foreground">
                <ImagePlus className="w-4 h-4" />
                <span className="text-[8px] mt-0.5 px-0.5 truncate max-w-full">
                  無預覽
                </span>
              </div>
            ) : (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={draft.previewUrl}
                alt=""
                className="w-full h-full object-cover"
                onError={() => setPreviewBroken(true)}
              />
            )}
            {!disabled && (
              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 flex items-center justify-center transition-colors opacity-0 group-hover:opacity-100">
                <ImagePlus className="w-3.5 h-3.5 text-white" />
              </div>
            )}
          </button>

          {/* Name */}
          <div className="flex-1 min-w-0">
            <Input
              value={draft.name}
              onChange={(e) => onChange({ name: e.target.value })}
              placeholder="海報名稱（必填）*"
              disabled={disabled}
              className={cn(
                "h-9",
                !draft.name.trim() && draft.status === "idle" && "border-orange-400/60"
              )}
            />
            {draft.status === "error" && draft.errorMsg && (
              <p className="text-xs text-destructive mt-1 truncate">{draft.errorMsg}</p>
            )}
            {statusLabel && (
              <p className="text-xs text-muted-foreground mt-1">{statusLabel}</p>
            )}
          </div>

          {/* Status icon */}
          {statusIcon && <div className="mt-2">{statusIcon}</div>}

          {/* Expand toggle */}
          {draft.status === "idle" && (
            <Button
              type="button"
              variant="quiet"
              size="icon"
              className="mt-0.5 shrink-0"
              onClick={() => setExpanded((v) => !v)}
              aria-label={expanded ? "收合" : "展開"}
            >
              {expanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </Button>
          )}

          {/* Remove */}
          {draft.status === "idle" && (
            <Button
              type="button"
              variant="quiet"
              size="icon"
              className="mt-0.5 shrink-0 hover:text-destructive"
              onClick={onRemove}
              aria-label="移除"
            >
              <Trash2 className="w-4 h-4" />
            </Button>
          )}
        </div>

        {/* ── Expanded fields ────────────────────────────────────────── */}
        {expanded && draft.status === "idle" && (
          <div className="space-y-3 pt-1 border-t border-border">
            {/* 作品 + 群組 — searchable */}
            <div className="space-y-1">
              <Label className="text-xs">作品 *</Label>
              <WorkPicker
                works={works}
                value={draft.work_id}
                onChange={(v) => onChange({ work_id: v, parent_group_id: NONE })}
                triggerClassName="h-9"
              />
            </div>

            {draft.work_id && (
              <div className="space-y-1">
                <Label className="text-xs">群組</Label>
                <GroupPicker
                  workId={draft.work_id}
                  workName={works.find((w) => w.id === draft.work_id)?.title_zh}
                  groups={groupOptions}
                  value={draft.parent_group_id}
                  onChange={(v) => onChange({ parent_group_id: v })}
                  onGroupCreated={() => refetchGroups(draft.work_id)}
                />
              </div>
            )}

            {/* 發行日期 + 年份 */}
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1">
                <Label className="text-xs">發行日期</Label>
                <DatePicker
                  value={draft.poster_release_date}
                  onChange={(v) => {
                    const yearPatch = /^\d{4}-\d{2}-\d{2}$/.test(v) ? { year: v.slice(0, 4) } : {};
                    onChange({ poster_release_date: v, ...yearPatch });
                  }}
                  className="h-9"
                />
              </div>
              <div className="space-y-1">
                <Label className="text-xs">發行年份</Label>
                <Input
                  type="number"
                  min={1900}
                  max={2100}
                  value={draft.year}
                  onChange={(e) => onChange({ year: e.target.value })}
                  placeholder="例：2026"
                  className="h-9"
                />
              </div>
            </div>

            {/* 地區 + 發行類型 */}
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1">
                <Label className="text-xs">地區</Label>
                <Select value={draft.region} onValueChange={(v) => onChange({ region: v })}>
                  <SelectTrigger className="h-9"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {REGIONS.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs">發行類型</Label>
                <Select value={draft.poster_release_type} onValueChange={(v) => onChange({ poster_release_type: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {RELEASE_TYPES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* 尺寸 + 材質 */}
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1">
                <Label className="text-xs">尺寸</Label>
                <Select value={draft.size_type} onValueChange={(v) => onChange({ size_type: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {SIZE_TYPES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs">材質</Label>
                <Select value={draft.material_type} onValueChange={(v) => onChange({ material_type: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {MATERIAL_TYPES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* 通路類型 + 通路細分 */}
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1">
                <Label className="text-xs">通路類型</Label>
                <Select value={draft.channel_category} onValueChange={(v) => onChange({ channel_category: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {CHANNEL_CATEGORIES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs">通路細分</Label>
                <Select value={draft.channel_type} onValueChange={(v) => onChange({ channel_type: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {CHANNEL_TYPES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* 通路名稱 */}
            <div className="space-y-1">
              <Label className="text-xs">通路名稱</Label>
              <Input
                value={draft.channel_name}
                onChange={(e) => onChange({ channel_name: e.target.value })}
                placeholder="例：威秀影城"
                className="h-9"
              />
            </div>

            {/* 獨家 */}
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={draft.is_exclusive}
                onChange={(e) => onChange({ is_exclusive: e.target.checked })}
                className="h-4 w-4 rounded border-input"
              />
              獨家
            </label>
            {draft.is_exclusive && (
              <Input
                value={draft.exclusive_name}
                onChange={(e) => onChange({ exclusive_name: e.target.value })}
                placeholder="獨家名稱"
                className="h-9"
              />
            )}

            {/* 版本標記 */}
            <div className="space-y-1">
              <Label className="text-xs">版本標記</Label>
              <Input
                value={draft.version_label}
                onChange={(e) => onChange({ version_label: e.target.value })}
                placeholder="例：v2、25 週年"
                className="h-9"
              />
            </div>

            {/* 來源 */}
            <div className="grid grid-cols-2 gap-2">
              <div className="space-y-1">
                <Label className="text-xs">來源平台</Label>
                <Select value={draft.source_platform} onValueChange={(v) => onChange({ source_platform: v })}>
                  <SelectTrigger className="h-9"><SelectValue placeholder="—" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {SOURCE_PLATFORMS.map((r) => (
                      <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs">來源網址</Label>
                <Input
                  type="url"
                  value={draft.source_url}
                  onChange={(e) => onChange({ source_url: e.target.value })}
                  className="h-9"
                />
              </div>
            </div>

            <div className="space-y-1">
              <Label className="text-xs">備註</Label>
              <Textarea
                value={draft.source_note}
                onChange={(e) => onChange({ source_note: e.target.value })}
                rows={2}
              />
            </div>

            {/* 收藏者資訊 */}
            <div className="space-y-2 pt-1">
              <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                收藏者資訊
              </p>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={draft.signed} onChange={(e) => onChange({ signed: e.target.checked })} className="h-4 w-4 rounded border-input" />
                有簽名 signed
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={draft.numbered} onChange={(e) => onChange({ numbered: e.target.checked })} className="h-4 w-4 rounded border-input" />
                限量編號 numbered
              </label>
              {draft.numbered && (
                <Input
                  value={draft.edition_number}
                  onChange={(e) => onChange({ edition_number: e.target.value })}
                  placeholder="例：42/325"
                  className="h-9"
                />
              )}
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={draft.linen_backed} onChange={(e) => onChange({ linen_backed: e.target.checked })} className="h-4 w-4 rounded border-input" />
                亞麻布背裱 linen backed
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={draft.licensed} onChange={(e) => onChange({ licensed: e.target.checked })} className="h-4 w-4 rounded border-input" />
                官方授權 licensed
              </label>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
