# POSTER. V2 — 一頁式技術摘要

## 核心

做一個「可搜尋 / 收藏 / 投稿 / 審核」的電影海報收藏資料庫。
Tech stack: Flutter Web + Supabase (Postgres + Auth + Storage) + Riverpod + GoRouter

---

## 資料結構（最小必要）

```
users
works          ← 一部電影一筆
posters        ← 一張海報一筆（正式資料，只能審核產生）
submissions    ← 投稿待審核
favorites
poster_views
favorite_categories
audit_logs
```

### 關聯

```
works  1 ── N  posters
submissions  → (admin approve) →  posters
users  → favorites  → posters
users  → poster_views  → posters
users  → submissions
```

---

## Schema

### works（NEW）

| Column | Type | Note |
|--------|------|------|
| id | uuid PK | gen_random_uuid() |
| work_key | text UNIQUE | ⚠️ nullable — admin 用 title_zh + year 搜尋配對，不強制格式 |
| title_zh | text NOT NULL | 中文片名 |
| title_en | text | 英文片名 |
| movie_release_date | date | 電影上映日（屬於 work） |
| movie_release_year | int | 上映年份 |
| poster_count | int default 0 | 反正規化計數，RPC 維護 |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### posters（RESTRUCTURED）

| Column | Type | Note |
|--------|------|------|
| id | uuid PK | |
| work_id | uuid NOT NULL FK works | 每張海報屬於一部電影 |
| poster_name | text | e.g. "台灣院線正式版" |
| region | region_enum default 'TW' | 海報地區 |
| poster_release_date | date | 海報發行日（屬於 poster） |
| poster_release_type | release_type_enum | theatrical/reissue/special/limited |
| size_type | size_type_enum | B1/B2/A3/A4/mini/custom |
| channel_category | channel_cat_enum | cinema/distributor/lottery/exhibition/retail |
| channel_type | text | 分類內自由文字 |
| channel_name | text | e.g. "威秀影城" |
| is_exclusive | boolean default false | |
| exclusive_name | text | e.g. "IMAX 限定" |
| material_type | text | e.g. "紙質", "帆布" |
| version_label | text | e.g. "A版", "角色版-主角" |
| image_url | text NOT NULL | |
| thumbnail_url | text | |
| image_size_bytes | bigint | |
| source_url | text | 來源連結 |
| source_platform | text | e.g. "Facebook" |
| source_note | text | |
| uploader_id | uuid NOT NULL FK users | |
| reviewer_id | uuid FK users | |
| review_note | text | |
| reviewed_at | timestamptz | |
| status | poster_status default 'approved' | 既有資料預設 approved |
| view_count | bigint default 0 | RPC 維護 |
| favorite_count | bigint default 0 | RPC 維護 |
| tags | text[] | 保留，做輔助標籤 |
| approved_at | timestamptz | |
| created_at | timestamptz | |
| deleted_at | timestamptz | soft delete |

### submissions（NEW）

| Column | Type | Note |
|--------|------|------|
| id | uuid PK | |
| batch_id | uuid | NULL = 單張, 同值 = 同批次 |
| work_title_zh | text NOT NULL | 使用者填的，不一定對 |
| work_title_en | text | |
| movie_release_year | int | |
| poster_name | text | |
| region | region_enum default 'TW' | |
| poster_release_date | date | |
| poster_release_type | release_type_enum | |
| size_type | size_type_enum | |
| channel_category | channel_cat_enum | |
| channel_type | text | |
| channel_name | text | |
| is_exclusive | boolean default false | |
| exclusive_name | text | |
| material_type | text | |
| version_label | text | |
| image_url | text NOT NULL | |
| thumbnail_url | text | |
| image_size_bytes | bigint | |
| source_url | text | |
| source_platform | text | |
| source_note | text | |
| uploader_id | uuid NOT NULL FK users | |
| status | submission_status default 'pending' | pending/approved/rejected/duplicate |
| reviewer_id | uuid FK users | |
| review_note | text | |
| reviewed_at | timestamptz | |
| matched_work_id | uuid FK works | admin 配對或新建 |
| created_poster_id | uuid FK posters | 核准後回填 |
| created_at | timestamptz | |

### poster_views（NEW）

| Column | Type | Note |
|--------|------|------|
| user_id | uuid FK users | PK 之一 |
| poster_id | uuid FK posters | PK 之一 |
| viewed_date | date default current_date | PK 之一 |

PRIMARY KEY (user_id, poster_id, viewed_date)

### users（EXTENDED）

新增欄位：
| Column | Type | Note |
|--------|------|------|
| is_public | boolean default true | 公開個人檔案 |
| bio | text | 自介 |

### Enums

```sql
CREATE TYPE region_enum AS ENUM (
  'TW','KR','HK','CN','JP','US','UK','FR','IT','PL','BE','OTHER'
);

CREATE TYPE release_type_enum AS ENUM (
  'theatrical','reissue','special','limited','other'
);

CREATE TYPE size_type_enum AS ENUM (
  'B1','B2','A3','A4','mini','custom','other'
);

CREATE TYPE channel_cat_enum AS ENUM (
  'cinema','distributor','lottery','exhibition','retail','other'
);

CREATE TYPE submission_status AS ENUM (
  'pending','approved','rejected','duplicate'
);
```

---

## 必守規則

### 1. ID 規則

| ID | 格式 | 範例 |
|----|------|------|
| workId / posterId / submissionId | UUID v4 | `a1b2c3d4-...` |
| work_key | `{slug}-{release-date}` or NULL | nullable UNIQUE, admin 可手動填或留空 |
| favoriteId | composite PK: `(user_id, poster_id)` | |
| viewId | composite PK: `(user_id, poster_id, YYYY-MM-DD)` | |
| batchId | UUID v4（client 產生） | |

### 2. 分離兩種日期

- 電影上映日 → `works.movie_release_date`
- 海報發行日 → `posters.poster_release_date`

### 3. 瀏覽數規則

同 user + 同 poster + 同一天 → 只算 1 次（poster_views composite PK 保證）

### 4. 正式資料只能「審核產生」

```
user → submissions → (admin approve) → posters
```

前端不能直接寫 posters。

### 5. 計數只能後端改

- `view_count` → RPC: `increment_view_with_dedup()`
- `favorite_count` → RPC: `toggle_favorite()`
- `poster_count` → RPC: `approve_submission()`

前端不能直接 UPDATE 這些欄位。用 Supabase RPC（等同 Cloud Functions）。

---

## 權限

| 角色 | 權限 |
|------|------|
| user | 瀏覽 / 收藏 / 投稿 / 看自己的 submissions |
| admin | 審核 submissions, 管理 posters |
| owner | 管理 admin / 最終修改 |

RLS policies 保證：
- `posters`: 所有人可讀 approved, 只有 admin 可寫
- `submissions`: 本人可讀自己的, admin 可讀全部
- `poster_views`: 本人可寫自己的
- `favorites`: 本人可讀寫自己的
- `works`: 所有人可讀, admin 可寫
- `audit_logs`: admin 可讀

---

## 必做 RPC（Supabase Edge Functions / SQL Functions）

### 1. increment_view_with_dedup(poster_id)

```sql
-- 嘗試 INSERT poster_views
-- ON CONFLICT DO NOTHING（同 user + poster + 今天）
-- 如果真的 INSERT 了 → view_count +1
```

