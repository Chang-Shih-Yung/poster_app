import PageShell from "@/components/PageShell";
import { getServerSupabase } from "@/lib/auth-cache";
import SetsClient from "./SetsClient";

export const dynamic = "force-dynamic";

/**
 * Poster sets management page. Lists every poster_set with its member
 * count, plus inline rename/delete actions. Sets themselves are managed
 * here; assigning posters into sets happens in the poster form via
 * SetPicker.
 */
export default async function SetsPage() {
  const supabase = await getServerSupabase();

  // One round-trip per concern. set_counts is a thin aggregation —
  // small enough that we just count rows in JS once we have them.
  const [{ data: sets }, { data: counts }] = await Promise.all([
    supabase
      .from("poster_sets")
      .select("id, name, description, created_at, updated_at")
      .order("created_at", { ascending: false }),
    supabase
      .from("posters")
      .select("set_id")
      .not("set_id", "is", null)
      .is("deleted_at", null),
  ]);

  const countBySet = new Map<string, number>();
  for (const row of counts ?? []) {
    const id = row.set_id as string | null;
    if (!id) continue;
    countBySet.set(id, (countBySet.get(id) ?? 0) + 1);
  }

  const rows = (sets ?? []).map((s) => ({
    id: s.id as string,
    name: s.name as string,
    description: (s.description as string | null) ?? null,
    created_at: s.created_at as string,
    updated_at: s.updated_at as string,
    poster_count: countBySet.get(s.id as string) ?? 0,
  }));

  return (
    <PageShell title="海報組合（套票）" back>
      <div className="px-4 md:px-0 pt-4 md:pt-0 space-y-4">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight">
          海報組合（套票）
        </h1>
        <p className="text-sm text-muted-foreground">
          一個套票 = N 張一起發行的海報（影城套票、IG 活動組合等）。在這裡管
          理套票本身；每張海報屬於哪個套票在海報的「海報發行組合」欄位設定。
        </p>
        <SetsClient initial={rows} />
      </div>
    </PageShell>
  );
}
