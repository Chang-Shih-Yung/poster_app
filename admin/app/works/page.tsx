import Link from "next/link";
import Nav from "@/components/Nav";
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
    <>
      <Nav />
      <main className="px-6 py-8 max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-semibold">作品 Works</h1>
          <Link
            href="/works/new"
            className="px-3 py-1.5 text-sm rounded-md bg-accent text-bg font-medium hover:opacity-90"
          >
            + 新增作品
          </Link>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
            載入失敗：{error.message}
          </div>
        )}

        <div className="rounded-lg bg-surface border border-line1 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr>
                <th>Studio</th>
                <th>中文名</th>
                <th>英文名</th>
                <th>類型</th>
                <th>年份</th>
                <th>海報數</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {works?.map((w) => (
                <tr key={w.id}>
                  <td className="text-textMute">{w.studio ?? "—"}</td>
                  <td>{w.title_zh}</td>
                  <td className="text-textMute">{w.title_en ?? "—"}</td>
                  <td className="text-textMute">{w.work_kind}</td>
                  <td className="text-textMute">{w.movie_release_year ?? "—"}</td>
                  <td>{w.poster_count}</td>
                  <td>
                    <Link href={`/works/${w.id}`}>編輯</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {(!works || works.length === 0) && (
            <div className="px-4 py-8 text-center text-textFaint text-sm">
              目前沒有作品。按右上「新增作品」開始。
            </div>
          )}
        </div>
      </main>
    </>
  );
}
