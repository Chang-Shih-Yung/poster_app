"use client";

import * as React from "react";
import { Pencil, Trash2, Tag, Loader2 } from "lucide-react";
import TreeShell from "../../_components/TreeShell";
import TreeRow from "../../_components/TreeRow";
import FAB from "../../_components/FAB";
import { FormSheet } from "../../_components/FormSheet";
import {
  ItemActionsBundle,
  type ItemAction,
} from "../../_components/ItemActionsBundle";
import { NULL_STUDIO_KEY } from "@/lib/keys";
import { WORK_KINDS } from "@/lib/enums";
import { useTransitionAction } from "@/lib/clientActions";
import { Button } from "@/components/ui/button";
import {
  renameWork,
  changeWorkKind,
  deleteWork,
  createWork,
  loadWorksPage,
} from "@/app/actions/works";

type Work = {
  id: string;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  poster_count: number;
  placeholder_count: number;
  studio: string | null;
  created_at?: string;
};

const WORK_KIND_OPTIONS = WORK_KINDS.map((k) => ({
  value: k.value,
  label: k.label,
}));

const WORK_ACTIONS: ItemAction<Work>[] = [
  {
    kind: "form",
    icon: <Pencil className="w-4 h-4" />,
    label: "重新命名作品",
    formTitle: "重新命名作品",
    submitLabel: "儲存",
    fields: (w) => [
      {
        key: "name",
        kind: "text",
        label: "中文名稱",
        placeholder: "作品中文名",
        required: true,
        initialValue: w.title_zh,
      },
    ],
    run: (w, values) => renameWork(w.id, values.name),
  },
  {
    kind: "form",
    icon: <Tag className="w-4 h-4" />,
    label: "變更類型",
    formTitle: "變更作品類型",
    submitLabel: "儲存",
    fields: (w) => [
      {
        key: "kind",
        kind: "select",
        label: "類型",
        options: WORK_KIND_OPTIONS,
        initialValue: w.work_kind,
      },
    ],
    run: (w, values) => changeWorkKind(w.id, values.kind),
  },
  {
    kind: "instant",
    icon: <Trash2 className="w-4 h-4" />,
    label: "刪除作品",
    hint: "底下的群組與海報全部一併刪除",
    destructive: true,
    confirm: (w) =>
      `刪除作品「${w.title_zh}」？\n底下的所有群組跟海報都會一起被刪除（${w.poster_count} 張海報）。\n此操作不可復原。`,
    run: (w) => deleteWork(w.id),
  },
];

export default function StudioClient({
  studio,
  works: initial,
  initialCursor,
  nav,
}: {
  studio: string;
  works: Work[];
  initialCursor?: string | null;
  nav?: React.ReactNode;
}) {
  const [rows, setRows] = React.useState<Work[]>(initial);
  const [cursor, setCursor] = React.useState<string | null>(
    initialCursor ?? null
  );
  const [activeWork, setActiveWork] = React.useState<Work | null>(null);
  const [addOpen, setAddOpen] = React.useState(false);
  const [loadingMore, setLoadingMore] = React.useState(false);
  const [loadError, setLoadError] = React.useState<string | null>(null);
  const { runFormAction } = useTransitionAction();

  // Reset accumulator when the server pushes a fresh batch (after a
  // mutation revalidates).
  React.useEffect(() => {
    setRows(initial);
    setCursor(initialCursor ?? null);
  }, [initial, initialCursor]);

  function loadMore() {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    setLoadError(null);
    (async () => {
      const r = await loadWorksPage({
        cursor,
        studio: studio === NULL_STUDIO_KEY ? null : studio,
      });
      if (!r.ok) {
        setLoadError(r.error);
      } else {
        // Map the action's WorkRow shape (minimal subset) into the
        // local Work shape used by this list.
        setRows((prev) => [
          ...prev,
          ...r.data.rows.map((w) => ({
            id: w.id,
            title_zh: w.title_zh,
            title_en: w.title_en,
            work_kind: w.work_kind,
            poster_count: w.poster_count,
            placeholder_count: w.placeholder_count,
            studio: w.studio,
            created_at: w.created_at,
          })),
        ]);
        setCursor(r.data.nextCursor);
      }
      setLoadingMore(false);
    })();
  }

  const totalPosters = rows.reduce((acc, w) => acc + w.poster_count, 0);
  const totalPlaceholders = rows.reduce((acc, w) => acc + w.placeholder_count, 0);

  return (
    <TreeShell
      nav={nav}
      back={{ href: "/tree", label: "目錄" }}
      title={studio}
      subtitle={[
        `${rows.length} 部作品${cursor ? "（還有更多）" : ""}`,
        `${totalPosters} 張海報`,
        totalPlaceholders > 0 ? `${totalPlaceholders} 待補圖` : null,
      ]
        .filter(Boolean)
        .join(" · ")}
      fab={<FAB onClick={() => setAddOpen(true)} label="新增作品" />}
    >
      {rows.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          這個分類底下還沒有作品。點右下的 + 開始建立。
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((w) => {
            const kindLabel =
              WORK_KINDS.find((k) => k.value === w.work_kind)?.label ?? w.work_kind;
            return (
              <TreeRow
                key={w.id}
                kind="folder"
                href={`/tree/work/${w.id}`}
                title={w.title_zh}
                subtitle={[
                  w.title_en,
                  w.placeholder_count > 0
                    ? `${w.placeholder_count} 待補圖`
                    : null,
                ]
                  .filter(Boolean)
                  .join(" · ") || undefined}
                count={w.poster_count}
                countLabel="張海報"
                badge={kindLabel}
                onMore={() => setActiveWork(w)}
              />
            );
          })}
        </ul>
      )}

      <ItemActionsBundle<Work>
        item={activeWork}
        onClose={() => setActiveWork(null)}
        title={activeWork?.title_zh ?? ""}
        description={
          activeWork
            ? [
                `${activeWork.poster_count} 張海報`,
                activeWork.placeholder_count > 0
                  ? `${activeWork.placeholder_count} 待補圖`
                  : null,
              ]
                .filter(Boolean)
                .join(" · ")
            : undefined
        }
        actions={WORK_ACTIONS}
      />

      <FormSheet
        open={addOpen}
        onOpenChange={setAddOpen}
        title="新增作品"
        description={`會建立在「${studio}」分類底下。`}
        fields={[
          {
            key: "title",
            kind: "text",
            label: "中文名稱",
            placeholder: "例：神隱少女",
            required: true,
          },
          {
            key: "kind",
            kind: "select",
            label: "類型",
            options: WORK_KIND_OPTIONS,
            initialValue: "movie",
          },
        ]}
        submitLabel="新增"
        onSubmit={(values) =>
          runFormAction(
            () =>
              createWork({
                title_zh: values.title,
                studio: studio === NULL_STUDIO_KEY ? null : studio,
                work_kind: values.kind || "movie",
              }),
            () => setAddOpen(false)
          )
        }
      />

      {cursor && (
        <div className="flex justify-center py-6">
          <Button
            variant="outline"
            onClick={loadMore}
            disabled={loadingMore}
          >
            {loadingMore && <Loader2 className="animate-spin" />}
            {loadingMore ? "載入中…" : "載入更多"}
          </Button>
        </div>
      )}

      {loadError && (
        <div className="text-center py-3 text-sm text-destructive">
          載入失敗：{loadError}
        </div>
      )}
    </TreeShell>
  );
}
