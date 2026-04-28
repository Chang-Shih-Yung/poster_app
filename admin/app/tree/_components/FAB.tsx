"use client";

import { Plus } from "lucide-react";

/**
 * Floating + button. Positioned by the parent (TreeShell sticks it
 * bottom-right above the tab bar).
 */
export default function FAB({
  onClick,
  label,
}: {
  onClick: () => void;
  label: string;
}) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      className="w-14 h-14 rounded-full bg-primary/20 text-primary shadow-lg flex items-center justify-center hover:bg-primary/30 transition-colors backdrop-blur-sm"
    >
      <Plus className="w-6 h-6" />
    </button>
  );
}
