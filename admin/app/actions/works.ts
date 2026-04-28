"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";
import { NULL_STUDIO_KEY } from "@/lib/keys";

const WORKS_PAGE_SIZE = 50;

export type WorkRow = {
  id: string;
  studio: string | null;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  movie_release_year: number | null;
  poster_count: number;
  placeholder_count: number;
  created_at: string;
};

export type WorksPage = {
  rows: WorkRow[];
  nextCursor: string | null;
};

export async function loadWorksPage(opts: {
  cursor: string | null;
  studio?: string | null;
}): Promise<ActionResult<WorksPage>> {
  try {
    const { supabase } = await requireAdmin();
    let q = supabase
      .from("works")
      .select(
        "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count, placeholder_count, created_at"
      )
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(WORKS_PAGE_SIZE);

    if (opts.cursor) q = q.lt("created_at", opts.cursor);
    if (opts.studio !== undefined) {
      q =
        opts.studio === null || opts.studio === NULL_STUDIO_KEY
          ? q.is("studio", null)
          : q.eq("studio", opts.studio);
    }
    const { data, error } = await q;
    if (error) throw error;
    const rows = (data ?? []) as WorkRow[];
    const nextCursor =
      rows.length === WORKS_PAGE_SIZE ? rows[rows.length - 1].created_at : null;
    return ok({ rows, nextCursor });
  } catch (e) {
    return fail(e);
  }
}

/**
 * Server actions for `works` rows + the synthetic "studio" pseudo-table
 * (works.studio is just a string column; renaming a studio is bulk
 * UPDATE, deleting it is bulk DELETE). All actions are admin-gated via
 * requireAdmin and revalidate every page that surfaces work data.
 *
 * Cache invalidation strategy: precise paths only (no `"layout"`
 * qualifier). `"layout"` blows up the entire layout segment cache and
 * cascades into sibling routes that did not change — for an editor
 * making rapid edits, that thrashes the cache miss → re-fetch loop.
 * Each surface that consumes a row is listed explicitly below.
 */

function revalidateWorkSurfaces(workId?: string) {
  // The dashboard counts (works/posters/placeholders), the tree root
  // (studio aggregation), the works/posters lists, and the per-work
  // detail page all read works data. Revalidate just those, not entire
  // layout segments.
  revalidatePath("/");
  revalidatePath("/tree");
  revalidatePath("/works");
  revalidatePath("/posters");
  if (workId) {
    revalidatePath(`/works/${workId}`);
    revalidatePath(`/tree/work/${workId}`);
  }
}

export async function createWork(input: {
  title_zh: string;
  studio: string | null;
  work_kind: string;
}): Promise<
  ActionResult<{
    id: string;
    title_zh: string;
    title_en: string | null;
    work_kind: string;
    poster_count: number;
    studio: string | null;
  }>
> {
  try {
    const { supabase, user } = await requireAdmin();
    if (!input.title_zh.trim()) throw new Error("作品名稱必填");
    const { data, error } = await supabase
      .from("works")
      .insert({
        title_zh: input.title_zh.trim(),
        studio: input.studio,
        work_kind: input.work_kind,
      })
      .select("id, title_zh, title_en, work_kind, poster_count, studio")
      .single();
    if (error) throw error;
    revalidateWorkSurfaces();
    await logAudit(supabase, user, {
      action: "create_work",
      target_kind: "work",
      target_id: data.id,
      payload: {
        title_zh: input.title_zh.trim(),
        studio: input.studio,
        work_kind: input.work_kind,
      },
    });
    return ok(data);
  } catch (e) {
    return fail(e);
  }
}

