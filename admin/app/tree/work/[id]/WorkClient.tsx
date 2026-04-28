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
import { encodeStudioParam, NULL_STUDIO_KEY } from "../../_components/keys";
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
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
  attachImage,
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
  const [addPickerOpen, setAddPickerOpen] = React.useState(false);
  const [addGroupOpen, setAddGroupOpen] = React.useState(false);
  const [addPosterOpen, setAddPosterOpen] = React.useState(false);
  const { runFormAction } = useTransitionAction();

  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const uploadTargetRef = React.useRef<Poster | null>(null);

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
        // Trigger file picker; the actual upload + attachImage runs
        // in handleFile below. The action returns ok immediately —
        // the upload progress is its own UI.
        uploadTargetRef.current = p;
        fileInputRef.current?.click();
        return { ok: true, data: undefined };
      },
    },
    {
      kind: "instant",
      icon: <Trash2 className="w-4 h-4" />,
      label: "刪除海報",
      destructive: true,
      confirm: (p) => `刪除海報「${p.poster_name ?? "(未命名)"}」？此操作不可復原。`,
      run: (p) => deletePoster(p.id),
    },
  ];

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const target = uploadTargetRef.current;
    if (!file || !target) return;
    try {
      const result = await uploadPosterImage(file, target.id);
      const r = await attachImage(target.id, {
        poster_url: result.posterUrl,
        thumbnail_url: result.thumbnailUrl,
        blurhash: result.blurhash,
        image_size_bytes: result.imageSizeBytes,
      });
      if (!r.ok) throw new Error(r.error);
    } catch (err) {
      alert(describeError(err));
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = "";
      uploadTargetRef.current = null;
    }
  }

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
      fab={<FAB onClick={() => setAddPickerOpen(true)} label="新增" />}
    >
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleFile}
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
                title={it.data.poster_name ?? "(未命名)"}
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
        title={activePoster?.poster_name ?? "(未命名)"}
        description={
          activePoster?.is_placeholder ? "尚未上傳真實圖片" : "海報"
        }
        actions={posterActions}
      />

      {/* Add picker: a small Sheet that just chooses between
       * "new group" and "new poster". Each option triggers its own
       * FormSheet below. */}
      <Sheet open={addPickerOpen} onOpenChange={setAddPickerOpen}>
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
                  onClick: () => {
                    setAddPickerOpen(false);
                    setAddGroupOpen(true);
                  },
                },
                {
                  icon: <FilePlus2 className="w-4 h-4" />,
                  label: "新增海報",
                  hint: "直接掛在這個作品下，不放進群組",
                  onClick: () => {
                    setAddPickerOpen(false);
                    setAddPosterOpen(true);
                  },
                },
              ]}
            />
          </div>
        </SheetContent>
      </Sheet>

      <FormSheet
        open={addGroupOpen}
        onOpenChange={setAddGroupOpen}
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
            () => setAddGroupOpen(false)
          )
        }
      />

      <FormSheet
        open={addPosterOpen}
        onOpenChange={setAddPosterOpen}
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
            () => setAddPosterOpen(false)
          )
        }
      />
    </TreeShell>
  );
}
