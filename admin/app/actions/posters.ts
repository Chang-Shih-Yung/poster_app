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
  // Required per partner spec
  year: number;                          // posterReleaseYear (required)
  region: string;                        // required, default 'TW'
  size_type: string;                     // required
  channel_category: string;              // required
  // Optional metadata
  poster_release_date?: string | null;   // YYYY-MM-DD
  poster_release_type?: string | null;
  channel_type?: string | null;
  channel_name?: string | null;
  channel_note?: string | null;
  // Cinema-specific (only when channel_category=cinema)
  cinema_release_types?: string[] | null;
  premium_format?: string | null;
  cinema_name?: string | null;
  // CUSTOM size-specific (only when size_type=custom)
  custom_width?: number | null;
  custom_height?: number | null;
  size_unit?: string | null;
  // Other
  is_exclusive?: boolean;
  is_public?: boolean;
  // 售價 (#13 spec)
  price_type?: string | null;       // 'gift' | 'paid' | null
  price_amount?: number | null;     // only meaningful when price_type='paid'
  // 套票組合 (#14 spec)
  set_id?: string | null;
  // 是否限量（額外欄位，spec 沒列但合夥人補的）
  is_limited?: boolean;
  limited_quantity?: number | null;  // only meaningful when is_limited=true
  // 是否有工藝（合夥人後加）
  has_craft?: boolean;
  craft_note?: string | null;        // only meaningful when has_craft=true
  exclusive_name?: string | null;
  material_type?: string | null;
  version_label?: string | null;
  source_url?: string | null;
  source_platform?: string | null;
  source_note?: string | null;
  batch_id?: string | null;
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
    // poster_name is OPTIONAL per 2026-05-02 partner spec — admin can leave
    // it blank and treat the file's place in tree as identifier. Empty/blank
    // value is normalized to NULL at insert.
    if (input.year == null) throw new Error("發行年份必填");
    if (!input.region) throw new Error("地區必填");
    if (!input.size_type) throw new Error("尺寸必填");
    if (!input.channel_category) throw new Error("通路類型必填");
    const trimmed = input.poster_name?.trim() ?? "";
    const nameForInsert: string | null = trimmed === "" ? null : trimmed;

    // Friendly pre-check for the unique (work_id, lower(poster_name))
    // index added in 20260429150000. SKIP when name is null — Postgres
    // treats NULL as not-equal so multiple unnamed posters under the same
    // work are allowed by design.
    if (nameForInsert) {
      const { data: dup } = await supabase
        .from("posters")
        .select("id")
        .eq("work_id", input.work_id)
        .ilike("poster_name", nameForInsert)
        .is("deleted_at", null)
        .maybeSingle();
      if (dup) {
        throw new Error(
          `此作品已有海報「${nameForInsert}」（同名擋下，請改名或加版本標記）`
        );
      }
    }

    const { data, error } = await supabase
      .from("posters")
      .insert({
        work_id: input.work_id,
        parent_group_id: input.parent_group_id,
        poster_name: nameForInsert,
        year: input.year,
        poster_release_date: input.poster_release_date ?? null,
        region: input.region,
        poster_release_type: input.poster_release_type ?? null,
        size_type: input.size_type,
        channel_category: input.channel_category,
        channel_type: input.channel_type ?? null,
        channel_name: input.channel_name ?? null,
        channel_note: input.channel_note ?? null,
        cinema_release_types: input.cinema_release_types ?? [],
        premium_format: input.premium_format ?? null,
        cinema_name: input.cinema_name ?? null,
        custom_width: input.custom_width ?? null,
        custom_height: input.custom_height ?? null,
        size_unit: input.size_unit ?? null,
        is_exclusive: input.is_exclusive ?? false,
        // is_public defaults to true (DB default also true) — admin can
        // toggle off in the form to hide a row from the Flutter feed.
        is_public: input.is_public ?? true,
        price_type: input.price_type ?? null,
        price_amount: input.price_amount ?? null,
        set_id: input.set_id ?? null,
        is_limited: input.is_limited ?? false,
        limited_quantity: input.limited_quantity ?? null,
        has_craft: input.has_craft ?? false,
        craft_note: input.craft_note ?? null,
        exclusive_name: input.exclusive_name ?? null,
        material_type: input.material_type ?? null,
        version_label: input.version_label ?? null,
        source_url: input.source_url ?? null,
        source_platform: input.source_platform ?? null,
        source_note: input.source_note ?? null,
        batch_id: input.batch_id ?? null,
        source: "admin",
        status: "approved",
      })
      .select("id, poster_name, is_placeholder, thumbnail_url")
      .single();
    if (error) {
      // Postgres unique_violation falls through here when the friendly
      // pre-check missed a race-condition window.
      if ((error as { code?: string }).code === "23505") {
        throw new Error(
          `此作品已有海報「${nameForInsert ?? ""}」（race condition; please retry）`
        );
      }
      throw error;
    }
    revalidatePosterSurfaces(input.work_id);
    void logAudit(supabase, user, {
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
    void logAudit(supabase, user, {
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

/**
 * Move a poster to a different group (or to work root if newParentGroupId is null).
 */
export async function movePoster(
  id: string,
  newParentGroupId: string | null
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id, parent_group_id, poster_name")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    if (!existing) throw new Error("找不到此海報");

    // No-op: already at the target parent.
    if (existing.parent_group_id === newParentGroupId) return ok(undefined);

    const { error } = await supabase
      .from("posters")
      .update({ parent_group_id: newParentGroupId })
      .eq("id", id);
    if (error) throw error;

    revalidatePosterSurfaces(existing.work_id ?? undefined, id);
    void logAudit(supabase, user, {
      action: "move_poster",
      target_kind: "poster",
      target_id: id,
      payload: {
        from_parent: existing.parent_group_id,
        to_parent: newParentGroupId,
        work_id: existing.work_id,
      },
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
    void logAudit(supabase, user, {
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
    void logAudit(supabase, user, {
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
 * Attach a promotional image (cinema flyer / IG campaign / ticket
 * bundle ad) to a poster. Same Storage origin guard as attachImage so
 * a compromised admin can't inject arbitrary content URLs.
 *
 * `null` URLs are NOT supported here — use detachPromoImage to clear.
 */
export async function attachPromoImage(
  id: string,
  payload: {
    promo_image_url: string;
    promo_thumbnail_url: string;
  }
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    assertStorageUrl(payload.promo_image_url, "promo_image_url");
    assertStorageUrl(payload.promo_thumbnail_url, "promo_thumbnail_url");
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id, promo_image_url, promo_thumbnail_url")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("posters")
      .update({
        promo_image_url: payload.promo_image_url,
        promo_thumbnail_url: payload.promo_thumbnail_url,
      })
      .eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    void logAudit(supabase, user, {
      action: "attach_promo_image",
      target_kind: "image",
      target_id: id,
      payload: {
        previous_url: existing?.promo_image_url ?? null,
        previous_thumbnail: existing?.promo_thumbnail_url ?? null,
        new_url: payload.promo_image_url,
        new_thumbnail: payload.promo_thumbnail_url,
      },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/**
 * Clear the promo image (sets both URLs to null). Storage objects are
 * left in the bucket — same policy as attachImage / replacements: we
 * never delete uploaded blobs, only un-link them. Run a Storage GC
 * sweep separately if you care about cost.
 */
export async function detachPromoImage(id: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: existing, error: lookupErr } = await supabase
      .from("posters")
      .select("work_id, promo_image_url, promo_thumbnail_url")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("posters")
      .update({
        promo_image_url: null,
        promo_thumbnail_url: null,
      })
      .eq("id", id);
    if (error) throw error;
    revalidatePosterSurfaces(existing?.work_id ?? undefined, id);
    void logAudit(supabase, user, {
      action: "detach_promo_image",
      target_kind: "image",
      target_id: id,
      payload: {
        previous_url: existing?.promo_image_url ?? null,
        previous_thumbnail: existing?.promo_thumbnail_url ?? null,
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
  "poster_release_date",
  "region",
  "poster_release_type",
  "size_type",
  "channel_category",
  "channel_type",
  "channel_name",
  "channel_note",
  "cinema_release_types",
  "premium_format",
  "cinema_name",
  "custom_width",
  "custom_height",
  "size_unit",
  "is_exclusive",
  "exclusive_name",
  "material_type",
  "version_label",
  "source_url",
  "source_platform",
  "source_note",
  "batch_id",
  "parent_group_id",
  // is_public is a partner-spec field — admin can ship 海報 but keep
  // hidden from the public Flutter feed (is_public=false).
  "is_public",
  // 售價 + 套票（2026-05-02 spec wave 3）
  "price_type",
  "price_amount",
  "set_id",
  // 是否限量
  "is_limited",
  "limited_quantity",
  // 是否有工藝
  "has_craft",
  "craft_note",
  // collector flags (signed / numbered / edition_number / linen_backed /
  // licensed) intentionally REMOVED — DB columns dropped in 20260429150000.
]);

export async function updatePosterMetadata(
  id: string,
  patch: Record<string, unknown>
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const safePatch = Object.fromEntries(
      Object.entries(patch).filter(([k]) => POSTER_METADATA_ALLOWED.has(k))
    );
    if (Object.keys(safePatch).length === 0) {
      throw new Error("沒有可更新的欄位");
    }
    // Stamp who-did-it. updated_at trigger already fires on UPDATE.
    const patchWithActor = { ...safePatch, updated_by: user.id };

    // If poster_name is being changed, pre-check the unique constraint
    // for friendlier error than raw 23505.
    if (typeof safePatch.poster_name === "string") {
      const trimmed = (safePatch.poster_name as string).trim();
      const { data: existingRow } = await supabase
        .from("posters")
        .select("work_id")
        .eq("id", id)
        .maybeSingle();
      if (existingRow?.work_id) {
        const { data: dup } = await supabase
          .from("posters")
          .select("id")
          .eq("work_id", existingRow.work_id)
          .ilike("poster_name", trimmed)
          .neq("id", id)
          .is("deleted_at", null)
          .maybeSingle();
        if (dup) {
          throw new Error(
            `此作品已有同名海報「${trimmed}」（同名擋下，請改名或加版本標記）`
          );
        }
      }
    }

    const { data, error } = await supabase
      .from("posters")
      .update(patchWithActor)
      .eq("id", id)
      .select("work_id")
      .maybeSingle();
    if (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new Error("此作品已有同名海報（race condition; please retry）");
      }
      throw error;
    }
    revalidatePosterSurfaces(data?.work_id ?? undefined, id);
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
