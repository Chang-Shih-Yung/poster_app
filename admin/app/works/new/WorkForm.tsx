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

export default function WorkForm({ mode, initial }: WorkFormProps) {
  const router = useRouter();
  const [studio, setStudio] = useState(initial?.studio ?? "");
  const [titleZh, setTitleZh] = useState(initial?.title_zh ?? "");
  const [titleEn, setTitleEn] = useState(initial?.title_en ?? "");
  const [workKind, setWorkKind] = useState(initial?.work_kind ?? "movie");
  const [releaseYear, setReleaseYear] = useState(
    initial?.movie_release_year?.toString() ?? ""
  );
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!titleZh.trim()) {
      setError("中文名必填");
      return;
    }
    setSubmitting(true);

    const supabase = createClient();
    const row = {
      studio: studio.trim() || null,
      title_zh: titleZh.trim(),
      title_en: titleEn.trim() || null,
      work_kind: workKind,
      movie_release_year: releaseYear.trim() ? parseInt(releaseYear, 10) : null,
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
          placeholder="例：吉卜力 / Marvel / 新海誠 作品"
          className="w-full"
        />
      </Field>

      <Field label="中文名 *" required>
        <input
          value={titleZh}
          onChange={(e) => setTitleZh(e.target.value)}
          className="w-full"
          required
        />
      </Field>

      <Field label="英文名">
        <input
          value={titleEn}
          onChange={(e) => setTitleEn(e.target.value)}
          className="w-full"
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

      <Field label="發行年份">
        <input
          type="number"
          min={1900}
          max={2100}
          value={releaseYear}
          onChange={(e) => setReleaseYear(e.target.value)}
          className="w-full"
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
