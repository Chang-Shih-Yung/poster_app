"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";

/**
 * Server actions for `posters` rows. Image upload still happens on the
 * client (browser-image-compression + Supabase Storage upload) — only
 * the DB write portion (attachImage) is a server action so the row's
 * is_placeholder flip is admin-gated.
 *
 * Legacy NOT NULL columns (`title`, `poster_url`, `uploader_id`) are
 * back-filled here. A schema cleanup ticket is captured in TODOS.md.
 */

function revalidatePosterSurfaces(workId?: string, posterId?: string) {
  revalidatePath("/posters", "layout");
  revalidatePath("/upload-queue");
  revalidatePath("/tree", "layout");
  revalidatePath("/", "layout");
  if (workId) {
    revalidatePath(`/works/${workId}`);
    revalidatePath(`/tree/work/${workId}`);
  }
  if (posterId) revalidatePath(`/posters/${posterId}`);
}

/**
 * Create a poster row. The minimal form (Sheet "新增海報" inside the
 * tree) supplies just work_id + name; the full PosterForm supplies
 * every metadata field.
 *
 * `title`, `poster_url`, `uploader_id` are NOT NULL legacy columns;
 * the BEFORE INSERT trigger `fill_legacy_poster_defaults` (migration
 * 20260428100200) defaults them so callers don't have to. `status`
 * is set explicitly because admin-created rows bypass the public
 * submission moderation queue.
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
    const { supabase } = await requireAdmin();
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
    await logAudit({
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
    const { supabase } = await requireAdmin();
    if (!poster_name.trim()) throw new Error("名稱不能為空");
    const trimmed = poster_name.trim();
    // The DB trigger `sync_poster_title_from_name` keeps `title` in
    // lock-step when poster_name updates, so we don't need to write
    // both columns from here.
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id, poster_name")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("posters")
      .update({ poster_name: trimmed })
      .eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    await logAudit({
      action: "rename_poster",
      target_kind: "poster",
      target_id: id,
      payload: { from: existing?.poster_name ?? null, to: trimmed },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deletePoster(id: string): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
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
    await logAudit({
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
 * URLs/blurhash and flips is_placeholder. The upload itself stays on
 * the client (browser image compression libraries can't run on the
 * server cheaply) but the DB write goes through admin gating.
 */
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
    const { supabase } = await requireAdmin();
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
    await logAudit({
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

export async function updatePosterMetadata(
  id: string,
  patch: Record<string, unknown>
): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase.from("posters").update(patch).eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
