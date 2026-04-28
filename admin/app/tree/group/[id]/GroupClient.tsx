"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
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

type GroupInfo = {
  id: string;
  name: string;
  group_type: string | null;
  work_id: string;
  parent_group_id: string | null;
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

const childGroupActions: ItemAction<Group>[] = [
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

export default function GroupClient({
  group,
  back,
  groups,
  posters,
  nav,
}: {
  group: GroupInfo;
  back: { href: string; label: string };
  groups: Group[];
  posters: Poster[];
  nav?: React.ReactNode;
}) {
  const router = useRouter();
  const [activeGroup, setActiveGroup] = React.useState<Group | null>(null);
  const [activePoster, setActivePoster] = React.useState<Poster | null>(null);
  const [selfActive, setSelfActive] = React.useState(false);
  const [addPickerOpen, setAddPickerOpen] = React.useState(false);
  const [addGroupOpen, setAddGroupOpen] = React.useState(false);
  const [addPosterOpen, setAddPosterOpen] = React.useState(false);
  const { runFormAction, runAction } = useTransitionAction();

  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const uploadTargetRef = React.useRef<Poster | null>(null);

  // "Edit this group" actions — reuse the child-group action descriptors
  // but with a custom delete that navigates back after success (the
  // current URL would 404 once the group is gone).
  const selfActions: ItemAction<GroupInfo>[] = [
    {
      kind: "form",
      icon: <Pencil className="w-4 h-4" />,
      label: "重新命名群組",
      formTitle: `重新命名「${group.name}」`,
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
      hint: "海報會被丟回上一層",
      destructive: true,
      confirm: (g) =>
        `刪除群組「${g.name}」？\n子群組會一併消失，群組內的海報會被丟回上一層（海報本身不刪）。`,
      run: async (g) => {
        const r = await deleteGroup(g.id);
        if (r.ok) router.push(back.href);
        return r;
      },
    },
  ];

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

  // Suppress unused warning; runAction is part of useTransitionAction's
  // contract — kept for future use cases.
  void runAction;

  const items = [
    ...groups.map((g) => ({ kind: "group" as const, data: g })),
    ...posters.map((p) => ({ kind: "poster" as const, data: p })),
  ];

  return (
    <TreeShell
      nav={nav}
      back={back}
      title={group.name}
      subtitle={`${groups.length} 個子群組 · ${posters.length} 張直屬海報`}
      fab={<FAB onClick={() => setAddPickerOpen(true)} label="新增" />}
    >
      <div className="flex justify-end mb-2">
        <button
          onClick={() => setSelfActive(true)}
          className="text-xs text-muted-foreground hover:text-foreground inline-flex items-center gap-1"
        >
          <Pencil className="w-3 h-3" /> 編輯此群組
        </button>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleFile}
      />
      {items.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          這個群組還是空的。
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

      <ItemActionsBundle<GroupInfo>
        item={selfActive ? group : null}
        onClose={() => setSelfActive(false)}
        title={group.name}
        description="對這個群組本身做動作"
        actions={selfActions}
      />

      <ItemActionsBundle<Group>
        item={activeGroup}
        onClose={() => setActiveGroup(null)}
        title={activeGroup?.name ?? ""}
        description={
          activeGroup ? `${activeGroup.child_count} 張海報` : undefined
        }
        actions={childGroupActions}
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

      <Sheet open={addPickerOpen} onOpenChange={setAddPickerOpen}>
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle>新增到「{group.name}」</SheetTitle>
            <SheetDescription>選擇要新增的類型</SheetDescription>
          </SheetHeader>
          <div className="mt-3">
            <SheetMenuList
              items={[
                {
                  icon: <FolderPlus className="w-4 h-4" />,
                  label: "新增子群組（資料夾）",
                  hint: "可以再往下分層",
                  onClick: () => {
                    setAddPickerOpen(false);
                    setAddGroupOpen(true);
                  },
                },
                {
                  icon: <FilePlus2 className="w-4 h-4" />,
                  label: "新增海報",
                  hint: "直接放在這個群組裡",
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
        title="新增子群組"
        description={`會建在「${group.name}」底下。`}
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
                work_id: group.work_id,
                parent_group_id: group.id,
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
        description={`會放在「${group.name}」群組裡。`}
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
                work_id: group.work_id,
                parent_group_id: group.id,
                poster_name: values.name,
              }),
            () => setAddPosterOpen(false)
          )
        }
      />
    </TreeShell>
  );
}
