import Link from "next/link";
import { Layers, Image as ImageIcon, ChevronRight } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import PageShell from "@/components/PageShell";
import { createClient } from "@/lib/supabase/server";
import LogoutButton from "@/components/LogoutButton";
import { Card, CardContent } from "@/components/ui/card";

export const dynamic = "force-dynamic";

export default async function MorePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <PageShell title="更多">
      <div className="px-4 md:px-0 pt-4 md:pt-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-6">
          更多
        </h1>

        <section className="mb-6">
          <SectionLabel>帳號</SectionLabel>
          <Card>
            <CardContent className="p-4">
              <div className="text-sm text-foreground">{user?.email}</div>
              <div className="text-xs text-muted-foreground mt-1">管理員</div>
            </CardContent>
          </Card>
        </section>

        <section className="mb-6">
          <SectionLabel>資料管理</SectionLabel>
          <Card>
            <CardContent className="p-0">
              <ul className="divide-y divide-border">
                <Row href="/works" label="所有作品" icon={Layers} />
                <Row href="/posters" label="所有海報" icon={ImageIcon} />
              </ul>
            </CardContent>
          </Card>
        </section>

        <section>
          <LogoutButton />
        </section>
      </div>
    </PageShell>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div className="text-xs uppercase tracking-wider text-muted-foreground mb-2">
      {children}
    </div>
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
        className="flex items-center px-4 py-3.5 min-h-[52px] hover:no-underline group transition-colors"
      >
        <Icon className="w-4 h-4 mr-3 text-muted-foreground shrink-0 group-hover:text-foreground transition-colors" />
        <span className="text-foreground flex-1">{label}</span>
        <ChevronRight className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
      </Link>
    </li>
  );
}
