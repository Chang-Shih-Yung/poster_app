"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";
import { NULL_STUDIO_KEY } from "@/app/tree/_components/keys";

/**
 * Page size for the cursor-based "load more" buttons on /works and
 * /tree/studio/[studio]. Small enough to render fast on first paint,
 * big enough that we don't pummel the DB on a busy studio.
 */
const WORKS_PAGE_SIZE = 50;

export type WorkRow = {
  id: string;
  studio: string | null;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  movie_release_year: number | null;
  poster_count: number;
  created_at: string;
};

export type WorksPage = {
  rows: WorkRow[];
  /** Cursor for the next page, or null when this was the last batch. */
  nextCursor: string | null;
};

/**
 * Fetch one page of works, optionally scoped to a studio. Cursor is
 * the previous batch's last `created_at` (ISO string). Sort order is
 * `created_at DESC, id DESC` so the cursor is monotonic and stable
 * even when two works share a created_at.
 */
export async function loadWorksPage(opts: {
  cursor: string | null;
  studio?: string | null; // omit for "all studios" (the /works listing)
}): Promise<ActionResult<WorksPage>> {
  try {
    const { supabase } = await requireAdmin();
    let q = supabase
      .from("works")
      .select(
        "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count, created_at"
      )
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(WORKS_PAGE_SIZE);

    if (opts.cursor) {
      // Cursor: rows strictly older than this timestamp. The id tie-break
      // doesn't matter for the request — supabase doesn't expose tuple
      // comparison cleanly — and the page size is small enough that any
      // duplicate-timestamp edge is negligible.
      q = q.lt("created_at", opts.cursor);
    }
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
 */

function revalidateWorkSurfaces(workId?: string) {
  // Studio + work pages all read works one way or another; revalidate
  // the umbrella surfaces every time so we never serve stale list/tree
  // counts after a mutation.
  revalidatePath("/tree", "layout");
  revalidatePath("/works", "layout");
  revalidatePath("/posters", "layout");
  revalidatePath("/", "layout");
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
    const { supabase } = await requireAdmin();
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
    const { supabase } = await requireAdmin();
    if (!title_zh.trim()) throw new Error("名稱不能為空");
    const trimmed = title_zh.trim();
    const { data: before } = await supabase
      .from("works")
      .select("title_zh")
      .eq("id", id)
      .maybeSingle();
    const { error } = await supabase
      .from("works")
      .update({ title_zh: trimmed })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit({
      action: "rename_work",
      target_kind: "work",
      target_id: id,
      payload: { from: before?.title_zh ?? null, to: trimmed },
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
    const { supabase } = await requireAdmin();
    const { data: before } = await supabase
      .from("works")
      .select("work_kind")
      .eq("id", id)
      .maybeSingle();
    const { error } = await supabase
      .from("works")
      .update({ work_kind })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit({
      action: "change_work_kind",
      target_kind: "work",
      target_id: id,
      payload: { from: before?.work_kind ?? null, to: work_kind },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

/**
 * Generic patch for works — used by /works/[id] and /works/new where
 * the form lets the user edit the full row at once. Specialised
 * actions (renameWork, changeWorkKind) stay around for one-off Sheet
 * forms in the tree where only one field changes.
 */
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
    const { supabase } = await requireAdmin();
    const { error } = await supabase.from("works").update(patch).eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deleteWork(id: string): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    // Snapshot before deletion so the audit trail captures what was lost.
    const { data: before } = await supabase
      .from("works")
      .select("id, studio, title_zh, title_en, work_kind, poster_count")
      .eq("id", id)
      .maybeSingle();
    const { error } = await supabase.from("works").delete().eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
    await logAudit({
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
    const { supabase } = await requireAdmin();
    if (!newName.trim()) throw new Error("分類名稱不能為空");
    if (newName === oldName) return ok(undefined);
    const trimmed = newName.trim();
    // Count affected rows for the audit payload before we mutate.
    const countQ =
      oldName === NULL_STUDIO_KEY
        ? supabase.from("works").select("id", { count: "exact", head: true }).is("studio", null)
        : supabase.from("works").select("id", { count: "exact", head: true }).eq("studio", oldName);
    const { count: affected } = await countQ;
    const q = supabase.from("works").update({ studio: trimmed });
    const { error } =
      oldName === NULL_STUDIO_KEY
        ? await q.is("studio", null)
        : await q.eq("studio", oldName);
    if (error) throw error;
    revalidateWorkSurfaces();
    await logAudit({
      action: "rename_studio",
      target_kind: "studio",
      target_id: trimmed,
      payload: { from: oldName, to: trimmed, affected_works: affected ?? null },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deleteStudio(studio: string): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    if (studio === NULL_STUDIO_KEY) {
      throw new Error(
        "「未分類」是虛擬分類，無法直接刪除；請改名讓裡面的作品有歸屬"
      );
    }
    // Snapshot the work titles + counts before the cascade demolition.
    const { data: before } = await supabase
      .from("works")
      .select("id, title_zh, poster_count")
      .eq("studio", studio);
    const { error } = await supabase.from("works").delete().eq("studio", studio);
    if (error) throw error;
    revalidateWorkSurfaces();
    await logAudit({
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
