import type { Metadata } from "next";
import "./globals.css";
import { ThemeProvider } from "@/components/ThemeProvider";

export const metadata: Metadata = {
  title: "Poster. Admin",
  description: "Editorial backend for Poster. catalogue + collection data.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-Hant" suppressHydrationWarning>
      <body>
        {/* `defaultTheme="dark"` keeps the legacy admin pages looking
         * identical until they migrate. The toggle lives on /tree and
         * only repaints surfaces that read shadcn CSS vars. */}
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false}>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