### 2. toggle_favorite(poster_id)

```sql
-- ⚠️ ON CONFLICT + SELECT FOR UPDATE 防 race condition
BEGIN;
  -- 嘗試取得鎖
  SELECT id FROM posters WHERE id = poster_id FOR UPDATE;
  -- 檢查是否已收藏
  IF EXISTS (SELECT 1 FROM favorites WHERE user_id = auth.uid() AND poster_id = $1) THEN
    DELETE FROM favorites WHERE user_id = auth.uid() AND poster_id = $1;
    UPDATE posters SET favorite_count = favorite_count - 1 WHERE id = $1;
  ELSE
    INSERT INTO favorites (user_id, poster_id) VALUES (auth.uid(), $1)
      ON CONFLICT DO NOTHING;
    UPDATE posters SET favorite_count = favorite_count + 1 WHERE id = $1;
  END IF;
COMMIT;
```

### 3. approve_submission(submission_id, work_id?)（核心）

```sql
-- ⚠️ 必須 transaction wrapping，失敗整包 rollback
BEGIN;
  1. 如果 work_id 有值 → 用既有 work
  2. 如果 work_id 為 NULL → 建新 work（從 submission 資料）
  3. INSERT INTO posters SELECT ... FROM submissions WHERE id = $1
     -- ⚠️ INSERT...SELECT 維持 submissions/posters 分離
  4. UPDATE works SET poster_count = poster_count + 1 WHERE id = work_id
  5. UPDATE submissions SET status = 'approved', created_poster_id = new_poster_id
  6. INSERT audit_log
COMMIT;
-- 任一步驟失敗 → ROLLBACK，不會產生孤兒資料
```

### 4. reject_submission(submission_id, note)

```
1. submission.status → 'rejected'
2. submission.review_note → note
3. INSERT audit_log
```

### 5. home_sections()（NEW — 效能優化）

```sql
-- 首頁 8 個 section 合併成 1 個 RPC，1 round-trip 取代 8 個
-- 回傳 JSON: [{title, items: [poster, ...]}, ...]
-- 每個 section 內部用對應的 filter/sort
```

### 6. list_favorites_with_posters(uid, offset, limit)（NEW — 效能優化）

```sql
-- 取代 client-side IN clause 做法
-- DB 層 JOIN favorites + posters，直接分頁回傳
-- 解決收藏數量多時 IN clause 超過 URL 長度限制
SELECT p.* FROM favorites f
  JOIN posters p ON p.id = f.poster_id
  WHERE f.user_id = $1 AND p.deleted_at IS NULL
  ORDER BY f.created_at DESC
  LIMIT $3 OFFSET $2;
```

### 7. top_tags(limit)（NEW — 取代 client-side 計算）

```sql
-- 取代目前 client-side 撈 500 筆再計算的做法
SELECT tag, count(*) as cnt
  FROM posters, unnest(tags) AS tag
  WHERE status = 'approved' AND deleted_at IS NULL
  GROUP BY tag ORDER BY cnt DESC LIMIT $1;
```

---

## favorites schema 變更

⚠️ **移除 denormalized 欄位**：`poster_title` 和 `poster_thumbnail_url` 從 favorites 表刪除。
改用 JOIN 解析。原因：denorm 資料會跟 poster 更新脫節（poster rename 後收藏還顯示舊名）。

```sql
ALTER TABLE favorites DROP COLUMN IF EXISTS poster_title;
ALTER TABLE favorites DROP COLUMN IF EXISTS poster_thumbnail_url;
```

---

## MVP 功能

### User 端

- [x] Google 登入（Supabase Auth）
- [x] 海報列表 / 搜尋
- [x] 海報詳情
- [x] 收藏
- [x] 單張投稿
- [x] 投稿確認頁（preview before submit）
- [x] 結構化 metadata 表單（region, channel, size...）

### Admin 端

- [x] 待審核列表
- [x] 審核（approve / reject）
- [x] Work 配對 UI（搜尋既有 or 建新的）
- [x] 批次投稿（/upload/batch，共用 work info + N 張海報）

---

## Jira Task 拆分

### EPIC 1: Schema Migration（資料基礎）

- [x] 建立 enums（region_enum, release_type_enum, size_type_enum, channel_cat_enum, submission_status）
- [x] 建立 works table（⚠️ work_key 為 nullable UNIQUE）
- [x] 建立 submissions table
- [x] 建立 poster_views table
- [x] posters 加新欄位（work_id, region, poster_release_date, size_type, channel_*, source_*, etc.）
- [x] users 加新欄位（is_public, bio）
- [x] favorites 移除 denorm 欄位（poster_title, poster_thumbnail_url）
- [x] 新 table 的 RLS policies + GRANT EXECUTE on RPCs
- [x] 資料回填 migration（20260416100400_backfill_and_cleanup.sql，已 push）
- [x] 測試：migration 驗證（migration_validation_test.dart, 4 tests）

### EPIC 2: Dart Models & Repositories

- [x] Work model（work.dart）
- [x] Submission model（submission.dart）
- [x] 擴充 Poster model（新欄位）
- [x] 擴充 AppUser model（is_public, bio）
- [x] WorkRepository（CRUD, search by title_zh + year）
- [x] SubmissionRepository（取代 poster_upload_repository）
- [x] ViewRepository（call dedup RPC + ⚠️ session-level Set 擋重複）
- [x] UserRepository（public profiles, search users）← EPIC 7 完成
- [x] 更新 PosterRepository（join works, 用 list_favorites_with_posters RPC）
- [x] 更新 FavoriteRepository（改用 toggle_favorite RPC，移除 denorm 寫入）
- [x] 測試：每個 model 的 fromRow/toJson round-trip 測試（35 tests passing）

### EPIC 3: RPC / Edge Functions

- [x] increment_view_with_dedup()
- [x] toggle_favorite()（⚠️ ON CONFLICT + SELECT FOR UPDATE 防 race condition）
- [x] approve_submission()（⚠️ 必須 transaction wrapping）
- [x] reject_submission()
- [x] home_sections()（⚠️ 新增 — 首頁 8 section 合併查詢）
- [x] list_favorites_with_posters()（⚠️ 新增 — 取代 IN clause）
- [x] top_tags()（⚠️ 新增 — 取代 client-side 500 rows 計算）
- [x] 每個 RPC 末尾加 GRANT EXECUTE ON FUNCTION ... TO authenticated
- [x] 測試：RPC integration tests（submission_repository_test.dart, 5 tests）

### EPIC 4: Upload Redesign（投稿）

- [x] 投稿表單加結構化欄位（region, channel, size, source...）
- [x] work title auto-suggest（_WorkTitleAutocomplete widget, debounced search）
- [x] 確認頁 UI（_ConfirmSheet bottom sheet + _SummaryRow）
- [x] 寫入 submissions table（不再寫 posters）
- [x] 我的投稿頁顯示 submission status（使用 Submission model + V2 provider）

### EPIC 5: Admin Review Upgrade

- [x] 審核列表從 submissions table 拉
- [x] Work 配對 UI：搜尋既有 work or 建新 work
- [x] Approve flow：submission → poster + work（via approve_submission RPC）
- [x] Reject flow：填 review_note（via reject_submission RPC）
- [x] batch_id 群組顯示（_BatchGroup widget, grouped ListView）
- [x] Duplicate 偵測提示（_duplicateCountProvider + amber warning banner）

