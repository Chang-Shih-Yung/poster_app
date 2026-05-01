"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  REGIONS,
  RELEASE_TYPES,
  SIZE_TYPES,
  SIZE_UNITS,
  CHANNEL_CATEGORIES,
  CHANNEL_TYPES,
  CINEMA_RELEASE_TYPES,
  PREMIUM_FORMATS,
  CINEMA_NAMES,
  SOURCE_PLATFORMS,
  MATERIAL_TYPES,
  WORK_KINDS,
} from "@/lib/enums";
import { flattenGroupTree, type FlattenedGroup } from "@/lib/groupTree";
import { DEFAULT_REGION } from "@/lib/keys";
import { createPoster, updatePosterMetadata } from "@/app/actions/posters";
import { applyPromoImageChange } from "@/lib/imageUpload";
import PromoImagePicker, {
  EMPTY_PROMO_STATE,
  type PromoImagePickerState,
} from "@/components/PromoImagePicker";
import { toast } from "sonner";
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
import { MultiSelectDropdown } from "@/components/ui/multi-select";
import { WorkPicker, type WorkOption } from "@/components/WorkPicker";
import { GroupPicker } from "@/components/GroupPicker";
import { DatePicker } from "@/components/DatePicker";
import { AlertTriangle, Loader2 } from "lucide-react";

type InitialPoster = {
  id: string;
  work_id: string | null;
  work_kind?: string | null;
  poster_name: string | null;
  region: string | null;
  year: number | null;
  poster_release_date: string | null;
  poster_release_type: string | null;
  size_type: string | null;
  custom_width: number | null;
  custom_height: number | null;
  size_unit: string | null;
  channel_category: string | null;
  channel_type: string | null;
  channel_name: string | null;
  channel_note: string | null;
  cinema_release_types: string[] | null;
  premium_format: string | null;
  cinema_name: string | null;
  is_exclusive: boolean;
  exclusive_name: string | null;
  material_type: string | null;
  version_label: string | null;
  source_url: string | null;
  source_platform: string | null;
  source_note: string | null;
  is_placeholder: boolean;
  parent_group_id?: string | null;
  // Promo image (cinema flyer / IG campaign / etc.) — optional second image.
  // Edit mode prefills the picker with this; create mode always starts empty.
  promo_image_url?: string | null;
  promo_thumbnail_url?: string | null;
};

type PosterFormProps = {
  mode: "create" | "edit";
  works: WorkOption[];
  initial?: InitialPoster;
  defaultWorkId?: string;
};

// Sentinel "no value" because Radix Select rejects empty string item values.
const NONE = "__none__";

// Aligned with collaborator's poster spec — required fields per spec are
// enforced here at the form layer (zod) before hitting the server action.
const schema = z
  .object({
    work_id: z.string().min(1, "必須指定作品"),
    parent_group_id: z.string(),
    poster_name: z.string().trim().min(1, "海報名稱必填"),
    poster_release_date: z.string(), // YYYY-MM-DD or "" (optional)
    year: z
      .string()
      .trim()
      .refine(
        (v) => /^\d+$/.test(v) && +v >= 1900 && +v <= 2100,
        "發行年份必填（1900-2100 整數）"
      ),
    region: z.string().min(1, "地區必填"),
    poster_release_type: z.string(),
    size_type: z.string().refine((v) => v !== NONE, "尺寸必填"),
    custom_width: z.string(),
    custom_height: z.string(),
    size_unit: z.string(),
    channel_category: z
      .string()
      .refine((v) => v !== NONE, "通路類型必填"),
    channel_type: z.string(),
    channel_name: z.string(),
    channel_note: z.string(),
    cinema_release_types: z.array(z.string()),
    premium_format: z.string(),
    cinema_name: z.string(),
    is_exclusive: z.boolean(),
    exclusive_name: z.string(),
    material_type: z.string(),
    version_label: z.string(),
    source_url: z.string(),
    source_platform: z.string(),
    source_note: z.string(),
  })
  // CUSTOM size requires width + height + unit
  .refine(
    (data) =>
      data.size_type !== "custom" ||
      (data.custom_width.trim() && data.custom_height.trim() && data.size_unit !== NONE),
    {
      message: "尺寸選 CUSTOM 時，寬/高/單位都必填",
      path: ["size_type"],
    }
  );

type FormValues = z.infer<typeof schema>;

