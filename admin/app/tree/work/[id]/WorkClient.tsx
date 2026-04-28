"use client";

import * as React from "react";
import { Pencil, Trash2, FolderPlus, FilePlus2, ImagePlus } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import TreeShell from "../../_components/TreeShell";
import TreeRow from "../../_components/TreeRow";
import { SheetMenuList } from "../../_components/SheetMenu";
import FAB from "../../_components/FAB";
import { FormSheet } from "../../_components/FormSheet";
import {
  ItemActionsBundle,
  type ItemAction,
} from "../../_components/ItemActionsBundle";
import { useAddSheets } from "../../_components/useAddSheets";
import { useImageAttach } from "../../_components/useImageAttach";
import { encodeStudioParam, NULL_STUDIO_KEY, UNNAMED_POSTER } from "@/lib/keys";
import { useTransitionAction } from "@/lib/clientActions";
import {
  createGroup,
  renameGroup,
  deleteGroup,
} from "@/app/actions/groups";
import {
  createPoster,
  renamePoster,
  deletePoster,
} from "@/app/actions/posters";

type WorkInfo = {
  id: string;
  title_zh: string;
  studio: string | null;
  work_kind: string;
};

type Group = {
  id: string;
  name: string;
  group_type: string | null;
  child_count: number;
};

type Poster = {
  id: string;
  poster_name: string | null;
  is_placeholder: boolean;
  thumbnail_url: string | null;
};

const groupActions: ItemAction<Group>[] = [
  {
    kind: "form",
    icon: <Pencil className="w-4 h-4" />,
    label: "重新命名群組",
    formTitle: "重新命名群組",
    submitLabel: "儲存",
    fields: (g) => [
      {
        key: "name",
        kind: "text",
        label: "群組名稱",
        required: true,
        initialValue: g.name,
      },
    ],
    run: (g, values) => renameGroup(g.id, values.name),
  },
  {
    kind: "instant",
    icon: <Trash2 className="w-4 h-4" />,
    label: "刪除群組",
    hint: "海報會被丟回上一層，不會被刪除",
    destructive: true,
    confirm: (g) =>
      `刪除群組「${g.name}」？\n子群組會一併消失，群組內的海報會被丟回上一層（海報本身不刪）。`,
    run: (g) => deleteGroup(g.id),
  },
];

