import { createClient } from "@/lib/supabase/server";
import LogoutButton from "@/components/LogoutButton";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default async function UnauthorizedPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <main className="min-h-screen bg-background text-foreground flex items-center justify-center p-4">
      <Card className="w-96">
        <CardHeader className="text-center">
          <CardTitle>無權限</CardTitle>
          <CardDescription>
            {user?.email} 不在 admin 白名單內。請改用已授權的 Google 帳號登入。
          </CardDescription>
        </CardHeader>
        <CardContent className="flex justify-center">
          <LogoutButton />
        </CardContent>
      </Card>
    </main>
  );
}
