"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import type { ActionResult } from "@/app/actions/_internal";

/**
 * Common boilerplate for calling server actions from a client. Two
 * shapes:
 *
 *   - `runFormAction(actionFn, onSuccess?, opts?)` — returns a
 *     Promise<void> suitable for FormSheet's onSubmit prop. Resolves
 *     on success (FormSheet closes itself), rejects with the action
 *     error so FormSheet's own try/catch surfaces it inline.
 *
 *   - `runAction(actionFn, opts?)` — fire-and-forget, with the
 *     transition pending state tracked. Used for confirm-then-go
 *     deletes that don't open a form first.
 *
 * Both helpers toast on outcome so EVERY mutation gives the user
 * feedback by default:
 *   - Failure → toast.error(r.error) (skipped if opts.onError handles it)
 *   - Success → toast.success(opts.successToast)
 *               opts.successToast can be a string (toast it),
 *               undefined (toast a generic "已完成"),
 *               or false (suppress — for low-noise / inline UI changes
 *               like drag reorders that already animate).
 *
 * `pending` reflects "any action wrapped by this hook is in flight"
 * — useTransition keeps the prior UI rendered until it clears, which
 * is what eliminates the post-mutation flash that `router.refresh`
 * used to cause.
 */

const DEFAULT_SUCCESS = "已完成";

type SuccessToast = string | false | undefined;

function maybeToastSuccess(t: SuccessToast) {
  if (t === false) return;
  toast.success(t ?? DEFAULT_SUCCESS);
}

export function useTransitionAction() {
  const [pending, startTransition] = useTransition();

  function runFormAction<T>(
    actionFn: () => Promise<ActionResult<T>>,
    onSuccess?: (data: T) => void,
    opts?: { successToast?: SuccessToast }
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      startTransition(async () => {
        const r = await actionFn();
        if (!r.ok) {
          reject(new Error(r.error));
          return;
        }
        if (onSuccess) onSuccess(r.data);
        maybeToastSuccess(opts?.successToast);
        resolve();
      });
    });
  }

  function runAction(
    actionFn: () => Promise<ActionResult<unknown>>,
    opts?: {
      onError?: (err: string) => void;
      onSuccess?: () => void;
      successToast?: SuccessToast;
    }
  ) {
    startTransition(async () => {
      const r = await actionFn();
      if (!r.ok) {
        if (opts?.onError) opts.onError(r.error);
        else toast.error(r.error);
        return;
      }
      opts?.onSuccess?.();
      maybeToastSuccess(opts?.successToast);
    });
  }

  return { pending, runFormAction, runAction };
}
