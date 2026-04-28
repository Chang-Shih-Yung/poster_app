"use client";

import { useState } from "react";

/**
 * Picker → form state machine for the "+ FAB → choose kind → fill
 * form" flow shared by /tree/work and /tree/group. Replaces three
 * separate `useState(false)` calls that were prone to "the picker
 * AND the group form are both open" inconsistency.
 *
 * Generic over the form keys, e.g. `useAddSheets<"group" | "poster">()`.
 *
 * State machine:
 *   closed  → openPicker() → picker
 *   picker  → openForm("k") → form:k
 *   any     → close() → closed
 */
export function useAddSheets<K extends string>() {
  type State = { kind: "closed" } | { kind: "picker" } | { kind: K };
  const [state, setState] = useState<State>({ kind: "closed" });

  return {
    /** True iff the picker sheet is currently shown. */
    pickerOpen: state.kind === "picker",
    /** Which form is open (or null if none). */
    formKind:
      state.kind === "closed" || state.kind === "picker"
        ? null
        : (state.kind as K),
    openPicker: () => setState({ kind: "picker" }),
    /** Switch from picker (or closed) to a specific form. */
    openForm: (k: K) => setState({ kind: k }),
    /** Reset to closed. */
    close: () => setState({ kind: "closed" }),
    /** Convenience for `<Sheet onOpenChange={setPickerSheet}>`. */
    setPickerOpen: (v: boolean) =>
      setState(v ? { kind: "picker" } : { kind: "closed" }),
    /** Convenience for `<FormSheet onOpenChange={setFormOpen("group")}>`. */
    setFormOpen:
      (k: K) =>
      (v: boolean) =>
        setState(v ? { kind: k } : { kind: "closed" }),
  };
}
