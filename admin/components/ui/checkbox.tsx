"use client";

import * as React from "react";
import * as CheckboxPrimitive from "@radix-ui/react-checkbox";
import { Check } from "lucide-react";

import { cn } from "@/lib/utils";

/**
 * shadcn new-york Checkbox — Radix-driven, fully styled, keyboard
 * accessible. Use this everywhere instead of bare <input type="checkbox">
 * so visual + a11y stay consistent.
 *
 * Pattern:
 *   <label className="flex items-center gap-2 cursor-pointer">
 *     <Checkbox checked={value} onCheckedChange={onChange} />
 *     <span>Label</span>
 *   </label>
 *
 * onCheckedChange returns CheckedState (boolean | "indeterminate"); for
 * boolean fields wrap with `(c) => onChange(c === true)` if you need to
 * coerce.
 */
const Checkbox = React.forwardRef<
  React.ElementRef<typeof CheckboxPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof CheckboxPrimitive.Root>
>(({ className, ...props }, ref) => (
  <CheckboxPrimitive.Root
    ref={ref}
    className={cn(
      "peer h-4 w-4 shrink-0 rounded-sm border border-input shadow",
      "ring-offset-background focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
      "disabled:cursor-not-allowed disabled:opacity-50",
      "data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground data-[state=checked]:border-primary",
      "transition-colors",
      className
    )}
    {...props}
  >
    <CheckboxPrimitive.Indicator
      className={cn("flex items-center justify-center text-current")}
    >
      <Check className="h-3.5 w-3.5" strokeWidth={3} />
    </CheckboxPrimitive.Indicator>
  </CheckboxPrimitive.Root>
));
Checkbox.displayName = CheckboxPrimitive.Root.displayName;

export { Checkbox };
