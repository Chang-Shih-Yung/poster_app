"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import type { ActionResult } from "@/app/actions/_internal";

/**
 * Common boilerplate for calling server actions from a client. Two
 * shapes:
 *
 *   - `runFormAction(actionFn)` — returns a Promise<void> suitable
 *     for FormSheet's onSubmit prop. Resolves on success (FormSheet
 *     closes itself), rejects with the action error so FormSheet's
 *     own try/catch surfaces it inline.
 *
 *   - `runAction(actionFn, { onError })` — fire-and-forget, with the
 *     transition pending state tracked. Used for confirm-then-go
 *     deletes that don't open a form first.
 *
 * `pending` reflects "any action wrapped by this hook is in flight"
 * — useTransition keeps the prior UI rendered until it clears, which
 * is what eliminates the post-mutation flash that `router.refresh`
 * used to cause.
 */
export function useTransitionAction() {
  const [pending, startTransition] = useTransition();

  function runFormAction<T>(
    actionFn: () => Promise<ActionResult<T>>,
    onSuccess?: (data: T) => void
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      startTransition(async () => {
        const r = await actionFn();
        if (!r.ok) {
          reject(new Error(r.error));
          return;
        }
        if (onSuccess) onSuccess(r.data);
        resolve();
      });
    });
  }

  function runAction(
    actionFn: () => Promise<ActionResult<unknown>>,
    opts?: { onError?: (err: string) => void; onSuccess?: () => void }
  ) {
    startTransition(async () => {
      const r = await actionFn();
      if (!r.ok) {
        if (opts?.onError) opts.onError(r.error);
        else toast.error(r.error);
        return;
      }
      opts?.onSuccess?.();
    });
  }

  return { pending, runFormAction, runAction };
}
