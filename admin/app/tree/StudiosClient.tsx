"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, FolderPlus } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import TreeShell from "./_components/TreeShell";
import TreeRow from "./_components/TreeRow";
import { SheetMenuList } from "./_components/SheetMenu";
import FAB from "./_components/FAB";
import { FormSheet } from "./_components/FormSheet";
import { describeError } from "@/lib/errors";
import { NULL_STUDIO_KEY, encodeStudioParam } from "./_components/keys";
import { createClient } from "@/lib/supabase/client";
import { WORK_KINDS } from "@/lib/enums";

type Studio = { studio: string; works: number; posters: number };

export default function StudiosClient({
  studios: initialStudios,
  nav,
}: {
  studios: Studio[];
  nav?: React.ReactNode;
}) {
  const router = useRouter();
  const supabase = createClient();
  const [studios, setStudios] = React.useState<Studio[]>(initialStudios);
  const [activeStudio, setActiveStudio] = React.useState<Studio | null>(null);
  const [renameOpen, setRenameOpen] = React.useState(false);
  const [addOpen, setAddOpen] = React.useState(false);

  async function renameStudio(values: Record<string, string>) {
    const studio = activeStudio;
    if (!studio) return;
    const newName = values.name.trim();
    if (!newName || newName === studio.studio) return;
    const q = supabase.from("works").update({ studio: newName });
    const { error } =
      studio.studio === NULL_STUDIO_KEY
        ? await q.is("studio", null)
        : await q.eq("studio", studio.studio);
    if (error) throw error;
    setStudios((list) =>
      list.map((s) => (s.studio === studio.studio ? { ...s, studio: newName } : s))
    );
    router.refresh();
  }

  async function deleteStudio(studio: Studio) {
    if (studio.studio === NULL_STUDIO_KEY) {
      alert(
        `「未分類」是虛擬分類（不是真實的 studio），無法直接刪除。\n\n要清空的話請改名（例如「吉卜力」）讓裡面的作品有歸屬。`
      );
      return;
    }
    if (
      !confirm(
        `刪除分類「${studio.studio}」？\n底下 ${studio.works} 部作品、${studio.posters} 張海報全部會被刪除。\n此操作不可復原。`
      )
    )
      return;
    const { error } = await supabase
      .from("works")
      .delete()
      .eq("studio", studio.studio);
    if (error) {
      alert(describeError(error));
      return;
    }
    setStudios((list) => list.filter((s) => s.studio !== studio.studio));
    router.refresh();
  }

  async function createStudio(values: Record<string, string>) {
    const studio = values.studio.trim();
    const title = values.title.trim();
    const kind = values.kind || "movie";
    if (!studio || !title) return;
    const { error } = await supabase.from("works").insert({
      title_zh: title,
      studio,
      work_kind: kind,
    });
    if (error) throw error;
    setStudios((list) => {
      const existing = list.find((s) => s.studio === studio);
      if (existing) {
        return list.map((s) =>
          s.studio === studio ? { ...s, works: s.works + 1 } : s
        );
      }
      return [...list, { studio, works: 1, posters: 0 }];
    });
    router.refresh();
  }

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

      <Sheet
        open={!!activeStudio && !renameOpen}
        onOpenChange={(v) => {
          if (!v) setActiveStudio(null);
        }}
      >
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle className="truncate">{activeStudio?.studio}</SheetTitle>
            <SheetDescription>
              {activeStudio?.works} 部作品 · {activeStudio?.posters} 張海報
            </SheetDescription>
          </SheetHeader>
          {activeStudio && (
            <div className="mt-3">
              <SheetMenuList
                items={[
                  {
                    icon: <Pencil className="w-4 h-4" />,
                    label: "重新命名分類",
                    hint:
                      activeStudio.studio === NULL_STUDIO_KEY
                        ? `會把所有未分類的 ${activeStudio.works} 部作品歸入新分類`
                        : `會把所有「${activeStudio.studio}」的作品改名`,
                    onClick: () => setRenameOpen(true),
                  },
                  {
                    icon: <Trash2 className="w-4 h-4" />,
                    label: "刪除整個分類",
                    hint: "底下作品與海報全部一併刪除",
                    destructive: true,
                    disabled: activeStudio.studio === NULL_STUDIO_KEY,
                    onClick: () => {
                      const target = activeStudio;
                      setActiveStudio(null);
                      void deleteStudio(target);
                    },
                  },
                ]}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* Rename sheet — separate from action sheet so its open state can
       * survive after the parent action sheet closes. */}
      <FormSheet
        open={renameOpen}
        onOpenChange={(v) => {
          setRenameOpen(v);
          if (!v) setActiveStudio(null);
        }}
        title={`重新命名「${activeStudio?.studio ?? ""}」`}
        description="會更新所有屬於這個分類的作品。"
        fields={[
          {
            key: "name",
            kind: "text",
            label: "新分類名稱",
            placeholder: "例：吉卜力",
            required: true,
            initialValue:
              activeStudio?.studio === NULL_STUDIO_KEY
                ? ""
                : activeStudio?.studio ?? "",
          },
        ]}
        submitLabel="儲存"
        onSubmit={renameStudio}
      />

      {/* New studio sheet — needs studio + first work title + kind because
       * a studio is just a string column on works (no row exists if no
       * work uses it). */}
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
        onSubmit={createStudio}
      />

      {/* Empty-state quick action — only visible when no studios exist */}
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
