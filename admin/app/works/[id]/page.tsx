import Link from "next/link";
import { FolderTree, AlertTriangle } from "lucide-react";
import PageShell from "@/components/PageShell";
import WorkForm from "../new/WorkForm";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

/**
 * Work detail page = work-level metadata + flat list of every poster
 * in this work. Group hierarchy management lives ONLY in /tree so
 * there's exactly one canonical editing surface for the tree shape.
 * Otherwise the same data shown two ways invites "why doesn't this
 * match?" confusion (raised by Henry 2026-04-27).
 */
export default async function EditWorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: work }, { data: posters }, { count: groupsCount }] = await Promise.all([
    supabase
      .from("works")
      .select("id, studio, title_zh, title_en, work_kind, movie_release_year")
      .eq("id", id)
      .single(),
    supabase
      .from("posters")
      .select("id, poster_name, region, is_placeholder, parent_group_id, created_at")
      .eq("work_id", id)
      .order("created_at", { ascending: false }),
    supabase
      .from("poster_groups")
      .select("*", { count: "exact", head: true })
      .eq("work_id", id),
  ]);

  if (!work) notFound();

  return (
    <PageShell title={work.title_zh} showBack>
      <div className="md:px-0 space-y-6">
        <section className="px-4 pt-4 md:px-0 md:pt-0">
          <h1 className="hidden md:block text-2xl font-semibold mb-6">
            編輯作品：{work.title_zh}
          </h1>
          <WorkForm mode="edit" initial={work} />
        </section>

        {/* Tree CTA — single canonical place to edit hierarchy. */}
        <Link
          href="/tree"
          className="mx-4 md:mx-0 flex items-center gap-3 px-4 py-3 rounded-lg bg-surface border border-line1 hover:bg-surfaceRaised hover:no-underline"
        >
          <FolderTree className="w-5 h-5 shrink-0 text-accent" />
          <div className="flex-1 min-w-0">
            <div className="text-sm text-text">
              在目錄樹編輯群組與層級
            </div>
            <div className="text-xs text-textFaint mt-0.5">
              {groupsCount ?? 0} 個群組 · 用拖拉以外的 inline + ✏ 🗑 操作
            </div>
          </div>
          <span className="text-accent shrink-0">→</span>
        </Link>

        <section>
          <div className="flex items-center justify-between mb-2 px-4 md:px-0">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-textMute">
              海報（{posters?.length ?? 0}）— 平鋪
            </h2>
            <Link
              href={`/posters/new?work_id=${id}`}
              className="text-xs text-accent px-2 py-1"
            >
              + 新增
            </Link>
          </div>
          <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
            {posters?.map((p) => (
              <li key={p.id}>
                <Link
                  href={`/posters/${p.id}`}
                  className="flex items-center justify-between px-4 py-3 min-h-[52px] hover:bg-surfaceRaised hover:no-underline"
                >
                  <div className="min-w-0 flex-1">
                    <div className="text-sm truncate">
                      {p.poster_name ?? "(未命名)"}
                    </div>
                    <div className="text-xs text-textFaint truncate mt-0.5">
                      {p.region ?? "—"}
                      {p.is_placeholder && " · 待補真圖"}
                      {!p.parent_group_id && " · 未掛群組"}
                    </div>
                  </div>
                  {p.is_placeholder && (
                    <span className="text-xs text-amber-400 mr-2">占位</span>
                  )}
                </Link>
              </li>
            ))}
            {(!posters || posters.length === 0) && (
              <li className="px-4 py-6 text-center text-textFaint text-sm">
                還沒有海報
              </li>
            )}
          </ul>
          <p className="px-4 md:px-0 text-[11px] text-textFaint mt-2 flex items-start gap-1.5">
            <AlertTriangle className="w-3 h-3 shrink-0 mt-0.5" />
            <span>
              這裡是平鋪所有海報，不分群組。要看「哪張屬於哪一層」請開目錄樹。
            </span>
          </p>
        </section>
      </div>
    </PageShell>
  );
}
