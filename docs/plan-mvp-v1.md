# 電影海報資料庫 App — MVP v1 計畫

## 產品目標

建立一個以電影海報資料庫為核心的 App，不只是看海報，而是：
- 海報資料完整整理
- 使用者可搜尋、瀏覽、收藏
- 使用者可上傳海報資料
- 管理端可審核後上架
- 後續擴充成有社群性、收藏性、資料價值的產品

## 開發階段

### 第一階段：做出可上線的第一版（MVP）
- 建立完整海報資料庫
- 搜尋 / 瀏覽頁
- 海報詳情頁
- 使用者上傳資料
- Admin 審核功能
- 收藏功能
- Google 登入與角色管理

### 第二階段：強化使用體驗
- 進階篩選
- 我的收藏 / 我的投稿
- 瀏覽數、熱門排序
- 更完整的搜尋與分類

### 第三階段：擴充資料與社群功能
- 排行榜
- 使用者互動
- 收藏清單分類
- 海報版本整理
- 更完整的後台管理功能

## 目前狀態

已完成：
- App 方向已確立
- 第一版功能範圍已確立
- 海報資料欄位大致已定
- Firebase 架構方向已定（Firestore 存資料、Storage 存圖片）
- submissions / posters 分流概念已定
- 搜尋頁風格方向已定
- user / admin / 最終控制人 權限概念已定

進行中：把這些整合成穩定可跑的版本。

## 技術架構

### 技術棧
- **前端**：Flutter（iOS / Android / Web 三端）
- **後端**：Supabase（Spark/Free plan，不綁卡）
  - Auth：Google OAuth，role 放 `public.users.role`（user/admin/owner）
  - Postgres：海報 / 使用者 / 投稿 / 收藏 / audit_logs
  - Storage：海報圖片（`posters` bucket，10MB/張）
  - RLS：Row Level Security 取代 Firestore rules
  - RPC：`SECURITY DEFINER` 函式處理審核、計數等原子操作
  - Edge Functions：避開，改用 RPC（對齊 Nexus_Finance 慣例）

### 套件選型
- 狀態管理：Riverpod
- 導航：go_router
- Model：freezed
- 圖片：image_picker + image_cropper、cached_network_image

### 專案結構（feature-first）
```
lib/
├── core/              # router, theme, network, utils
├── data/              # models, repositories, providers
├── features/
│   ├── auth/
│   ├── posters/
│   ├── submission/
│   ├── favorites/
│   ├── admin/
│   └── profile/
└── main.dart
```

### Postgres 資料模型（單表 + status 版）
- `public.posters` — 所有海報（含待審）
  - id uuid, title, year, director, tags text[], poster_url, thumbnail_url, uploader_id
  - **status**: enum `poster_status` = pending | approved | rejected
  - reviewer_id, review_note, reviewed_at
  - view_count bigint（Postgres `UPDATE ... SET view_count = view_count + 1` 無熱點問題，不需 shard）
  - created_at, approved_at, deleted_at（soft delete）
- `public.users` — id (FK auth.users), display_name, avatar_url, role (user/admin/owner), submission_count
- `public.favorites` — (user_id, poster_id) 複合主鍵，存 poster_title + thumbnail snapshot
- `public.audit_logs` — actor_id, action, target_table, target_id, before/after jsonb

**審核策略**：單表 + status 欄位，RLS 保證只有 admin 能把 pending → approved。
- RLS 範例：`using (status = 'approved' or uploader_id = auth.uid() or is_admin())`
- 公開查詢：`.from('posters').select().eq('status','approved').is_('deleted_at', null)` + 索引 `(status, created_at desc) where deleted_at is null`

### view_count（Postgres 版）
Postgres MVCC 天生支援高併發 `UPDATE`，海報頁載入時一行 RPC：
`update posters set view_count = view_count + 1 where id = $1`。
不需要 Firestore 的分片計數器。真的變熱點（單張海報 >100 writes/sec）再引入計數分表。

### 權限模型
- role 放 `public.users.role`，`is_admin()` helper function（SECURITY DEFINER）
- RLS 直接對 `auth.uid()` 比對
- 審核、刪除、改 role 等敏感操作走 RPC（SECURITY DEFINER）

### 資安措施（已規劃）
- RLS policies 嚴格檢查（每張表都開 RLS）
- Storage bucket policy：檔案大小 10MB、allowed MIME 白名單、upload 路徑綁 uid
- Supabase rate limiting + Captcha（防腳本刷爆）
- Free plan 本身有額度上限（5GB storage / 500MB DB），不會被刷出天價帳單
- 縮圖：Supabase Storage 內建 image transform（query param：`?width=400`）
- 隱私政策 + 刪除帳號功能（`delete from auth.users` 會 cascade 清乾淨）
- DMCA 檢舉機制
- 未來 NSFW 過濾可走 Edge Function + 第三方 API

