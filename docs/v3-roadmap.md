# Poster. v3 執行順序總覽（Roadmap）

**Status:** 2026-04-24 產品定位已鎖定（見
`plan-v3-collection-pivot.md` §Decisions locked），剩下的全是執行問題。

此文件是「**誰要做什麼、什麼順序做**」的總表，供 Henry / 合夥人 /
編輯者 / Claude 各自對照自己要負責的行動。

---

## ⏱ 現在狀態（2026-04-24）

| 項目 | 狀態 |
|---|---|
| bot seed 清除 | ✅ 已完成 |
| v3 技術設計 doc（`plan-v3-collection-pivot.md`）| ✅ 鎖定 |
| v3 行為流程 doc（`v3-behavior-flows.md`）| ✅ 鎖定 |
| 編輯者工具 README + CSV 範本 | ✅ 完成 |
| 吉卜力 benchmark 資料（37 列）| ✅ 完成 |
| Phase 1 DB migration | ⏳ 等合夥人定 schema |
| admin/ Next.js 後台 | ⏳ 等 Phase 1 |
| 收藏導向前端改寫 | ⏳ 等後台 |

---

## 📋 接下來的 TODO（依賴關係排序）

### 🟩 Phase 0：本週 / 下週就能做（不被任何東西擋）

| # | 任務 | 誰做 | 產出 |
|---|---|---|---|
| 0.1 | 把吉卜力 CSV 匯入一份新的 Google Sheets | **Henry** | 官方海報目錄 Sheet（第一個分頁叫「Ghibli 範例」、唯讀）|
| 0.2 | 在同一 Sheet 開第二分頁「正式資料」 | **Henry** | 編輯者工作區 |
| 0.3 | 分享 Sheet 給編輯者 | **Henry** | 編輯者開始擴充吉卜力外的電影 |
| 0.4 | 分享 `plan-v3-collection-pivot.md` + `v3-behavior-flows.md` + 吉卜力 CSV 給合夥人 | **Henry** | 合夥人開始驗證 schema |
| 0.5 | 合夥人回饋 schema 欄位夠不夠、關聯正不正確 | **合夥人** | schema 定稿（label / value / 關聯）|
| 0.6 | 產 8 張 `work_kind` silhouette 占位圖 | **Henry**（找 AI 或設計師）| 電影 / 演唱會 / 戲劇 / 展覽 / 活動 / 原創 / 廣告 / 其他 通用剪影 |
| 0.7 | 編輯者填吉卜力外的其他電影 | **編輯者** | 目錄從 37 列擴充到 ~500+ 列 |

### 🟨 Phase 1：合夥人 schema 定稿後（工程 ~1 週）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 1.1 | 寫 Phase 1 migration SQL（`poster_groups`, `user_poster_state`, `user_poster_override`, etc.）| **Claude** | 0.5 schema 定稿 |
| 1.2 | 遷移現有 `posters` 表：加 `parent_group_id`, `is_placeholder`| **Claude** | 1.1 |
| 1.3 | apply migrations 到 Supabase production | **Henry**（貼 Supabase Dashboard）| 1.1/1.2 審過 |
| 1.4 | 跑 `bot_write_paths.sql` 驗證 DB 沒壞 | **Henry** | 1.3 |
| 1.5 | 凍結 v2 的 feed / 追蹤 / 通知功能，加「freeze」註記 | **Claude** | 並行 |

### 🟧 Phase 2：Migration 完 → 後台上線（工程 ~2-4 週）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 2.1 | `admin/` Next.js sub-app 骨架（auth、router、role gate）| **Claude** | 1.3 |
| 2.2 | Google Sheets API 整合（service account、讀取範圍）| **Claude** | 2.1 |
| 2.3 | 「從 Sheet 同步」按鈕 + diff preview + 匯入邏輯 | **Claude** | 2.2 |
| 2.4 | 後台「待補圖」佇列 + 拖拉上傳 + 自動壓縮 | **Claude** | 2.1 |
| 2.5 | 後台「投稿審核」佇列 | **Claude** | 2.1 |
| 2.6 | 官方跑第一次大 sync — 把 Google Sheets 正式資料全部灌進 DB | **Henry** | 2.3 跑通 |
| 2.7 | 8 張 silhouette 圖上傳到 Supabase Storage | **Henry** | 0.6 完成 |
| 2.8 | 部署 admin 到 Vercel（新專案、新網址 `admin.poster.app`）| **Claude / Henry** | 2.1-2.5 |

