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
    void logAudit(supabase, user, {
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
    void logAudit(supabase, user, {
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

/**
 * Move a group to a different parent (or to work root if newParentGroupId is null).
 * Guards against circular references — you cannot move a group inside one of its
 * own descendants.
 */
export async function moveGroup(
  id: string,
  newParentGroupId: string | null
): Promise<ActionResult> {
  try {
    const { supabase, user } = await requireAdmin();

    // Fetch current state for audit + revalidation.
    const { data: existing, error: lookupErr } = await supabase
      .from("poster_groups")
      .select("work_id, parent_group_id, name")
      .eq("id", id)
      .maybeSingle();
    if (lookupErr) throw lookupErr;
    if (!existing) throw new Error("找不到此群組");

    // No-op: already at the target parent.
    if (existing.parent_group_id === newParentGroupId) return ok(undefined);

    // Circular-dependency guard: walk the subtree rooted at `id` via a
    // recursive CTE and reject if `newParentGroupId` is a descendant.
    if (newParentGroupId !== null) {
      const { data: subtree, error: treeErr } = await supabase
        .from("poster_groups")
        .select("id")
        .or(`id.eq.${id},parent_group_id.eq.${id}`);
      if (treeErr) throw treeErr;

      // Full BFS using in-memory rows (adequate for typical group tree depth).
      const descendantIds = new Set<string>();
      const queue = [id];
      while (queue.length) {
        const cur = queue.shift()!;
        descendantIds.add(cur);
        // Fetch children of `cur`.
        const { data: children } = await supabase
          .from("poster_groups")
          .select("id")
          .eq("parent_group_id", cur)
          .eq("work_id", existing.work_id);
        for (const c of children ?? []) queue.push(c.id as string);
      }
      if (descendantIds.has(newParentGroupId)) {
        throw new Error("無法將群組移到自己的子群組內");
      }
    }

    const { error } = await supabase
      .from("poster_groups")
      .update({ parent_group_id: newParentGroupId })
      .eq("id", id);
    if (error) throw error;

    revalidateGroupSurfaces(existing.work_id ?? undefined, id);
    if (existing.parent_group_id)
      revalidateGroupSurfaces(undefined, existing.parent_group_id);
    if (newParentGroupId)
      revalidateGroupSurfaces(undefined, newParentGroupId);

    void logAudit(supabase, user, {
      action: "move_group",
      target_kind: "group",
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

    // Cascade scope snapshot. Since 20260430100000 the FK is ON DELETE
    // CASCADE, so deleting a group nukes every descendant group AND
    // every poster under any descendant. Capture the counts BEFORE the
    // delete so the audit log can answer "how big was the blast" later.
    let cascade: { posters_total: number; placeholders: number } | null = null;
    if (existing?.work_id) {
      const { data: counts } = await supabase.rpc(
        "get_group_recursive_counts",
        { p_work_id: existing.work_id as string }
      );
      const row = (counts as { group_id: string; total: number; placeholder_total: number }[] | null)
        ?.find((r) => r.group_id === id);
      if (row) {
        cascade = {
          posters_total: Number(row.total ?? 0),
          placeholders: Number(row.placeholder_total ?? 0),
        };
      }
    }

    const { error } = await supabase
      .from("poster_groups")
      .delete()
      .eq("id", id);
    if (error) throw error;
    revalidateGroupSurfaces(
      existing?.work_id ?? undefined,
      existing?.parent_group_id ?? undefined
    );
    void logAudit(supabase, user, {
      action: "delete_group",
      target_kind: "group",
      target_id: id,
      payload: existing ? { snapshot: existing, cascade } : null,
    });
    return ok(undefined);
  } catch (e) {
    return fail(e);
  }
}
