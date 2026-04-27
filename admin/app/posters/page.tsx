import PageShell from "@/components/PageShell";
import PostersList from "./PostersList";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function PostersListPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; placeholder?: string }>;
}) {
  const { q, placeholder } = await searchParams;
  const supabase = await createClient();

  let query = supabase
    .from("posters")
    .select(
      "id, poster_name, region, is_placeholder, thumbnail_url, poster_url, works(title_zh, studio)"
    )
    .order("created_at", { ascending: false })
    .limit(200);

  if (placeholder === "1") {
    query = query.eq("is_placeholder", true);
  }
  if (q) {
    query = query.ilike("poster_name", `%${q}%`);
  }

  const { data: rows } = await query;

  // Supabase types `works` as either an object or array depending on the
  // join cardinality. PostersList expects { ... } | null — normalise.
  const posters = (rows ?? []).map((r) => {
    const work = Array.isArray(r.works) ? r.works[0] : r.works;
    return {
      ...r,
      works: work ?? null,
    };
  });

  return (
    <PageShell title="所有海報">
      <div className="md:px-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-4 px-4 md:px-0">
          所有海報
        </h1>
        <PostersList
          initial={posters}
          query={q ?? ""}
          placeholderOnly={placeholder === "1"}
        />
      </div>
    </PageShell>
  );
}
