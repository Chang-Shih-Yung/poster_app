"use client";

import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { LogOut } from "lucide-react";

export default function LogoutButton({
  variant = "outline",
  withIcon = true,
}: {
  variant?: "outline" | "ghost" | "secondary" | "quiet";
  withIcon?: boolean;
}) {
  const router = useRouter();

  async function logout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <Button onClick={logout} variant={variant} size="sm">
      {withIcon && <LogOut />}
      登出
    </Button>
  );
}
