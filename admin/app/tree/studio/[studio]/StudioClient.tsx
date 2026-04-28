"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, Tag } from "lucide-react";
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
import { FormSheet, describeError } from "../../_components/FormSheet";
import { NULL_STUDIO_KEY } from "../../_components/keys";
import { createClient } from "@/lib/supabase/client";
import { WORK_KINDS } from "@/lib/enums";

type Work = {
  id: string;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  poster_count: number;
  studio: string | null;
};

export default function StudioClient({
  studio,
  works: initialWorks,
}: {
  studio: string;
  works: Work[];
}) {
  const router = useRouter();
  const supabase = createClient();
  const [works, setWorks] = React.useState<Work[]>(initialWorks);
  const [activeWork, setActiveWork] = React.useState<Work | null>(null);
  const [renameOpen, setRenameOpen] = React.useState(false);
  const [kindOpen, setKindOpen] = React.useState(false);
  const [addOpen, setAddOpen] = React.useState(false);

  async function renameWork(values: Record<string, string>) {
    if (!activeWork) return;
    const newName = values.name.trim();
    if (!newName || newName === activeWork.title_zh) return;
    const { error } = await supabase
      .from("works")
      .update({ title_zh: newName })
      .eq("id", activeWork.id);
    if (error) throw error;
    setWorks((list) =>
      list.map((w) => (w.id === activeWork.id ? { ...w, title_zh: newName } : w))
    );
    router.refresh();
  }

  async function changeKind(values: Record<string, string>) {
    if (!activeWork) return;
    const kind = values.kind;
    if (!kind || kind === activeWork.work_kind) return;
    const { error } = await supabase
      .from("works")
      .update({ work_kind: kind })
      .eq("id", activeWork.id);
    if (error) throw error;
    setWorks((list) =>
      list.map((w) => (w.id === activeWork.id ? { ...w, work_kind: kind } : w))
    );
    router.refresh();
  }

  async function deleteWork(work: Work) {
    if (
      !confirm(
        `刪除作品「${work.title_zh}」？\n底下的所有群組跟海報都會一起被刪除（${work.poster_count} 張海報）。\n此操作不可復原。`
      )
    )
      return;
    const { error } = await supabase.from("works").delete().eq("id", work.id);
    if (error) {
      alert(describeError(error));
      return;
    }
    setWorks((list) => list.filter((w) => w.id !== work.id));
    router.refresh();
  }

  async function createWork(values: Record<string, string>) {
    const title = values.title.trim();
    const kind = values.kind || "movie";
    if (!title) return;
    const studioValue = studio === NULL_STUDIO_KEY ? null : studio;
    const { data, error } = await supabase
      .from("works")
      .insert({ title_zh: title, studio: studioValue, work_kind: kind })
      .select("id, title_zh, title_en, work_kind, poster_count, studio")
      .single();
    if (error) throw error;
    setWorks((list) => [data as Work, ...list]);
    router.refresh();
  }

  const totalPosters = works.reduce((acc, w) => acc + w.poster_count, 0);

  return (
    <TreeShell
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

      <Sheet
        open={!!activeWork && !renameOpen && !kindOpen}
        onOpenChange={(v) => {
          if (!v) setActiveWork(null);
        }}
      >
        <SheetContent side="bottom">
          <SheetHeader>
            <SheetTitle className="truncate">{activeWork?.title_zh}</SheetTitle>
            <SheetDescription>
              {activeWork?.poster_count ?? 0} 張海報
            </SheetDescription>
          </SheetHeader>
          {activeWork && (
            <div className="mt-3">
              <SheetMenuList
                items={[
                  {
                    icon: <Pencil className="w-4 h-4" />,
                    label: "重新命名作品",
                    onClick: () => setRenameOpen(true),
                  },
                  {
                    icon: <Tag className="w-4 h-4" />,
                    label: "變更類型",
                    hint:
                      WORK_KINDS.find((k) => k.value === activeWork.work_kind)
                        ?.label ?? activeWork.work_kind,
                    onClick: () => setKindOpen(true),
                  },
                  {
                    icon: <Trash2 className="w-4 h-4" />,
                    label: "刪除作品",
                    hint: "底下的群組與海報全部一併刪除",
                    destructive: true,
                    onClick: () => {
                      const target = activeWork;
                      setActiveWork(null);
                      void deleteWork(target);
                    },
                  },
                ]}
              />
            </div>
          )}
        </SheetContent>
      </Sheet>

      <FormSheet
        open={renameOpen}
        onOpenChange={(v) => {
          setRenameOpen(v);
          if (!v) setActiveWork(null);
        }}
        title={`重新命名「${activeWork?.title_zh ?? ""}」`}
        fields={[
          {
            key: "name",
            kind: "text",
            label: "中文名稱",
            placeholder: "作品中文名",
            required: true,
            initialValue: activeWork?.title_zh ?? "",
          },
        ]}
        submitLabel="儲存"
        onSubmit={renameWork}
      />

      <FormSheet
        open={kindOpen}
        onOpenChange={(v) => {
          setKindOpen(v);
          if (!v) setActiveWork(null);
        }}
        title="變更作品類型"
        fields={[
          {
            key: "kind",
            kind: "select",
            label: "類型",
            options: WORK_KINDS.map((k) => ({ value: k.value, label: k.label })),
            initialValue: activeWork?.work_kind ?? "movie",
          },
        ]}
        submitLabel="儲存"
        onSubmit={changeKind}
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
            options: WORK_KINDS.map((k) => ({ value: k.value, label: k.label })),
            initialValue: "movie",
          },
        ]}
        submitLabel="新增"
        onSubmit={createWork}
      />
    </TreeShell>
  );
}