### EPIC 6: View Tracking

- [x] poster_views schema（已在 EPIC 1）
- [x] 詳情頁觸發 increment_view_with_dedup（via ViewRepository）
- [x] ⚠️ Dart 端加 session-level Set<String> 擋同 session 重複 view RPC
- [x] 移除舊的 atomic counter RPC（backfill migration drops increment_poster_view_count + review_poster）
- [x] 測試：view dedup 行為驗證（view_dedup_test.dart, 5 tests）

### EPIC 7: User Discovery

- [x] users.is_public + profile 設定 toggle（_PrivacyToggle widget + updateOwnProfile）
- [x] PublicProfilePage（/user/:id，含 avatar, bio, 已通過海報 grid）
- [x] 搜尋加入 users（search_users RPC + unified_search RPC）
- [x] 探索頁「社群動態」section（social_activity_feed RPC）

### EPIC 8: Batch Upload

- [x] batch upload flow UI（BatchSubmissionPage: shared work info + N poster cards）
- [x] client 產生 batchId（Uuid().v4() 共用給整批）
- [x] concurrent image upload（Future.wait 平行上傳 + insert）
- 說明：批次流程沒有獨立確認頁；所有卡片先預覽後整批送出。

### EPIC 9: Search Upgrade

- [x] pg_trgm + GIN index（works, posters, users 6 個 GIN indexes）
- [x] full-text search on works（title_zh, title_en via ilike + trgm）
- [x] full-text search on posters（title, poster_name, channel_name）
- [x] unified search page：grouped results（works, posters, users）

### EPIC 11: Social Signals & Follows（NEW — 2026-04-17）

**目標**：把 home page 從「一堆海報」升級成「能看到誰、在做什麼、為什麼重要」。
Spotify 風格 actor-first sections + follow graph 預留。

**Schema**：
- 新表 `follows (follower_id, followee_id, created_at)` — composite PK，CHECK 防自追
- RLS：公開 graph（任何人可讀），本人可寫/刪自己的
- Index: `idx_follows_followee`（反查「誰追蹤我」）
- **不**加 users.follower_count/following_count denorm 欄位（review #5 教訓）

**設計決定**：
1. follows 是公開 graph（IG/Twitter 模式），不做隱私追蹤
2. 防自追：DB CHECK + RPC 擋 + UI hide 三層
3. User 切回 `is_public=false` 時保留 follows 紀錄，只是 feed 不顯示其活動
4. 「追蹤的人最近在收」section 放熱門下面、編輯策展上面；登入+有追蹤才顯示

**RPCs**：
- [x] `toggle_follow(p_user_id) → bool` — 追蹤/取消
- [x] `trending_favorites(p_days=7, p_limit=10)` — 本週最多人收藏 + top 3 collector avatars
- [x] `active_collectors(p_days=7, p_limit=12)` — 最近活躍公開用戶 + 各自最近 3 張收藏縮圖
- [x] `follow_feed(p_limit=20)` — 我追蹤的人最近 favorites + submissions
- [x] `user_relationship_stats(p_user_id) → jsonb` — {follower_count, following_count, is_following_me, am_i_following}
- [x] rename `social_activity_feed` → `recent_approved_feed`

**Repositories + Models**：
- [x] `FollowRepository`（toggle / stats）
- [x] `SocialRepository`（trending / active_collectors / follow_feed / recent_approved_feed）
- [x] Models: `TrendingPoster`, `CollectorPreview`, `MiniUser`, `UserRelationshipStats`, `FollowActivity`, `PosterThumb`
- [x] Poster model 擴充 `uploaderName` / `uploaderAvatar`（optional，從 social RPC 帶回）

**UI**：
- [x] `_FeedCard` 右下角加 22px uploader avatar overlay + 獨立 tap 跳 /user/:id
- [x] Home 重排 sections：熱門 → 追蹤的人最近在收（空則隱） → 本週最多人收藏 → 活躍收藏家 → 編輯策展 → 剛上架（rename from 社群動態）→ 最新上架
- [x] 新 section：本週最多人收藏（`_TrendingRow` + `_TrendingCard` + `_AvatarStack` 疊頭像）
- [x] 新 section：活躍收藏家（`_CollectorsRow` + `_CollectorCard`：48px 大頭像 + 名字 + N 次活動 + 底部 3 張 mini-thumb）
- [x] 新 section：追蹤的人最近在收（`_FollowFeedRow`，重用 `_FeedCard` 但注入 actor 資訊）
- [x] `FollowPill` widget — outlined 未追蹤 / filled 追蹤中 / 動畫過渡 / 樂觀更新 + 失敗回滾
- [x] Integrate follow pill 到 PublicProfilePage 頭像旁 + SearchPage `_UserTile` trailing（compact 模式）
- [x] PublicProfilePage 加統計列：「追蹤者 · 追蹤中 · 已通過 · 投稿」4 欄數字 + 「追蹤你」reverse tag

**Performance 預留**：
- 現在 scale sub-100ms 夠用
- 未來到 100k favorites/day 需要：`idx_favorites_created_at`（partial: last 30d）+ `trending_favorites` 升級為 materialized view

**Jira Task 拆解**：

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 11-1 | Schema migration: follows + RLS + indexes | ✅ | S |
| 11-2 | 6 RPCs (toggle_follow, trending_favorites, active_collectors, follow_feed, user_relationship_stats, rename) | ✅ | M |
| 11-3 | Dart models + FollowRepository + SocialRepository | ✅ | M |
| 11-4 | `_FeedCard` uploader avatar overlay | ✅ | XS |
| 11-5 | Home: 重排 + 3 新 section + 空態處理 | ✅ | M |
| 11-6 | `_CollectorCard` 新卡型 | ✅ | S |
| 11-7 | `_FollowPill` + integrate PublicProfile + SearchPage | ✅ | S |
| 11-8 | PublicProfilePage 統計列 | ✅ | XS |
| 11-9 | Tests: models fromRow + RPC param shape | ✅ | S |
| 11-10 | 更新 v2-architecture.md + audit 表 | ✅ | XS |

**驗證**：flutter analyze 0 errors / 0 warnings, flutter test **72/72 pass**

