import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import LogoutButton from "./LogoutButton";

export default async function Nav() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <nav className="hidden md:flex items-center justify-between px-6 py-3 border-b border-line1">
      <div className="flex items-center gap-6">
        <Link href="/" className="font-semibold text-text hover:no-underline">
          Poster. Admin
        </Link>
        <Link href="/tree">目錄樹</Link>
        <Link href="/works">所有作品</Link>
        <Link href="/posters">所有海報</Link>
        <Link href="/upload-queue">待補圖</Link>
      </div>
      <div className="flex items-center gap-3 text-sm text-textMute">
        {user && <span>{user.email}</span>}
        <LogoutButton />
      </div>
    </nav>
  );
}
