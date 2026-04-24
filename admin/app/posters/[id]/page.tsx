import Nav from "@/components/Nav";
import PosterForm from "../new/PosterForm";
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
        "id, work_id, poster_name, region, poster_release_type, size_type, channel_category, channel_name, is_exclusive, exclusive_name, material_type, version_label, source_url, source_note, is_placeholder"
      )
      .eq("id", id)
      .single(),
    supabase.from("works").select("id, title_zh, studio").order("studio").order("title_zh"),
  ]);

  if (!poster) notFound();

  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-2xl mx-auto">
        <h1 className="text-2xl font-semibold mb-6">
          編輯海報：{poster.poster_name ?? "(未命名)"}
        </h1>
        <PosterForm mode="edit" works={works ?? []} initial={poster} />
      </main>
    </>
  );
}
