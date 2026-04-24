"use client";

import { useState } from "react";
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
  };
  defaultWorkId?: string;
};

export default function PosterForm({ mode, works, initial, defaultWorkId }: PosterFormProps) {
  const router = useRouter();
  const [workId, setWorkId] = useState(initial?.work_id ?? defaultWorkId ?? "");
  const [posterName, setPosterName] = useState(initial?.poster_name ?? "");
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

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!workId) {
      setError("必須指定作品");
      return;
    }
    setSubmitting(true);
    const supabase = createClient();

    const row: Record<string, unknown> = {
      work_id: workId,
      poster_name: posterName.trim() || null,
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
      row.uploader_id = null; // legacy column; admin-created rows have no uploader
      row.poster_url = ""; // legacy NOT NULL; placeholder swap happens later
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

      <Field label="海報名稱">
        <input
          value={posterName}
          onChange={(e) => setPosterName(e.target.value)}
          placeholder="例：B1 原版 / IMAX 威秀獨家"
          className="w-full"
        />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="地區">
          <select value={region} onChange={(e) => setRegion(e.target.value)} className="w-full">
            {REGIONS.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
        <Field label="發行類型">
          <select value={releaseType} onChange={(e) => setReleaseType(e.target.value)} className="w-full">
            <option value="">—</option>
            {RELEASE_TYPES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="尺寸">
          <select value={sizeType} onChange={(e) => setSizeType(e.target.value)} className="w-full">
            <option value="">—</option>
            {SIZE_TYPES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
        <Field label="通路類型">
          <select value={channelCat} onChange={(e) => setChannelCat(e.target.value)} className="w-full">
            <option value="">—</option>
            {CHANNEL_CATEGORIES.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="通路名稱">
        <input
          value={channelName}
          onChange={(e) => setChannelName(e.target.value)}
          placeholder="例：威秀影城、東寶"
          className="w-full"
        />
      </Field>

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