執行順序：11-1 → 11-2 → 11-3 → (11-4 // 11-5 // 11-6 // 11-7) → 11-8 → 11-9 → 11-10

---

### EPIC 12: Font Bundling（修豆腐字）— 2026-04-17 規劃

**問題**：Flutter Web + CanvasKit renderer + 只用 `google_fonts` CDN，第一幀中文顯示 tofu（豆腐字）。

**根因**：
1. Google Fonts 執行時才下載，冷快取 = 沒字型
2. `pubspec.yaml` 的 `fonts:` 區塊整段被 comment 掉
3. CanvasKit 沒 fallback CJK glyph 庫

**解法**：Bundle Noto Sans TC subset 成 local asset。

**Task 拆解**：

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 12-1 | 下載 Noto Sans TC（SubsetOTF/TC Regular + Medium，pyftsubset 再砍到 CJK 常用區塊） | ✅ | XS |
| 12-2 | 放進 `assets/fonts/`（2 檔約 7.5MB），pubspec.yaml 宣告 2 個 weight | ✅ | XS |
| 12-3 | `app_theme.dart`：`fontFamily: 'NotoSansTC'`，拔除 google_fonts import 與 dependency | ✅ | S |
| 12-4 | `web/index.html`：黑底 splash + POSTER. 字樣 + spinner，觀察 `<flt-glass-pane>` 出現後 fade 移除 | ✅ | XS |
| 12-5 | flutter analyze 0 errors / flutter test 72/72 pass | ✅ | XS |
| 12-6 | 更新 v2-architecture.md 打勾 | ✅ | XS |

**實作筆記**：
- 想過用 WOFF2（~50% 小）但 Flutter pubspec 不官方支援，放棄
- SemiBold (w600) 從 Noto CJK github 載不到（官方只有 400/500/700），theme 用 w600 時 CanvasKit 自動從 Medium (w500) synthesize，視覺差異不明顯，省 ~4.5MB
- 字體 charset 只收 Latin + CJK Unified (U+4E00-9FA5)，無日文假名（目前 UI 不用）；以後 i18n 加日文版時要擴 subset
- `<html lang="zh-Hant">` 標對，避免瀏覽器 fallback font 亂猜

執行順序：12-1 → 12-2 → 12-3 → 12-4 → 12-5 → 12-6

---

### EPIC 13: Content Moderation Automation（內容審查自動化）— ⚠️ 寫進 md，暫不實作

**狀態**：規格已寫，等使用者決策再實作（審查成本 ~$30/月 + 策略選擇）。

**問題**：目前 admin 審查每張 poster 都肉眼看，不 scale。開放平台需要 5 層自動化審查，admin 只需看剩下 5-10% flagged 的內容。

**5 層審查架構**：

1. **Hash 指紋比對**（自動、毫秒）
   - 上傳時算 pHash / MD5
   - 比對：歷史 reject blacklist + PhotoDNA（CSAM 防護，免費給 startup）+ 版權黑名單
   - 命中 → 自動拒絕

2. **第三方 ML 審查 API**（自動、~1 秒）
   - AWS Rekognition Moderation 或 Google Cloud Vision SafeSearch
   - 回傳 {Nudity, Violence, Suggestive, Weapons, Drug_Use, Gambling} 分數
   - < 0.4 全過 = 候選通過；≥ 0.7 任一 = 自動拒絕；0.4-0.7 = admin queue

3. **內容分類**（這是不是海報？）
   - Rekognition Labels API 回傳 {Poster, Print, Art, ...} 信心分數
   - Poster/Print < 0.5 → flag「這不是海報」

4. **User trust score**
   - 通過率 > 80% 且 > 10 筆 → trusted，前 3 層全過即 auto-approved
   - 新帳號（< 7 天 / < 3 投稿）→ 永遠進 admin queue
   - 被檢舉/有 rejection → score 降

5. **社群檢舉**
   - 每張 approved poster 有「檢舉」按鈕
   - 累積 3 個檢舉 → 自動暫下架 + 進 admin queue

**AI-generated 禁止政策**：
- v1：TOS 條款 + 投稿 checkbox「我確認此海報非 AI 生成」
- v2（未來）：整合 Hive.ai AI detector（$0.005/張，80-90% 準確率）
- **Schema 不加 `ai_generated` flag**（因為一律禁止，通過的預設非 AI）

**Schema 新增**：
```sql
alter table submissions add column moderation_scores jsonb;
alter table submissions add column moderation_flags text[];
alter table users add column trust_score float default 0;
alter table users add column approved_count int default 0;
alter table users add column rejected_count int default 0;

create table poster_reports (
  id uuid primary key,
  poster_id uuid references posters(id),
  reporter_id uuid references users(id),
  reason text,
  status text default 'pending',
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

create table known_bad_hashes (
  id uuid primary key,
  phash text unique,
  source text,            -- 'admin_reject' | 'photodna' | 'community'
  added_at timestamptz
);
```

**Task 拆解**（等使用者決策後啟動）：

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 13-1 | 選定 moderation API（AWS Rekognition vs Google Vision vs Hive.ai） | [ ] TBD | — |
| 13-2 | Supabase Edge Function：呼叫 moderation API + 寫 moderation_scores | [ ] | M |
| 13-3 | pHash 計算 + known_bad_hashes blacklist | [ ] | S |
| 13-4 | Trust score 計算規則 + 觸發條件 | [ ] | M |
| 13-5 | poster_reports schema + 檢舉 UI + admin queue | [ ] | M |
| 13-6 | AI-generated TOS checkbox + 未來接 detector | [ ] | S |
| 13-7 | Tests: moderation thresholds / trust score transitions | [ ] | S |

**TBD 討論項目**：
- 用哪家 moderation API？（成本 vs 準確率 vs 地區可用性）
- Trust score 閾值（approved_count >= 10 太嚴？）
- 社群檢舉的 threshold（3 夠嗎？）
- 誤判申訴流程（appeal）

---

### EPIC 14: Dynamic Home Sections（簡化版）— 2026-04-17 規劃

**問題**：
1. 現在 `home_sections()` RPC 裡 6 個 tag 寫死（收藏必備/經典/日本/台灣/手繪/大師），改動要 migration
2. 「最新上架」「剛上架」內容重複（`created_at` 與 `approved_at` 在 approve 時同一 `now()`）

**解法**：把 section 設定移進 DB，不再 hardcode。先做**簡化版**（無排程、無 A/B、無 audience 規則），未來再擴。

**Schema 新增**：
```sql
create table home_sections_config (
  id uuid primary key,
  slug text unique not null,           -- 'popular', 'japan_tag', 'for_you'
  title_zh text not null,
  title_en text not null,
  icon text,                           -- lucide icon name
  source_type text not null,           -- 'tag' | 'popular' | 'trending_favorites' | 'active_collectors' | 'follow_feed' | 'recent_approved' | 'for_you_feed'
  source_params jsonb,                 -- {'tag': '日本'} or {'days': 7, 'limit': 10}
  position int not null,
  enabled boolean default true,
  visibility text default 'always',    -- 'always' | 'signed_in' | 'has_follows'
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

**決策紀錄**：
1. **砍掉「最新上架」section**（跟「剛上架」重複）
2. 6 個 tag sections 遷移到 config，之後隨 EPIC 18 的 tag taxonomy 重整一起調整（可能會被新的 faceted browse 取代）
3. 先不加 schedule / starts_at / ends_at / audience_rule（YAGNI）

**Task 拆解**：

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 14-1 | Schema migration: `home_sections_config` + seed rows | [ ] | S |
| 14-2 | RPC `home_sections_v2(p_user_id?)`：讀 config、依 source_type dispatch 對應子 RPC | [ ] | M |
| 14-3 | Dart repository 改讀新 RPC | [ ] | S |
| 14-4 | Home page：移除 `_homeSectionsProvider` 分散邏輯，統一來源 | [ ] | S |
| 14-5 | 砍掉「最新上架」section | [ ] | XS |
| 14-6 | Tests: config row → rendered section 對應 | [ ] | S |

執行順序：14-1 → 14-2 → (14-3 // 14-4) → 14-5 → 14-6

---

### EPIC 15: Recommendation Engine（「為你推薦」）— 2026-04-17 規劃

**目標**：使用者看到個人化推薦，基於他收藏過的海報 tag 風格。

**分兩個 method 並行**：

**Method 1 — Real-time tag affinity**（立刻上線）
- 一個 RPC `for_you_feed_v1(p_limit)`
- 邏輯：抓使用者 favorites 的 top 5 tag + 出現次數當權重 → 找有這些 tag 的海報（排除已收藏） → 按 tag overlap 分數排序
- 冷啟動 fallback 寫在 RPC 內部：`if 我的收藏 < 3 → return trending_favorites`
- 無批次、無新表

**Method 3 — Collaborative filtering**（先做起來放）
- `user_recommendations` 表儲存每晚批次結果
- `pg_cron` 每晚 03:00 執行批次 job
- 邏輯：對每個 user 找「跟我有 ≥ 3 張共同收藏」的相似用戶 top 50 → 從他們的收藏裡取我沒看過的、累積分數高的 30 張
- 新 RPC `for_you_feed_cf(p_limit)` 讀表
- **有完整 tests**，先不開給 user

**上線策略**：
- v1 只用 Method 1（tag affinity）
- Method 3 完成後 + 用戶量夠（> 100 active、> 1000 favorites）再切換 / 混合

**Schema 新增**：
```sql
create table user_recommendations (
  user_id uuid,
  poster_id uuid,
  score float,
  reason text,                    -- 'similar_favorites' | 'tag_match:日本'
  job_slug text,                  -- 'cf_nightly'
  computed_at timestamptz,
  primary key (user_id, poster_id, job_slug)
);

create table recommendation_jobs (
  slug text primary key,
  algorithm text,
  params jsonb,
  cron_expr text,                 -- '0 3 * * *' 每天 03:00
  enabled boolean,
  last_run_at timestamptz
);
```

**Task 拆解**：

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 15-1 | RPC `for_you_feed_v1`（tag affinity + cold-start fallback） | [ ] | M |
| 15-2 | SocialRepository 加 `forYouFeed()` + provider | [ ] | S |
| 15-3 | Home page 新增「為你推薦」section（位置：熱門下面、追蹤動態上面） | [ ] | S |
| 15-4 | Schema: `user_recommendations` + `recommendation_jobs` | [ ] | S |
| 15-5 | 啟用 pg_cron extension | [ ] | XS |
| 15-6 | Collaborative filtering 批次 job（SQL function + cron） | [ ] | M |
| 15-7 | RPC `for_you_feed_cf` 讀 user_recommendations 表 | [ ] | S |
| 15-8 | Tests: tag affinity 排序 / 冷啟動 fallback / CF 相似度算法 | [ ] | M |

執行順序：15-1 → 15-2 → 15-3 **(Method 1 上線)** → 15-4 → 15-5 → 15-6 → 15-7 → 15-8 **(Method 3 做起來放)**

---

### EPIC 16: TMDB Optional Helper — 延後

**範圍**：投稿時使用者可以打電影名字 → 搜尋 TMDB → 選中自動填標題/年份/導演。**不強制**。找不到 TMDB 就允許手動建 work。

**延後理由**：EPIC 13 的審查機制先定，TMDB 只是錦上添花，不是關鍵路徑。

---

### EPIC 17: i18n（zh-TW + en）— 延後

**範圍**：`flutter_localizations` + gen-l10n + ARB 檔。

**延後理由**：
1. 字型問題先解（EPIC 12）
2. EPIC 18 tag taxonomy 完成後，tag label 本身就有 `label_zh` / `label_en` → i18n 範圍縮小 70%，只剩 UI chrome
3. 目前使用者 99% 是台灣人，英文版優先度低

---

### EPIC 18: Tag Taxonomy Redesign ⭐️ 核心大項 — 2026-04-17 規劃

**問題診斷**：
- 現有 `posters.tags text[]` 是扁平字串陣列，混合了國別 / 年代 / 媒材 / 設計師等不同維度
- 6 個 home section tag (收藏必備/經典/日本/台灣/手繪/大師) 語義混亂，無法做多維度篩選
- 現在 `works` 綁定「電影」假設，馬戲團/演唱會/原創藝術海報 schema 上無法乾淨處理
- `size_type_enum` 過於簡化（B1/B2/A3/A4/mini/custom），收藏家會不滿意
- 沒有 i18n 底層支撐

**設計原則**：
- Faceted taxonomy（多維度並行）— 一張海報可同時有 5-8 個 tag 橫跨多 category
- 不縮限範圍（設計師國籍、作品類型），open platform 精神
- 不預設所有 poster 都有「作者/設計師」（馬戲團可能沒有可追溯作者）
- Tag 是 **admin 定義 canonical**，使用者不能自由新增（避免污染）
- 使用者找不到 tag 有 3 層 fallback

### 9+1 個 tag categories

基於對 r/MoviePosters、Polska Szkoła Plakatu、日本 chirashi 圈、Mondo、Heritage 拍賣、eMoviePoster、IMPAwards、台灣設計圈（聶永真/王志弘/方序中/黃海等）的實地研究：

1. **國別 (country of issue)** — 海報印刷市場
   - ENUM 擴充現有 `region_enum`：美版/英版/日版/台版/港版/中國版/韓版/法版/義版/德版/波蘭版/捷克版/古巴版/蘇聯版/澳版/印度版/泰版/越版/土耳其版/其他
   - **重要**：海報的「印刷市場」≠ 電影的「出品國」。波蘭海報派幫美國片畫的超現實版 → 兩個都要標

2. **年代 (era)** — free tag
   - 默片時代 / 黃金年代 1930s-40s / 1950s / 1960s / 1970s New Hollywood / 1980s / 1990s / 2000s / 2010s / 2020s
   - 主題年代：港片黃金期 / 台灣新電影 / 昭和 / 平成 / 令和 / Polish Poster School 黃金期

3. **媒材/技法 (medium & technique)** — free tag
   - offset litho / stone litho 石版 / silkscreen 絹印 / letterpress 活版 / woodblock 木刻 / hand-painted 手繪 / photo-montage 攝影拼貼 / illustration 插畫 / typographic 字體設計 / collage / foil 燙金 / embossed 壓印 / risograph / AI-generated (**禁止收錄**)

4. **設計師 (designer)** — controlled vocab with aliases
   - 初期 seed ~30-40 位知名設計師：台灣、日本、波蘭、美國、歐洲
   - 台灣/華語：聶永真、王志弘、方序中、何佳興、黃海、致禾、霧室、Bito、陳世川
   - 西方：Saul Bass, Drew Struzan, Reynold Brown, Bob Peak, Bill Gold, Tyler Stout, Olly Moss, Martin Ansin, Laurent Durieux
   - 波蘭：Jan Lenica, Roman Cieślewicz, Franciszek Starowieyski, Andrzej Pągowski
   - 日本：横尾忠則, 粟津潔, 石岡瑛子
   - **完整 canonical 列表會持續增長**（使用者建議 queue 驅動）

5. **版本 (edition type)** — ENUM 擴充現有 `release_type_enum`
   - 院線首刷 / 二刷再版 / teaser 前導 / international / 影展版 / 角色版 / style A/B / IMAX / Dolby / 限定版 / AP artist proof / PP printer's proof / variant / timed release / 未採用稿 / 非官方 bootleg / 同人 fan art

6. **規格 (size/format)** — ENUM 大幅擴充
   - 現有：B1/B2/A3/A4/mini/custom（太簡化）
   - 擴充：US One Sheet (27×41) / Half Sheet / Insert / Subway / UK Quad (landscape) / French Grande / Italian Due Fogli / Italian Locandina / Polish A1 (23×33) / Japan B1 (728×1030) / Japan B2 (515×728) / Japan B0 / Chirashi チラシ / Australian Daybill / 台灣全開/對開/四開 / Mondo standard (24×36) / Lobby Card / Fotobusta / Press Kit

7. **Chirashi 專屬** — 日本 chirashi 自成一格的次分類
   - Type A / B / C（序列發放）/ 前売 mae-uri / 試写会 / 両面印刷 / glossy / matte

8. **美學 (visual aesthetic)** — free tag
   - minimalist / maximalist / photo-realist painted (Struzan 風) / floating heads 浮頭 / big face 大頭照 / typographic-led / silhouette / surreal (波蘭風) / pop art / noir 黑色電影風 / watercolor 水彩 / ink-wash 水墨 / risograph-aesthetic / retro reissue

9. **收藏價值 (condition & provenance)**
   - Grading ENUM（跟 Heritage / eMoviePoster 對齊）：Mint / Near Mint / Very Fine / Fine / Very Good / Good / Fair
   - Boolean flags（新增 poster 欄位）：`signed` 親簽 / `numbered` 編號 / `linen_backed` 裱布 / `licensed` 授權
   - Tag：rolled 捲筒 / folded 摺疊 / restored 修復 / pinholes / fading 褪色 / COA 真品證書 / 戲院使用過

10. **作品類型 (work_kind)** — **NEW ENUM，解決馬戲團盲點**
    ```sql
    create type work_kind_enum as enum (
      'movie',          -- 電影（最多）
      'concert',        -- 演唱會 / 音樂會
      'theatre',        -- 戲劇 / 舞台劇
      'exhibition',     -- 展覽
      'event',          -- 活動（馬戲團、馬拉松、節慶）
      'original_art',   -- 原創作品（無外部 reference）
      'advertisement',  -- 商業廣告
      'other'
    );
    alter table works add column work_kind work_kind_enum default 'movie';
    ```
    投稿 flow 第一步問「這張海報是關於什麼？」→ 選 kind → 不同 kind 走不同表單（電影問年份/導演，活動問日期/地點）

### Schema 新增

```sql
create table tag_categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title_zh text not null,
  title_en text not null,
  description_zh text,
  description_en text,
  position int not null,
  icon text,                              -- lucide icon name
  kind text not null,                     -- 'enum' | 'controlled_vocab' | 'free_tag'
  is_required boolean default false,      -- 投稿必填？
  allow_other boolean default true,       -- 「其他」fallback tag？
  allows_suggestion boolean default true, -- 可建議新 tag？
  created_at timestamptz default now()
);

