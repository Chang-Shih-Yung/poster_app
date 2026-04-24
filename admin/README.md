# Poster. Admin

Editorial backend for Poster. — only Henry + 合夥人 can log in; everyone
else gets kicked to `/unauthorized`. Same Supabase project as the
Flutter app.

## 本地開發（Henry 的第一次跑起來）

前置條件：
- Node 22（`nvm use 22` 或裝 Node.js 22.x）
- pnpm（`npm install -g pnpm`）
- Supabase 專案的 anon key 跟 URL（Dashboard → Project Settings → API）

### 1. 安裝依賴

```bash
cd admin
pnpm install
```

### 2. 建 `.env.local`

```bash
cp .env.example .env.local
```

然後填入三個變數（見 `.env.example` 說明）：
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `ADMIN_EMAILS`（你自己跟合夥人的 Gmail，逗號分隔）

### 3. Supabase 那邊要設好兩件事

#### 3a. Apply Phase 1 migration

Dashboard → SQL Editor → 貼入
`supabase/migrations/20260424120000_v3_phase1_groups_and_collection.sql`
→ Run。結束時跑檔案末端的 post-apply checklist 5 條 SELECT 確認表
都建好。

#### 3b. 啟用 Google OAuth provider

Dashboard → Authentication → Providers → **Google** → Enable。

需要 Google Cloud Console 開一組 OAuth client id/secret：
- https://console.cloud.google.com/apis/credentials
- Application type: Web application
- Authorized redirect URIs: 填 `https://<你的 supabase 專案>.supabase.co/auth/v1/callback`

把 client id 跟 secret 貼到 Supabase Auth provider 頁面。

#### 3c. 把自己的 users.role 設成 'admin'

第一次用你的 Gmail 登入之後，users 表會自動生出一筆 row（role 預設
`user`）。用 Dashboard SQL：

```sql
update public.users set role = 'admin' where handle = 'your-handle';
-- 或用 email 找（需要 join auth.users）
update public.users
  set role = 'admin'
  where id = (
    select id from auth.users where email = 'henry1010921@gmail.com'
  );
```

合夥人那支 email 同樣要設。

### 4. 跑起來

```bash
pnpm dev
```

開 http://localhost:3000 → 應該會被推到 `/login` → 按「以 Google 登入」。

## 部署到 Vercel

1. GitHub repo 已經含 `admin/` 目錄
2. Vercel → New Project → 選這個 repo
3. **Root Directory 要設成 `admin`**（不是 repo 根目錄！）
4. Framework preset: Next.js
5. Environment variables：貼上 `.env.local` 的三個變數
6. Deploy

記得更新 Supabase Auth 的 Redirect URLs，把新 Vercel domain 加進
Allow List（Dashboard → Authentication → URL Configuration）。

## 目前有什麼（v0，2026-04-24）

- [x] Google OAuth 登入
- [x] Admin email 白名單（middleware 層）
- [x] Dashboard 顯示 works / posters / 待補圖數量
- [x] Works list / new / edit 頁
- [x] Posters list（可搜尋、可篩選只看待補圖）
- [x] Posters new / edit 頁（完整 metadata 表單）
- [x] 夜幕 dark theme（配合 Flutter app 風格）

## 還沒做（Phase 2）

- [ ] `poster_groups` 樹狀編輯器（拖拉新增 / 重排層級）
- [ ] 真實圖片上傳（拖拉 + 壓縮 + thumb + BlurHash）
- [ ] 投稿審核佇列（使用者送上來的 metadata 建檔）
- [ ] 吉卜力樣板 CSV → 一鍵 seed 匯入腳本
- [ ] 批次操作（多選、批次刪除 / 改 studio）

## 架構備忘

- **Next.js 15** App Router，React 19
- **Supabase SSR** 套件，middleware 每個 request refresh session
- 兩層權限：middleware 擋 email，RLS 擋 DB 操作
- 直接走 anon key — 不用 service role key，所有寫入走 RLS policies

## Troubleshooting

| 症狀 | 診斷 |
|---|---|
| 本地 `pnpm dev` 跑起來但一片白 | 檢查 `.env.local` 三個變數 |
| 登入後一直被踢 `/unauthorized` | email 不在 `ADMIN_EMAILS`（大小寫敏感）|
| 登入按鈕沒反應 | Supabase Auth provider Google 沒 Enable |
| Dashboard 顯示「載入失敗」 | RLS 擋了 anon；檢查 users.role 有沒有設成 admin |
| 新增 works 報 permission denied | 同上，users.role 必須是 'admin' 或 'owner' |
| migration 跑失敗 | 看錯誤訊息；最常見是某個表已存在 — migration 全部用 IF NOT EXISTS 所以重跑安全 |