### 搜尋策略
- **MVP**：Postgres 直接查
  - tags：`where tags && array['諾蘭']`（GIN index 已建）
  - 標題模糊：`where title ilike '%XXX%'` + `pg_trgm` GIN index
  - 年份/導演：equality
- **v2 升級**（資料量大再處理）：
  - Postgres Full Text Search（`to_tsvector`）或
  - 切 Typesense / Meilisearch（self-host 免費）
- Repository 層抽象化（`PosterSearchRepository` interface），切換時只動 data layer

### CI/CD 與環境（Day 0）
- **三環境**：`poster-app-dev` / `poster-app-staging` / `poster-app-prod`（各自獨立 Supabase Project，Free plan 每個帳號上限 2，另 2 個晚點再開）
- `--dart-define` 切 `SUPABASE_URL` / `SUPABASE_ANON_KEY`
- GitHub Actions：push → flutter test + `supabase db push` 到 dev，PR 合併 main → staging，tag → prod
- Migration 進 repo（`supabase/migrations/`），用 `supabase db push` 部署
- 本地測試：`supabase start` 跑本地 Docker stack（Postgres + Auth + Storage + Studio）

## 已知風險
1. 海報版權（使用者上傳可能盜版）
2. Firebase 成本攻擊（惡意刷流量）
3. Security Rules 寫錯導致資料外洩
4. 個資法 / GDPR 合規
5. 圖片上傳惡意檔案

## 審查重點（要 eng manager 盯的事）
1. 技術選型是否合理（Flutter + Firebase 對此需求是否合適）
2. 資料模型是否能支撐第二、三階段擴充（排行榜、版本整理、收藏清單）
3. submissions → posters 分流流程是否穩健（失敗處理、race condition）
4. 權限模型（Custom Claims）是否健全
5. 資安規範是否完整（OWASP Mobile Top 10、個資法）
6. 搜尋從 Firestore 遷移到 Algolia / Typesense 的切換成本
7. 成本風險與防禦機制是否足夠
8. 開發順序是否合理、有沒有被忽略的依賴
9. 邊界情境：離線上傳、審核中海報被刪、admin 誤刪、圖片 CDN 失效
10. 測試策略（Security Rules 測試、整合測試、E2E）

---

# 技術審查報告

**審查日期**：2026-04-14
**審查範圍**：MVP v1 架構、資安、資料模型、流程
**審查模式**：FULL_REVIEW
**結果**：15 個 issue（4 P1 / 4 P2 / 7 P3）+ 4 個 critical failure mode gaps

## Step 0 — 範圍判斷

**接受 MVP 範圍**。7 項功能（登入、瀏覽、搜尋、詳情、上傳、審核、收藏）合理。
但有 3 個基礎建設必須 Day 0 補上：
1. 測試策略（Security Rules 測試、Cloud Function 單測、E2E）
2. CI/CD + 三環境分離（dev / staging / prod）
3. 可觀測性（Crashlytics、Functions logs、預算警報）

## 架構決策（已確認）

| # | 決策 | 結果 |
|---|------|------|
| 1 | submissions + posters 雙 collection vs 單 collection + status | **單 collection + status**（避免 race condition） |
| 2 | viewCount 計數 | **Day 1 shard counter**（10 片分片） |
| 8 | 搜尋方案 | **Firestore MVP，v2 依觸發條件切 Algolia/Typesense** |
| 4 | CI/CD + 多環境 | **Day 0 三專案分離 + GitHub Actions** |

## 架構 Issues（剩餘 11 項 — TODO）

### P1（上線前必處理）

**#3 Storage 檔案與 Firestore 文件的 cascade delete**
- 問題：海報文件刪除時，Storage 的原圖 + 縮圖不會自動刪，產生孤兒檔案 + 隱私外洩風險（GDPR 刪除權）。
- 修：Cloud Function `onDelete` trigger，刪 poster 時同時刪 `posters/{id}/*` 全部 Storage 路徑。DMCA 下架走同一條。

**#5 Custom Claims 不即時刷新**
- 問題：admin 權限變動後，user JWT 最長 1 小時後才更新，期間權限不一致。
- 修：admin 改權限時寫 `users/{uid}.claimsUpdatedAt`，client 偵測到就 `getIdToken(true)` 強制刷新。

**#7 審計日誌 + soft delete**
- 問題：admin 誤刪海報無法復原，也查不到誰刪了什麼。
- 修：`audit_logs/{id}`（action, actorId, targetId, before, after, ts）；posters 加 `deletedAt`，查詢過濾。硬刪只由排程任務處理（30 天後）。

