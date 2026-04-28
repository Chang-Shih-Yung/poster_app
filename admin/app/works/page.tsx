import PageShell from "@/components/PageShell";
import WorksList from "./WorksList";
import { getServerSupabase } from "@/lib/auth-cache";

export const dynamic = "force-dynamic";

const PAGE_SIZE = 50;

export default async function WorksListPage() {
  const supabase = await getServerSupabase();

  const [{ data: works }, { data: studioRows }] = await Promise.all([
    supabase
      .from("works")
      .select(
        "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count, created_at"
      )
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(PAGE_SIZE),
    supabase
      .from("works")
      .select("studio")
      .not("studio", "is", null)
      .order("studio", { ascending: true }),
  ]);

  const initial = works ?? [];
  const nextCursor =
    initial.length === PAGE_SIZE
      ? (initial[initial.length - 1].created_at as string)
      : null;

  // Deduplicate studios (PostgREST doesn't have DISTINCT in select).
  const studios = [
    ...new Set(
      (studioRows ?? [])
        .map((r) => r.studio as string)
        .filter(Boolean)
    ),
  ];

  return (
    <PageShell title="所有作品">
      <div className="pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-4 px-4 md:px-0">
          所有作品
        </h1>
        <WorksList initial={initial} initialCursor={nextCursor} studios={studios} />
      </div>
    </PageShell>
  );
}