create table tags (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  category_id uuid references tag_categories(id) on delete restrict,
  label_zh text not null,
  label_en text not null,
  description text,
  aliases text[] default '{}',            -- ['miyazaki','ミヤザキ','宮崎駿']
  poster_count int default 0,             -- denorm, periodic refresh
  is_canonical boolean default true,      -- admin-approved vs user-suggested
  is_other_fallback boolean default false,-- 標記此為「其他」fallback tag
  deprecated boolean default false,
  created_by uuid references users(id),
  created_at timestamptz default now()
);

create index idx_tags_category on tags(category_id) where deprecated = false;
create index idx_tags_aliases_gin on tags using gin (aliases);

create table poster_tags (
  poster_id uuid references posters(id) on delete cascade,
  tag_id uuid references tags(id) on delete cascade,
  added_by uuid references users(id),
  added_at timestamptz default now(),
  primary key (poster_id, tag_id)
);
create index idx_poster_tags_tag on poster_tags(tag_id);

create table tag_suggestions (
  id uuid primary key default gen_random_uuid(),
  suggested_by uuid references users(id),
  suggested_slug text,
  suggested_label_zh text not null,
  suggested_label_en text,
  category_id uuid references tag_categories(id),
  reason text,
  linked_submission_id uuid references submissions(id),
  status text default 'pending',          -- pending | approved | rejected | merged
  merged_into_tag_id uuid references tags(id),
  reviewed_by uuid references users(id),
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz default now()
);
```

### Fallback 機制（使用者找不到 tag）

**Flow A — Tag 存在但搜不到（拼法/變體）**
- `tags.aliases text[]` 欄位
- 搜索 UI 用 ILIKE 同時比對 `label_zh + label_en + aliases`
- 使用者打 "miyazaki" → 找到宮崎駿。admin 零介入

**Flow B — Category 必填但真的沒有對的 tag**
- 每個 required category 預先 seed canonical「**其他 Other**」tag（`is_other_fallback=true`）
- 使用者選「其他」完成投稿
- admin 審稿看到 `其他_country` + submission 標題 → 判斷要不要新增該國別 tag

**Flow C — 使用者有具體建議**
- Tag picker UI 有「**建議新增 tag**」按鈕
- 開小 form：category + label_zh + label_en + reason
- 寫進 `tag_suggestions` queue（獨立於 poster review）
- **建議不擋投稿**——投稿用「其他」照送
- admin 批准後 auto-apply 新 tag 到觸發的 poster

### AI-generated 禁止執行

- v1：投稿頁必勾「我確認此海報非 AI 生成」checkbox（否則無法送出）
- TOS 條款寫明違者永久停權
- 社群檢舉機制（EPIC 13）補捉漏網之魚
- v2（未來）：EPIC 13 整合 AI detector API 自動阻擋
- **Schema 不加 `ai_generated` flag**——一律禁止，通過的都預設非 AI

### Admin UI MVP（最小範圍）

**做**：`/admin/tag-suggestions` 頁面，三個動作：批准 / 拒絕 / 合併到既有 tag
- 批准：RPC 自動建 tag + apply 到 linked submission + update status
- 拒絕：update status + admin_note
- 合併：選既有 tag 當 merge target + 建議 label 加進 aliases

**不做**（用 Supabase dashboard 直改）：
- 新增 canonical tag（seed 靠 migration，少量新增手改 SQL）
- 編輯 tag label / aliases
- 合併兩個既有 tag / 廢除 tag
- 調整 poster_count

理由：這些操作低頻（一年幾次），Supabase Studio 改 SQL 完全夠。等真的操作頻繁再做 UI。

### 遷移既有資料（170+ approved posters）

自動 script：
1. 對每張 poster 的 `tags text[]`，逐字串 match：
   - 完全相等 label_zh → 建 `poster_tags`
   - 相等 aliases 中任一 → 建 `poster_tags`
2. 無法 match 的字串 → 進 `tag_suggestions` 表，`suggested_by=NULL`, `status=pending`（admin 批量處理）
3. 保留 `posters.tags` 欄位當備份，EPIC 18 全部穩定後 drop

### Task 拆解

| # | 任務 | 狀態 | 預估 |
|---|------|------|------|
| 18-1 | Schema: `tag_categories` + `tags` + `poster_tags` + `tag_suggestions` 四表 + RLS | [ ] | M |
| 18-2 | Enum 擴充：`region_enum` 加 +10 國別 / `release_type_enum` 加 +8 / `size_type_enum` 加 +15 規格 | [ ] | S |
| 18-3 | 新 `work_kind_enum` + `works.work_kind` 欄位 | [ ] | S |
| 18-4 | Poster 新 boolean 欄位：`signed` / `numbered` / `linen_backed` / `licensed` | [ ] | XS |
| 18-5 | Seed migration：10 個 tag_categories + 200+ canonical tags | [ ] | L |
| 18-6 | Migration script：舊 `posters.tags text[]` 匹配到 `poster_tags` + 無法 match 進 suggestions queue | [ ] | M |
| 18-7 | Dart models：`TagCategory`, `Tag`, `TagSuggestion` + repositories | [ ] | M |
| 18-8 | 投稿 flow 重設計：第一步選 work_kind → 對應表單 → 多 facet tag picker | [ ] | L |
| 18-9 | Tag picker UI component：search with aliases、category-grouped、「其他」fallback、「建議新 tag」入口 | [ ] | L |
| 18-10 | Admin `/admin/tag-suggestions` page（approve / reject / merge） | [ ] | M |
| 18-11 | RPC `approve_tag_suggestion(id)` / `reject_tag_suggestion(id, note)` / `merge_tag_suggestion(id, target_tag_id)` | [ ] | M |
| 18-12 | AI-generated checkbox 加到 submission_page + batch_submission_page + TOS 條款 | [ ] | S |
| 18-13 | Home `/` 更新：faceted browse 入口（「按國別」「按設計師」「按年代」），整合 EPIC 14 config | [ ] | M |
| 18-14 | Search page：filter 按 category 分群 | [ ] | M |
| 18-15 | Tests: models, tag fallback flow, migration script correctness | [ ] | M |
| 18-16 | 更新 v2-architecture.md | [ ] | XS |

**執行順序**：
```
18-1 → 18-2 → 18-3 → 18-4 → 18-5 (DB foundation)
                                    ↓
                 18-6 (migration) + 18-7 (Dart layer)
                                    ↓
       18-8 → 18-9 (投稿 UX) // 18-10 → 18-11 (admin UI)
                                    ↓
              18-12 (AI ban) + 18-13 + 18-14 (browse/search)
                                    ↓
                        18-15 → 18-16
