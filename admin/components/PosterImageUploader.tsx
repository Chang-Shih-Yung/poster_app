"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { uploadPosterImage } from "@/lib/imageUpload";
import { createClient } from "@/lib/supabase/client";

/**
 * Big mobile-friendly upload zone for one poster. Tap → opens system
 * file picker (camera or gallery on phones, file dialog on desktop).
 * Compresses + uploads + writes posters.image_url|thumbnail_url|
 * blurhash + flips is_placeholder = false.
 *
 * Shown on the poster edit page.
 */
export default function PosterImageUploader({
  posterId,
  currentImageUrl,
  isPlaceholder,
}: {
  posterId: string;
  currentImageUrl: string | null;
  isPlaceholder: boolean;
}) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string | null>(null);

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    setBusy(true);
    try {
      setProgress("壓縮中…");
      const result = await uploadPosterImage(file, posterId);
      setProgress("寫入 DB…");
      const supabase = createClient();
      const { error: dbError } = await supabase
        .from("posters")
        .update({
          poster_url: result.posterUrl,
          thumbnail_url: result.thumbnailUrl,
          blurhash: result.blurhash,
          image_size_bytes: result.imageSizeBytes,
          is_placeholder: false,
        })
        .eq("id", posterId);
      if (dbError) throw dbError;
      setProgress("完成");
      router.refresh();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    } finally {
      setBusy(false);
      setProgress(null);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  const showPlaceholder = isPlaceholder || !currentImageUrl;

  return (
    <div className="space-y-3">
      <div
        onClick={() => !busy && fileRef.current?.click()}
        className={`relative w-full aspect-[2/3] rounded-lg overflow-hidden border ${
          showPlaceholder
            ? "border-dashed border-line2 bg-surfaceRaised"
            : "border-line1"
        } ${!busy ? "cursor-pointer active:opacity-80" : "opacity-60"}`}
      >
        {currentImageUrl && !showPlaceholder ? (
          <img
            src={currentImageUrl}
            alt=""
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-textMute p-4 text-center">
            <svg
              width={42}
              height={42}
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={1.5}
              strokeLinecap="round"
              strokeLinejoin="round"
              className="mb-3"
            >
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <circle cx="8.5" cy="8.5" r="1.5" />
              <polyline points="21 15 16 10 5 21" />
            </svg>
            <div className="text-sm font-medium">點此上傳真實海報圖</div>
            <div className="text-xs text-textFaint mt-1">
              支援 JPG / PNG / HEIC，自動壓縮與產生縮圖
            </div>
          </div>
        )}

        {busy && (
          <div className="absolute inset-0 bg-bg/80 flex items-center justify-center">
            <div className="text-sm">{progress ?? "處理中…"}</div>
          </div>
        )}
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        onChange={onFileChange}
        className="hidden"
        disabled={busy}
      />

      {currentImageUrl && !showPlaceholder && (
        <button
          onClick={() => fileRef.current?.click()}
          disabled={busy}
          className="w-full py-2 text-sm rounded-md border border-line2 text-textMute"
        >
          換一張
        </button>
      )}

      {error && (
        <div className="p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
          上傳失敗：{error}
        </div>
      )}
    </div>
  );
}
