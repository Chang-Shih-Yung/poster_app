"use client";

import { useEffect, useRef, useState } from "react";
import {
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  ImagePlus,
  Loader2,
  Trash2,
  AlertTriangle,
} from "lucide-react";
import {
  REGIONS,
  SIZE_TYPES,
  SIZE_UNITS,
  CHANNEL_CATEGORIES,
  CINEMA_RELEASE_TYPES,
  PREMIUM_FORMATS,
  CINEMA_NAMES,
  MATERIAL_TYPES,
  SOURCE_PLATFORMS,
  PRICE_TYPES,
} from "@/lib/enums";
// SetPicker 已從批量移除（建立時沒有 poster id 不能掛 sibling）；admin
// 在 /posters/[id] 編輯頁用 PosterCombinationField 加同組合海報。
import type { FlattenedGroup } from "@/lib/groupTree";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { FormField } from "@/components/ui/form-field";
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
import { MultiSelectDropdown } from "@/components/ui/multi-select";
import PromoImageGallery from "@/components/PromoImageGallery";
import { cn } from "@/lib/utils";
import { NONE, type DraftPoster } from "./_shared";

/**
 * One row in the batch import grid. Pure presentational — all state
 * (drafts, groups cache) lives in BatchImport. Splitting this out keeps
 * the parent's submit/validation logic testable without an HTML tree
 * mock for every form field.
 */
