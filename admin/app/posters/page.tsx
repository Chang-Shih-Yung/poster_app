import Link from "next/link";
import PageShell from "@/components/PageShell";
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
      "id, poster_name, region, is_placeholder, thumbnail_url, created_at, works(title_zh, studio)"
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
    <PageShell
      title="海報"
      mobileAction={
        <Link
          href="/posters/new"
          className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium"
        >
          + 新增
        </Link>
      }
    >
      <div className="md:px-0">
        <div className="hidden md:flex items-center justify-between mb-6">
          <h1 className="text-2xl font-semibold">海報 Posters</h1>
          <Link
            href="/posters/new"
            className="px-3 py-1.5 text-sm rounded-md bg-accent text-bg font-medium"
          >
            + 新增海報
          </Link>
        </div>

        <form className="px-4 md:px-0 mb-3 flex items-center gap-2 text-sm">
          <input
            name="q"
            placeholder="按名稱搜尋…"
            defaultValue={q ?? ""}
            className="flex-1"
          />
          <button
            type="submit"
            className="px-3 py-1.5 border border-line2 rounded-md text-textMute"
          >
            搜尋
          </button>
        </form>

        <label className="flex items-center gap-2 text-xs text-textMute px-4 md:px-0 mb-3">
          <input
            type="checkbox"
            name="placeholder"
            value="1"
            defaultChecked={placeholder === "1"}
            className="form-checkbox"
            disabled
          />
          只看待補真圖（在 URL 加 ?placeholder=1）
        </label>

        {error && (
          <div className="mx-4 md:mx-0 mb-3 p-3 rounded-md bg-red-900/40 border border-red-700 text-sm">
            載入失敗：{error.message}
          </div>
        )}

        <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
          {posters?.map((p) => {
            const work = Array.isArray(p.works) ? p.works[0] : p.works;
            return (
              <li key={p.id}>
                <Link
                  href={`/posters/${p.id}`}
                  className="flex items-center justify-between px-4 py-3 min-h-[64px] hover:bg-surfaceRaised hover:no-underline"
                >
                  {p.thumbnail_url ? (
                    <img
                      src={p.thumbnail_url}
                      alt=""
                      className="w-10 h-12 rounded object-cover border border-line1 mr-3 shrink-0"
                    />
                  ) : (
                    <div className="w-10 h-12 rounded bg-surfaceRaised border border-line1 mr-3 shrink-0" />
                  )}
                  <div className="min-w-0 flex-1">
                    <div className="text-sm truncate">
                      {p.poster_name ?? "(未命名)"}
                    </div>
                    <div className="text-xs text-textFaint truncate mt-0.5">
                      {work?.studio ? `${work.studio} · ` : ""}
                      {work?.title_zh ?? "?"} · {p.region ?? "—"}
                    </div>
                  </div>
                  {p.is_placeholder && (
                    <span className="text-xs text-amber-400 mr-2 shrink-0">
                      占位
                    </span>
                  )}
                </Link>
              </li>
            );
          })}
          {(!posters || posters.length === 0) && (
            <li className="px-4 py-10 text-center text-textFaint text-sm">
              沒有符合條件的海報
            </li>
          )}
        </ul>
      </div>
    </PageShell>
  );
}
