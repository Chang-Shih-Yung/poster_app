import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import GroupClient from "./GroupClient";

export const dynamic = "force-dynamic";

/**
 * Group page — children of a poster_group node. Computes recursive
 * poster counts the same way as /tree/work/[id] and resolves the back
 * breadcrumb to either the parent group or the work this group sits in.
 */
export default async function GroupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: group } = await supabase
    .from("poster_groups")
    .select("id, name, group_type, work_id, parent_group_id")
    .eq("id", id)
    .maybeSingle();

  if (!group) notFound();

  const workId = group.work_id as string;

  // Resolve back link: if there's a parent group, link to it; else link
  // to the work. Fetch the parent's name in the same round-trip the
  // recursive count needs anyway.
  const [{ data: rootGroups }, { data: rootPosters }, { data: allGroups }, { data: allPosters }, { data: work }, { data: parentGroup }] =
    await Promise.all([
      supabase
        .from("poster_groups")
        .select("id, name, group_type")
        .eq("parent_group_id", id)
        .order("created_at", { ascending: false }),
      supabase
        .from("posters")
        .select("id, poster_name, is_placeholder, thumbnail_url")
        .eq("parent_group_id", id)
        .order("created_at", { ascending: false }),
      supabase
        .from("poster_groups")
        .select("id, parent_group_id")
        .eq("work_id", workId),
      supabase
        .from("posters")
        .select("parent_group_id")
        .eq("work_id", workId)
        .is("deleted_at", null),
      supabase.from("works").select("id, title_zh").eq("id", workId).maybeSingle(),
      group.parent_group_id
        ? supabase
            .from("poster_groups")
            .select("id, name")
            .eq("id", group.parent_group_id as string)
            .maybeSingle()
        : Promise.resolve({ data: null }),
    ]);

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

  const back = parentGroup
    ? {
        href: `/tree/group/${parentGroup.id as string}`,
        label: parentGroup.name as string,
      }
    : {
        href: `/tree/work/${workId}`,
        label: (work?.title_zh as string | undefined) ?? "作品",
      };

  return (
    <GroupClient
      group={{
        id: group.id as string,
        name: group.name as string,
        group_type: (group.group_type as string | null) ?? null,
        work_id: workId,
        parent_group_id: (group.parent_group_id as string | null) ?? null,
      }}
      back={back}
      groups={groups}
      posters={posters}
    />
  );
}
