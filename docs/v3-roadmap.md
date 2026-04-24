# Poster. v3 執行順序總覽（Roadmap）

**Status:** 2026-04-24 大翻轉 — **不再經過 Google Sheets**，一切資料
輸入直接走自建後台。兩個 admin 帳號（Henry + 合夥人）從一開始就用後
台進行 schema 驗證、資料建檔、圖片上傳。

此文件是「**誰要做什麼、什麼順序做**」的總表，供 Henry / 合夥人 /
Claude 各自對照自己要負責的行動。

---

## ⏱ 現在狀態（2026-04-24 下午）

| 項目 | 狀態 |
|---|---|
| bot seed 清除 | ✅ 已完成 |
| v3 技術設計 doc | ✅ 鎖定 |
| v3 行為流程 doc | ✅ 鎖定 |
| 吉卜力 benchmark CSV（37 列）| ✅ 留作**資料樣板**、不再經過 Sheets |
| **Google Sheets 中繼** | ❌ **已廢止** — 直接走後台 |
| Phase 1 DB migration | 🔵 **Claude 進行中** |
| admin/ Next.js 後台 | 🔵 **Claude 進行中** |
| 收藏導向前端改寫 | ⏳ 等後台跑通第一批資料 |

---

## 🔀 2026-04-24 下午的架構翻轉

**原計畫**：編輯者用 Google Sheets 填資料 → 後台同步按鈕拉進 DB →
後台做圖片上傳、審核、樹狀編輯。

**新計畫**：完全跳過 Sheets。所有人直接用後台。後台一開始就包含：
- Google OAuth（只白名單 admin email 能進）
- works / poster_groups / posters 的 CRUD
- 樹狀編輯器（visual tree of posters）
- 圖片上傳 + 壓縮 + thumb 產生
- 編輯者 = admin、合夥人 = admin，沒有第三類使用者進這裡

**為什麼翻轉好**：

1. 一個工具從頭到尾，不用在匯入邏輯上花工
2. 圖片可以跟 metadata 一起即時上傳（不用「先灌文字再補圖」兩段）
3. Schema 變動時直接改後台 UI 跟 DB 同步，不用同時改 Sheet 欄位、
   CSV template、import script、UI
4. 編輯者學一個工具就好（後台）而不是兩個（Sheets + 後台）

**留下的代價**：

- 後台要**更早上線**（本來可以慢慢做，現在變緊迫）
- 編輯者第一天沒東西用，要等到後台最小可用版本
- 吉卜力 benchmark CSV 留作**資料樣板**（給我寫 seed script 用），
  不給人工填了

---

## 📋 新版 TODO（依賴排序）

### 🟩 Phase 0：這輪 session 就做完

| # | 任務 | 誰做 | 狀態 |
|---|---|---|---|
| 0.1 | 更新 roadmap 反映翻轉 | Claude | ✅ 本檔 |
| 0.2 | 寫 Phase 1 migration SQL（基於 19 欄 schema 草稿）| Claude | 🔵 進行中 |
| 0.3 | Bootstrap `admin/` Next.js 15 專案 | Claude | 🔵 進行中 |
| 0.4 | 實作 Google OAuth + admin email 白名單 | Claude | 🔵 進行中 |
| 0.5 | 基本 CRUD：works / posters 的 list / new / edit 頁面 | Claude | 🔵 進行中 |

### 🟨 Phase 1：後台 v0 可用之後（這兩三天）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 1.1 | Apply migration 到 Supabase production | **Henry** | 0.2 完 |
| 1.2 | 設定 Supabase Auth Google provider + admin email 白名單到環境變數 | **Henry** | 0.4 完 |
| 1.3 | 本地跑後台 `pnpm dev` 確認能進 | **Henry** | 0.5 完 |
| 1.4 | 部署 admin 到 Vercel（新專案）| Henry / Claude | 1.3 |
| 1.5 | 合夥人登入後台 → **對著真資料驗證 schema 夠不夠**| **合夥人 + Henry** | 1.4 |
| 1.6 | 根據 1.5 回饋調整 schema + 後台 UI | Claude | 1.5 |

### 🟧 Phase 2：後台功能補齊（1-2 週）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 2.1 | 樹狀編輯器（drag-drop / 新增群組節點）| Claude | Phase 1 穩 |
| 2.2 | 圖片上傳 + 壓縮 + thumb + BlurHash | Claude | Phase 1 穩 |
| 2.3 | 把吉卜力 37 列樣板寫成 seed script 一次灌入（當作 smoke test）| Claude | 2.1 + 2.2 |
| 2.4 | 8 張 silhouette 占位圖上傳到 Supabase Storage | **Henry**（產圖）| 2.2 |
| 2.5 | 使用者投稿審核佇列 UI（還沒有投稿資料、先建好殼）| Claude | Phase 1 |

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

- ❌ **Google Sheets 中繼**（今天廢止）
- ❌ **Sheets API 同步按鈕**（不需要了）
- ❌ **CSV 匯入工具**（CSV 只留作 seed script 的資料來源）
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

**Auto mode 下：持續推進 Phase 0 和 Phase 1**。這輪 session 會交付：

- Phase 1 migration SQL（寫好但 Henry 決定何時 apply）
- `admin/` Next.js 專案骨架 + Google OAuth + admin 白名單
- works / posters 基本 CRUD

**需要 Henry 做的事**（同 Phase 1 表格）：
1. 拿 migration SQL 貼到 Supabase Dashboard 執行
2. 設定 Supabase Google OAuth provider
3. 設定 admin email 白名單（環境變數）
4. 本地跑後台、再部署 Vercel
5. 跟合夥人一起驗證 schema

---

*這份檔案就是你不知道「下一步該做什麼」時翻開來看的地方。*
