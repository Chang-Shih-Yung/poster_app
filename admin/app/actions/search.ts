"use server";

import { requireAdmin } from "./_internal";

export type SearchResult = {
  kind: "group" | "poster";
  id: string;
  label: string;
  /** For groups: the work title. For posters: the work title + group path. */
  meta: string;
  /** Poster thumbnail URL (null for groups / placeholder posters). */
  thumbnailUrl: string | null;
};

/**
 * Full-text style search across poster_groups and posters.
 * Returns up to 8 results per kind, merged and ordered: groups first,
 * then posters.
 */
export async function globalSearch(
  query: string
): Promise<SearchResult[]> {
  const q = query.trim();
  if (q.length < 1) return [];

  const { supabase } = await requireAdmin();
  const pattern = `%${q}%`;

  const [groupsRes, postersRes] = await Promise.all([
    supabase
      .from("poster_groups")
      .select(
        "id, name, works!inner(title_zh)"
      )
      .ilike("name", pattern)
      .is("deleted_at", null)
      .limit(8),
    supabase
      .from("posters")
      .select(
        "id, poster_name, thumbnail_url, works!inner(title_zh)"
      )
      .ilike("poster_name", pattern)
      .is("deleted_at", null)
      .limit(8),
  ]);

  const results: SearchResult[] = [];

  for (const g of groupsRes.data ?? []) {
    const work = Array.isArray(g.works) ? g.works[0] : g.works;
    results.push({
      kind: "group",
      id: g.id as string,
      label: g.name as string,
      meta: (work as { title_zh: string } | null)?.title_zh ?? "—",
      thumbnailUrl: null,
    });
  }

  for (const p of postersRes.data ?? []) {
    const work = Array.isArray(p.works) ? p.works[0] : p.works;
    results.push({
      kind: "poster",
      id: p.id as string,
      label: (p.poster_name as string | null) ?? "（未命名）",
      meta: (work as { title_zh: string } | null)?.title_zh ?? "—",
      thumbnailUrl: (p.thumbnail_url as string | null) ?? null,
    });
  }

  return results;
}
