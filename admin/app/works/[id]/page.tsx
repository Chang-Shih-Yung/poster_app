import Link from "next/link";
import PageShell from "@/components/PageShell";
import WorkForm from "../new/WorkForm";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import GroupManager from "./GroupManager";

export const dynamic = "force-dynamic";

export default async function EditWorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: work }, { data: posters }, { data: groups }] = await Promise.all([
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
      .select("id, name, group_type, parent_group_id, display_order")
      .eq("work_id", id)
      .order("display_order")
      .order("name"),
  ]);

  if (!work) notFound();

  return (
    <PageShell title={work.title_zh} showBack>
      <div className="md:px-0 space-y-8">
        <section className="px-4 pt-4 md:px-0 md:pt-0">
          <h1 className="hidden md:block text-2xl font-semibold mb-6">
            編輯作品：{work.title_zh}
          </h1>
          <WorkForm mode="edit" initial={work} />
        </section>

        <section>
          <div className="flex items-center justify-between mb-2 px-4 md:px-0">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-textMute">
              群組（{groups?.length ?? 0}）
            </h2>
          </div>
          <GroupManager workId={id} initialGroups={groups ?? []} />
        </section>

        <section>
          <div className="flex items-center justify-between mb-2 px-4 md:px-0">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-textMute">
              海報（{posters?.length ?? 0}）
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
        </section>
      </div>
    </PageShell>
  );
}
