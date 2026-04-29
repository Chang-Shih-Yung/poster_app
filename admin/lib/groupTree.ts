/**
 * Pure helpers for navigating and aggregating the work → group → poster
 * tree. Exposed as plain functions so server pages, client components,
 * and tests can all share one implementation.
 */

export type GroupRow = {
  id: string;
  name?: string;
  parent_group_id: string | null;
};

export type PosterRow = {
  parent_group_id: string | null;
};

/**
 * Recursive total of posters living anywhere under the given group
 * (direct children + every descendant). Used to render a meaningful
 * count badge while a folder is collapsed.
 *
 * Both arrays are scoped to a single work — caller already filtered.
 */
export function recursivePosterCount(
  groupId: string,
  groups: GroupRow[],
  posters: PosterRow[]
): number {
  // Map: parent_id (or "__root__") → child group ids
  const subOf = new Map<string, string[]>();
  for (const g of groups) {
    const parent = g.parent_group_id ?? "__root__";
    if (!subOf.has(parent)) subOf.set(parent, []);
    subOf.get(parent)!.push(g.id);
  }
  // Direct poster count keyed by parent_group_id
  const directCount = new Map<string, number>();
  for (const p of posters) {
    if (!p.parent_group_id) continue;
    directCount.set(
      p.parent_group_id,
      (directCount.get(p.parent_group_id) ?? 0) + 1
    );
  }
  function walk(id: string): number {
    let total = directCount.get(id) ?? 0;
    for (const sub of subOf.get(id) ?? []) total += walk(sub);
    return total;
  }
  return walk(groupId);
}

/**
 * Walk parent links to produce a "/"-joined path for a group, like
 * "復仇者聯盟系列 / 2024". Bounded at 20 hops so a malformed parent
 * cycle can't loop forever.
 */
export function groupPath(
  groupId: string | null,
  byId: Map<string, GroupRow>
): string {
  if (!groupId) return "未掛群組";
  const parts: string[] = [];
  let cur: string | null = groupId;
  let depth = 0;
  while (cur && depth < 20) {
    const g = byId.get(cur);
    if (!g) break;
    parts.unshift(g.name ?? "(unknown)");
    cur = g.parent_group_id;
    depth++;
  }
  return parts.join(" / ") || "未掛群組";
}

/**
 * Flatten a poster_groups tree into a list. Each item carries:
 *   - `label`: full parent path (e.g. "美麗華 / 2025 / 限定版") — used
 *              by the trigger so user sees the full context.
 *   - `name`:  just the leaf node name — useful when UI wants to render
 *              indented rows instead of repeating the path.
 *   - `depth`: 0 = top-level under the work, 1+ = nested. Used by
 *              dropdowns to insert a separator before each new top
 *              group (depth=0) and/or to indent child rows.
 */
export type FlattenInput = {
  id: string;
  name: string;
  parent_group_id: string | null;
  display_order: number;
};

export type FlattenedGroup = {
  id: string;
  label: string;
  name: string;
  depth: number;
};

export function flattenGroupTree(rows: FlattenInput[]): FlattenedGroup[] {
  const childrenMap = new Map<string | null, FlattenInput[]>();
  for (const r of rows) {
    const arr = childrenMap.get(r.parent_group_id) ?? [];
    arr.push(r);
    childrenMap.set(r.parent_group_id, arr);
  }
  const out: FlattenedGroup[] = [];
  function walk(parent: string | null, prefix: string[]) {
    const kids = (childrenMap.get(parent) ?? []).sort((a, b) =>
      a.display_order !== b.display_order
        ? a.display_order - b.display_order
        : a.name.localeCompare(b.name)
    );
    for (const k of kids) {
      const path = [...prefix, k.name];
      out.push({
        id: k.id,
        label: path.join(" / "),
        name: k.name,
        depth: prefix.length,
      });
      walk(k.id, path);
    }
  }
  walk(null, []);
  return out;
}
