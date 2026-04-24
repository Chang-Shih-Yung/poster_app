import Nav from "./Nav";
import BottomTabBar from "./BottomTabBar";
import MobileHeader from "./MobileHeader";

/**
 * Unified page chrome:
 *   - Mobile: sticky top header + main + fixed bottom tab bar
 *   - Desktop (md+): top nav only
 * Pages pass a mobile title + optional back + action; the content
 * goes in children.
 */
export default function PageShell({
  title,
  showBack,
  mobileAction,
  children,
}: {
  title: string;
  showBack?: boolean;
  mobileAction?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <>
      <Nav />
      <MobileHeader title={title} showBack={showBack} action={mobileAction} />
      <main className="pb-24 md:pb-10 md:max-w-6xl md:mx-auto md:px-6 md:pt-8">
        {children}
      </main>
      <BottomTabBar />
    </>
  );
}
