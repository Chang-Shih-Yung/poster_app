# Henry 的後台設定指南（白話版）

不用懂工程也能照做。預期 30 分鐘內你會看到後台跑起來。

如果中間哪一步卡住，把錯誤訊息丟回來給 Claude，會幫你排除。

---

## 🧠 先搞懂：到底有幾個東西？

```
┌──────────────────────────────────────────────────────────┐
│                                                            │
│   一個 Supabase 專案（你現在 Flutter app 在用的那個）        │
│   ────────────────────────────                              │
│   • 一個資料庫（works、posters、users 等表）                 │
│   • 一個 Auth 系統（Google 登入，已啟用）                    │
│   • 一個 Storage（posters bucket，存圖片）                  │
│                                                            │
│   👇 同時被兩個東西用：                                       │
│                                                            │
│   ┌─────────────────────┐    ┌──────────────────────┐    │
│   │  Flutter app         │    │  Next.js admin       │    │
│   │  (使用者收藏端)       │    │  (你 + 合夥人編輯端)   │    │
│   │  已上線              │    │  ⬅ 我們現在要架的     │    │
│   └─────────────────────┘    └──────────────────────┘    │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

**❌ 不要開新的 Supabase 專案。**
**✅ 用 Flutter app 用的那個現有專案。**

---

## 🔐 三道權限閘門（為什麼這樣設計？）

我設了三道閘門，**每一道擋掉不同的攻擊**：

```
你的 Gmail → ① Google OAuth → ② Email 白名單 → ③ DB 角色 → ✅ 進後台
              「你是誰？」     「你被允許嗎？」  「你可以寫嗎？」

  別人的 Gmail → ① Google OAuth → ② Email 白名單 ❌ 被擋在 /unauthorized 頁
                                                  (UI 看不到任何東西)

  你的 Gmail，但 role 不是 admin →  ✅ 進得去頁面，但 ❌ 任何寫入都被資料庫擋下
                                  (這是萬一 ② 設錯了的最後保險)
```

| 閘門 | 在哪設定 | 擋什麼 |
|---|---|---|
| ① Google OAuth | Supabase（已啟用，不用動）| 沒登入的隨機人 |
| ② Email 白名單 | `admin/.env.local` 的 `ADMIN_EMAILS` | 沒被你授權的 Google 帳號 |
| ③ DB role | Supabase 的 `users.role` 欄位 | 萬一 ② 設錯，DB 還會擋 |

**三道一起 = 即使你 .env 寫錯、即使 Google 帳號被駭、即使 middleware 有 bug，DB 自己會擋下亂寫。**

---

## 📝 你要做的 5 步驟

### Step 1：拿 Supabase 的網址跟 key（5 分鐘）

1. 開瀏覽器 → 進 https://supabase.com/dashboard
2. 用你現在 Flutter app 在用的那個 Supabase 帳號登入
3. 點進去你的專案（應該只有一個）
4. 左下齒輪 ⚙️ → Project Settings → **API**
5. 把這兩個值複製下來，先記事本貼著：

   ```
   Project URL:    https://xxxxxxxxxxxxx.supabase.co
   anon public:    eyJhbGciOi... (一長串)
   ```

⚠️ **不要碰 service_role 那個 key**——那是上帝模式金鑰，後台不會用到。

---

### Step 2：跑 migration（3 分鐘）

這一步在 DB 建好後台需要的新表（poster_groups、user_poster_state 等）。

1. 還在 Supabase Dashboard
2. 左側 SQL Editor 圖示 → **+ New query**
3. 打開電腦的這個檔案：
   ```
   /Users/itts/Desktop/poster_app/supabase/migrations/20260424120000_v3_phase1_groups_and_collection.sql
   ```
4. 複製**整個檔案內容**貼進 SQL Editor
5. 按右下角 **Run**
6. 等個 3 秒，看到「Success」就好了
7. 確認一下：在 SQL Editor 跑這 5 行：
   ```sql
   select 1 from public.poster_groups limit 1;            -- 沒錯誤就對
   select 1 from public.user_poster_state limit 1;        -- 沒錯誤就對
   select 1 from public.user_poster_override limit 1;     -- 沒錯誤就對
   select studio from public.works limit 1;               -- 沒錯誤就對
   select is_placeholder from public.posters limit 1;     -- 沒錯誤就對
   ```
   每行單獨跑，看到「No rows returned」是正常的（只是表還空）。

---

### Step 3：把你跟合夥人的 role 設成 admin（2 分鐘）

**先決條件**：你跟合夥人都至少**用 Flutter app 登入過一次**。沒登入過 `users` 表就沒你的 row。

1. SQL Editor → 跑這個查你自己的 row：
   ```sql
   select id, role
   from public.users
   where id = (
     select id from auth.users
     where email = 'henry1010921@gmail.com'
   );
   ```
2. 看到一筆 row、role 是 `'user'`？正常。把它改成 admin：
   ```sql
   update public.users
   set role = 'admin'
   where id = (
     select id from auth.users
     where email = 'henry1010921@gmail.com'
   );
   ```
3. 合夥人那筆**也照做**（換成他的 email）。
4. 如果合夥人還沒用 app 登入過，叫他先登入一次再回頭跑這 SQL。

---

### Step 4：本地把後台跑起來（10 分鐘）

開 terminal（macOS：Cmd+Space 打 "Terminal"），然後：

```bash
# 切到 admin 子資料夾
cd /Users/itts/Desktop/poster_app/admin

