"use client";

import * as React from "react";
import { Check, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

export type SearchableItem = {
  value: string;
  label: string;
  searchText?: string;
  separatorBefore?: boolean;
  indentRem?: number;
};

type Props = {
  items: SearchableItem[];
  value: string | null | undefined;
  onChange: (value: string) => void;
  placeholder?: string;
  searchPlaceholder?: string;
  emptyText?: string;
  disabled?: boolean;
  /** Override the trigger label when nothing is selected (e.g. show
   * a sentinel option's label). */
  triggerOverride?: string;
  triggerClassName?: string;
  contentClassName?: string;
  /** Render an extra footer area inside the popover (e.g. "+ 新增…").
   * Receives a `close` callback so the action can dismiss the popover. */
  footer?: (close: () => void) => React.ReactNode;
  /** Cap the number of rows actually rendered in the dropdown. With
   * 1000+ items cmdk's default behavior (render all + display:none the
   * non-matches) becomes laggy. We do our own filter on `searchText`
   * and cap to maxResults; if the user's query matches more, we show
   * a hint to type more characters. */
  maxResults?: number;
};

export function SearchableSelect({
  items,
  value,
  onChange,
  placeholder = "選擇…",
  searchPlaceholder = "搜尋…",
  emptyText = "找不到符合項目",
  disabled,
  triggerOverride,
  triggerClassName,
  contentClassName,
  footer,
  maxResults,
}: Props) {
  const [open, setOpen] = React.useState(false);
  const [search, setSearch] = React.useState("");
  const selected = items.find((i) => i.value === value);

  // Filter + cap. Done in JS rather than via cmdk's internal filter so
  // we can ALSO truncate, which cmdk can't do (it always renders every
  // item and toggles `display:none`).
  const { visible, hiddenCount } = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    const filtered = q
      ? items.filter((i) =>
          (i.searchText ?? i.label).toLowerCase().includes(q)
        )
      : items;
    if (maxResults && filtered.length > maxResults) {
      return {
        visible: filtered.slice(0, maxResults),
        hiddenCount: filtered.length - maxResults,
      };
    }
    return { visible: filtered, hiddenCount: 0 };
  }, [items, search, maxResults]);

  return (
    <Popover
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) setSearch(""); // reset search when closing
      }}
    >
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className={cn(
            "w-full justify-between font-normal",
            !selected && !triggerOverride && "text-muted-foreground",
            triggerClassName
          )}
        >
          <span className="truncate text-left">
            {triggerOverride ?? selected?.label ?? placeholder}
          </span>
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        align="start"
        className={cn(
          "p-0 w-[--radix-popover-trigger-width] min-w-[14rem]",
          contentClassName
        )}
      >
        {/* shouldFilter={false}: we do our own filter above. cmdk still
            handles keyboard nav + selection + scrolling. */}
        <Command shouldFilter={false}>
          <CommandInput
            placeholder={searchPlaceholder}
            value={search}
            onValueChange={setSearch}
          />
          <CommandList>
            {visible.length === 0 && (
              <CommandEmpty>{emptyText}</CommandEmpty>
            )}
            <CommandGroup>
              {visible.map((item, idx) => (
                <React.Fragment key={item.value}>
                  {item.separatorBefore && idx > 0 && <CommandSeparator />}
                  <CommandItem
                    value={item.value}
                    onSelect={() => {
                      onChange(item.value);
                      setOpen(false);
                    }}
                    style={
                      item.indentRem
                        ? { paddingLeft: `${0.5 + item.indentRem}rem` }
                        : undefined
                    }
                  >
                    <Check
                      className={cn(
                        "mr-2 h-4 w-4 shrink-0",
                        value === item.value ? "opacity-100" : "opacity-0"
                      )}
                    />
                    <span className="truncate">{item.label}</span>
                  </CommandItem>
                </React.Fragment>
              ))}
            </CommandGroup>
            {hiddenCount > 0 && (
              <div className="px-3 py-2 text-xs text-muted-foreground border-t border-border">
                還有 {hiddenCount} 筆符合，請輸入更多關鍵字縮小範圍
              </div>
            )}
            {footer && (
              <>
                <CommandSeparator />
                <CommandGroup>{footer(() => setOpen(false))}</CommandGroup>
              </>
            )}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
