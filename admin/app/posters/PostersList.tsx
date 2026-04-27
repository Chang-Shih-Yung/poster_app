"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, ImagePlus, Loader2, AlertTriangle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { uploadPosterImage } from "@/lib/imageUpload";

/**
 * Flat list of every poster in the catalogue with inline rename, inline
 * image upload, and trash. Mirrors the leaf-poster row affordances from
 * the tree, just decoupled from the tree's hierarchy. Useful for "show
 * me everything I've created" and quick-fix passes.
 */

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
      return "(unknown)";
    }
  }
  return String(e);
}

export default function PostersList({
  initial,
  query,
  placeholderOnly,
}: {
  initial: Poster[];
  query: string;
  placeholderOnly: boolean;
}) {
  const router = useRouter();
  const [posters, setPosters] = useState<Poster[]>(initial);
  const [editing, setEditing] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const supabase = createClient();

  async function rename(p: Poster, newName: string) {
    if (!newName.trim() || newName === p.poster_name) {
      setEditing(null);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { error } = await supabase
        .from("posters")
        .update({ poster_name: newName.trim(), title: newName.trim() })
        .eq("id", p.id);
      if (error) throw error;
      setPosters((list) =>
        list.map((x) =>
          x.id === p.id ? { ...x, poster_name: newName.trim() } : x
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

  async function remove(p: Poster) {
    if (!confirm(`刪除海報「${p.poster_name ?? "(未命名)"}」？此操作不可復原。`)) return;
    setBusy(true);
    setError(null);
    try {
      const { error } = await supabase.from("posters").delete().eq("id", p.id);
      if (error) throw error;
      setPosters((list) => list.filter((x) => x.id !== p.id));
      router.refresh();
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="sticky z-30 bg-bg/95 backdrop-blur-sm px-4 md:px-0 py-2.5 mb-1 top-[calc(env(safe-area-inset-top,0px)+52px)] md:top-0 space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs text-textMute">{posters.length} 張海報</span>
          {placeholderOnly && (
            <a
              href="/posters"
              className="text-xs text-accent"
            >
              清除「只看待補圖」篩選
            </a>
          )}
        </div>
        <form className="flex gap-2 text-sm" action="/posters" method="get">
          <input
            name="q"
            placeholder="按名稱搜尋..."
            defaultValue={query}
            className="flex-1"
          />
          {placeholderOnly && (
            <input type="hidden" name="placeholder" value="1" />
          )}
          <button
            type="submit"
            className="px-3 py-1.5 border border-line2 rounded-md text-textMute"
          >
            搜尋
          </button>
        </form>
      </div>

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

      <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
        {posters.map((p, i) => (
          <PosterRow
            key={p.id}
            poster={p}
            index={i + 1}
            isEditing={editing === p.id}
            editValue={editValue}
            onEditValue={setEditValue}
            onStartEdit={() => {
              setEditValue(p.poster_name ?? "");
              setEditing(p.id);
            }}
            onCancelEdit={() => setEditing(null)}
            onCommit={() => rename(p, editValue)}
            onDelete={() => remove(p)}
            onUploaded={(updated) => {
              setPosters((list) =>
                list.map((x) =>
                  x.id === p.id
                    ? {
                        ...x,
                        thumbnail_url: updated.thumbnail_url,
                        poster_url: updated.poster_url,
                        is_placeholder: false,
                      }
                    : x
                )
              );
            }}
            busy={busy}
          />
        ))}
        {posters.length === 0 && (
          <li className="px-4 py-10 text-center text-textFaint text-sm">
            沒有符合條件的海報
          </li>
        )}
      </ul>
    </>
  );
}

function PosterRow({
  poster: p,
  index,
  isEditing,
  editValue,
  onEditValue,
  onStartEdit,
  onCancelEdit,
  onCommit,
  onDelete,
  onUploaded,
  busy,
}: {
  poster: Poster;
  index: number;
  isEditing: boolean;
  editValue: string;
  onEditValue: (v: string) => void;
  onStartEdit: () => void;
  onCancelEdit: () => void;
  onCommit: () => void;
  onDelete: () => void;
  onUploaded: (u: { thumbnail_url: string; poster_url: string }) => void;
  busy: boolean;
}) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const supabase = createClient();
  const router = useRouter();

  if (isEditing) {
    return (
      <li>
        <div className="bg-surfaceRaised py-2 px-4">
          <div className="flex gap-2">
            <input
              autoFocus
              value={editValue}
              onChange={(e) => onEditValue(e.target.value)}
              placeholder="海報名稱"
              className="flex-1"
              disabled={busy}
              onKeyDown={(e) => {
                if (e.key === "Enter") onCommit();
                if (e.key === "Escape") onCancelEdit();
              }}
            />
            <button
              onClick={onCommit}
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
      const { error } = await supabase
        .from("posters")
        .update({
          poster_url: result.posterUrl,
          thumbnail_url: result.thumbnailUrl,
          blurhash: result.blurhash,
          image_size_bytes: result.imageSizeBytes,
          is_placeholder: false,
        })
        .eq("id", p.id);
      if (error) throw error;
      onUploaded({
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
      });
      router.refresh();
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
        <span className="text-xs text-textFaint tabular-nums shrink-0 w-7">
          {index}.
        </span>

        {p.thumbnail_url ? (
          <img
            src={p.thumbnail_url}
            alt=""
            className="w-10 h-12 rounded object-cover border border-line1 mr-3 shrink-0"
          />
        ) : (
          <div className="w-10 h-12 rounded bg-surfaceRaised border border-line1 mr-3 shrink-0" />
        )}

        <a
          href={`/posters/${p.id}`}
          className="min-w-0 flex-1 mr-2 hover:no-underline"
        >
          <span className="flex items-baseline gap-1">
            <span className="text-sm text-text truncate">
              {p.poster_name ?? "(未命名)"}
            </span>
            <button
              onClick={(e) => {
                e.preventDefault();
                onStartEdit();
              }}
              className="shrink-0 text-textFaint hover:text-text p-1 -m-1"
              aria-label="重新命名"
              title="重新命名"
            >
              <Pencil className="w-3 h-3" />
            </button>
          </span>
          <span className="block text-xs text-textFaint truncate mt-0.5">
            {[p.works?.studio, p.works?.title_zh, p.region]
              .filter(Boolean)
              .join(" · ")}
            {p.is_placeholder && (
              <span className="text-amber-400 ml-1">· 待補真圖</span>
            )}
          </span>
        </a>

        <button
          onClick={(e) => {
            e.preventDefault();
            inputRef.current?.click();
          }}
          className="w-9 h-9 flex items-center justify-center text-textMute shrink-0"
          aria-label={p.is_placeholder ? "上傳真實圖片" : "更換圖片"}
          title={p.is_placeholder ? "上傳真實圖片" : "更換圖片"}
        >
          {uploading ? (
            <Loader2 className="w-4 h-4 animate-spin text-accent" />
          ) : (
            <ImagePlus
              className={`w-4 h-4 ${p.is_placeholder ? "text-amber-400" : "text-accent"}`}
            />
          )}
        </button>

        <button
          onClick={(e) => {
            e.preventDefault();
            onDelete();
          }}
          className="w-9 h-9 flex items-center justify-center text-textMute hover:text-red-400 shrink-0"
          aria-label="刪除"
          title="刪除"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      </div>
      {uploadError && (
        <div className="px-4 py-2 text-xs text-red-400 bg-red-900/20 border-y border-red-700/40">
          上傳失敗：{uploadError}
          <button
            onClick={() => setUploadError(null)}
            className="ml-2 underline"
          >
            關閉
          </button>
        </div>
      )}
    </li>
  );
}