export default function PosterForm({
  mode,
  works,
  initial,
  defaultWorkId,
}: PosterFormProps) {
  const router = useRouter();
  const [groupOptions, setGroupOptions] = useState<FlattenedGroup[]>([]);
  const [serverError, setServerError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  // Promo image picker state lives outside RHF — RHF doesn't model File
  // gracefully, and the post-submit upload pipeline needs the raw File
  // anyway. Edit mode preserves the existing URL so the picker shows it
  // until the admin actively replaces or removes.
  const [promoState, setPromoState] = useState<PromoImagePickerState>(
    EMPTY_PROMO_STATE
  );
  const existingPromoUrl =
    initial?.promo_thumbnail_url ?? initial?.promo_image_url ?? null;

  const {
    register,
    handleSubmit,
    control,
    watch,
    setValue,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      work_id: initial?.work_id ?? defaultWorkId ?? "",
      parent_group_id: initial?.parent_group_id ?? NONE,
      poster_name: initial?.poster_name ?? "",
      year: initial?.year != null ? String(initial.year) : "",
      poster_release_date: initial?.poster_release_date ?? "",
      region: initial?.region ?? DEFAULT_REGION,
      poster_release_type: initial?.poster_release_type ?? NONE,
      size_type: initial?.size_type ?? NONE,
      custom_width: initial?.custom_width != null ? String(initial.custom_width) : "",
      custom_height: initial?.custom_height != null ? String(initial.custom_height) : "",
      size_unit: initial?.size_unit ?? NONE,
      channel_category: initial?.channel_category ?? NONE,
      channel_type: initial?.channel_type ?? NONE,
      channel_name: initial?.channel_name ?? "",
      channel_note: initial?.channel_note ?? "",
      cinema_release_types: initial?.cinema_release_types ?? [],
      premium_format: initial?.premium_format ?? NONE,
      cinema_name: initial?.cinema_name ?? NONE,
      is_exclusive: initial?.is_exclusive ?? false,
      exclusive_name: initial?.exclusive_name ?? "",
      material_type: initial?.material_type ?? NONE,
      version_label: initial?.version_label ?? "",
      source_url: initial?.source_url ?? "",
      source_platform: initial?.source_platform ?? NONE,
      source_note: initial?.source_note ?? "",
    },
  });

  const workId = watch("work_id");
  const isExclusive = watch("is_exclusive");
  const sizeType = watch("size_type");
  const channelCategory = watch("channel_category");
  const cinemaReleaseTypes = watch("cinema_release_types");
  const posterReleaseDate = watch("poster_release_date");

  // Auto-fill year from poster_release_date when date changes
  useEffect(() => {
    if (posterReleaseDate && /^\d{4}-\d{2}-\d{2}$/.test(posterReleaseDate)) {
      setValue("year", posterReleaseDate.slice(0, 4));
    }
  }, [posterReleaseDate, setValue]);

  // Conditional logic flags
  const isCinema = channelCategory === "cinema";
  const showPremiumFormat =
    isCinema && cinemaReleaseTypes.includes("premium_format_limited");
  const isCustomSize = sizeType === "custom";

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
    if (!workId) {
      setGroupOptions([]);
      return;
    }
    refetchGroups(workId);
  }, [workId]);

  function onSubmit(values: FormValues) {
    setServerError(null);
    const fromSentinel = (v: string) => (v === NONE ? null : v || null);

    // Normalize cinema-only fields to null when channel_category != cinema
    const cinemaPayload = isCinema
      ? {
          cinema_release_types: values.cinema_release_types,
          premium_format: showPremiumFormat
            ? fromSentinel(values.premium_format)
            : null,
          cinema_name: fromSentinel(values.cinema_name),
        }
      : {
          cinema_release_types: [] as string[],
          premium_format: null,
          cinema_name: null,
        };

    // Normalize CUSTOM-size fields
    const customSizePayload = isCustomSize
      ? {
          custom_width: values.custom_width.trim()
            ? Number(values.custom_width)
            : null,
          custom_height: values.custom_height.trim()
            ? Number(values.custom_height)
            : null,
          size_unit: fromSentinel(values.size_unit),
        }
      : {
          custom_width: null,
          custom_height: null,
          size_unit: null,
        };

    const payload = {
      poster_name: values.poster_name.trim(),
      year: parseInt(values.year, 10),
      poster_release_date: values.poster_release_date || null,
      region: values.region || DEFAULT_REGION,
      poster_release_type: fromSentinel(values.poster_release_type),
      size_type: values.size_type,
      ...customSizePayload,
      channel_category: values.channel_category,
      channel_type: isCinema ? null : fromSentinel(values.channel_type),
      channel_name: values.channel_name.trim() || null,
      channel_note: values.channel_note.trim() || null,
      ...cinemaPayload,
      is_exclusive: values.is_exclusive,
      exclusive_name: values.is_exclusive
        ? values.exclusive_name.trim() || null
        : null,
      material_type: fromSentinel(values.material_type),
      version_label: values.version_label.trim() || null,
      source_url: values.source_url.trim() || null,
      source_platform: fromSentinel(values.source_platform),
      source_note: values.source_note.trim() || null,
    };

    startTransition(async () => {
      // Branch the write so TS sees create's typed return (with id) vs
      // edit's untyped one. Storing targetId as we go keeps the post-write
      // promo-image hook simple regardless of mode.
      let targetId: string;
      if (mode === "create") {
        const r = await createPoster({
          work_id: values.work_id,
          parent_group_id: fromSentinel(values.parent_group_id),
          ...payload,
        });
        if (!r.ok) {
          setServerError(r.error);
          return;
        }
        targetId = r.data.id;
      } else {
        const r = await updatePosterMetadata(initial!.id, {
          parent_group_id: fromSentinel(values.parent_group_id),
          title: payload.poster_name,
          ...payload,
        });
        if (!r.ok) {
          setServerError(r.error);
          return;
        }
        targetId = initial!.id;
      }

      // Promo image side-effect (after metadata write succeeded). Same
      // pipeline regardless of mode. Failures here don't roll back the
      // metadata write — partial success is better than losing a long
      // form. Warn + send the user to the edit page so they can retry.
      const hasPromoChange =
        promoState.file || (promoState.markedForRemoval && existingPromoUrl);
      if (hasPromoChange) {
        const promoR = await applyPromoImageChange(
          targetId,
          promoState,
          existingPromoUrl
        );
        if (!promoR.ok) {
          toast.warning(
            `海報資料已${mode === "create" ? "建立" : "儲存"}，但宣傳圖片處理失敗：${promoR.error}。請進編輯頁重試宣傳圖。`,
            { duration: 12000 }
          );
          router.push(`/posters/${targetId}`);
          return;
        }
      }

      router.push("/posters");
    });
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      {serverError && (
        <Card className="border-destructive/40 bg-destructive/10">
          <CardContent className="p-3 flex items-start gap-2 text-sm text-destructive">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{serverError}</span>
          </CardContent>
        </Card>
      )}

      {/* ── 作品 & 群組 ─────────────────────────────────────────── */}
      <FormField label="作品 *" error={errors.work_id?.message}>
        <Controller
          control={control}
          name="work_id"
          render={({ field }) => (
            <WorkPicker
              works={works}
              value={field.value}
              onChange={field.onChange}
              disabled={pending}
            />
          )}
        />
      </FormField>

      {initial?.work_kind && workId && (
        <WorkKindReadOnly workKind={initial.work_kind} />
      )}

      <FormField
        label="所屬群組"
        helper={!workId ? "先選作品才能看到該作品的群組" : undefined}
      >
        <Controller
          control={control}
          name="parent_group_id"
          render={({ field }) => (
            <GroupPicker
              workId={workId}
              workName={works.find((w) => w.id === workId)?.title_zh}
              groups={groupOptions}
              value={field.value}
              onChange={field.onChange}
              onGroupCreated={() => refetchGroups(workId)}
              disabled={!workId || pending}
            />
          )}
        />
      </FormField>

      {/* ── 基本資訊 ─────────────────────────────────────────────── */}
      <FormField label="海報名稱 *" error={errors.poster_name?.message}>
        <Input
          {...register("poster_name")}
          placeholder="例：B1 原版 / IMAX 威秀獨家"
          disabled={pending}
        />
      </FormField>

      <div className="grid grid-cols-2 gap-3">
        <FormField label="發行精確日期" helper="填日期後年份自動帶入">
          <Controller
            control={control}
            name="poster_release_date"
            render={({ field }) => (
              <DatePicker
                value={field.value}
                onChange={field.onChange}
                disabled={pending}
              />
            )}
          />
        </FormField>
        <FormField label="發行年份 *" error={errors.year?.message}>
          <Input
            type="number"
            min={1900}
            max={2100}
            {...register("year")}
            placeholder="例：2026"
            disabled={pending}
          />
        </FormField>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <FormField label="地區 *" error={errors.region?.message}>
          <Controller
            control={control}
            name="region"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
        <FormField label="發行類型">
          <Controller
            control={control}
            name="poster_release_type"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
      </div>

      {/* ── 尺寸（CUSTOM 時展開 width/height/unit）─────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="尺寸 *" error={errors.size_type?.message}>
          <Controller
            control={control}
            name="size_type"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
        <FormField label="材質">
          <Controller
            control={control}
            name="material_type"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
      </div>

      {isCustomSize && (
        <div className="grid grid-cols-3 gap-2 p-3 rounded border border-border bg-secondary/30">
          <FormField label="寬 *">
            <Input
              type="number"
              step="0.1"
              {...register("custom_width")}
              placeholder="60"
              disabled={pending}
            />
          </FormField>
          <FormField label="高 *">
            <Input
              type="number"
              step="0.1"
              {...register("custom_height")}
              placeholder="90"
              disabled={pending}
            />
          </FormField>
          <FormField label="單位 *">
            <Controller
              control={control}
              name="size_unit"
              render={({ field }) => (
                <Select
                  value={field.value}
                  onValueChange={field.onChange}
                  disabled={pending}
                >
                  <SelectTrigger>
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
              )}
            />
          </FormField>
        </div>
      )}

      <FormField label="版本標記">
        <Input
          {...register("version_label")}
          placeholder="例：v2、25 週年、一刷"
          disabled={pending}
        />
      </FormField>

      {/* ── 通路 ─────────────────────────────────────────────────── */}
      <FormField
        label="通路類型 *"
        error={errors.channel_category?.message}
      >
        <Controller
          control={control}
          name="channel_category"
          render={({ field }) => (
            <Select
              value={field.value}
              onValueChange={field.onChange}
              disabled={pending}
            >
              <SelectTrigger>
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
          )}
        />
      </FormField>

      {/* Cinema-specific fields */}
      {isCinema && (
        <>
          <FormField
            label="影城發行類型"
            helper="可複選；含「特殊廳限定」會顯示放映格式選單"
          >
            <Controller
              control={control}
              name="cinema_release_types"
              render={({ field }) => (
                <MultiSelectDropdown
                  items={CINEMA_RELEASE_TYPES}
                  value={field.value}
                  onChange={field.onChange}
                  placeholder="—"
                  disabled={pending}
                />
              )}
            />
          </FormField>

          {showPremiumFormat && (
            <FormField label="發行影廳（特殊廳）">
              <Controller
                control={control}
                name="premium_format"
                render={({ field }) => (
                  <Select
                    value={field.value}
                    onValueChange={field.onChange}
                    disabled={pending}
                  >
                    <SelectTrigger>
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
                )}
              />
            </FormField>
          )}

          <FormField label="影城">
            <Controller
              control={control}
              name="cinema_name"
              render={({ field }) => (
                <Select
                  value={field.value}
                  onValueChange={field.onChange}
                  disabled={pending}
                >
                  <SelectTrigger>
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
              )}
            />
          </FormField>
        </>
      )}

      {/* Non-cinema channel_type */}
      {!isCinema && channelCategory !== NONE && (
        <FormField label="通路細分">
          <Controller
            control={control}
            name="channel_type"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
      )}

      <FormField label="通路名稱" helper="例：威秀影城、東寶、誠品畫廊">
        <Input
          {...register("channel_name")}
          placeholder="例：威秀影城"
          disabled={pending}
        />
      </FormField>

      <FormField label="通路補充說明">
        <Textarea
          {...register("channel_note")}
          placeholder="例：威秀獨家加贈卡套、限前 100 名"
          disabled={pending}
          rows={2}
        />
      </FormField>

      <FormField
        label="宣傳圖片"
        helper="影院 DM、IG 活動圖、票券優惠等取得方式佐證"
      >
        <PromoImagePicker
          existingUrl={existingPromoUrl}
          state={promoState}
          onChange={setPromoState}
          disabled={pending}
        />
      </FormField>

      <label className="flex items-center gap-2 text-sm text-foreground">
        <input
          type="checkbox"
          {...register("is_exclusive")}
          className="h-4 w-4 rounded border-input"
        />
        <span>獨家</span>
      </label>

      {isExclusive && (
        <FormField label="獨家名稱">
          <Input
            {...register("exclusive_name")}
            placeholder="例：威秀影城"
            disabled={pending}
          />
        </FormField>
      )}

      {/* ── 來源 ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="來源平台">
          <Controller
            control={control}
            name="source_platform"
            render={({ field }) => (
              <Select
                value={field.value}
                onValueChange={field.onChange}
                disabled={pending}
              >
                <SelectTrigger>
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
            )}
          />
        </FormField>
        <FormField label="來源網址">
          <Input type="url" {...register("source_url")} disabled={pending} />
        </FormField>
      </div>

      <FormField label="備註">
        <Textarea {...register("source_note")} disabled={pending} />
      </FormField>

      {/* ── 送出 ─────────────────────────────────────────────────── */}
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

      <p className="text-xs text-muted-foreground pt-2">
        新建海報預設 is_placeholder = true（先用通用剪影顯示）。
      </p>
    </form>
  );
}

function FormField({
  label,
  helper,
  error,
  children,
}: {
  label: string;
  helper?: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
      {error ? (
        <p className="text-xs text-destructive">{error}</p>
      ) : helper ? (
        <p className="text-xs text-muted-foreground">{helper}</p>
      ) : null}
    </div>
  );
}

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
