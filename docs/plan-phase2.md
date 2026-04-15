# Phase 2：強化使用體驗

日期：2026-04-15
前置：MVP v1 已 ship（commit `8e28bec`）

---

## 目標

把 MVP 從「可用」推到「好用」。核心是 **personal view**（我的投稿、收藏分類）+ **discovery 強化**（熱門、進階篩選、搜尋體驗）。

---

## 範圍

### A. 資料層
- **Seed 40 筆海報** — MVP 只有 4-5 筆，UI 看不出真實感、熱門排序也沒意義。用 SQL seed 補到 40 筆，涵蓋不同年份/導演/tags。
- **`favorite_categories` 表** — 新增 category 概念，`favorites` 加 `category_id` FK（nullable = 預設分類）。

### B. Backend / Repository
- `PosterRepository.listApproved` 擴充參數：
  - `sortBy: 'latest' | 'popular'`
  - `yearMin`, `yearMax`
  - `tags: List<String>`（AND 邏輯，所有選的 tag 都要命中）
  - `director: String?`
- `popular` 排序 = `order by view_count desc` + `where created_at > now() - interval '30 days'`（30 天窗口避免老海報壓榜）
- `PosterRepository.listMine(userId, statusFilter?)` — 列出使用者自己的投稿（含 pending / rejected）
- `FavoriteCategoryRepository` — CRUD + 移動 favorite 到 category

### C. 我的投稿 + Profile 重構

Profile 頁改成 section-based：
```
┌─ 我的 tab ──────────────┐
│ 👤 user@gmail.com       │
│ 角色：user              │
├────────────────────────┤
│ 📤 我的投稿 (N)    >   │ → /me/submissions
│ ❤️ 我的收藏 (N)    >   │ → 收藏 tab
│ ⚙️ (Admin 區塊如適用)   │
│                         │
│ [登出]                  │
└────────────────────────┘
```

**MySubmissionsPage**：list 全部投稿，每張顯示 status chip（審核中/已上架/已退回），rejected 的顯示 admin 備註。

### D. Browse 頁增強

**最新 / 熱門 segmented control**（頂部，搜尋框下方）：
```
┌────────────────────────┐
│ [🔍 搜尋框]      [⚙️]   │
├────────────────────────┤
│ [ 最新 ] [ 熱門 ]      │
├────────────────────────┤
│ [海報 grid / list]     │
└────────────────────────┘
```

**進階篩選 bottom sheet**（點 ⚙️ 開啟）：
- 年份 range slider（1990–現在）
- 導演文字輸入
- Tags multi-select chips（從現有 tags 抓 top 20）
- [清除] / [套用]
- 套用後 browse 頂部顯示「已套用 3 項篩選 [清除]」chip

### E. UX 三小餐（全做）

1. **Grid / List toggle** — 右上角切換 icon，list mode 顯示大圖 + 標題 + 年份 + 導演 + tags
2. **搜尋歷史** — 點搜尋框時下拉最近 5 筆（SharedPreferences 存），點擊直接填入
3. **Skeleton loading** — 瀏覽頁 loading 時顯示 6 個 placeholder card（不是一顆 spinner）

### F. 收藏分類

- 收藏 tab 頂部 horizontal tab bar：「全部」+ 使用者建立的分類
- 長按 / swipe 收藏 → 顯示「移到分類」選單
- 「全部」旁有「＋ 新分類」按鈕 → dialog 輸入名稱
- 分類管理：tab bar 滑到最右「編輯」→ reorder / rename / delete（delete 時裡面的 favorite 變預設）
- 預設 = `category_id IS NULL`

---

## NOT in scope（Phase 3 再說）

- 社群互動（留言、追蹤）
- 海報版本整理
- 排行榜頁（tab 獨立）
- GDPR 一鍵刪資料（ship 前要做）
- 推播通知
- 多語言

---

## 資料模型變更

```sql
-- Migration: 20260415000400_phase2_categories.sql

create table public.favorite_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

alter table public.favorites
  add column category_id uuid references public.favorite_categories(id) on delete set null;

create index favorites_user_category_idx
  on public.favorites (user_id, category_id, created_at desc);

-- RLS
alter table public.favorite_categories enable row level security;

create policy "own_categories_select" on public.favorite_categories
  for select using (user_id = auth.uid());
create policy "own_categories_insert" on public.favorite_categories
  for insert with check (user_id = auth.uid());
create policy "own_categories_update" on public.favorite_categories
  for update using (user_id = auth.uid());
create policy "own_categories_delete" on public.favorite_categories
  for delete using (user_id = auth.uid());
```

**Seed**：`20260415000500_seed_posters.sql` — 40 筆 approved 海報，年份散佈 1985-2024，涵蓋 ~15 位導演、~10 種 tags。圖片用 `posters` bucket public URL（或 placeholder URL — 跟你確認 MVP 怎麼存的）。

---

## 執行順序

1. **A1 migration** — 分類表 + 關聯欄位 + RLS
2. **A2 seed** — 40 筆海報
3. **B1** — PosterRepository 擴充 filters + sortBy
4. **B2** — FavoriteCategoryRepository 新增
5. **B3** — listMine
6. **D1** — Browse segmented control（簡單、先 ship）
7. **D2** — 進階篩選 bottom sheet
8. **E1** — Grid/list toggle
9. **E2** — Skeleton loading
10. **E3** — 搜尋歷史
11. **C** — MySubmissionsPage + Profile 重構
12. **F** — 收藏分類 UI

每個項目完 commit 一次，不等到最後才 push。

---

## 成功指標（自我驗證）

- [ ] 40 筆海報載入、熱門排序有 meaningful difference
- [ ] 進階篩選可同時用年份 + tag + 導演 + 搜尋
- [ ] 切最新/熱門時頁面不閃爍、pagination 正常
- [ ] MySubmissionsPage 顯示 pending/approved/rejected 三種狀態
- [ ] 建立 3 個分類、移動收藏、刪除分類 → 收藏回到預設
- [ ] Grid/list toggle 即時切換、偏好記住（SharedPreferences）
- [ ] 搜尋歷史去重、最多 5 筆
- [ ] Skeleton loader 在 slow 3G 下看起來 native
- [ ] `flutter analyze` 零錯誤
