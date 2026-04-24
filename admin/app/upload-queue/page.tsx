import Link from "next/link";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

/**
 * "Needs real image" queue. Lists every poster where is_placeholder=true.
 * Mobile-optimised: big tappable cards, one-tap to jump into upload.
 * Batch-upload wizard is deferred to Phase 2.2.
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
      <div className="md:px-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-6 px-4 md:px-0">
          待補真圖（{posters?.length ?? 0} 張）
        </h1>

        <div className="px-4 py-3 md:px-0 text-sm text-textMute">
          以下是所有尚未上傳真實圖片的海報。點開任一張 → 在編輯頁上傳圖
          → 自動完成壓縮 + thumb + BlurHash，狀態變成「已補圖」。
        </div>

        <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
          {posters?.map((p) => {
            const work = Array.isArray(p.works) ? p.works[0] : p.works;
            return (
              <li key={p.id}>
                <Link
                  href={`/posters/${p.id}`}
                  className="flex items-center justify-between px-4 py-3.5 min-h-[64px] hover:bg-surfaceRaised hover:no-underline active:bg-surfaceRaised"
                >
                  <div className="min-w-0 flex-1">
                    <div className="text-sm text-text truncate">
                      {p.poster_name ?? "(未命名)"}
                    </div>
                    <div className="text-xs text-textFaint truncate mt-0.5">
                      {work?.studio ? `${work.studio} · ` : ""}
                      {work?.title_zh ?? "?"} · {p.region ?? "—"}
                    </div>
                  </div>
                  <span className="text-xs text-amber-400 mr-2">待補</span>
                  <svg
                    className="text-textFaint shrink-0"
                    width={16}
                    height={16}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <polyline points="9 18 15 12 9 6" />
                  </svg>
                </Link>
              </li>
            );
          })}
          {(!posters || posters.length === 0) && (
            <li className="px-4 py-10 text-center text-textFaint text-sm">
              🎉 沒有待補圖的海報。
            </li>
          )}
        </ul>
      </div>
    </PageShell>
  );
}
