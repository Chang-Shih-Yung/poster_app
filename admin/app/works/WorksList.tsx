"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Pencil, Trash2, Plus, Loader2, AlertTriangle, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";

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
    <div className="px-4 md:px-0">
      <div className="sticky top-[calc(env(safe-area-inset-top,0px)+52px)] md:top-14 z-30 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80 -mx-4 md:mx-0 px-4 md:px-0 py-2.5 mb-3 flex items-center justify-between">
        <span className="text-xs text-muted-foreground">
          {works.length} 部作品
        </span>
        <Button size="sm" onClick={() => setAdding(true)}>
          <Plus />
          新增作品
        </Button>
      </div>

      {adding && (
        <Card className="mb-3">
          <CardContent className="p-3 space-y-2">
            <Input
              autoFocus
              value={newStudio}
              onChange={(e) => setNewStudio(e.target.value)}
              placeholder="（選填）所屬分類"
              disabled={busy}
            />
            <Input
              value={newTitle}
              onChange={(e) => setNewTitle(e.target.value)}
              placeholder="作品名稱（中文）"
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
              <Button
                size="sm"
                onClick={createNew}
                disabled={busy || !newTitle.trim()}
              >
                {busy && <Loader2 className="animate-spin" />}
                {busy ? "建立中" : "建立"}
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  setAdding(false);
                  setNewStudio("");
                  setNewTitle("");
                }}
                disabled={busy}
              >
                取消
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {error && (
        <Card className="mb-3 border-destructive/40 bg-destructive/10">
          <CardContent className="p-3 flex items-start gap-2 text-sm text-destructive">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span className="flex-1">{error}</span>
            <Button
              variant="quiet"
              size="icon"
              onClick={() => setError(null)}
              aria-label="關閉"
            >
              <X />
            </Button>
          </CardContent>
        </Card>
      )}

      {works.length === 0 ? (
        <Card>
          <CardContent className="py-10 text-center text-muted-foreground text-sm">
            <div>還沒有作品。</div>
            <Button
              variant="link"
              onClick={() => setAdding(true)}
              className="mt-2"
            >
              <Plus />
              新增第一筆
            </Button>
          </CardContent>
        </Card>
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
    </div>
  );
}

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
          <div className="pb-1 text-xs text-muted-foreground">
            {studio} ({items.length})
          </div>
          <Card>
            <CardContent className="p-0">
              <ul className="divide-y divide-border">
                {items.map((w) => (
                  <li key={w.id}>
                    {editing === w.id ? (
                      <div className="bg-secondary/40 py-2 px-3 flex gap-2">
                        <Input
                          autoFocus
                          value={editValue}
                          onChange={(e) => onChangeEdit(e.target.value)}
                          placeholder="作品中文名"
                          disabled={busy}
                          onKeyDown={(e) => {
                            if (e.key === "Enter") onCommitEdit(w, editValue);
                            if (e.key === "Escape") onCancelEdit();
                          }}
                        />
                        <Button
                          size="sm"
                          onClick={() => onCommitEdit(w, editValue)}
                          disabled={busy || !editValue.trim()}
                        >
                          {busy ? "儲存中" : "確認"}
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={onCancelEdit}
                          disabled={busy}
                        >
                          取消
                        </Button>
                      </div>
                    ) : (
                      <div className="flex items-center px-4 py-3 min-h-[60px]">
                        <Link
                          href={`/works/${w.id}`}
                          className="min-w-0 flex-1 mr-2 hover:no-underline"
                        >
                          <span className="flex items-baseline gap-2">
                            <span className="text-sm text-foreground truncate">
                              {w.title_zh}
                            </span>
                            {w.poster_count > 0 && (
                              <Badge variant="muted">{w.poster_count}</Badge>
                            )}
                          </span>
                          {(w.title_en || w.work_kind) && (
                            <span className="block text-xs text-muted-foreground truncate mt-0.5">
                              {[w.title_en, w.work_kind].filter(Boolean).join(" · ")}
                            </span>
                          )}
                        </Link>
                        <Button
                          variant="quiet"
                          size="icon"
                          onClick={() => onStartEdit(w)}
                          aria-label="重新命名"
                          title="重新命名"
                        >
                          <Pencil />
                        </Button>
                        <Button
                          variant="quiet"
                          size="icon"
                          onClick={() => onRemove(w)}
                          aria-label="刪除"
                          title="刪除"
                          className="hover:text-destructive"
                        >
                          <Trash2 />
                        </Button>
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        </div>
      ))}
    </div>
  );
}
