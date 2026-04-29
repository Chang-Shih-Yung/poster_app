import PageShell from "@/components/PageShell";
import BatchImport from "./BatchImport";
import { getServerSupabase } from "@/lib/auth-cache";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function BatchImportPage() {
  const supabase = await getServerSupabase();
  const { data: works } = await supabase
    .from("works")
    .select("id, title_zh, studio")
    .order("studio")
    .order("title_zh");

  return (
    <PageShell title="批量新增海報" back>
      <div className="px-4 py-4 md:px-0 md:py-0">
        <div className="hidden md:flex items-baseline justify-between mb-4">
          <h1 className="text-2xl font-semibold tracking-tight">批量新增海報</h1>
          <Link
            href="/posters/new"
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            改為新增單張 →
          </Link>
        </div>
        <BatchImport works={works ?? []} />
      </div>
    </PageShell>
  );
}
