# Poster. v3 執行順序總覽（Roadmap）

**Status:** 2026-04-24 雙軌並行。

- **Google 試算表**：Henry 前期跟合夥人共編用（免費、共編方便、誰
  都會用）。主要拿來討論 schema 長什麼樣、欄位合不合用。
- **admin 後台**：Claude 已經做好 v0，Henry 架好環境就能登入。正式
  大量建檔走後台，Sheet 上的討論結論定稿後同步進 DB。

兩個工具並不衝突：Sheet 是**會議桌**、admin 是**資料庫**。

此文件是「**誰要做什麼、什麼順序做**」的總表，供 Henry / 合夥人 /
Claude 各自對照自己要負責的行動。

---

## ⏱ 現在狀態（2026-04-24 下午）

| 項目 | 狀態 |
|---|---|
| bot seed 清除 | ✅ 已完成 |
| v3 技術設計 doc | ✅ 鎖定 |
| v3 行為流程 doc | ✅ 鎖定 |
| 吉卜力 benchmark CSV（37 列）| ✅ 拿來匯入 Google 試算表，跟合夥人共編討論 |
| Google 試算表（共編用）| 🔵 Henry 這週設好、分享合夥人 |
| Phase 1 DB migration | ✅ 寫好（`20260424120000_v3_phase1_*.sql`），待 Henry apply |
| admin/ Next.js 後台 v0 | ✅ 寫好，待 Henry 本地設環境變數跑起來 |
| 收藏導向前端改寫 | ⏳ 等後台跑通第一批資料 |

---

## 🔀 2026-04-24 工具分工（雙軌並行）

**Google 試算表的角色（前期、短期）**：
- Henry + 合夥人**討論 schema** 的共編白板
- 匯入吉卜力 37 列 benchmark → 合夥人邊看邊回饋「欄位夠不夠」「關
  聯對不對」
- Henry 想改欄位結構時馬上能改（不需要 migration）
- 用到 **schema 定稿為止**

**admin 後台的角色（長期、主力）**：
- 正式資料的**唯一真相**
- Google OAuth 擋住非 admin 的人
- works / posters CRUD（v0 已完成）
- 未來加：樹狀編輯、圖片上傳、投稿審核

**Schema 定稿後怎麼從 Sheet 搬到 DB**：

- 簡單版：一次性匯入 — 寫個 Node 腳本讀 Sheet API 把現有列轉成
  INSERT 進 DB（2 小時工作）
- 或者：乾脆手動把 Sheet 資料**抄進 admin 後台**（如果 Sheet 只有
  50-200 列，手動兩三小時搞定）

兩條路都可行，看 Sheet 累積多少資料來決定。

---

## 📋 新版 TODO（依賴排序）

### 🟩 Phase 0：這輪 session 已完成

| # | 任務 | 誰做 | 狀態 |
|---|---|---|---|
| 0.1 | 更新 roadmap | Claude | ✅ |
| 0.2 | Phase 1 migration SQL（基於 19 欄 schema 草稿）| Claude | ✅ |
| 0.3 | Bootstrap `admin/` Next.js 15 專案 | Claude | ✅ |
| 0.4 | Google OAuth + admin email 白名單 | Claude | ✅ |
| 0.5 | works / posters 基本 CRUD（list / new / edit）| Claude | ✅ |
| 0.6 | 更新 roadmap 反映 Sheet + admin 雙軌 | Claude | ✅ 本次 |

### 🟨 Phase 1：本週該做的（雙軌並行）

**🅰 Google 試算表那軌（Henry + 合夥人前期討論）**

| # | 任務 | 誰做 |
|---|---|---|
| 1.A1 | 匯入吉卜力 benchmark CSV 到新建的 Google 試算表 | **Henry** |
| 1.A2 | 依 `scripts/editor_tooling/ghibli_benchmark_README.md` 設 3 個視覺化（凍結首列首欄、條件式底色、群組收合）| **Henry** |
| 1.A3 | 分享給合夥人、請他邊看邊回饋欄位 | **Henry** |
| 1.A4 | 收回饋 → 決定要加 / 改哪些欄位 | **Henry + 合夥人** |

**🅱 後台那軌（Henry 本地跑 + Claude 補功能）**

| # | 任務 | 誰做 |
|---|---|---|
| 1.B1 | Apply Phase 1 migration 到 Supabase production | **Henry**（貼 Dashboard）|
| 1.B2 | 啟用 Supabase Auth Google provider（建 Google Cloud OAuth client）| **Henry** |
| 1.B3 | 把你跟合夥人的 `users.role` 設成 `admin` | **Henry**（跑 SQL）|
| 1.B4 | `cd admin && pnpm install`，建 `.env.local`，`pnpm dev` | **Henry** |
| 1.B5 | 確認登入 → Dashboard 跑起來 | **Henry** |
| 1.B6 | （可選）部署後台到 Vercel（新專案、Root Directory = `admin`）| Henry / Claude |

**🅲 合流點**

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 1.C1 | Schema 定稿後：寫 migration 把新欄位加進 DB + admin 表單 | Claude | 1.A4 |
| 1.C2 | Sheet 裡的資料**一次性匯入 DB**（Node 腳本或手動）| Claude / Henry | 1.C1 |

