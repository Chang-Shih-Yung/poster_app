# 海報目錄 — Google Sheet 編輯者範本

這份 CSV 是**給非技術人員用的 Google Sheets 範本**，對應 v3 Phase 1
的資料灌檔流程（見 `docs/plan-v3-collection-pivot.md`）。

## 使用流程

1. 把 `poster_catalogue_template.csv` 上傳到 Google Sheets（選「檔案 →
   匯入 → 上傳」）。
2. 範本裡有 4 筆範例列，用千與千尋示範完整欄位寫法。**開始正式編輯前
   請把範例列刪掉。**
3. 設定欄位權限（可選但建議）：
   - `work_kind`, `region`, `release_type`, `size`, `channel_category`
     這幾欄加資料驗證下拉選單（下方欄位表列了每個的合法值）。
   - `is_exclusive` 設成 Checkbox。
4. 編輯者一列一張海報填寫。累積到一批（~50-200 列）後通知工程側，
   後台按「從 Sheet 同步」一次匯入。

## 欄位說明

| 欄位 | 必填 | 說明 | 合法值 |
|---|---|---|---|
| `work_title_zh` | ✅ | 作品中文名 | 自由填 |
| `work_title_en` | | 作品英文名 | 自由填 |
| `work_kind` | ✅ | 作品類別 | `movie` · `concert` · `theatre` · `exhibition` · `event` · `original_art` · `advertisement` · `other` |
| `path` | ✅ | 樹狀分類路徑，用 ` > ` 分隔 | 例：`2014 重映 > IMAX` |
| `poster_name` | ✅ | 葉節點海報名稱 | 自由填 |
| `region` | ✅ | 海報發行地 | `tw` · `jp` · `us` · `hk` · `kr` · `cn` · `other` |
| `release_year` | | 發行年份 | 1900-2100 整數 |
| `release_type` | | 發行類型 | `theatrical` · `teaser` · `character` · `final` · `advance` · `re_release` |
| `size` | | 規格尺寸 | `b1` · `b2` · `b3` · `a4` · `custom` |
| `channel_category` | | 通路大類 | `cinema` · `streaming` · `physical` · `online` · `event` |
| `channel_name` | | 通路名稱 | 自由填，例：威秀、秀泰、Toho |
| `is_exclusive` | | 是否獨家 | TRUE / FALSE |
| `exclusive_of` | | 獨家通路名 | 自由填（只在 is_exclusive = TRUE 時有意義） |
| `material` | | 材質 | 自由填，例：霧面紙、金屬、金箔紙 |
| `version_label` | | 版本標記 | 自由填，例：v2、修正版 |
| `source_url` | | 參考來源連結 | URL |
| `notes` | | 備註 | 自由填 |

## `path` 的樹狀邏輯（重點）

範本的核心是 `path` 欄，它決定了這張海報在樹的哪裡。

以千與千尋為例：

```
千與千尋 (work)
├── 2001 日本首映 (group)
│   ├── 正式版 (group)
│   │   └── B1 原版 ← path: "2001 日本首映 > 正式版", poster_name: "B1 原版"
│   └── 前売券 (group)
│       └── 前売券附贈版 ← path: "2001 日本首映 > 前売券", poster_name: "前売券附贈版"
├── 2014 重映 (group)
│   └── IMAX (group)
│       └── IMAX 威秀獨家 ← path: "2014 重映 > IMAX", poster_name: "IMAX 威秀獨家"
└── 2024 25週年 (group)
    └── 台灣版 (group)
        └── 25 週年 Final ← path: "2024 25週年 > 台灣版", poster_name: "25 週年 Final"
```

每次同步，我們的匯入邏輯會自動：

- 依照 `work_title_zh` + `release_year` 找到（或建立）對應的 work
- 沿著 `path` 一層層建立 / 找到 `poster_groups`
- 把這列當作 **葉節點的 `poster`** 掛在最後一層 group 底下

## 圖片怎麼辦？

**Sheet 不填圖片**。同步進後台後，每張海報會出現在後台的「待補圖」清
單，官方編輯者登入後台拖拉上傳圖片。詳見 v3 doc §3.6。

`source_url` 可以先填「哪裡有參考圖」方便後續補圖。

## 常見錯誤

- ❌ `path` 用中文的「＞」而不是英文的 `>` — 匯入會當成字串一部分，無法切分
- ❌ `work_kind` / `region` 打錯 enum（例如 `Taiwan` 而不是 `tw`）— 匯入會擋下並顯示錯誤
- ❌ 同一 work 的 `work_title_zh` 寫法不一致（千與千尋 vs 千與千尋 ` `）—
  會建立兩個 work。匯入前會做 NFKC 正規化但仍建議手動統一。
