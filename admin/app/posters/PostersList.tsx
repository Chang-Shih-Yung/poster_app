"use client";

import { useRef, useState, useTransition } from "react";
import Link from "next/link";
import { Pencil, Trash2, ImagePlus, Loader2, AlertTriangle, X } from "lucide-react";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { UNNAMED_POSTER } from "@/lib/keys";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  renamePoster,
  deletePoster,
  attachImage,
} from "@/app/actions/posters";
import { toast } from "sonner";
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

type Poster = {
  id: string;
  poster_name: string | null;
  region: string | null;
  is_placeholder: boolean;
  thumbnail_url: string | null;
  poster_url: string | null;
  works: {
    title_zh: string | null;
    studio: string | null;
  } | null;
};

export default function PostersList({
  initial,
  query,
  placeholderOnly,
}: {
  initial: Poster[];
  query: string;
  placeholderOnly: boolean;
}) {
  const [editing, setEditing] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<Poster | null>(null);
  const [pending, startTransition] = useTransition();

  function commitRename(p: Poster, newName: string) {
    if (!newName.trim() || newName === p.poster_name) {
      setEditing(null);
      return;
    }
    startTransition(async () => {
      const r = await renamePoster(p.id, newName);
      if (!r.ok) setError(r.error);
      else setEditing(null);
    });
  }

  function remove(p: Poster) {
    setPendingDelete(p);
  }

  function confirmDelete() {
    if (!pendingDelete) return;
    const p = pendingDelete;
    setPendingDelete(null);
    const name = p.poster_name ?? UNNAMED_POSTER;
    const tid = toast.loading(`刪除「${name}」中…`);
    startTransition(async () => {
      const r = await deletePoster(p.id);
      toast.dismiss(tid);
      if (!r.ok) {
        setError(r.error);
        toast.error(r.error);
      } else {
        toast.success(`已刪除「${name}」`);
      }
    });
  }

  return (
    <div className="px-4 md:px-0">
      <div className="sticky top-[calc(env(safe-area-inset-top,0px)+52px)] md:top-14 z-30 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80 -mx-4 md:mx-0 px-4 md:px-0 py-2.5 mb-3 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground">
            {initial.length} 張海報
          </span>
          {placeholderOnly && (
            <Button asChild variant="link" size="sm">
              <Link href="/posters">清除「只看待補圖」篩選</Link>
            </Button>
          )}
        </div>
        <form className="flex gap-2" action="/posters" method="get">
          <Input
            name="q"
            placeholder="按名稱搜尋..."
            defaultValue={query}
            className="flex-1"
          />
          {placeholderOnly && (
            <input type="hidden" name="placeholder" value="1" />
          )}
          <Button type="submit" variant="outline">
            搜尋
          </Button>
        </form>
      </div>

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

      <Card>
        <CardContent className="p-0">
          <ul className="divide-y divide-border">
            {initial.map((p) => (
              <PosterRow
                key={p.id}
                poster={p}
                isEditing={editing === p.id}
                editValue={editValue}
                onEditValue={setEditValue}
                onStartEdit={() => {
                  setEditValue(p.poster_name ?? "");
                  setEditing(p.id);
                }}
                onCancelEdit={() => setEditing(null)}
                onCommit={() => commitRename(p, editValue)}
                onDelete={() => remove(p)}
                busy={pending}
              />
            ))}
            {initial.length === 0 && (
              <li className="px-4 py-10 text-center text-muted-foreground text-sm">
                沒有符合條件的海報
              </li>
            )}
          </ul>
        </CardContent>
      </Card>

      <AlertDialog
        open={pendingDelete != null}
        onOpenChange={(open) => {
          if (!open) setPendingDelete(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>確認刪除海報</AlertDialogTitle>
            <AlertDialogDescription>
              刪除海報「{pendingDelete?.poster_name ?? UNNAMED_POSTER}」？此操作不可復原。
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

function PosterRow({
  poster: p,
  isEditing,
  editValue,
  onEditValue,
  onStartEdit,
  onCancelEdit,
  onCommit,
  onDelete,
  busy,
}: {
  poster: Poster;
  isEditing: boolean;
  editValue: string;
  onEditValue: (v: string) => void;
  onStartEdit: () => void;
  onCancelEdit: () => void;
  onCommit: () => void;
  onDelete: () => void;
  busy: boolean;
}) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  if (isEditing) {
    return (
      <li>
        <div className="bg-secondary/40 py-2 px-3 flex gap-2">
          <Input
            autoFocus
            value={editValue}
            onChange={(e) => onEditValue(e.target.value)}
            placeholder="海報名稱"
            disabled={busy}
            onKeyDown={(e) => {
              if (e.key === "Enter") onCommit();
              if (e.key === "Escape") onCancelEdit();
            }}
          />
          <Button
            size="sm"
            onClick={onCommit}
            disabled={busy || !editValue.trim()}
          >
            {busy ? "儲存中" : "確認"}
          </Button>
          <Button size="sm" variant="outline" onClick={onCancelEdit} disabled={busy}>
            取消
          </Button>
        </div>
      </li>
    );
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadError(null);
    setUploading(true);
    try {
      const result = await uploadPosterImage(file, p.id);
      const r = await attachImage(p.id, {
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
        blurhash: result.blurhash,
        image_size_bytes: result.imageSizeBytes,
      });
      if (!r.ok) throw new Error(r.error);
    } catch (err) {
      setUploadError(describeError(err));
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <li>
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleFile}
        disabled={uploading || busy}
      />
      <div className="flex items-center px-4 py-3 min-h-[64px]">
        {p.thumbnail_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={p.thumbnail_url}
            alt=""
            className="w-10 h-12 rounded object-cover border border-border mr-3 shrink-0"
          />
        ) : (
          <div className="w-10 h-12 rounded bg-secondary border border-border mr-3 shrink-0" />
        )}

        <Link
          href={`/posters/${p.id}`}
          className="min-w-0 flex-1 mr-2 hover:no-underline"
        >
          <span className="flex items-center gap-2">
            <span className="text-sm text-foreground truncate">
              {p.poster_name ?? UNNAMED_POSTER}
            </span>
            {p.is_placeholder && <Badge variant="placeholder">待補圖</Badge>}
          </span>
          <span className="block text-xs text-muted-foreground truncate mt-0.5">
            {[p.works?.studio, p.works?.title_zh, p.region]
              .filter(Boolean)
              .join(" · ")}
          </span>
        </Link>

        <Button
          variant="quiet"
          size="icon"
          onClick={(e) => {
            e.preventDefault();
            onStartEdit();
          }}
          aria-label="重新命名"
          title="重新命名"
        >
          <Pencil />
        </Button>
        <Button
          variant="quiet"
          size="icon"
          onClick={(e) => {
            e.preventDefault();
            inputRef.current?.click();
          }}
          aria-label={p.is_placeholder ? "上傳真實圖片" : "更換圖片"}
          title={p.is_placeholder ? "上傳真實圖片" : "更換圖片"}
        >
          {uploading ? <Loader2 className="animate-spin" /> : <ImagePlus />}
        </Button>
        <Button
          variant="quiet"
          size="icon"
          onClick={(e) => {
            e.preventDefault();
            onDelete();
          }}
          aria-label="刪除"
          title="刪除"
          className="hover:text-destructive"
        >
          <Trash2 />
        </Button>
      </div>
      {uploadError && (
        <div className="px-4 py-2 text-xs text-destructive bg-destructive/10 border-t border-destructive/30 flex items-center gap-2">
          <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
          上傳失敗：{uploadError}
          <Button
            variant="link"
            size="sm"
            onClick={() => setUploadError(null)}
            className="h-auto p-0"
          >
            關閉
          </Button>
        </div>
      )}
    </li>
  );
}
