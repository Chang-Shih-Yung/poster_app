"use client";

import * as React from "react";
import { Loader2, X, Search, ImageOff, Image as ImageIcon } from "lucide-react";
import { toast } from "sonner";
import {
  listSiblings,
  listAllPostersForPicker,
  linkPosters,
  unlinkPoster,
  type SiblingPoster,
} from "@/app/actions/poster-sets";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { UNNAMED_POSTER } from "@/lib/keys";

/**
 * Spec #14 —「海報發行組合」UX。Admin 不思考 set 物件，他思考的是
 * 「這張跟那張是一組」。這個元件把 sibling-shaped 的 mental model
 * 直接當主介面：
 *
 *   1. Toggle 是 / 否
 *   2. 是 → 跳出搜尋框 + 該海報目前的同組合夥伴 list
 *   3. 搜尋並挑一張海報 → 立刻送 server action linkPosters，連結進
 *      同 set（或自動建一個 set 把兩者放進去）
 *   4. 每個 sibling 旁邊有 × 可以單獨踢出
 *
 * 只在 mode="edit" 用。create mode（海報還沒 ID）不能掛 sibling，
 * 元件以唯讀提示「先建好海報才能加入組合」呈現，admin 建好回到編輯
 * 頁再加。
 */
export default function PosterCombinationField({
  posterId,
  disabled,
}: {
  /** null = create mode，元件會顯示 disabled 提示。 */
  posterId: string | null;
  disabled?: boolean;
}) {
  const isCreateMode = !posterId;

  const [siblings, setSiblings] = React.useState<SiblingPoster[]>([]);
  const [loaded, setLoaded] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  // toggle: 是（屬於組合）/ 否（單張）
  // 預設由 siblings.length > 0 推得，但 admin 可以手動把它打開準備加
  const [yesMode, setYesMode] = React.useState(false);

  const refresh = React.useCallback(async () => {
    if (!posterId) return;
    const r = await listSiblings(posterId);
    if (r.ok) {
      setSiblings(r.data);
      setLoaded(true);
      // 如果有 siblings，自動進入「是」模式
      if (r.data.length > 0) setYesMode(true);
    }
  }, [posterId]);

  React.useEffect(() => {
    if (posterId) void refresh();
  }, [posterId, refresh]);

  async function onAddSibling(siblingId: string) {
    if (!posterId) return;
    setBusy(true);
    const r = await linkPosters({
      poster_id: posterId,
      sibling_id: siblingId,
    });
    setBusy(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success("已加入組合");
    await refresh();
  }

  async function onRemoveSibling(siblingId: string) {
    setBusy(true);
    // 把對方踢出 set。對方那張 unlink 後，如果 set 只剩 self 一張，
    // server 會自動清理：self 也會 set_id = null + set 刪掉。
    const r = await unlinkPoster(siblingId);
    setBusy(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success("已從組合移除");
    await refresh();
  }

  async function onSetToNo() {
    if (!posterId || siblings.length === 0) {
      // 沒 sibling 直接收起來就好
      setYesMode(false);
      return;
    }
    if (
      !window.confirm(
        `這張海報目前跟 ${siblings.length} 張海報是同組合，切換到「否」會把這張踢出組合。確定？`
      )
    ) {
      return;
    }
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

      {/* 是模式：sibling list + picker */}
      {yesMode && (
        <>
          {loaded && siblings.length > 0 && (
            <div className="space-y-1.5">
              <div className="text-xs text-muted-foreground">
                同組合的海報（{siblings.length} 張）
              </div>
              <ul className="space-y-1">
                {siblings.map((s) => (
                  <SiblingRow
                    key={s.id}
                    sibling={s}
                    onRemove={() => onRemoveSibling(s.id)}
                    disabled={busy || disabled}
                  />
                ))}
              </ul>
            </div>
          )}

          <SiblingPicker
            posterId={posterId!}
            existingIds={new Set(siblings.map((s) => s.id))}
            onPick={onAddSibling}
            disabled={busy || disabled}
          />
        </>
      )}
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

function SiblingRow({
  sibling,
  onRemove,
  disabled,
}: {
  sibling: SiblingPoster;
  onRemove: () => void;
  disabled?: boolean;
}) {
  return (
    <li className="flex items-center gap-2 px-2 py-1.5 rounded-md border border-border bg-secondary/30">
      <Thumb url={sibling.thumbnail_url} />
      <div className="flex-1 min-w-0 text-sm">
        <div className="truncate text-foreground">
          {sibling.poster_name ?? UNNAMED_POSTER}
        </div>
        <div className="truncate text-xs text-muted-foreground">
          {sibling.work_title_zh ?? "—"}
        </div>
      </div>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        onClick={onRemove}
        disabled={disabled}
        className="h-7 w-7 text-muted-foreground hover:text-destructive"
        aria-label="從組合移除"
      >
        <X className="h-4 w-4" />
      </Button>
    </li>
  );
}

function Thumb({ url }: { url: string | null }) {
  if (url) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url}
        alt=""
        className="w-8 h-10 object-cover rounded border border-border shrink-0"
      />
    );
  }
  return (
    <span className="w-8 h-10 flex items-center justify-center rounded bg-muted text-muted-foreground border border-border shrink-0">
      <ImageOff className="w-3.5 h-3.5" />
    </span>
  );
}

/**
 * Inline searchable picker. Loads all posters once via server action,
 * filters in-memory by name / work title. Click a row to add as sibling.
 */
function SiblingPicker({
  posterId,
  existingIds,
  onPick,
  disabled,
}: {
  posterId: string;
  existingIds: Set<string>;
  onPick: (id: string) => void;
  disabled?: boolean;
}) {
  const [pool, setPool] = React.useState<SiblingPoster[]>([]);
  const [poolLoaded, setPoolLoaded] = React.useState(false);
  const [query, setQuery] = React.useState("");

  React.useEffect(() => {
    let cancelled = false;
    (async () => {
      const r = await listAllPostersForPicker(posterId);
      if (!cancelled && r.ok) {
        setPool(r.data);
        setPoolLoaded(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [posterId]);

  const q = query.trim().toLowerCase();
  const filtered = React.useMemo(() => {
    let list = pool.filter((p) => !existingIds.has(p.id));
    if (q) {
      list = list.filter(
        (p) =>
          (p.poster_name ?? "").toLowerCase().includes(q) ||
          (p.work_title_zh ?? "").toLowerCase().includes(q)
      );
    }
    return list.slice(0, 30); // cap render — 大量 list 會卡
  }, [pool, existingIds, q]);

  return (
    <div className="space-y-2">
      <div className="text-xs text-muted-foreground">加入同組合的海報</div>
      <div className="relative">
        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground pointer-events-none" />
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="搜尋海報名稱或作品…"
          className="pl-8 h-9"
          disabled={disabled}
        />
      </div>
      {!poolLoaded ? (
        <div className="flex items-center gap-2 text-xs text-muted-foreground py-2">
          <Loader2 className="w-3.5 h-3.5 animate-spin" />
          載入海報清單中…
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-xs text-muted-foreground py-2">
          {q ? `找不到符合「${query}」的海報` : "沒有可加入的海報"}
        </div>
      ) : (
        <ul className="max-h-64 overflow-y-auto space-y-1 rounded-md border border-border p-1">
          {filtered.map((p) => (
            <li key={p.id}>
              <button
                type="button"
                onClick={() => onPick(p.id)}
                disabled={disabled}
                className="w-full flex items-center gap-2 px-2 py-1.5 rounded text-left hover:bg-secondary/60 disabled:opacity-60 transition-colors"
              >
                {p.thumbnail_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={p.thumbnail_url}
                    alt=""
                    className="w-8 h-10 object-cover rounded border border-border shrink-0"
                  />
                ) : (
                  <span className="w-8 h-10 flex items-center justify-center rounded bg-muted text-muted-foreground border border-border shrink-0">
                    <ImageIcon className="w-3.5 h-3.5" />
                  </span>
                )}
                <div className="flex-1 min-w-0 text-sm">
                  <div className="truncate text-foreground">
                    {p.poster_name ?? UNNAMED_POSTER}
                  </div>
                  <div className="truncate text-xs text-muted-foreground">
                    {p.work_title_zh ?? "—"}
                  </div>
                </div>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
