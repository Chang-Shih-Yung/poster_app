import PageShell from "@/components/PageShell";
import TreeBrowser from "./TreeBrowser";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

/**
 * Top-level tree page. Server-fetches the studio list (with work counts
 * and poster counts aggregated). Each studio node is expanded
 * client-side on tap, which triggers a fetch of its works via the
 * client Supabase helper.
 */
export default async function TreePage() {
  const supabase = await createClient();

  // Aggregate at studio level.
  const { data: worksByStudio } = await supabase
    .from("works")
    .select("id, studio, work_kind, poster_count")
    .order("studio", { ascending: true, nullsFirst: false });

  const studioMap = new Map<
    string,
    { studio: string; works: number; posters: number }
  >();
  for (const w of worksByStudio ?? []) {
    const key = w.studio ?? "(未分類)";
    const existing = studioMap.get(key);
    if (existing) {
      existing.works += 1;
      existing.posters += w.poster_count ?? 0;
    } else {
      studioMap.set(key, {
        studio: key,
        works: 1,
        posters: w.poster_count ?? 0,
      });
    }
  }
  const studios = Array.from(studioMap.values());

  return (
    <PageShell title="目錄樹">
      <div className="px-0 md:px-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-6 px-4 md:px-0">
          目錄樹
        </h1>
        <TreeBrowser studios={studios} />
      </div>
    </PageShell>
  );
}
