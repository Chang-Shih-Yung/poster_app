import { notFound } from "next/navigation";
import { getServerSupabase } from "@/lib/auth-cache";
import WorkClient from "./WorkClient";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

/**
 * Work detail page — list of immediate children (top-level groups +
 * direct posters). Group counts come from the SQL function
 * `get_group_recursive_counts` so we don't have to ship every poster
 * row down the wire just to compute badges.
 */
export default async function WorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await getServerSupabase();

  const [
    { data: work },
    { data: rootGroups },
    { data: rootPosters },
    { data: counts },
  ] = await Promise.all([
    supabase
      .from("works")
      .select("id, title_zh, studio, work_kind")
      .eq("id", id)
      .maybeSingle(),
    supabase
      .from("poster_groups")
      .select("id, name, group_type, parent_group_id")
      .eq("work_id", id)
      .is("parent_group_id", null)
      .order("created_at", { ascending: false }),
    supabase
      .from("posters")
      .select("id, poster_name, is_placeholder, thumbnail_url")
      .eq("work_id", id)
      .is("parent_group_id", null)
      .order("created_at", { ascending: false }),
    supabase.rpc("get_group_recursive_counts", { p_work_id: id }),
  ]);

  if (!work) notFound();

  const countByGroup = new Map<string, { total: number; placeholder: number }>();
  for (const row of (counts ?? []) as {
    group_id: string;
    total: number;
    placeholder_total: number;
  }[]) {
    countByGroup.set(row.group_id, {
      total: Number(row.total),
      placeholder: Number(row.placeholder_total),
    });
  }

  const groups = (rootGroups ?? []).map((g) => ({
    id: g.id as string,
    name: g.name as string,
    group_type: (g.group_type as string | null) ?? null,
    child_count: countByGroup.get(g.id as string)?.total ?? 0,
    placeholder_count: countByGroup.get(g.id as string)?.placeholder ?? 0,
  }));

  const posters = (rootPosters ?? []).map((p) => ({
    id: p.id as string,
    poster_name: (p.poster_name as string | null) ?? null,
    is_placeholder: !!p.is_placeholder,
    thumbnail_url: (p.thumbnail_url as string | null) ?? null,
  }));

  return (
    <WorkClient
      nav={<Nav />}
      work={{
        id: work.id as string,
        title_zh: work.title_zh as string,
        studio: (work.studio as string | null) ?? null,
        work_kind: work.work_kind as string,
      }}
      groups={groups}
      posters={posters}
    />
  );
}
