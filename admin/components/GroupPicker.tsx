"use client";

import * as React from "react";
import { FolderPlus } from "lucide-react";
import { toast } from "sonner";
import { createGroup } from "@/app/actions/groups";
import {
  SearchableSelect,
  type SearchableItem,
} from "@/components/ui/searchable-select";
import { CommandItem } from "@/components/ui/command";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import type { FlattenedGroup } from "@/lib/groupTree";

const NONE = "__none__";

/**
 * Searchable dropdown for picking a group within a work. On top of the
 * search behaviour from SearchableSelect:
 *
 * 1. Inserts a visual separator before each new top-level group block
 *    so the parent → child structure is readable in a long list.
 * 2. Adds an inline "+ 新增頂層群組…" action that opens a dialog,
 *    creates the group via the existing `createGroup` server action,
 *    and auto-selects it.
 *
 * Newly-created groups are always inserted at the work's top level —
 * keeps the UX simple. If the admin needs nesting, they can move the
 * group later from the tree view.
 */
export function GroupPicker({
  workId,
  workName,
  groups,
  value,
  onChange,
  onGroupCreated,
  disabled,
  noneLabel = "── 不屬於任何群組 ──",
}: {
  workId: string;
  /** Used in the "建立在 X 頂層" dialog copy. */
  workName?: string;
  groups: FlattenedGroup[];
  /** Either NONE sentinel or a group id. */
  value: string;
  onChange: (v: string) => void;
  /** Called after a new group is created so the parent can re-fetch
   * the groups list (server-side create doesn't push to client state). */
  onGroupCreated?: (newGroupId: string) => void;
  disabled?: boolean;
  noneLabel?: string;
}) {
  const [createOpen, setCreateOpen] = React.useState(false);
  const [newName, setNewName] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);

  // Build the items: NONE first, then each group with a separator
  // before every top-level (depth=0) group except the first.
  const items: SearchableItem[] = [
    {
      value: NONE,
      label: noneLabel,
      searchText: "none 不屬於 不指定",
    },
    ...groups.map((g, idx): SearchableItem => {
      const isTopLevel = g.depth === 0;
      // The "previous" group in the list — used to detect block boundaries.
      const prev = groups[idx - 1];
      // Insert a separator BEFORE this row when it's a new top-level block
      // and we've already emitted at least one group above.
      const separatorBefore = isTopLevel && idx > 0;
      return {
        value: g.id,
        label: g.label, // full path so trigger shows context
        searchText: g.label,
        separatorBefore,
        // Tiny indent for child rows so depth is visible at a glance.
        // Top-level: 0; depth 1: 0.75rem; depth 2+: capped at 1.5rem.
        indentRem: Math.min(g.depth, 2) * 0.75,
        // Keep as part of label cluster — separatorBefore handles the visual gap.
        ...(prev && !isTopLevel ? {} : {}),
      };
    }),
  ];

  async function submitNewGroup() {
    const trimmed = newName.trim();
    if (!trimmed) {
      toast.error("群組名稱必填");
      return;
    }
    setSubmitting(true);
    const r = await createGroup({
      work_id: workId,
      parent_group_id: null, // 永遠建在頂層 — 簡化決策
      name: trimmed,
    });
    setSubmitting(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success(`已新增群組「${trimmed}」`);
    setCreateOpen(false);
    setNewName("");
    onGroupCreated?.(r.data.id);
    onChange(r.data.id);
  }

  return (
    <>
      <SearchableSelect
        items={items}
        value={value}
        onChange={onChange}
        placeholder={noneLabel}
        searchPlaceholder="搜尋群組（含父層）…"
        emptyText="找不到符合的群組"
        disabled={disabled}
        footer={(close) => (
          <CommandItem
            value="__action_new_group__"
            keywords={["新增群組 new add"]}
            onSelect={() => {
              close();
              setCreateOpen(true);
            }}
            className="text-primary"
          >
            <FolderPlus className="mr-2 h-4 w-4" />
            <span>新增頂層群組…</span>
          </CommandItem>
        )}
      />

      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>新增群組</DialogTitle>
            <DialogDescription>
              {workName
                ? `會建在「${workName}」的頂層。建好後想嵌套到別的群組底下，到目錄頁拖移即可。`
                : "會建在這個作品的頂層。"}
            </DialogDescription>
          </DialogHeader>
          <Input
            autoFocus
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            placeholder="例：2024 國際版"
            disabled={submitting}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                submitNewGroup();
              }
            }}
          />
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setCreateOpen(false)}
              disabled={submitting}
            >
              取消
            </Button>
            <Button
              type="button"
              onClick={submitNewGroup}
              disabled={submitting || !newName.trim()}
            >
              {submitting && <Loader2 className="animate-spin" />}
              {submitting ? "建立中…" : "建立並選取"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
