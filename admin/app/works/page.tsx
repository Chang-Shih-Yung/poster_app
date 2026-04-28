import PageShell from "@/components/PageShell";
import WorksList from "./WorksList";
import { getServerSupabase } from "@/lib/auth-cache";

export const dynamic = "force-dynamic";

const PAGE_SIZE = 50;

export default async function WorksListPage() {
  // First page: 50 rows. Subsequent pages come from the loadWorksPage
  // server action via the "載入更多" button below.
  const supabase = await getServerSupabase();
  const { data: works } = await supabase
    .from("works")
    .select(
      "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count, created_at"
    )
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .limit(PAGE_SIZE);

  const initial = works ?? [];
  const nextCursor =
    initial.length === PAGE_SIZE
      ? (initial[initial.length - 1].created_at as string)
      : null;

  return (
    <PageShell title="所有作品">
      <div className="pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-4 px-4 md:px-0">
          所有作品
        </h1>
        <WorksList initial={initial} initialCursor={nextCursor} />
      </div>
    </PageShell>
  );
}