```

**總預估**：CC 尺度約 6-8 小時

### TBD 討論項目

- ~~Admin UI 範圍~~ ✅ 已定案：只做 suggestions queue
- 投稿 UX 重設計：work_kind 第一步選擇的具體流程（直接下拉 vs 視覺選單）
- Tag picker 的 UI pattern：全展開 vs 分類收摺 vs 搜索優先
- 初期 seed 數量：200 還是先 100（MVP）？

---

### EPIC 10: Polish & Tech Debt

- [x] ⚠️ 拆分 library_page.dart（1800+ 行 → 4 個 part 檔案）
- [x] 移除 favorite_category_repository + favorite_category model（已刪除）
- [x] ~~topTags 改 SQL RPC~~ → 已在 EPIC 3 完成
- [x] Work page（/work/:id, 同一電影的所有海報）
- [x] blurhash placeholders for images（ShimmerPlaceholder widget; 真正的 blurhash pipeline 需要 upload-time encoding，先以輕量 shimmer 取代）
- [x] rate limiting on uploads（trigger + RPC: 每小時 20 張、每天 60 張）

---

## 開發順序（三階段 + worktree 平行策略）

```
Phase 1: Foundation ✅
├── worktree A: EPIC 1 — works table + enums + migration ✅
├── worktree B: EPIC 2 — Dart models + repositories ✅
└── worktree C: EPIC 3 — 7 個 RPC ✅

