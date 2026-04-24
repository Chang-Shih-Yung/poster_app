"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type GroupRow = {
  id: string;
  name: string;
  group_type: string | null;
  parent_group_id: string | null;
  display_order: number;
};

/**
 * Mobile-friendly group manager for one work. Lists groups in a flat
 * indented view (depth resolved client-side), with inline rename + add
 * + delete. Bigger drag-drop tree editor lands in a future iteration —
 * for v0 the editor adds and renames, no reordering yet.
 */
export default function GroupManager({
  workId,
  initialGroups,
}: {
  workId: string;
  initialGroups: GroupRow[];
}) {
  const router = useRouter();
  const [groups, setGroups] = useState<GroupRow[]>(initialGroups);
  const [adding, setAdding] = useState<{ parentId: string | null } | null>(null);
  const [newName, setNewName] = useState("");
  const [newType, setNewType] = useState("");
  const [busy, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  // Build a tree client-side from the flat list.
  const childrenOf = (parentId: string | null) =>
    groups
      .filter((g) => g.parent_group_id === parentId)
      .sort((a, b) =>
        a.display_order !== b.display_order
          ? a.display_order - b.display_order
          : a.name.localeCompare(b.name)
      );

  async function addGroup(parentId: string | null) {
    setError(null);
    if (!newName.trim()) return;
    const supabase = createClient();
    const { data, error } = await supabase
      .from("poster_groups")
      .insert({
        work_id: workId,
        parent_group_id: parentId,
        name: newName.trim(),
        group_type: newType.trim() || null,
        display_order: childrenOf(parentId).length,
      })
      .select("id, name, group_type, parent_group_id, display_order")
      .single();
    if (error) {
      setError(error.message);
      return;
    }
    setGroups((g) => [...g, data as GroupRow]);
    setNewName("");
    setNewType("");
    setAdding(null);
    startTransition(() => router.refresh());
  }

  async function deleteGroup(id: string) {
    if (!confirm("刪除此群組？子群組與底下的海報關聯會被解除（poster.parent_group_id 設為 NULL）")) return;
    const supabase = createClient();
    const { error } = await supabase
      .from("poster_groups")
      .delete()
      .eq("id", id);
    if (error) {
      setError(error.message);
      return;
    }
    setGroups((g) => g.filter((x) => x.id !== id));
    startTransition(() => router.refresh());
  }

  function renderNode(g: GroupRow, depth: number): React.ReactNode {
    const children = childrenOf(g.id);
    return (
      <div key={g.id}>
        <div
          className="flex items-center justify-between min-h-[48px] hover:bg-surfaceRaised pr-3"
          style={{ paddingLeft: `${depth * 16 + 16}px` }}
        >
          <div className="min-w-0 flex-1">
            <div className="text-sm truncate">{g.name}</div>
            {g.group_type && (
              <div className="text-xs text-textFaint truncate">{g.group_type}</div>
            )}
          </div>
          <button
            onClick={() => setAdding({ parentId: g.id })}
            className="text-xs text-accent px-2 py-1"
          >
            + 子群組
          </button>
          <button
            onClick={() => deleteGroup(g.id)}
            className="text-xs text-red-400 px-2 py-1"
          >
            刪
          </button>
        </div>
        {adding?.parentId === g.id && (
          <AddRow
            depth={depth + 1}
            name={newName}
            type={newType}
            onName={setNewName}
            onType={setNewType}
            onSubmit={() => addGroup(g.id)}
            onCancel={() => {
              setAdding(null);
              setNewName("");
              setNewType("");
            }}
            busy={busy}
          />
        )}
        {children.map((c) => renderNode(c, depth + 1))}
      </div>
    );
  }

  const roots = childrenOf(null);

  return (
    <div className="border-y border-line1 md:border md:rounded-lg md:bg-surface">
      {error && (
        <div className="px-4 py-2 bg-red-900/40 border-b border-red-700 text-sm">
          {error}
        </div>
      )}

      {roots.map((r) => renderNode(r, 0))}

      {adding?.parentId === null ? (
        <AddRow
          depth={0}
          name={newName}
          type={newType}
          onName={setNewName}
          onType={setNewType}
          onSubmit={() => addGroup(null)}
          onCancel={() => {
            setAdding(null);
            setNewName("");
            setNewType("");
          }}
          busy={busy}
        />
      ) : (
        <button
          onClick={() => setAdding({ parentId: null })}
          className="w-full px-4 py-3 text-sm text-accent text-left hover:bg-surfaceRaised"
        >
          + 新增頂層群組（例如：2001 日本首映）
        </button>
      )}

      {roots.length === 0 && adding === null && (
        <div className="px-4 py-6 text-center text-textFaint text-sm">
          還沒有群組。建一個試試看。
        </div>
      )}
    </div>
  );
}

function AddRow({
  depth,
  name,
  type,
  onName,
  onType,
  onSubmit,
  onCancel,
  busy,
}: {
  depth: number;
  name: string;
  type: string;
  onName: (v: string) => void;
  onType: (v: string) => void;
  onSubmit: () => void;
  onCancel: () => void;
  busy: boolean;
}) {
  return (
    <div
      className="bg-surfaceRaised py-3 pr-3 space-y-2"
      style={{ paddingLeft: `${depth * 16 + 16}px` }}
    >
      <input
        autoFocus
        value={name}
        onChange={(e) => onName(e.target.value)}
        placeholder="群組名稱（例：2001 日本首映 / 角色版）"
        className="w-full"
        onKeyDown={(e) => {
          if (e.key === "Enter") onSubmit();
          if (e.key === "Escape") onCancel();
        }}
      />
      <input
        value={type}
        onChange={(e) => onType(e.target.value)}
        placeholder="（選填）類型 e.g. release_era / variant"
        className="w-full"
      />
      <div className="flex gap-2">
        <button
          onClick={onSubmit}
          disabled={busy || !name.trim()}
          className="px-3 py-1.5 text-xs rounded-md bg-accent text-bg font-medium disabled:opacity-50"
        >
          {busy ? "建立中…" : "建立"}
        </button>
        <button
          onClick={onCancel}
          className="px-3 py-1.5 text-xs rounded-md border border-line2 text-textMute"
        >
          取消
        </button>
      </div>
    </div>
  );
}
