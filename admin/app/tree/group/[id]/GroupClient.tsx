"use client";

import * as React from "react";
import { useTransition } from "react";
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
import { uploadPosterImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
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
  const [renameSelfOpen, setRenameSelfOpen] = React.useState(false);
  const [renameGroupOpen, setRenameGroupOpen] = React.useState(false);
  const [renamePosterOpen, setRenamePosterOpen] = React.useState(false);
  const [selfMenuOpen, setSelfMenuOpen] = React.useState(false);
  const [addPickerOpen, setAddPickerOpen] = React.useState(false);
  const [addGroupOpen, setAddGroupOpen] = React.useState(false);
  const [addPosterOpen, setAddPosterOpen] = React.useState(false);
  const [, startTransition] = useTransition();

  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const uploadTargetRef = React.useRef<Poster | null>(null);

  /* ─────────────── self mutations ─────────────── */
  function handleRenameSelf(values: Record<string, string>) {
    return new Promise<void>((resolve, reject) => {
      startTransition(async () => {
        const r = await renameGroup(group.id, values.name);
        if (!r.ok) reject(new Error(r.error));
        else {
          setRenameSelfOpen(false);
          setSelfMenuOpen(false);
          resolve();
        }
      });
    });
  }

  function handleDeleteSelf() {
    if (
      !confirm(
        `刪除群組「${group.name}」？\n子群組會一併消失，群組內的海報會被丟回上一層（海報本身不刪）。`
      )
    )
      return;
    startTransition(async () => {
      const r = await deleteGroup(group.id);
      if (!r.ok) {
        alert(r.error);
        return;
      }
      // After self-delete the URL is invalid; jump to parent.
      router.push(back.href);
    });
  }

  /* ─────────────── child group mutations ─────────────── */
  function handleRenameChildGroup(values: Record<string, string>) {
    if (!activeGroup) return Promise.resolve();
    return new Promise<void>((resolve, reject) => {
      startTransition(async () => {
        const r = await renameGroup(activeGroup.id, values.name);
        if (!r.ok) reject(new Error(r.error));
        else {
          setRenameGroupOpen(false);
          setActiveGroup(null);
          resolve();
        }
      });
    });
  }

  function handleDeleteChildGroup(target: Group) {
    if (
      !confirm(
        `刪除群組「${target.name}」？\n子群組會一併消失，群組內的海報會被丟回上一層（海報本身不刪）。`
      )
    )
      return;
    startTransition(async () => {
      const r = await deleteGroup(target.id);
      if (!r.ok) alert(r.error);
    });
  }

  function handleCreateChildGroup(values: Record<string, string>) {
    return new Promise<void>((resolve, reject) => {
      startTransition(async () => {
        const r = await createGroup({
          work_id: group.work_id,
          parent_group_id: group.id,
          name: values.name,
        });
        if (!r.ok) reject(new Error(r.error));
        else {
          setAddGroupOpen(false);
          resolve();
        }
      });
    });
  }

  /* ─────────────── poster mutations ─────────────── */
  function handleRenamePoster(values: Record<string, string>) {
    if (!activePoster) return Promise.resolve();
    return new Promise<void>((resolve, reject) => {
      startTransition(async () => {
        const r = await renamePoster(activePoster.id, values.name);
        if (!r.ok) reject(new Error(r.error));
        else {
          setRenamePosterOpen(false);
          setActivePoster(null);
          resolve();
        }
      });
    });
  }

  function handleDeletePoster(target: Poster) {
    if (!confirm(`刪除海報「${target.poster_name ?? "(未命名)"}」？此操作不可復原。`))
      return;
    startTransition(async () => {
      const r = await deletePoster(target.id);
      if (!r.ok) alert(r.error);
    });
  }

  function handleCreatePoster(values: Record<string, string>) {
    return new Promise<void>((resolve, reject) => {
      startTransition(async () => {
        const r = await createPoster({
          work_id: group.work_id,
          parent_group_id: group.id,
          poster_name: values.name,
        });
        if (!r.ok) reject(new Error(r.error));
        else {
          setAddPosterOpen(false);
          resolve();
        }
      });
    });
  }

  function pickImageFor(poster: Poster) {
    uploadTargetRef.current = poster;
    fileInputRef.current?.click();
  }

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

  /* ─────────────── render ─────────────── */
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
          onClick={() => setSelfMenuOpen(true)}
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

      <Sheet
        open={selfMenuOpen && !renameSelfOpen}
        onOpenChange={setSelfMenuOpen}
      >
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle className="truncate">{group.name}</SheetTitle>
            <SheetDescription>對這個群組本身做動作</SheetDescription>
          </SheetHeader>
          <div className="mt-3">
            <SheetMenuList
              items={[
                {
                  icon: <Pencil className="w-4 h-4" />,
                  label: "重新命名群組",
                  onClick: () => setRenameSelfOpen(true),
                },
                {
                  icon: <Trash2 className="w-4 h-4" />,
                  label: "刪除群組",
                  hint: "海報會被丟回上一層",
                  destructive: true,
                  onClick: () => {
                    setSelfMenuOpen(false);
                    handleDeleteSelf();
                  },
                },
              ]}
            />
          </div>
        </SheetContent>
      </Sheet>

      <Sheet
        open={!!activeGroup && !renameGroupOpen}
        onOpenChange={(v) => {
          if (!v) setActiveGroup(null);
        }}
      >
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle className="truncate">{activeGroup?.name}</SheetTitle>
            <SheetDescription>
              {activeGroup?.child_count ?? 0} 張海報
            </SheetDescription>
          </SheetHeader>
          {activeGroup && (
            <div className="mt-3">
              <SheetMenuList
                items={[
                  {
                    icon: <Pencil className="w-4 h-4" />,
                    label: "重新命名群組",
                    onClick: () => setRenameGroupOpen(true),
                  },
                  {
                    icon: <Trash2 className="w-4 h-4" />,
                    label: "刪除群組",
                    hint: "海報會被丟回上一層，不會被刪除",
                    destructive: true,
                    onClick: () => {
                      const target = activeGroup;
                      setActiveGroup(null);
                      handleDeleteChildGroup(target);
                    },
                  },
                ]}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

      <Sheet
        open={!!activePoster && !renamePosterOpen}
        onOpenChange={(v) => {
          if (!v) setActivePoster(null);
        }}
      >
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle className="truncate">
              {activePoster?.poster_name ?? "(未命名)"}
            </SheetTitle>
            <SheetDescription>
              {activePoster?.is_placeholder ? "尚未上傳真實圖片" : "海報"}
            </SheetDescription>
          </SheetHeader>
          {activePoster && (
            <div className="mt-3">
              <SheetMenuList
                items={[
                  {
                    icon: <Pencil className="w-4 h-4" />,
                    label: "重新命名海報",
                    onClick: () => setRenamePosterOpen(true),
                  },
                  {
                    icon: <ImagePlus className="w-4 h-4" />,
                    label: activePoster.is_placeholder ? "上傳真實圖片" : "更換圖片",
                    onClick: () => {
                      const target = activePoster;
                      setActivePoster(null);
                      pickImageFor(target);
                    },
                  },
                  {
                    icon: <Trash2 className="w-4 h-4" />,
                    label: "刪除海報",
                    destructive: true,
                    onClick: () => {
                      const target = activePoster;
                      setActivePoster(null);
                      handleDeletePoster(target);
                    },
                  },
                ]}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

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
        open={renameSelfOpen}
        onOpenChange={(v) => {
          setRenameSelfOpen(v);
          if (!v) setSelfMenuOpen(false);
        }}
        title={`重新命名「${group.name}」`}
        fields={[
          {
            key: "name",
            kind: "text",
            label: "群組名稱",
            required: true,
            initialValue: group.name,
          },
        ]}
        submitLabel="儲存"
        onSubmit={handleRenameSelf}
      />

      <FormSheet
        open={renameGroupOpen}
        onOpenChange={(v) => {
          setRenameGroupOpen(v);
          if (!v) setActiveGroup(null);
        }}
        title={`重新命名「${activeGroup?.name ?? ""}」`}
        fields={[
          {
            key: "name",
            kind: "text",
            label: "群組名稱",
            required: true,
            initialValue: activeGroup?.name ?? "",
          },
        ]}
        submitLabel="儲存"
        onSubmit={handleRenameChildGroup}
      />

      <FormSheet
        open={renamePosterOpen}
        onOpenChange={(v) => {
          setRenamePosterOpen(v);
          if (!v) setActivePoster(null);
        }}
        title="重新命名海報"
        fields={[
          {
            key: "name",
            kind: "text",
            label: "海報名稱",
            placeholder: "例：B1 原版",
            required: true,
            initialValue: activePoster?.poster_name ?? "",
          },
        ]}
        submitLabel="儲存"
        onSubmit={handleRenamePoster}
      />

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
        onSubmit={handleCreateChildGroup}
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
        onSubmit={handleCreatePoster}
      />
    </TreeShell>
  );
}
