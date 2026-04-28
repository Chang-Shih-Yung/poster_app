# Admin TODO list

Living follow-up list. Items marked **[done]** are merged; the rest are still
open.

---

## 1. `posters` legacy NOT NULL columns — **[done]**

`title`, `poster_url`, `uploader_id` are nullable on the schema and on
`Poster.fromRow`. Triggers still set sensible defaults (auth.uid() for
uploader_id; poster_name for title) but the columns no longer lie about
the data contract — `poster_url IS NULL` now meaningfully says "no
real image yet" alongside `is_placeholder=true`.

Flutter readers in 9 sites updated to fall back gracefully:
`p.title ?? p.posterName ?? '(未命名)'`, `p.posterUrl ?? ''`, and
guarded calls (uploader badge skipped when `uploaderId` is null;
fullscreen viewer disabled for placeholder posters).

**Migrations landed:**
- `20260428100200_posters_legacy_defaults.sql` (triggers)
- `20260428110000_drop_posters_legacy_not_null.sql` (drop NOT NULL)

---

## 2. Cursor pagination for `/works` and `/tree/studio/[studio]` — **[done]**

Server-rendered first batch of 50 rows; "載入更多" button calls the
`loadWorksPage` server action and appends the next 50. Order is
`created_at DESC, id DESC`; cursor is the trailing row's `created_at`. After
any mutation, `revalidatePath` re-renders the page → the accumulated batches
reset to the fresh first page (intentional — server is more authoritative
than the client's cached append history).

---

## 3. Postgres function for recursive group counts — **[done]**

`public.get_group_recursive_counts(p_work_id uuid)` returns
`(group_id, total)` per group. `/tree/work/[id]` and `/tree/group/[id]`
call it via `supabase.rpc(...)` instead of pulling every group + every
poster down to the client. The TS implementation in `lib/groupTree.ts`
stays as the unit-test oracle.

**Migration landed:** `20260428100100_get_group_recursive_counts.sql`

---

## 4. E2E tests for the golden path

Playwright (or `/qa`) covering: log in → create studio → add work → add
group → add poster → upload image → see thumbnail. The user is planning to
drive this via gstack `/qa` against a local `:3000` dev server (Google
OAuth blocks the side preview).

**Open.**

---

## 6. 上傳流程升級（/plan-design-review D3+D5+D6+D7）

**[done]**

### 背景

管理員補圖時每張需要額外 2-3 個 tap（上傳完 → 手動回佇列 → 再點下一張）。50 張就是 150 個無謂操作。此外上傳期間介面完全沉默，無法分辨是否在進行中。

### 要做的事

1. **`useImageAttach` 加 loading 狀態：** 回傳 `uploadingId: string | null`；呼叫端（WorkClient、GroupClient）把它傳給對應的 TreeRow，TreeRow 在 `uploadingId === poster.id` 時用 `Loader2` 取代 `MoreVertical`。

2. **上傳成功後 sonner toast：** `handleFile` 結束時呼叫 `onSuccess?.(target.id)`；WorkClient / GroupClient 的 callback 顯示 `toast.success('圖片已更新')` 並呼叫 `router.refresh()`（讓縮圖即時更新）。

3. **`/posters/[id]` 上傳後自動導往下一張：** `PosterImageUploader` 的 `onSuccess` 在上傳完成後呼叫 Server Action 查詢同作品內下一個 `is_placeholder=true` 的 poster（`work_id = current AND id != current ORDER BY created_at ASC LIMIT 1`）。有則 `router.push('/posters/' + nextId)`；無則 `router.push('/upload-queue')`。

4. **`/upload-queue` 加進度計數：** 頁面標題改為「待補圖（N 張）」，小字「還剩 N 張未上傳」。N = 0 時顯示綠色空狀態「所有海報都已上傳真實圖片 ✓」（原文字保留，但改為綠色字加 checkmark）。

**依賴：** `useImageAttach.ts`, `WorkClient.tsx`, `GroupClient.tsx`, `PosterImageUploader.tsx`, `upload-queue/page.tsx`, `posters/[id]/page.tsx`

**預估：** 2-3 小時

---

## 7. 將 alert()/confirm() 全面替換為 shadcn UI（D4+D8）

**[done]**

### 背景

`clientActions.ts` 的 `runAction` 預設錯誤處理是 `alert(r.error)`；`ItemActionsBundle` 的刪除確認使用 `window.confirm()`。兩者都是原生瀏覽器 API——iOS Safari PWA 模式下 `confirm()` 有機率被忽略，導致刪除動作跳過確認直接執行。

### 要做的事

1. **`app/layout.tsx`** 加 `import { Toaster } from 'sonner'` 並在 `<body>` 內加 `<Toaster />`。

2. **`clientActions.ts`** 的 `runAction` else-branch：`alert(r.error)` → `toast.error(r.error)`（加 `import { toast } from 'sonner'`）。

3. **`ItemActionsBundle.tsx`** 加一層確認狀態：
   - 新增 `confirmState: { action: ItemInstantAction<T>; item: T } | null` state。
   - 點擊有 `confirm` 屬性的 instant action → 關閉 SheetMenu → 設定 `confirmState`。
   - 渲染一個 `<AlertDialog>` 讀取 `confirmState.action.confirm(item)` 作為訊息，確認後才呼叫 `runAction`。

**依賴：** `clientActions.ts`, `ItemActionsBundle.tsx`, `app/layout.tsx`

**預估：** 1 小時

---

## 8. Dashboard 重設（D2）

**[done]**

### 背景

首頁快速操作列（瀏覽目錄、新增作品、新增海報、待補真圖佇列）與底部 tab bar 完全重複。「待補真圖 N 張」是靜態數字，點不進去。Dashboard 應呈現「今天最需要做什麼」而非站地圖。

### 要做的事

`app/page.tsx` 改為三個區塊：

1. **Urgent amber banner**（僅在 `placeholderCount > 0` 時顯示）：`<Link href="/upload-queue">` 包整個 amber Card，顯示「⚠ 待補圖 N 張 — 點此進入佇列 →」。

2. **3 個 stat card**（現有，保留）：作品數、海報數、已補圖（= 總 - 待補）。

3. **最近新增 5 張海報列表**：新增一個 query `SELECT id, poster_name, thumbnail_url, works(title_zh) FROM posters ORDER BY created_at DESC LIMIT 5`。顯示為 Card 列表，每列有縮圖（10×12 rounded）、海報名、作品名、時間 badge。

**移除：** 快速操作 `<Card>` 整個區塊。

**依賴：** `app/page.tsx`

**預估：** 1-2 小時

---

## 9. Tree row 加待補圖遞迴計數（D1+D11）

**[done]**

### 背景

管理員在 `/tree/work/[id]` 或 `/tree/group/[id]` 瀏覽時，看不出哪個群組下還有待補圖的海報，必須另開 `/upload-queue` 才知道進度。

### 要做的事

1. **DB migration**：擴充 `get_group_recursive_counts(p_work_id)` 加一欄 `placeholder_total int`，計算各群組遞迴內 `is_placeholder = true` 的海報數。

2. **`/tree/work/[id]/page.tsx`**：RPC 回傳新欄位後傳給 `WorkClient`。

3. **`WorkClient.tsx` / `GroupClient.tsx`**：`Group` type 加 `placeholder_count: number`；`TreeRow` 的 `subtitle` 改為「N 張 · M 待補」（M > 0 時 amber 色）；`WorkClient` 的 subtitle 也加「N 張直屬海報 · M 待補」。

4. **`/tree/studio/[studio]/StudioClient.tsx`**：`Work` row 的 subtitle 改為「N 張海報 · M 待補」（需要在 `loadWorksPage` / studio page query 加 `placeholder_count`）。

**依賴：** `supabase/migrations/`, `tree/work/[id]/page.tsx`, `WorkClient.tsx`, `GroupClient.tsx`, `StudioClient.tsx`

**預估：** 2 小時（含 migration）

---

## 10. Tree 頁面層級內篩選（D9）

**[done]**

### 背景

作品或群組超過 20 筆時靠滾動找特定項目效率很低。由於 tree 頁面是 SSR，資料已在 client，不需要額外 DB query。

### 要做的事

在 `StudioClient`、`WorkClient`、`GroupClient` 的列表頂部加一個 `<Input placeholder="搜尋…">` input。用 `useState(filterText)` 即時過濾 `items` 陣列（`title_zh`、`name`、`poster_name` 包含關鍵字）。filter 為空時顯示全部。

**實作細節：**
- Input 只在 `items.length >= 8` 時才渲染（少量時不需要）。
- 搜尋框 focus 後 keyboard 不擋 Sheet 開關（Radix Sheet 用 `pointer-events: none` 管理，不影響 input）。
- filter 後 count 為 0 時顯示「找不到「xxx」。」

**依賴：** `StudiosClient.tsx`, `WorkClient.tsx`, `GroupClient.tsx`

**預估：** 1 小時

---

## 11. 觸控目標與空狀態 CTA 小修（TODO F）

**[done]**

### 要做的事

1. `TreeRow.tsx`：`⋯` 按鈕從 `w-10 h-10`（40px）改為 `w-11 h-11`（44px），符合 Apple HIG 最小觸控目標規範。

2. 各頁空狀態文字統一加 CTA hint：
   - `GroupClient`：「這個群組還是空的。」→「這個群組還是空的。點右下的 + 開始新增。」
   - `WorkClient`：「這個作品還沒有任何群組或海報。」→「這個作品還沒有任何群組或海報。點右下的 + 開始新增。」

**預估：** 15 分鐘

---

## 5. Audit trail for destructive actions — **[done]**

`admin_audit_log` table + `logAudit()` helper in `app/actions/_internal.ts`.
Every rename / delete / kind-change / studio-rename / image-attach writes a
row with `(admin_user_id, admin_email, action, target_kind, target_id,
payload, created_at)`. Audit writes are fire-and-forget — a slow audit
insert never blocks the user-visible mutation, and audit failures log to
the server console rather than failing the action.

**Migration landed:** `20260428100000_admin_audit_log.sql`
**RLS:** admin can read own rows; service-role bypass for the writes.
**Open follow-up:** retention policy (right now rows accumulate forever).

---

## 12. 樹狀圖拖拉換層 / 排序

**Open.**

### 背景

目前群組和海報的層級只能透過「刪掉重建」來改變。Admin 希望像 Google 雲端硬碟一樣，長按一個資料夾或檔案，直接拖到目標層級放開。

### 資料層支援（已就緒）

- 移動海報：`UPDATE posters SET parent_group_id = $newGroupId WHERE id = $posterId`（null = 直屬作品層）
- 移動群組：`UPDATE poster_groups SET parent_group_id = $newParentId WHERE id = $groupId`（null = 作品頂層）
- 排序：`poster_groups.display_order` 欄位已存在（目前全為 0）；`posters` 尚無 `display_order` 欄位，需加。

### 要做的事

1. **Server Action `moveItem`**（`app/actions/groups.ts` 或新檔）
   - `moveGroup(id, newParentGroupId: string | null)` — 需驗證目標不是自己的後代（防循環）。
   - `movePoster(id, newParentGroupId: string | null)` — 直接更新。
   - `reorderItems(items: { kind: 'group' | 'poster', id: string, order: number }[])` — 批量更新 display_order。

2. **Migration**：`posters` 加 `display_order int not null default 0` + index。

3. **前端套件**：`@dnd-kit/core` + `@dnd-kit/sortable`（shadcn 生態、支援觸控、tree 拖拉有 preset）。

4. **UI 互動**：
   - 長按 TreeRow → 進入「拖拉模式」（row 出現抓取手勢、輕微縮放提示）。
   - 拖拉中：目標 drop zone 高亮（淡 amber 背景 + 上/下邊框線）。
   - 跨層移動：拖到頁面邊緣 → 自動捲動或切換到上一層。
   - 放開 → 呼叫 Server Action → optimistic update（先改 local state，失敗再 rollback）。

5. **防呆**：群組不能拖進自己的子孫（前端 UI 灰掉 + server 端 check）。

### 範圍邊界
- 本 TODO **不含**跨作品移動（海報換 `work_id`）——那需要額外的 metadata 決策。
- 排序持久化（`display_order`）需要 migration；如果先只做「換層」不做「排序」，migration 可延後。

**預估：** 跨層拖拉（不含排序）1 天；加上排序 +半天。
**依賴：** `app/actions/groups.ts`, `WorkClient.tsx`, `GroupClient.tsx`, `@dnd-kit/core`
