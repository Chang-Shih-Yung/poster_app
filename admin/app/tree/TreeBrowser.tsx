"use client";

import { useCallback, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Studio = { studio: string; works: number; posters: number };

type WorkNode = {
  id: string;
  title_zh: string;
  title_en: string | null;
  work_kind: string;
  poster_count: number;
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

export default function TreeBrowser({ studios }: { studios: Studio[] }) {
  const [openStudios, setOpenStudios] = useState<Set<string>>(new Set());
  const [worksByStudio, setWorksByStudio] = useState<Record<string, WorkNode[]>>({});

  const [openWorks, setOpenWorks] = useState<Set<string>>(new Set());
  const [openGroups, setOpenGroups] = useState<Set<string>>(new Set());
  const [childrenByWork, setChildrenByWork] = useState<
    Record<string, ChildrenData>
  >({});
  const [childrenByGroup, setChildrenByGroup] = useState<
    Record<string, ChildrenData>
  >({});

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

      if (!worksByStudio[studio]) {
        const supabase = createClient();
        const q = supabase
          .from("works")
          .select("id, title_zh, title_en, work_kind, poster_count")
          .order("title_zh");
        const { data } =
          studio === "(未分類)"
            ? await q.is("studio", null)
            : await q.eq("studio", studio);
        setWorksByStudio((s) => ({ ...s, [studio]: (data ?? []) as WorkNode[] }));
      }
    },
    [openStudios, worksByStudio]
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

      if (!childrenByWork[workId]) {
        const supabase = createClient();
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
            .select(
              "id, poster_name, is_placeholder, thumbnail_url, work_id, parent_group_id"
            )
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
      }
    },
    [openWorks, childrenByWork]
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

      if (!childrenByGroup[groupId]) {
        const supabase = createClient();
        const [groupsRes, postersRes] = await Promise.all([
          supabase
            .from("poster_groups")
            .select("id, name, group_type, work_id, parent_group_id")
            .eq("parent_group_id", groupId)
            .order("display_order")
            .order("name"),
          supabase
            .from("posters")
            .select(
              "id, poster_name, is_placeholder, thumbnail_url, work_id, parent_group_id"
            )
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
      }
    },
    [openGroups, childrenByGroup]
  );

  if (studios.length === 0) {
    return (
      <div className="px-4 py-10 text-center text-textFaint text-sm">
        還沒有任何作品。
        <br />
        <Link href="/works/new" className="text-accent">
          去新增第一筆
        </Link>
      </div>
    );
  }

  return (
    <ul className="divide-y divide-line1 border-y border-line1 md:border md:rounded-lg md:bg-surface">
      {studios.map((s) => {
        const open = openStudios.has(s.studio);
        const works = worksByStudio[s.studio];
        return (
          <li key={s.studio}>
            <TreeRow
              depth={0}
              onClick={() => toggleStudio(s.studio)}
              chevron={works && works.length > 0 ? (open ? "down" : "right") : "none"}
              title={s.studio}
              subtitle={`${s.works} 作品 · ${s.posters} 海報`}
            />
            {open && works && (
              <ul>
                {works.map((w) => {
                  const workOpen = openWorks.has(w.id);
                  const children = childrenByWork[w.id];
                  return (
                    <li key={w.id}>
                      <TreeRow
                        depth={1}
                        onClick={() => toggleWork(w.id)}
                        chevron={workOpen ? "down" : "right"}
                        title={w.title_zh}
                        subtitle={`${w.poster_count} 張海報${w.title_en ? ` · ${w.title_en}` : ""}`}
                        rightSlot={
                          <Link
                            href={`/works/${w.id}`}
                            onClick={(e) => e.stopPropagation()}
                            className="text-xs text-accent px-2 py-1"
                          >
                            編輯
                          </Link>
                        }
                      />
                      {workOpen && children && (
                        <GroupsAndPosters
                          depth={2}
                          groups={children.groups}
                          posters={children.posters}
                          openGroups={openGroups}
                          childrenByGroup={childrenByGroup}
                          toggleGroup={toggleGroup}
                        />
                      )}
                    </li>
                  );
                })}
                {works.length === 0 && (
                  <li className="pl-10 pr-4 py-3 text-xs text-textFaint">
                    此 studio 尚無作品
                  </li>
                )}
              </ul>
            )}
          </li>
        );
      })}
    </ul>
  );
}

