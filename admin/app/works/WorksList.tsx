"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, Plus, Loader2, AlertTriangle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

/**
 * Flat list of every work in the catalogue, with inline rename + delete +
 * count badge — same affordances as the tree, but without the parent
 * context. Useful for "show me everything I've created" cleanup work.
 */

type Work = {
  id: string;
  studio: string | null;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  movie_release_year: number | null;
  poster_count: number;
};

function describeError(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === "string") return e;
  if (e && typeof e === "object") {
    const obj = e as Record<string, unknown>;
    const parts: string[] = [];
    if (typeof obj.message === "string") parts.push(obj.message);
    if (typeof obj.details === "string") parts.push(obj.details);
    if (typeof obj.code === "string") parts.push(`code: ${obj.code}`);
    if (parts.length > 0) return parts.join(" · ");
    try {
      return JSON.stringify(e);
    } catch {
      return "(unknown error)";
    }
  }
  return String(e);
}

export default function WorksList({ initial }: { initial: Work[] }) {
  const router = useRouter();
  const [works, setWorks] = useState<Work[]>(initial);
  const [editing, setEditing] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [newStudio, setNewStudio] = useState("");
  const [newTitle, setNewTitle] = useState("");

  const supabase = createClient();

  async function rename(work: Work, newTitle: string) {
    if (!newTitle.trim() || newTitle === work.title_zh) {
      setEditing(null);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { error } = await supabase
        .from("works")
        .update({ title_zh: newTitle.trim() })
        .eq("id", work.id);
      if (error) throw error;
      setWorks((list) =>
        list.map((w) =>
          w.id === work.id ? { ...w, title_zh: newTitle.trim() } : w
        )
      );
      setEditing(null);
      router.refresh();
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(false);
    }
  }

  async function remove(work: Work) {
    if (
      !confirm(
        `刪除作品「${work.title_zh}」？\n底下所有群組與海報（${work.poster_count} 張）都會一起刪除。\n此操作不可復原。`
      )
    )
      return;
    setBusy(true);
    setError(null);
    try {
      const { error } = await supabase
        .from("works")
        .delete()
        .eq("id", work.id);
      if (error) throw error;
      setWorks((list) => list.filter((w) => w.id !== work.id));
      router.refresh();
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(false);
    }
  }

  async function createNew() {
    if (!newTitle.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const { data, error } = await supabase
        .from("works")
        .insert({
          title_zh: newTitle.trim(),
          studio: newStudio.trim() || null,
          work_kind: "movie",
        })
        .select(
          "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count"
        )
        .single();
      if (error) throw error;
      setWorks((list) => [data as Work, ...list]);
      setAdding(false);
      setNewStudio("");
      setNewTitle("");
      router.refresh();
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="sticky z-30 bg-bg/95 backdrop-blur-sm flex items-center justify-between px-4 md:px-0 py-2.5 mb-1 top-[calc(env(safe-area-inset-top,0px)+52px)] md:top-0">
        <span className="text-xs text-textMute">{works.length} 部作品</span>
        <button
          onClick={() => setAdding(true)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md bg-accent text-bg font-medium"
        >
          <Plus className="w-4 h-4" /> 新增作品
        </button>
      </div>

      {adding && (
        <div className="mx-4 md:mx-0 mb-3 p-3 rounded-md bg-surfaceRaised border border-line2 space-y-2">
          <input
            autoFocus
            value={newStudio}
            onChange={(e) => setNewStudio(e.target.value)}
            placeholder="（選填）所屬分類（電影 / 演唱會 ...）"
            className="w-full"
            disabled={busy}
          />
          <input
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            placeholder="作品名稱（中文）"
            className="w-full"
            disabled={busy}
            onKeyDown={(e) => {
              if (e.key === "Enter") createNew();
              if (e.key === "Escape") {
                setAdding(false);
                setNewStudio("");
                setNewTitle("");
              }
            }}
          />
          <div className="flex gap-2">
            <button
              onClick={createNew}
              disabled={busy || !newTitle.trim()}
              className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium disabled:opacity-50 inline-flex items-center gap-1"
            >
              {busy && <Loader2 className="w-3 h-3 animate-spin" />}
              {busy ? "建立中" : "建立"}
            </button>
            <button
              onClick={() => {
                setAdding(false);
                setNewStudio("");
                setNewTitle("");
              }}
              disabled={busy}
              className="px-3 py-1.5 text-xs rounded-md border border-line2 text-textMute"
            >
              取消
            </button>
          </div>
        </div>
      )}

      {error && (
        <div className="mx-4 md:mx-0 mb-3 p-3 rounded-md bg-red-900/40 border border-red-700 text-sm flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0 text-red-400" />
          <span className="flex-1">{error}</span>
          <button
            onClick={() => setError(null)}
            className="text-textMute hover:text-text shrink-0"
          >
            關閉
          </button>
        </div>
      )}

      {works.length === 0 ? (
        <ul className="border-y border-line1 md:border md:rounded-lg md:bg-surface">
          <li className="px-4 py-10 text-center text-textFaint text-sm">
            還沒有作品。
            <br />
            <button
              onClick={() => setAdding(true)}
              className="text-accent inline-flex items-center gap-1 mt-2"
            >
              <Plus className="w-4 h-4" /> 新增第一筆
            </button>
          </li>
        </ul>
      ) : (
        <WorksSections
          works={works}
          editing={editing}
          editValue={editValue}
          busy={busy}
          onStartEdit={(w) => {
            setEditValue(w.title_zh);
            setEditing(w.id);
          }}
          onCancelEdit={() => setEditing(null)}
          onChangeEdit={setEditValue}
          onCommitEdit={rename}
          onRemove={remove}
        />
      )}
    </>
  );
}

/**
 * Sections works by their `studio` field, preserving the newest-first
 * order within each section. Section header shows the studio name +
 * total count; "(未分類)" collects works whose studio is null.
 */
function WorksSections({
  works,
  editing,
  editValue,
  busy,
  onStartEdit,
  onCancelEdit,
  onChangeEdit,
  onCommitEdit,
  onRemove,
}: {
  works: Work[];
  editing: string | null;
  editValue: string;
  busy: boolean;
  onStartEdit: (w: Work) => void;
  onCancelEdit: () => void;
  onChangeEdit: (v: string) => void;
  onCommitEdit: (w: Work, newTitle: string) => void;
  onRemove: (w: Work) => void;
}) {
  // Bucket by studio in iteration order so the studio whose newest work
  // appears first in the source list comes first in the rendered sections.
  const sections = new Map<string, Work[]>();
  for (const w of works) {
    const k = w.studio ?? "(未分類)";
    if (!sections.has(k)) sections.set(k, []);
    sections.get(k)!.push(w);
  }

  return (
    <div className="space-y-4">
      {[...sections.entries()].map(([studio, items]) => (
        <div key={studio}>
          <div className="px-4 md:px-0 pb-1 text-xs text-textFaint">
            {studio} ({items.length})
          </div>
          <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
            {items.map((w, i) => (
              <li key={w.id}>
                {editing === w.id ? (
                  <div className="bg-surfaceRaised py-2 px-4">
                    <div className="flex gap-2">
                      <input
                        autoFocus
                        value={editValue}
                        onChange={(e) => onChangeEdit(e.target.value)}
                        placeholder="作品中文名"
                        className="flex-1"
                        disabled={busy}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") onCommitEdit(w, editValue);
                          if (e.key === "Escape") onCancelEdit();
                        }}
                      />
                      <button
                        onClick={() => onCommitEdit(w, editValue)}
                        disabled={busy || !editValue.trim()}
                        className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium disabled:opacity-50"
                      >
                        {busy ? "儲存中" : "確認"}
                      </button>
                      <button
                        onClick={onCancelEdit}
                        disabled={busy}
                        className="px-3 py-1.5 text-xs rounded-md border border-line2 text-textMute"
                      >
                        取消
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center px-4 py-3 min-h-[60px]">
                    <span className="text-xs text-textFaint tabular-nums shrink-0 w-7">
                      {i + 1}.
                    </span>
                    <a
                      href={`/works/${w.id}`}
                      className="min-w-0 flex-1 mr-2 hover:no-underline"
                    >
                      <span className="flex items-baseline gap-1">
                        <span className="text-sm text-text truncate">
                          {w.title_zh}
                        </span>
                        {w.poster_count > 0 && (
                          <span className="text-xs text-textFaint tabular-nums shrink-0">
                            ({w.poster_count})
                          </span>
                        )}
                        <button
                          onClick={(e) => {
                            e.preventDefault();
                            onStartEdit(w);
                          }}
                          className="shrink-0 text-textFaint hover:text-text p-1 -m-1"
                          aria-label="重新命名"
                          title="重新命名"
                        >
                          <Pencil className="w-3 h-3" />
                        </button>
                      </span>
                      {(w.title_en || w.work_kind) && (
                        <span className="block text-xs text-textFaint truncate mt-0.5">
                          {[w.title_en, w.work_kind].filter(Boolean).join(" · ")}
                        </span>
                      )}
                    </a>
                    <button
                      onClick={() => onRemove(w)}
                      className="w-9 h-9 flex items-center justify-center text-textMute hover:text-red-400 shrink-0"
                      aria-label="刪除"
                      title="刪除"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
