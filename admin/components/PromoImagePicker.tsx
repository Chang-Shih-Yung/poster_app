"use client";

import * as React from "react";
import { ImagePlus, X, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * Inline form-field picker for a poster's promo image (cinema flyer /
 * IG campaign / ticket bundle ad). Conceptually just one more field on
 * the poster, like 區域 / 尺寸 / 發行年份 — not a special post-creation
 * widget.
 *
 * Holds NO file state of its own. The parent form owns:
 *   - `file`              the newly picked File (overrides existing)
 *   - `markedForRemoval`  user clicked X on existing
 * Mutual logic: picking a file always wins (markedForRemoval clears).
 *
 * Submit-time decisions live in the parent — typically:
 *   if (state.file)               → uploadPromoImage + attachPromoImage
 *   else if (state.markedForRemoval && existingUrl) → detachPromoImage
 *   else                          → no-op
 *
 * The applyPromoImageChange() helper in lib/imageUpload encapsulates
 * that whole branch so both PosterForm and BatchImport stay simple.
 */

export type PromoImagePickerState = {
  file: File | null;
  markedForRemoval: boolean;
};

export const EMPTY_PROMO_STATE: PromoImagePickerState = {
  file: null,
  markedForRemoval: false,
};

export default function PromoImagePicker({
  existingUrl,
  state,
  onChange,
  disabled,
  /** Smaller layout (single rectangular row) for use inside batch DraftCard
   *  where vertical space is tight. Default false renders the larger
   *  4:3 box used by PosterForm. */
  compact,
}: {
  existingUrl: string | null;
  state: PromoImagePickerState;
  onChange: (s: PromoImagePickerState) => void;
  disabled?: boolean;
  compact?: boolean;
}) {
  const fileRef = React.useRef<HTMLInputElement>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [pendingPreview, setPendingPreview] = React.useState<string | null>(null);

  // Manage the object URL lifecycle for the pending file preview. Revoked
  // when the picker unmounts or the file changes — otherwise we leak blob
  // URLs every time the user re-picks.
  React.useEffect(() => {
    if (!state.file) {
      setPendingPreview(null);
      return;
    }
    const url = URL.createObjectURL(state.file);
    setPendingPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [state.file]);

  const showExisting = !state.file && !state.markedForRemoval && !!existingUrl;
  const showPending = !!state.file;
  const displayUrl = showPending ? pendingPreview : showExisting ? existingUrl : null;

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);

    // HEIC pre-convert mirrors the main poster pipeline. Heavy import
    // is lazy so non-Apple users don't pay for it.
    let workingFile = file;
    const isHeic =
      file.type === "image/heic" ||
      file.type === "image/heif" ||
      /\.(heic|heif)$/i.test(file.name);
    if (isHeic) {
      try {
        const heic2any = (await import("heic2any")).default;
        const converted = (await heic2any({
          blob: file,
          toType: "image/jpeg",
          quality: 0.9,
        })) as Blob;
        workingFile = new File(
          [converted],
          file.name.replace(/\.(heic|heif)$/i, ".jpg"),
          { type: "image/jpeg" }
        );
      } catch (err) {
        setError(
          `HEIC 轉檔失敗：${err instanceof Error ? err.message : String(err)}`
        );
        if (fileRef.current) fileRef.current.value = "";
        return;
      }
    }

    onChange({ file: workingFile, markedForRemoval: false });
    if (fileRef.current) fileRef.current.value = "";
  }

  function handleRemove() {
    if (showPending) {
      // User is bailing on the new pick — go back to whatever existed
      // before (or the empty state).
      onChange({ file: null, markedForRemoval: false });
    } else if (showExisting) {
      onChange({ file: null, markedForRemoval: true });
    }
  }

  function handleUndoRemoval() {
    onChange({ file: null, markedForRemoval: false });
  }

  const aspectClass = compact ? "aspect-[16/9]" : "aspect-[4/3]";

  return (
    <div className="space-y-2">
      <button
        type="button"
        onClick={() => !disabled && fileRef.current?.click()}
        disabled={disabled}
        className={cn(
          "relative w-full rounded-lg overflow-hidden border text-foreground",
          aspectClass,
          displayUrl
            ? "border-border"
            : "border-dashed border-input bg-secondary/40",
          state.markedForRemoval && !displayUrl && "border-destructive/40 bg-destructive/5",
          disabled
            ? "opacity-60"
            : "active:opacity-80 hover:bg-secondary/60 transition-colors"
        )}
      >
        {displayUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={displayUrl}
            alt="宣傳圖片"
            className="w-full h-full object-contain bg-black/30"
          />
        ) : state.markedForRemoval ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-destructive p-3 text-center">
            <AlertTriangle className="w-6 h-6 mb-1" strokeWidth={1.5} />
            <div className="text-xs font-medium">儲存後會移除原本的宣傳圖</div>
          </div>
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground p-3 text-center">
            <ImagePlus className={cn(compact ? "w-7 h-7 mb-1" : "w-9 h-9 mb-2")} strokeWidth={1.5} />
            <div className={cn(compact ? "text-xs" : "text-sm", "font-medium text-foreground")}>
              點此上傳宣傳圖片
            </div>
            {!compact && (
              <div className="text-xs text-muted-foreground mt-1 leading-snug">
                影院 DM、IG 活動圖、票券優惠等取得方式佐證
              </div>
            )}
          </div>
        )}
      </button>

      <input
        ref={fileRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif,image/heic,image/heif,.heic,.heif"
        onChange={onFileChange}
        className="hidden"
        disabled={disabled}
      />

      {/* Action row: only shown when there's something to undo */}
      {(showExisting || showPending || state.markedForRemoval) && (
        <div className="flex gap-2">
          {!state.markedForRemoval ? (
            <>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => fileRef.current?.click()}
                disabled={disabled}
                className="flex-1"
              >
                換一張
              </Button>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleRemove}
                disabled={disabled}
                className="text-destructive hover:text-destructive"
              >
                <X className="w-4 h-4" />
                {showPending ? "取消選擇" : "移除"}
              </Button>
            </>
          ) : (
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handleUndoRemoval}
              disabled={disabled}
              className="flex-1"
            >
              取消移除（保留原本）
            </Button>
          )}
        </div>
      )}

      {error && (
        <div className="text-xs text-destructive flex items-start gap-1.5">
          <AlertTriangle className="w-3.5 h-3.5 mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}
    </div>
  );
}
