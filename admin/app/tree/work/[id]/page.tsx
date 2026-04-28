import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { recursivePosterCount } from "@/lib/groupTree";
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

  const allGroupRows = (allGroups ?? []).map((g) => ({
    id: g.id as string,
    parent_group_id: (g.parent_group_id as string | null) ?? null,
  }));
  const allPosterRows = (allPosters ?? []).map((p) => ({
    parent_group_id: (p.parent_group_id as string | null) ?? null,
  }));

  const groups = (rootGroups ?? []).map((g) => ({
    id: g.id as string,
    name: g.name as string,
    group_type: (g.group_type as string | null) ?? null,
    child_count: recursivePosterCount(g.id as string, allGroupRows, allPosterRows),
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
