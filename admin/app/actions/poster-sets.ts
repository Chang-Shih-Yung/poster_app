"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";

/**
 * Server actions for poster_sets ("套票"). One set = N posters released
 * together (cinema bundle, IG campaign, ticket combo). Independent of
 * works/groups: a set can span multiple works.
 *
 * UI surfaces:
 *   - PosterForm picker (inline create + select)
 *   - Future: dedicated /sets management page
 */

export type PosterSet = {
  id: string;
  name: string;
  description: string | null;
  cover_url: string | null;
  created_at: string;
  updated_at: string;
};

/**
 * List all sets — cheap because there shouldn't be many (~tens). If this
 * grows past a few hundred we'll add server-side search; for now the
 * SearchableSelect on the client filters in memory.
 */
export async function listPosterSets(): Promise<ActionResult<PosterSet[]>> {
  try {
    const { supabase } = await requireAdmin();
    const { data, error } = await supabase
      .from("poster_sets")
      .select("id, name, description, cover_url, created_at, updated_at")
      .order("created_at", { ascending: false });
    if (error) throw error;
    return ok((data ?? []) as PosterSet[]);
  } catch (e) {
    return fail(e);
  }
}

export async function createPosterSet(input: {
  name: string;
  description?: string | null;
}): Promise<ActionResult<{ id: string; name: string }>> {
  try {
    const { supabase, user } = await requireAdmin();
    const trimmed = input.name.trim();
    if (!trimmed) throw new Error("套票名稱必填");

    const { data, error } = await supabase
      .from("poster_sets")
      .insert({
        name: trimmed,
        description: input.description?.trim() || null,
        created_by: user.id,
      })
      .select("id, name")
      .single();
    if (error) throw error;

    revalidatePath("/posters");
    void logAudit(supabase, user, {
      action: "create_poster_set",
      target_kind: "poster_set",
      target_id: data.id as string,
      payload: { name: data.name },
    });
    return ok({ id: data.id as string, name: data.name as string });
  } catch (e) {
    return fail(e);
  }
}

export async function updatePosterSet(
  id: string,
  patch: { name?: string; description?: string | null }
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const cleanPatch: Record<string, unknown> = {};
    if (patch.name !== undefined) {
      const t = patch.name.trim();
      if (!t) throw new Error("套票名稱不能為空");
      cleanPatch.name = t;
    }
    if (patch.description !== undefined) {
      cleanPatch.description = patch.description?.trim() || null;
    }
    if (Object.keys(cleanPatch).length === 0) {
      throw new Error("沒有可更新的欄位");
    }
    const { error } = await supabase
      .from("poster_sets")
      .update(cleanPatch)
      .eq("id", id);
    if (error) throw error;
    revalidatePath("/posters");
    void logAudit(supabase, user, {
      action: "update_poster_set",
      target_kind: "poster_set",
      target_id: id,
      payload: cleanPatch,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deletePosterSet(id: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: existing } = await supabase
      .from("poster_sets")
      .select("name")
      .eq("id", id)
      .maybeSingle();
    const { error } = await supabase.from("poster_sets").delete().eq("id", id);
    if (error) throw error;
    // posters.set_id cascades to NULL (FK ON DELETE SET NULL) — posters
    // themselves stay, just lose the set link.
    revalidatePath("/posters");
    void logAudit(supabase, user, {
      action: "delete_poster_set",
      target_kind: "poster_set",
      target_id: id,
      payload: existing ? { snapshot: existing } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
