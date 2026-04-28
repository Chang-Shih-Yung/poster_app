"use client";

import * as React from "react";
import { Pencil, Trash2, Tag } from "lucide-react";
import TreeShell from "../../_components/TreeShell";
import TreeRow from "../../_components/TreeRow";
import FAB from "../../_components/FAB";
import { FormSheet } from "../../_components/FormSheet";
import {
  ItemActionsBundle,
  type ItemAction,
} from "../../_components/ItemActionsBundle";
import { NULL_STUDIO_KEY } from "../../_components/keys";
import { WORK_KINDS } from "@/lib/enums";
import { useTransitionAction } from "@/lib/clientActions";
import {
  renameWork,
  changeWorkKind,
  deleteWork,
  createWork,
} from "@/app/actions/works";

type Work = {
  id: string;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  poster_count: number;
  studio: string | null;
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
  works,
  nav,
}: {
  studio: string;
  works: Work[];
  nav?: React.ReactNode;
}) {
  const [activeWork, setActiveWork] = React.useState<Work | null>(null);
  const [addOpen, setAddOpen] = React.useState(false);
  const { runFormAction } = useTransitionAction();

  const totalPosters = works.reduce((acc, w) => acc + w.poster_count, 0);

  return (
    <TreeShell
      nav={nav}
      back={{ href: "/tree", label: "目錄" }}
      title={studio}
      subtitle={`${works.length} 部作品 · ${totalPosters} 張海報`}
      fab={<FAB onClick={() => setAddOpen(true)} label="新增作品" />}
    >
      {works.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          這個分類底下還沒有作品。點右下的 + 開始建立。
        </div>
      ) : (
        <ul className="space-y-2">
          {works.map((w) => {
            const kindLabel =
              WORK_KINDS.find((k) => k.value === w.work_kind)?.label ?? w.work_kind;
            return (
              <TreeRow
                key={w.id}
                kind="folder"
                href={`/tree/work/${w.id}`}
                title={w.title_zh}
                subtitle={w.title_en ?? undefined}
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
          activeWork ? `${activeWork.poster_count} 張海報` : undefined
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
    </TreeShell>
  );
}
