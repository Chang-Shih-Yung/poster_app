import { createClient } from "@/lib/supabase/server";
import StudiosClient from "./StudiosClient";
import { NULL_STUDIO_KEY } from "@/lib/keys";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

export default async function TreePage() {
  const supabase = await createClient();

  const { data: worksByStudio } = await supabase
    .from("works")
    .select("id, studio, work_kind, poster_count")
    .order("studio", { ascending: true, nullsFirst: false });

  // Aggregate to one row per studio (NULL → "(未分類)" sentinel) so the
  // root list mirrors the data we display: name + work count + total
  // posters.
  const map = new Map<string, { studio: string; works: number; posters: number }>();
  for (const w of worksByStudio ?? []) {
    const key = w.studio ?? NULL_STUDIO_KEY;
    const existing = map.get(key);
    if (existing) {
      existing.works += 1;
      existing.posters += w.poster_count ?? 0;
    } else {
      map.set(key, { studio: key, works: 1, posters: w.poster_count ?? 0 });
    }
  }

  return (
    <StudiosClient nav={<Nav />} studios={Array.from(map.values())} />
  );
}
