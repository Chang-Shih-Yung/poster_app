"use client";

import * as React from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
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
 *                       it into "are-you-sure" before the action runs.
 *
 * The `item` prop drives everything — set to non-null to open the
 * menu, set to null (via `onClose`) to dismiss. Forms keep the menu
 * dismissed automatically via the standard "open: !!item && !formOpen"
 * pattern.
 */

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
  run: (item: T) => Promise<ActionResult<unknown>>;
};

export type ItemAction<T> = ItemFormAction<T> | ItemInstantAction<T>;

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

  return (
    <>
      <Sheet
        open={item != null && formIdx == null}
        onOpenChange={(v) => {
          if (!v) closeAll();
        }}
      >
        <SheetContent side="bottom">
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
                    // instant: confirm if requested, then fire.
                    const target = item;
                    if (a.confirm) {
                      const msg = a.confirm(target);
                      if (msg && !confirm(msg)) return;
                    }
                    onClose();
                    runAction(() => a.run(target));
                  },
                }))}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

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
            runFormAction(() => activeForm.run(item, values), () => {
              setFormIdx(null);
              onClose();
            })
          }
        />
      )}
    </>
  );
}
