"use client";

import * as React from "react";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme, resolvedTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);
  // next-themes resolves on the client; rendering before mount produces
  // a flash of mismatched icon.
  React.useEffect(() => setMounted(true), []);
  const current = mounted ? resolvedTheme ?? theme : "dark";
  const next = current === "dark" ? "light" : "dark";
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(next)}
      title={current === "dark" ? "切換到白天模式" : "切換到夜晚模式"}
      aria-label="切換主題"
    >
      {mounted && current === "dark" ? (
        <Sun className="h-4 w-4" />
      ) : (
        <Moon className="h-4 w-4" />
      )}
    </Button>
  );
}
