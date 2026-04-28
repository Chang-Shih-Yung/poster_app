"use client";

import { useRef, useState } from "react";
import { toast } from "sonner";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { attachImage } from "@/app/actions/posters";

type Target = { id: string; poster_name?: string | null };

/**
 * Bundle of state + handlers for "tap a poster row → choose file →
 * upload + attach" flow used by both WorkClient and GroupClient.
 *
 * The hook owns:
 *   - `fileInputRef` — the hidden `<input type="file">` element ref.
 *     The caller renders `<input ref={fileInputRef} ... onChange={handleFile} />`.
 *   - `uploadTargetRef` — which poster the upload is for. Captured
 *     when `pickFor()` is called, cleared when handleFile completes.
 *   - `uploading` / `uploadTargetId` — observable state so callers
 *     can show a spinner on the row being uploaded.
 *
 * Failure path: `toast.error()` so errors surface non-blockingly.
 * Success path: `toast.success()` + optional `onSuccess` callback,
 * which callers use to navigate to the next placeholder poster.
 */
export function useImageAttach() {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const uploadTargetRef = useRef<Target | null>(null);
  const onSuccessRef = useRef<((posterId: string) => void) | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadTargetId, setUploadTargetId] = useState<string | null>(null);

  function pickFor(target: Target, onSuccess?: (posterId: string) => void) {
    uploadTargetRef.current = target;
    onSuccessRef.current = onSuccess ?? null;
    fileInputRef.current?.click();
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const target = uploadTargetRef.current;
    if (!file || !target) return;
    setUploading(true);
    setUploadTargetId(target.id);
    try {
      const result = await uploadPosterImage(file, target.id);
      const r = await attachImage(target.id, {
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
        blurhash: result.blurhash,
        image_size_bytes: result.imageSizeBytes,
      });
      if (!r.ok) throw new Error(r.error);
      const name = target.poster_name ?? "海報";
      toast.success(`「${name}」上傳成功`);
      onSuccessRef.current?.(target.id);
    } catch (err) {
      toast.error(describeError(err));
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = "";
      uploadTargetRef.current = null;
      onSuccessRef.current = null;
      setUploading(false);
      setUploadTargetId(null);
    }
  }

  return { fileInputRef, pickFor, handleFile, uploading, uploadTargetId };
}
