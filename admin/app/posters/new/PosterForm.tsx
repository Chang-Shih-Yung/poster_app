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
  CHANNEL_CATEGORIES,
  CHANNEL_TYPES,
  SOURCE_PLATFORMS,
  MATERIAL_TYPES,
  WORK_KINDS,
} from "@/lib/enums";
import { flattenGroupTree, type FlattenedGroup } from "@/lib/groupTree";
import { DEFAULT_REGION } from "@/lib/keys";
import { createPoster, updatePosterMetadata } from "@/app/actions/posters";
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
  poster_release_date: string | null;   // YYYY-MM-DD or null
  poster_release_type: string | null;
  size_type: string | null;
  channel_category: string | null;
  channel_type: string | null;
  channel_name: string | null;
  is_exclusive: boolean;
  exclusive_name: string | null;
  material_type: string | null;
  version_label: string | null;
  source_url: string | null;
  source_platform: string | null;
  source_note: string | null;
  // Collector flags
  signed: boolean;
  numbered: boolean;
  edition_number: string | null;
  linen_backed: boolean;
  licensed: boolean;
  is_placeholder: boolean;
  parent_group_id?: string | null;
};

type PosterFormProps = {
  mode: "create" | "edit";
  works: WorkOption[];
  initial?: InitialPoster;
  defaultWorkId?: string;
};

// Sentinel "no value" because Radix Select rejects empty string item values.
const NONE = "__none__";

