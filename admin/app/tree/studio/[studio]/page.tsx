import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import StudioClient from "./StudioClient";
import { NULL_STUDIO_KEY } from "../../_components/keys";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

export default async function StudioPage({
  params,
}: {
  params: Promise<{ studio: string }>;
}) {
  const { studio: rawParam } = await params;
  const studio = decodeURIComponent(rawParam);
  const supabase = await createClient();

  const q = supabase
    .from("works")
    .select("id, title_zh, title_en, work_kind, poster_count, studio")
    .order("created_at", { ascending: false });
  const { data: works } =
    studio === NULL_STUDIO_KEY ? await q.is("studio", null) : await q.eq("studio", studio);

  // Empty studio that isn't the synthetic "未分類" → 404. (For 未分類
  // we still render the empty page so admin can rename / add into it.)
  if ((!works || works.length === 0) && studio !== NULL_STUDIO_KEY) {
    notFound();
  }

  return (
    <StudioClient nav={<Nav />} studio={studio} works={works ?? []} />
  );
}
