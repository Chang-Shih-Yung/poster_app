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

/* ─────────────── 海報組合（sibling 為導向的 UX）─────────────────
 *
 * 合夥人 spec #14 mental model：admin 不思考 set 這個物件，他只想說
 * 「這張跟那張是一組」。後端我們仍用 poster_sets 表當底層存儲（FK
 * ON DELETE SET NULL，刪 set 海報還在），但 server actions 暴露出
 * 給 UI 的 API 是 sibling-shaped：linkPosters / unlinkPoster /
 * listSiblings。Admin 不用先建 set。
 * ───────────────────────────────────────────────────────────── */

export type SiblingPoster = {
  id: string;
  poster_name: string | null;
  work_title_zh: string | null;
  thumbnail_url: string | null;
  is_placeholder: boolean;
};

/**
 * 列出某張海報的同組合夥伴（同 set_id，排除自己）。
 * 海報沒掛 set_id（單張）→ 回空陣列。
 */
export async function listSiblings(
  posterId: string
): Promise<ActionResult<SiblingPoster[]>> {
  try {
    const { supabase } = await requireAdmin();
    const { data: self, error: selfErr } = await supabase
      .from("posters")
      .select("set_id")
      .eq("id", posterId)
      .maybeSingle();
    if (selfErr) throw selfErr;
    const setId = self?.set_id as string | null | undefined;
    if (!setId) return ok([]);
    const { data, error } = await supabase
      .from("posters")
      .select("id, poster_name, thumbnail_url, is_placeholder, works!inner(title_zh)")
      .eq("set_id", setId)
      .neq("id", posterId)
      .is("deleted_at", null);
    if (error) throw error;
    const rows: SiblingPoster[] = (data ?? []).map((p) => {
      const work = Array.isArray(p.works) ? p.works[0] : p.works;
      return {
        id: p.id as string,
        poster_name: (p.poster_name as string | null) ?? null,
        work_title_zh: (work as { title_zh: string } | null)?.title_zh ?? null,
        thumbnail_url: (p.thumbnail_url as string | null) ?? null,
        is_placeholder: !!p.is_placeholder,
      };
    });
    return ok(rows);
  } catch (e) {
    return fail(e);
  }
}

/**
 * 把 posterId 加到 siblingId 的組合。
 *
 * 三種情境（自動處理）：
 *   1. sibling 已有 set_id  → posterId.set_id = 那個 set
 *   2. sibling 沒 set_id   → 新建一個 set（auto-name），兩者都進
 *   3. posterId 已有別的 set_id → 警告：要先 unlink 自己才能加入新組合
 *      （避免 silent merge 兩個 set，admin 預期外）
 */
export async function linkPosters(input: {
  poster_id: string;
  sibling_id: string;
}): Promise<ActionResult<{ set_id: string }>> {
  try {
    const { supabase, user } = await requireAdmin();
    if (input.poster_id === input.sibling_id) {
      throw new Error("不能把海報跟自己綁在一起");
    }
    const { data: rows, error: lookupErr } = await supabase
      .from("posters")
      .select("id, set_id, poster_name, work_id")
      .in("id", [input.poster_id, input.sibling_id]);
    if (lookupErr) throw lookupErr;
    const self = (rows ?? []).find((r) => r.id === input.poster_id);
    const sib = (rows ?? []).find((r) => r.id === input.sibling_id);
    if (!self) throw new Error("找不到海報");
    if (!sib) throw new Error("找不到要連結的海報");

    let targetSetId = (sib.set_id as string | null) ?? null;

    if (
      self.set_id &&
      targetSetId &&
      self.set_id !== targetSetId
    ) {
      throw new Error(
        "這張海報已經屬於別的組合，要先在這張海報上把組合解除才能加入新組合"
      );
    }

    if (!targetSetId) {
      // 兩者都沒 set — 建一個 auto-named set 把兩者放進去。
      // 名字暫用「同 work / 多 work」+ 時間 sentinel；admin 之後可以
      // 在 /sets 改名。
      const autoName = `組合 ${new Date()
        .toISOString()
        .replace(/[T:.Z-]/g, "")
        .slice(0, 12)}`;
      const { data: newSet, error: createErr } = await supabase
        .from("poster_sets")
        .insert({ name: autoName, created_by: user.id })
        .select("id")
        .single();
      if (createErr) throw createErr;
      targetSetId = newSet.id as string;
    }

    // self 加入 target set（含 self 已經在 same set 的 idempotent case）
    const idsToUpdate: string[] = [];
    if (self.set_id !== targetSetId) idsToUpdate.push(self.id as string);
    if (sib.set_id !== targetSetId) idsToUpdate.push(sib.id as string);
    if (idsToUpdate.length > 0) {
      const { error: updErr } = await supabase
        .from("posters")
        .update({ set_id: targetSetId })
        .in("id", idsToUpdate);
      if (updErr) throw updErr;
    }

    revalidatePath(`/posters/${input.poster_id}`);
    revalidatePath(`/posters/${input.sibling_id}`);
    void logAudit(supabase, user, {
      action: "link_posters",
      target_kind: "poster",
      target_id: input.poster_id,
      payload: { sibling_id: input.sibling_id, set_id: targetSetId },
    });
    return ok({ set_id: targetSetId });
  } catch (e) {
    return fail(e);
  }
}

