"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, FolderPlus, FilePlus2, ImagePlus } from "lucide-react";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import TreeShell from "../../_components/TreeShell";
import DndTreeList, { type DndGroup, type DndPoster } from "../../_components/DndTreeList";
import { SheetMenuList } from "../../_components/SheetMenu";
import FAB from "../../_components/FAB";
import { FormSheet } from "../../_components/FormSheet";
import {
  ItemActionsBundle,
  type ItemAction,
} from "../../_components/ItemActionsBundle";
import { useAddSheets } from "../../_components/useAddSheets";
import { useImageAttach } from "../../_components/useImageAttach";
import { UNNAMED_POSTER } from "@/lib/keys";
import { useTransitionAction } from "@/lib/clientActions";
import {
  createGroup,
  renameGroup,
  deleteGroup,
  moveGroup,
} from "@/app/actions/groups";
import {
  createPoster,
  renamePoster,
  deletePoster,
  movePoster,
} from "@/app/actions/posters";

type GroupInfo = {
  id: string;
  name: string;
  group_type: string | null;
  work_id: string;
  parent_group_id: string | null;
};

type Group = DndGroup;
type Poster = DndPoster;

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
    hint: "海報會回到作品頂層，不會被刪除",
    destructive: true,
    confirm: (g) =>
      `刪除群組「${g.name}」？\n子群組會一併消失，群組內的海報會回到作品頂層（不放進任何群組），海報本身不刪。`,
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
  const [filter, setFilter] = React.useState("");

  // After a successful upload, navigate to the next placeholder in this group.
  function handleUploadSuccess(uploadedId: string) {
    const nextPlaceholder = posters.find(
      (p) => p.id !== uploadedId && p.is_placeholder
    );
    if (nextPlaceholder) {
      router.push(`/posters/${nextPlaceholder.id}`);
    }
  }
  const addSheets = useAddSheets<"group" | "poster">();
  const image = useImageAttach();
  const { runFormAction } = useTransitionAction();

  // Self-actions for "編輯此群組". The delete variant navigates back
  // because the current URL would 404 once the group is gone.
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
      hint: "海報會回到作品頂層，不會被刪除",
      destructive: true,
      confirm: (g) =>
        `刪除群組「${g.name}」？\n子群組會一併消失，群組內的海報會回到作品頂層（不放進任何群組），海報本身不刪。`,
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
          placeholder: "例:B1 原版",
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
        image.pickFor(p, handleUploadSuccess);
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

  const allItems = [
    ...groups.map((g) => ({ kind: "group" as const, data: g })),
    ...posters.map((p) => ({ kind: "poster" as const, data: p })),
  ];

  const filteredItems = filter.trim()
    ? allItems.filter((it) => {
        const label =
          it.kind === "group"
            ? it.data.name
            : (it.data.poster_name ?? "");
        return label.toLowerCase().includes(filter.trim().toLowerCase());
      })
    : allItems;

  // DnD move handlers — "root" in GroupClient means move to the parent group's level.
  async function handleMoveGroup(groupId: string, newParentGroupId: string | null) {
    const r = await moveGroup(groupId, newParentGroupId);
    if (!r.ok) toast.error(r.error ?? "移動失敗");
    else toast.success("已移動群組");
  }

  async function handleMovePoster(posterId: string, newParentGroupId: string | null) {
    const r = await movePoster(posterId, newParentGroupId);
    if (!r.ok) toast.error(r.error ?? "移動失敗");
    else toast.success("已移動海報");
  }

  // Root zone label depends on whether this group has a parent
  const rootZoneLabel = group.parent_group_id
    ? "移到上一層群組"
    : "移到作品頂層（不放在任何群組）";

  return (
    <TreeShell
      nav={nav}
      back={back}
      title={group.name}
      subtitle={`${groups.length} 個子群組 · ${posters.length} 張直屬海報`}
      fab={<FAB onClick={addSheets.openPicker} label="新增" />}
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
        ref={image.fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={image.handleFile}
      />

      {allItems.length >= 8 && (
        <div className="mb-3">
          <Input
            placeholder="搜尋子群組或海報…"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="h-9 text-sm"
          />
        </div>
      )}

      {allItems.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          這個群組還是空的。點右下的 + 開始新增。
        </div>
      ) : filteredItems.length === 0 ? (
        <div className="text-center text-muted-foreground py-12 text-sm">
          找不到「{filter}」。
        </div>
      ) : (
        <DndTreeList
          items={filteredItems}
          rootParentId={group.parent_group_id}
          rootZoneLabel={rootZoneLabel}
          onMoveGroup={handleMoveGroup}
          onMovePoster={handleMovePoster}
          onGroupMore={setActiveGroup}
          onPosterMore={setActivePoster}
          uploadingPosterId={image.uploading ? image.uploadTargetId : null}
        />
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
        title={activePoster?.poster_name ?? UNNAMED_POSTER}
        description={
          activePoster?.is_placeholder ? "尚未上傳真實圖片" : "海報"
        }
        actions={posterActions}
      />

      <Sheet open={addSheets.pickerOpen} onOpenChange={addSheets.setPickerOpen}>
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
                  onClick: () => addSheets.openForm("group"),
                },
                {
                  icon: <FilePlus2 className="w-4 h-4" />,
                  label: "新增海報",
                  hint: "直接放在這個群組裡",
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
            addSheets.close
          )
        }
      />

      <FormSheet
        open={addSheets.formKind === "poster"}
        onOpenChange={addSheets.setFormOpen("poster")}
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
            addSheets.close
          )
        }
      />
    </TreeShell>
  );
}
