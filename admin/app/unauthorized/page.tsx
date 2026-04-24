import { createClient } from "@/lib/supabase/server";
import LogoutButton from "@/components/LogoutButton";

export default async function UnauthorizedPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <main className="min-h-screen flex items-center justify-center">
      <div className="w-96 p-8 rounded-xl bg-surface border border-line1 text-center space-y-4">
        <h1 className="text-xl font-semibold">無權限</h1>
        <p className="text-sm text-textMute">
          {user?.email} 不在 admin 白名單內。請改用已授權的 Google 帳號登入。
        </p>
        <LogoutButton />
      </div>
    </main>
  );
}
