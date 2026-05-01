"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, Plus, Loader2 } from "lucide-react";
import { toast } from "sonner";
import {
  createPosterSet,
  updatePosterSet,
  deletePosterSet,
} from "@/app/actions/poster-sets";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { FormField } from "@/components/ui/form-field";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

export type SetRow = {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
  poster_count: number;
};

/**
 * Client-side list + CRUD UI for poster_sets.
 *
 * Shape mirrors the WorksList pattern:
 *   - Top bar: count + 「新增套票」button (opens create dialog)
 *   - List of rows with per-row 編輯 / 刪除 buttons
 *   - Edit reuses the same dialog as create (just pre-filled)
 *   - Delete goes through AlertDialog confirm
 *   - All mutations call router.refresh() to re-fetch from the server
 *     component above; preserves tab/scroll state.
 */
export default function SetsClient({ initial }: { initial: SetRow[] }) {
  const router = useRouter();
  const [pending, startTransition] = React.useTransition();

  // Create / edit dialog state. editingId === null means create mode.
  const [dialogOpen, setDialogOpen] = React.useState(false);
  const [editingId, setEditingId] = React.useState<string | null>(null);
  const [name, setName] = React.useState("");
  const [description, setDescription] = React.useState("");

  // Delete confirm state.
  const [deleteTarget, setDeleteTarget] = React.useState<SetRow | null>(null);

  function openCreate() {
    setEditingId(null);
    setName("");
    setDescription("");
    setDialogOpen(true);
  }

  function openEdit(row: SetRow) {
    setEditingId(row.id);
    setName(row.name);
    setDescription(row.description ?? "");
    setDialogOpen(true);
  }

  function closeDialog() {
    setDialogOpen(false);
    setEditingId(null);
    setName("");
    setDescription("");
  }

  async function submit() {
    const trimmed = name.trim();
    if (!trimmed) {
      toast.error("套票名稱必填");
      return;
    }
    startTransition(async () => {
      const r =
        editingId == null
          ? await createPosterSet({
              name: trimmed,
              description: description.trim() || null,
            })
          : await updatePosterSet(editingId, {
              name: trimmed,
              description: description.trim() || null,
            });
      if (!r.ok) {
        toast.error(r.error);
        return;
      }
      toast.success(
        editingId == null
          ? `已新增套票「${trimmed}」`
          : `已更新套票「${trimmed}」`
      );
      closeDialog();
      router.refresh();
    });
  }

  async function confirmDelete() {
    const t = deleteTarget;
    if (!t) return;
    setDeleteTarget(null);
    startTransition(async () => {
      const r = await deletePosterSet(t.id);
      if (!r.ok) {
        toast.error(r.error);
        return;
      }
      toast.success(`已刪除套票「${t.name}」`);
      router.refresh();
    });
  }

  return (
    <>
      <div className="flex items-center justify-between">
        <span className="text-xs text-muted-foreground">
          {initial.length} 個套票
        </span>
        <Button size="sm" onClick={openCreate} disabled={pending}>
          <Plus />
          新增套票
        </Button>
      </div>

      {initial.length === 0 ? (
        <Card>
          <CardContent className="py-10 text-center text-muted-foreground text-sm">
            還沒有套票。點右上「新增套票」開始建立。
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              {initial.map((s) => (
                <li
                  key={s.id}
                  className="flex items-center gap-3 px-4 py-3 min-h-[60px]"
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-foreground truncate">
                        {s.name}
                      </span>
                      <span className="text-xs text-muted-foreground shrink-0 px-1.5 py-0.5 rounded bg-secondary">
                        {s.poster_count} 張
                      </span>
                    </div>
                    {s.description && (
                      <div className="text-xs text-muted-foreground truncate mt-0.5">
                        {s.description}
                      </div>
                    )}
                  </div>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => openEdit(s)}
                    disabled={pending}
                    aria-label={`編輯套票 ${s.name}`}
                  >
                    <Pencil className="w-4 h-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => setDeleteTarget(s)}
                    disabled={pending}
                    aria-label={`刪除套票 ${s.name}`}
                    className="text-destructive hover:text-destructive"
                  >
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}

      {/* ── Create / edit dialog ─────────────────────────────────── */}
      <Dialog open={dialogOpen} onOpenChange={(v) => (v ? null : closeDialog())}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editingId == null ? "新增套票" : "編輯套票"}
            </DialogTitle>
            <DialogDescription>
              一個套票 = N 張一起發行的海報。建立後可在海報的「海報發行組合」欄位掛上。
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <FormField label="套票名稱" required>
              <Input
                autoFocus
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="例：2024 麥可傑克森電影上映套票"
                disabled={pending}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submit();
                  }
                }}
              />
            </FormField>
            <FormField label="說明">
              <Textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="說明這個套票的活動內容（選填）"
                rows={2}
                disabled={pending}
              />
            </FormField>
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={closeDialog}
              disabled={pending}
            >
              取消
            </Button>
            <Button
              type="button"
              onClick={submit}
              disabled={pending || !name.trim()}
            >
              {pending && <Loader2 className="animate-spin" />}
              {pending
                ? "儲存中…"
                : editingId == null
                  ? "建立"
                  : "儲存"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Delete confirm ───────────────────────────────────────── */}
      <AlertDialog
        open={deleteTarget != null}
        onOpenChange={(v) => {
          if (!v) setDeleteTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>刪除套票？</AlertDialogTitle>
            <AlertDialogDescription className="whitespace-pre-line">
              {deleteTarget &&
                `刪除套票「${deleteTarget.name}」？\n` +
                  (deleteTarget.poster_count > 0
                    ? `底下 ${deleteTarget.poster_count} 張海報會失去組合連結（海報本身不刪），可日後再掛回別的套票。`
                    : "這個套票底下還沒有任何海報，刪除安全。")}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setDeleteTarget(null)}>
              取消
            </AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmDelete}
            >
              確認刪除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