# 確認 Node 22（如果沒有 nvm 就先 brew install nvm 再來）
nvm use 22

# 第一次跑要安裝套件（之後不用）
pnpm install

# 建立環境變數檔
cp .env.example .env.local

# 編輯它（用任何文字編輯器都行）
open -a "TextEdit" .env.local
```

`.env.local` 裡面**只有 3 個變數要改**：

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co       ← Step 1 拿到的 Project URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOi...                       ← Step 1 拿到的 anon public
ADMIN_EMAILS=henry1010921@gmail.com,夥伴的@gmail.com               ← 你跟合夥人 email，逗號分隔
```

存檔關閉。

回到 terminal：

```bash
pnpm dev
```

看到：
```
▲ Next.js 15.0.3
- Local: http://localhost:3000
```

**就開瀏覽器打開** http://localhost:3000 → 應該被推到 `/login` → 點「以 Google 登入」→ 選你的 Gmail → 進到 Dashboard 應該看到三張卡片。

---

### Step 5：確認手機看也 OK（5 分鐘）

合夥人主要在手機操作，你電腦先測沒問題後：

**選項 A：iPhone 模擬器**
- 你 Mac 有裝 Xcode 的話 → 開 Simulator → Safari 訪問 `http://你電腦的區網 IP:3000`

**選項 B：直接拿手機**
- 確保手機跟電腦同一個 Wi-Fi
- 電腦終端機跑 `ipconfig getifaddr en0` 拿你電腦的 IP（例如 `192.168.0.7`）
- 手機 Safari 打 `http://192.168.0.7:3000`
- 應該也會正確被推到登入頁

要傳給合夥人之前，**先部署到 Vercel**，這樣他不用跟你同網路：

```bash
# 第一次部署
cd /Users/itts/Desktop/poster_app/admin
pnpm dlx vercel
# 按提示一路選 yes / 選 root directory = . / 選 framework = Next.js
# 設定好之後它會給你個網址，類似 https://poster-admin-xxx.vercel.app
```

部署完還要做兩件事（Vercel Dashboard 上）：

1. 把 Step 1 的三個環境變數加到 Vercel：Settings → Environment Variables
2. 把 Vercel 給你的網址加到 Supabase 的允許清單：
   - Supabase Dashboard → Authentication → URL Configuration
   - **Redirect URLs** 加：`https://poster-admin-xxx.vercel.app/auth/callback`

然後合夥人手機開那個 vercel.app 網址就能用。

---

## 🆘 卡關時的 Q&A

**Q: pnpm 找不到怎麼辦？**
```bash
npm install -g pnpm
```

**Q: nvm 找不到？**
```bash
brew install nvm
# 然後依照它的提示在 ~/.zshrc 加幾行
```

**Q: Step 4 開 localhost:3000 看到一片白？**
- 開瀏覽器 DevTools (Cmd+Option+I) → Console
- 通常是 `.env.local` 變數沒填好
- 重啟 `pnpm dev`（按 Ctrl+C 再 `pnpm dev`）

**Q: 登入後一直被踢回 `/unauthorized`？**
- 你的 Gmail 沒寫進 `ADMIN_EMAILS`，或大小寫不對
- 改 `.env.local` → 重啟 `pnpm dev`

**Q: 登入後進得去 Dashboard，但新增作品時報 "permission denied"？**
- Step 3 的 `users.role = 'admin'` 沒設成功
- 回 SQL Editor 確認 select 出來的 role 真的是 `'admin'`

**Q: Google 登入按了沒反應？**
- 不應該發生，因為你 Flutter 本來就是 Google 登入。
- 但若真的卡住，看 Supabase Dashboard → Authentication → URL Configuration → Site URL，應該包含 `http://localhost:3000`。

---

## ✅ 你這 5 步做完之後

- 你跟合夥人都能用各自手機 / 桌機開後台
- 開始建第一筆作品 + 海報試試看
- 用 `/tree` 瀏覽看樹狀
- 在某張海報的編輯頁試試圖片上傳
- 試完發現哪個 UX 卡卡的 → 告訴 Claude → 下輪修

---

*這份指南就是 README 的白話加長版。原本的 README 留給工程師查技術細節，這份給你照做。*
