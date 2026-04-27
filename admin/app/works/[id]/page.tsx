import Link from "next/link";
import { FolderTree } from "lucide-react";
import PageShell from "@/components/PageShell";
import WorkForm from "../new/WorkForm";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

/**
 * Work detail page = work-level metadata + every poster in this work,
 * grouped by their direct parent group as section headers (so the
 * editor can still see "which group does this poster belong to" at a
 * glance without navigating to the catalogue tree). Hierarchy editing
 * itself stays in /tree — single canonical surface for tree shape.
 */
export default async function EditWorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: work }, { data: posters }, { data: groups }] = await Promise.all([
    supabase
      .from("works")
      .select("id, studio, title_zh, title_en, work_kind, movie_release_year")
      .eq("id", id)
      .single(),
    supabase
      .from("posters")
      .select("id, poster_name, region, is_placeholder, parent_group_id, created_at")
      .eq("work_id", id)
      .order("created_at", { ascending: false }),
    supabase
      .from("poster_groups")
      .select("id, name, parent_group_id")
      .eq("work_id", id),
  ]);

  if (!work) notFound();

  // Build group lookup + a "section path" for each group: walk parents to
  // produce a label like "復仇者聯盟系列 / 2024" so the editor sees the
  // immediate context without re-creating the whole tree visually.
  const groupById = new Map<string, { id: string; name: string; parent_group_id: string | null }>();
  for (const g of groups ?? []) groupById.set(g.id, g);

  function pathOf(groupId: string | null): string {
    if (!groupId) return "未掛群組";
    const parts: string[] = [];
    let cur: string | null = groupId;
    let depth = 0;
    while (cur && depth < 20) {
      const g = groupById.get(cur);
      if (!g) break;
      parts.unshift(g.name);
      cur = g.parent_group_id;
      depth++;
    }
    return parts.join(" / ") || "未掛群組";
  }

  // Bucket posters by their group path so we can render one section per
  // group. Maintain insertion order so newest-first poster ordering
  // determines which section comes first too.
  const sections = new Map<string, typeof posters>();
  for (const p of posters ?? []) {
    const key = pathOf(p.parent_group_id);
    if (!sections.has(key)) sections.set(key, []);
    sections.get(key)!.push(p);
  }

  return (
    <PageShell title={work.title_zh} showBack>
      <div className="md:px-0 space-y-6">
        <section className="px-4 pt-4 md:px-0 md:pt-0">
          <h1 className="hidden md:block text-2xl font-semibold mb-6">
            編輯作品：{work.title_zh}
          </h1>
          <WorkForm mode="edit" initial={work} />
        </section>

        {/* CTA — single canonical place to edit hierarchy. */}
        <Link
          href="/tree"
          className="mx-4 md:mx-0 flex items-center gap-3 px-4 py-3 rounded-lg bg-surface border border-line1 hover:bg-surfaceRaised hover:no-underline"
        >
          <FolderTree className="w-5 h-5 shrink-0 text-accent" />
          <div className="flex-1 min-w-0 text-sm text-text">
            在目錄編輯群組與層級
          </div>
          <span className="text-accent shrink-0">→</span>
        </Link>

        <section>
          <div className="flex items-center justify-between mb-2 px-4 md:px-0">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-textMute">
              所有海報（{posters?.length ?? 0}）
            </h2>
            <Link
              href={`/posters/new?work_id=${id}`}
              className="text-xs text-accent px-2 py-1"
            >
              + 新增
            </Link>
          </div>

          {sections.size === 0 ? (
            <ul className="border-y border-line1 md:border md:rounded-lg md:bg-surface">
              <li className="px-4 py-6 text-center text-textFaint text-sm">
                還沒有海報
              </li>
            </ul>
          ) : (
            <div className="space-y-4">
              {[...sections.entries()].map(([sectionLabel, items]) => (
                <div key={sectionLabel}>
                  <div className="px-4 md:px-0 pb-1 text-xs text-textFaint">
                    {sectionLabel} ({items?.length ?? 0})
                  </div>
                  <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
                    {(items ?? []).map((p) => (
                      <li key={p.id}>
                        <Link
                          href={`/posters/${p.id}`}
                          className="flex items-center justify-between px-4 py-3 min-h-[52px] hover:bg-surfaceRaised hover:no-underline"
                        >
                          <div className="min-w-0 flex-1">
                            <div className="text-sm truncate">
                              {p.poster_name ?? "(未命名)"}
                            </div>
                            <div className="text-xs text-textFaint truncate mt-0.5">
                              {p.region ?? "—"}
                              {p.is_placeholder && " · 待補真圖"}
                            </div>
                          </div>
                          {p.is_placeholder && (
                            <span className="text-xs text-amber-400 mr-2">占位</span>
                          )}
                        </Link>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </PageShell>
  );
}