const schema = z.object({
  work_id: z.string().min(1, "必須指定作品"),
  parent_group_id: z.string(),
  poster_name: z.string().trim().min(1, "海報名稱必填"),
  year: z
    .string()
    .trim()
    .refine(
      (v) => v === "" || (/^\d+$/.test(v) && +v >= 1900 && +v <= 2100),
      "年份格式錯誤（1900-2100 整數）"
    ),
  poster_release_date: z.string(),   // YYYY-MM-DD or ""
  region: z.string(),
  poster_release_type: z.string(),
  size_type: z.string(),
  channel_category: z.string(),
  channel_type: z.string(),
  channel_name: z.string(),
  is_exclusive: z.boolean(),
  exclusive_name: z.string(),
  material_type: z.string(),
  version_label: z.string(),
  source_url: z.string(),
  source_platform: z.string(),
  source_note: z.string(),
  // Collector flags
  signed: z.boolean(),
  numbered: z.boolean(),
  edition_number: z.string(),
  linen_backed: z.boolean(),
  licensed: z.boolean(),
});

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
      channel_category: initial?.channel_category ?? NONE,
      channel_type: initial?.channel_type ?? NONE,
      channel_name: initial?.channel_name ?? "",
      is_exclusive: initial?.is_exclusive ?? false,
      exclusive_name: initial?.exclusive_name ?? "",
      material_type: initial?.material_type ?? NONE,
      version_label: initial?.version_label ?? "",
      source_url: initial?.source_url ?? "",
      source_platform: initial?.source_platform ?? NONE,
      source_note: initial?.source_note ?? "",
      signed: initial?.signed ?? false,
      numbered: initial?.numbered ?? false,
      edition_number: initial?.edition_number ?? "",
      linen_backed: initial?.linen_backed ?? false,
      licensed: initial?.licensed ?? true,
    },
  });

  const workId = watch("work_id");
  const isExclusive = watch("is_exclusive");
  const numbered = watch("numbered");
  const posterReleaseDate = watch("poster_release_date");

  // Auto-fill year from poster_release_date when date changes
  useEffect(() => {
    if (posterReleaseDate && /^\d{4}-\d{2}-\d{2}$/.test(posterReleaseDate)) {
      setValue("year", posterReleaseDate.slice(0, 4));
    }
  }, [posterReleaseDate, setValue]);

  // Load groups for the selected work. Extracted so GroupPicker's
  // "+ 新增頂層群組" can re-fetch after creating a new group.
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
    if (!workId) { setGroupOptions([]); return; }
    refetchGroups(workId);
  }, [workId]);

  function onSubmit(values: FormValues) {
    setServerError(null);
    const yearInt = values.year ? parseInt(values.year, 10) : null;
    const fromSentinel = (v: string) => (v === NONE ? null : v || null);

    const payload = {
      poster_name: values.poster_name.trim(),
      year: yearInt,
      poster_release_date: values.poster_release_date || null,
      region: values.region || DEFAULT_REGION,
      poster_release_type: fromSentinel(values.poster_release_type),
      size_type: fromSentinel(values.size_type),
      channel_category: fromSentinel(values.channel_category),
      channel_type: fromSentinel(values.channel_type),
      channel_name: values.channel_name.trim() || null,
      is_exclusive: values.is_exclusive,
      exclusive_name: values.is_exclusive ? values.exclusive_name.trim() || null : null,
      material_type: fromSentinel(values.material_type),
      version_label: values.version_label.trim() || null,
      source_url: values.source_url.trim() || null,
      source_platform: fromSentinel(values.source_platform),
      source_note: values.source_note.trim() || null,
      signed: values.signed,
      numbered: values.numbered,
      edition_number: values.numbered ? values.edition_number.trim() || null : null,
      linen_backed: values.linen_backed,
      licensed: values.licensed,
    };

    startTransition(async () => {
      const r =
        mode === "create"
          ? await createPoster({
              work_id: values.work_id,
              parent_group_id: fromSentinel(values.parent_group_id),
              ...payload,
            })
          : await updatePosterMetadata(initial!.id, {
              parent_group_id: fromSentinel(values.parent_group_id),
              title: payload.poster_name,
              ...payload,
            });
      if (!r.ok) {
        setServerError(r.error);
        return;
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

      <FormField label="所屬群組" helper={!workId ? "先選作品才能看到該作品的群組" : undefined}>
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
        <FormField label="發行年份" error={errors.year?.message}>
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
        <FormField label="地區">
          <Controller
            control={control}
            name="region"
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {REGIONS.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
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
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {RELEASE_TYPES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </FormField>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <FormField label="尺寸">
          <Controller
            control={control}
            name="size_type"
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {SIZE_TYPES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
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
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {MATERIAL_TYPES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </FormField>
      </div>

      <FormField label="版本標記">
        <Input
          {...register("version_label")}
          placeholder="例：v2、25 週年、一刷"
          disabled={pending}
        />
      </FormField>

      {/* ── 通路 ─────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <FormField label="通路類型">
          <Controller
            control={control}
            name="channel_category"
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {CHANNEL_CATEGORIES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </FormField>
        <FormField label="通路細分">
          <Controller
            control={control}
            name="channel_type"
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {CHANNEL_TYPES.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </FormField>
      </div>

      <FormField label="通路名稱">
        <Input
          {...register("channel_name")}
          placeholder="例：威秀影城、東寶"
          disabled={pending}
        />
      </FormField>

      <label className="flex items-center gap-2 text-sm text-foreground">
        <input type="checkbox" {...register("is_exclusive")} className="h-4 w-4 rounded border-input" />
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
              <Select value={field.value} onValueChange={field.onChange} disabled={pending}>
                <SelectTrigger><SelectValue placeholder="—" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>—</SelectItem>
                  {SOURCE_PLATFORMS.map((r) => (
                    <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
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

      {/* ── 收藏者資訊 ────────────────────────────────────────────── */}
      <div className="pt-1">
        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
          收藏者資訊
        </p>
        <div className="space-y-2">
          <label className="flex items-center gap-2 text-sm text-foreground">
            <input type="checkbox" {...register("signed")} className="h-4 w-4 rounded border-input" />
            <span>有簽名 signed</span>
          </label>
          <label className="flex items-center gap-2 text-sm text-foreground">
            <input type="checkbox" {...register("numbered")} className="h-4 w-4 rounded border-input" />
            <span>限量編號 numbered</span>
          </label>
          {numbered && (
            <FormField label="編號">
              <Input
                {...register("edition_number")}
                placeholder="例：42/325"
                disabled={pending}
              />
            </FormField>
          )}
          <label className="flex items-center gap-2 text-sm text-foreground">
            <input type="checkbox" {...register("linen_backed")} className="h-4 w-4 rounded border-input" />
            <span>亞麻布背裱 linen backed</span>
          </label>
          <label className="flex items-center gap-2 text-sm text-foreground">
            <input type="checkbox" {...register("licensed")} className="h-4 w-4 rounded border-input" defaultChecked />
            <span>官方授權 licensed</span>
          </label>
        </div>
      </div>

      {/* ── 送出 ─────────────────────────────────────────────────── */}
      <div className="pt-4 flex gap-3">
        <Button type="submit" disabled={pending}>
          {pending && <Loader2 className="animate-spin" />}
          {pending ? "儲存中…" : mode === "create" ? "建立" : "儲存"}
        </Button>
        <Button type="button" variant="outline" onClick={() => router.back()} disabled={pending}>
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
      <span className="text-xs uppercase tracking-wider text-muted-foreground">類型</span>
      <Badge variant="muted">{label}</Badge>
    </div>
  );
}
