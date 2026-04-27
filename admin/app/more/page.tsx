import Link from "next/link";
import { Layers, Image as ImageIcon, ChevronRight } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";
import LogoutButton from "@/components/LogoutButton";

export const dynamic = "force-dynamic";

export default async function MorePage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <PageShell title="更多">
      <div className="md:px-0">
        <h1 className="hidden md:block text-2xl font-semibold mb-6 px-4 md:px-0">
          更多
        </h1>

        <section className="mb-6 px-4 md:px-0">
          <div className="text-xs uppercase tracking-wider text-textMute mb-2">
            帳號
          </div>
          <div className="rounded-lg bg-surface border border-line1 p-4">
            <div className="text-sm text-text">{user?.email}</div>
            <div className="text-xs text-textFaint mt-1">管理員</div>
          </div>
        </section>

        <section className="mb-6">
          <div className="text-xs uppercase tracking-wider text-textMute mb-2 px-4 md:px-0">
            資料管理
          </div>
          <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
            <Row href="/works" label="管理所有作品" icon={Layers} />
            <Row href="/posters" label="管理所有海報" icon={ImageIcon} />
          </ul>
        </section>

        <section className="px-4 md:px-0">
          <LogoutButton />
        </section>
      </div>
    </PageShell>
  );
}

function Row({
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
        className="flex items-center px-4 py-3.5 min-h-[52px] hover:bg-surfaceRaised hover:no-underline"
      >
        <Icon className="w-4 h-4 mr-3 text-textMute shrink-0" />
        <span className="text-text flex-1">{label}</span>
        <ChevronRight className="w-4 h-4 text-textFaint" />
      </Link>
    </li>
  );
}
