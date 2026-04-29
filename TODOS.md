# TODOS

長尾任務清單。優先級用 P1（重要）/ P2（次要）/ P3（可有可無）標。

完成後刪掉條目，不留歷史 — Git log 才是歷史。

---

## P2 — 海報批量新增的延伸打磨

### 進度條 + 取消上傳
**What:** 批量送出時，整個流程顯示一個整體進度條（X/N 完成），允許取消尚未開始的卡片。
**Why:** 目前每張卡片各自有狀態圖示，但 20 張一起傳時看不清整體進度。建立中如果使用者後悔（例如選錯作品）只能等全部跑完。
**Pros:** 清楚回饋、可中斷；批量上限可以更安心提到 50+。
**Cons:** AbortController 串接 createPoster + uploadPosterImage + attachImage 三段，要小心半途中斷後 DB 殘留。
**Context:** `app/posters/batch/BatchImport.tsx` 的 `submitAll`。目前用 Promise.all。改成 `pLimit(3)` 加 AbortController 串入每張卡片。
**Depends on:** 無。

### 「離開頁面有未存內容」用 router blocker 而非 beforeunload
**What:** Next.js App Router 內部的「左滑返回」/`router.back()` 不會觸發 `beforeunload`。要用 `useRouter().beforePopState` 或 `<Link>` 攔截。
**Why:** 目前 `beforeunload` 只擋瀏覽器層的 unload（重新整理、關 tab），App Router 內部跳轉直接通過。
**Context:** `BatchImport.tsx` 已加 `beforeunload` listener，要再加 router-level guard。Next 14+ 沒有官方 API，社群常見作法是 hijack `<Link>` + history listener。
**Pros:** 防止誤觸 BottomTabBar 飛走 5 張海報的 metadata。
**Cons:** Next 沒官方 API，第三方 hack 跨版本可能壞。

### HEIC client-side 自動轉 JPEG
**What:** 用 `heic2any` 或 wasm 把使用者選的 HEIC 在瀏覽器轉成 JPEG，desktop Chrome 也能處理。
**Why:** 目前 desktop Chrome 直接拒絕 HEIC，使用者必須回 iPhone 用 Safari 或先匯出。
**Context:** `_shared.ts` 的 `rejectionReason`。改成在 `addFiles` 時偵測 HEIC，跑 `heic2any({ blob: file, toType: "image/jpeg" })` 後當 JPEG 處理。
**Cons:** heic2any 1MB+ bundle、處理大照片慢（一張 4-8 秒）。
**Pros:** 完全消除「手機照片需要先轉檔」的痛點。
**Recommendation:** 等收到第二位回報的 admin 才做。

---

## P3 — 健全性

### WorkPicker 支援大量資料
**What:** 1000+ works 時改用 virtualized list（react-window）。
**Why:** cmdk 預設每次按鍵全 list 重 filter，目前 ~50 部作品沒事。資料量到 1000 時下拉開啟會有明顯卡頓。
**Context:** `components/ui/searchable-select.tsx`。
**Recommendation:** 等實際慢起來再做。

### `submitAll` Promise.all → pLimit(3)
**What:** 限制平行上傳 concurrency 到 3。
**Why:** 一次選 20 張，目前 60 個並行 query（20 createPoster + 20 upload + 20 attachImage）瞬間打 Supabase。
**Context:** `BatchImport.tsx submitAll`。
**Recommendation:** 等收到 rate-limit 錯誤再做。

### CINEMA_NAMES 枚舉接到表單
**What:** `lib/enums.ts` 已定義 CINEMA_NAMES，但 PosterForm/BatchImport 通路名稱還是 free text Input。
**Why:** 結構化才能做後續分析（哪家影城最多獨家版）。
**Context:** `channel_name` 欄位。當 `channel_category === "cinema"` 時切換成 Select。

---

## P3 — Schema / 資料

### 把 `mini` 從 size_type_enum 真的拿掉
**What:** Postgres enum 不能 DROP VALUE，要 recreate 整個 type。
**Why:** Migration `20260429100000` 把 `mini` 的 row 全改成 `other`，但 enum 還包含 `mini`，使用者可以用 SQL 直接寫回去（不會被 admin form 接受，但理論上有可能）。
**Context:**
```sql
-- 1. 建新 enum without mini
-- 2. ALTER TABLE 改用新 enum (含 USING cast)
-- 3. DROP TYPE 舊的
-- 4. RENAME 新的
```
**Recommendation:** 沒人撞到再做。

---
