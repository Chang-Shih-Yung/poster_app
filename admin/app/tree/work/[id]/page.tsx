import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import WorkClient from "./WorkClient";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

/**
 * Work detail page — list of immediate children (top-level groups +
 * direct posters). Pre-computes recursive poster counts for groups so
 * the row can show an accurate "(N)" while collapsed.
 */
export default async function WorkPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: work }, { data: rootGroups }, { data: rootPosters }, { data: allGroups }, { data: allPosters }] =
    await Promise.all([
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
      supabase
        .from("poster_groups")
        .select("id, parent_group_id")
        .eq("work_id", id),
      supabase
        .from("posters")
        .select("parent_group_id")
        .eq("work_id", id)
        .is("deleted_at", null),
    ]);

  if (!work) notFound();

  // Recursive poster count per group — same algorithm as the old
  // TreeBrowser.decorateGroupCounts, just on the server.
  const subOf = new Map<string, string[]>();
  for (const g of allGroups ?? []) {
    const parent = (g.parent_group_id as string | null) ?? "__root__";
    if (!subOf.has(parent)) subOf.set(parent, []);
    subOf.get(parent)!.push(g.id as string);
  }
  const directPosterCount = new Map<string, number>();
  for (const p of allPosters ?? []) {
    const k = p.parent_group_id as string | null;
    if (!k) continue;
    directPosterCount.set(k, (directPosterCount.get(k) ?? 0) + 1);
  }
  function recurse(groupId: string): number {
    let total = directPosterCount.get(groupId) ?? 0;
    for (const sub of subOf.get(groupId) ?? []) {
      total += recurse(sub);
    }
    return total;
  }

  const groups = (rootGroups ?? []).map((g) => ({
    id: g.id as string,
    name: g.name as string,
    group_type: (g.group_type as string | null) ?? null,
    child_count: recurse(g.id as string),
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
