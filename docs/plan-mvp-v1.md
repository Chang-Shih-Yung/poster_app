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
- **後端**：Firebase BaaS
  - Auth：Google 登入 + Custom Claims（role）
  - Firestore：海報 / 使用者 / 投稿資料
  - Storage：海報圖片
  - Cloud Functions：審核流程、權限檢查、縮圖產生
  - Hosting：admin 後台（可選）

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

### Firestore 資料模型
- `posters/{posterId}` — 已上架公開可讀
  - title, year, director, tags[], posterUrl, thumbnailUrl, uploaderId, viewCount, createdAt
- `submissions/{submissionId}` — 待審（本人 + admin 可讀）
  - posterData, status (pending/approved/rejected), submitterId, reviewerId, reviewNote
- `users/{userId}` — displayName, role (user/admin/owner), favorites[], submissionCount
- `favorites/{userId}/items/{posterId}` — subcollection

**分流策略**：submissions → Cloud Function 審核通過 → 複製到 posters + 刪除 submission

### 權限模型
- role 放 Firebase Custom Claims（JWT）
- `posters`：所有人可讀，只有 admin / Function 可寫
- `submissions`：只有本人與 admin 可讀，本人可建立，admin 可更新狀態

### 資安措施（已規劃）
- Security Rules 嚴格檢查
- Storage 檔案大小 / 類型限制
- App Check（防腳本刷爆帳單）
- Firebase 預算警報
- Cloud Function 自動產縮圖
- 隱私政策 + 刪除帳號功能
- DMCA 檢舉機制
- 未來接 Cloud Vision SafeSearch 過濾 NSFW

### 搜尋策略
- 初期：Firestore 直接查
- 資料量大後：切 Algolia 或 Typesense（repository 層抽象化）

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