export async function renameWork(
  id: string,
  title_zh: string
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    if (!title_zh.trim()) throw new Error("名稱不能為空");
    const trimmed = title_zh.trim();
    // One round-trip: the update returns the new row. We don't need the
    // pre-rename value for the audit (rename audit answers "who renamed
    // it to what" — the previous value is in the previous audit row).
    const { error } = await supabase
      .from("works")
      .update({ title_zh: trimmed })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit(supabase, user, {
      action: "rename_work",
      target_kind: "work",
      target_id: id,
      payload: { to: trimmed },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function changeWorkKind(
  id: string,
  work_kind: string
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { error } = await supabase
      .from("works")
      .update({ work_kind })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit(supabase, user, {
      action: "change_work_kind",
      target_kind: "work",
      target_id: id,
      payload: { to: work_kind },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/** Runtime whitelist for updateWork — TypeScript types are erased
 *  after compilation, so a crafted JSON payload could include extra
 *  fields (e.g. poster_count, created_at). This strips them. */
const WORK_UPDATE_ALLOWED = new Set([
  "studio",
  "title_zh",
  "title_en",
  "work_kind",
  "movie_release_year",
]);

export async function updateWork(
  id: string,
  patch: {
    studio?: string | null;
    title_zh?: string;
    title_en?: string | null;
    work_kind?: string;
    movie_release_year?: number | null;
  }
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const safePatch = Object.fromEntries(
      Object.entries(patch).filter(([k]) => WORK_UPDATE_ALLOWED.has(k))
    );
    if (Object.keys(safePatch).length === 0) {
      throw new Error("沒有可更新的欄位");
    }
    const { error } = await supabase.from("works").update(safePatch).eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit(supabase, user, {
      action: "update_work",
      target_kind: "work",
      target_id: id,
      payload: patch,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deleteWork(id: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    // Snapshot before deletion — required because after delete the row
    // is gone and the audit log is the only record. This is the one
    // mutation that justifies the extra round-trip.
    const { data: before } = await supabase
      .from("works")
      .select("id, studio, title_zh, title_en, work_kind, poster_count")
      .eq("id", id)
      .maybeSingle();
    const { error } = await supabase.from("works").delete().eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit(supabase, user, {
      action: "delete_work",
      target_kind: "work",
      target_id: id,
      payload: before ? { snapshot: before } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/* ─────────────── studio pseudo-table ─────────────── */

export async function renameStudio(
  oldName: string,
  newName: string
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    if (!newName.trim()) throw new Error("分類名稱不能為空");
    if (newName === oldName) return ok(undefined);
    const trimmed = newName.trim();
    // Combine the count + update into one atomic write that returns the
    // affected rows. Postgres .update().select() yields the new state,
    // and the row count is rows.length — saving the separate COUNT
    // round-trip we used to do.
    const q = supabase.from("works").update({ studio: trimmed });
    const { data: rows, error } =
      oldName === NULL_STUDIO_KEY
        ? await q.is("studio", null).select("id")
        : await q.eq("studio", oldName).select("id");
    if (error) throw error;
    revalidateWorkSurfaces();
    await logAudit(supabase, user, {
      action: "rename_studio",
      target_kind: "studio",
      target_id: trimmed,
      payload: {
        from: oldName,
        to: trimmed,
        affected_works: rows?.length ?? 0,
      },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/** Hard cap for bulk studio deletion — a safety net against
 *  accidental wipes when confirm() is bypassed via direct fetch. */
const STUDIO_DELETE_MAX = 50;

export async function deleteStudio(studio: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    if (studio === NULL_STUDIO_KEY) {
      throw new Error(
        "「未分類」是虛擬分類，無法直接刪除；請改名讓裡面的作品有歸屬"
      );
    }
    // Snapshot before deletion — also serves as a server-side count
    // guard so a crafted request that skips the client confirm()
    // dialog can't wipe unbounded data.
    const { data: before } = await supabase
      .from("works")
      .select("id, title_zh, poster_count")
      .eq("studio", studio);
    if ((before?.length ?? 0) > STUDIO_DELETE_MAX) {
      throw new Error(
        `分類底下有 ${before!.length} 部作品，超過安全上限 ${STUDIO_DELETE_MAX}。請先個別刪除或搬移作品。`
      );
    }
    const { error } = await supabase.from("works").delete().eq("studio", studio);
    if (error) throw error;
    revalidateWorkSurfaces();
    await logAudit(supabase, user, {
      action: "delete_studio",
      target_kind: "studio",
      target_id: studio,
      payload: {
        deleted_works: before ?? [],
        total_posters: (before ?? []).reduce(
          (n, w) => n + ((w.poster_count as number | null) ?? 0),
          0
        ),
      },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
