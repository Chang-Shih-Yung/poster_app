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
 * Spec #18 海報發行資訊 — 多張版本。
 *
 * 兩種 mode：
 *
 * Edit mode（posterId 已存在）：
 *   - 元件自己 fetch 既有清單，新增/移除即時呼 server action
 *   - 失敗單張不影響整批，AlertDialog 二次確認 remove
 *
 * Create mode（posterId=null + pendingFiles + onPendingChange 受控）：
 *   - 純前端 staging，沒 server call
 *   - File 暫存到 parent state，object URL 顯示縮圖
 *   - submit 後 parent 拿到新 poster id，逐張 upload + addPromoImage
 *
 * 兩種 mode UI 視覺一致 — admin 不用知道差別。
 */
export default function PromoImageGallery({
  posterId,
  disabled,
  pendingFiles,
  onPendingChange,
}: {
  /** edit mode 帶 poster id；create mode 傳 null + pendingFiles props */
  posterId: string | null;
  disabled?: boolean;
  /** Create mode 暫存的檔案陣列（受控）。Edit mode 忽略。 */
  pendingFiles?: File[];
  onPendingChange?: (next: File[]) => void;
}) {
  const isCreateMode = !posterId;
  const fileRef = React.useRef<HTMLInputElement>(null);

  // Edit mode 的 server-fetched gallery
  const [images, setImages] = React.useState<PromoImage[]>([]);
  const [busy, setBusy] = React.useState(false);
  const [progress, setProgress] = React.useState<string | null>(null);
  const [removeTarget, setRemoveTarget] = React.useState<
    { kind: "server"; image: PromoImage } | { kind: "pending"; index: number } | null
  >(null);

  const refresh = React.useCallback(async () => {
    if (!posterId) return;
    const r = await listPromoImages(posterId);
    if (r.ok) setImages(r.data);
  }, [posterId]);

  React.useEffect(() => {
    if (posterId) void refresh();
  }, [posterId, refresh]);

  // Create mode：把 pendingFiles 的 object URL 算一次（避免每 render 都建）
  const pendingPreviewUrls = React.useMemo(() => {
    if (!isCreateMode) return [];
    return (pendingFiles ?? []).map((f) => URL.createObjectURL(f));
  }, [isCreateMode, pendingFiles]);

  // Cleanup object URLs when files change / unmount.
  React.useEffect(() => {
    return () => {
      pendingPreviewUrls.forEach((u) => URL.revokeObjectURL(u));
    };
  }, [pendingPreviewUrls]);

  /** 處理 HEIC + 把 File 加入清單。 */
  async function ingestFiles(files: File[]) {
    if (files.length === 0) return;

    if (isCreateMode) {
      // Create mode：HEIC 也要先轉，這樣 staging 預覽不會壞掉，submit
      // 時再壓縮上傳。
      setBusy(true);
      const converted: File[] = [];
      for (let i = 0; i < files.length; i++) {
        setProgress(`${i + 1} / ${files.length} 處理中…`);
        const file = files[i];
        try {
          let working = file;
          if (
            file.type === "image/heic" ||
            file.type === "image/heif" ||
            /\.(heic|heif)$/i.test(file.name)
          ) {
            const heic2any = (await import("heic2any")).default;
            const blob = (await heic2any({
              blob: file,
              toType: "image/jpeg",
              quality: 0.9,
            })) as Blob;
            working = new File(
              [blob],
              file.name.replace(/\.(heic|heif)$/i, ".jpg"),
              { type: "image/jpeg" }
            );
          }
          converted.push(working);
        } catch (err) {
          console.error("[promo gallery] HEIC convert failed", err);
          toast.error(`「${file.name}」HEIC 轉檔失敗`);
        }
      }
      setBusy(false);
      setProgress(null);
      if (converted.length > 0) {
        onPendingChange?.([...(pendingFiles ?? []), ...converted]);
      }
      return;
    }

    // Edit mode：壓縮 + 上 Storage + 寫 DB（即時）
    if (!posterId) return;
    setBusy(true);
    let okCount = 0;
    let failCount = 0;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      try {
        setProgress(`${i + 1} / ${files.length} 處理中…`);

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
        console.error("[promo gallery] upload failed", err);
      }
    }
    setBusy(false);
    setProgress(null);
    if (okCount > 0 && failCount === 0) {
      toast.success(`已新增 ${okCount} 張宣傳圖片`);
    } else if (okCount > 0) {
      toast.warning(`${okCount} 張成功、${failCount} 張失敗`);
    } else {
      toast.error(`${failCount} 張全部上傳失敗`);
    }
    await refresh();
  }

  async function onFilesChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    await ingestFiles(files);
    if (fileRef.current) fileRef.current.value = "";
  }

  async function confirmRemove() {
    const t = removeTarget;
    if (!t) return;
    setRemoveTarget(null);
    if (t.kind === "pending") {
      // Create mode — 從 pending list 拔掉
      const next = (pendingFiles ?? []).filter((_, i) => i !== t.index);
      onPendingChange?.(next);
      return;
    }
    // Edit mode — 即時砍 DB row
    setBusy(true);
    const r = await removePromoImage(t.image.id);
    setBusy(false);
    if (!r.ok) {
      toast.error(r.error);
      return;
    }
    toast.success("已移除宣傳圖片");
    await refresh();
  }

  // 當前要顯示的縮圖列表（mode-aware）
  const displayItems: Array<{
    key: string;
    url: string;
    onRemove: () => void;
  }> = isCreateMode
    ? pendingPreviewUrls.map((url, idx) => ({
        key: `pending-${idx}`,
        url,
        onRemove: () =>
          setRemoveTarget({ kind: "pending", index: idx }),
      }))
    : images.map((img) => ({
        key: img.id,
        url: img.thumbnail_url,
        onRemove: () => setRemoveTarget({ kind: "server", image: img }),
      }));

  const totalCount = displayItems.length;

  return (
    <div className="space-y-2">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
        {displayItems.map((item) => (
          <div
            key={item.key}
            className="relative group aspect-[4/3] rounded-lg overflow-hidden border border-border bg-black/30"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={item.url}
              alt=""
              className="w-full h-full object-contain"
            />
            <button
              type="button"
              onClick={item.onRemove}
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
                {totalCount === 0 ? "上傳宣傳圖片（可多張）" : "新增一張"}
              </span>
            </>
          )}
        </button>
      </div>

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
              {removeTarget?.kind === "pending"
                ? "這張還沒上傳，移除等於放棄不送出。"
                : "只解除這張海報跟宣傳圖的連結，Storage 檔案會留著（之後可重傳新版）。"}
              <span className="flex items-start gap-2 mt-3 text-xs text-destructive">
                <AlertTriangle className="w-3.5 h-3.5 mt-0.5 shrink-0" />
                此操作無法 undo。
              </span>
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
