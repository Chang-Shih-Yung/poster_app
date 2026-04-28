"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, type ActionResult } from "./_internal";

/**
 * Server actions for `poster_groups` rows. Same revalidation surface as
 * works (a group rename changes the breadcrumb on the work page; a
 * group delete shifts poster counts across the tree).
 */

function revalidateGroupSurfaces(workId?: string, groupId?: string) {
  revalidatePath("/tree", "layout");
  revalidatePath("/works", "layout");
  revalidatePath("/posters", "layout");
  if (workId) {
    revalidatePath(`/works/${workId}`);
    revalidatePath(`/tree/work/${workId}`);
  }
  if (groupId) revalidatePath(`/tree/group/${groupId}`);
}

export async function createGroup(input: {
  work_id: string;
  parent_group_id: string | null;
  name: string;
}): Promise<
  ActionResult<{
    id: string;
    name: string;
    group_type: string | null;
  }>
> {
  try {
    const { supabase } = await requireAdmin();
    if (!input.name.trim()) throw new Error("群組名稱必填");
    const { data, error } = await supabase
      .from("poster_groups")
      .insert({
        work_id: input.work_id,
        parent_group_id: input.parent_group_id,
        name: input.name.trim(),
      })
      .select("id, name, group_type")
      .single();
    if (error) throw error;
    revalidateGroupSurfaces(input.work_id, input.parent_group_id ?? undefined);
    return ok(data);
  } catch (e) {
    return fail(e);
  }
}

export async function renameGroup(
  id: string,
  name: string
): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    if (!name.trim()) throw new Error("名稱不能為空");
    const { data: existing, error: lookupErr } = await supabase
      .from("poster_groups")
      .select("work_id")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("poster_groups")
      .update({ name: name.trim() })
      .eq("id", id);
    if (error) throw error;
    revalidateGroupSurfaces(existing?.work_id ?? undefined, id);
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deleteGroup(id: string): Promise<ActionResult> {
  try {
    const { supabase } = await requireAdmin();
    const { data: existing, error: lookupErr } = await supabase
      .from("poster_groups")
      .select("work_id, parent_group_id")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    const { error } = await supabase
      .from("poster_groups")
      .delete()
      .eq("id", id);
    if (error) throw error;
    revalidateGroupSurfaces(
      existing?.work_id ?? undefined,
      existing?.parent_group_id ?? undefined
    );
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
