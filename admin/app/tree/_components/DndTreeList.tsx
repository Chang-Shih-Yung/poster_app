"use client";

/**
 * DndTreeList — drag-to-move for groups and posters.
 *
 * Wraps a list of mixed group/poster items in a @dnd-kit DndContext.
 * Each row gets a GripVertical handle; long-pressing (touch) or
 * click-dragging (mouse) initiates a drag. Dropping on a folder row
 * moves the dragged item into that folder. Dropping on the "root zone"
 * moves it to the parent level supplied by the caller (null = work root).
 *
 * The parent component is responsible for calling the actual server
 * actions via the onMoveGroup / onMovePoster callbacks.
 */

import * as React from "react";
import {
  DndContext,
  DragOverlay,
  MouseSensor,
  TouchSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import { Folder, FileImage, FolderInput } from "lucide-react";
import { cn } from "@/lib/utils";
import { UNNAMED_POSTER } from "@/lib/keys";
import TreeRow from "./TreeRow";

// ── Types ────────────────────────────────────────────────────────────────────

export type DndGroup = {
  id: string;
  name: string;
  group_type: string | null;
  child_count: number;
  placeholder_count: number;
};

export type DndPoster = {
  id: string;
  poster_name: string | null;
  is_placeholder: boolean;
  thumbnail_url: string | null;
};

type Item =
  | { kind: "group"; data: DndGroup }
  | { kind: "poster"; data: DndPoster };

type DndTreeListProps = {
  items: Item[];
  /** parent_group_id to use when dropping on the "root zone"
   *  null  = work root (used by WorkClient)
   *  uuid  = parent group's id (used by GroupClient) */
  rootParentId: string | null;
  /** Label for the root drop zone shown while dragging */
  rootZoneLabel: string;
  onMoveGroup: (groupId: string, newParentGroupId: string | null) => Promise<void>;
  onMovePoster: (posterId: string, newParentGroupId: string | null) => Promise<void>;
  /** Extra per-row props from the parent — e.g. onMore callbacks */
  onGroupMore: (group: DndGroup) => void;
  onPosterMore: (poster: DndPoster) => void;
  /** While uploading, which poster is in progress */
  uploadingPosterId?: string | null;
};

// ── Root drop zone ────────────────────────────────────────────────────────────

const ROOT_DROP_ID = "__root__";

function RootDropZone({ label }: { label: string }) {
  const { setNodeRef, isOver } = useDroppable({ id: ROOT_DROP_ID });
  return (
    <li
      ref={setNodeRef}
      className={cn(
        "rounded-xl border-2 border-dashed flex items-center gap-2 px-4 py-3 text-sm transition-all duration-150",
        isOver
          ? "border-primary bg-primary/10 text-primary"
          : "border-border text-muted-foreground"
      )}
    >
      <FolderInput className="w-4 h-4 shrink-0" />
      <span>{label}</span>
    </li>
  );
}

// ── Draggable group row ───────────────────────────────────────────────────────

function DraggableGroupRow({
  group,
  onMore,
  isDraggingAny,
}: {
  group: DndGroup;
  onMore: () => void;
  isDraggingAny: boolean;
}) {
  const draggableId = `group:${group.id}`;

  const {
    attributes,
    listeners,
    setNodeRef: setDragRef,
    isDragging,
  } = useDraggable({ id: draggableId, data: { kind: "group", item: group } });

  const { setNodeRef: setDropRef, isOver } = useDroppable({
    id: draggableId,
    // Disable dropping on yourself or when nothing is being dragged.
    disabled: !isDraggingAny,
  });

  const ref = React.useCallback(
    (node: HTMLLIElement | null) => {
      setDragRef(node);
      setDropRef(node);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [setDragRef, setDropRef]
  );

  const subtitle = [
    group.group_type,
    group.placeholder_count > 0 ? `${group.placeholder_count} 待補圖` : null,
  ]
    .filter(Boolean)
    .join(" · ") || undefined;

  return (
    <TreeRow
      innerRef={ref}
      kind="folder"
      href={`/tree/group/${group.id}`}
      title={group.name}
      subtitle={subtitle}
      count={group.child_count}
      countLabel="張海報"
      onMore={onMore}
      dragListeners={listeners}
      dragAttributes={attributes}
      isDragging={isDragging}
      isDropTarget={isOver && !isDragging}
    />
  );
}

// ── Draggable poster row ──────────────────────────────────────────────────────

function DraggablePosterRow({
  poster,
  onMore,
  uploadingPosterId,
}: {
  poster: DndPoster;
  onMore: () => void;
  uploadingPosterId?: string | null;
}) {
  const draggableId = `poster:${poster.id}`;

  const {
    attributes,
    listeners,
    setNodeRef,
    isDragging,
  } = useDraggable({ id: draggableId, data: { kind: "poster", item: poster } });

  const isUploading = uploadingPosterId === poster.id;

  return (
    <TreeRow
      innerRef={setNodeRef}
      kind="poster"
      href={`/posters/${poster.id}`}
      thumbnailUrl={poster.thumbnail_url}
      title={poster.poster_name ?? UNNAMED_POSTER}
      subtitle={isUploading ? "上傳中…" : undefined}
      placeholder={poster.is_placeholder}
      onMore={onMore}
      dragListeners={listeners}
      dragAttributes={attributes}
      isDragging={isDragging}
    />
  );
}

// ── Drag overlay preview ──────────────────────────────────────────────────────

function DragPreview({ item }: { item: Item }) {
  return (
    <div className="rounded-xl border border-primary bg-card shadow-xl px-3 py-3 flex items-center gap-3 opacity-95 pointer-events-none">
      {item.kind === "group" ? (
        <Folder className="w-5 h-5 text-muted-foreground shrink-0" />
      ) : (
        <FileImage className="w-5 h-5 text-muted-foreground shrink-0" />
      )}
      <span className="text-sm font-medium truncate max-w-[180px]">
        {item.kind === "group"
          ? item.data.name
          : (item.data.poster_name ?? UNNAMED_POSTER)}
      </span>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function DndTreeList({
  items,
  rootParentId,
  rootZoneLabel,
  onMoveGroup,
  onMovePoster,
  onGroupMore,
  onPosterMore,
  uploadingPosterId,
}: DndTreeListProps) {
  const [activeItem, setActiveItem] = React.useState<Item | null>(null);

  const mouseSensor = useSensor(MouseSensor, {
    activationConstraint: { distance: 8 },
  });
  const touchSensor = useSensor(TouchSensor, {
    activationConstraint: { delay: 400, tolerance: 8 },
  });
  const sensors = useSensors(mouseSensor, touchSensor);

  function handleDragStart(event: DragStartEvent) {
    const data = event.active.data.current as { kind: string; item: DndGroup | DndPoster };
    if (data.kind === "group") {
      setActiveItem({ kind: "group", data: data.item as DndGroup });
    } else {
      setActiveItem({ kind: "poster", data: data.item as DndPoster });
    }
  }

  async function handleDragEnd(event: DragEndEvent) {
    setActiveItem(null);
    const { active, over } = event;
    if (!over) return;

    const activeData = active.data.current as { kind: string; item: DndGroup | DndPoster };
    const overId = over.id as string;

    // Determine target parent id
    let newParentGroupId: string | null;
    if (overId === ROOT_DROP_ID) {
      newParentGroupId = rootParentId;
    } else if (overId.startsWith("group:")) {
      newParentGroupId = overId.slice("group:".length);
    } else {
      return; // unknown drop target
    }

    // Don't drop a group on itself
    if (activeData.kind === "group" && newParentGroupId === activeData.item.id) return;

    if (activeData.kind === "group") {
      await onMoveGroup(activeData.item.id, newParentGroupId);
    } else {
      await onMovePoster(activeData.item.id, newParentGroupId);
    }
  }

  const isDraggingAny = activeItem !== null;

  return (
    <DndContext
      sensors={sensors}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <ul className="space-y-2">
        {/* Root drop zone — visible only while dragging */}
        {isDraggingAny && <RootDropZone label={rootZoneLabel} />}

        {items.map((it) =>
          it.kind === "group" ? (
            <DraggableGroupRow
              key={`g:${it.data.id}`}
              group={it.data}
              onMore={() => onGroupMore(it.data)}
              isDraggingAny={isDraggingAny}
            />
          ) : (
            <DraggablePosterRow
              key={`p:${it.data.id}`}
              poster={it.data}
              onMore={() => onPosterMore(it.data)}
              uploadingPosterId={uploadingPosterId}
            />
          )
        )}
      </ul>

      {/* Ghost image that follows the cursor / finger */}
      <DragOverlay dropAnimation={null}>
        {activeItem ? <DragPreview item={activeItem} /> : null}
      </DragOverlay>
    </DndContext>
  );
}
