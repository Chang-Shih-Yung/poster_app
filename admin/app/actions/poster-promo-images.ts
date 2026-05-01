"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";

/**
 * Server actions for poster_promo_images (spec #18 多張版本).
 *
 * Admin uploads images via the client-side `uploadPromoImage` helper
 * (lib/imageUpload.ts), which returns Supabase Storage URLs. Those URLs
 * are validated here (must originate from our bucket) before insertion.
 *
 * Backwards-compat with posters.promo_image_url / promo_thumbnail_url:
 * the table-driven model is the new source of truth; the legacy single-
 * column fields are not maintained going forward.
 */

export type PromoImage = {
  id: string;
  image_url: string;
  thumbnail_url: string;
  sort_order: number;
  created_at: string;
};

function assertStorageUrl(url: string, label: string) {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("NEXT_PUBLIC_SUPABASE_URL 未設定");
  if (!url.startsWith(`${base}/storage/v1/`)) {
    throw new Error(
      `${label} 必須來自 Supabase Storage（收到：${url.slice(0, 60)}…）`
    );
  }
}

/** List all promo images for a poster, sorted by sort_order ASC. */
export async function listPromoImages(
  posterId: string
): Promise<ActionResult<PromoImage[]>> {
  try {
    const { supabase } = await requireAdmin();
    const { data, error } = await supabase
      .from("poster_promo_images")
      .select("id, image_url, thumbnail_url, sort_order, created_at")
      .eq("poster_id", posterId)
      .order("sort_order", { ascending: true });
    if (error) throw error;
    return ok((data ?? []) as PromoImage[]);
  } catch (e) {
    return fail(e);
  }
}

/**
 * Append a new promo image to a poster. sort_order = max(existing)+1
 * so it lands at the end of the gallery.
 */
export async function addPromoImage(
  posterId: string,
  payload: { image_url: string; thumbnail_url: string }
): Promise<ActionResult<{ id: string }>> {
  try {
    const { supabase, user } = await requireAdmin();
    assertStorageUrl(payload.image_url, "image_url");
    assertStorageUrl(payload.thumbnail_url, "thumbnail_url");

    // Compute next sort_order (cheap — small N per poster)
    const { data: existing } = await supabase
      .from("poster_promo_images")
      .select("sort_order")
      .eq("poster_id", posterId)
      .order("sort_order", { ascending: false })
      .limit(1);
    const nextOrder =
      ((existing?.[0]?.sort_order as number | null) ?? -1) + 1;

    const { data, error } = await supabase
      .from("poster_promo_images")
      .insert({
        poster_id: posterId,
        image_url: payload.image_url,
        thumbnail_url: payload.thumbnail_url,
        sort_order: nextOrder,
      })
      .select("id")
      .single();
    if (error) throw error;

    revalidatePath(`/posters/${posterId}`);
    void logAudit(supabase, user, {
      action: "add_promo_image",
      target_kind: "image",
      target_id: posterId,
      payload: { promo_image_id: data.id, sort_order: nextOrder },
    });
    return ok({ id: data.id as string });
  } catch (e) {
    return fail(e);
  }
}

/**
 * Remove one promo image. Storage object stays — admin can clean up via
 * a separate sweep job later.
 */
export async function removePromoImage(
  promoImageId: string
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: existing } = await supabase
      .from("poster_promo_images")
      .select("poster_id, image_url, thumbnail_url")
      .eq("id", promoImageId)
      .maybeSingle();
    const { error } = await supabase
      .from("poster_promo_images")
      .delete()
      .eq("id", promoImageId);
    if (error) throw error;
    if (existing?.poster_id) {
      revalidatePath(`/posters/${existing.poster_id}`);
    }
    void logAudit(supabase, user, {
      action: "remove_promo_image",
      target_kind: "image",
      target_id: (existing?.poster_id as string | undefined) ?? promoImageId,
      payload: existing ? { promo_image_id: promoImageId, snapshot: existing } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/**
 * Reorder promo images for a poster. `orderedIds` is the new full order
 * (must contain every existing promo_image id for that poster).
 *
 * Implementation: bulk update each row's sort_order to its index in the
 * new array. Single transaction by using upsert.
 */
export async function reorderPromoImages(
  posterId: string,
  orderedIds: string[]
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    // Sanity check: ids must all belong to this poster.
    const { data: existing, error: lookupErr } = await supabase
      .from("poster_promo_images")
      .select("id")
      .eq("poster_id", posterId);
    if (lookupErr) throw lookupErr;
    const existingIds = new Set((existing ?? []).map((r) => r.id as string));
    if (
      existingIds.size !== orderedIds.length ||
      !orderedIds.every((id) => existingIds.has(id))
    ) {
      throw new Error("傳入的順序 id 與資料庫不符");
    }

    // N is small per poster (typically <10), parallel update is fine.
    await Promise.all(
      orderedIds.map((id, idx) =>
        supabase
          .from("poster_promo_images")
          .update({ sort_order: idx })
          .eq("id", id)
      )
    );

    revalidatePath(`/posters/${posterId}`);
    void logAudit(supabase, user, {
      action: "reorder_promo_images",
      target_kind: "image",
      target_id: posterId,
      payload: { count: orderedIds.length },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
