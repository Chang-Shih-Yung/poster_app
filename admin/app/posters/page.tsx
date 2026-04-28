import PageShell from "@/components/PageShell";
import PostersList from "./PostersList";
import { getServerSupabase } from "@/lib/auth-cache";

export const dynamic = "force-dynamic";

export default async function PostersListPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; placeholder?: string }>;
}) {
  const { q, placeholder } = await searchParams;
  const supabase = await getServerSupabase();

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
    // Escape LIKE/ILIKE wildcards so user input can't craft
    // expensive patterns or match everything with a bare "%".
    const escaped = q.replaceAll(/[%_\\]/g, String.raw`\$&`);
    query = query.ilike("poster_name", `%${escaped}%`);
  }

  const { data: rows } = await query;

  const posters = (rows ?? []).map((r) => {
    const work = Array.isArray(r.works) ? r.works[0] : r.works;
    return {
      ...r,
      works: work ?? null,
    };
  });

  return (
    <PageShell title="所有海報">
      <div className="pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-4 px-4 md:px-0">
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
