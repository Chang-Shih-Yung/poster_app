"use client";

import * as React from "react";
import { FolderPlus, Loader2 } from "lucide-react";
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
import type { FlattenedGroup } from "@/lib/groupTree";

const NONE = "__none__";

/**
 * Pure transform: turn a flat group list into rows for SearchableSelect.
 * Exported for testing — the UI behavior of separators / indent is
 * easier to verify here than against a rendered popover.
 */
export function buildGroupItems(
  groups: FlattenedGroup[],
  noneLabel: string
): SearchableItem[] {
  const items: SearchableItem[] = [
    {
      value: NONE,
      label: noneLabel,
      searchText: "none 不屬於 不放進 不指定 直接 作品下",
    },
  ];
  for (let idx = 0; idx < groups.length; idx++) {
    const g = groups[idx];
    const isTopLevel = g.depth === 0;
    items.push({
      value: g.id,
      label: g.label,
      searchText: g.label,
      // Visual break before each new top-level block (after the first).
      separatorBefore: isTopLevel && idx > 0,
      // Indent capped at depth 2 to keep the dropdown readable.
      indentRem: Math.min(g.depth, 2) * 0.75,
    });
  }
  return items;
}

/**
 * Searchable dropdown for picking a group within a work. On top of the
 * search behaviour from SearchableSelect:
 *
 * 1. Inserts a visual separator before each new top-level group block
 *    so the parent → child structure is readable in a long list.
 * 2. Adds an inline "+ 新增資料夾…" action that opens a dialog,
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
  noneLabel,
}: {
  workId: string;
  /** Used in the "在 X 底下新增資料夾" dialog copy AND, when no explicit
   * `noneLabel` is passed, woven into the NONE row so the admin can see
   * exactly which work the poster will land directly under. */
  workName?: string;
  groups: FlattenedGroup[];
  /** Either NONE sentinel or a group id. */
  value: string;
  onChange: (v: string) => void;
  /** Called after a new group is created so the parent can re-fetch
   * the groups list (server-side create doesn't push to client state). */
  onGroupCreated?: (newGroupId: string) => void;
  disabled?: boolean;
  /** Override the default NONE row label. When omitted, GroupPicker
   * builds one from `workName` so the row is concrete (e.g. "── 直接放在
   * 《蒼鷺與少年》底下 ──") instead of the generic "不放進群組". */
  noneLabel?: string;
}) {
  const [createOpen, setCreateOpen] = React.useState(false);
  const [newName, setNewName] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);

  // Dynamic NONE label so the admin sees the actual parent work name in
  // the dropdown — way clearer than a generic "不放進群組". Falls back to
  // the generic copy when workName is missing (e.g. picker rendered
  // before a work has been chosen in batch mode).
  const resolvedNoneLabel =
    noneLabel ??
    (workName
      ? `── 直接放在《${workName}》底下 ──`
      : "── 直接放在這個作品底下 ──");

  const items = buildGroupItems(groups, resolvedNoneLabel);

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
        placeholder={resolvedNoneLabel}
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
            <span>新增資料夾…</span>
          </CommandItem>
        )}
      />

      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>新增資料夾</DialogTitle>
            <DialogDescription>
              {workName
                ? `會在「${workName}」底下新增資料夾。`
                : "會在這個作品底下新增資料夾。"}
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
