"use client";

import { useRef, useState } from "react";
import { ImagePlus, AlertTriangle } from "lucide-react";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { attachImage } from "@/app/actions/posters";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Big mobile-friendly upload zone for one poster. Tap → opens system
 * file picker (camera or gallery on phones). Compresses + uploads to
 * Storage on the client, then calls the admin-gated attachImage
 * server action to flip is_placeholder + revalidate the surfaces.
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
      const r = await attachImage(posterId, {
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
        blurhash: result.blurhash,
        image_size_bytes: result.imageSizeBytes,
      });
      if (!r.ok) throw new Error(r.error);
      setProgress("完成");
    } catch (err) {
      setError(describeError(err));
    } finally {
      setBusy(false);
      setProgress(null);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  const showPlaceholder = isPlaceholder || !currentImageUrl;

  return (
    <div className="space-y-3">
      <button
        type="button"
        onClick={() => !busy && fileRef.current?.click()}
        disabled={busy}
        className={cn(
          "relative w-full aspect-[2/3] rounded-xl overflow-hidden border text-foreground",
          showPlaceholder
            ? "border-dashed border-input bg-secondary/40"
            : "border-border",
          busy ? "opacity-60" : "active:opacity-80 hover:bg-secondary/60 transition-colors"
        )}
      >
        {currentImageUrl && !showPlaceholder ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={currentImageUrl}
            alt=""
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground p-4 text-center">
            <ImagePlus className="w-10 h-10 mb-3" strokeWidth={1.5} />
            <div className="text-sm font-medium text-foreground">
              點此上傳真實海報圖
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              支援 JPG / PNG / HEIC，自動壓縮與產生縮圖
            </div>
          </div>
        )}

        {busy && (
          <div className="absolute inset-0 bg-background/80 flex items-center justify-center">
            <div className="text-sm">{progress ?? "處理中…"}</div>
          </div>
        )}
      </button>

      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        onChange={onFileChange}
        className="hidden"
        disabled={busy}
      />

      {currentImageUrl && !showPlaceholder && (
        <Button
          variant="outline"
          onClick={() => fileRef.current?.click()}
          disabled={busy}
          className="w-full"
        >
          換一張
        </Button>
      )}

      {error && (
        <Card className="border-destructive/40 bg-destructive/10">
          <CardContent className="p-3 flex items-start gap-2 text-sm text-destructive">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>上傳失敗：{error}</span>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
