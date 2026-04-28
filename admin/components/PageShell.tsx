import Nav from "./Nav";
import BottomTabBar from "./BottomTabBar";
import MobileHeader from "./MobileHeader";

/**
 * Unified page chrome:
 *   - Mobile: sticky top header + main + fixed bottom tab bar
 *   - Desktop (md+): top nav only
 *
 * Pages pass a mobile title + optional back behaviour + action; the
 * content goes in children. The body uses shadcn theme tokens so light
 * / dark mode swap globally.
 */
export default function PageShell({
  title,
  back,
  mobileAction,
  children,
}: {
  title: string;
  /** `true` → router.back(); `{ href, label }` → breadcrumb-style link
   * to a parent page; falsy → no back button (root page). */
  back?: { href: string; label: string } | boolean;
  mobileAction?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Nav />
      <MobileHeader title={title} back={back} action={mobileAction} />
      <main className="pb-24 md:pb-10 md:max-w-6xl md:mx-auto md:px-6 md:pt-8">
        {children}
      </main>
      <BottomTabBar />
    </div>
  );
}
