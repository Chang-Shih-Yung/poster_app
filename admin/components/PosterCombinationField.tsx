"use client";

import * as React from "react";
import { toast } from "sonner";
import {
  listSiblings,
  listAllPostersForPicker,
  linkPosters,
  unlinkPoster,
  type SiblingPoster,
} from "@/app/actions/poster-sets";
import {
  MultiSelectDropdown,
  type MultiSelectItem,
} from "@/components/ui/multi-select";
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
import { UNNAMED_POSTER } from "@/lib/keys";

/**
 * Spec #14 —「海報發行組合」UX。Admin 的心智模型：「這張跟那幾張是
 * 一組」，不思考 set 物件。元件用 MultiSelectDropdown（跟「發行類型」
 * cinema_release_types 同款）讓 admin 一次挑多張同組合的海報；後端
 * 用 poster_sets 表當底層存儲，自動 union/cleanup（admin 看不到 set）。
 *
 * UX 流程：
 *   1. 「是 / 否」toggle button
 *   2. 是 → 跳出 MultiSelectDropdown 含 search、checkbox、badge 顯示已選
 *   3. 勾／取消勾 → onChange diff → linkPosters / unlinkPoster (sequential
 *      避免多筆同時建 set 的 race)
 *   4. 切回「否」→ unlinkPoster(self)，整張海報退出組合
 *
 * Create mode（posterId=null）看不到 picker，秀提示「建立後回編輯頁」。
 */
export default function PosterCombinationField({
  posterId,
  disabled,
}: {
  /** null = create mode；元件顯示 disabled 提示。 */
  posterId: string | null;
  disabled?: boolean;
}) {
  const isCreateMode = !posterId;

  const [siblings, setSiblings] = React.useState<SiblingPoster[]>([]);
  const [pool, setPool] = React.useState<SiblingPoster[]>([]);
  const [busy, setBusy] = React.useState(false);
  const [yesMode, setYesMode] = React.useState(false);
  // AlertDialog 二次確認 state — 跟「砍 group / 砍分類」其他破壞性動作
  // 用同款 shadcn 對話框，不再用瀏覽器原生 window.confirm（iOS Safari
  // PWA 模式下會被無聲忽略）。
  const [confirmRemoveSelfOpen, setConfirmRemoveSelfOpen] = React.useState(false);

  const refresh = React.useCallback(async () => {
    if (!posterId) return;
    const r = await listSiblings(posterId);
    if (r.ok) {
      setSiblings(r.data);
      if (r.data.length > 0) setYesMode(true);
    }
  }, [posterId]);

  // Initial load — siblings + pool of all posters for the picker
  React.useEffect(() => {
    if (!posterId) return;
    void refresh();
    void (async () => {
      const r = await listAllPostersForPicker(posterId);
      if (r.ok) setPool(r.data);
    })();
  }, [posterId, refresh]);

  /** Sync siblings to a new selected-id list. Diff added vs removed,
   *  call linkPosters / unlinkPoster sequentially. Sequential matters:
   *  the first link may create the set; subsequent links rely on
   *  self.set_id being populated to merge into the same set. */
  async function applySelection(newIds: string[]) {
    if (!posterId) return;
    const oldIds = siblings.map((s) => s.id);
    const added = newIds.filter((id) => !oldIds.includes(id));
    const removed = oldIds.filter((id) => !newIds.includes(id));
    if (added.length === 0 && removed.length === 0) return;

    setBusy(true);
    let okCount = 0;
    let firstError: string | null = null;
    for (const id of added) {
      const r = await linkPosters({ poster_id: posterId, sibling_id: id });
      if (r.ok) okCount++;
      else if (!firstError) firstError = r.error;
    }
    for (const id of removed) {
      const r = await unlinkPoster(id);
      if (r.ok) okCount++;
      else if (!firstError) firstError = r.error;
    }
    setBusy(false);

    if (firstError) {
      toast.error(firstError);
    } else if (added.length > 0 && removed.length > 0) {
      toast.success(`已加入 ${added.length} 張、移除 ${removed.length} 張`);
    } else if (added.length > 0) {
      toast.success(`已加入 ${added.length} 張到組合`);
    } else if (removed.length > 0) {
      toast.success(`已移除 ${removed.length} 張`);
    }
    await refresh();
  }

  /** 「否」按下：沒 sibling 就直接切；有就 open 二次確認對話框。 */
  function onSetToNo() {
    if (!posterId || siblings.length === 0) {
      setYesMode(false);
      return;
    }
    setConfirmRemoveSelfOpen(true);
  }

  /** AlertDialog 確認後的實際移除動作。 */
  async function confirmRemoveSelf() {
    setConfirmRemoveSelfOpen(false);
    if (!posterId) return;
    setBusy(true);
    const r = await unlinkPoster(posterId);
    setBusy(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success("已從組合移除");
    setYesMode(false);
    await refresh();
  }

  if (isCreateMode) {
    return (
      <div className="text-sm text-muted-foreground rounded-md border border-dashed border-input bg-secondary/30 p-3">
        建立海報後，回到編輯頁就能在這裡加入「同組合的其他海報」。
      </div>
    );
  }

  // Items for MultiSelectDropdown — show "name · work" so admin can
  // disambiguate two posters with the same name across different works.
  const items: MultiSelectItem[] = pool.map((p) => ({
    value: p.id,
    label: `${p.poster_name ?? UNNAMED_POSTER}${
      p.work_title_zh ? ` · ${p.work_title_zh}` : ""
    }`,
  }));
  const value = siblings.map((s) => s.id);

  return (
    <div className="space-y-3">
      {/* 是 / 否 toggle */}
      <div className="flex items-center gap-2">
        <ToggleButton
          active={!yesMode}
          onClick={() => onSetToNo()}
          disabled={busy || disabled}
        >
          否（單張）
        </ToggleButton>
        <ToggleButton
          active={yesMode}
          onClick={() => setYesMode(true)}
          disabled={busy || disabled}
        >
          是（屬於組合）
        </ToggleButton>
      </div>

      {/* 是 → 多選下拉（跟發行類型同款 MultiSelectDropdown） */}
      {yesMode && (
        <MultiSelectDropdown
          items={items}
          value={value}
          onChange={applySelection}
          placeholder="選擇同組合的海報…（可複選）"
          searchPlaceholder="搜尋海報名稱或作品…"
          emptyText="找不到符合的海報"
          disabled={busy || disabled}
        />
      )}

      {/* 切到「否」+ 已有 sibling → AlertDialog 二次確認 */}
      <AlertDialog
        open={confirmRemoveSelfOpen}
        onOpenChange={setConfirmRemoveSelfOpen}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>從組合移除這張海報？</AlertDialogTitle>
            <AlertDialogDescription>
              {`這張海報目前跟 ${siblings.length} 張海報是同組合，切換到「否」會把這張踢出組合。`}
              其他海報的組合不受影響；如果剩下不足 2 張，整個組合會自動解散。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmRemoveSelf}
            >
              確認移除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function ToggleButton({
  active,
  onClick,
  disabled,
  children,
}: {
  active: boolean;
  onClick: () => void;
  disabled?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={
        "px-3 py-1.5 text-sm rounded-md border transition-colors " +
        (active
          ? "bg-primary text-primary-foreground border-primary"
          : "bg-background text-foreground border-input hover:bg-secondary/60")
      }
    >
      {children}
    </button>
  );
}