export function DraftCard({
  draft,
  works,
  groups,
  onChange,
  onRemove,
  onWorkChange,
  onGroupCreated,
  onWorkCreated,
  disabled,
}: {
  draft: DraftPoster;
  works: WorkOption[];
  /** Groups for THIS card's work_id. Parent maintains the cache. */
  groups: FlattenedGroup[];
  onChange: (patch: Partial<DraftPoster>) => void;
  onRemove: () => void;
  /** Called when the card's work_id changes — parent uses this to
   * pre-fetch the groups list for the new work. */
  onWorkChange: (newWorkId: string) => void;
  /** Called after a new group is created via the GroupPicker — parent
   * re-fetches groups for this work. */
  onGroupCreated: () => void;
  /** Called after a new work is created from the inline WorkPicker dialog
   *  — parent should refetch the works list so the new row shows up. */
  onWorkCreated: () => void;
  disabled: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const [previewBroken, setPreviewBroken] = useState(false);
  const replaceInputRef = useRef<HTMLInputElement>(null);

  // Reset the broken-preview state whenever the underlying file changes
  // (e.g. user clicked the thumbnail to swap photos).
  useEffect(() => {
    setPreviewBroken(false);
  }, [draft.previewUrl]);

  function handleReplaceFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    URL.revokeObjectURL(draft.previewUrl);
    onChange({
      file,
      previewUrl: URL.createObjectURL(file),
    });
    e.target.value = "";
  }

  const statusIcon =
    draft.status === "creating" || draft.status === "uploading" ? (
      <Loader2 className="w-4 h-4 animate-spin text-muted-foreground shrink-0" />
    ) : draft.status === "done" ? (
      <CheckCircle2 className="w-4 h-4 text-green-600 shrink-0" />
    ) : draft.status === "error" || draft.status === "image_failed" ? (
      <AlertTriangle className="w-4 h-4 text-destructive shrink-0" />
    ) : null;

  const statusLabel =
    draft.status === "creating"
      ? "建立中…"
      : draft.status === "uploading"
        ? "上傳中…"
        : null;

  // image_failed is a "soft" failure: the poster row exists, only the
  // image upload portion failed. Surface it in amber rather than red so
  // the admin doesn't think they need to retry the whole row.
  const cardChrome = cn(
    "transition-colors",
    draft.status === "done" && "border-green-500/40 bg-green-500/5",
    draft.status === "error" && "border-destructive/40 bg-destructive/5",
    draft.status === "image_failed" && "border-amber-500/50 bg-amber-500/5"
  );

  return (
    <Card className={cardChrome}>
      <CardContent className="p-3 space-y-2">
        <input
          ref={replaceInputRef}
          type="file"
          // Explicit list mirrors BatchImport's inputs — `image/*` alone
          // makes some Chrome builds grey out HEIC in the picker even
          // though we support converting it via heic2any.
          accept="image/jpeg,image/png,image/webp,image/gif,image/heic,image/heif,.heic,.heif"
          className="hidden"
          onChange={handleReplaceFile}
        />

        {/* ── Header row ────────────────────────────────────────────── */}
        <div className="flex items-start gap-2.5">
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

          <div className="flex-1 min-w-0">
            <Input
              value={draft.name}
              onChange={(e) => onChange({ name: e.target.value })}
              placeholder="海報官方名稱"
              disabled={disabled}
              // Name is optional now — no orange "missing" border. We could
              // surface other missing required fields (work / year / region /
              // size / channel) here later but isReady() already gates the
              // submit button, so the current UX (red error message + button
              // disabled) covers it.
              className="h-9"
            />
            {(draft.status === "error" || draft.status === "image_failed") &&
              draft.errorMsg && (
                <p
                  className={cn(
                    "text-xs mt-1 break-words",
                    draft.status === "image_failed"
                      ? "text-amber-700 dark:text-amber-500"
                      : "text-destructive"
                  )}
                >
                  {draft.errorMsg}
                </p>
              )}
            {statusLabel && (
              <p className="text-xs text-muted-foreground mt-1">
                {statusLabel}
              </p>
            )}
          </div>

          {statusIcon && <div className="mt-2">{statusIcon}</div>}

          {draft.status === "idle" && (
            <Button
              type="button"
              variant="quiet"
              size="icon"
              className="mt-0.5 shrink-0"
              onClick={() => setExpanded((v) => !v)}
              aria-label={expanded ? "收合" : "展開"}
            >
              {expanded ? (
                <ChevronUp className="w-4 h-4" />
              ) : (
                <ChevronDown className="w-4 h-4" />
              )}
            </Button>
          )}

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
            {/* spec #1 — 作品台灣官方名稱（必填）= 選中的作品 title_zh
               admin 點下拉可挑既有作品，或從「+ 新增作品…」inline 建。 */}
            <FormField label="作品台灣官方名稱" required size="compact">
              <WorkPicker
                works={works}
                value={draft.work_id}
                onChange={(v) => {
                  onChange({ work_id: v, parent_group_id: NONE });
                  onWorkChange(v);
                }}
                onWorkCreated={onWorkCreated}
                triggerClassName="h-9"
              />
            </FormField>

            {/* spec #2 — 作品英文官方名稱（必填）= 選中作品的 title_en。
                Read-only 顯示（要改在「+ 新增作品」dialog 內或 /works/[id]）。
                如果作品的 title_en 是空（spec wave 3 後新作品強制 title_en
                必填，舊作品可能空），秀紅字提示。 */}
            {draft.work_id && (() => {
              const w = works.find((x) => x.id === draft.work_id);
              const titleEn = w?.title_en?.trim() ?? "";
              return (
                <FormField label="作品英文官方名稱" required size="compact">
                  <div
                    className={cn(
                      "h-9 px-3 flex items-center text-sm rounded-md border bg-muted/30",
                      titleEn
                        ? "text-foreground border-border"
                        : "text-destructive border-destructive/30"
                    )}
                  >
                    {titleEn || "（此作品尚未填英文名，請至作品設定補上）"}
                  </div>
                </FormField>
              );
            })()}

            {draft.work_id && (
              <FormField label="群組" size="compact">
                <GroupPicker
                  workId={draft.work_id}
                  workName={works.find((w) => w.id === draft.work_id)?.title_zh}
                  groups={groups}
                  value={draft.parent_group_id}
                  onChange={(v) => onChange({ parent_group_id: v })}
                  onGroupCreated={onGroupCreated}
                />
              </FormField>
            )}

            <div className="grid grid-cols-2 gap-2">
              <FormField label="海報發行日" size="compact">
                <DatePicker
                  value={draft.poster_release_date}
                  onChange={(v) => {
                    const yearPatch = /^\d{4}-\d{2}-\d{2}$/.test(v)
                      ? { year: v.slice(0, 4) }
                      : {};
                    onChange({ poster_release_date: v, ...yearPatch });
                  }}
                  className="h-9"
                />
              </FormField>
              <FormField label="海報發行年份" required size="compact">
                <Input
                  type="number"
                  min={1900}
                  max={2100}
                  value={draft.year}
                  onChange={(e) => onChange({ year: e.target.value })}
                  placeholder="例：2026"
                  className="h-9"
                />
              </FormField>
            </div>

            <FormField label="海報發行地" required size="compact">
              <Select
                value={draft.region}
                onValueChange={(v) => onChange({ region: v })}
              >
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
            </FormField>
            {/* Top-level「發行類型」單選已移除 — 2026-05-02 spec 沒有這個概念，
                發行類型只存在於影城條件多選（見下方 cinema_release_types）。
                poster_release_type DB 欄位保留（不破壞舊資料），新海報會送 NONE。*/}

            {/* 規格 + 材質 */}
            <div className="grid grid-cols-2 gap-2">
              <FormField label="海報發行規格" required size="compact">
                <Select
                  value={draft.size_type}
                  onValueChange={(v) => onChange({ size_type: v })}
                >
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
              </FormField>
              <FormField label="海報發行材質" size="compact">
                <Select
                  value={draft.material_type}
                  onValueChange={(v) => onChange({ material_type: v })}
                >
                  <SelectTrigger className="h-9">
                    <SelectValue placeholder="—" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {MATERIAL_TYPES.map((r) => (
                      <SelectItem key={r.value} value={r.value}>
                        {r.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
            </div>

            {/* CUSTOM 尺寸：寬高單位 */}
            {draft.size_type === "custom" && (
              <div className="grid grid-cols-3 gap-2 p-2 rounded border border-border bg-secondary/30">
                <FormField label="寬" required size="compact">
                  <Input
                    type="number"
                    step="0.1"
                    value={draft.custom_width}
                    onChange={(e) =>
                      onChange({ custom_width: e.target.value })
                    }
                    placeholder="60"
                    className="h-9"
                  />
                </FormField>
                <FormField label="高" required size="compact">
                  <Input
                    type="number"
                    step="0.1"
                    value={draft.custom_height}
                    onChange={(e) =>
                      onChange({ custom_height: e.target.value })
                    }
                    placeholder="90"
                    className="h-9"
                  />
                </FormField>
                <FormField label="單位" required size="compact">
                  <Select
                    value={draft.size_unit}
                    onValueChange={(v) => onChange({ size_unit: v })}
                  >
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder="—" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {SIZE_UNITS.map((u) => (
                        <SelectItem key={u.value} value={u.value}>
                          {u.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </FormField>
              </div>
            )}

            {/* 海報發行通路 */}
            <FormField label="海報發行通路" required size="compact">
              <Select
                value={draft.channel_category}
                onValueChange={(v) =>
                  onChange({
                    channel_category: v,
                    // Reset cinema-only fields when switching away from cinema
                    ...(v !== "cinema" && {
                      cinema_release_types: [],
                      premium_format: NONE,
                      cinema_name: NONE,
                    }),
                  })
                }
              >
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
            </FormField>

            {/* Cinema-specific (only when channel_category=cinema) */}
            {draft.channel_category === "cinema" && (
              <>
                <FormField label="發行類型（可複選）" size="compact">
                  <MultiSelectDropdown
                    items={CINEMA_RELEASE_TYPES}
                    value={draft.cinema_release_types}
                    onChange={(v) => onChange({ cinema_release_types: v })}
                    placeholder="—"
                  />
                </FormField>
                {draft.cinema_release_types.includes(
                  "premium_format_limited"
                ) && (
                  <FormField label="發行影廳" size="compact">
                    <Select
                      value={draft.premium_format}
                      onValueChange={(v) => onChange({ premium_format: v })}
                    >
                      <SelectTrigger className="h-9">
                        <SelectValue placeholder="—" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value={NONE}>—</SelectItem>
                        {PREMIUM_FORMATS.map((r) => (
                          <SelectItem key={r.value} value={r.value}>
                            {r.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </FormField>
                )}
                <FormField label="海報發行影城" size="compact">
                  <Select
                    value={draft.cinema_name}
                    onValueChange={(v) => onChange({ cinema_name: v })}
                  >
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder="—" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {CINEMA_NAMES.map((r) => (
                        <SelectItem key={r.value} value={r.value}>
                          {r.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </FormField>
              </>
            )}

            {/* 「通路細分」(channel_type)、「通路名稱」(channel_name)、
                「通路補充說明」(channel_note)、「獨家」(is_exclusive +
                exclusive_name)、「版本標記」(version_label) 都不在合夥人
                2026-05-02 spec — UI 全部移除，DB 欄位保留（不破壞舊資料）。
                Spec 順序對齊：13 售價 → 14 組合 → 15 平台 → 16 連結 →
                17 補充說明 → 18 圖檔 → 26 公開 */}

            {/* ── #13 海報發行售價 ──────────────────────────────── */}
            <div className="grid grid-cols-2 gap-2">
              <FormField label="海報發行售價" size="compact">
                <Select
                  value={draft.price_type}
                  onValueChange={(v) =>
                    onChange({
                      price_type: v,
                      // 切回 NONE / gift 時清掉金額
                      ...(v !== "paid" && { price_amount: "" }),
                    })
                  }
                >
                  <SelectTrigger className="h-9">
                    <SelectValue placeholder="—" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {PRICE_TYPES.map((p) => (
                      <SelectItem key={p.value} value={p.value}>
                        {p.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
              {draft.price_type === "paid" && (
                <FormField label="售價金額（TWD）" required size="compact">
                  <Input
                    type="number"
                    step="1"
                    min="0"
                    value={draft.price_amount}
                    onChange={(e) =>
                      onChange({ price_amount: e.target.value })
                    }
                    placeholder="例：188"
                    className="h-9"
                  />
                </FormField>
              )}
            </div>

            {/* ── #14 海報發行組合 ──────────────────────────────── */}
            {/* 批量是 create-only。海報還沒 ID 時不能掛 sibling。
                建好後在 /posters/[id] 編輯頁裡用 PosterCombinationField
                加入同組合的其他海報。 */}
            <FormField label="海報發行組合" size="compact">
              <div className="text-xs text-muted-foreground rounded-md border border-dashed border-input bg-secondary/30 p-2.5">
                建立海報後，到編輯頁加入「同組合的其他海報」。
              </div>
            </FormField>

            {/* ── 是否限量（合夥人後加） ─────────────────────── */}
            <FormField label="是否限量" size="compact">
              <div className="flex items-center gap-2 flex-wrap">
                <label className="flex items-center gap-2 select-none cursor-pointer">
                  <input
                    type="checkbox"
                    checked={draft.is_limited}
                    onChange={(e) =>
                      onChange({
                        is_limited: e.target.checked,
                        ...(!e.target.checked && { limited_quantity: "" }),
                      })
                    }
                    disabled={disabled}
                    className="h-4 w-4 rounded border-input"
                  />
                  <span className="text-sm">
                    {draft.is_limited ? "限量" : "非限量"}
                  </span>
                </label>
                {draft.is_limited && (
                  <div className="flex items-center gap-1.5">
                    <span className="text-xs text-muted-foreground">限量</span>
                    <Input
                      type="number"
                      min="1"
                      step="1"
                      value={draft.limited_quantity}
                      onChange={(e) =>
                        onChange({ limited_quantity: e.target.value })
                      }
                      placeholder="例：100"
                      className="h-9 w-24"
                    />
                    <span className="text-xs text-muted-foreground">張</span>
                  </div>
                )}
              </div>
            </FormField>

            {/* ── #15 #16 來源平台 + 連結 ──────────────────────── */}
            <div className="grid grid-cols-2 gap-2">
              <FormField label="資料來源平台" size="compact">
                <Select
                  value={draft.source_platform}
                  onValueChange={(v) => onChange({ source_platform: v })}
                >
                  <SelectTrigger className="h-9">
                    <SelectValue placeholder="—" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={NONE}>—</SelectItem>
                    {SOURCE_PLATFORMS.map((r) => (
                      <SelectItem key={r.value} value={r.value}>
                        {r.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
              <FormField label="資料來源連結" size="compact">
                <Input
                  type="url"
                  value={draft.source_url}
                  onChange={(e) => onChange({ source_url: e.target.value })}
                  className="h-9"
                />
              </FormField>
            </div>

            {/* ── #18 海報發行資訊（圖檔，可多張） ──────────────── */}
            {/* 跟單張 PosterForm 共用 PromoImageGallery 元件 — create
                mode 收 File[]，submit pipeline 逐張上傳 */}
            <FormField label="海報發行資訊" size="compact">
              <PromoImageGallery
                posterId={null}
                pendingFiles={draft.promoFiles}
                onPendingChange={(files) => onChange({ promoFiles: files })}
                disabled={draft.status !== "idle"}
              />
            </FormField>

            {/* ── #29 備註（= source_note，跟單張 PosterForm 同位置）── */}
            <FormField label="備註" size="compact">
              <Textarea
                value={draft.source_note}
                onChange={(e) => onChange({ source_note: e.target.value })}
                rows={2}
              />
            </FormField>

            {/* ── #26 是否公開 ─────────────────────────────────── */}
            <label className="flex items-center gap-2 text-sm select-none cursor-pointer">
              <input
                type="checkbox"
                checked={draft.is_public}
                onChange={(e) => onChange({ is_public: e.target.checked })}
                disabled={disabled}
                className="h-4 w-4 rounded border-input"
              />
              <span>
                {draft.is_public ? "公開" : "未公開（admin 限定）"}
              </span>
            </label>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
