import Link from "next/link";
import { ChevronRight } from "lucide-react";
import PageShell from "@/components/PageShell";
import { getServerSupabase } from "@/lib/auth-cache";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { UNNAMED_POSTER } from "@/lib/keys";

export const dynamic = "force-dynamic";

/**
 * "Needs real image" queue. Lists every poster where is_placeholder=true.
 * One-tap to jump into upload. Batch-upload wizard is deferred to
 * Phase 2.2.
 */
export default async function UploadQueuePage() {
  const supabase = await getServerSupabase();
  const PAGE_LIMIT = 100;
  const [{ data: posters }, { count: totalPosters }, { count: remainingCount }] =
    await Promise.all([
      supabase
        .from("posters")
        .select("id, poster_name, region, created_at, works(title_zh, studio)")
        .eq("is_placeholder", true)
        .order("created_at", { ascending: false })
        .limit(PAGE_LIMIT),
      supabase
        .from("posters")
        .select("*", { count: "exact", head: true })
        .is("deleted_at", null),
      supabase
        .from("posters")
        .select("*", { count: "exact", head: true })
        .eq("is_placeholder", true),
    ]);

  const total = totalPosters ?? 0;
  const remaining = remainingCount ?? 0;
  const done = total - remaining;
  const pct = total > 0 ? Math.round((done / total) * 100) : 100;
  const shown = posters?.length ?? 0;
  const hasMore = remaining > shown;

  return (
    <PageShell title={`待補真圖（${remaining}）`}>
      <div className="px-4 md:px-0 pt-4 md:pt-0 space-y-4">
        <div>
          <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-1">
            待補真圖
          </h1>
          <p className="text-sm text-muted-foreground">
            點開任一張 → 在編輯頁上傳圖，自動壓縮 + thumb + BlurHash。
          </p>
        </div>

        {/* Progress counter */}
        {total > 0 && (
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs text-muted-foreground">
              <span>進度</span>
              <span>
                <span className="font-medium text-foreground">{done}</span> / {total} 張已補圖
                （{pct}%）
              </span>
            </div>
            <div className="h-2 rounded-full bg-secondary overflow-hidden">
              <div
                className="h-full rounded-full bg-primary transition-all"
                style={{ width: `${pct}%` }}
              />
            </div>
          </div>
        )}

        <Card>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              {hasMore && (
                <li className="px-4 py-2 text-xs text-muted-foreground bg-muted/30">
                  顯示前 {shown} 張，共 {remaining} 張待補
                </li>
              )}
              {posters?.map((p) => {
                const work = Array.isArray(p.works) ? p.works[0] : p.works;
                return (
                  <li key={p.id}>
                    <Link
                      href={`/posters/${p.id}`}
                      className="flex items-center px-4 py-3.5 min-h-[64px] hover:no-underline group transition-colors"
                    >
                      <div className="min-w-0 flex-1">
                        <div className="text-sm text-foreground truncate">
                          {p.poster_name ?? UNNAMED_POSTER}
                        </div>
                        <div className="text-xs text-muted-foreground truncate mt-0.5">
                          {work?.studio ? `${work.studio} · ` : ""}
                          {work?.title_zh ?? "?"} · {p.region ?? "—"}
                        </div>
                      </div>
                      <Badge variant="placeholder" className="mr-2">
                        待補
                      </Badge>
                      <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0 group-hover:text-foreground transition-colors" />
                    </Link>
                  </li>
                );
              })}
              {(!posters || posters.length === 0) && (
                <li className="px-4 py-10 text-center text-sm">
                  <span className="text-muted-foreground">所有海報都已上傳真實圖片 🎉</span>
                </li>
              )}
            </ul>
          </CardContent>
        </Card>
      </div>
    </PageShell>
  );
}
