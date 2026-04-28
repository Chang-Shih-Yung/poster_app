import Link from "next/link";
import { FolderTree, Plus, Upload, ChevronRight } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { cn } from "@/lib/utils";

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
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-6">
          後台 · 總覽
        </h1>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-6">
          <StatCard label="作品數" value={worksCount.count ?? 0} />
          <StatCard label="海報數" value={postersCount.count ?? 0} />
          <StatCard
            label="待補真圖"
            value={placeholderCount.count ?? 0}
            highlight={Boolean(placeholderCount.count)}
          />
        </div>

        <Card>
          <CardHeader className="py-4">
            <CardTitle className="text-sm">快速操作</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              <ActionRow href="/tree" label="瀏覽海報目錄" icon={FolderTree} />
              <ActionRow href="/works/new" label="新增作品" icon={Plus} />
              <ActionRow href="/posters/new" label="新增海報" icon={Plus} />
              <ActionRow href="/upload-queue" label="待補真圖佇列" icon={Upload} />
            </ul>
          </CardContent>
        </Card>
      </div>
    </PageShell>
  );
}

function StatCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number | string;
  highlight?: boolean;
}) {
  return (
    <Card
      className={cn(
        highlight &&
          "border-amber-500/40 bg-amber-500/5 dark:border-amber-500/30 dark:bg-amber-500/10"
      )}
    >
      <CardHeader className="p-4 pb-2">
        <CardDescription className="text-[11px] uppercase tracking-wider">
          {label}
        </CardDescription>
        <CardTitle className="text-2xl md:text-3xl">{value}</CardTitle>
      </CardHeader>
    </Card>
  );
}

function ActionRow({
  href,
  label,
  icon: Icon,
}: {
  href: string;
  label: string;
  icon: LucideIcon;
}) {
  return (
    <li>
      <Link
        href={href}
        className="flex items-center px-4 py-3.5 min-h-[52px] hover:no-underline group transition-colors"
      >
        <Icon className="w-4 h-4 mr-3 text-muted-foreground shrink-0 group-hover:text-foreground transition-colors" />
        <span className="text-foreground flex-1">{label}</span>
        <ChevronRight className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
      </Link>
    </li>
  );
}
