"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin, ok, fail, logAudit, type ActionResult } from "./_internal";

/**
 * Server actions for `poster_groups` rows. Same revalidation surface as
 * works (a group rename changes the breadcrumb on the work page; a
 * group delete shifts poster counts across the tree).
 */

function revalidateGroupSurfaces(workId?: string, groupId?: string) {
  revalidatePath("/tree");
  revalidatePath("/works");
  revalidatePath("/posters");
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
    const { supabase, user } = await requireAdmin();
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
    await logAudit(supabase, user, {
      action: "create_group",
      target_kind: "group",
      target_id: data.id,
      payload: {
        work_id: input.work_id,
        parent_group_id: input.parent_group_id,
        name: input.name.trim(),
      },
    });
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
    const { supabase, user } = await requireAdmin();
    if (!name.trim()) throw new Error("名稱不能為空");
    const trimmed = name.trim();
    // One round-trip: update returns the new row + work_id needed for
    // revalidate. No separate lookup of the previous name (audit log
    // records "to" only; previous values are in the prior audit row).
    const { data, error } = await supabase
      .from("poster_groups")
      .update({ name: trimmed })
      .eq("id", id)
      .select("work_id")
      .maybeSingle();
    if (error) throw error;
    revalidateGroupSurfaces(data?.work_id ?? undefined, id);
    await logAudit(supabase, user, {
      action: "rename_group",
      target_kind: "group",
      target_id: id,
      payload: { to: trimmed },
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}

export async function deleteGroup(id: string): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();
    // Snapshot is required — after delete the row is gone and the
    // audit log is the only post-mortem.
    const { data: existing, error: lookupErr } = await supabase
      .from("poster_groups")
      .select("work_id, parent_group_id, name, group_type")
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
    await logAudit(supabase, user, {
      action: "delete_group",
      target_kind: "group",
      target_id: id,
      payload: existing ? { snapshot: existing } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
