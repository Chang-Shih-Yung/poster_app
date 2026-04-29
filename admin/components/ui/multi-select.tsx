"use client";

import * as React from "react";
import { Check, ChevronsUpDown, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

export type MultiSelectItem = {
  value: string;
  label: string;
};

type Props = {
  items: readonly MultiSelectItem[];
  value: string[];
  onChange: (next: string[]) => void;
  placeholder?: string;
  searchPlaceholder?: string;
  emptyText?: string;
  disabled?: boolean;
  triggerClassName?: string;
  /** Max badges to display in trigger before collapsing to "+N more". */
  maxDisplayed?: number;
};

/**
 * Multi-select dropdown — same visual family as SearchableSelect but lets
 * the user pick multiple values. Selected values render as small Badges
 * inside the trigger; clicking the X on a badge removes that value
 * without opening the popover.
 *
 * Used for `cinema_release_types` which is `array<string>` per partner
 * spec — one poster can be both "premium_format_limited" AND
 * "weekly_bonus".
 */
export function MultiSelectDropdown({
  items,
  value,
  onChange,
  placeholder = "選擇…（可複選）",
  searchPlaceholder = "搜尋…",
  emptyText = "找不到符合項目",
  disabled,
  triggerClassName,
  maxDisplayed = 3,
}: Props) {
  const [open, setOpen] = React.useState(false);

  function toggle(itemValue: string) {
    if (value.includes(itemValue)) {
      onChange(value.filter((v) => v !== itemValue));
    } else {
      onChange([...value, itemValue]);
    }
  }

  function removeOne(itemValue: string, e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    onChange(value.filter((v) => v !== itemValue));
  }

  const selectedItems = items.filter((i) => value.includes(i.value));
  const visible = selectedItems.slice(0, maxDisplayed);
  const overflow = selectedItems.length - visible.length;

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
            "w-full justify-between font-normal h-auto min-h-9 py-1.5",
            value.length === 0 && "text-muted-foreground",
            triggerClassName
          )}
        >
          <div className="flex flex-wrap gap-1 items-center flex-1 min-w-0">
            {value.length === 0 ? (
              <span className="text-sm">{placeholder}</span>
            ) : (
              <>
                {visible.map((item) => (
                  <Badge
                    key={item.value}
                    variant="secondary"
                    className="text-xs gap-1 px-1.5 py-0.5"
                  >
                    <span className="truncate max-w-[10rem]">{item.label}</span>
                    {!disabled && (
                      <span
                        role="button"
                        aria-label={`移除 ${item.label}`}
                        onClick={(e) => removeOne(item.value, e)}
                        className="rounded-sm hover:bg-secondary-foreground/20 -mr-0.5"
                      >
                        <X className="h-3 w-3" />
                      </span>
                    )}
                  </Badge>
                ))}
                {overflow > 0 && (
                  <Badge variant="secondary" className="text-xs px-1.5 py-0.5">
                    +{overflow}
                  </Badge>
                )}
              </>
            )}
          </div>
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        align="start"
        className="p-0 w-[--radix-popover-trigger-width] min-w-[14rem]"
      >
        <Command>
          <CommandInput placeholder={searchPlaceholder} />
          <CommandList>
            <CommandEmpty>{emptyText}</CommandEmpty>
            <CommandGroup>
              {items.map((item) => {
                const checked = value.includes(item.value);
                return (
                  <CommandItem
                    key={item.value}
                    value={item.value}
                    keywords={[item.label]}
                    onSelect={() => toggle(item.value)}
                  >
                    <Check
                      className={cn(
                        "mr-2 h-4 w-4 shrink-0",
                        checked ? "opacity-100" : "opacity-0"
                      )}
                    />
                    <span className="truncate">{item.label}</span>
                  </CommandItem>
                );
              })}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