Phase 2: Wire Up ✅
├── worktree D: EPIC 4 — submission_page 改寫（寫入 submissions 表）✅
├── worktree E: library_page.dart 拆分（4 個 part 檔案）✅
└── worktree F: poster_detail 接 ViewRepository + toggle_favorite RPC ✅

Phase 3: Polish ✅
├── worktree G: EPIC 5 — admin review upgrade（submissions + work matching）✅
├── worktree H: EPIC 6 — view tracking + client-side Set dedup ✅
└── worktree I: home_sections 1-RPC 接線 + topTags RPC 接線 ✅

驗證：flutter analyze 0 errors, flutter test 56/56 pass

✅ Phase 3 後完成:
  - 資料回填 migration ✅（pushed to Supabase）
  - RPC integration tests ✅（5 tests）
  - 移除 dead code ✅（incrementViewCount, mySubmissionsProvider, listMine, favorite_category files）
  - 投稿確認頁 UI ✅（_ConfirmSheet + _WorkTitleAutocomplete）
  - batch_id 群組顯示 ✅ + duplicate 偵測 ✅
  - View dedup tests ✅（5 tests）
  - Migration validation tests ✅（4 tests）
```

```
延後（EPICs 7-10 核心外）:
6. User discovery                    ← EPIC 7
7. Batch upload                      ← EPIC 8
8. Search upgrade                    ← EPIC 9
9. 剩餘 Polish                       ← EPIC 10
```

---

## Navigation（V2）

```
Bottom tabs:
  探索 (/)           Spotify-style sections feed
  我的 (/library)    個人收藏 L/M/S density

Top bar:
  Avatar → /profile
  Search → /search
  + → /upload

Sub-pages (push):
  /poster/:id        海報詳情（slide up）
  /work/:id          同一電影所有海報
  /user/:id          公開個人檔案
  /upload             單張投稿
  /upload/batch       批量投稿
  /upload/confirm     確認頁
  /me/submissions    我的投稿
  /me/favorites      我的收藏
  /admin             審核佇列
```

---

## Flutter 專案結構（V2）

```
lib/
  core/
    constants/
      enums.dart                  Region, ChannelCat, SizeType, ReleaseType
      region_labels.dart          TW → "台灣" display mapping
    env.dart
    router/app_router.dart
    services/
      image_compressor.dart       既有, 不改
    theme/app_theme.dart
  data/
    models/
      work.dart                   NEW
      poster.dart                 EXTENDED
      submission.dart             NEW
      app_user.dart               EXTENDED (is_public, bio)
      favorite.dart
      favorite_category.dart
    providers/
      supabase_providers.dart
    repositories/
      auth_repository.dart
      work_repository.dart        NEW
      poster_repository.dart      EXTENDED (join works)
      submission_repository.dart  NEW (取代 poster_upload_repository)
      favorite_repository.dart
      user_repository.dart        NEW (public profiles, search)
      view_repository.dart        NEW (dedup view tracking)
  features/
    auth/
      signin_page.dart
    home/
      home_page.dart              Spotify-style explore
    posters/
      library_page.dart           我的, L/M/S density
      poster_detail_page.dart     EXTENDED: structured metadata
      work_page.dart              NEW: 同一電影所有海報
    profile/
      profile_page.dart
      public_profile_page.dart    NEW
      my_favorites_page.dart
    submission/
      submission_page.dart        REDESIGNED: structured fields
      batch_submission_page.dart  NEW
      submission_confirm_page.dart NEW
      my_submissions_page.dart
    admin/
      admin_review_page.dart      EXTENDED
      admin_submission_detail.dart NEW
    search/
      search_page.dart            NEW: unified search
    shell/
      app_shell.dart
