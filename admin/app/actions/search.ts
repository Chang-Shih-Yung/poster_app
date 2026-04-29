"use server";

import { requireAdmin } from "./_internal";

export type SearchResult = {
  kind: "studio" | "work" | "group" | "poster";
  id: string;
  label: string;
  /** Sub-line text. Studio: count summary. Work: studio + year. Group:
   * the parent work title. Poster: work title (+ optional group path). */
  meta: string;
  /** Poster thumbnail URL (null for groups/works/studios + placeholder posters). */
  thumbnailUrl: string | null;
};

/**
 * Substring search across the entire tree hierarchy:
 *   studio → work → group → poster
 *
 * Returns up to ~6 results per layer, ordered top-down so the user
 * always sees broader hits before the narrowest. Backed by `ilike`
 * substring match — adequate for our scale (~hundreds of works).
 *
 * Folder vs poster icon (rendered in GlobalSearch component):
 *   - studio  → folder
 *   - work    → folder
 *   - group   → folder
 *   - poster  → thumbnail / image icon
 */
export async function globalSearch(
  query: string
): Promise<SearchResult[]> {
  const q = query.trim();
  if (q.length < 1) return [];

  const { supabase } = await requireAdmin();
  const pattern = `%${q}%`;

  const [studiosRes, worksRes, groupsRes, postersRes] = await Promise.all([
    // Studios are a derived dimension (DISTINCT works.studio). We pull
    // matching works and dedupe in JS — Supabase's PostgREST doesn't
    // do server-side DISTINCT cleanly. ~100 row cap is plenty.
    supabase
      .from("works")
      .select("studio")
      .ilike("studio", pattern)
      .not("studio", "is", null)
      .limit(100),
    supabase
      .from("works")
      .select("id, title_zh, title_en, studio, movie_release_year, poster_count")
      .or(`title_zh.ilike.${pattern},title_en.ilike.${pattern}`)
      .limit(8),
    // poster_groups doesn't have a deleted_at column (only posters does).
    // Earlier we filtered .is("deleted_at", null) here by mistake — that
    // would silently fail and return 0 rows even when the group existed.
    supabase
      .from("poster_groups")
      .select("id, name, works!inner(title_zh)")
      .ilike("name", pattern)
      .limit(8),
    supabase
      .from("posters")
      .select("id, poster_name, thumbnail_url, works!inner(title_zh)")
      .ilike("poster_name", pattern)
      .is("deleted_at", null)
      .limit(8),
  ]);

  const results: SearchResult[] = [];

  // ── Studios (dedupe + count from the over-fetched 100-row cap) ─
  if (studiosRes.data && studiosRes.data.length > 0) {
    const counts = new Map<string, number>();
    for (const row of studiosRes.data) {
      const s = row.studio as string | null;
      if (!s) continue;
      counts.set(s, (counts.get(s) ?? 0) + 1);
    }
    // Sort by count desc, take top 4
    const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
    for (const [studio, count] of sorted) {
      results.push({
        kind: "studio",
        id: studio,
        label: studio,
        meta: `${count} 部作品`,
        thumbnailUrl: null,
      });
    }
  }

  // ── Works ────────────────────────────────────────────────────
  for (const w of worksRes.data ?? []) {
    const subtitleParts = [
      w.studio as string | null,
      w.movie_release_year ? String(w.movie_release_year) : null,
      w.poster_count ? `${w.poster_count} 張海報` : null,
    ].filter(Boolean);
    results.push({
      kind: "work",
      id: w.id as string,
      label: (w.title_zh as string | null) ?? (w.title_en as string | null) ?? "—",
      meta: subtitleParts.join(" · ") || "—",
      thumbnailUrl: null,
    });
  }

  // ── Groups ───────────────────────────────────────────────────
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

  // ── Posters ──────────────────────────────────────────────────
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

