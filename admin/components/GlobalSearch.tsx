"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Search, Folder, FolderTree, Film, ImageOff, Loader2 } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { globalSearch, type SearchResult } from "@/app/actions/search";
import { encodeStudioParam, NULL_STUDIO_KEY } from "@/lib/keys";

/** Build the navigation href for a search result. Inlined here because
 * `app/actions/search.ts` is `"use server"` and can only export async
 * functions. */
function hrefFor(result: SearchResult): string {
  switch (result.kind) {
    case "studio":
      return `/tree/studio/${encodeStudioParam(result.id || NULL_STUDIO_KEY)}`;
    case "work":
      return `/tree/work/${result.id}`;
    case "group":
      return `/tree/group/${result.id}`;
    case "poster":
      return `/posters/${result.id}`;
  }
}

const KIND_LABEL: Record<SearchResult["kind"], string> = {
  studio: "分類",
  work: "作品",
  group: "群組",
  poster: "海報",
};

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = React.useState(value);
  React.useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

// ── Result row ────────────────────────────────────────────────────────────────

function ResultRow({
  result,
  onNavigate,
}: {
  result: SearchResult;
  onNavigate: () => void;
}) {
  const router = useRouter();

  function handleClick(e: React.MouseEvent) {
    e.preventDefault();
    onNavigate();
    router.push(hrefFor(result));
  }

  const isPoster = result.kind === "poster";

  return (
    <li>
      <button
        onClick={handleClick}
        className="w-full flex items-center gap-3 px-4 py-3 hover:bg-muted/60 transition-colors text-left"
      >
        {/* Icon: folder for studio/work/group, thumbnail for poster */}
        <span className="shrink-0 flex items-center justify-center w-10 h-10">
          {result.kind === "studio" ? (
            <span className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-muted-foreground">
              <FolderTree className="w-5 h-5" strokeWidth={1.75} />
            </span>
          ) : result.kind === "work" ? (
            <span className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-muted-foreground">
              <Film className="w-5 h-5" strokeWidth={1.75} />
            </span>
          ) : result.kind === "group" ? (
            <span className="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center text-muted-foreground">
              <Folder className="w-5 h-5" strokeWidth={1.75} />
            </span>
          ) : result.thumbnailUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={result.thumbnailUrl}
              alt=""
              className="w-10 h-12 rounded object-cover border border-border"
            />
          ) : (
            <span className="w-10 h-12 rounded bg-secondary flex items-center justify-center text-muted-foreground border border-border">
              <ImageOff className="w-4 h-4" strokeWidth={1.75} />
            </span>
          )}
        </span>

        {/* Text */}
        <span className="flex-1 min-w-0">
          <span className="block text-sm text-foreground truncate">
            {result.label}
          </span>
          <span className="block text-xs text-muted-foreground truncate mt-0.5">
            {KIND_LABEL[result.kind]} · {result.meta}
          </span>
        </span>

        {/* Type chip — color-coded by kind */}
        <span
          className={cn(
            "shrink-0 text-[10px] tracking-wide px-1.5 py-0.5 rounded",
            isPoster
              ? "bg-amber-500/10 text-amber-600 dark:text-amber-400"
              : "bg-secondary text-muted-foreground"
          )}
        >
          {KIND_LABEL[result.kind]}
        </span>
      </button>
    </li>
  );
}

// ── Sheet body ────────────────────────────────────────────────────────────────

function SearchSheetBody({ onClose }: { onClose: () => void }) {
  const [query, setQuery] = React.useState("");
  const [results, setResults] = React.useState<SearchResult[]>([]);
  const [loading, setLoading] = React.useState(false);
  const inputRef = React.useRef<HTMLInputElement>(null);

  const debouncedQuery = useDebounce(query, 250);

  // Focus input when sheet opens
  React.useEffect(() => {
    const t = setTimeout(() => inputRef.current?.focus(), 80);
    return () => clearTimeout(t);
  }, []);

  React.useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    globalSearch(debouncedQuery).then((res) => {
      if (!cancelled) {
        setResults(res);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [debouncedQuery]);

  return (
    <div className="flex flex-col min-h-0">
      {/* Input */}
      <div className="px-4 pb-3 border-b border-border">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground pointer-events-none" />
          <Input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="搜尋分類 / 作品 / 群組 / 海報…"
            className="pl-9 h-10"
          />
          {loading && (
            <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground animate-spin" />
          )}
        </div>
      </div>

      {/* Results */}
      {results.length > 0 ? (
        <ul className="overflow-y-auto divide-y divide-border">
          {results.map((r) => (
            <ResultRow key={`${r.kind}:${r.id}`} result={r} onNavigate={onClose} />
          ))}
        </ul>
      ) : debouncedQuery.trim() && !loading ? (
        <div className="py-12 text-center text-muted-foreground text-sm">
          找不到「{debouncedQuery}」
        </div>
      ) : !debouncedQuery.trim() ? (
        <div className="py-10 text-center text-muted-foreground text-sm">
          輸入關鍵字搜尋分類、作品、群組或海報
        </div>
      ) : null}
    </div>
  );
}

// ── Main export ───────────────────────────────────────────────────────────────

export default function GlobalSearch() {
  const [open, setOpen] = React.useState(false);

  return (
    <>
      {/* Trigger button */}
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors rounded-md px-2 py-1.5 hover:bg-muted/50 -ml-1"
        aria-label="搜尋"
      >
        <Search className="w-4 h-4" />
        <span className="hidden sm:inline">搜尋</span>
      </button>

      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="bottom" className="max-h-[80dvh] flex flex-col p-0 gap-0">
          <SheetHeader className="px-4 pt-4 pb-3 shrink-0">
            <SheetTitle>搜尋</SheetTitle>
          </SheetHeader>
          {open && <SearchSheetBody onClose={() => setOpen(false)} />}
        </SheetContent>
      </Sheet>
    </>
  );
}
