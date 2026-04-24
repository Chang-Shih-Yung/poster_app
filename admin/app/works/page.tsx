import Link from "next/link";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function WorksListPage() {
  const supabase = await createClient();
  const { data: works, error } = await supabase
    .from("works")
    .select("id, studio, title_zh, title_en, work_kind, movie_release_year, poster_count")
    .order("studio", { ascending: true, nullsFirst: false })
    .order("title_zh", { ascending: true });

  return (
    <PageShell
      title="作品"
      mobileAction={
        <Link
          href="/works/new"
          className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium"
        >
          + 新增
        </Link>
      }
    >
      <div className="md:px-0">
        <div className="hidden md:flex items-center justify-between mb-6 px-4 md:px-0">
          <h1 className="text-2xl font-semibold">作品 Works</h1>
          <Link
            href="/works/new"
            className="px-3 py-1.5 text-sm rounded-md bg-accent text-bg font-medium hover:opacity-90"
          >
            + 新增作品
          </Link>
        </div>

        {error && (
          <div className="mx-4 md:mx-0 mb-3 p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
            載入失敗：{error.message}
          </div>
        )}

        <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
          {works?.map((w) => (
            <li key={w.id}>
              <Link
                href={`/works/${w.id}`}
                className="flex items-center justify-between px-4 py-3.5 min-h-[60px] hover:bg-surfaceRaised hover:no-underline active:bg-surfaceRaised"
              >
                <div className="min-w-0 flex-1">
                  <div className="text-sm text-text truncate">
                    {w.title_zh}
                  </div>
                  <div className="text-xs text-textFaint truncate mt-0.5">
                    {w.studio ? `${w.studio} · ` : ""}
                    {w.work_kind}
                    {w.movie_release_year ? ` · ${w.movie_release_year}` : ""}
                  </div>
                </div>
                <div className="text-xs text-textMute mr-2 shrink-0">
                  {w.poster_count} 張
                </div>
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
          ))}
          {(!works || works.length === 0) && (
            <li className="px-4 py-10 text-center text-textFaint text-sm">
              還沒有作品。
              <br />
              <Link href="/works/new" className="text-accent">
                去新增第一筆
              </Link>
            </li>
          )}
        </ul>
      </div>
    </PageShell>
  );
}
