import PageShell from "@/components/PageShell";
import PosterForm from "../new/PosterForm";
import PosterImageUploader from "@/components/PosterImageUploader";
import PosterStatsCard from "./PosterStatsCard";
import { getServerSupabase } from "@/lib/auth-cache";
import { notFound } from "next/navigation";
import { UNNAMED_POSTER } from "@/lib/keys";

export const dynamic = "force-dynamic";

export default async function EditPosterPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await getServerSupabase();
  // System columns (created_at / updated_at / uploader_id / updated_by /
  // view_count / favorite_count / status / is_public) are read here and
  // displayed in the read-only stats card below the metadata form.
  // SELECT * — historically we listed every column explicitly, but
  // after several ALTER TABLE waves the PostgREST schema cache is the
  // weakest link: any single typo or stale entry causes the entire
  // request to fail with PGRST204. `*` sidesteps that — it returns
  // whatever the DB actually has, no name validation. Pulls maybe a
  // few extra unused bytes (tags, blurhash, etc.) which is fine.
  const [posterRes, worksRes] = await Promise.all([
    supabase.from("posters").select("*").eq("id", id).single(),
    supabase.from("works").select("id, title_zh, title_en, studio").order("studio").order("title_zh"),
  ]);
  // Surface query errors instead of silently 404-ing — schema-cache miss
  // (PGRST204) and other Supabase errors used to look like "row not found"
  // even when the row was clearly there. Now we log the full error
  // (visible in Vercel runtime logs) and throw with a one-line message
  // that fits the truncated log column.
  if (posterRes.error) {
    const e = posterRes.error;
    console.error("[posters/[id]] supabase select error", {
      poster_id: id,
      code: e.code,
      message: e.message,
      details: e.details,
      hint: e.hint,
    });
    throw new Error(
      `Load poster ${id}: ${e.code ?? "?"} ${e.message ?? ""} ${e.hint ?? ""}`.trim()
    );
  }
  const poster = posterRes.data;
  const works = worksRes.data;
  if (!poster) notFound();

  // Resolve uploader / updater display names in one query — DB doesn't
  // join through PostgREST when the FK target is `users` (no posters→users
  // relationship exposed), so do it manually.
  const userIds = [poster.uploader_id, poster.updated_by].filter(
    (v): v is string => !!v
  );
  const userNames = new Map<string, string>();
  if (userIds.length > 0) {
    const { data: users } = await supabase
      .from("users")
      .select("id, display_name")
      .in("id", userIds);
    for (const u of users ?? []) {
      userNames.set(u.id as string, (u.display_name as string | null) ?? "—");
    }
  }

  return (
    <PageShell title={poster.poster_name ?? UNNAMED_POSTER} back>
      <div className="px-4 md:px-0 pt-4 md:pt-0 space-y-6">
        <section>
          <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-4">
            編輯海報：{poster.poster_name ?? UNNAMED_POSTER}
          </h1>
          <h2 className="text-xs uppercase tracking-wider text-muted-foreground mb-3">
            真實圖片
          </h2>
          <PosterImageUploader
            posterId={poster.id}
            currentImageUrl={poster.thumbnail_url ?? poster.poster_url}
            isPlaceholder={poster.is_placeholder}
          />
        </section>

        <section>
          <h2 className="text-xs uppercase tracking-wider text-muted-foreground mb-3">
            Metadata
          </h2>
          {/* Promo image is now an inline field inside PosterForm — no
              separate section needed. */}
          <PosterForm mode="edit" works={works ?? []} initial={poster} />
        </section>

        <section>
          <h2 className="text-xs uppercase tracking-wider text-muted-foreground mb-3">
            統計資訊
          </h2>
          <PosterStatsCard
            status={poster.status as string}
            isPublic={poster.is_public as boolean | null}
            createdAt={poster.created_at as string}
            updatedAt={poster.updated_at as string | null}
            uploaderName={userNames.get(poster.uploader_id as string) ?? null}
            updaterName={
              poster.updated_by
                ? userNames.get(poster.updated_by as string) ?? null
                : null
            }
            viewCount={Number(poster.view_count ?? 0)}
            favoriteCount={Number(poster.favorite_count ?? 0)}
          />
        </section>
      </div>
    </PageShell>
  );
}
