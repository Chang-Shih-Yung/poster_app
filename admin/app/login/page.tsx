"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { describeError } from "@/lib/errors";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { AlertTriangle, Loader2 } from "lucide-react";

export default function LoginPage() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signInWithGoogle() {
    setError(null);
    setBusy(true);
    try {
      const supabase = createClient();
      const origin = window.location.origin;
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: `${origin}/auth/callback`,
        },
      });
      if (error) throw error;
      // Successful OAuth start: Supabase redirects the page itself.
    } catch (e) {
      setError(describeError(e));
      setBusy(false);
    }
  }

  return (
    <main className="min-h-screen bg-background text-foreground flex items-center justify-center p-4">
      <Card className="w-80">
        <CardHeader className="text-center">
          <CardTitle>Poster. Admin</CardTitle>
          <CardDescription>只有白名單內的 Google 帳號能登入。</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button onClick={signInWithGoogle} className="w-full" disabled={busy}>
            {busy && <Loader2 className="animate-spin" />}
            {busy ? "導向中…" : "以 Google 登入"}
          </Button>
          {error && (
            <div className="flex items-start gap-2 rounded-md bg-destructive/10 border border-destructive/30 p-3 text-sm text-destructive">
              <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
              <span>登入失敗：{error}</span>
            </div>
          )}
        </CardContent>
      </Card>
    </main>
  );
}
