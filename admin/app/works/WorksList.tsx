"use client";

import { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { Pencil, Trash2, Plus, Loader2, AlertTriangle, X } from "lucide-react";
import { NULL_STUDIO_KEY } from "@/lib/keys";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  renameWork,
  deleteWork,
  createWork,
  loadWorksPage,
} from "@/app/actions/works";

type Work = {
  id: string;
  studio: string | null;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  movie_release_year: number | null;
  poster_count: number;
  created_at?: string;
};

export default function WorksList({
  initial,
  initialCursor,
}: {
  initial: Work[];
  initialCursor?: string | null;
}) {
  // The first batch comes from the server-rendered page; subsequent
  // batches are appended via loadWorksPage on "載入更多". A
  // server-side mutation (rename/delete/create) calls revalidatePath
  // which re-renders the page → the appended pages disappear, but
  // that's fine because the user just acted and the new server data
  // is more authoritative than our accumulated copy.
  const [rows, setRows] = useState<Work[]>(initial);
  const [cursor, setCursor] = useState<string | null>(initialCursor ?? null);
  const [editing, setEditing] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [newStudio, setNewStudio] = useState("");
  const [newTitle, setNewTitle] = useState("");
  const [pending, startTransition] = useTransition();
  const [loadingMore, setLoadingMore] = useState(false);

  // Reset to the freshly-rendered server batch whenever the server
  // pushes new initial props down (i.e. after a mutation revalidates).
  useEffect(() => {
    setRows(initial);
    setCursor(initialCursor ?? null);
  }, [initial, initialCursor]);

  function loadMore() {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    setError(null);
    (async () => {
      const r = await loadWorksPage({ cursor });
      if (!r.ok) {
        setError(r.error);
      } else {
        setRows((prev) => [...prev, ...r.data.rows]);
        setCursor(r.data.nextCursor);
      }
      setLoadingMore(false);
    })();
  }

  function commitRename(work: Work, newTitle: string) {
    if (!newTitle.trim() || newTitle === work.title_zh) {
      setEditing(null);
      return;
    }
    startTransition(async () => {
      const r = await renameWork(work.id, newTitle);
      if (!r.ok) setError(r.error);
      else setEditing(null);
    });
  }

  function remove(work: Work) {
    if (
      !confirm(
        `刪除作品「${work.title_zh}」？\n底下所有群組與海報（${work.poster_count} 張）都會一起刪除。\n此操作不可復原。`
      )
    )
      return;
    startTransition(async () => {
      const r = await deleteWork(work.id);
      if (!r.ok) setError(r.error);
    });
  }

  function createNew() {
    if (!newTitle.trim()) return;
    startTransition(async () => {
      const r = await createWork({
        title_zh: newTitle,
        studio: newStudio.trim() || null,
        work_kind: "movie",
      });
      if (!r.ok) {
        setError(r.error);
        return;
      }
      setAdding(false);
      setNewStudio("");
      setNewTitle("");
    });
  }

  return (
    <div className="px-4 md:px-0">
      <div className="sticky top-[calc(env(safe-area-inset-top,0px)+52px)] md:top-14 z-30 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80 -mx-4 md:mx-0 px-4 md:px-0 py-2.5 mb-3 flex items-center justify-between">
        <span className="text-xs text-muted-foreground">
          {rows.length} 部作品{cursor ? "（還有更多）" : ""}
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
              disabled={pending}
            />
            <Input
              value={newTitle}
              onChange={(e) => setNewTitle(e.target.value)}
              placeholder="作品名稱（中文）"
              disabled={pending}
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
                disabled={pending || !newTitle.trim()}
              >
                {pending && <Loader2 className="animate-spin" />}
                {pending ? "建立中" : "建立"}
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  setAdding(false);
                  setNewStudio("");
                  setNewTitle("");
                }}
                disabled={pending}
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

      {rows.length === 0 ? (
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
          works={rows}
          editing={editing}
          editValue={editValue}
          busy={pending}
          onStartEdit={(w) => {
            setEditValue(w.title_zh);
            setEditing(w.id);
          }}
          onCancelEdit={() => setEditing(null)}
          onChangeEdit={setEditValue}
          onCommitEdit={commitRename}
          onRemove={remove}
        />
      )}

      {cursor && (
        <div className="flex justify-center py-6">
          <Button
            variant="outline"
            onClick={loadMore}
            disabled={loadingMore}
          >
            {loadingMore && <Loader2 className="animate-spin" />}
            {loadingMore ? "載入中…" : "載入更多"}
          </Button>
        </div>
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
    const k = w.studio ?? NULL_STUDIO_KEY;
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
