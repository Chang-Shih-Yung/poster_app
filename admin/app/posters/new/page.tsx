import Nav from "@/components/Nav";
import PosterForm from "./PosterForm";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function NewPosterPage({
  searchParams,
}: {
  searchParams: Promise<{ work_id?: string }>;
}) {
  const { work_id } = await searchParams;
  const supabase = await createClient();
  const { data: works } = await supabase
    .from("works")
    .select("id, title_zh, studio")
    .order("studio")
    .order("title_zh");

  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-2xl mx-auto">
        <h1 className="text-2xl font-semibold mb-6">新增海報</h1>
        <PosterForm
          mode="create"
          works={works ?? []}
          defaultWorkId={work_id}
        />
      </main>
    </>
  );
}
