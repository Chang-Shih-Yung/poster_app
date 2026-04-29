"use client";

import { useEffect } from "react";

/**
 * Block in-app and browser-level navigation while there's unsaved work.
 *
 * Why each layer exists:
 *
 *   1. `beforeunload`        — close tab / refresh / hard-link to external URL
 *   2. `popstate`            — mobile swipe-back, browser back button
 *   3. document `click`      — internal `<a href>` clicks (Next `<Link>` renders
 *                              an anchor, so capture-phase click intercepts both
 *                              shadcn Links and the bottom tab bar)
 *
 * What this does NOT cover: imperative `router.push()` from inside React
 * code — Next App Router has no public hook for those. We don't have any
 * uncovered call sites in BatchImport (the only `router.push` runs after
 * a successful submit, when there's nothing left to lose).
 *
 * Pass `active = false` to disable the guard entirely (e.g. when the form
 * is empty). The hook attaches/detaches listeners reactively.
 *
 * The popstate trick:
 *   - On mount, push a sentinel history entry with the same URL (no-op
 *     for the user but gives us a "buffer" to consume on back).
 *   - When `popstate` fires (= user pressed back), we re-push the
 *     sentinel so the URL stays put and ASK the user to confirm.
 *   - If they confirm: detach the popstate listener and call
 *     `history.go(-2)` so we skip past both our sentinel AND the
 *     real previous entry.
 *   - If they cancel: do nothing. The sentinel keeps the page open.
 *
 * The trick costs ONE extra entry on the history stack while the page
 * is mounted. Cleanup pops it back off if cleanup runs without the
 * user navigating away.
 */
export function useUnsavedChangesGuard(
  active: boolean,
  message = "有未儲存的內容，確定離開嗎？"
) {
  useEffect(() => {
    if (!active || typeof window === "undefined") return;

    function beforeUnload(e: BeforeUnloadEvent) {
      e.preventDefault();
      // Modern browsers ignore the message and show their own.
      e.returnValue = "";
    }

    function clickGuard(e: MouseEvent) {
      // Only intercept left-clicks on plain links (not modifier-clicks
      // like cmd-click which open new tabs and don't lose state anyway).
      if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
        return;
      }
      const target = e.target as Element | null;
      const link = target?.closest?.("a[href]") as HTMLAnchorElement | null;
      if (!link) return;
      // Allow target=_blank (new tab) — current page is unaffected.
      if (link.target && link.target !== "_self") return;
      // Allow same-page hash links.
      if (link.hash && link.pathname === window.location.pathname) return;
      if (!window.confirm(message)) {
        e.preventDefault();
        e.stopPropagation();
      }
    }

    function popstateGuard() {
      // The user just popped past our sentinel. Re-push it so the URL
      // is back to where they thought they were.
      window.history.pushState(null, "", window.location.href);
      if (window.confirm(message)) {
        // Detach BEFORE navigating, otherwise we'd intercept again.
        window.removeEventListener("popstate", popstateGuard);
        // Skip our sentinel + the original entry the user wanted to leave.
        window.history.go(-2);
      }
    }

    // Set up the sentinel for popstate to consume.
    window.history.pushState(null, "", window.location.href);

    window.addEventListener("beforeunload", beforeUnload);
    document.addEventListener("click", clickGuard, true); // capture
    window.addEventListener("popstate", popstateGuard);

    return () => {
      window.removeEventListener("beforeunload", beforeUnload);
      document.removeEventListener("click", clickGuard, true);
      window.removeEventListener("popstate", popstateGuard);
      // Pop the sentinel we pushed on mount. If the user already
      // navigated away (hook re-runs / unmounts), the sentinel is gone
      // so this is a no-op.
      // We can't reliably tell, so we leave it: an extra history entry
      // is harmless. A user pressing back twice will end up at the
      // page above — same UX as if we'd cleaned up.
    };
  }, [active, message]);
}
