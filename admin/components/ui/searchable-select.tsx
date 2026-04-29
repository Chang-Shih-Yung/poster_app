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

/**
 * A single row inside a searchable dropdown. `label` is what the user
 * sees in both the trigger and the row; `searchText` (optional) is what
 * cmdk uses for matching when the user types — useful when we want to
 * search by parent path even though the row only shows the leaf name.
 *
 * `separatorBefore` lets the caller mark visual breaks (e.g. between
 * top-level group blocks) without a separate Group wrapper.
 */
export type SearchableItem = {
  value: string;
  label: string;
  searchText?: string;
  separatorBefore?: boolean;
  // Optional left indent in rem for showing tree depth visually
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
}: Props) {
  const [open, setOpen] = React.useState(false);
  const selected = items.find((i) => i.value === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
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
        <Command
          // cmdk default filter searches all of `value` + every item's
          // text content. We force it to use our `searchText` when set
          // so we can search by parent path while displaying only the
          // leaf name.
          filter={(value, search, keywords) => {
            const haystack = (
              keywords?.join(" ") ?? value
            ).toLowerCase();
            return haystack.includes(search.toLowerCase()) ? 1 : 0;
          }}
        >
          <CommandInput placeholder={searchPlaceholder} />
          <CommandList>
            <CommandEmpty>{emptyText}</CommandEmpty>
            <CommandGroup>
              {items.map((item, idx) => (
                <React.Fragment key={item.value}>
                  {item.separatorBefore && idx > 0 && <CommandSeparator />}
                  <CommandItem
                    value={item.value}
                    keywords={[item.searchText ?? item.label]}
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
