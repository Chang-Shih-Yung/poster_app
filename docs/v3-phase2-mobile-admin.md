# v3 Phase 2 — Mobile-first admin 設計 + 圖片上傳 + 批量

**Context**: 合夥人要求「手機一目瞭然樹狀收納 + 圖片上傳 + 批量」。
Phase 1 後台是 desktop-oriented CRUD 表格；這份 plan 轉為 mobile-first
paradigm。Phase 1 migration + Google OAuth + CRUD 地基都繼續用。

**使用者分工（Henry 2026-04-24 晚補充）**:
- **Google 試算表** — Henry 自己用。技術人員喜歡表格密度、欄位一目
  瞭然、快速大量編輯。Sheet 是 Henry 的思考白板、design draft，**不**
  是 DB 的副本。
- **admin 後台（這份文件的主角）** — 合夥人用。非技術人員、手機操作
  為主、UX 要極致友善。是資料的**真相來源**（Sheet 不是）。

兩個工具**不做資料同步**。想進 DB 的東西，就在 admin 後台做。Sheet
裡的東西是 Henry 個人的筆記。

## 三個核心 UX 決策

### 1. 可收合樹（collapsible tree）取代 desktop tree view

Poster. v3 階層到 5 層：Studio → Work → Release era → Variant group
→ Poster leaf。手機單欄寬度不可能秀完整棵樹，所以用 Finder / Notion
outline 式可收合 — 點 chevron 展開 / 收合子層。

為什麼不用 drill-down（iOS Files 式）：使用者在不同分支之間切換時
要返回多次，上下文斷裂。可收合樹保留全樹結構、使用者用捲動找目標。

為什麼不用 Miller columns（macOS Finder 欄位式）：手機太窄。

**結論：可收合樹**。UI 上用縮排 + chevron + 子項數量提示。

### 2. 嚮導式批量上傳（wizard）取代 drag-drop

手機端一次多檔拖拉 UX 很爛（沒 desktop 那種檔案瀏覽器）。改用
iOS 「設定 → 引導式流程」的模式：

1. 進入「待補圖」列表（篩 `is_placeholder=true`）
2. 按「批量上傳」進嚮導
3. 一張一張逐一：顯示要填的海報 metadata → 選圖 → 自動壓縮 → 上傳
   → 下一張
4. 中途可跳過、可暫停
5. 完成後回列表看剩幾張

好處：每一步單純、進度可見、手機螢幕夠用、失敗可重試。

### 3. 長按多選（long-press to select）

iOS / Android 標準 bulk UX。單擊 = 主要動作（進編輯）。長按 = 進
選取模式（Checkbox 出現 / header 換成「已選 N 張」/ 底部 action bar
浮出）。退出選取模式：header 的 ✕。

支援批量操作：
- 🗑️ 刪除（soft delete）
- 📤 批量上傳（跳轉嚮導）
- 📁 搬到其他 group（picker）

## 實作分解

### 2.1 Mobile-first layout 重構（這輪 session 做）

- Tailwind 從 desktop-first 轉 mobile-first（`md:` prefix 給 >= 768px）
- 現有 header nav 降級成 desktop-only
- 新增底部 tab bar（mobile only）：🏠 Dashboard · 🌳 Tree · 📤 Upload
  queue · ⋯ More
- 所有 form / table 改成單欄流式
- 觸控目標 ≥ 44px

### 2.2 `/tree` 可收合樹狀頁（這輪 session 做）

- 路徑：`/tree`
- 第 0 層：`SELECT DISTINCT studio FROM works`，按筆數排序
- 展開 studio → 子 `SELECT FROM works WHERE studio = ?`（lazy load）
- 展開 work → 子 groups（parent_group_id IS NULL）+ 未掛 group 的
  leaf posters
- 展開 group → 子 groups + leaf posters under that group
- 每個節點顯示：icon、名稱、子項數量、佔位狀態
- 葉節點點擊 → 跳 `/posters/:id` 編輯
- 資料透過 Server Components 取得、子層 lazy fetch（client-side）

狀態管理：展開集合用 URL query param（`?open=studio:吉卜力,work:xxx`）
→ 可分享連結、可刷新保留狀態。

### 2.3 圖片上傳（這輪 session 做）

**Storage bucket**: 用現有 `posters` public bucket（Flutter app 已經
在用）。路徑規則：`{user_id_or_admin}/{poster_id}_{timestamp}.jpg`。

**壓縮 pipeline**（client-side）：
- 主圖 max 1600px 長邊、JPEG q=0.85
- Thumb max 400px 長邊、JPEG q=0.75
- BlurHash 用 `blurhash` npm 套件算 6×4 解析度

**流程**：
1. 使用者在 `/posters/:id` 或批量嚮導中 `<input type=file accept="image/*">`
2. 讀檔、用 `<canvas>` 降解析度 + 壓縮
3. `supabase.storage.from('posters').upload()` 上主圖 + thumb
4. 計算 BlurHash
5. UPDATE posters SET image_url, thumbnail_url, blurhash,
   is_placeholder=false

**失敗處理**：單張失敗不中斷整個流程，顯示紅色錯誤、可重試。

### 2.4 批量選取（下輪 session）

- 所有 list 頁加長按 handler
- 進入選取模式後 header 變「已選 N 張」+ ✕ 退出
- 底部浮現 action bar

### 2.5 批量上傳嚮導（下輪 session）

- 入口：`/upload-queue` → 顯示所有 `is_placeholder=true`
- 按「全部上傳」進嚮導（或選取部分後按「批量上傳」）
- 嚮導頁路徑：`/upload-queue/wizard?index=0&ids=a,b,c`

### 2.6 批量刪除 / 搬家（下輪 session）

### 2.7 需要新的 DB 欄位嗎？

**不需要新欄位** — Phase 1 migration 已經建好了：
- `poster_groups` recursive 表
- `posters.parent_group_id`
- `posters.is_placeholder`

這輪只用已經存在的結構。唯一需要動的是讓 admin UI 真的開始使用
`poster_groups` —— Phase 1 只做到欄位存在，沒 UI 建/改 group。

### 2.7a 這輪要加的 UI：新增 / 編輯 poster_group

既然樹要用 `poster_groups`，admin 必須能建群組：
- 在 work 編輯頁加「新增群組」按鈕 → 打開小表單（name, type）
- 在 group 詳情頁加「新增子群組」
- 葉 poster 編輯頁加「所屬群組」選擇器

## 技術工具選型

- **Tailwind** — 已有
- **react-icons** 或 **lucide-react** — icon（chevron、menu 等）
- **browser-image-compression** — 客戶端圖片壓縮（~15KB gzipped）
- **blurhash** — BlurHash 計算
- **shadcn/ui**（或類似）— 暫緩，先用原生 + Tailwind，不想多一個依賴

## 手機 viewport 設計原則

- 基準：iPhone 13 (375 × 812)
- 觸控目標：≥ 44 × 44px（Apple HIG）
- 字級：body ≥ 14px，title ≥ 17px
- 底部 tab bar：固定 60px 高 + safe-area-inset-bottom
- 側向 padding：16px（系統標準）

## 進度紀錄

- 2026-04-24 晚：Phase 2 plan 寫好，這輪 session 目標是 2.1 + 2.2 + 2.3