```

---

## V1 已完成 vs V2 待做

| 功能 | V1 | V2 |
|------|----|----|
| Auth (Google) | done | keep |
| 探索頁 (Spotify sections) | done | keep, 加 hero banner + 社群動態 |
| 我的 (L/M/S library) | done | keep, join works |
| 海報詳情 | done | extend: structured metadata |
| 收藏 | done | 改用 RPC 維護 count |
| 投稿 (single) | done | redesign: structured fields + confirm |
| Admin 審核 | done | upgrade: work matching + batch |
| Client 壓縮 | done | keep |
| Storage dual upload | done | keep |
| RLS | done (V1 tables) | 加 V2 tables |
| works table | — | NEW |
| submissions table | — | NEW |
| poster_views dedup | — | NEW |
| Structured enums | — | NEW |
| User discovery | — | NEW |
| Batch upload | — | NEW |
| Full-text search | — | NEW |

---

## Tech Stack 決定

**Supabase（維持）。不換 Firebase。**

原因：V2 資料模型（works → posters JOIN, enums, dedup, aggregate counts）天生就是 relational。Firestore 做不了 JOIN, 沒 enum, 要硬搞 denormalization。Supabase 的 RLS + SQL Functions = Cloud Functions 的效果，不需要額外服務。

---

## Security Checklist

| Item | Status |
|------|--------|
| RLS on V1 tables | done |
| RLS on V2 tables (works, submissions, poster_views) | TODO |
| Admin-only RPCs check is_admin() | done |
| Storage upload 限制 own folder | done |
| Soft delete (no hard deletes) | done |
| Audit logs on admin actions | done |
| Rate limiting on uploads | done (trigger: 20/hr, 60/day) |
| DMCA / takedown flow | TODO (need report button) |

---

## Eng Review 決定紀錄（12 issues）

Review date: 2026-04-16

| # | 類別 | 問題 | 決定 |
|---|------|------|------|
| 1 | 架構 | submissions/posters 欄位重複 | 維持分離，approve RPC 用 INSERT...SELECT |
| 2 | 架構 | work_key NOT NULL 不可靠 | 改 nullable UNIQUE，admin 用 title_zh + year 搜尋 |
| 3 | 架構 | approve_submission 無 transaction | 加 BEGIN/COMMIT，失敗 ROLLBACK |
| 4 | 架構 | toggle_favorite race condition | ON CONFLICT + SELECT FOR UPDATE row lock |
| 5 | 架構 | favorites denorm 欄位會脫節 | 刪掉 poster_title / poster_thumbnail_url，改 JOIN |
| 6 | 架構 | migration 009 資料回填順序 | 延後到 Dart-side ready（Phase 3 後） |
| 7 | 品質 | library_page.dart 1800+ 行 | 先拆 4 檔再加 V2 功能（Phase 2 前置） |
| 8 | 品質 | topTags client-side 撈 500 rows | 改 SQL RPC（unnest + group by） |
| 9 | 測試 | 幾乎零測試覆蓋（3%） | 每個 EPIC 同時寫 unit test |
| 10 | 效能 | 首頁 8 個平行 Supabase 查詢 | 合併成 home_sections() RPC，1 round-trip |
| 11 | 效能 | 收藏篩選 IN clause 不 scale | 改 list_favorites_with_posters() RPC + JOIN |
| 12 | 效能 | view count 每次進 detail 都打 RPC | Dart 端加 session-level Set dedup |

---

## Post-EPICs 7-10 Audit（2026-04-17）

驗證：**flutter analyze 0 errors / 0 warnings, flutter test 56/56 pass**

掃到的問題 + 修法：

| # | 類別 | 問題 | 修法 |
|---|------|------|------|
| A1 | 效能 | PublicProfilePage 用 `listApproved` 拉全站後 client 端 filter uploader | 加 `listByUploader(uploaderId)` 直接 DB 索引查詢 |
| A2 | 效能 | posters 缺 `uploader_id` / `work_id` 索引；submissions 缺 `batch_id` 索引；rate-limit trigger 每次 insert 掃 submissions 兩次 | 新 migration `20260417100400_indexes_and_cleanup.sql` 加 partial + composite indexes |
| A3 | 安全 | `listApproved` 的 `.or(title.ilike.%$search%,…)` 把使用者輸入拼進 PostgREST DSL，`,()` 能逃逸 | 預先 strip `,()` + escape `%`，搜尋主要路徑走 `unified_search` RPC |
| A4 | 效能 | `checkDuplicate` / `listMine` / `listPending` 無 limit，大表會回整疊 | 加 `cap: 20` / `limit: 100` 參數 |
| A5 | 架構 | blurhash pipeline 需要 upload-time encoding + storage；範圍偏大 | 先出 `ShimmerPlaceholder` widget，符合 luxury dark aesthetic，保留 hash 欄位作為未來升級 |
| A6 | 產品 | 首頁 6 個 tag-based sections（收藏必備/經典/日本/...）hardcoded 在 SQL RPC | 接受：這是編輯部策展語意，不該動態化。未來可升級為 `home_section_config` 表 |

仍未做：
- Admin 批次審核（批次 approve/reject 一次處理 batch_id 群組）— EPIC 8 衍生
- 公開個人檔案 poster 分頁（目前 cap 60）
- 搜尋結果分頁（目前 cap 8 each group）
- Real blurhash pipeline（需要 image_processor 或 upload-side Edge Function）

---

## /review 跑過的發現（2026-04-17）

跑 `/review` 時掃到的真實 bug + 修法：

| # | 嚴重度 | 類別 | 問題 | 修法 |
|---|--------|------|------|------|
| R1 | **P1** | 資料正確性 | `increment_view_with_dedup` 把 `GET DIAGNOSTICS ROW_COUNT`（bigint）塞進 `boolean` 變數，每次呼叫都 raise。`view_count` 從未遞增，Dart 端 try/catch 吞掉錯誤 | Migration `20260417100500_fix_view_increment_bug.sql`：改用 int + `> 0` 比較 |
| R2 | **P1** | 併發 | `approve_submission` 在 `select status` 與 `update` 之間沒鎖 submission row，兩個 admin 同時點核准會建兩張 poster + 雙倍 poster_count | Migration `20260417100600_fix_approve_submission_race.sql`：`SELECT ... FOR UPDATE` 鎖到 commit |
| R3 | P3 | 觀察性 | ViewRepository 的 `catch (_)` 吞掉所有錯誤，導致 R1 存在數週未被發現 | 改成 `catch (e, st)` + `print` 留 breadcrumb，不崩 detail 頁但不再沉默 |
| R4 | P3 | 注入 | `PosterRepository.listApproved` 的 `.or('title.ilike.%$q%,…')` 把使用者輸入拼進 PostgREST DSL；輸入 `,()` 能改寫查詢 | strip `,()` + escape `%` |
| R5 | P3 | 效能 | `listByUploader` / `checkDuplicate` / `listMine` / `listPending` 無 limit；`posters.uploader_id` 與 `posters.work_id` 缺索引；rate-limit trigger 每 insert 掃 submissions 2 次 | 新 migration `20260417100400_indexes_and_cleanup.sql` + 各 repo 加 `limit:` / `cap:` 參數 |
