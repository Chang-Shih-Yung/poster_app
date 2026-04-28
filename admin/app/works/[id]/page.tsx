import Link from "next/link";
import { FolderTree, Plus, ChevronRight } from "lucide-react";
import PageShell from "@/components/PageShell";
import WorkForm from "../new/WorkForm";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { UNNAMED_POSTER } from "@/lib/keys";

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
  const groupById = new Map<
    string,
    { id: string; name: string; parent_group_id: string | null }
  >();
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

  const sections = new Map<string, typeof posters>();
  for (const p of posters ?? []) {
    const key = pathOf(p.parent_group_id);
    if (!sections.has(key)) sections.set(key, []);
    sections.get(key)!.push(p);
  }

  return (
    <PageShell title={work.title_zh} back={true}>
      <div className="px-4 md:px-0 pt-4 md:pt-0 space-y-6">
        <section>
          <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-6">
            編輯作品：{work.title_zh}
          </h1>
          <WorkForm mode="edit" initial={work} />
        </section>

        {/* CTA — single canonical place to edit hierarchy. */}
        <Card>
          <Link
            href="/tree"
            className="flex items-center gap-3 px-4 py-3 hover:no-underline group transition-colors"
          >
            <FolderTree className="w-5 h-5 shrink-0 text-muted-foreground group-hover:text-foreground transition-colors" />
            <div className="flex-1 min-w-0 text-sm text-foreground">
              在目錄編輯群組與層級
            </div>
            <ChevronRight className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
          </Link>
        </Card>

        <section>
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              所有海報（{posters?.length ?? 0}）
            </h2>
            <Button asChild variant="link" size="sm">
              <Link href={`/posters/new?work_id=${id}`}>
                <Plus />
                新增
              </Link>
            </Button>
          </div>

          {sections.size === 0 ? (
            <Card>
              <CardContent className="py-6 text-center text-muted-foreground text-sm">
                還沒有海報
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-4">
              {[...sections.entries()].map(([sectionLabel, items]) => (
                <div key={sectionLabel}>
                  <div className="pb-1 text-xs text-muted-foreground">
                    {sectionLabel} ({items?.length ?? 0})
                  </div>
                  <Card>
                    <CardContent className="p-0">
                      <ul className="divide-y divide-border">
                        {(items ?? []).map((p) => (
                          <li key={p.id}>
                            <Link
                              href={`/posters/${p.id}`}
                              className="flex items-center px-4 py-3 min-h-[52px] hover:no-underline group transition-colors"
                            >
                              <div className="min-w-0 flex-1">
                                <div className="text-sm text-foreground truncate">
                                  {p.poster_name ?? UNNAMED_POSTER}
                                </div>
                                <div className="text-xs text-muted-foreground truncate mt-0.5">
                                  {p.region ?? "—"}
                                  {p.is_placeholder && " · 待補真圖"}
                                </div>
                              </div>
                              {p.is_placeholder && (
                                <Badge variant="placeholder" className="mr-2">
                                  占位
                                </Badge>
                              )}
                              <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0 group-hover:text-foreground transition-colors" />
                            </Link>
                          </li>
                        ))}
                      </ul>
                    </CardContent>
                  </Card>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </PageShell>
  );
}
