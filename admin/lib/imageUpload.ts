"use client";

import imageCompression from "browser-image-compression";
import { encode as encodeBlurhash } from "blurhash";
import { createClient } from "./supabase/client";
import { attachPromoImage, detachPromoImage } from "@/app/actions/posters";
import type { PromoImagePickerState } from "@/components/PromoImagePicker";

/**
 * Result of uploading one image to the posters bucket. URLs are public
 * (bucket is public-read) so the Flutter app can render them with no
 * extra auth.
 */
export type UploadResult = {
  posterUrl: string;
  thumbnailUrl: string;
  blurhash: string;
  imageSizeBytes: number;
};

const POSTERS_BUCKET = "posters";

/**
 * End-to-end pipeline for uploading one real poster image:
 *   1. Compress main image (long edge ≤ 1600px, jpeg q≈0.85)
 *   2. Compress thumbnail (long edge ≤ 400px, jpeg q≈0.75)
 *   3. Compute BlurHash (6×4) from the thumbnail bytes
 *   4. Upload both to Supabase Storage under `${posterId}/`
 *   5. Return URLs + blurhash so caller can UPDATE posters.*.
 *
 * Failure surfaces: client-side compression errors, Storage upload
 * errors. Caller should catch and surface to the user.
 */
export async function uploadPosterImage(
  file: File,
  posterId: string
): Promise<UploadResult> {
  const main = await imageCompression(file, {
    maxSizeMB: 2,
    maxWidthOrHeight: 1600,
    useWebWorker: true,
    fileType: "image/jpeg",
    initialQuality: 0.85,
  });

  const thumb = await imageCompression(file, {
    maxSizeMB: 0.4,
    maxWidthOrHeight: 400,
    useWebWorker: true,
    fileType: "image/jpeg",
    initialQuality: 0.75,
  });

  const blurhash = await computeBlurhash(thumb);

  const supabase = createClient();
  const ts = Date.now();
  const mainPath = `${posterId}/main_${ts}.jpg`;
  const thumbPath = `${posterId}/thumb_${ts}.jpg`;

  const [mainUp, thumbUp] = await Promise.all([
    supabase.storage.from(POSTERS_BUCKET).upload(mainPath, main, {
      contentType: "image/jpeg",
      upsert: true,
    }),
    supabase.storage.from(POSTERS_BUCKET).upload(thumbPath, thumb, {
      contentType: "image/jpeg",
      upsert: true,
    }),
  ]);

  if (mainUp.error) throw mainUp.error;
  if (thumbUp.error) throw thumbUp.error;

  const posterUrl = supabase.storage.from(POSTERS_BUCKET).getPublicUrl(mainPath).data.publicUrl;
  const thumbnailUrl = supabase.storage.from(POSTERS_BUCKET).getPublicUrl(thumbPath).data.publicUrl;

  return {
    posterUrl,
    thumbnailUrl,
    blurhash,
    imageSizeBytes: main.size,
  };
}

/**
 * Read a blob into an HTMLImageElement, draw to a tiny canvas, then
 * call the BlurHash encoder. The 6×4 component count keeps the
 * resulting hash short (<40 chars) while still capturing the dominant
 * shapes / colours.
 */
async function computeBlurhash(blob: Blob): Promise<string> {
  const url = URL.createObjectURL(blob);
  try {
    const img = await loadImage(url);
    const canvas = document.createElement("canvas");
    const w = 64;
    const h = Math.round((img.height / img.width) * w) || 64;
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("no 2d ctx");
    ctx.drawImage(img, 0, 0, w, h);
    const data = ctx.getImageData(0, 0, w, h);
    return encodeBlurhash(data.data, data.width, data.height, 6, 4);
  } finally {
    URL.revokeObjectURL(url);
  }
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

/**
 * Result of uploading a promo image — slimmer than UploadResult because
 * promo images don't get blurhash (not animated into the main feed) and
 * we don't track size separately for audit purposes.
 */
export type PromoUploadResult = {
  promoImageUrl: string;
  promoThumbnailUrl: string;
};

/**
 * Pipeline for uploading a poster's promo image (cinema flyer / IG
 * campaign shot / etc.). Mirrors uploadPosterImage minus the blurhash:
 *   1. Compress main (long edge ≤ 1600px)
 *   2. Compress thumbnail (long edge ≤ 400px)
 *   3. Upload to ${posterId}/promo_main_${ts}.jpg + promo_thumb_${ts}.jpg
 *
 * Same bucket as the main poster image. The `promo_` filename prefix
 * makes it easy to spot in the Storage browser.
 */
export async function uploadPromoImage(
  file: File,
  posterId: string
): Promise<PromoUploadResult> {
  const main = await imageCompression(file, {
    maxSizeMB: 2,
    maxWidthOrHeight: 1600,
    useWebWorker: true,
    fileType: "image/jpeg",
    initialQuality: 0.85,
  });

  const thumb = await imageCompression(file, {
    maxSizeMB: 0.4,
    maxWidthOrHeight: 400,
    useWebWorker: true,
    fileType: "image/jpeg",
    initialQuality: 0.75,
  });

  const supabase = createClient();
  const ts = Date.now();
  const mainPath = `${posterId}/promo_main_${ts}.jpg`;
  const thumbPath = `${posterId}/promo_thumb_${ts}.jpg`;

  const [mainUp, thumbUp] = await Promise.all([
    supabase.storage.from(POSTERS_BUCKET).upload(mainPath, main, {
      contentType: "image/jpeg",
      upsert: true,
    }),
    supabase.storage.from(POSTERS_BUCKET).upload(thumbPath, thumb, {
      contentType: "image/jpeg",
      upsert: true,
    }),
  ]);

  if (mainUp.error) throw mainUp.error;
  if (thumbUp.error) throw thumbUp.error;

  return {
    promoImageUrl: supabase.storage.from(POSTERS_BUCKET).getPublicUrl(mainPath).data.publicUrl,
    promoThumbnailUrl: supabase.storage.from(POSTERS_BUCKET).getPublicUrl(thumbPath).data.publicUrl,
  };
}

/**
 * Apply a PromoImagePicker state to a poster row. Encapsulates the
 * upload-or-detach branch that PosterForm and BatchImport otherwise
 * have to repeat.
 *
 *   - state.file present              → upload + attachPromoImage
 *   - state.markedForRemoval && existingUrl → detachPromoImage
 *   - neither                          → noop (returns ok)
 *
 * Caller is expected to pass `existingUrl: null` for newly-created
 * posters. Errors propagate through the standard ActionResult shape so
 * the parent UI can surface them inline.
 */
export async function applyPromoImageChange(
  posterId: string,
  state: PromoImagePickerState,
  existingUrl: string | null
): Promise<{ ok: true } | { ok: false; error: string }> {
  if (state.file) {
    try {
      const r = await uploadPromoImage(state.file, posterId);
      const ar = await attachPromoImage(posterId, {
        promo_image_url: r.promoImageUrl,
        promo_thumbnail_url: r.promoThumbnailUrl,
      });
      if (!ar.ok) return ar;
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e instanceof Error ? e.message : String(e) };
    }
  }
  if (state.markedForRemoval && existingUrl) {
    const r = await detachPromoImage(posterId);
    if (!r.ok) return r;
  }
  return { ok: true };
}
