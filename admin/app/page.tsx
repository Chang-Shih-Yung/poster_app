import Link from "next/link";
import { AlertTriangle, FolderTree, ImageOff } from "lucide-react";
import PageShell from "@/components/PageShell";
import { getServerSupabase } from "@/lib/auth-cache";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { UNNAMED_POSTER } from "@/lib/keys";

export const dynamic = "force-dynamic";

export default async function Dashboard() {
  const supabase = await getServerSupabase();

  const [worksRes, postersRes, placeholderRes, recentRes] = await Promise.all([
    supabase.from("works").select("*", { count: "exact", head: true }),
    supabase.from("posters").select("*", { count: "exact", head: true }),
    supabase
      .from("posters")
      .select("*", { count: "exact", head: true })
      .eq("is_placeholder", true),
    supabase
      .from("posters")
      .select("id, poster_name, is_placeholder, thumbnail_url, work_id, works(title_zh)")
      .order("created_at", { ascending: false })
      .limit(5),
  ]);

  const placeholderCount = placeholderRes.count ?? 0;
  type RecentPoster = {
    id: string;
    poster_name: string | null;
    is_placeholder: boolean;
    thumbnail_url: string | null;
    work_id: string;
    works: { title_zh: string } | { title_zh: string }[] | null;
  };
  const recentPosters = (recentRes.data ?? []) as unknown as RecentPoster[];

  return (
    <PageShell title="總覽">
      <div className="px-4 pt-4 pb-8 md:px-0 md:pt-0 space-y-4">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight">
          後台 · 總覽
        </h1>

        {/* Urgent banner — only when there are placeholders */}
        {placeholderCount > 0 && (
          <Link
            href="/upload-queue"
            className="flex items-start gap-3 rounded-lg border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm hover:bg-amber-500/15 transition-colors hover:no-underline"
          >
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0 text-amber-500" />
            <div>
              <p className="font-medium text-amber-600 dark:text-amber-400">
                {placeholderCount} 張海報尚未上傳真實圖片
              </p>
              <p className="text-muted-foreground text-xs mt-0.5">
                點此前往補圖佇列 →
              </p>
            </div>
          </Link>
        )}

        {/* Stat cards */}
        <div className="grid grid-cols-3 gap-3">
          <StatCard label="作品" value={worksRes.count ?? 0} href="/tree" />
          <StatCard label="海報" value={postersRes.count ?? 0} href="/tree" />
          <StatCard
            label="待補圖"
            value={placeholderCount}
            href="/upload-queue"
            highlight={placeholderCount > 0}
          />
        </div>

        {/* Recent posters */}
        {recentPosters.length > 0 && (
          <Card>
            <CardHeader className="py-4 pb-2">
              <CardTitle className="text-sm">最近新增的海報</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <ul className="divide-y divide-border">
                {recentPosters.map((p) => {
                  const work = Array.isArray(p.works) ? p.works[0] : p.works;
                  return (
                  <li key={p.id}>
                    <Link
                      href={`/posters/${p.id}`}
                      className="flex items-center gap-3 px-4 py-3 hover:no-underline group transition-colors"
                    >
                      {/* Thumbnail */}
                      <div className="w-8 h-10 rounded shrink-0 overflow-hidden bg-muted flex items-center justify-center">
                        {p.thumbnail_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={p.thumbnail_url}
                            alt={p.poster_name ?? ""}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <ImageOff className="w-4 h-4 text-muted-foreground" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-foreground truncate group-hover:text-foreground">
                          {p.poster_name ?? UNNAMED_POSTER}
                        </p>
                        <p className="text-xs text-muted-foreground truncate">
                          {work?.title_zh ?? "—"}
                          {p.is_placeholder && (
                            <span className="ml-1.5 text-amber-500">待補圖</span>
                          )}
                        </p>
                      </div>
                    </Link>
                  </li>
                  );
                })}
              </ul>
            </CardContent>
          </Card>
        )}

        {/* Tree shortcut — always visible */}
        <Link
          href="/tree"
          className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors hover:no-underline"
        >
          <FolderTree className="w-4 h-4" />
          瀏覽完整海報目錄
        </Link>
      </div>
    </PageShell>
  );
}

function StatCard({
  label,
  value,
  href,
  highlight,
}: {
  label: string;
  value: number | string;
  href: string;
  highlight?: boolean;
}) {
  return (
    <Link href={href} className="hover:no-underline">
      <Card
        className={cn(
          "transition-colors hover:bg-muted/40",
          highlight &&
            "border-amber-500/40 bg-amber-500/5 dark:border-amber-500/30 dark:bg-amber-500/10 hover:bg-amber-500/15"
        )}
      >
        <CardHeader className="p-4 pb-2">
          <CardDescription className="text-[11px] uppercase tracking-wider">
            {label}
          </CardDescription>
          <CardTitle className="text-2xl md:text-3xl">{value}</CardTitle>
        </CardHeader>
      </Card>
    </Link>
  );
}
