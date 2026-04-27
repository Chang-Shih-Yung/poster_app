"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  ChevronRight,
  Folder,
  FileImage,
  Pencil,
  Plus,
  Trash2,
  ImagePlus,
  AlertTriangle,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

/**
 * Tree-as-editor design (2026-04-27 redesign): every row has inline
 * rename / add-child / delete buttons so the tree is the *primary*
 * editing surface, not a read-only viewer. Click row body to expand;
 * click the small action buttons on the right to mutate.
 *
 * Studio is a pseudo-node — it's not a separate table, just a string
 * column on works. So renaming a studio = bulk-update every work in
 * that bucket; adding a child = creating a new work with that studio
 * pre-filled; deleting = clearing studio on every work in the bucket.
 * The component handles those special cases inline.
 */

type Studio = { studio: string; works: number; posters: number };

type WorkNode = {
  id: string;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  poster_count: number;
  studio: string | null;
};

type GroupNode = {
  id: string;
  name: string;
  group_type: string | null;
  work_id: string;
  parent_group_id: string | null;
};

type PosterLeaf = {
  id: string;
  poster_name: string | null;
  is_placeholder: boolean;
  thumbnail_url: string | null;
  work_id: string;
  parent_group_id: string | null;
};

type ChildrenData = {
  groups: GroupNode[];
  posters: PosterLeaf[];
};

const NULL_STUDIO_KEY = "(未分類)";

