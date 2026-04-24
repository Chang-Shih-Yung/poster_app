import Link from "next/link";
import Nav from "@/components/Nav";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function PostersListPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; placeholder?: string }>;
}) {
  const { q, placeholder } = await searchParams;
  const supabase = await createClient();

  let query = supabase
    .from("posters")
    .select(
      "id, poster_name, region, is_placeholder, created_at, works(title_zh, studio)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  if (placeholder === "1") {
    query = query.eq("is_placeholder", true);
  }
  if (q) {
    query = query.ilike("poster_name", `%${q}%`);
  }

  const { data: posters, error } = await query;

  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-semibold">海報 Posters</h1>
          <Link
            href="/posters/new"
            className="px-3 py-1.5 text-sm rounded-md bg-accent text-bg font-medium"
          >
            + 新增海報
          </Link>
        </div>

        <form className="mb-4 flex items-center gap-3 text-sm">
          <input
            name="q"
            placeholder="按名稱搜尋…"
            defaultValue={q ?? ""}
            className="w-64"
          />
          <label className="flex items-center gap-2 text-textMute">
            <input
              type="checkbox"
              name="placeholder"
              value="1"
              defaultChecked={placeholder === "1"}
            />
            只看待補真圖
          </label>
          <button
            type="submit"
            className="px-3 py-1.5 border border-line2 rounded-md text-textMute"
          >
            搜尋
          </button>
        </form>

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
                <th>作品</th>
                <th>海報名</th>
                <th>地區</th>
                <th>狀態</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {posters?.map((p) => {
                const work = Array.isArray(p.works) ? p.works[0] : p.works;
                return (
                  <tr key={p.id}>
                    <td className="text-textMute">{work?.studio ?? "—"}</td>
                    <td>{work?.title_zh ?? "—"}</td>
                    <td>{p.poster_name ?? "—"}</td>
                    <td className="text-textMute">{p.region ?? "—"}</td>
                    <td>
                      {p.is_placeholder ? (
                        <span className="text-amber-400">待補真圖</span>
                      ) : (
                        <span className="text-green-400">✓</span>
                      )}
                    </td>
                    <td>
                      <Link href={`/posters/${p.id}`}>編輯</Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {(!posters || posters.length === 0) && (
            <div className="px-4 py-8 text-center text-textFaint text-sm">
              沒有符合條件的海報。
            </div>
          )}
        </div>
      </main>
    </>
  );
}
