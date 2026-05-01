"use client";

import * as React from "react";
import { PackagePlus, Loader2, Settings } from "lucide-react";
import { toast } from "sonner";
import {
  createPosterSet,
  type PosterSet,
} from "@/app/actions/poster-sets";
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
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

const NONE = "__none__";

/**
 * Searchable dropdown for picking a poster set ("套票"). Mirrors the
 * GroupPicker shape:
 *   - First row "── 不屬於套票 ──" maps to NONE sentinel (server treats null)
 *   - Inline "+ 新增套票…" footer opens a dialog and auto-selects on success
 *
 * Sets are independent of works/groups — same set can appear under
 * different works (e.g. crossover campaigns). So the picker takes the
 * full list, doesn't filter by work.
 */
export function SetPicker({
  sets,
  value,
  onChange,
  onSetCreated,
  disabled,
}: {
  sets: PosterSet[];
  /** Either NONE sentinel or a poster_sets.id. */
  value: string;
  onChange: (v: string) => void;
  /** Called after a new set is created so caller can re-fetch sets. */
  onSetCreated?: (newSetId: string) => void;
  disabled?: boolean;
}) {
  const [createOpen, setCreateOpen] = React.useState(false);
  const [newName, setNewName] = React.useState("");
  const [newDesc, setNewDesc] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);

  const items: SearchableItem[] = [
    {
      value: NONE,
      label: "── 不屬於套票 ──",
      searchText: "none 不屬於 沒有 單張",
    },
    ...sets.map((s) => ({
      value: s.id,
      label: s.name,
      searchText: `${s.name} ${s.description ?? ""}`,
    })),
  ];

  async function submitNewSet() {
    const trimmed = newName.trim();
    if (!trimmed) {
      toast.error("套票名稱必填");
      return;
    }
    setSubmitting(true);
    const r = await createPosterSet({
      name: trimmed,
      description: newDesc.trim() || null,
    });
    setSubmitting(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success(`已新增套票「${trimmed}」`);
    setCreateOpen(false);
    setNewName("");
    setNewDesc("");
    onSetCreated?.(r.data.id);
    onChange(r.data.id);
  }

  return (
    <>
      <SearchableSelect
        items={items}
        value={value}
        onChange={onChange}
        placeholder="── 不屬於套票 ──"
        searchPlaceholder="搜尋套票…"
        emptyText="找不到符合的套票"
        disabled={disabled}
        footer={(close) => (
          <>
            <CommandItem
              value="__action_new_set__"
              keywords={["新增套票 new add"]}
              onSelect={() => {
                close();
                setCreateOpen(true);
              }}
              className="text-primary"
            >
              <PackagePlus className="mr-2 h-4 w-4" />
              <span>新增套票…</span>
            </CommandItem>
            <CommandItem
              value="__action_manage_sets__"
              keywords={["管理 manage sets edit delete"]}
              onSelect={() => {
                close();
                // Hard navigation — keeps the user's current form state
                // safe (Next preserves popovers' parent state on
                // back-nav, but just in case admin returns via /sets→
                // back, the form is rehydrated by RHF defaults).
                window.location.href = "/sets";
              }}
            >
              <Settings className="mr-2 h-4 w-4" />
              <span>管理套票（重新命名 / 刪除）…</span>
            </CommandItem>
          </>
        )}
      />

      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>新增套票</DialogTitle>
            <DialogDescription>
              一個套票 = N 張一起發行的海報（影城套票、IG 活動組合、票券優惠等）。
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <label className="text-xs text-muted-foreground">
                套票名稱（必填）
              </label>
              <Input
                autoFocus
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="例：2024 麥可傑克森電影上映套票"
                disabled={submitting}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submitNewSet();
                  }
                }}
              />
            </div>
            <div className="space-y-1">
              <label className="text-xs text-muted-foreground">說明</label>
              <Textarea
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                placeholder="說明這個套票的活動內容"
                rows={2}
                disabled={submitting}
              />
            </div>
          </div>
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
              onClick={submitNewSet}
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
