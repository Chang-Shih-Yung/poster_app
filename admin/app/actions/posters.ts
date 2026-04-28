"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";

/**
 * Server actions for `posters` rows. Image upload still happens on the
 * client (browser-image-compression + Supabase Storage upload) — only
 * the DB write portion (attachImage) is a server action so the row's
 * is_placeholder flip is admin-gated.
 *
 * Cache invalidation: precise paths only. `"layout"` qualifier was
 * removed because it cascaded too aggressively — every poster mutation
 * was blowing up the entire layout segment cache.
 */

function revalidatePosterSurfaces(workId?: string, posterId?: string) {
  revalidatePath("/posters");
  revalidatePath("/upload-queue");
  revalidatePath("/tree");
  revalidatePath("/");
  if (workId) {
    revalidatePath(`/works/${workId}`);
    revalidatePath(`/tree/work/${workId}`);
  }
  if (posterId) revalidatePath(`/posters/${posterId}`);
}

/**
 * Create a poster row. The minimal form (Sheet "新增海報" inside the
 * tree) supplies just work_id + name; the full PosterForm supplies
 * every metadata field. `title`, `poster_url`, `uploader_id` are
 * filled by DB triggers (migrations 20260428100200 +
 * 20260428110000), so we don't write them here.
 */
export async function createPoster(input: {
  work_id: string;
  parent_group_id: string | null;
  poster_name: string;
  year?: number | null;
  region?: string | null;
  poster_release_type?: string | null;
  size_type?: string | null;
  channel_category?: string | null;
  channel_name?: string | null;
  is_exclusive?: boolean;
  exclusive_name?: string | null;
  material_type?: string | null;
  version_label?: string | null;
  source_url?: string | null;
  source_note?: string | null;
}): Promise<
  ActionResult<{
    id: string;
    poster_name: string | null;
    is_placeholder: boolean;
    thumbnail_url: string | null;
  }>
> {
  try {
    const { supabase, user } = await requireAdmin();
    if (!input.poster_name.trim()) throw new Error("海報名稱必填");
    const trimmed = input.poster_name.trim();
    const { data, error } = await supabase
      .from("posters")
      .insert({
        work_id: input.work_id,
        parent_group_id: input.parent_group_id,
        poster_name: trimmed,
        year: input.year ?? null,
        region: input.region ?? null,
        poster_release_type: input.poster_release_type ?? null,
        size_type: input.size_type ?? null,
        channel_category: input.channel_category ?? null,
        channel_name: input.channel_name ?? null,
        is_exclusive: input.is_exclusive ?? false,
        exclusive_name: input.exclusive_name ?? null,
        material_type: input.material_type ?? null,
        version_label: input.version_label ?? null,
        source_url: input.source_url ?? null,
        source_note: input.source_note ?? null,
        status: "approved",
      })
      .select("id, poster_name, is_placeholder, thumbnail_url")
      .single();
    if (error) throw error;
    revalidatePosterSurfaces(input.work_id);
    await logAudit(supabase, user, {
      action: "create_poster",
      target_kind: "poster",
      target_id: data.id,
      payload: {
        work_id: input.work_id,
        parent_group_id: input.parent_group_id,
        poster_name: trimmed,
      },
    });
    return ok(data);
  } catch (e) {
    return fail(e);
  }
}

export async function renamePoster(
  id: string,
  poster_name: string
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    if (!poster_name.trim()) throw new Error("名稱不能為空");
    const trimmed = poster_name.trim();
    // One round-trip: update returns the new row + work_id needed for
    // revalidation. DB trigger `sync_poster_title_from_name` keeps the
    // legacy `title` column in lock-step.
    const { data, error } = await supabase
      .from("posters")
      .update({ poster_name: trimmed })
      .eq("id", id)
      .select("work_id")
      .maybeSingle();
    if (error) throw error;
    revalidatePosterSurfaces(data?.work_id ?? undefined, id);
    await logAudit(supabase, user, {
      action: "rename_poster",
      target_kind: "poster",
      target_id: id,
      payload: { to: trimmed },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deletePoster(id: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select(
        "id, work_id, parent_group_id, poster_name, region, year, poster_url, thumbnail_url, is_placeholder"
      )
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase.from("posters").delete().eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    await logAudit(supabase, user, {
      action: "delete_poster",
      target_kind: "poster",
      target_id: id,
      payload: existing ? { snapshot: existing } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/**
 * After client-side image upload finishes, this writes the resulting
 * URLs/blurhash and flips is_placeholder.
 *
 * The audit trail wants the previous URL (so a wrong image upload
 * leaves a forensic trail). We fetch + update in two round-trips
 * because the new URL replaces the old in the row, so .update().select()
 * can't return the previous value.
 */
/**
 * Validate that a URL originates from the project's Supabase Storage
 * bucket. Blocks arbitrary URL injection via crafted server-action
 * calls (even if the admin session is compromised, malicious content
 * can't be served to Flutter app users through poster images).
 */
function assertStorageUrl(url: string, label: string) {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("NEXT_PUBLIC_SUPABASE_URL 未設定");
  if (!url.startsWith(`${base}/storage/v1/`)) {
    throw new Error(`${label} 必須來自 Supabase Storage（收到：${url.slice(0, 60)}…）`);
  }
}

export async function attachImage(
  id: string,
  payload: {
    poster_url: string;
    thumbnail_url: string;
    blurhash: string;
    image_size_bytes: number;
  }
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    assertStorageUrl(payload.poster_url, "poster_url");
    assertStorageUrl(payload.thumbnail_url, "thumbnail_url");
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id, poster_url, thumbnail_url, is_placeholder")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("posters")
      .update({
        poster_url: payload.poster_url,
        thumbnail_url: payload.thumbnail_url,
        blurhash: payload.blurhash,
        image_size_bytes: payload.image_size_bytes,
        is_placeholder: false,
      })
      .eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    await logAudit(supabase, user, {
      action: "attach_image",
      target_kind: "image",
      target_id: id,
      payload: {
        was_placeholder: existing?.is_placeholder ?? null,
        previous_url: existing?.poster_url ?? null,
        previous_thumbnail: existing?.thumbnail_url ?? null,
        new_url: payload.poster_url,
        new_thumbnail: payload.thumbnail_url,
        size_bytes: payload.image_size_bytes,
      },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/**
 * Whitelist of columns the poster metadata form is allowed to write.
 * Anything outside this list (e.g. id, work_id, status, is_placeholder,
 * poster_url, thumbnail_url, created_at) is silently stripped so a
 * crafted client request can't overwrite protected fields.
 */
const POSTER_METADATA_ALLOWED = new Set([
  "poster_name",
  "title",
  "year",
  "region",
  "poster_release_type",
  "size_type",
  "channel_category",
  "channel_name",
  "is_exclusive",
  "exclusive_name",
  "material_type",
  "version_label",
  "source_url",
  "source_note",
  "parent_group_id",
]);

export async function updatePosterMetadata(
  id: string,
  patch: Record<string, unknown>
): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    const safePatch = Object.fromEntries(
      Object.entries(patch).filter(([k]) => POSTER_METADATA_ALLOWED.has(k))
    );
    if (Object.keys(safePatch).length === 0) {
      throw new Error("沒有可更新的欄位");
    }
    const { data, error } = await supabase
      .from("posters")
      .update(safePatch)
      .eq("id", id)
      .select("work_id")
      .maybeSingle();
    if (error) throw error;
    revalidatePosterSurfaces(data?.work_id ?? undefined, id);
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