export default function TreeBrowser({ studios: initialStudios }: { studios: Studio[] }) {
  const router = useRouter();
  const [studios, setStudios] = useState<Studio[]>(initialStudios);

  const [openStudios, setOpenStudios] = useState<Set<string>>(new Set());
  const [worksByStudio, setWorksByStudio] = useState<Record<string, WorkNode[]>>({});

  const [openWorks, setOpenWorks] = useState<Set<string>>(new Set());
  const [openGroups, setOpenGroups] = useState<Set<string>>(new Set());
  const [childrenByWork, setChildrenByWork] = useState<Record<string, ChildrenData>>({});
  const [childrenByGroup, setChildrenByGroup] = useState<Record<string, ChildrenData>>({});

  // Inline-edit state — only one row at a time.
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const supabase = createClient();

  /* ──────────────────────────── studio level ─────────────────────────── */

  const loadStudioWorks = useCallback(
    async (studio: string) => {
      const q = supabase
        .from("works")
        .select("id, title_zh, title_en, work_kind, poster_count, studio")
        .order("title_zh");
      const { data } =
        studio === NULL_STUDIO_KEY ? await q.is("studio", null) : await q.eq("studio", studio);
      setWorksByStudio((s) => ({ ...s, [studio]: (data ?? []) as WorkNode[] }));
    },
    [supabase]
  );

  const toggleStudio = useCallback(
    async (studio: string) => {
      const next = new Set(openStudios);
      if (next.has(studio)) {
        next.delete(studio);
        setOpenStudios(next);
        return;
      }
      next.add(studio);
      setOpenStudios(next);
      if (!worksByStudio[studio]) await loadStudioWorks(studio);
    },
    [openStudios, worksByStudio, loadStudioWorks]
  );

  async function renameStudio(oldName: string, newName: string) {
    if (newName.trim() === "") return;
    if (newName === oldName) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const q = supabase.from("works").update({ studio: newName.trim() });
      const { error } =
        oldName === NULL_STUDIO_KEY ? await q.is("studio", null) : await q.eq("studio", oldName);
      if (error) throw error;
      // Refresh: rebuild studios list + reload works.
      router.refresh();
      setStudios((list) => {
        const filtered = list.filter((s) => s.studio !== oldName);
        const moved = list.find((s) => s.studio === oldName);
        const target = filtered.find((s) => s.studio === newName.trim());
        if (target && moved) {
          target.works += moved.works;
          target.posters += moved.posters;
          return [...filtered];
        }
        if (moved) {
          return [...filtered, { ...moved, studio: newName.trim() }];
        }
        return list;
      });
      setEditing(null);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function deleteStudio(studio: string) {
    const items = (worksByStudio[studio] ?? []).length || studios.find((s) => s.studio === studio)?.works || 0;
    const msg =
      studio === NULL_STUDIO_KEY
        ? `「未分類」是一個虛擬分類（不是真實的 studio），無法直接刪除。\n\n要清空的話，請把它改名（例如「吉卜力」）讓裡面的作品有歸屬。`
        : `把「${studio}」清空（${items} 部作品的 studio 變成 NULL，會被丟回「未分類」）？\n作品本身不會被刪除。`;
    if (studio === NULL_STUDIO_KEY) {
      alert(msg);
      return;
    }
    if (!confirm(msg)) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase.from("works").update({ studio: null }).eq("studio", studio);
      if (error) throw error;
      router.refresh();
      setStudios((list) => list.filter((s) => s.studio !== studio));
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function addWorkToStudio(studio: string, title: string) {
    if (!title.trim()) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const studioValue = studio === NULL_STUDIO_KEY ? null : studio;
      const { data, error } = await supabase
        .from("works")
        .insert({
          title_zh: title.trim(),
          studio: studioValue,
          work_kind: "movie",
        })
        .select("id, title_zh, title_en, work_kind, poster_count, studio")
        .single();
      if (error) throw error;
      const newWork = data as WorkNode;
      setWorksByStudio((s) => ({ ...s, [studio]: [...(s[studio] ?? []), newWork] }));
      setStudios((list) =>
        list.map((s) => (s.studio === studio ? { ...s, works: s.works + 1 } : s))
      );
      setAdding(null);
      router.refresh();
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  /* ──────────────────────────── work level ───────────────────────────── */

  const loadWorkChildren = useCallback(
    async (workId: string) => {
      const [groupsRes, postersRes] = await Promise.all([
        supabase
          .from("poster_groups")
          .select("id, name, group_type, work_id, parent_group_id")
          .eq("work_id", workId)
          .is("parent_group_id", null)
          .order("display_order")
          .order("name"),
        supabase
          .from("posters")
          .select("id, poster_name, is_placeholder, thumbnail_url, work_id, parent_group_id")
          .eq("work_id", workId)
          .is("parent_group_id", null)
          .order("created_at", { ascending: false }),
      ]);
      setChildrenByWork((c) => ({
        ...c,
        [workId]: {
          groups: (groupsRes.data ?? []) as GroupNode[],
          posters: (postersRes.data ?? []) as PosterLeaf[],
        },
      }));
    },
    [supabase]
  );

  const toggleWork = useCallback(
    async (workId: string) => {
      const next = new Set(openWorks);
      if (next.has(workId)) {
        next.delete(workId);
        setOpenWorks(next);
        return;
      }
      next.add(workId);
      setOpenWorks(next);
      if (!childrenByWork[workId]) await loadWorkChildren(workId);
    },
    [openWorks, childrenByWork, loadWorkChildren]
  );

  async function renameWork(work: WorkNode, newName: string) {
    if (!newName.trim() || newName === work.title_zh) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase
        .from("works")
        .update({ title_zh: newName.trim() })
        .eq("id", work.id);
      if (error) throw error;
      setWorksByStudio((map) => {
        const studioKey = work.studio ?? NULL_STUDIO_KEY;
        const arr = map[studioKey];
        if (!arr) return map;
        return {
          ...map,
          [studioKey]: arr.map((w) =>
            w.id === work.id ? { ...w, title_zh: newName.trim() } : w
          ),
        };
      });
      setEditing(null);
      router.refresh();
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function deleteWork(work: WorkNode) {
    if (
      !confirm(
        `刪除作品「${work.title_zh}」？\n底下的所有群組跟海報都會一起被刪除（${work.poster_count} 張海報）。\n此操作不可復原。`
      )
    )
      return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase.from("works").delete().eq("id", work.id);
      if (error) throw error;
      const studioKey = work.studio ?? NULL_STUDIO_KEY;
      setWorksByStudio((map) => ({
        ...map,
        [studioKey]: (map[studioKey] ?? []).filter((w) => w.id !== work.id),
      }));
      setStudios((list) =>
        list.map((s) =>
          s.studio === studioKey
            ? { ...s, works: s.works - 1, posters: s.posters - work.poster_count }
            : s
        )
      );
      router.refresh();
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function addGroupToWork(workId: string, name: string) {
    if (!name.trim()) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const existing = childrenByWork[workId]?.groups.length ?? 0;
      const { data, error } = await supabase
        .from("poster_groups")
        .insert({
          work_id: workId,
          parent_group_id: null,
          name: name.trim(),
          display_order: existing,
        })
        .select("id, name, group_type, work_id, parent_group_id")
        .single();
      if (error) throw error;
      setChildrenByWork((c) => ({
        ...c,
        [workId]: {
          groups: [...(c[workId]?.groups ?? []), data as GroupNode],
          posters: c[workId]?.posters ?? [],
        },
      }));
      setAdding(null);
      router.refresh();
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  /* ──────────────────────────── group level ──────────────────────────── */

  const loadGroupChildren = useCallback(
    async (groupId: string) => {
      const [groupsRes, postersRes] = await Promise.all([
        supabase
          .from("poster_groups")
          .select("id, name, group_type, work_id, parent_group_id")
          .eq("parent_group_id", groupId)
          .order("display_order")
          .order("name"),
        supabase
          .from("posters")
          .select("id, poster_name, is_placeholder, thumbnail_url, work_id, parent_group_id")
          .eq("parent_group_id", groupId)
          .order("created_at", { ascending: false }),
      ]);
      setChildrenByGroup((c) => ({
        ...c,
        [groupId]: {
          groups: (groupsRes.data ?? []) as GroupNode[],
          posters: (postersRes.data ?? []) as PosterLeaf[],
        },
      }));
    },
    [supabase]
  );

  const toggleGroup = useCallback(
    async (groupId: string) => {
      const next = new Set(openGroups);
      if (next.has(groupId)) {
        next.delete(groupId);
        setOpenGroups(next);
        return;
      }
      next.add(groupId);
      setOpenGroups(next);
      if (!childrenByGroup[groupId]) await loadGroupChildren(groupId);
    },
    [openGroups, childrenByGroup, loadGroupChildren]
  );

  async function renameGroup(group: GroupNode, newName: string) {
    if (!newName.trim() || newName === group.name) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase
        .from("poster_groups")
        .update({ name: newName.trim() })
        .eq("id", group.id);
      if (error) throw error;
      setEditing(null);
      router.refresh();
      // Cheap update local: refetch parent.
      if (group.parent_group_id) await loadGroupChildren(group.parent_group_id);
      else await loadWorkChildren(group.work_id);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function deleteGroup(group: GroupNode) {
    if (
      !confirm(
        `刪除群組「${group.name}」？\n子群組會一併消失，群組內的海報會被「丟回上一層」（parent_group_id 設為 NULL，海報本身不刪）。`
      )
    )
      return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase.from("poster_groups").delete().eq("id", group.id);
      if (error) throw error;
      router.refresh();
      if (group.parent_group_id) await loadGroupChildren(group.parent_group_id);
      else await loadWorkChildren(group.work_id);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  type AddChildOpts = { groupId?: string; workId?: string; childKind: "group" | "poster" };

  async function addChildToGroup(opts: AddChildOpts, name: string) {
    if (!name.trim()) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      if (opts.childKind === "group") {
        const { error } = await supabase.from("poster_groups").insert({
          work_id: opts.workId!,
          parent_group_id: opts.groupId ?? null,
          name: name.trim(),
        });
        if (error) throw error;
      } else {
        // childKind === 'poster' — insert minimal row, defaults handle the rest.
        const { error } = await supabase.from("posters").insert({
          work_id: opts.workId!,
          parent_group_id: opts.groupId ?? null,
          poster_name: name.trim(),
          title: name.trim(), // legacy NOT NULL
          status: "approved",
          poster_url: "",
        });
        if (error) throw error;
      }
      setAdding(null);
      router.refresh();
      if (opts.groupId) await loadGroupChildren(opts.groupId);
      else if (opts.workId) await loadWorkChildren(opts.workId);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  /* ──────────────────────────── poster level ─────────────────────────── */

  async function renamePoster(poster: PosterLeaf, newName: string) {
    if (!newName.trim() || newName === poster.poster_name) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase
        .from("posters")
        .update({ poster_name: newName.trim(), title: newName.trim() })
        .eq("id", poster.id);
      if (error) throw error;
      setEditing(null);
      router.refresh();
      if (poster.parent_group_id) await loadGroupChildren(poster.parent_group_id);
      else if (poster.work_id) await loadWorkChildren(poster.work_id);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function deletePoster(poster: PosterLeaf) {
    if (!confirm(`刪除海報「${poster.poster_name ?? "(未命名)"}」？此操作不可復原。`)) return;
    setBusy(true);
    setErrorMsg(null);
    try {
      const { error } = await supabase.from("posters").delete().eq("id", poster.id);
      if (error) throw error;
      router.refresh();
      if (poster.parent_group_id) await loadGroupChildren(poster.parent_group_id);
      else if (poster.work_id) await loadWorkChildren(poster.work_id);
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  /* ──────────────────────────── render ───────────────────────────────── */

  if (studios.length === 0) {
    return (
      <div className="px-4 py-10 text-center text-textFaint text-sm">
        還沒有任何作品。
        <br />
        <button
          onClick={() => setAdding("__root__")}
          className="text-accent"
        >
          新增第一個 studio
        </button>
        {adding === "__root__" && (
          <div className="mt-3 px-4">
            <InlineInput
              placeholder="新 studio 名稱（例：吉卜力）"
              onSubmit={async (val) => {
                if (!val.trim()) return;
                setStudios([{ studio: val.trim(), works: 0, posters: 0 }]);
                setAdding(null);
              }}
              onCancel={() => setAdding(null)}
              busy={busy}
            />
          </div>
        )}
      </div>
    );
  }

  return (
    <>
      {errorMsg && (
        <div className="mx-4 my-2 p-3 rounded-md bg-red-900/40 border border-red-700 text-sm flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0 text-red-400" />
          <span className="flex-1">{errorMsg}</span>
          <button onClick={() => setErrorMsg(null)} className="text-textMute hover:text-text shrink-0">
            關閉
          </button>
        </div>
      )}

      <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
        {studios.map((s) => {
          const open = openStudios.has(s.studio);
          const works = worksByStudio[s.studio];
          const editKey = `studio:${s.studio}`;
          const addKey = `studio:${s.studio}:add`;
          return (
            <li key={s.studio}>
              {editing === editKey ? (
                <InlineRowEdit
                  depth={0}
                  initialValue={s.studio === NULL_STUDIO_KEY ? "" : s.studio}
                  placeholder={s.studio === NULL_STUDIO_KEY ? "把未分類改名（例：吉卜力）" : "新 studio 名稱"}
                  helper={
                    s.studio === NULL_STUDIO_KEY
                      ? `會把 ${s.works} 部「未分類」作品的 studio 全部設為這個名字`
                      : `會把 ${s.works} 部「${s.studio}」作品的 studio 全部改名`
                  }
                  onSubmit={(val) => renameStudio(s.studio, val)}
                  onCancel={() => setEditing(null)}
                  busy={busy}
                />
              ) : (
                <TreeRow
                  depth={0}
                  onClick={() => toggleStudio(s.studio)}
                  chevron={s.works > 0 ? (open ? "down" : "right") : "none"}
                  title={s.studio}
                  subtitle={`${s.works} 作品 · ${s.posters} 海報`}
                  actions={
                    <RowActions
                      onRename={() => setEditing(editKey)}
                      onAddChild={() => {
                        setAdding(addKey);
                        if (!open) toggleStudio(s.studio);
                      }}
                      onDelete={() => deleteStudio(s.studio)}
                      addLabel="新增作品"
                    />
                  }
                />
              )}
              {open && works && (
                <ul>
                  {works.map((w) => (
                    <WorkRow
                      key={w.id}
                      work={w}
                      open={openWorks.has(w.id)}
                      children={childrenByWork[w.id]}
                      openGroups={openGroups}
                      childrenByGroup={childrenByGroup}
                      editing={editing}
                      adding={adding}
                      onToggle={() => toggleWork(w.id)}
                      onToggleGroup={toggleGroup}
                      onSetEditing={setEditing}
                      onSetAdding={setAdding}
                      onRenameWork={renameWork}
                      onDeleteWork={deleteWork}
                      onAddGroupToWork={addGroupToWork}
                      onRenameGroup={renameGroup}
                      onDeleteGroup={deleteGroup}
                      onAddChildToGroup={addChildToGroup}
                      onRenamePoster={renamePoster}
                      onDeletePoster={deletePoster}
                      busy={busy}
                    />
                  ))}
                  {adding === addKey && (
                    <li>
                      <InlineRowEdit
                        depth={1}
                        placeholder="作品名稱（中文）"
                        onSubmit={(val) => addWorkToStudio(s.studio, val)}
                        onCancel={() => setAdding(null)}
                        busy={busy}
                        bgClass="bg-surfaceRaised"
                      />
                    </li>
                  )}
                </ul>
              )}
            </li>
          );
        })}
      </ul>
    </>
  );
}

/* ────────────────────── recursive children renderer ─────────────────── */

function WorkRow(props: {
  work: WorkNode;
  open: boolean;
  children: ChildrenData | undefined;
  openGroups: Set<string>;
  childrenByGroup: Record<string, ChildrenData>;
  editing: string | null;
  adding: string | null;
  onToggle: () => void;
  onToggleGroup: (id: string) => void;
  onSetEditing: (k: string | null) => void;
  onSetAdding: (k: string | null) => void;
  onRenameWork: (w: WorkNode, newName: string) => void;
  onDeleteWork: (w: WorkNode) => void;
  onAddGroupToWork: (workId: string, name: string) => void;
  onRenameGroup: (g: GroupNode, newName: string) => void;
  onDeleteGroup: (g: GroupNode) => void;
  onAddChildToGroup: (
    opts: { groupId?: string; workId?: string; childKind: "group" | "poster" },
    name: string
  ) => void;
  onRenamePoster: (p: PosterLeaf, newName: string) => void;
  onDeletePoster: (p: PosterLeaf) => void;
  busy: boolean;
}) {
  const w = props.work;
  const editKey = `work:${w.id}`;
  const addGroupKey = `work:${w.id}:add-group`;
  const addPosterKey = `work:${w.id}:add-poster`;

  return (
    <li>
      {props.editing === editKey ? (
        <InlineRowEdit
          depth={1}
          initialValue={w.title_zh}
          placeholder="作品中文名"
          onSubmit={(val) => props.onRenameWork(w, val)}
          onCancel={() => props.onSetEditing(null)}
          busy={props.busy}
        />
      ) : (
        <TreeRow
          depth={1}
          onClick={props.onToggle}
          chevron={props.open ? "down" : "right"}
          title={w.title_zh}
          subtitle={`${w.poster_count} 張海報${w.title_en ? ` · ${w.title_en}` : ""}`}
          actions={
            <RowActions
              onRename={() => props.onSetEditing(editKey)}
              onAddChild={() => {
                props.onSetAdding(addGroupKey);
                if (!props.open) props.onToggle();
              }}
              onDelete={() => props.onDeleteWork(w)}
              extra={
                <IconButton
                  onClick={(e) => {
                    e.stopPropagation();
                    props.onSetAdding(addPosterKey);
                    if (!props.open) props.onToggle();
                  }}
                  title="新增海報"
                >
                  <ImagePlus className="w-4 h-4 text-accent" />
                </IconButton>
              }
              addLabel="新增群組"
            />
          }
          rightAfterActions={
            <Link
              href={`/works/${w.id}`}
              onClick={(e) => e.stopPropagation()}
              className="text-xs text-accent px-2 py-1.5"
            >
              詳細
            </Link>
          }
        />
      )}

      {props.open && props.children && (
        <ul>
          {props.children.groups.map((g) => (
            <GroupNodeRow
              key={g.id}
              group={g}
              depth={2}
              open={props.openGroups.has(g.id)}
              children={props.childrenByGroup[g.id]}
              openGroups={props.openGroups}
              childrenByGroup={props.childrenByGroup}
              editing={props.editing}
              adding={props.adding}
              onToggleGroup={props.onToggleGroup}
              onSetEditing={props.onSetEditing}
              onSetAdding={props.onSetAdding}
              onRenameGroup={props.onRenameGroup}
              onDeleteGroup={props.onDeleteGroup}
              onAddChildToGroup={props.onAddChildToGroup}
              onRenamePoster={props.onRenamePoster}
              onDeletePoster={props.onDeletePoster}
              busy={props.busy}
            />
          ))}
          {props.children.posters.map((p) => (
            <PosterRow
              key={p.id}
              poster={p}
              depth={2}
              editing={props.editing}
              onSetEditing={props.onSetEditing}
              onRename={props.onRenamePoster}
              onDelete={props.onDeletePoster}
              busy={props.busy}
            />
          ))}
          {props.adding === addGroupKey && (
            <li>
              <InlineRowEdit
                depth={2}
                placeholder="群組名稱（例：2001 日本首映）"
                onSubmit={(val) => props.onAddGroupToWork(w.id, val)}
                onCancel={() => props.onSetAdding(null)}
                busy={props.busy}
                bgClass="bg-surfaceRaised"
              />
            </li>
          )}
          {props.adding === addPosterKey && (
            <li>
              <InlineRowEdit
                depth={2}
                placeholder="海報名稱（例：B1 原版）"
                onSubmit={(val) =>
                  props.onAddChildToGroup({ workId: w.id, childKind: "poster" }, val)
                }
                onCancel={() => props.onSetAdding(null)}
                busy={props.busy}
                bgClass="bg-surfaceRaised"
              />
            </li>
          )}
          {props.children.groups.length === 0 && props.children.posters.length === 0 && props.adding !== addGroupKey && props.adding !== addPosterKey && (
            <li className="pl-12 pr-4 py-3 text-xs text-textFaint">
              此作品還沒有群組或海報
            </li>
          )}
        </ul>
      )}
    </li>
  );
}

function GroupNodeRow(props: {
  group: GroupNode;
  depth: number;
  open: boolean;
  children: ChildrenData | undefined;
  openGroups: Set<string>;
  childrenByGroup: Record<string, ChildrenData>;
  editing: string | null;
  adding: string | null;
  onToggleGroup: (id: string) => void;
  onSetEditing: (k: string | null) => void;
  onSetAdding: (k: string | null) => void;
  onRenameGroup: (g: GroupNode, newName: string) => void;
  onDeleteGroup: (g: GroupNode) => void;
  onAddChildToGroup: (
    opts: { groupId?: string; workId?: string; childKind: "group" | "poster" },
    name: string
  ) => void;
  onRenamePoster: (p: PosterLeaf, newName: string) => void;
  onDeletePoster: (p: PosterLeaf) => void;
  busy: boolean;
}) {
  const g = props.group;
  const editKey = `group:${g.id}`;
  const addGroupKey = `group:${g.id}:add-group`;
  const addPosterKey = `group:${g.id}:add-poster`;

  return (
    <li>
      {props.editing === editKey ? (
        <InlineRowEdit
          depth={props.depth}
          initialValue={g.name}
          placeholder="群組名稱"
          onSubmit={(val) => props.onRenameGroup(g, val)}
          onCancel={() => props.onSetEditing(null)}
          busy={props.busy}
        />
      ) : (
        <TreeRow
          depth={props.depth}
          icon="folder"
          onClick={() => props.onToggleGroup(g.id)}
          chevron={props.open ? "down" : "right"}
          title={g.name}
          subtitle={g.group_type ?? undefined}
          actions={
            <RowActions
              onRename={() => props.onSetEditing(editKey)}
              onAddChild={() => {
                props.onSetAdding(addGroupKey);
              }}
              onDelete={() => props.onDeleteGroup(g)}
              addLabel="子群組"
              extra={
                <IconButton
                  onClick={(e) => {
                    e.stopPropagation();
                    props.onSetAdding(addPosterKey);
                  }}
                  title="新增海報"
                >
                  <ImagePlus className="w-4 h-4 text-accent" />
                </IconButton>
              }
            />
          }
        />
      )}

      {props.open && props.children && (
        <ul>
          {props.children.groups.map((sub) => (
            <GroupNodeRow
              key={sub.id}
              group={sub}
              depth={props.depth + 1}
              open={props.openGroups.has(sub.id)}
              children={props.childrenByGroup[sub.id]}
              openGroups={props.openGroups}
              childrenByGroup={props.childrenByGroup}
              editing={props.editing}
              adding={props.adding}
              onToggleGroup={props.onToggleGroup}
              onSetEditing={props.onSetEditing}
              onSetAdding={props.onSetAdding}
              onRenameGroup={props.onRenameGroup}
              onDeleteGroup={props.onDeleteGroup}
              onAddChildToGroup={props.onAddChildToGroup}
              onRenamePoster={props.onRenamePoster}
              onDeletePoster={props.onDeletePoster}
              busy={props.busy}
            />
          ))}
          {props.children.posters.map((p) => (
            <PosterRow
              key={p.id}
              poster={p}
              depth={props.depth + 1}
              editing={props.editing}
              onSetEditing={props.onSetEditing}
              onRename={props.onRenamePoster}
              onDelete={props.onDeletePoster}
              busy={props.busy}
            />
          ))}
          {props.adding === addGroupKey && (
            <li>
              <InlineRowEdit
                depth={props.depth + 1}
                placeholder="子群組名稱"
                onSubmit={(val) =>
                  props.onAddChildToGroup({ groupId: g.id, workId: g.work_id, childKind: "group" }, val)
                }
                onCancel={() => props.onSetAdding(null)}
                busy={props.busy}
                bgClass="bg-surfaceRaised"
              />
            </li>
          )}
          {props.adding === addPosterKey && (
            <li>
              <InlineRowEdit
                depth={props.depth + 1}
                placeholder="海報名稱"
                onSubmit={(val) =>
                  props.onAddChildToGroup({ groupId: g.id, workId: g.work_id, childKind: "poster" }, val)
                }
                onCancel={() => props.onSetAdding(null)}
                busy={props.busy}
                bgClass="bg-surfaceRaised"
              />
            </li>
          )}
        </ul>
      )}
    </li>
  );
}

function PosterRow(props: {
  poster: PosterLeaf;
  depth: number;
  editing: string | null;
  onSetEditing: (k: string | null) => void;
  onRename: (p: PosterLeaf, newName: string) => void;
  onDelete: (p: PosterLeaf) => void;
  busy: boolean;
}) {
  const p = props.poster;
  const editKey = `poster:${p.id}`;

  if (props.editing === editKey) {
    return (
      <InlineRowEdit
        depth={props.depth}
        initialValue={p.poster_name ?? ""}
        placeholder="海報名稱"
        onSubmit={(val) => props.onRename(p, val)}
        onCancel={() => props.onSetEditing(null)}
        busy={props.busy}
      />
    );
  }

  return (
    <Link
      href={`/posters/${p.id}`}
      className="block hover:bg-surfaceRaised hover:no-underline"
    >
      <TreeRow
        depth={props.depth}
        chevron="none"
        icon="poster"
        thumbnailUrl={p.thumbnail_url}
        title={p.poster_name ?? "(未命名)"}
        subtitle={p.is_placeholder ? "待補真圖" : undefined}
        subtitleColor={p.is_placeholder ? "amber" : undefined}
        actions={
          <RowActions
            onRename={(e) => {
              e?.stopPropagation();
              e?.preventDefault();
              props.onSetEditing(editKey);
            }}
            onDelete={(e) => {
              e?.stopPropagation();
              e?.preventDefault();
              props.onDelete(p);
            }}
          />
        }
      />
    </Link>
  );
}

/* ────────────────────────────── primitives ─────────────────────────── */

function TreeRow({
  depth,
  chevron,
  icon,
  title,
  subtitle,
  subtitleColor,
  thumbnailUrl,
  actions,
  rightAfterActions,
  onClick,
}: {
  depth: number;
  chevron: "right" | "down" | "none";
  icon?: "folder" | "poster";
  title: string;
  subtitle?: string;
  subtitleColor?: "amber";
  thumbnailUrl?: string | null;
  actions?: React.ReactNode;
  rightAfterActions?: React.ReactNode;
  onClick?: () => void;
}) {
  const padding = depth * 16 + 8;
  return (
    <div
      onClick={onClick}
      className={`flex items-center w-full min-h-[52px] pr-1 ${
        onClick ? "cursor-pointer hover:bg-surfaceRaised active:bg-surfaceRaised" : ""
      }`}
      style={{ paddingLeft: `${padding}px` }}
    >
      <span className="w-5 flex justify-center text-textMute shrink-0">
        {chevron === "right" && <ChevronIcon direction="right" />}
        {chevron === "down" && <ChevronIcon direction="down" />}
      </span>

      {thumbnailUrl ? (
        <img
          src={thumbnailUrl}
          alt=""
          className="w-8 h-10 rounded object-cover border border-line1 mr-2 shrink-0"
        />
      ) : (
        <span className="w-6 mr-2 text-textMute shrink-0 flex items-center justify-center">
          {icon === "folder" && <FolderIcon />}
          {icon === "poster" && <PosterIcon />}
        </span>
      )}

      <span className="flex-1 min-w-0">
        <span className="block text-sm text-text truncate">{title}</span>
        {subtitle && (
          <span
            className={`block text-xs truncate ${
              subtitleColor === "amber" ? "text-amber-400" : "text-textFaint"
            }`}
          >
            {subtitle}
          </span>
        )}
      </span>

      <span className="flex items-center shrink-0">{actions}</span>
      {rightAfterActions}
    </div>
  );
}

function RowActions({
  onRename,
  onAddChild,
  onDelete,
  addLabel,
  extra,
}: {
  onRename?: (e?: React.MouseEvent) => void;
  onAddChild?: () => void;
  onDelete?: (e?: React.MouseEvent) => void;
  addLabel?: string;
  extra?: React.ReactNode;
}) {
  return (
    <div className="flex items-center gap-0.5">
      {extra}
      {onAddChild && (
        <IconButton
          onClick={(e) => {
            e.stopPropagation();
            onAddChild();
          }}
          title={addLabel ?? "新增子項"}
        >
          <Plus className="w-4 h-4 text-accent" />
        </IconButton>
      )}
      {onRename && (
        <IconButton
          onClick={(e) => {
            e.stopPropagation();
            onRename(e);
          }}
          title="重新命名"
          hoverColor="text"
        >
          <Pencil className="w-4 h-4" />
        </IconButton>
      )}
      {onDelete && (
        <IconButton
          onClick={(e) => {
            e.stopPropagation();
            onDelete(e);
          }}
          title="刪除"
          hoverColor="red"
        >
          <Trash2 className="w-4 h-4" />
        </IconButton>
      )}
    </div>
  );
}

function IconButton({
  onClick,
  title,
  hoverColor,
  children,
}: {
  onClick: (e: React.MouseEvent) => void;
  title: string;
  hoverColor?: "text" | "red";
  children: React.ReactNode;
}) {
  const hoverClass =
    hoverColor === "red"
      ? "hover:text-red-400"
      : hoverColor === "text"
      ? "hover:text-text"
      : "";
  return (
    <button
      onClick={onClick}
      className={`min-w-[36px] min-h-[36px] flex items-center justify-center text-textMute ${hoverClass}`}
      title={title}
      aria-label={title}
    >
      {children}
    </button>
  );
}

function InlineRowEdit({
  depth,
  initialValue = "",
  placeholder,
  helper,
  onSubmit,
  onCancel,
  busy,
  bgClass,
}: {
  depth: number;
  initialValue?: string;
  placeholder?: string;
  helper?: string;
  onSubmit: (val: string) => void;
  onCancel: () => void;
  busy: boolean;
  bgClass?: string;
}) {
  const padding = depth * 16 + 28;
  return (
    <div className={`py-2 pr-3 ${bgClass ?? "bg-surfaceRaised"}`} style={{ paddingLeft: `${padding}px` }}>
      <InlineInput
        initialValue={initialValue}
        placeholder={placeholder}
        helper={helper}
        onSubmit={onSubmit}
        onCancel={onCancel}
        busy={busy}
      />
    </div>
  );
}

function InlineInput({
  initialValue = "",
  placeholder,
  helper,
  onSubmit,
  onCancel,
  busy,
}: {
  initialValue?: string;
  placeholder?: string;
  helper?: string;
  onSubmit: (val: string) => void;
  onCancel: () => void;
  busy: boolean;
}) {
  const [value, setValue] = useState(initialValue);
  return (
    <div>
      <div className="flex gap-2">
        <input
          autoFocus
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder={placeholder}
          className="flex-1"
          disabled={busy}
          onKeyDown={(e) => {
            if (e.key === "Enter") onSubmit(value);
            if (e.key === "Escape") onCancel();
          }}
        />
        <button
          onClick={() => onSubmit(value)}
          disabled={busy || !value.trim()}
          className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium disabled:opacity-50"
        >
          {busy ? "處理中…" : "確認"}
        </button>
        <button
          onClick={onCancel}
          disabled={busy}
          className="px-3 py-1.5 text-xs rounded-md border border-line2 text-textMute"
        >
          取消
        </button>
      </div>
      {helper && <div className="text-[11px] text-textFaint mt-1.5">{helper}</div>}
    </div>
  );
}

/* ────────────────────────────── icons ──────────────────────────────── */

function ChevronIcon({ direction }: { direction: "right" | "down" }) {
  return (
    <ChevronRight
      className="w-3.5 h-3.5"
      style={{
        transform: direction === "down" ? "rotate(90deg)" : "rotate(0deg)",
        transition: "transform 0.15s ease",
      }}
      strokeWidth={2.5}
    />
  );
}

function FolderIcon() {
  return <Folder className="w-4 h-4" strokeWidth={1.75} />;
}

function PosterIcon() {
  return <FileImage className="w-4 h-4" strokeWidth={1.75} />;
}
