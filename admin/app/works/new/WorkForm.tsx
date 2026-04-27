"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { WORK_KINDS } from "@/lib/enums";

type WorkFormProps = {
  mode: "create" | "edit";
  initial?: {
    id: string;
    studio: string | null;
    title_zh: string;
    title_en: string | null;
    work_kind: string;
    movie_release_year: number | null;
  };
};

/**
 * "Work" in the DB schema, but Henry's mental model treats it as a
 * "群組" (the same word he uses for poster_groups one level deeper).
 * UI labels reflect that. The form intentionally captures only what's
 * meaningful at the group level — name, kind, IP holder. Per-poster
 * data (year, region, channel, etc.) lives on PosterForm.
 */
export default function WorkForm({ mode, initial }: WorkFormProps) {
  const router = useRouter();
  const [studio, setStudio] = useState(initial?.studio ?? "");
  const [titleZh, setTitleZh] = useState(initial?.title_zh ?? "");
  const [workKind, setWorkKind] = useState(initial?.work_kind ?? "movie");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!titleZh.trim()) {
      setError("群組名稱必填");
      return;
    }
    setSubmitting(true);

    const supabase = createClient();
    const row = {
      studio: studio.trim() || null,
      title_zh: titleZh.trim(),
      work_kind: workKind,
    };

    const { error } =
      mode === "create"
        ? await supabase.from("works").insert(row)
        : await supabase.from("works").update(row).eq("id", initial!.id);

    setSubmitting(false);

    if (error) {
      setError(error.message);
      return;
    }

    router.push("/works");
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      {error && (
        <div className="p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
          {error}
        </div>
      )}

      <Field label="Studio / IP 持有者">
        <input
          value={studio}
          onChange={(e) => setStudio(e.target.value)}
          placeholder="例：漫威 / 吉卜力 / 新海誠 作品"
          className="w-full"
        />
      </Field>

      <Field label="群組名稱 *" required>
        <input
          value={titleZh}
          onChange={(e) => setTitleZh(e.target.value)}
          placeholder="例：復仇者系列 / 神隱少女"
          className="w-full"
          required
        />
      </Field>

      <Field label="類型">
        <select
          value={workKind}
          onChange={(e) => setWorkKind(e.target.value)}
          className="w-full"
        >
          {WORK_KINDS.map((k) => (
            <option key={k.value} value={k.value}>
              {k.label}
            </option>
          ))}
        </select>
      </Field>

      <p className="text-[11px] text-textFaint">
        年份、地區、通路等資訊請在每張海報單獨設定（每張海報可能對應不同
        重映、版本、通路）。
      </p>

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
    </form>
  );
}

function Field({
  label,
  required,
  children,
}: {
  label: string;
  required?: boolean;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="block text-xs uppercase tracking-wider text-textMute mb-1.5">
        {label}
      </span>
      {children}
    </label>
  );
}