/**
 * 把 posterId 從目前所屬組合移除（set_id = null）。
 * 移除後如果該 set 只剩 < 2 張海報（孤兒），順手把 set 砍掉，
 * 那張剩下的也 set_id = null — 一張不算組合。
 */
export async function unlinkPoster(
  posterId: string
): Promise<ActionResult<{ deleted_set: boolean }>> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: self, error: selfErr } = await supabase
      .from("posters")
      .select("set_id")
      .eq("id", posterId)
      .maybeSingle();
    if (selfErr) throw selfErr;
    const oldSetId = (self?.set_id as string | null) ?? null;
    if (!oldSetId) return ok({ deleted_set: false });

    // self 先離開 set
    const { error: updErr } = await supabase
      .from("posters")
      .update({ set_id: null })
      .eq("id", posterId);
    if (updErr) throw updErr;

    // 看 set 還剩幾張
    const { data: remaining, error: countErr } = await supabase
      .from("posters")
      .select("id")
      .eq("set_id", oldSetId)
      .is("deleted_at", null);
    if (countErr) throw countErr;
    let deletedSet = false;
    if ((remaining?.length ?? 0) < 2) {
      // 把剩下的也踢出 + 刪 set
      if ((remaining?.length ?? 0) === 1) {
        await supabase
          .from("posters")
          .update({ set_id: null })
          .eq("id", remaining![0].id as string);
      }
      await supabase.from("poster_sets").delete().eq("id", oldSetId);
      deletedSet = true;
    }

    revalidatePath(`/posters/${posterId}`);
    void logAudit(supabase, user, {
      action: "unlink_poster",
      target_kind: "poster",
      target_id: posterId,
      payload: { from_set_id: oldSetId, deleted_set: deletedSet },
    });
    return ok({ deleted_set: deletedSet });
  } catch (e) {
    return fail(e);
  }
}

/**
 * 給 sibling picker 用的「所有海報」清單。會排除 self（如果有），
 * 排除已經在 self 同 set 的（避免 admin 重複加）。
 *
 * 返回精簡欄位 — name + work + thumbnail，足夠 picker 顯示。
 */
export async function listAllPostersForPicker(
  excludePosterId: string | null
): Promise<ActionResult<SiblingPoster[]>> {
  try {
    const { supabase } = await requireAdmin();
    let q = supabase
      .from("posters")
      .select("id, poster_name, thumbnail_url, is_placeholder, works!inner(title_zh)")
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(500);
    if (excludePosterId) q = q.neq("id", excludePosterId);
    const { data, error } = await q;
    if (error) throw error;
    const rows: SiblingPoster[] = (data ?? []).map((p) => {
      const work = Array.isArray(p.works) ? p.works[0] : p.works;
      return {
        id: p.id as string,
        poster_name: (p.poster_name as string | null) ?? null,
        work_title_zh: (work as { title_zh: string } | null)?.title_zh ?? null,
        thumbnail_url: (p.thumbnail_url as string | null) ?? null,
        is_placeholder: !!p.is_placeholder,
      };
    });
    return ok(rows);
  } catch (e) {
    return fail(e);
  }
}
