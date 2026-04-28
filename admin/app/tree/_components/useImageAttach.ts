"use client";

import { useRef } from "react";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { attachImage } from "@/app/actions/posters";

type Target = { id: string };

/**
 * Bundle of state + handlers for "tap a poster row → choose file →
 * upload + attach" flow used by both WorkClient and GroupClient.
 *
 * The hook owns:
 *   - `fileInputRef` — the hidden `<input type="file">` element ref.
 *     The caller renders `<input ref={fileInputRef} ... onChange={handleFile} />`.
 *   - `uploadTargetRef` — which poster the upload is for. Captured
 *     when `pickFor()` is called, cleared when handleFile completes.
 *
 * Failure path: a single `alert(describeError(...))` matches the
 * old inline behaviour. Callers don't need to wire their own error
 * UI for this path.
 */
export function useImageAttach() {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const uploadTargetRef = useRef<Target | null>(null);

  function pickFor(target: Target) {
    uploadTargetRef.current = target;
    fileInputRef.current?.click();
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const target = uploadTargetRef.current;
    if (!file || !target) return;
    try {
      const result = await uploadPosterImage(file, target.id);
      const r = await attachImage(target.id, {
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
        blurhash: result.blurhash,
        image_size_bytes: result.imageSizeBytes,
      });
      if (!r.ok) throw new Error(r.error);
    } catch (err) {
      alert(describeError(err));
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = "";
      uploadTargetRef.current = null;
    }
  }

  return { fileInputRef, pickFor, handleFile };
}
