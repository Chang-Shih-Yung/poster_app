import Link from "next/link";
import { ChevronRight } from "lucide-react";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export const dynamic = "force-dynamic";

/**
 * "Needs real image" queue. Lists every poster where is_placeholder=true.
 * One-tap to jump into upload. Batch-upload wizard is deferred to
 * Phase 2.2.
 */
export default async function UploadQueuePage() {
  const supabase = await createClient();
  const { data: posters } = await supabase
    .from("posters")
    .select(
      "id, poster_name, region, created_at, works(title_zh, studio)"
    )
    .eq("is_placeholder", true)
    .order("created_at", { ascending: false })
    .limit(100);

  return (
    <PageShell title="待補真圖">
      <div className="px-4 md:px-0 pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-2">
          待補真圖（{posters?.length ?? 0} 張）
        </h1>

        <p className="text-sm text-muted-foreground mb-4">
          以下是所有尚未上傳真實圖片的海報。點開任一張 → 在編輯頁上傳圖
          → 自動完成壓縮 + thumb + BlurHash，狀態變成「已補圖」。
        </p>

        <Card>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
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
                          {p.poster_name ?? "(未命名)"}
                        </div>
                        <div className="text-xs text-muted-foreground truncate mt-0.5">
                          {work?.studio ? `${work.studio} · ` : ""}
                          {work?.title_zh ?? "?"} · {p.region ?? "—"}
                        </div>
                      </div>
                      <Badge
                        variant="outline"
                        className="mr-2 text-amber-500 border-amber-500/40 dark:text-amber-400"
                      >
                        待補
                      </Badge>
                      <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0 group-hover:text-foreground transition-colors" />
                    </Link>
                  </li>
                );
              })}
              {(!posters || posters.length === 0) && (
                <li className="px-4 py-10 text-center text-muted-foreground text-sm">
                  所有海報都已上傳真實圖片
                </li>
              )}
            </ul>
          </CardContent>
        </Card>
      </div>
    </PageShell>
  );
}