### 🟧 Phase 2：mobile-first 後台 + 圖片上傳

合夥人要求「手機一目瞭然樹狀 + 圖片上傳 + 批量」三大目標的拆解。
詳細設計見 `docs/v3-phase2-mobile-admin.md`。

| # | 任務 | 誰做 | 狀態 |
|---|---|---|---|
| 2.1 | Mobile-first layout + 底部 tab bar | Claude | ✅ |
| 2.2 | `/tree` 可收合樹狀頁（Studio → Work → Group → Poster）| Claude | ✅ |
| 2.3 | `poster_groups` CRUD（新增子群組 / 刪除）| Claude | ✅ |
| 2.4 | 圖片上傳：客戶端壓縮 + thumb + BlurHash + Storage | Claude | ✅ |
| 2.5 | `/upload-queue` 待補圖列表頁 | Claude | ✅ |
| 2.6 | 多選模式（長按觸發）+ 批量動作底欄 | Claude | ⏳ 下輪 |
| 2.7 | 批量上傳嚮導頁（一張接一張，可跳過）| Claude | ⏳ 下輪 |
| 2.8 | 批量刪除 / 批量搬群組 | Claude | ⏳ 下輪 |
| 2.9 | 8 張 silhouette 占位圖上傳到 Supabase Storage | **Henry**（產圖）| ⏳ |
| 2.10 | 使用者投稿審核佇列 UI（還沒有投稿資料、先建好殼）| Claude | ⏳ |

### 🟥 Phase 3：Flutter app 改寫（2-4 週，後台穩才動）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 3.1 | 樹狀瀏覽頁 | Claude | Phase 2 有資料 |
| 3.2 | 翻牌互動 + state 寫入 | Claude | 3.1 |
| 3.3 | 個人卡夾頁 | Claude | 3.2 |
| 3.4 | 提交建檔申請流 | Claude | 3.1 |
| 3.5 | 自拍覆寫（private）| Claude | 3.2 |
| 3.6 | 活動 feed 改寫 | Claude | 3.2 |
| 3.7 | 凍結的 v2 功能移到次要 tab | Claude | 並行 |
| 3.8 | 端到端測試 | Claude | 3.1-3.7 |

### ⚪ Phase 4：未來選項（不排期）

- 線下活動 QR 簽到徽章
- 官方限定海報編號驗證
- 戲院 loyalty API 整合
- 使用者投稿變「信任編輯者」升級路徑

---

## 🔒 已明確**不做**的事（v3 範圍外）

- ❌ **強制用 Google 試算表做 scale 資料輸入**（只用來合夥人共編討
  論；超過幾百列以後轉進後台）
- ❌ 翻牌數量徽章、集滿徽章、速度徽章、稀有度徽章
- ❌ 照片審查驗證徽章
- ❌ 自拍公開 / community override
- ❌ 付費 / gacha / 戰鬥機制
- ❌ Schema designer 元層
- ❌ Flutter web 做後台
- ❌ iframe 嵌入 Google Sheets
- ❌ 使用者上傳 canonical 圖（只能上傳個人私密自拍）
- ❌ 稀有度全域統計

---

## 🆘 阻塞排除清單

| 如果卡在這 | 該做啥 |
|---|---|
| 後台跑不起來 | 檢查 `.env.local` 有沒有 `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `ADMIN_EMAILS` |
| Google OAuth 登入不能 | Supabase Dashboard → Auth → Providers → Google 要開啟並填 OAuth client id / secret |
| Login 成功但被擋 | 登入的 email 不在 `ADMIN_EMAILS` 裡、或大小寫不符 |
| 後台部署 Vercel 失敗 | 新專案的 Root Directory 要設 `admin/`、環境變數要重貼 |

---

## 📬 Claude 的工作狀態

**Phase 0 已全部交付**：
- Phase 1 migration SQL（`supabase/migrations/20260424120000_v3_phase1_*.sql`）
- `admin/` Next.js 專案骨架 + Google OAuth + admin 白名單
- Dashboard + works/posters 基本 CRUD
- 三份主要 docs 同步到最新狀態

**等 Henry / 合夥人動的事**（同 Phase 1 表格）：

**Sheet 那軌**：
1. 匯入吉卜力 CSV 到 Google 試算表
2. 分享合夥人共編、討論 schema

**後台那軌**：
1. 拿 migration SQL 貼到 Supabase Dashboard 執行
2. 設定 Supabase Google OAuth provider
3. 跑 SQL 把自己 + 合夥人 `users.role` 設成 `admin`
4. 本地 `cd admin && pnpm install && pnpm dev`
5. 登入 → Dashboard 跑起來
6. （可選）部署 Vercel

**Claude 下一輪會做什麼**：等 Henry 回饋「schema 要加什麼 / 哪裡不
順 / 哪個 feature 優先」，然後進 Phase 2（樹狀編輯 / 圖片上傳 / 合
流 Sheet）。

---

*這份檔案就是你不知道「下一步該做什麼」時翻開來看的地方。*
