"use client";

import { useEffect, useState } from "react";

/**
 * State returned by the guard hook so the caller can render its own
 * confirm dialog (we use shadcn AlertDialog instead of window.confirm
 * to keep the UI consistent across the admin panel).
 *
 * `pending` is `null` when no navigation is being held; otherwise a
 * thunk that, when called, performs the navigation the user attempted.
 * The dialog should call `confirm()` to run that thunk + close, or
 * `cancel()` to drop it.
 */
export type UnsavedGuardState = {
  pending: boolean;
  confirm: () => void;
  cancel: () => void;
};

/**
 * Block IN-APP navigation while there's unsaved work.
 *
 * Layers:
 *
 *   1. `popstate`            — mobile swipe-back, browser back button.
 *                              Push a sentinel history entry on mount and
 *                              re-push it when popstate fires, while also
 *                              raising a pending navigation for the caller's
 *                              AlertDialog to handle.
 *
 *   2. document `click`      — internal `<a href>` clicks (Next `<Link>`
 *                              renders an anchor). Capture-phase preventDefault
 *                              + stash the URL as a pending nav.
 *
 * What this does NOT cover (intentional):
 *
 *   • `beforeunload` (close tab / refresh / cross-origin link). Adding it
 *     creates a fight with our AlertDialog: when the dialog's "捨棄並離開"
 *     thunk does `window.location.href = url`, beforeunload fires AGAIN
 *     and shows a SECOND native confirm. The user clicks twice or gets
 *     stuck. Pick one layer and stick to it. We pick AlertDialog because
 *     it covers the real-world risk (mobile tap on BottomTabBar, swipe
 *     back) consistently with the rest of the admin UI; close-tab/F5
 *     are deliberate user actions where the data loss is expected.
 *
 *   • imperative `router.push()` from React code. Next App Router has no
 *     public hook for those. Audit the page that uses this guard to make
 *     sure all imperative pushes happen at moments where there's nothing
 *     left to lose (e.g. after a successful submit).
 */
export function useUnsavedChangesGuard(active: boolean): UnsavedGuardState {
  // The pending navigation is stored as a thunk. Using a state-of-function
  // requires the lazy-init/lazy-update form (`setPendingAction(() => fn)`)
  // because React would otherwise call the function thinking it's an
  // updater.
  const [pendingAction, setPendingAction] = useState<null | (() => void)>(
    null
  );

  useEffect(() => {
    if (!active || typeof window === "undefined") return;

    function clickGuard(e: MouseEvent) {
      // Modifier-clicks open a new tab and don't lose state — let them through.
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
        return;
      }
      const target = e.target as Element | null;
      const link = target?.closest?.("a[href]") as HTMLAnchorElement | null;
      if (!link) return;
      // target=_blank → new tab, current page survives.
      if (link.target && link.target !== "_self") return;
      // Same-page hash links don't navigate away.
      if (link.hash && link.pathname === window.location.pathname) return;

      // Hold the click. The caller's AlertDialog will decide.
      e.preventDefault();
      e.stopPropagation();
      const url = link.href;
      setPendingAction(() => () => {
        // Full-page nav. Could route via Next router for client-side
        // transition, but BottomTabBar / breadcrumbs are all admin
        // pages — a full reload is one extra second and avoids needing
        // to thread a `router` ref through.
        window.location.href = url;
      });
    }

    function popstateGuard() {
      // Re-push the sentinel so the URL stays put while we ask.
      window.history.pushState(null, "", window.location.href);
      setPendingAction(() => () => {
        // Confirmed: detach so the second popstate isn't intercepted,
        // then walk back past both our sentinel AND the original entry
        // the user wanted to leave.
        window.removeEventListener("popstate", popstateGuard);
        window.history.go(-2);
      });
    }

    window.history.pushState(null, "", window.location.href);

    document.addEventListener("click", clickGuard, true);
    window.addEventListener("popstate", popstateGuard);

    return () => {
      document.removeEventListener("click", clickGuard, true);
      window.removeEventListener("popstate", popstateGuard);
    };
  }, [active]);

  return {
    pending: pendingAction !== null,
    confirm: () => {
      const fn = pendingAction;
      setPendingAction(null);
      fn?.();
    },
    cancel: () => setPendingAction(null),
  };
}