/**
 * Recursive renderer for a mixed list of groups and leaf posters under
 * the same parent. Groups nest further; leaves are tappable to edit.
 */
function GroupsAndPosters({
  depth,
  groups,
  posters,
  openGroups,
  childrenByGroup,
  toggleGroup,
}: {
  depth: number;
  groups: GroupNode[];
  posters: PosterLeaf[];
  openGroups: Set<string>;
  childrenByGroup: Record<string, ChildrenData>;
  toggleGroup: (id: string) => void;
}) {
  return (
    <ul>
      {groups.map((g) => {
        const open = openGroups.has(g.id);
        const children = childrenByGroup[g.id];
        return (
          <li key={g.id}>
            <TreeRow
              depth={depth}
              onClick={() => toggleGroup(g.id)}
              chevron={open ? "down" : "right"}
              icon="folder"
              title={g.name}
              subtitle={g.group_type ?? undefined}
            />
            {open && children && (
              <GroupsAndPosters
                depth={depth + 1}
                groups={children.groups}
                posters={children.posters}
                openGroups={openGroups}
                childrenByGroup={childrenByGroup}
                toggleGroup={toggleGroup}
              />
            )}
          </li>
        );
      })}
      {posters.map((p) => (
        <li key={p.id}>
          <Link
            href={`/posters/${p.id}`}
            className="block hover:bg-surfaceRaised hover:no-underline"
          >
            <TreeRow
              depth={depth}
              chevron="none"
              icon="poster"
              thumbnailUrl={p.thumbnail_url}
              title={p.poster_name ?? "(未命名)"}
              subtitle={p.is_placeholder ? "待補真圖" : undefined}
              subtitleColor={p.is_placeholder ? "amber" : undefined}
            />
          </Link>
        </li>
      ))}
      {groups.length === 0 && posters.length === 0 && (
        <li
          className="py-3 text-xs text-textFaint"
          style={{ paddingLeft: `${depth * 16 + 16}px` }}
        >
          此節點尚無內容
        </li>
      )}
    </ul>
  );
}

/**
 * One row of the tree. Depth drives left padding, chevron shows
 * expand/collapse state (none for leaves), icon + title + subtitle
 * form the main content.
 */
function TreeRow({
  depth,
  chevron,
  icon,
  title,
  subtitle,
  subtitleColor,
  thumbnailUrl,
  rightSlot,
  onClick,
}: {
  depth: number;
  chevron: "right" | "down" | "none";
  icon?: "folder" | "poster";
  title: string;
  subtitle?: string;
  subtitleColor?: "amber";
  thumbnailUrl?: string | null;
  rightSlot?: React.ReactNode;
  onClick?: () => void;
}) {
  const Padding = depth * 16 + 8;
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      onClick={onClick}
      className={`flex items-center w-full min-h-[52px] pr-3 ${
        onClick ? "text-left hover:bg-surfaceRaised active:bg-surfaceRaised" : ""
      }`}
      style={{ paddingLeft: `${Padding}px` }}
    >
      <span className="w-5 flex justify-center text-textMute shrink-0">
        {chevron === "right" && <Chevron direction="right" />}
        {chevron === "down" && <Chevron direction="down" />}
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

      {rightSlot}
    </Tag>
  );
}

function Chevron({ direction }: { direction: "right" | "down" }) {
  return (
    <svg
      width={14}
      height={14}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.5}
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{
        transform: direction === "down" ? "rotate(90deg)" : "rotate(0deg)",
        transition: "transform 0.15s ease",
      }}
    >
      <polyline points="9 18 15 12 9 6" />
    </svg>
  );
}

function FolderIcon() {
  return (
    <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 7a2 2 0 012-2h4l2 2h8a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2V7z" />
    </svg>
  );
}

function PosterIcon() {
  return (
    <svg width={14} height={16} viewBox="0 0 16 20" fill="none" stroke="currentColor" strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="2" width="12" height="16" rx="1.5" />
      <path d="M5 8l2 2 4-4" />
    </svg>
  );
}
