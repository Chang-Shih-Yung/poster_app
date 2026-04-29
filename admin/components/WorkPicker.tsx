"use client";

import { SearchableSelect, type SearchableItem } from "@/components/ui/searchable-select";

export type WorkOption = {
  id: string;
  title_zh: string;
  studio: string | null;
};

/**
 * Searchable dropdown for picking a work. Used in PosterForm and
 * BatchImport. With hundreds of works the plain Select is unusable on
 * mobile; this lets the user type to filter by either title or studio.
 *
 * The trigger shows `[studio] title_zh` so the selection is unambiguous
 * even when two studios have works with the same title.
 */
export function WorkPicker({
  works,
  value,
  onChange,
  placeholder = "── 選擇作品 ──",
  disabled,
  triggerClassName,
}: {
  works: WorkOption[];
  value: string;
  onChange: (id: string) => void;
  placeholder?: string;
  disabled?: boolean;
  triggerClassName?: string;
}) {
  const items: SearchableItem[] = works.map((w) => ({
    value: w.id,
    label: w.studio ? `[${w.studio}] ${w.title_zh}` : w.title_zh,
    // Search by both studio and title — admin types either to find a work.
    searchText: `${w.studio ?? ""} ${w.title_zh}`.trim(),
  }));

  return (
    <SearchableSelect
      items={items}
      value={value || null}
      onChange={onChange}
      placeholder={placeholder}
      searchPlaceholder="搜尋作品名稱或工作室…"
      emptyText="找不到符合的作品"
      disabled={disabled}
      triggerClassName={triggerClassName}
      // 500 rows is the comfort zone for cmdk + Popover on a mid-tier
      // mobile device. Beyond that admin should narrow with search.
      maxResults={500}
    />
  );
}
