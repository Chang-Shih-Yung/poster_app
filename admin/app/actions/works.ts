"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, type ActionResult } from "./_internal";
import { NULL_STUDIO_KEY } from "@/app/tree/_components/keys";

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
    const { error } = await supabase
      .from("works")
      .update({ title_zh: title_zh.trim() })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
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
    const { error } = await supabase
      .from("works")
      .update({ work_kind })
      .eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
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
    const { error } = await supabase.from("works").delete().eq("id", id);
    if (error) throw error;
    revalidateWorkSurfaces(id);
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
    const q = supabase.from("works").update({ studio: newName.trim() });
    const { error } =
      oldName === NULL_STUDIO_KEY
        ? await q.is("studio", null)
        : await q.eq("studio", oldName);
    if (error) throw error;
    revalidateWorkSurfaces();
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
    const { error } = await supabase.from("works").delete().eq("studio", studio);
    if (error) throw error;
    revalidateWorkSurfaces();
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