**#12 Crashlytics + 基本可觀測性**
- 問題：線上壞了不知道。
- 修：Flutter Crashlytics + Cloud Functions logs 接 Cloud Logging + 預算警報（$5 / $20 / $50）+ App Check 異常警報。

### P2（MVP 第 2 週內補）

**#6 favorites 列表 N+1 查詢**
- 問題：`favorites/{uid}/items` 只存 posterId，渲染列表要 N 次 `posters/{id}` 讀取。
- 修：收藏時把 posterId + title + thumbnailUrl snapshot 存進 items。海報更新時 Cloud Function fan-out 更新收藏快照（或容忍 stale）。

**#11 統一錯誤處理策略**
- 問題：Firebase 錯誤（網路、權限、quota）散落各頁，UX 不一致。
- 修：`AppException` 分類（network / auth / permission / notFound / quota / unknown）+ 全域 `ErrorBoundary` widget + Riverpod `AsyncValue.guard`。

**#14 Firestore 複合索引規劃**
- 問題：`where status == approved orderBy createdAt desc` 這種查詢要複合索引，沒建會 runtime error。
- 修：`firestore.indexes.json` 進 repo，Day 1 先建：(status, createdAt)、(status, tags, createdAt)、(uploaderId, createdAt)、(status, year, createdAt)。

**#15 cursor 分頁（非 offset）**
- 問題：offset pagination 會隨 skip 數線性增加讀取費用。
- 修：用 `startAfterDocument(lastDoc)`，每頁 20 筆，client 記 lastDoc。

### P3（可延到 v2）

**#9 Flutter Web bundle 過大**
- Web 首次載入 2-3MB 很常見。修：`--web-renderer canvaskit` 評估、route-level deferred imports、CDN fingerprint。

**#10 providers 放在 feature folder 還是 data/**
- 建議：repository provider 放 `data/providers/`，UI state provider 放各 feature 內。避免循環依賴。

**#13 改用 Firebase Extension: Resize Images**
- 別自己寫縮圖 Cloud Function，官方 extension 已處理 format / size variants / EXIF 剝除。省工又穩。

## Code Quality Issues

1. **freezed + json_serializable 必須綁 CI**：PR 沒跑 `build_runner` 會讓 model 漂移。加 `dart run build_runner build --delete-conflicting-outputs` 進 CI check。
2. **Riverpod provider 命名一致性**：`xxxProvider` vs `xxxNotifierProvider` 要有規範，否則 code review 會吵。
3. **Secrets 管理**：Firebase config 不是 secret 可進 repo，但 API keys（Algolia 未來、第三方）必須走 GitHub Secrets + Firebase Functions config。

## Test Coverage Gap

**目標 27 條關鍵路徑，目前 0**。以下是 8 個 Security Rules critical paths（必須測）：

| # | 路徑 | Rule 目標 |
|---|------|----------|
| 1 | 匿名讀 approved poster | ✅ 允許 |
| 2 | 匿名讀 pending poster | ❌ 拒絕 |
| 3 | uploader 讀自己的 pending | ✅ 允許 |
| 4 | admin 讀任意 pending | ✅ 允許 |
| 5 | 一般 user 改他人 poster | ❌ 拒絕 |
| 6 | user 自己的 submission status=pending → approved | ❌ 拒絕（只能 admin / Function） |
| 7 | user 讀他人 favorites | ❌ 拒絕 |
| 8 | user 偽造 role=admin 寫 users/{self} | ❌ 拒絕 |

工具：`@firebase/rules-unit-testing` + Jest，跑 in-memory emulator，每次 PR 必跑。

## Performance Issues

1. **Firestore 熱文件**：viewCount 已用 shard 解決。注意 `users/{uid}.submissionCount` 同樣要 shard 或用 Function 批次更新。
2. **圖片 CDN**：Firebase Storage 直連沒 CDN，高流量頁用 Cloud CDN 或接 Cloudflare R2 + Image Resizing。
3. **冷啟動**：Cloud Functions 冷啟 1-3 秒。審核 Function 用 `minInstances: 1`（月 ~$5 換 UX）。

## Critical Failure Mode Gaps（必補）

1. **離線上傳**：image_picker 選完檔斷網，Flutter 預設會 lost。用 `firebase_storage` 的 `resumable upload` + local queue。
2. **審核中海報被使用者刪**：Cloud Function 要檢查文件存在，gracefully 結束，不丟 exception 卡重試迴圈。
3. **admin 誤刪**：見 #7 soft delete + audit log。
4. **圖片 CDN 失效**：`cached_network_image` 加 placeholder + retry，並設 `errorWidget` 顯示佔位圖而非崩潰。

## Worktree 並行開發建議（5 Lane）

