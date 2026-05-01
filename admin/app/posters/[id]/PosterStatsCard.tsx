import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { CheckCircle2, Clock, Archive, XCircle, Eye, Heart, EyeOff } from "lucide-react";

/**
 * Read-only system fields shown at the bottom of the poster edit page.
 * Per partner spec (#19-#26): admin can see who created / when / view +
 * favorite counts / current visibility, but doesn't EDIT these here.
 *
 * Visibility (is_public) IS editable but lives in the metadata form
 * above (so it saves alongside other patches via updatePosterMetadata).
 * This card just displays the current state.
 */

const STATUS_LABELS: Record<string, { label: string; color: "approved" | "pending" | "rejected" | "archived" }> = {
  approved: { label: "已通過", color: "approved" },
  pending:  { label: "待審核", color: "pending" },
  rejected: { label: "已退件", color: "rejected" },
  archived: { label: "已封存", color: "archived" },
};

const STATUS_CLASSES = {
  approved: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border-emerald-500/20",
  pending:  "bg-amber-500/10 text-amber-700 dark:text-amber-400 border-amber-500/20",
  rejected: "bg-destructive/10 text-destructive border-destructive/20",
  archived: "bg-muted text-muted-foreground border-border",
} as const;

const STATUS_ICONS = {
  approved: CheckCircle2,
  pending: Clock,
  rejected: XCircle,
  archived: Archive,
};

function formatTime(iso: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  // YYYY-MM-DD HH:mm in local time. Drop seconds — admin doesn't need
  // sub-minute precision for forensics.
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const min = String(d.getMinutes()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
}

export default function PosterStatsCard({
  status,
  isPublic,
  createdAt,
  updatedAt,
  uploaderName,
  updaterName,
  viewCount,
  favoriteCount,
}: {
  status: string;
  isPublic: boolean | null;
  createdAt: string;
  updatedAt: string | null;
  uploaderName: string | null;
  updaterName: string | null;
  viewCount: number;
  favoriteCount: number;
}) {
  const statusInfo = STATUS_LABELS[status] ?? { label: status, color: "archived" as const };
  const StatusIcon = STATUS_ICONS[statusInfo.color];

  return (
    <Card>
      <CardContent className="p-4 space-y-3">
        {/* Status + visibility chips on top row */}
        <div className="flex flex-wrap gap-2 pb-2 border-b border-border">
          <span
            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs border ${STATUS_CLASSES[statusInfo.color]}`}
          >
            <StatusIcon className="w-3 h-3" />
            {statusInfo.label}
          </span>
          <Badge
            variant={isPublic === false ? "muted" : "secondary"}
            className="gap-1"
          >
            {isPublic === false ? (
              <>
                <EyeOff className="w-3 h-3" />
                未公開
              </>
            ) : (
              <>
                <Eye className="w-3 h-3" />
                已公開
              </>
            )}
          </Badge>
        </div>

        {/* Counts row */}
        <div className="grid grid-cols-2 gap-3 text-sm">
          <div className="flex items-center gap-2">
            <Eye className="w-4 h-4 text-muted-foreground" />
            <span className="text-muted-foreground">瀏覽數</span>
            <span className="font-medium">{viewCount.toLocaleString()}</span>
          </div>
          <div className="flex items-center gap-2">
            <Heart className="w-4 h-4 text-muted-foreground" />
            <span className="text-muted-foreground">收藏數</span>
            <span className="font-medium">{favoriteCount.toLocaleString()}</span>
          </div>
        </div>

        {/* Audit / timeline rows */}
        <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-2 text-sm pt-2 border-t border-border">
          <div className="flex justify-between gap-2">
            <dt className="text-muted-foreground">建立者</dt>
            <dd className="font-medium truncate">{uploaderName ?? "—"}</dd>
          </div>
          <div className="flex justify-between gap-2">
            <dt className="text-muted-foreground">建立時間</dt>
            <dd className="font-medium tabular-nums">{formatTime(createdAt)}</dd>
          </div>
          <div className="flex justify-between gap-2">
            <dt className="text-muted-foreground">更新者</dt>
            <dd className="font-medium truncate">{updaterName ?? "—"}</dd>
          </div>
          <div className="flex justify-between gap-2">
            <dt className="text-muted-foreground">更新時間</dt>
            <dd className="font-medium tabular-nums">{formatTime(updatedAt)}</dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  );
}