### 🟥 Phase 3：後台上線 → Flutter app 改寫（工程 ~3-5 週）

| # | 任務 | 誰做 | 依賴 |
|---|---|---|---|
| 3.1 | 新的樹狀瀏覽頁（取代目前 home）| **Claude** | 2.6（有資料）|
| 3.2 | 翻牌互動（flip 動畫 + state 寫入）| **Claude** | 3.1 |
| 3.3 | 個人卡夾頁（進度 / 完成度 / 貢獻徽章）| **Claude** | 3.2 |
| 3.4 | 「提交建檔申請」flow（取代目前上傳流程）| **Claude** | 3.1 |
| 3.5 | 自拍覆寫（private only）| **Claude** | 3.2 |
| 3.6 | 活動 feed 改寫（contribution-first）| **Claude** | 3.2 |
| 3.7 | 凍結的 v2 功能放到次要 tab | **Claude** | 並行 |
| 3.8 | 端到端測試（重寫 `bot_flows_test.py` 對新 schema）| **Claude** | 3.1-3.7 |

### ⚪ Phase 4：未來（v3 外、不排期）

- 線下活動 QR 簽到徽章
- 官方限定海報編號驗證
- 戲院 loyalty API 整合（極度推測性）
- 使用者投稿變「信任編輯者」升級路徑

---

## 🔒 已明確**不做**的事（v3 範圍外）

避免 scope drift，這些已經討論過並排除：

- ❌ 翻牌數量徽章（點幾下就破解）
- ❌ 集滿徽章（同上）
- ❌ 速度 / 首位成就（偏袒早期使用者）
- ❌ 稀有度 tier（Common / Rare / Legendary）
- ❌ 照片審查驗證徽章（盜圖秒破、審核成本高）
- ❌ 自拍公開 / community override
- ❌ 付費 / gacha / 戰鬥機制
- ❌ Schema designer（像 Supabase Studio 那種元層）——後台只管一個固定 schema 的 CRUD
- ❌ Flutter web 做後台（改為 Next.js 獨立 app）
- ❌ iframe 嵌入 Google Sheets（改為 API 拉取同步）
- ❌ 使用者上傳 canonical 圖（只能上傳個人私密自拍）
- ❌ 稀有度全域統計（反正統計不準）

---

## 🆘 阻塞排除清單（卡關時看這裡）

| 如果卡在這 | 該催誰 / 做啥 |
|---|---|
| Phase 1 遲遲開不了工 | 催合夥人定 schema（0.5）|
| Sheet 同步失敗 | 檢查 Google Cloud service account + Sheets API 有沒有啟用 |
| 後台無法部署 | 檢查 Vercel 新專案建好、環境變數 `SUPABASE_SERVICE_ROLE_KEY` 有設 |
| 使用者反應「app 變了很多」 | 預期的，v3 是 pivot 不是 iteration；做好溝通文案 |
| 編輯者填到一半 schema 改了 | 保留 Sheet 原樣，寫 migration 把 CSV 欄位 map 到新 schema |

---

## 📬 Claude 的停手狀態

**現在我不動 code**。Auto mode 期間依然等以下任一項解鎖：

1. 合夥人定 schema（解鎖 Phase 1）
2. Henry 提出新的設計問題想討論
3. Henry 發現現有 doc 需要調整

在那之前 Claude 只做：
- 更新 docs 反映新討論
- 產更多示範資料（如吉卜力範例已完成，若需要可擴展）
- 不動 Flutter、不動 Supabase、不動 Next.js。

---

*這份檔案就是你不知道「下一步該做什麼」時翻開來看的地方。*
