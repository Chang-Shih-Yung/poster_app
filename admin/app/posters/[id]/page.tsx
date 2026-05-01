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
  const [{ data: poster }, { data: works }] = await Promise.all([
    supabase
      .from("posters")
      .select(
        "id, work_id, work_kind, parent_group_id, poster_name, year, poster_release_date, region, poster_release_type, size_type, custom_width, custom_height, size_unit, channel_category, channel_type, channel_name, channel_note, cinema_release_types, premium_format, cinema_name, is_exclusive, exclusive_name, material_type, version_label, source_url, source_platform, source_note, is_placeholder, poster_url, thumbnail_url, promo_image_url, promo_thumbnail_url, status, is_public, created_at, updated_at, uploader_id, updated_by, view_count, favorite_count"
      )
      .eq("id", id)
      .single(),
    supabase.from("works").select("id, title_zh, studio").order("studio").order("title_zh"),
  ]);

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
