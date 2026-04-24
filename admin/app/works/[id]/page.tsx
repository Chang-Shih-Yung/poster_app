import Nav from "@/components/Nav";
import WorkForm from "../new/WorkForm";
import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function EditWorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: work } = await supabase
    .from("works")
    .select("id, studio, title_zh, title_en, work_kind, movie_release_year")
    .eq("id", id)
    .single();

  if (!work) notFound();

  const { data: posters } = await supabase
    .from("posters")
    .select("id, poster_name, region, is_placeholder, created_at")
    .eq("work_id", id)
    .order("created_at", { ascending: false });

  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-3xl mx-auto space-y-10">
        <section>
          <h1 className="text-2xl font-semibold mb-6">
            編輯作品：{work.title_zh}
          </h1>
          <WorkForm mode="edit" initial={work} />
        </section>

        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold">本作品的海報（{posters?.length ?? 0}）</h2>
            <Link
              href={`/posters/new?work_id=${id}`}
              className="text-sm px-3 py-1.5 rounded-md bg-accent text-bg font-medium"
            >
              + 新增海報
            </Link>
          </div>
          <div className="rounded-lg bg-surface border border-line1 overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr>
                  <th>名稱</th>
                  <th>地區</th>
                  <th>占位?</th>
                  <th>建立時間</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {posters?.map((p) => (
                  <tr key={p.id}>
                    <td>{p.poster_name ?? "—"}</td>
                    <td className="text-textMute">{p.region ?? "—"}</td>
                    <td>{p.is_placeholder ? "✓" : ""}</td>
                    <td className="text-textFaint text-xs">
                      {new Date(p.created_at).toLocaleDateString()}
                    </td>
                    <td>
                      <Link href={`/posters/${p.id}`}>編輯</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {(!posters || posters.length === 0) && (
              <div className="px-4 py-6 text-center text-textFaint text-sm">
                還沒有海報。按「+ 新增海報」開始。
              </div>
            )}
          </div>
        </section>
      </main>
    </>
  );
}
