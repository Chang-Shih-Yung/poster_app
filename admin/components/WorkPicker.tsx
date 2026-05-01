"use client";

import * as React from "react";
import { FilePlus, Loader2 } from "lucide-react";
import { toast } from "sonner";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { FormField } from "@/components/ui/form-field";
import { createWork } from "@/app/actions/works";
import { WORK_KINDS } from "@/lib/enums";

export type WorkOption = {
  id: string;
  title_zh: string;
  title_en: string | null;
  studio: string | null;
};

/**
 * Searchable dropdown for picking a work. Used in PosterForm and
 * BatchImport. Two key differences from a plain Select:
 *
 *   1. Search by title or studio — works with hundreds of rows on mobile.
 *   2. Inline "+ 新增作品…" dialog (mirrors GroupPicker) so admin can
 *      create a new work without leaving the poster form. The dialog
 *      collects 作品台灣官方名稱 + 作品英文官方名稱 (both required per
 *      partner spec) + optional 工作室 + 類型. On success the new work
 *      is auto-selected; the parent should refetch the works list via
 *      onWorkCreated.
 *
 * The trigger shows `[studio] title_zh` so the selection is unambiguous
 * even when two studios have works with the same title.
 */
export function WorkPicker({
  works,
  value,
  onChange,
  onWorkCreated,
  placeholder = "── 選擇作品 ──",
  disabled,
  triggerClassName,
}: {
  works: WorkOption[];
  value: string;
  onChange: (id: string) => void;
  /** Called after a new work is created so the parent can refetch the
   *  works list. The new work's id is also passed to onChange so it
   *  becomes the active selection. */
  onWorkCreated?: (newWorkId: string) => void;
  placeholder?: string;
  disabled?: boolean;
  triggerClassName?: string;
}) {
  const [createOpen, setCreateOpen] = React.useState(false);
  const [titleZh, setTitleZh] = React.useState("");
  const [titleEn, setTitleEn] = React.useState("");
  const [studio, setStudio] = React.useState("");
  const [workKind, setWorkKind] = React.useState<string>("movie");
  const [submitting, setSubmitting] = React.useState(false);

  const items: SearchableItem[] = works.map((w) => ({
    value: w.id,
    label: w.studio ? `[${w.studio}] ${w.title_zh}` : w.title_zh,
    // Search by both studio and title — admin types either to find a work.
    searchText: `${w.studio ?? ""} ${w.title_zh}`.trim(),
  }));

  function resetDialog() {
    setTitleZh("");
    setTitleEn("");
    setStudio("");
    setWorkKind("movie");
  }

  async function submitNewWork() {
    const zh = titleZh.trim();
    const en = titleEn.trim();
    if (!zh) {
      toast.error("作品台灣官方名稱必填");
      return;
    }
    if (!en) {
      toast.error("作品英文官方名稱必填");
      return;
    }
    setSubmitting(true);
    const r = await createWork({
      title_zh: zh,
      title_en: en,
      studio: studio.trim() || null,
      work_kind: workKind,
    });
    setSubmitting(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success(`已新增作品「${zh}」`);
    setCreateOpen(false);
    resetDialog();
    onWorkCreated?.(r.data.id);
    onChange(r.data.id);
  }

  return (
    <>
      <SearchableSelect
        items={items}
        value={value || null}
        onChange={onChange}
        placeholder={placeholder}
        searchPlaceholder="搜尋作品名稱或工作室…"
        emptyText="找不到符合的作品"
        disabled={disabled}
        triggerClassName={triggerClassName}
        // 500 rows is the comfort zone for cmdk + Popover on a mid-tier
        // mobile device. Beyond that admin should narrow with search.
        maxResults={500}
        footer={(close) => (
          <CommandItem
            value="__action_new_work__"
            keywords={["新增作品 new add"]}
            onSelect={() => {
              close();
              setCreateOpen(true);
            }}
            className="text-primary"
          >
            <FilePlus className="mr-2 h-4 w-4" />
            <span>新增作品…</span>
          </CommandItem>
        )}
      />

      <Dialog
        open={createOpen}
        onOpenChange={(v) => {
          setCreateOpen(v);
          if (!v) resetDialog();
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>新增作品</DialogTitle>
            <DialogDescription>
              一個作品（電影 / 演唱會 / 戲劇 / 展覽…）下面可以掛多張海報。建立後會自動選取，繼續填海報資料。
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <FormField label="作品台灣官方名稱" required>
              <Input
                autoFocus
                value={titleZh}
                onChange={(e) => setTitleZh(e.target.value)}
                placeholder="例：蒼鷺與少年"
                disabled={submitting}
              />
            </FormField>
            <FormField label="作品英文官方名稱" required>
              <Input
                value={titleEn}
                onChange={(e) => setTitleEn(e.target.value)}
                placeholder="例：The Boy and the Heron"
                disabled={submitting}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    submitNewWork();
                  }
                }}
              />
            </FormField>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="工作室 / IP 持有者">
                <Input
                  value={studio}
                  onChange={(e) => setStudio(e.target.value)}
                  placeholder="例：吉卜力"
                  disabled={submitting}
                />
              </FormField>
              <FormField label="類型">
                <Select
                  value={workKind}
                  onValueChange={setWorkKind}
                  disabled={submitting}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {WORK_KINDS.map((k) => (
                      <SelectItem key={k.value} value={k.value}>
                        {k.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </FormField>
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
              onClick={submitNewWork}
              disabled={submitting || !titleZh.trim() || !titleEn.trim()}
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