```
Lane A (基礎建設, Day 0-3)
  ├─ Firebase projects × 3 + GitHub Actions
  ├─ Security Rules 骨架 + 測試框架
  └─ App Check + 預算警報

Lane B (Auth + Model, Day 3-7)  [depends A]
  ├─ Google Sign-In + Custom Claims
  ├─ freezed models + repositories
  └─ go_router + Riverpod scaffold

Lane C (瀏覽/搜尋/詳情, Day 7-14)  [depends B]     Lane D (上傳 + 審核, Day 7-14)  [depends B]
  ├─ 搜尋頁 + 列表分頁                              ├─ 上傳 form + image_cropper
  ├─ 詳情頁 + viewCount shard                        ├─ submission 建立（status=pending）
  └─ 收藏 + favorites snapshot                       └─ admin 審核 UI + Cloud Function

Lane E (上線準備, Day 14-18)  [depends C, D]
  ├─ Crashlytics + observability
  ├─ E2E 測試
  ├─ 隱私政策 + 刪除帳號 + DMCA 表單
  └─ Store submission
```

## NOT in scope（明確排除）

1. 排行榜 / 熱門排序（v2）
2. 使用者互動（留言、按讚）（v3）
3. 收藏清單分類（v2）
4. 海報版本整理（v3）
5. 進階篩選 UI（v2）
6. 社群 feed（v3）
7. 付費 / 贊助（未定）
8. 多語系（目前只中文）
9. 推播通知（v2，審核結果通知可進 MVP 但非必要）

## 已存在可直接用的輪子

- **firebase_ui_auth**：Google Sign-In UI 不用自己刻
- **firebase-extensions: resize-images**：縮圖 pipeline 官方版
- **firebase-extensions: delete-user-data**：GDPR 刪除帳號時一鍵刪所有 user 資料
- **cached_network_image**：圖片快取 + placeholder
- **image_cropper**：裁切 UI

## 結語

這個架構基本面 OK，Firebase + Flutter 對這個需求是合理選型。主要風險不在技術選型，在於：
- **Security Rules 沒測就是定時炸彈**（P0 優先）
- **成本攻擊**（App Check + 預算警報必開）
- **版權與 GDPR**（soft delete + audit + DMCA 流程必備）

先補 Day 0 基礎建設（三環境 + 測試 + CI/CD），再進 feature development。不要 YOLO 寫 rules 直接上線。


---

## 附錄：三個炸彈與 Day 0 的白話解釋

### 炸彈 1：Security Rules 沒測

Firebase 的權限不是寫在後端 code，是寫在 `firestore.rules` 檔案裡。例如：

```
match /posters/{id} {
  allow read: if resource.data.status == 'approved';
  allow write: if request.auth.token.role == 'admin';
}
```

這是一段邏輯，會寫錯。寫錯的後果不是 500 error，而是「全世界都能讀 users collection」或「任何人能把自己改成 admin」。Rules 錯誤通常不會讓 app 壞掉，app 跑得很順，只是資料外洩，你自己測不出來。

**解法**：用 `@firebase/rules-unit-testing` 寫測試，模擬「匿名使用者試圖讀 pending 海報 → 必須被拒絕」這種情境。每次改 rules 都跑一次。

不測 = 用生產環境的真實使用者幫你做 QA。

### 炸彈 2：成本攻擊

Firebase 按讀寫次數計費。有人寫腳本對你的 API 狂打，一晚上可以刷出幾千美金帳單。這不是假設，是 Firebase 社群經典事故。

**防禦**：
- **App Check**：只有你家 app（經過 Google attestation）能打 API，腳本打不進來
- **預算警報**：帳單超過 $5 / $20 / $50 先通知你，不要睡醒發現欠 Google $3000

### 炸彈 3：GDPR / 版權流程

- **GDPR（個資法）**：使用者有權要求「刪除我所有資料」。你要真的能一鍵刪乾淨，包括 Firestore + Storage + 收藏快照 + log。沒做好被檢舉會罰錢。
- **版權**：使用者上傳盜版海報，版權方寄 DMCA 下架通知，你必須在時限內移除。沒做 = 平台連帶責任。

這三件事都不是「功能」，demo 看不出來，容易被跳過。但上線後出事，每一件都是公司等級的麻煩。

### 「Day 0」是什麼

**Day 0** = 寫第一行 feature code 之前。
**YOLO** = 先衝 feature，資安測試之後再補。

不要先把上傳、搜尋、收藏做好，最後才想到要寫 rules 測試和 CI/CD。那時候：
- Rules 已經長很複雜，補測試超痛
- 沒有 staging 環境，bug 直接進 prod
- App Check 還沒開，上線第一週就可能被刷爆

**正確順序**：先花 2-3 天把地基做好（三環境、rules 測試框架、CI/CD、App Check、預算警報），再開始寫功能。後面每個 feature 都自動繼承這些防護。

白話：**蓋房子先打地基，不要先搬沙發進客廳。**
