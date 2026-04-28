import PageShell from "@/components/PageShell";
import WorkForm from "./WorkForm";
import { getServerSupabase } from "@/lib/auth-cache";

export const dynamic = "force-dynamic";

export default async function NewWorkPage() {
  const supabase = await getServerSupabase();
  const { data: studioRows } = await supabase
    .from("works")
    .select("studio")
    .not("studio", "is", null)
    .order("studio", { ascending: true });

  const studios = [
    ...new Set(
      (studioRows ?? []).map((r) => r.studio as string).filter(Boolean)
    ),
  ];

  return (
    <PageShell title="新增作品" back>
      <div className="px-4 py-4 md:px-0 md:py-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-6">
          新增作品
        </h1>
        <WorkForm mode="create" studios={studios} />
      </div>
    </PageShell>
  );
}