export default function WorkClient({
  work,
  groups,
  posters,
  nav,
}: {
  work: WorkInfo;
  groups: Group[];
  posters: Poster[];
  nav?: React.ReactNode;
}) {
  const [activeGroup, setActiveGroup] = React.useState<Group | null>(null);
  const [activePoster, setActivePoster] = React.useState<Poster | null>(null);
  const addSheets = useAddSheets<"group" | "poster">();
  const image = useImageAttach();
  const { runFormAction } = useTransitionAction();

  // Poster actions reference `image.pickFor` so they have to live
  // inside the component body, not module scope.
  const posterActions: ItemAction<Poster>[] = [
    {
      kind: "form",
      icon: <Pencil className="w-4 h-4" />,
      label: "重新命名海報",
      formTitle: "重新命名海報",
      submitLabel: "儲存",
      fields: (p) => [
        {
          key: "name",
          kind: "text",
          label: "海報名稱",
          placeholder: "例：B1 原版",
          required: true,
          initialValue: p.poster_name ?? "",
        },
      ],
      run: (p, values) => renamePoster(p.id, values.name),
    },
    {
      kind: "instant",
      icon: <ImagePlus className="w-4 h-4" />,
      label: "上傳 / 更換圖片",
      hint: "選一張新圖，覆蓋既有海報",
      run: async (p) => {
        image.pickFor(p);
        return { ok: true, data: undefined };
      },
    },
    {
      kind: "instant",
      icon: <Trash2 className="w-4 h-4" />,
      label: "刪除海報",
      destructive: true,
      confirm: (p) =>
        `刪除海報「${p.poster_name ?? UNNAMED_POSTER}」？此操作不可復原。`,
      run: (p) => deletePoster(p.id),
    },
  ];

  const items = [
    ...groups.map((g) => ({ kind: "group" as const, data: g })),
    ...posters.map((p) => ({ kind: "poster" as const, data: p })),
  ];

  const studioKey = work.studio ?? NULL_STUDIO_KEY;

  return (
    <TreeShell
      nav={nav}
      back={{
        href: `/tree/studio/${encodeStudioParam(studioKey)}`,
        label: studioKey,
      }}
      title={work.title_zh}
      subtitle={`${groups.length} 個群組 · ${posters.length} 張直屬海報`}
      fab={<FAB onClick={addSheets.openPicker} label="新增" />}
    >
      <input
        ref={image.fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={image.handleFile}
      />
      {items.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          這個作品還沒有任何群組或海報。
        </div>
      ) : (
        <ul className="space-y-2">
          {items.map((it) =>
            it.kind === "group" ? (
              <TreeRow
                key={`g:${it.data.id}`}
                kind="folder"
                href={`/tree/group/${it.data.id}`}
                title={it.data.name}
                subtitle={it.data.group_type ?? undefined}
                count={it.data.child_count}
                countLabel="張海報"
                onMore={() => setActiveGroup(it.data)}
              />
            ) : (
              <TreeRow
                key={`p:${it.data.id}`}
                kind="poster"
                href={`/posters/${it.data.id}`}
                thumbnailUrl={it.data.thumbnail_url}
                title={it.data.poster_name ?? UNNAMED_POSTER}
                placeholder={it.data.is_placeholder}
                onMore={() => setActivePoster(it.data)}
              />
            )
          )}
        </ul>
      )}

      <ItemActionsBundle<Group>
        item={activeGroup}
        onClose={() => setActiveGroup(null)}
        title={activeGroup?.name ?? ""}
        description={
          activeGroup ? `${activeGroup.child_count} 張海報` : undefined
        }
        actions={groupActions}
      />

      <ItemActionsBundle<Poster>
        item={activePoster}
        onClose={() => setActivePoster(null)}
        title={activePoster?.poster_name ?? UNNAMED_POSTER}
        description={
          activePoster?.is_placeholder ? "尚未上傳真實圖片" : "海報"
        }
        actions={posterActions}
      />

      {/* Picker: choose group vs poster, then dispatch into FormSheet */}
      <Sheet open={addSheets.pickerOpen} onOpenChange={addSheets.setPickerOpen}>
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle>新增到「{work.title_zh}」</SheetTitle>
            <SheetDescription>選擇要新增的類型</SheetDescription>
          </SheetHeader>
          <div className="mt-3">
            <SheetMenuList
              items={[
                {
                  icon: <FolderPlus className="w-4 h-4" />,
                  label: "新增群組（資料夾）",
                  hint: "可以再往下分層，例如「2024 國際版」",
                  onClick: () => addSheets.openForm("group"),
                },
                {
                  icon: <FilePlus2 className="w-4 h-4" />,
                  label: "新增海報",
                  hint: "直接掛在這個作品下，不放進群組",
                  onClick: () => addSheets.openForm("poster"),
                },
              ]}
            />
          </div>
        </SheetContent>
      </Sheet>

      <FormSheet
        open={addSheets.formKind === "group"}
        onOpenChange={addSheets.setFormOpen("group")}
        title="新增群組"
        description={`會建在「${work.title_zh}」底下。`}
        fields={[
          {
            key: "name",
            kind: "text",
            label: "群組名稱",
            placeholder: "例：2024 國際版",
            required: true,
          },
        ]}
        submitLabel="新增"
        onSubmit={(values) =>
          runFormAction(
            () =>
              createGroup({
                work_id: work.id,
                parent_group_id: null,
                name: values.name,
              }),
            addSheets.close
          )
        }
      />

      <FormSheet
        open={addSheets.formKind === "poster"}
        onOpenChange={addSheets.setFormOpen("poster")}
        title="新增海報"
        description={`會直屬於「${work.title_zh}」（不放在群組裡）。`}
        fields={[
          {
            key: "name",
            kind: "text",
            label: "海報名稱",
            placeholder: "例：B1 原版",
            required: true,
          },
        ]}
        submitLabel="新增"
        onSubmit={(values) =>
          runFormAction(
            () =>
              createPoster({
                work_id: work.id,
                parent_group_id: null,
                poster_name: values.name,
              }),
            addSheets.close
          )
        }
      />
    </TreeShell>
  );
}
