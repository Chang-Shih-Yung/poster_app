import PageShell from "@/components/PageShell";
import PosterForm from "./PosterForm";
import { getServerSupabase } from "@/lib/auth-cache";

export const dynamic = "force-dynamic";

export default async function NewPosterPage({
  searchParams,
}: {
  searchParams: Promise<{ work_id?: string }>;
}) {
  const { work_id } = await searchParams;
  const supabase = await getServerSupabase();
  const { data: works } = await supabase
    .from("works")
    .select("id, title_zh, studio")
    .order("studio")
    .order("title_zh");

  return (
    <PageShell title="新增海報" back>
      <div className="px-4 py-4 md:px-0 md:py-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-2">
          新增海報
        </h1>
        <p className="text-sm text-muted-foreground mb-4">
          只填 metadata；圖片在建立後到編輯頁上傳。
        </p>
        <PosterForm mode="create" works={works ?? []} defaultWorkId={work_id} />
      </div>
    </PageShell>
  );
}
