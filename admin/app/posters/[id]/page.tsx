import PageShell from "@/components/PageShell";
import PosterForm from "../new/PosterForm";
import PosterImageUploader from "@/components/PosterImageUploader";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function EditPosterPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: poster }, { data: works }] = await Promise.all([
    supabase
      .from("posters")
      .select(
        "id, work_id, poster_name, region, poster_release_type, size_type, channel_category, channel_name, is_exclusive, exclusive_name, material_type, version_label, source_url, source_note, is_placeholder, poster_url, thumbnail_url"
      )
      .eq("id", id)
      .single(),
    supabase.from("works").select("id, title_zh, studio").order("studio").order("title_zh"),
  ]);

  if (!poster) notFound();

  return (
    <PageShell title={poster.poster_name ?? "(未命名)"} showBack>
      <div className="md:px-0 space-y-6">
        <section className="px-4 pt-4 md:px-0 md:pt-0">
          <h1 className="hidden md:block text-2xl font-semibold mb-2">
            編輯海報：{poster.poster_name ?? "(未命名)"}
          </h1>
          <h2 className="text-xs uppercase tracking-wider text-textMute mb-3">
            真實圖片
          </h2>
          <PosterImageUploader
            posterId={poster.id}
            currentImageUrl={poster.thumbnail_url ?? poster.poster_url}
            isPlaceholder={poster.is_placeholder}
          />
        </section>

        <section className="px-4 md:px-0">
          <h2 className="text-xs uppercase tracking-wider text-textMute mb-3">
            Metadata
          </h2>
          <PosterForm mode="edit" works={works ?? []} initial={poster} />
        </section>
      </div>
    </PageShell>
  );
}
