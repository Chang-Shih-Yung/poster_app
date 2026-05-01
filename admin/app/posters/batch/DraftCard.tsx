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
  CHANNEL_TYPES,
  CINEMA_RELEASE_TYPES,
  PREMIUM_FORMATS,
  CINEMA_NAMES,
  RELEASE_TYPES,
  MATERIAL_TYPES,
  SOURCE_PLATFORMS,
} from "@/lib/enums";
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
import PromoImagePicker, {
  type PromoImagePickerState,
} from "@/components/PromoImagePicker";
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
              placeholder="海報名稱 *"
              disabled={disabled}
              className={cn(
                "h-9",
                !draft.name.trim() &&
                  draft.status === "idle" &&
                  "border-orange-400/60"
              )}
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
            <FormField label="作品" required size="compact">
              <WorkPicker
                works={works}
                value={draft.work_id}
                onChange={(v) => {
                  onChange({ work_id: v, parent_group_id: NONE });
                  onWorkChange(v);
                }}
                triggerClassName="h-9"
              />
            </FormField>

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
              <FormField label="發行日期" size="compact">
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
              <FormField label="發行年份" required size="compact">
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

            <div className="grid grid-cols-2 gap-2">
              <FormField label="地區" required size="compact">
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
              <FormField label="發行類型" size="compact">
                <Select
                  value={draft.poster_release_type}
                  onValueChange={(v) => onChange({ poster_release_type: v })}
                >
                  <SelectTrigger className="h-9">
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
              </FormField>
            </div>

            {/* 尺寸 + 材質 */}
            <div className="grid grid-cols-2 gap-2">
              <FormField label="尺寸" required size="compact">
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
              <FormField label="材質" size="compact">
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

            {/* 通路類型 */}
            <FormField label="通路類型" required size="compact">
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
                <FormField label="影城發行類型（可複選）" size="compact">
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
                <FormField label="影城" size="compact">
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

            {/* Non-cinema channel_type */}
            {draft.channel_category !== "cinema" &&
              draft.channel_category !== NONE && (
                <FormField label="通路細分" size="compact">
                  <Select
                    value={draft.channel_type}
                    onValueChange={(v) => onChange({ channel_type: v })}
                  >
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder="—" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {CHANNEL_TYPES.map((r) => (
                        <SelectItem key={r.value} value={r.value}>
                          {r.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </FormField>
              )}

            <FormField label="通路名稱" size="compact">
              <Input
                value={draft.channel_name}
                onChange={(e) => onChange({ channel_name: e.target.value })}
                placeholder="例：威秀影城"
                className="h-9"
              />
            </FormField>

            <FormField label="通路補充說明" size="compact">
              <Textarea
                value={draft.channel_note}
                onChange={(e) => onChange({ channel_note: e.target.value })}
                placeholder="例：威秀獨家加贈卡套"
                rows={2}
              />
            </FormField>

            <FormField label="宣傳圖片" size="compact">
              <PromoImagePicker
                existingUrl={null}
                state={{
                  file: draft.promoFile,
                  // Batch import is create-only; markedForRemoval doesn't
                  // apply (no existing image to remove). Picker keeps the
                  // flag to preserve its API; we feed false here.
                  markedForRemoval: false,
                }}
                onChange={(s: PromoImagePickerState) =>
                  onChange({ promoFile: s.file })
                }
                disabled={draft.status !== "idle"}
                compact
              />
            </FormField>

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

            <FormField label="版本標記" size="compact">
              <Input
                value={draft.version_label}
                onChange={(e) => onChange({ version_label: e.target.value })}
                placeholder="例：v2、25 週年"
                className="h-9"
              />
            </FormField>

            <div className="grid grid-cols-2 gap-2">
              <FormField label="來源平台" size="compact">
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
              <FormField label="來源網址" size="compact">
                <Input
                  type="url"
                  value={draft.source_url}
                  onChange={(e) => onChange({ source_url: e.target.value })}
                  className="h-9"
                />
              </FormField>
            </div>

            <FormField label="備註" size="compact">
              <Textarea
                value={draft.source_note}
                onChange={(e) => onChange({ source_note: e.target.value })}
                rows={2}
              />
            </FormField>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
