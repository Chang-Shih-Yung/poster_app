import Link from "next/link";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

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
    <PageShell title="總覽">
      <div className="px-4 pt-4 md:px-0 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-6">
          後台 · 總覽
        </h1>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-6">
          <Card label="作品數" value={worksCount.count ?? 0} />
          <Card label="海報數" value={postersCount.count ?? 0} />
          <Card
            label="待補真圖"
            value={placeholderCount.count ?? 0}
            highlight={Boolean(placeholderCount.count)}
          />
        </div>

        <section className="rounded-lg bg-surface border border-line1">
          <div className="px-4 py-3 border-b border-line1 text-sm font-semibold">
            快速操作
          </div>
          <ul className="divide-y divide-line1">
            <ActionRow href="/tree" label="🌳 瀏覽目錄樹" />
            <ActionRow href="/works/new" label="➕ 新增作品" />
            <ActionRow href="/posters/new" label="➕ 新增海報" />
            <ActionRow href="/upload-queue" label="📤 待補真圖佇列" />
          </ul>
        </section>
      </div>
    </PageShell>
  );
}

function Card({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number | string;
  highlight?: boolean;
}) {
  return (
    <div
      className={`p-4 rounded-lg border ${
        highlight
          ? "bg-amber-900/20 border-amber-700"
          : "bg-surface border-line1"
      }`}
    >
      <div className="text-[11px] uppercase tracking-wider text-textMute mb-1">
        {label}
      </div>
      <div className="text-2xl md:text-3xl font-semibold">{value}</div>
    </div>
  );
}

function ActionRow({ href, label }: { href: string; label: string }) {
  return (
    <li>
      <Link
        href={href}
        className="flex items-center justify-between px-4 py-3.5 min-h-[52px] hover:bg-surfaceRaised hover:no-underline"
      >
        <span className="text-text">{label}</span>
        <svg
          className="text-textFaint"
          width={18}
          height={18}
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
}
