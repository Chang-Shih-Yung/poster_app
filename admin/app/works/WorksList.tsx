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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
import { toast } from "sonner";
import {
  updateWork,
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
  studios = [],
}: {
  initial: Work[];
  initialCursor?: string | null;
  studios?: string[];
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
  // Inline rename — 中文 + 英文兩個欄位（spec #1 + #2 都必填）
  const [editValue, setEditValue] = useState("");
  const [editValueEn, setEditValueEn] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [newStudio, setNewStudio] = useState("");
  // "select" 模式：從既有 studio 下拉挑；"custom" 模式：自由打字建新分類
  // （跟 WorkForm 的 pattern 一致 — 點下拉「其他（輸入新分類）…」會切到 custom）
  const [newStudioMode, setNewStudioMode] = useState<"select" | "custom">(
    "select"
  );
  const [newTitle, setNewTitle] = useState("");
  const [newTitleEn, setNewTitleEn] = useState("");
  const [pendingDelete, setPendingDelete] = useState<Work | null>(null);
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

  function commitRename(work: Work, newTitle: string, newTitleEn: string) {
    const trimmedZh = newTitle.trim();
    const trimmedEn = newTitleEn.trim();
    if (!trimmedZh || !trimmedEn) {
      toast.error("中文 + 英文名稱皆必填");
      return;
    }
    // 沒改任何東西就直接收掉，省一次 server round-trip
    if (
      trimmedZh === work.title_zh &&
      trimmedEn === (work.title_en ?? "")
    ) {
      setEditing(null);
      return;
    }
    const tid = toast.loading("儲存中…");
    startTransition(async () => {
      const r = await updateWork(work.id, {
        title_zh: trimmedZh,
        title_en: trimmedEn,
      });
      toast.dismiss(tid);
      if (!r.ok) {
        setError(r.error);
        toast.error(r.error);
      } else {
        setEditing(null);
        toast.success("已儲存");
      }
    });
  }

  function remove(work: Work) {
    setPendingDelete(work);
  }

  function confirmDelete() {
    if (!pendingDelete) return;
    const work = pendingDelete;
    setPendingDelete(null);
    const tid = toast.loading(`刪除「${work.title_zh}」中…`);
    startTransition(async () => {
      const r = await deleteWork(work.id);
      toast.dismiss(tid);
      if (!r.ok) {
        setError(r.error);
        toast.error(r.error);
      } else {
        toast.success(`已刪除「${work.title_zh}」`);
      }
    });
  }

  function createNew() {
    if (!newTitle.trim()) {
      toast.error("作品中文名稱必填");
      return;
    }
    if (!newTitleEn.trim()) {
      toast.error("作品英文名稱必填");
      return;
    }
    const tid = toast.loading("新增中…");
    startTransition(async () => {
      const r = await createWork({
        title_zh: newTitle,
        title_en: newTitleEn,
        studio: newStudio.trim() || null,
        work_kind: "movie",
      });
      toast.dismiss(tid);
      if (!r.ok) {
        setError(r.error);
        toast.error(r.error);
        return;
      }
      setAdding(false);
      setNewStudio("");
      setNewStudioMode("select");
      setNewTitle("");
      setNewTitleEn("");
      toast.success(`已新增「${newTitle}」`);
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
            {newStudioMode === "select" ? (
              <Select
                // Radix Select rejects empty-string values; sentinel-roundtrip
                // mirrors the WorkForm pattern. "__custom__" → 切到自由輸入。
                value={newStudio === "" ? "__none__" : newStudio}
                onValueChange={(v) => {
                  if (v === "__custom__") {
                    setNewStudioMode("custom");
                    setNewStudio("");
                  } else if (v === "__none__") {
                    setNewStudio("");
                  } else {
                    setNewStudio(v);
                  }
                }}
                disabled={pending}
              >
                <SelectTrigger>
                  <SelectValue placeholder="所屬分類" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">（未分類）</SelectItem>
                  {studios.map((s) => (
                    <SelectItem key={s} value={s}>
                      {s}
                    </SelectItem>
                  ))}
                  <SelectItem value="__custom__">
                    其他（輸入新分類）…
                  </SelectItem>
                </SelectContent>
              </Select>
            ) : (
              <div className="flex gap-2">
                <Input
                  autoFocus
                  value={newStudio}
                  onChange={(e) => setNewStudio(e.target.value)}
                  placeholder="新分類名稱"
                  disabled={pending}
                />
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="shrink-0"
                  onClick={() => {
                    setNewStudioMode("select");
                    // 如果輸入的字串剛好是既有 studio 就保留，否則清空
                    // 讓 Select 顯示 placeholder。
                    if (!studios.includes(newStudio)) setNewStudio("");
                  }}
                  disabled={pending}
                >
                  取消
                </Button>
              </div>
            )}
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
                  setNewStudioMode("select");
                  setNewTitle("");
                  setNewTitleEn("");
                }
              }}
            />
            <Input
              value={newTitleEn}
              onChange={(e) => setNewTitleEn(e.target.value)}
              placeholder="作品名稱（英文，spec 必填）"
              disabled={pending}
              onKeyDown={(e) => {
                if (e.key === "Enter") createNew();
                if (e.key === "Escape") {
                  setAdding(false);
                  setNewStudio("");
                  setNewStudioMode("select");
                  setNewTitle("");
                  setNewTitleEn("");
                }
              }}
            />
            <div className="flex gap-2">
              <Button
                size="sm"
                onClick={createNew}
                disabled={
                  pending || !newTitle.trim() || !newTitleEn.trim()
                }
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
                  setNewStudioMode("select");
                  setNewTitle("");
                  setNewTitleEn("");
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
          editValueEn={editValueEn}
          busy={pending}
          onStartEdit={(w) => {
            setEditValue(w.title_zh);
            setEditValueEn(w.title_en ?? "");
            setEditing(w.id);
          }}
          onCancelEdit={() => setEditing(null)}
          onChangeEdit={setEditValue}
          onChangeEditEn={setEditValueEn}
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

      <AlertDialog
        open={pendingDelete != null}
        onOpenChange={(open) => {
          if (!open) setPendingDelete(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>確認刪除作品</AlertDialogTitle>
            <AlertDialogDescription className="whitespace-pre-line">
              {`刪除作品「${pendingDelete?.title_zh}」？\n底下所有群組與海報（${pendingDelete?.poster_count ?? 0} 張）都會一起刪除。\n此操作不可復原。`}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmDelete}
            >
              確認刪除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function WorksSections({
  works,
  editing,
  editValue,
  editValueEn,
  busy,
  onStartEdit,
  onCancelEdit,
  onChangeEdit,
  onChangeEditEn,
  onCommitEdit,
  onRemove,
}: {
  works: Work[];
  editing: string | null;
  editValue: string;
  editValueEn: string;
  busy: boolean;
  onStartEdit: (w: Work) => void;
  onCancelEdit: () => void;
  onChangeEdit: (v: string) => void;
  onChangeEditEn: (v: string) => void;
  onCommitEdit: (w: Work, newTitle: string, newTitleEn: string) => void;
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
                      <div className="bg-secondary/40 py-2 px-3 space-y-2">
                        <Input
                          autoFocus
                          value={editValue}
                          onChange={(e) => onChangeEdit(e.target.value)}
                          placeholder="中文名稱"
                          disabled={busy}
                          onKeyDown={(e) => {
                            if (e.key === "Enter")
                              onCommitEdit(w, editValue, editValueEn);
                            if (e.key === "Escape") onCancelEdit();
                          }}
                        />
                        <Input
                          value={editValueEn}
                          onChange={(e) => onChangeEditEn(e.target.value)}
                          placeholder="英文名稱（spec 必填）"
                          disabled={busy}
                          onKeyDown={(e) => {
                            if (e.key === "Enter")
                              onCommitEdit(w, editValue, editValueEn);
                            if (e.key === "Escape") onCancelEdit();
                          }}
                        />
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            onClick={() =>
                              onCommitEdit(w, editValue, editValueEn)
                            }
                            disabled={
                              busy ||
                              !editValue.trim() ||
                              !editValueEn.trim()
                            }
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
                          disabled={busy}
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
