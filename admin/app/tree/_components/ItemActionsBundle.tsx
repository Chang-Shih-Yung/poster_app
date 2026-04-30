"use client";

import * as React from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { SheetMenuList, type SheetMenuItem } from "./SheetMenu";
import { FormSheet, type FormField } from "./FormSheet";
import { useTransitionAction } from "@/lib/clientActions";
import type { ActionResult } from "@/app/actions/_internal";

/**
 * A row's "⋯" menu in one declarative bundle. Pass the active item
 * + an action list; this owns the Sheet open/close state, dispatches
 * forms when their action is picked, and routes server-action calls
 * through useTransitionAction so each click stays flicker-free.
 *
 * Two action shapes:
 *
 *   { kind: "form" }    Opens a FormSheet with the supplied fields.
 *                       Resolves the action with the trimmed values.
 *   { kind: "instant" } Fires straight away. Optional confirm() turns
 *                       it into a shadcn AlertDialog before the action
 *                       runs (replaces the old window.confirm() which
 *                       is silently ignored in iOS Safari PWA mode).
 *
 * The `item` prop drives everything — set to non-null to open the
 * menu, set to null (via `onClose`) to dismiss. Forms keep the menu
 * dismissed automatically via the standard "open: !!item && !formOpen"
 * pattern.
 */

/**
 * Optional success-toast override for an ItemAction:
 *   - string             → toast that exact text
 *   - (item) => string   → derive from the item (e.g. "已刪除「{name}」")
 *   - false              → suppress (use when the UI already gives
 *                          unambiguous feedback, e.g. a navigation pop)
 *   - undefined / omit   → fallback to "已${action.label}" derived in
 *                          ItemActionsBundle below
 */
type ActionSuccessToast<T> = string | ((item: T) => string) | false;

export type ItemFormAction<T> = {
  kind: "form";
  icon: React.ReactNode;
  label: string;
  hint?: string;
  destructive?: boolean;
  disabled?: boolean;
  formTitle: string;
  formDescription?: string;
  fields: (item: T) => FormField[];
  submitLabel?: string;
  successToast?: ActionSuccessToast<T>;
  run: (item: T, values: Record<string, string>) => Promise<ActionResult<unknown>>;
};

export type ItemInstantAction<T> = {
  kind: "instant";
  icon: React.ReactNode;
  label: string;
  hint?: string;
  destructive?: boolean;
  disabled?: boolean;
  confirm?: (item: T) => string;
  successToast?: ActionSuccessToast<T>;
  run: (item: T) => Promise<ActionResult<unknown>>;
};

export type ItemAction<T> = ItemFormAction<T> | ItemInstantAction<T>;

/**
 * Resolve the per-action override into the helpers' SuccessToast value.
 * The default ("已${label}") is generated at the ItemActionsBundle layer
 * so every action gets feedback unless explicitly silenced.
 */
function resolveSuccessToast<T>(
  action: ItemAction<T>,
  item: T
): string | false {
  const t = action.successToast;
  if (t === false) return false;
  if (typeof t === "function") return t(item);
  if (typeof t === "string") return t;
  // Default: "已重新命名群組" / "已刪除群組" — reads naturally because
  // every action.label in this codebase is verb-led ("刪除...", "重新命名...").
  return `已${action.label}`;
}

type ConfirmState<T> = {
  action: ItemInstantAction<T>;
  item: T;
  message: string;
};

export function ItemActionsBundle<T>({
  item,
  onClose,
  title,
  description,
  actions,
}: {
  item: T | null;
  onClose: () => void;
  title: string;
  description?: React.ReactNode;
  actions: ItemAction<T>[];
}) {
  const [formIdx, setFormIdx] = React.useState<number | null>(null);
  const [confirmState, setConfirmState] = React.useState<ConfirmState<T> | null>(null);
  const { runFormAction, runAction } = useTransitionAction();

  // Closing the menu also closes any open form, since both reference
  // the same `item`.
  function closeAll() {
    setFormIdx(null);
    onClose();
  }

  const activeForm =
    item != null && formIdx != null && actions[formIdx]?.kind === "form"
      ? (actions[formIdx] as ItemFormAction<T>)
      : null;

  // Sheet is open when item is set AND we're not in form or confirm mode.
  const sheetOpen = item != null && formIdx == null && confirmState == null;

  return (
    <>
      <Sheet
        open={sheetOpen}
        onOpenChange={(v) => {
          if (!v) closeAll();
        }}
      >
        <SheetContent
          side="bottom"
          // Radix Dialog requires a Description child or an explicit
          // opt-out — bundles without a description (e.g. delete-only
          // single-action rows) pass undefined to silence the warning.
          {...(description ? {} : { "aria-describedby": undefined })}
        >
          <SheetHeader>
            <SheetTitle className="truncate">{title}</SheetTitle>
            {description && <SheetDescription>{description}</SheetDescription>}
          </SheetHeader>
          {item != null && (
            <div className="mt-3">
              <SheetMenuList
                items={actions.map<SheetMenuItem>((a, idx) => ({
                  icon: a.icon,
                  label: a.label,
                  hint: a.hint,
                  destructive: a.destructive,
                  disabled: a.disabled,
                  onClick: () => {
                    if (a.kind === "form") {
                      setFormIdx(idx);
                      return;
                    }
                    // instant: close sheet first, then either show
                    // AlertDialog (if confirm defined) or fire directly.
                    const target = item;
                    onClose();
                    if (a.confirm) {
                      const msg = a.confirm(target);
                      setConfirmState({ action: a, item: target, message: msg });
                      return;
                    }
                    runAction(() => a.run(target), {
                      successToast: resolveSuccessToast(a, target),
                    });
                  },
                }))}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* Destructive confirmation — replaces window.confirm() which is
          silently ignored in iOS Safari PWA mode. */}
      <AlertDialog
        open={confirmState != null}
        onOpenChange={(v) => {
          if (!v) setConfirmState(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>確認操作</AlertDialogTitle>
            <AlertDialogDescription className="whitespace-pre-line">
              {confirmState?.message}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setConfirmState(null)}>
              取消
            </AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (!confirmState) return;
                const { action, item: target } = confirmState;
                setConfirmState(null);
                runAction(() => action.run(target), {
                  successToast: resolveSuccessToast(action, target),
                });
              }}
            >
              確認刪除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {activeForm && item != null && (
        <FormSheet
          open
          onOpenChange={(v) => {
            if (!v) {
              setFormIdx(null);
              onClose();
            }
          }}
          title={activeForm.formTitle}
          description={activeForm.formDescription}
          fields={activeForm.fields(item)}
          submitLabel={activeForm.submitLabel}
          onSubmit={(values) =>
            runFormAction(
              () => activeForm.run(item, values),
              () => {
                setFormIdx(null);
                onClose();
              },
              { successToast: resolveSuccessToast(activeForm, item) }
            )
          }
        />
      )}
    </>
  );
}
