"use client";

import * as React from "react";
import { Pencil, Trash2, FolderPlus } from "lucide-react";
import TreeShell from "./_components/TreeShell";
import TreeRow from "./_components/TreeRow";
import FAB from "./_components/FAB";
import { FormSheet } from "./_components/FormSheet";
import { ItemActionsBundle, type ItemAction } from "./_components/ItemActionsBundle";
import { NULL_STUDIO_KEY, encodeStudioParam } from "@/lib/keys";
import { WORK_KINDS } from "@/lib/enums";
import { useTransitionAction } from "@/lib/clientActions";
import {
  renameStudio,
  deleteStudio,
  createWork,
} from "@/app/actions/works";

type Studio = { studio: string; works: number; posters: number };

const STUDIO_ACTIONS: ItemAction<Studio>[] = [
  {
    kind: "form",
    icon: <Pencil className="w-4 h-4" />,
    label: "重新命名分類",
    hint: "會把這個分類底下所有作品的 studio 改成新名字",
    formTitle: "重新命名分類",
    formDescription: "會更新所有屬於這個分類的作品。",
    submitLabel: "儲存",
    fields: (s) => [
      {
        key: "name",
        kind: "text",
        label: "新分類名稱",
        placeholder: "例：吉卜力",
        required: true,
        initialValue: s.studio === NULL_STUDIO_KEY ? "" : s.studio,
      },
    ],
    run: (s, values) => renameStudio(s.studio, values.name),
  },
  {
    kind: "instant",
    icon: <Trash2 className="w-4 h-4" />,
    label: "刪除整個分類",
    hint: "底下作品與海報全部一併刪除",
    destructive: true,
    disabled: false, // overridden per-item below
    confirm: (s) =>
      `刪除分類「${s.studio}」？\n底下 ${s.works} 部作品、${s.posters} 張海報全部會被刪除。\n此操作不可復原。`,
    run: (s) => deleteStudio(s.studio),
  },
];

export default function StudiosClient({
  studios,
  nav,
}: {
  studios: Studio[];
  nav?: React.ReactNode;
}) {
  const [activeStudio, setActiveStudio] = React.useState<Studio | null>(null);
  const [addOpen, setAddOpen] = React.useState(false);
  const { runFormAction } = useTransitionAction();

  // The "delete (未分類)" action is disabled — it's a synthetic
  // bucket, deleting it doesn't make sense at the data layer.
  const actionsForCurrent: ItemAction<Studio>[] = STUDIO_ACTIONS.map((a) =>
    a.kind === "instant" && a.label === "刪除整個分類"
      ? { ...a, disabled: activeStudio?.studio === NULL_STUDIO_KEY }
      : a
  );

  return (
    <TreeShell
      nav={nav}
      back={null}
      title="目錄"
      subtitle={`${studios.length} 個分類`}
      fab={<FAB onClick={() => setAddOpen(true)} label="新增分類" />}
    >
      {studios.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          還沒有任何分類。點右下的 + 開始建立。
        </div>
      ) : (
        <ul className="space-y-2">
          {studios.map((s) => (
            <TreeRow
              key={s.studio}
              kind="folder"
              href={`/tree/studio/${encodeStudioParam(s.studio)}`}
              title={s.studio}
              count={s.works}
              countLabel="作品"
              subtitle={`${s.posters} 張海報`}
              onMore={() => setActiveStudio(s)}
            />
          ))}
        </ul>
      )}

      <ItemActionsBundle<Studio>
        item={activeStudio}
        onClose={() => setActiveStudio(null)}
        title={activeStudio?.studio ?? ""}
        description={
          activeStudio
            ? `${activeStudio.works} 部作品 · ${activeStudio.posters} 張海報`
            : undefined
        }
        actions={actionsForCurrent}
      />

      <FormSheet
        open={addOpen}
        onOpenChange={setAddOpen}
        title="新增分類"
        description="分類底下至少要有一部作品。建立分類時會同時建立第一個作品。"
        fields={[
          {
            key: "studio",
            kind: "text",
            label: "分類名稱",
            placeholder: "例：吉卜力、漫威、五月天",
            required: true,
          },
          {
            key: "title",
            kind: "text",
            label: "第一個作品",
            placeholder: "例：神隱少女",
            required: true,
          },
          {
            key: "kind",
            kind: "select",
            label: "類型",
            options: WORK_KINDS.map((k) => ({ value: k.value, label: k.label })),
            initialValue: "movie",
          },
        ]}
        submitLabel="建立分類 + 作品"
        onSubmit={(values) =>
          runFormAction(
            () =>
              createWork({
                title_zh: values.title,
                studio: values.studio,
                work_kind: values.kind || "movie",
              }),
            () => setAddOpen(false)
          )
        }
      />

      {studios.length === 0 && (
        <div className="mt-2 flex justify-center">
          <button
            onClick={() => setAddOpen(true)}
            className="inline-flex items-center gap-1.5 text-primary text-sm hover:no-underline"
          >
            <FolderPlus className="w-4 h-4" /> 新增第一個分類
          </button>
        </div>
      )}
    </TreeShell>
  );
}
