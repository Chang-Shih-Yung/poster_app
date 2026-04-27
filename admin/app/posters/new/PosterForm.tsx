"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { REGIONS, RELEASE_TYPES, SIZE_TYPES, CHANNEL_CATEGORIES } from "@/lib/enums";

type WorkOption = { id: string; title_zh: string; studio: string | null };

type PosterFormProps = {
  mode: "create" | "edit";
  works: WorkOption[];
  initial?: {
    id: string;
    work_id: string | null;
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

export default function PosterForm({ mode, works, initial, defaultWorkId }: PosterFormProps) {
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
  const [releaseType, setReleaseType] = useState(initial?.poster_release_type ?? "");
  const [sizeType, setSizeType] = useState(initial?.size_type ?? "");
  const [channelCat, setChannelCat] = useState(initial?.channel_category ?? "");
  const [channelName, setChannelName] = useState(initial?.channel_name ?? "");
  const [isExclusive, setIsExclusive] = useState(initial?.is_exclusive ?? false);
  const [exclusiveName, setExclusiveName] = useState(initial?.exclusive_name ?? "");
  const [materialType, setMaterialType] = useState(initial?.material_type ?? "");
  const [versionLabel, setVersionLabel] = useState(initial?.version_label ?? "");
  const [sourceUrl, setSourceUrl] = useState(initial?.source_url ?? "");
  const [sourceNote, setSourceNote] = useState(initial?.source_note ?? "");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load poster_groups for the selected work whenever workId changes,
  // and flatten the tree into an indented option list.
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
      const flat = flattenTree(data ?? []);
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
    if (yearTrimmed && (Number.isNaN(yearInt!) || yearInt! < 1900 || yearInt! > 2100)) {
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
      // is_placeholder defaults to true DB-side; image_url stays NULL until
      // admin uploads the real scan (Phase 2 work).
      row.title = posterName.trim() || "(待命名)"; // legacy NOT NULL on posters.title
      row.status = "approved"; // admin-created rows bypass the review queue
      row.poster_url = ""; // legacy NOT NULL; placeholder swap happens later
      // uploader_id is NOT NULL on the legacy posters table — the admin who
      // creates the row counts as the "uploader" until we refactor to nullable.
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
        <div className="p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
          {error}
        </div>
      )}

      <Field label="作品 *" required>
        <select
          value={workId}
          onChange={(e) => setWorkId(e.target.value)}
          className="w-full"
          required
        >
          <option value="">── 選擇作品 ──</option>
          {works.map((w) => (
            <option key={w.id} value={w.id}>
              {w.studio ? `[${w.studio}] ` : ""}{w.title_zh}
            </option>
          ))}
        </select>
      </Field>

      <Field label="所屬群組">
        <select
          value={parentGroupId}
          onChange={(e) => setParentGroupId(e.target.value)}
          className="w-full"
          disabled={!workId}
        >
          <option value="">── 不屬於任何群組 ──</option>
          {groupOptions.map((g) => (
            <option key={g.id} value={g.id}>
              {g.label}
            </option>
          ))}
        </select>
        {!workId && (
          <span className="block text-xs text-textFaint mt-1">
            先選作品才能看到該作品的群組
          </span>
        )}
      </Field>

      <Field label="海報名稱">
        <input
          value={posterName}
          onChange={(e) => setPosterName(e.target.value)}
          placeholder="例：B1 原版 / IMAX 威秀獨家"
          className="w-full"
        />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="發行年份">
          <input
            type="number"
            min={1900}
            max={2100}
            value={year}
            onChange={(e) => setYear(e.target.value)}
            placeholder="例：2026"
            className="w-full"
          />
        </Field>
        <Field label="地區">
          <select value={region} onChange={(e) => setRegion(e.target.value)} className="w-full">
            {REGIONS.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="發行類型">
          <select value={releaseType} onChange={(e) => setReleaseType(e.target.value)} className="w-full">
            <option value="">—</option>
            {RELEASE_TYPES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
        <Field label="尺寸">
          <select value={sizeType} onChange={(e) => setSizeType(e.target.value)} className="w-full">
            <option value="">—</option>
            {SIZE_TYPES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="通路類型">
          <select value={channelCat} onChange={(e) => setChannelCat(e.target.value)} className="w-full">
            <option value="">—</option>
            {CHANNEL_CATEGORIES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
        <Field label="通路名稱">
          <input
            value={channelName}
            onChange={(e) => setChannelName(e.target.value)}
            placeholder="例：威秀影城、東寶"
            className="w-full"
          />
        </Field>
      </div>

      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={isExclusive}
          onChange={(e) => setIsExclusive(e.target.checked)}
        />
        <span>獨家</span>
      </label>

      {isExclusive && (
        <Field label="獨家名稱">
          <input
            value={exclusiveName}
            onChange={(e) => setExclusiveName(e.target.value)}
            placeholder="例：威秀影城"
            className="w-full"
          />
        </Field>
      )}

      <div className="grid grid-cols-2 gap-3">
        <Field label="材質">
          <input
            value={materialType}
            onChange={(e) => setMaterialType(e.target.value)}
            placeholder="例：霧面紙 / 金箔紙"
            className="w-full"
          />
        </Field>
        <Field label="版本標記">
          <input
            value={versionLabel}
            onChange={(e) => setVersionLabel(e.target.value)}
            placeholder="例：v2、25 週年"
            className="w-full"
          />
        </Field>
      </div>

      <Field label="來源網址">
        <input
          type="url"
          value={sourceUrl}
          onChange={(e) => setSourceUrl(e.target.value)}
          className="w-full"
        />
      </Field>

      <Field label="備註">
        <textarea
          value={sourceNote}
          onChange={(e) => setSourceNote(e.target.value)}
          className="w-full min-h-[60px]"
        />
      </Field>

      <div className="pt-4 flex gap-3">
        <button
          type="submit"
          disabled={submitting}
          className="px-4 py-2 rounded-md bg-accent text-bg font-medium disabled:opacity-50"
        >
          {submitting ? "儲存中…" : mode === "create" ? "建立" : "儲存"}
        </button>
        <button
          type="button"
          onClick={() => router.back()}
          className="px-4 py-2 rounded-md border border-line2 text-textMute"
        >
          取消
        </button>
      </div>

      <p className="text-xs text-textFaint pt-2">
        ⓘ 新建海報預設 is_placeholder = true（先用通用剪影顯示）。Phase 2
        後台會加拖拉上傳真實圖片的功能。
      </p>
    </form>
  );
}

function Field({ label, required, children }: { label: string; required?: boolean; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="block text-xs uppercase tracking-wider text-textMute mb-1.5">
        {label}
      </span>
      {children}
    </label>
  );
}

/**
 * Flatten a list of poster_groups (with parent_group_id) into a list of
 * { id, label } where label is the FULL PATH from root, e.g.
 * "美麗華 / 2025 / 測試子子群組". Native HTML <select> options can't
 * render true visual indent (browsers strip leading whitespace), so we
 * encode the hierarchy in the label itself — unambiguous and readable
 * regardless of the dropdown's positioning.
 */
type GroupRow = {
  id: string;
  name: string;
  parent_group_id: string | null;
  display_order: number;
};

function flattenTree(rows: GroupRow[]): { id: string; label: string }[] {
  const childrenMap = new Map<string | null, GroupRow[]>();
  for (const r of rows) {
    const arr = childrenMap.get(r.parent_group_id) ?? [];
    arr.push(r);
    childrenMap.set(r.parent_group_id, arr);
  }
  const out: { id: string; label: string }[] = [];
  function walk(parent: string | null, prefix: string[]) {
    const kids = (childrenMap.get(parent) ?? []).sort((a, b) =>
      a.display_order !== b.display_order
        ? a.display_order - b.display_order
        : a.name.localeCompare(b.name)
    );
    for (const k of kids) {
      const path = [...prefix, k.name];
      out.push({ id: k.id, label: path.join(" / ") });
      walk(k.id, path);
    }
  }
  walk(null, []);
  return out;
}
