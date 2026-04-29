"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { flattenGroupTree, type FlattenedGroup } from "@/lib/groupTree";
import { SIZE_TYPES, CHANNEL_CATEGORIES, REGIONS } from "@/lib/enums";
import { DEFAULT_REGION } from "@/lib/keys";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { createPoster, attachImage } from "@/app/actions/posters";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { WorkPicker, type WorkOption } from "@/components/WorkPicker";
import { GroupPicker } from "@/components/GroupPicker";
import {
  CheckCircle2,
  ImagePlus,
  Loader2,
  AlertTriangle,
} from "lucide-react";
import { toast } from "sonner";
import {
  NONE,
  fromSentinel,
  isReady,
  newDraft,
  rejectionReason,
  type DraftPoster,
} from "./_shared";
import { DraftCard } from "./DraftCard";

/**
 * Batch import flow (cards version):
 *
 *   File picker → N draft cards → apply-bar (bulk fields) → submit all
 *
 * State outline:
 *   - drafts: DraftPoster[]                  (one card each)
 *   - groupsByWork: Record<workId, groups[]> (cache so 10 cards on the
 *                                              same work don't fire 10
 *                                              parallel /poster_groups
 *                                              queries)
 *   - submitting: boolean                    (locks the UI during work)
 *
 * Two safety nets cover the easiest mistakes:
 *   1. unmount → revoke all `previewUrl` ObjectURLs (memory)
 *   2. beforeunload → warn the user if drafts have unsaved metadata
 */
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

  // Groups cache: workId → flat group list. Shared across the apply
  // bar and every DraftCard, so N cards on the same work share one
  // network round-trip instead of firing N.
  const [groupsByWork, setGroupsByWork] = useState<
    Record<string, FlattenedGroup[]>
  >({});
  const inflightRef = useRef<Set<string>>(new Set());

  // Apply-bar state
  const [applyWorkId, setApplyWorkId] = useState(defaultWorkId ?? "");
  const [applyGroupId, setApplyGroupId] = useState(defaultGroupId ?? NONE);
  const [applyRegion, setApplyRegion] = useState(DEFAULT_REGION);
  const [applyYear, setApplyYear] = useState("");
  const [applySizeType, setApplySizeType] = useState(NONE);
  const [applyChannelCat, setApplyChannelCat] = useState(NONE);

  /** Load groups for a work into the cache. No-op if already cached
   * (or already in flight) unless `force` is set. */
  const loadGroupsFor = useCallback(
    async (workId: string, opts: { force?: boolean } = {}) => {
      if (!workId) return;
      if (
        !opts.force &&
        (groupsByWork[workId] || inflightRef.current.has(workId))
      )
        return;
      inflightRef.current.add(workId);
      try {
        const supabase = createClient();
        const { data } = await supabase
          .from("poster_groups")
          .select("id, name, parent_group_id, display_order")
          .eq("work_id", workId)
          .order("display_order")
          .order("name");
        setGroupsByWork((prev) => ({
          ...prev,
          [workId]: flattenGroupTree(data ?? []),
        }));
      } finally {
        inflightRef.current.delete(workId);
      }
    },
    [groupsByWork]
  );

  // Initial load + reload when apply-bar work changes.
  // First mount only: keep `defaultGroupId` selected after the cache
  // populates. Subsequent work changes reset to NONE.
  const initialGroupRef = useRef(defaultGroupId ?? NONE);
  useEffect(() => {
    if (!applyWorkId) return;
    (async () => {
      await loadGroupsFor(applyWorkId);
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

  // ─── Lifecycle safety ─────────────────────────────────────────────
  // 1. Unmount cleanup: revoke every ObjectURL we created. Without
  //    this, leaving the page with 20 photo previews leaks 20× the
  //    file size in memory until tab close.
  const draftsRef = useRef(drafts);
  useEffect(() => {
    draftsRef.current = drafts;
  }, [drafts]);
  useEffect(() => {
    return () => {
      for (const d of draftsRef.current) {
        URL.revokeObjectURL(d.previewUrl);
      }
    };
  }, []);

  // 2. beforeunload: warn before navigating away if there are unsaved
  //    drafts that aren't already in flight or done. Mobile back-button
  //    eats the whole batch otherwise.
  useEffect(() => {
    const hasUnsavedWork = drafts.some(
      (d) =>
        d.status === "idle" &&
        // empty card with default name "" is fine — only block if user
        // has filled anything in.
        (d.name.trim() ||
          d.work_id ||
          d.year ||
          d.poster_release_date ||
          d.size_type !== NONE)
    );
    if (!hasUnsavedWork) return;
    function handler(e: BeforeUnloadEvent) {
      e.preventDefault();
      // Modern browsers ignore the message but show their own confirm.
      e.returnValue = "";
    }
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [drafts]);

  // ─── Helpers ──────────────────────────────────────────────────────
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
    const accepted: File[] = [];
    const rejected: { file: File; reason: string }[] = [];
    for (const f of Array.from(files)) {
      const reason = rejectionReason(f);
      if (reason) rejected.push({ file: f, reason });
      else accepted.push(f);
    }
    if (rejected.length > 0) {
      // One toast per reason class to avoid spam — group by reason.
      const grouped = new Map<string, string[]>();
      for (const r of rejected) {
        const list = grouped.get(r.reason) ?? [];
        list.push(r.file.name);
        grouped.set(r.reason, list);
      }
      for (const [reason, names] of grouped) {
        toast.error(
          `${names.length} 個檔案被略過：${reason}（${names.slice(0, 3).join(", ")}${names.length > 3 ? "…" : ""}）`,
          { duration: 8000 }
        );
      }
    }
    if (accepted.length === 0) return;

    const defaults: Partial<DraftPoster> = {
      work_id: applyWorkId,
      parent_group_id: applyGroupId,
      region: applyRegion,
      year: applyYear,
      size_type: applySizeType !== NONE ? applySizeType : NONE,
      channel_category: applyChannelCat !== NONE ? applyChannelCat : NONE,
    };
    setDrafts((prev) => [
      ...prev,
      ...accepted.map((f) => newDraft(f, defaults)),
    ]);
    // Pre-fetch groups for the work so the cards don't lag when the
    // user expands them.
    if (applyWorkId) loadGroupsFor(applyWorkId);
  }

  /** Returns true if any apply-bar field has a non-default value. */
  function hasApplyValues(): boolean {
    return Boolean(
      applyWorkId ||
        applyYear ||
        applySizeType !== NONE ||
        applyChannelCat !== NONE
    );
  }

  function applyAll() {
    if (!hasApplyValues()) {
      toast.error("請先在套用欄設定至少一個值");
      return;
    }
    setDrafts((prev) =>
      prev.map((d) => {
        if (d.status !== "idle") return d;
        const patch: Partial<DraftPoster> = {};
        if (applyWorkId) {
          patch.work_id = applyWorkId;
          patch.parent_group_id = applyGroupId;
        }
        // applyRegion always has a value (DEFAULT_REGION at minimum) —
        // we still apply it so the draft adopts whatever the bar shows.
        patch.region = applyRegion;
        if (applyYear) patch.year = applyYear;
        if (applySizeType !== NONE) patch.size_type = applySizeType;
        if (applyChannelCat !== NONE) patch.channel_category = applyChannelCat;
        return { ...d, ...patch };
      })
    );
    toast.success("已套用到全部卡片");
  }

  async function submitAll() {
    const toSubmit = drafts.filter(isReady);
    if (toSubmit.length === 0) {
      toast.error("至少需要一張填了「名稱」和「作品」的卡片");
      return;
    }
    setSubmitting(true);
    const tid = toast.loading(`建立 ${toSubmit.length} 張海報中…`);

    let fullSuccessCount = 0;
    let imageFailedCount = 0;
    let fullFailureCount = 0;

    await Promise.all(
      toSubmit.map(async (draft) => {
        let posterId: string | null = null;
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
            exclusive_name: draft.is_exclusive
              ? draft.exclusive_name.trim() || null
              : null,
            material_type: fromSentinel(draft.material_type),
            version_label: draft.version_label.trim() || null,
            source_url: draft.source_url.trim() || null,
            source_platform: fromSentinel(draft.source_platform),
            source_note: draft.source_note.trim() || null,
            signed: draft.signed,
            numbered: draft.numbered,
            edition_number: draft.numbered
              ? draft.edition_number.trim() || null
              : null,
            linen_backed: draft.linen_backed,
            licensed: draft.licensed,
          });
          if (!r.ok) throw new Error(r.error);
          posterId = r.data.id;

          updateDraft(draft.localId, {
            status: "uploading",
            createdPosterId: posterId,
          });

          // Upload + attach in a sub-try so we can distinguish the two
          // failure modes: row never created vs row created but image
          // failed (the latter is recoverable from /posters).
          try {
            const uploaded = await uploadPosterImage(draft.file, posterId);
            const ar = await attachImage(posterId, {
              poster_url: uploaded.posterUrl,
              thumbnail_url: uploaded.thumbnailUrl,
              blurhash: uploaded.blurhash,
              image_size_bytes: uploaded.imageSizeBytes,
            });
            if (!ar.ok) throw new Error(ar.error);
            updateDraft(draft.localId, { status: "done" });
            fullSuccessCount++;
          } catch (imgErr) {
            updateDraft(draft.localId, {
              status: "image_failed",
              errorMsg: `海報資料已建立，但圖片上傳失敗：${describeError(imgErr)}。可在「所有海報」找到並重試上傳，請勿重複建立。`,
            });
            imageFailedCount++;
          }
        } catch (e) {
          updateDraft(draft.localId, {
            status: "error",
            errorMsg: describeError(e),
          });
          fullFailureCount++;
        }
      })
    );

    toast.dismiss(tid);
    setSubmitting(false);

    if (fullFailureCount === 0 && imageFailedCount === 0) {
      toast.success(`${fullSuccessCount} 張海報已建立！`);
      setTimeout(() => router.push("/posters"), 1200);
    } else if (fullFailureCount === 0) {
      toast.warning(
        `${fullSuccessCount} 張完整成功，${imageFailedCount} 張海報已建立但圖片上傳失敗（請至「所有海報」重試圖片）`,
        { duration: 12000 }
      );
    } else {
      toast.error(
        `${fullSuccessCount} 張成功${imageFailedCount > 0 ? `，${imageFailedCount} 張缺圖片` : ""}，${fullFailureCount} 張完全失敗（請查看標紅卡片）`,
        { duration: 12000 }
      );
    }
  }

  // ─── Derived counts ───────────────────────────────────────────────
  const idleDrafts = drafts.filter((d) => d.status === "idle");
  const readyCount = idleDrafts.filter(isReady).length;
  const incompleteCount = idleDrafts.length - readyCount;
  const doneCount = drafts.filter((d) => d.status === "done").length;
  const errorCount = drafts.filter(
    (d) => d.status === "error" || d.status === "image_failed"
  ).length;
  const busyCount = drafts.filter(
    (d) => d.status === "creating" || d.status === "uploading"
  ).length;

  // ─── Empty state ──────────────────────────────────────────────────
  if (drafts.length === 0) {
    return (
      <div className="space-y-3">
        <p className="text-sm text-muted-foreground">
          先選照片，再批量填 metadata。
          <Link
            href="/posters/new"
            className="ml-2 underline-offset-2 hover:underline"
          >
            只要新增單張？
          </Link>
        </p>
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/jpeg,image/png,image/webp,image/gif"
          className="hidden"
          onChange={(e) => addFiles(e.target.files)}
        />
        <button
          onClick={() => fileInputRef.current?.click()}
          className="w-full border-2 border-dashed border-border rounded-xl py-14 flex flex-col items-center gap-3 text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
        >
          <ImagePlus className="w-10 h-10" />
          <span className="text-sm font-medium">
            點此選擇照片（可多選）
          </span>
          <span className="text-xs">JPG / PNG / WebP / GIF</span>
          <span className="text-[10px] text-muted-foreground/70 px-4 text-center">
            HEIC（iPhone 拍照預設格式）僅 Safari 可用，其他瀏覽器請改 JPEG
          </span>
        </button>
      </div>
    );
  }

  // ─── Main layout ──────────────────────────────────────────────────
  const applyHasValues = hasApplyValues();
  return (
    <div className="space-y-4 pb-6">
      <input
        ref={fileInputRef}
        type="file"
        multiple
        accept="image/jpeg,image/png,image/webp,image/gif"
        className="hidden"
        onChange={(e) => addFiles(e.target.files)}
      />
      <input
        ref={addMoreRef}
        type="file"
        multiple
        accept="image/jpeg,image/png,image/webp,image/gif"
        className="hidden"
        onChange={(e) => addFiles(e.target.files)}
      />

      {/* ── Apply bar ─────────────────────────────────────────────── */}
      <Card>
        <CardContent className="p-3 space-y-3">
          <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            套用到全部卡片
          </p>

          <div className="space-y-1">
            <Label className="text-xs">作品</Label>
            <WorkPicker
              works={works}
              value={applyWorkId}
              onChange={setApplyWorkId}
              triggerClassName="h-9"
            />
          </div>

          {applyWorkId && (
            <div className="space-y-1">
              <Label className="text-xs">群組</Label>
              <GroupPicker
                workId={applyWorkId}
                workName={works.find((w) => w.id === applyWorkId)?.title_zh}
                groups={groupsByWork[applyWorkId] ?? []}
                value={applyGroupId}
                onChange={setApplyGroupId}
                onGroupCreated={() =>
                  loadGroupsFor(applyWorkId, { force: true })
                }
              />
            </div>
          )}

          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1">
              <Label className="text-xs">地區</Label>
              <Select value={applyRegion} onValueChange={setApplyRegion}>
                <SelectTrigger className="h-9">
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
            <div className="space-y-1">
              <Label className="text-xs">尺寸</Label>
              <Select value={applySizeType} onValueChange={setApplySizeType}>
                <SelectTrigger className="h-9">
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
                <SelectTrigger className="h-9">
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
          </div>

          <Button
            type="button"
            variant="secondary"
            className="w-full"
            onClick={applyAll}
            disabled={submitting || !applyHasValues}
            title={
              !applyHasValues ? "請先在套用欄設定至少一個值" : undefined
            }
          >
            套用到全部 {idleDrafts.length} 張卡片
          </Button>
        </CardContent>
      </Card>

      {/* ── Cards ─────────────────────────────────────────────────── */}
      <div className="space-y-2">
        {drafts.map((draft) => (
          <DraftCard
            key={draft.localId}
            draft={draft}
            works={works}
            groups={
              draft.work_id ? groupsByWork[draft.work_id] ?? [] : []
            }
            onChange={(patch) => updateDraft(draft.localId, patch)}
            onRemove={() => removeDraft(draft.localId)}
            onWorkChange={(newWorkId) => {
              if (newWorkId) loadGroupsFor(newWorkId);
            }}
            onGroupCreated={() => {
              if (draft.work_id)
                loadGroupsFor(draft.work_id, { force: true });
            }}
            disabled={submitting || draft.status !== "idle"}
          />
        ))}
      </div>

      {/* ── Footer ────────────────────────────────────────────────── */}
      <div className="space-y-3 pt-2">
        {(doneCount > 0 || errorCount > 0 || busyCount > 0) && (
          <div className="flex gap-3 text-sm flex-wrap">
            {busyCount > 0 && (
              <span className="flex items-center gap-1 text-muted-foreground">
                <Loader2 className="w-3.5 h-3.5 animate-spin" /> {busyCount}{" "}
                張處理中
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
            disabled={
              submitting || readyCount === 0 || incompleteCount > 0
            }
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

        {incompleteCount > 0 && (
          <p className="text-xs text-destructive">
            還有 {incompleteCount} 張缺少「名稱」或「作品」，全部填完才能建立
          </p>
        )}
        {readyCount === 0 &&
          drafts.some((d) => d.status === "idle") &&
          incompleteCount === 0 && (
            <p className="text-xs text-destructive">
              每張卡片至少需填寫「海報名稱」和「作品」才能建立
            </p>
          )}
      </div>
    </div>
  );
}
