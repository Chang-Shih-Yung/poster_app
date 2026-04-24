"use client";

import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  async function signInWithGoogle() {
    const supabase = createClient();
    const origin = window.location.origin;
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${origin}/auth/callback`,
      },
    });
  }

  return (
    <main className="min-h-screen flex items-center justify-center">
      <div className="w-80 p-8 rounded-xl bg-surface border border-line1 text-center">
        <h1 className="text-xl font-semibold mb-2">Poster. Admin</h1>
        <p className="text-sm text-textMute mb-6">
          只有白名單內的 Google 帳號能登入。
        </p>
        <button
          onClick={signInWithGoogle}
          className="w-full py-2.5 rounded-md bg-accent text-bg font-medium hover:opacity-90"
        >
          以 Google 登入
        </button>
      </div>
    </main>
  );
}
