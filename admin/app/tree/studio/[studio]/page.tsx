import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import StudioClient from "./StudioClient";
import { NULL_STUDIO_KEY } from "@/lib/keys";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

const PAGE_SIZE = 50;

export default async function StudioPage({
  params,
}: {
  params: Promise<{ studio: string }>;
}) {
  const { studio: rawParam } = await params;
  const studio = decodeURIComponent(rawParam);
  const supabase = await createClient();

  // First page only; the StudioClient calls loadWorksPage(studio) for
  // subsequent batches via "載入更多".
  const q = supabase
    .from("works")
    .select(
      "id, title_zh, title_en, work_kind, poster_count, studio, created_at"
    )
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .limit(PAGE_SIZE);
  const { data: works } =
    studio === NULL_STUDIO_KEY
      ? await q.is("studio", null)
      : await q.eq("studio", studio);

  if ((!works || works.length === 0) && studio !== NULL_STUDIO_KEY) {
    notFound();
  }

  const initial = works ?? [];
  const initialCursor =
    initial.length === PAGE_SIZE
      ? (initial[initial.length - 1].created_at as string)
      : null;

  return (
    <StudioClient
      nav={<Nav />}
      studio={studio}
      works={initial}
      initialCursor={initialCursor}
    />
  );
}
