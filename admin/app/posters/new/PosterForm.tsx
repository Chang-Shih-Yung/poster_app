"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  REGIONS,
  SIZE_TYPES,
  SIZE_UNITS,
  CHANNEL_CATEGORIES,
  CINEMA_RELEASE_TYPES,
  PREMIUM_FORMATS,
  CINEMA_NAMES,
  SOURCE_PLATFORMS,
  MATERIAL_TYPES,
  WORK_KINDS,
  PRICE_TYPES,
} from "@/lib/enums";
import { flattenGroupTree, type FlattenedGroup } from "@/lib/groupTree";
import { DEFAULT_REGION } from "@/lib/keys";
import { createPoster, updatePosterMetadata } from "@/app/actions/posters";
import PromoImageGallery from "@/components/PromoImageGallery";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { FormField } from "@/components/ui/form-field";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useUnsavedChangesGuard } from "@/components/useUnsavedChangesGuard";
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
import PosterCombinationField from "@/components/PosterCombinationField";
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
  // Public visibility — admin can ship a poster but keep it hidden from
  // the Flutter feed (per partner spec). Default true on create.
  is_public?: boolean | null;
  // 售價 (#13 spec)
  price_type?: string | null;
  price_amount?: number | string | null;
  // 套票組合 (#14 spec)
  set_id?: string | null;
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
    // poster_name is OPTIONAL per 2026-05-02 spec.
    poster_name: z.string().trim(),
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
    is_public: z.boolean(),
    // 售價 — type 是 sentinel/value，amount 是 numeric string（解析在 submit）
    price_type: z.string(),
    price_amount: z.string(),
    // set_id 不在 zod 內 — 海報發行組合走 PosterCombinationField 直接呼
    // 叫 server action linkPosters / unlinkPoster，不經 form submit。
  })
  // price_type='paid' 時 price_amount 必填且為正數
  .refine(
    (data) =>
      data.price_type !== "paid" ||
      (/^\d+(\.\d+)?$/.test(data.price_amount.trim()) &&
        Number(data.price_amount) > 0),
    {
      message: "選「金額」時，請填入大於 0 的售價",
      path: ["price_amount"],
    }
  )
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
  // 宣傳圖片改 1:N gallery — 由 PromoImageGallery 自己 fetch / mutate，
  // 不再經過 RHF state 或 onSubmit。create mode 看不到（沒 ID），admin
  // 建好海報後在編輯頁加。
  // （unsaved-changes guard 在 useForm 之後 wire — 需要 isDirty 等 state）

  const {
    register,
    handleSubmit,
    control,
    watch,
    setValue,
    formState: { errors, isDirty, isSubmitSuccessful },
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
      // Default true for new rows; preserve current state on edit.
      is_public: initial?.is_public ?? true,
      price_type: initial?.price_type ?? NONE,
      price_amount:
        initial?.price_amount != null ? String(initial.price_amount) : "",
    },
  });

  // 防呆：表單有未儲存修改時，攔截 in-app navigation（mobile 滑回、
  // 點 BottomTab、breadcrumb link 等）。pending=true 期間（正在儲存）
  // 不擋 — startTransition 內部會 router.push 那條路不該被攔。submit
  // 成功後 isSubmitSuccessful 變 true，guard 自動解除。
  const guard = useUnsavedChangesGuard(
    isDirty && !pending && !isSubmitSuccessful
  );

  const workId = watch("work_id");
  // is_exclusive watcher removed — 獨家欄位 not in spec, UI dropped.
  // The form state still carries is_exclusive (via RHF) so existing values
  // get preserved on edit; we just don't render the toggle.
  const sizeType = watch("size_type");
  const channelCategory = watch("channel_category");
  const cinemaReleaseTypes = watch("cinema_release_types");
  const posterReleaseDate = watch("poster_release_date");
  const priceType = watch("price_type");

  // PosterCombinationField self-fetches its own data via server actions
  // (listSiblings / listAllPostersForPicker) — no parent-side cache needed.

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
      is_public: values.is_public,
      // 售價：'gift' 不帶金額；'paid' 必有金額；NONE = null
      price_type: fromSentinel(values.price_type),
      price_amount:
        values.price_type === "paid" && values.price_amount.trim()
          ? Number(values.price_amount)
          : null,
      // set_id 不在這個 payload — PosterCombinationField 直接呼叫
      // linkPosters / unlinkPoster 寫 DB，不經 form submit。
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

      // 宣傳圖片現在走 PromoImageGallery 直接呼 server action，不再用
      // form submit 帶 file。Create flow 結束直接跳列表；admin 想加
      // 宣傳圖回編輯頁加。
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

      {/* ── 作品 (spec #1+#2) & 群組 ──────────────────────────────── */}
      {/* spec #1 — 作品台灣官方名稱（必填）= 選中作品的 title_zh */}
      <FormField
        label="作品台灣官方名稱"
        required
        error={errors.work_id?.message}
      >
        <Controller
          control={control}
          name="work_id"
          render={({ field }) => (
            <WorkPicker
              works={works}
              value={field.value}
              onChange={field.onChange}
              // After inline create, re-run the server component so the
              // works prop includes the brand-new row. router.refresh()
              // preserves client state (form values) so this is safe.
              onWorkCreated={() => router.refresh()}
              disabled={pending}
            />
          )}
        />
      </FormField>

      {/* spec #2 — 作品英文官方名稱（必填）= 選中作品的 title_en，read-only */}
      {workId && (() => {
        const w = works.find((x) => x.id === workId);
        const titleEn = w?.title_en?.trim() ?? "";
        return (
          <FormField label="作品英文官方名稱" required>
            <div
              className={`h-10 px-3 flex items-center text-sm rounded-md border bg-muted/30 ${
                titleEn
                  ? "text-foreground border-border"
                  : "text-destructive border-destructive/30"
              }`}
            >
              {titleEn || "（此作品尚未填英文名，請改用「+ 新增作品」或至作品設定補上）"}
            </div>
          </FormField>
        );
      })()}

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
      <FormField label="海報官方名稱" error={errors.poster_name?.message}>
        <Input
          {...register("poster_name")}
          placeholder="例：B1 原版 / IMAX 威秀獨家"
          disabled={pending}
        />
      </FormField>

      <div className="grid grid-cols-2 gap-3">
        <FormField label="海報發行日" helper="填日期後年份自動帶入">
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
        <FormField label="海報發行年份" required error={errors.year?.message}>
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
        <FormField label="海報發行地" required error={errors.region?.message}>
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
        {/* Top-level「發行類型」單選已移除 — 合夥人 2026-05-02 spec 沒有
            這個概念，發行類型只存在於影城條件多選。poster_release_type
            DB 欄位保留（不破壞舊資料），新表單送 null。*/}
      </div>

      {/* ── 規格（CUSTOM 時展開 width/height/unit）─────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="海報發行規格" required error={errors.size_type?.message}>
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
        <FormField label="海報發行材質">
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
          <FormField label="寬" required>
            <Input
              type="number"
              step="0.1"
              {...register("custom_width")}
              placeholder="60"
              disabled={pending}
            />
          </FormField>
          <FormField label="高" required>
            <Input
              type="number"
              step="0.1"
              {...register("custom_height")}
              placeholder="90"
              disabled={pending}
            />
          </FormField>
          <FormField label="單位" required>
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

      {/* 「版本標記」(version_label)、「獨家」(is_exclusive/exclusive_name)、
          「通路名稱」(channel_name)、「通路補充說明」(channel_note)、
          「通路細分」(channel_type) 都不在合夥人 2026-05-02 spec 表內，
          UI 移除。DB 欄位保留（不破壞舊資料 + 不寫值就是 null）。 */}

      {/* ── 通路 ─────────────────────────────────────────────────── */}
      <FormField
        label="海報發行通路" required
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
            label="發行類型"
            helper="可複選；含「特殊影廳限定」會顯示發行影廳選單"
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
            <FormField label="發行影廳">
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

          <FormField label="海報發行影城">
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

      {/* 「通路細分」(channel_type)、「通路名稱」(channel_name)、
          「通路補充說明」(channel_note) 都不在 spec — UI 移除，DB 欄位保留。 */}

      {/* ── #13 海報發行售價 ─────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="海報發行售價">
          <Controller
            control={control}
            name="price_type"
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
                  {PRICE_TYPES.map((p) => (
                    <SelectItem key={p.value} value={p.value}>
                      {p.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </FormField>
        {priceType === "paid" && (
          <FormField
            label="售價金額（TWD）"
            required
            error={errors.price_amount?.message}
          >
            <Input
              type="number"
              step="1"
              min="0"
              {...register("price_amount")}
              placeholder="例：188"
              disabled={pending}
            />
          </FormField>
        )}
      </div>

      {/* ── #14 海報發行組合 ─────────────────────────────────────── */}
      {/* 「是 / 否」+ sibling picker — 不思考 set 物件，直接挑同組合的
          其他海報；後端用 poster_sets 表做底層存儲。create mode 看不到
          picker（沒 ID 不能掛 sibling），元件會顯示提示。 */}
      <FormField
        label="海報發行組合"
        helper="是 = 跟其他海報是同一發行組合（套票、IG 活動套組等）；否 = 單張獨立發行"
      >
        <PosterCombinationField
          posterId={mode === "edit" ? initial!.id : null}
          disabled={pending}
        />
      </FormField>

      {/* ── #15 #16 資料來源平台 + 連結 ──────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="資料來源平台">
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
        <FormField label="資料來源連結">
          <Input type="url" {...register("source_url")} disabled={pending} />
        </FormField>
      </div>

      {/* ── #17 資料來源補充說明 ─────────────────────────────────── */}
      <FormField label="資料來源補充說明">
        <Textarea {...register("source_note")} disabled={pending} />
      </FormField>

      {/* ── #18 海報發行資訊（圖檔，可多張）─────────────────────── */}
      <FormField label="海報發行資訊">
        <PromoImageGallery
          posterId={mode === "edit" ? initial!.id : null}
          disabled={pending}
        />
      </FormField>

      {/* ── 公開狀態 ─────────────────────────────────────────────── */}
      <FormField
        label="是否公開"
        helper="關閉後，這張海報不會出現在 Flutter app 的公開 feed（admin 仍可看見）"
      >
        <Controller
          control={control}
          name="is_public"
          render={({ field }) => (
            <label className="flex items-center gap-3 select-none cursor-pointer">
              <input
                type="checkbox"
                checked={field.value}
                onChange={(e) => field.onChange(e.target.checked)}
                disabled={pending}
                className="h-4 w-4 rounded border-input"
              />
              <span className="text-sm">
                {field.value ? "已公開" : "未公開（admin 限定）"}
              </span>
            </label>
          )}
        />
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

      {/* 離開頁面前的 unsaved-changes 二次確認 — 跟 BatchImport 同款
          shadcn AlertDialog，避免 admin 改了一半的表單被靜悄悄丟掉。 */}
      <AlertDialog
        open={guard.pending}
        onOpenChange={(open) => {
          if (!open) guard.cancel();
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>確定離開？</AlertDialogTitle>
            <AlertDialogDescription>
              這張海報有尚未儲存的修改，離開後會消失。要離開請確認，否則點「留在頁面」回去按「{mode === "create" ? "建立" : "儲存"}」。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={guard.cancel}>
              留在頁面
            </AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={guard.confirm}
            >
              捨棄並離開
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </form>
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
