# TODOS

長尾任務清單。完成後刪掉條目，不留歷史 — Git log 才是歷史。

---

## P1 — Flutter Dart enum 同步合夥人 spec schema

**What:** Admin 已對齊合夥人 2026-04-29 spec（4 個 migration 已 push 到 prod），Flutter app 端的 Dart enum class 還沒同步。Flutter 抓到新值會 fallback 顯示原始字串而非翻譯標籤。

**Why:** DB 已 commit 新 enum 值，admin 開始建的海報會用新值。Flutter app 只要不更新 Dart enum class，就會顯示「first_run」原始字串而非「首映」翻譯。**不會 crash，但 UI 醜。**

**File scope (Flutter side `lib/`):**
- `data/models/poster.dart`（type 定義 + fromString）
- `features/submission/submission_page.dart`（line 1308-1320 附近 fromString 用法）
- `data/repositories/poster_repository.dart`（filter 條件可能要調整）

**清單（Dart enum class 要新增 / 改名 / 砍掉的值）:**

### release_type 新值（11 個，全換）
- `firstRun` (= "first_run")
- `reRelease`
- `specialScreening`
- `anniversary`（已存在）
- `filmFestival`
- `theaterCampaign`
- `distributorCampaign`
- `retailRelease`
- `exhibitionRelease`
- `lotteryPrize`
- `other`（已存在）

**砍掉**：theatrical, reissue, festival, teaser, special, limited, international, character, style_a, style_b, imax, dolby, variant, timed_release, artist_proof, printer_proof, unused_concept, bootleg, fan_art

### channel_category 砍 + 加
- 加 `ichibanKuji` (= "ichiban_kuji")
- 砍 `distributor`, `retail`, `lottery`

### size_type 大砍只剩 11 個
保留：A1-A5, B1-B5, custom（小寫）
全砍：jp_*, tw_*, us_*, uk_*, fr_*, it_*, pl_*, au_*, mondo_*, lobby_card, press_kit, other, hk_mini

### 新 enum class（DB 端已建好，Flutter 要 mirror）
- `PremiumFormat` — IMAX, DOLBY, DVA, "4DX"（注意數字開頭，Dart 不能直接當識別字，要用 mapping）, ULTRA_4D, SCREENX, D_BOX, LUXE, REALD_3D
- `SizeUnit` — cm, inch
- `CinemaName` — vieshow, showtime, miramar, ambassador, centuryasia, eslite_art_house, star, hala, u_cinema, mld, other

### 新欄位（Flutter 要更新 model + repository）
- `cinema_release_types` — String[]
- `premium_format` — PremiumFormat?
- `cinema_name` — CinemaName?
- `custom_width`, `custom_height` — num?
- `size_unit` — SizeUnit?
- `channel_note` — String?

### 砍掉的欄位（Flutter model 移除）
- `signed`, `numbered`, `edition_number`, `linen_backed`, `licensed` — DB 已 DROP COLUMN

**Effort:** M (~半小時 Flutter Dart enum 改動 + 半小時 model + repository 同步)
**Priority:** P1（admin 任何新海報的 enum 值都是新值，Flutter 顯示會醜）
**Depends on:** 無
**Reference:** GBrain page `poster-app-schema-v2-partner-spec` 有完整 mapping 表
