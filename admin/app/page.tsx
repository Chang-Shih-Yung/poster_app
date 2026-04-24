import Link from "next/link";
import Nav from "@/components/Nav";
import { createClient } from "@/lib/supabase/server";

export default async function Dashboard() {
  const supabase = await createClient();

  const [worksCount, postersCount, placeholderCount] = await Promise.all([
    supabase.from("works").select("*", { count: "exact", head: true }),
    supabase.from("posters").select("*", { count: "exact", head: true }),
    supabase
      .from("posters")
      .select("*", { count: "exact", head: true })
      .eq("is_placeholder", true),
  ]);

  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-5xl mx-auto">
        <h1 className="text-2xl font-semibold mb-6">後台 · 總覽</h1>

        <div className="grid grid-cols-3 gap-4 mb-10">
          <Card label="作品數" value={worksCount.count ?? "?"} />
          <Card label="海報數" value={postersCount.count ?? "?"} />
          <Card
            label="待補真圖"
            value={placeholderCount.count ?? "?"}
            hint="is_placeholder = true"
          />
        </div>

        <section>
          <h2 className="text-lg font-semibold mb-3">快速操作</h2>
          <ul className="space-y-1 text-sm">
            <li>
              <Link href="/works/new">→ 新增作品</Link>
            </li>
            <li>
              <Link href="/posters/new">→ 新增海報</Link>
            </li>
            <li>
              <Link href="/works">→ 管理所有作品</Link>
            </li>
            <li>
              <Link href="/posters">→ 管理所有海報</Link>
            </li>
          </ul>
        </section>
      </main>
    </>
  );
}

function Card({
  label,
  value,
  hint,
}: {
  label: string;
  value: number | string;
  hint?: string;
}) {
  return (
    <div className="p-5 rounded-lg bg-surface border border-line1">
      <div className="text-xs uppercase tracking-wider text-textMute mb-1">
        {label}
      </div>
      <div className="text-3xl font-semibold">{value}</div>
      {hint && <div className="text-xs text-textFaint mt-2">{hint}</div>}
    </div>
  );
}
