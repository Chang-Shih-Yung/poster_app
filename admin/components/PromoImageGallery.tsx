"use client";

import * as React from "react";
import { ImagePlus, X, Loader2, AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { uploadPromoImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import {
  listPromoImages,
  addPromoImage,
  removePromoImage,
  type PromoImage,
} from "@/app/actions/poster-promo-images";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { cn } from "@/lib/utils";

/**
 * Spec #18 海報發行資訊 — 多張版本。Edit-page only（建立海報後才能用）。
 *
 * UX：
 *   - 縮圖 grid（每格 4:3），移除按鈕在右上
 *   - 一個「+ 新增」格在尾，點下開系統檔案選取（多選）
 *   - 選好後逐張壓縮上傳到 Storage、addPromoImage 寫一筆子表 row
 *   - 失敗的個別檔案 toast.warning，其他繼續
 *   - 移除有 AlertDialog confirm（避免誤觸）
 *   - 拖曳重排不在這版（之後加 reorderPromoImages 即可）
 *
 * 同 PosterCombinationField 模式：自己呼 server action，不經 form submit。
 * Create mode（posterId=null）顯示 disabled 提示。
 */
export default function PromoImageGallery({
  posterId,
  disabled,
}: {
  posterId: string | null;
  disabled?: boolean;
}) {
  const fileRef = React.useRef<HTMLInputElement>(null);
  const [images, setImages] = React.useState<PromoImage[]>([]);
  const [loaded, setLoaded] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [progress, setProgress] = React.useState<string | null>(null);
  const [removeTarget, setRemoveTarget] = React.useState<PromoImage | null>(
    null
  );

  const refresh = React.useCallback(async () => {
    if (!posterId) return;
    const r = await listPromoImages(posterId);
    if (r.ok) {
      setImages(r.data);
      setLoaded(true);
    }
  }, [posterId]);

  React.useEffect(() => {
    if (posterId) void refresh();
  }, [posterId, refresh]);

  async function onFilesChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    if (!posterId || files.length === 0) return;
    setBusy(true);

    let okCount = 0;
    let failCount = 0;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      try {
        setProgress(`${i + 1} / ${files.length} 處理中…`);

        // HEIC pre-convert (lazy heic2any)
        let working = file;
        if (
          file.type === "image/heic" ||
          file.type === "image/heif" ||
          /\.(heic|heif)$/i.test(file.name)
        ) {
          const heic2any = (await import("heic2any")).default;
          const converted = (await heic2any({
            blob: file,
            toType: "image/jpeg",
            quality: 0.9,
          })) as Blob;
          working = new File(
            [converted],
            file.name.replace(/\.(heic|heif)$/i, ".jpg"),
            { type: "image/jpeg" }
          );
        }

        const uploaded = await uploadPromoImage(working, posterId);
        const r = await addPromoImage(posterId, {
          image_url: uploaded.promoImageUrl,
          thumbnail_url: uploaded.promoThumbnailUrl,
        });
        if (!r.ok) throw new Error(r.error);
        okCount++;
      } catch (err) {
        failCount++;
        // Don't break the loop — admin probably uploaded 5 files and 1
        // bad file shouldn't kill the other 4.
        console.error("[promo gallery] upload failed", err);
      }
    }

    setBusy(false);
    setProgress(null);
    if (fileRef.current) fileRef.current.value = "";

    if (okCount > 0 && failCount === 0) {
      toast.success(`已新增 ${okCount} 張宣傳圖片`);
    } else if (okCount > 0 && failCount > 0) {
      toast.warning(`${okCount} 張成功、${failCount} 張失敗`);
    } else if (failCount > 0) {
      toast.error(`${failCount} 張全部上傳失敗`);
    }

    await refresh();
  }

  async function confirmRemove() {
    const t = removeTarget;
    if (!t) return;
    setRemoveTarget(null);
    setBusy(true);
    const r = await removePromoImage(t.id);
    setBusy(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success("已移除宣傳圖片");
    await refresh();
  }

  if (!posterId) {
    return (
      <div className="text-sm text-muted-foreground rounded-md border border-dashed border-input bg-secondary/30 p-3">
        建立海報後，回到編輯頁就能上傳宣傳圖片（可多張）。
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
        {/* Existing images */}
        {images.map((img) => (
          <div
            key={img.id}
            className="relative group aspect-[4/3] rounded-lg overflow-hidden border border-border bg-black/30"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={img.thumbnail_url}
              alt=""
              className="w-full h-full object-contain"
            />
            <button
              type="button"
              onClick={() => setRemoveTarget(img)}
              disabled={busy || disabled}
              className={cn(
                "absolute top-1.5 right-1.5 w-7 h-7 rounded-full",
                "bg-background/80 hover:bg-destructive hover:text-destructive-foreground",
                "border border-border flex items-center justify-center",
                "transition-colors backdrop-blur",
                "opacity-0 group-hover:opacity-100 focus:opacity-100"
              )}
              aria-label="移除這張宣傳圖片"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ))}

        {/* Add slot */}
        <button
          type="button"
          onClick={() => !busy && fileRef.current?.click()}
          disabled={busy || disabled}
          className={cn(
            "aspect-[4/3] rounded-lg border-2 border-dashed",
            "flex flex-col items-center justify-center gap-1",
            "text-muted-foreground transition-colors",
            busy || disabled
              ? "opacity-60"
              : "border-input hover:border-primary hover:text-primary hover:bg-secondary/40"
          )}
          aria-label="上傳宣傳圖片"
        >
          {busy ? (
            <>
              <Loader2 className="w-6 h-6 animate-spin" />
              <span className="text-xs">{progress ?? "處理中…"}</span>
            </>
          ) : (
            <>
              <ImagePlus className="w-7 h-7" strokeWidth={1.5} />
              <span className="text-xs">
                {images.length === 0 ? "上傳宣傳圖片（可多張）" : "新增一張"}
              </span>
            </>
          )}
        </button>
      </div>

      {!loaded && images.length === 0 && (
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Loader2 className="w-3 h-3 animate-spin" />
          載入中…
        </div>
      )}

      {/* Hidden file input — multi-select enabled */}
      <input
        ref={fileRef}
        type="file"
        multiple
        accept="image/jpeg,image/png,image/webp,image/gif,image/heic,image/heif,.heic,.heif"
        onChange={onFilesChange}
        className="hidden"
        disabled={busy || disabled}
      />

      <p className="text-xs text-muted-foreground">
        影院 DM、IG 活動圖、票券優惠等。可多張，HEIC 自動轉 JPEG。
      </p>

      <AlertDialog
        open={removeTarget != null}
        onOpenChange={(v) => {
          if (!v) setRemoveTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>移除這張宣傳圖片？</AlertDialogTitle>
            <AlertDialogDescription>
              只解除這張海報跟宣傳圖的連結，Storage 檔案會留著（之後可重傳新版）。
              {removeTarget && (
                <span className="flex items-start gap-2 mt-3 text-xs text-destructive">
                  <AlertTriangle className="w-3.5 h-3.5 mt-0.5 shrink-0" />
                  此操作無法 undo。
                </span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setRemoveTarget(null)}>
              取消
            </AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={confirmRemove}
            >
              確認移除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
