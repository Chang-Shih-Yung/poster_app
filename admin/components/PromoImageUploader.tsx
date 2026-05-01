"use client";

import { useRef, useState } from "react";
import { ImagePlus, AlertTriangle, X } from "lucide-react";
import { toast } from "sonner";
import { uploadPromoImage } from "@/lib/imageUpload";
import { describeError } from "@/lib/errors";
import { attachPromoImage, detachPromoImage } from "@/app/actions/posters";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
 * Optional secondary image slot on a poster — the cinema flyer / IG
 * promo / ticket bundle ad that announces the poster's distribution.
 *
 * Same upload pipeline as the main poster (heic2any client conversion,
 * compression, two-tier main+thumb), minus blurhash. Wider aspect (4:3)
 * because promo flyers are usually landscape OR square; A3 portrait
 * flyers are also common so we don't lock to one shape.
 */
export default function PromoImageUploader({
  posterId,
  currentImageUrl,
}: {
  posterId: string;
  currentImageUrl: string | null;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    setBusy(true);
    try {
      // HEIC pre-convert. Mirrors the main poster pipeline; lazy import
      // keeps the heic2any blob out of the initial bundle for non-Apple
      // visitors who'll never need it.
      let workingFile = file;
      const isHeic =
        file.type === "image/heic" ||
        file.type === "image/heif" ||
        /\.(heic|heif)$/i.test(file.name);
      if (isHeic) {
        setProgress("HEIC 轉檔中…");
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
      }

      setProgress("壓縮中…");
      const result = await uploadPromoImage(workingFile, posterId);
      setProgress("寫入 DB…");
      const r = await attachPromoImage(posterId, {
        promo_image_url: result.promoImageUrl,
        promo_thumbnail_url: result.promoThumbnailUrl,
      });
      if (!r.ok) throw new Error(r.error);
      toast.success("已更新宣傳圖片");
      setProgress("完成");
    } catch (err) {
      setError(describeError(err));
    } finally {
      setBusy(false);
      setProgress(null);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  async function onRemove() {
    setConfirmRemove(false);
    setError(null);
    setBusy(true);
    try {
      const r = await detachPromoImage(posterId);
      if (!r.ok) throw new Error(r.error);
      toast.success("已移除宣傳圖片");
    } catch (err) {
      setError(describeError(err));
    } finally {
      setBusy(false);
    }
  }

  const hasImage = !!currentImageUrl;

  return (
    <div className="space-y-3">
      <button
        type="button"
        onClick={() => !busy && fileRef.current?.click()}
        disabled={busy}
        className={cn(
          "relative w-full aspect-[4/3] rounded-xl overflow-hidden border text-foreground",
          hasImage
            ? "border-border"
            : "border-dashed border-input bg-secondary/40",
          busy ? "opacity-60" : "active:opacity-80 hover:bg-secondary/60 transition-colors"
        )}
      >
        {hasImage ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={currentImageUrl!}
            alt="宣傳圖片"
            className="w-full h-full object-contain bg-black/30"
          />
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground p-4 text-center">
            <ImagePlus className="w-9 h-9 mb-2" strokeWidth={1.5} />
            <div className="text-sm font-medium text-foreground">
              點此上傳宣傳圖片
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              影院 DM、IG 活動圖、票券優惠等取得方式佐證
            </div>
            <div className="text-xs text-muted-foreground mt-0.5">
              支援 JPG / PNG / HEIC，自動壓縮
            </div>
          </div>
        )}

        {busy && (
          <div className="absolute inset-0 bg-background/80 flex items-center justify-center">
            <div className="text-sm">{progress ?? "處理中…"}</div>
          </div>
        )}
      </button>

      <input
        ref={fileRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif,image/heic,image/heif,.heic,.heif"
        onChange={onFileChange}
        className="hidden"
        disabled={busy}
      />

      {hasImage && (
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() => fileRef.current?.click()}
            disabled={busy}
            className="flex-1"
          >
            換一張
          </Button>
          <Button
            variant="outline"
            onClick={() => setConfirmRemove(true)}
            disabled={busy}
            className="text-destructive hover:text-destructive"
          >
            <X className="w-4 h-4" />
            移除
          </Button>
        </div>
      )}

      {error && (
        <Card className="border-destructive/40 bg-destructive/10">
          <CardContent className="p-3 flex items-start gap-2 text-sm text-destructive">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>上傳失敗：{error}</span>
          </CardContent>
        </Card>
      )}

      <AlertDialog open={confirmRemove} onOpenChange={setConfirmRemove}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>移除宣傳圖片？</AlertDialogTitle>
            <AlertDialogDescription>
              只清除這張海報跟宣傳圖的關聯，Storage 的檔案會留著（之後可重傳新版）。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={onRemove}
            >
              確認移除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
