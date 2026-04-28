import PageShell from "@/components/PageShell";
import WorksList from "./WorksList";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function WorksListPage() {
  const supabase = await createClient();
  const { data: works } = await supabase
    .from("works")
    .select(
      "id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count"
    )
    .order("created_at", { ascending: false });

  return (
    <PageShell title="所有作品">
      <div className="pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-4 px-4 md:px-0">
          所有作品
        </h1>
        <WorksList initial={works ?? []} />
      </div>
    </PageShell>
  );
}
