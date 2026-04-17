# POSTER. — Design System v11

> **設計參考：** Spotify Music App (Figma Community)
> **核心美學：** 單頁圖庫。圓潤溫暖。零導航成本。
> **一句話原則：** 打開就是你的收藏，點進去就是沉浸。

---

## 設計原則

1. **一頁即全部。** 打開 app → 你的圖庫就在眼前。沒有 tab bar，沒有底部導航，沒有多餘的頁面跳轉。
2. **攝影即色彩。** 不使用 accent color。純黑底、白字、透明度。海報圖片是唯一的色彩來源。
3. **圓潤溫暖。** Icon 用 Lucide（圓角線條），取代 Phosphor 的銳角風格。UI 元素都帶圓角，手感溫暖。
4. **層次靠透明度。** `text` 100% / `textMute` 55% / `textFaint` 35%。分隔線是白色 8% / 14%。
5. **不要廢話。** 每個畫面只顯示必要資訊。登入頁不寫作文。空狀態一句話 + 一個動作。
6. **動態安靜。** Crossfade 180ms。Hero shared-element 連接列表與詳情。詳情頁從下往上滑出。
7. **單一 CTA。** 每個畫面只有一個主要行動。白色實心 pill（黑字）。

---

## v10 → v11 架構變更

### 砍掉的
- ❌ 底部浮動膠囊 tab bar（`_BrowseTabBar` + `_NakedIconButton`）
- ❌ 獨立收藏頁（`favorites_page.dart` 功能併入 Library filter）
- ❌ `_ClosablePage` X 按鈕 wrapper（改用各頁面自己的返回機制）
- ❌ `_ViewCtaPill`（L 模式「查看」按鈕，點整張海報就能進去）
- ❌ 登入頁的廢話文字（eyebrow、副標題、隱私說明）
- ❌ `phosphor_flutter` 全部換成 `lucide_icons_flutter`

### 新增的
- ✅ Spotify 風格 top bar（avatar + title + search + upload）
- ✅ Filter pills sub-header（tag filter + 收藏 filter + density toggle）
- ✅ Detail 頁 slide-up modal transition + chevron-down 關閉

### 路由變更

```
v10                              v11
──────────                       ──────────
/signin                          /signin（極簡）
/browse (主頁 + tab bar)         / → /library（單頁圖庫）
/upload                          /upload（push，自帶返回箭頭）
/favorites (獨立頁)              ❌ 砍掉（併入 library filter）
/profile                         /profile（push，自帶返回箭頭）
/poster/:id (push →)             /poster/:id（slide-up ↑ modal）
/admin                           /admin（保留）
/me/submissions                  /me/submissions（保留）
```

---

## 色彩 Token（不變，唯一來源：`app_theme.dart`）

| Token | 值 | 用途 |
|---|---|---|
| `bg` | `#050506` | Scaffold 底色 |
| `surface` | `#0A0A0C` | Sheet 底 |
| `surfaceRaised` | `#131316` | 卡片、對話框 |
| `surfaceGlass` | `rgba(20,20,22,0.55)` | Sheet overlay |
| `text` | `#FFFFFF` | 主要文字 |
| `textMute` | `white / 0.55` | 次要文字 |
| `textFaint` | `white / 0.35` | 第三層文字 |
| `line1` | `white / 0.08` | 細線 |
| `line2` | `white / 0.14` | 強分隔線 |
| `chipBg` | `white / 0.08` | 未選中 pill |
| `chipBgStrong` | `white / 0.14` | 選中 pill |

## 圓角系統（不變）

| 用途 | 半徑 |
|---|---|
| 輸入框 | 14px |
| 行卡片 / 海報卡片 | 18px |
| 對話框 | 20px |
| 身份卡 | 24px |
| Bottom sheet | 28px |
| Pill 按鈕 / 膠囊 | 999px |

## 字體系統（不變）

| 層級 | 尺寸 | 字重 | Letter-spacing | 用途 |
|---|---|---|---|---|
| displaySmall | 34px | w500 | -0.8 | L 模式海報標題 |
| headlineLarge | 28px | w500 | -0.6 | 年份大字 |
| headlineMedium | 24px | w500 | -0.4 | 詳情頁標題 |
| titleLarge | 18px | w600 | -0.2 | 卡片標題、Library 標題 |
| titleMedium | 16px | w500 | -0.1 | Profile 行列標題 |
| titleSmall | 14px | w500 | 0 | M 模式卡片標題 |
| bodyMedium | 14px | w400 | 0 | 正文 |
| bodySmall | 12px | w400 | 0 | 次要正文 |
| labelLarge | 13px | w500 | +0.3 | 按鈕文字 |
| labelMedium | 11px | w500 | +1.2 | Eyebrow、section label |
| labelSmall | 10px | w500 | +1.6 | 微型標籤 |

---

## 圖標系統（v11 重大變更）

**從 `phosphor_flutter` 換成 `lucide_icons_flutter`**

```yaml
# pubspec.yaml
lucide_icons_flutter: ^3.1.12
# 移除 phosphor_flutter
```

```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';
// Icon(LucideIcons.heart)
```

### 圖標對照表

| 動作 | v10 Phosphor | v11 Lucide | 備註 |
|---|---|---|---|
| 搜尋 | `magnifyingGlass` | `LucideIcons.search` | |
| 關閉 | `x` | `LucideIcons.x` | |
| 返回 | — | `LucideIcons.arrowLeft` | Profile/Upload 頂部 |
| 收藏（空） | `heart` | `LucideIcons.heart` | |
| 收藏（滿） | `PhosphorIconsFill.heart` | — | Lucide 無 fill，改用顏色或自訂 |
| 上傳 | `uploadSimple` | `LucideIcons.plus` | Spotify 風格用 + |
| 密度 L | `square` | `LucideIcons.square` | |
| 密度 M | `squaresFour` | `LucideIcons.layoutGrid` | |
| 密度 S | `listDashes` | `LucideIcons.list` | |
| 個人資料 | `user` | — | 改用 avatar 圖片 |
| 展開圖片 | `arrowsOut` | `LucideIcons.maximize` | |
| 分享 | `shareNetwork` | `LucideIcons.share2` | |
| 管理 | `shieldCheck` | `LucideIcons.shieldCheck` | |
| 登出 | `signOut` | `LucideIcons.logOut` | |
| 投稿 | `uploadSimple` | `LucideIcons.upload` | Profile 行列 |
| Google | `googleLogo` | — | 保留 Phosphor 或用自訂 SVG |
| chevron-down | — | `LucideIcons.chevronDown` | Detail 頁關閉 |
| chevron-right | `caretRight` | `LucideIcons.chevronRight` | Profile 行列 |
| 編輯 | `pencilSimple` | `LucideIcons.pencil` | |
| 刪除 | `trash` | `LucideIcons.trash2` | |
| 加號 | `plus` | `LucideIcons.plus` | |
| 勾選 | `check` | `LucideIcons.check` | |
| 拖曳 | `dotsSixVertical` | `LucideIcons.gripVertical` | |
| 圖片佔位 | `image` | `LucideIcons.image` | |
| 空收藏 | `heartBreak` | `LucideIcons.heartCrack` | |
| 空列表 | `filmSlate` | `LucideIcons.film` | |

**收藏 fill 狀態處理：** Lucide 是純線條 icon，沒有 fill variant。
改用 `Icon` 的 `color` + `fill` 屬性，或直接用 `Container` 包一個實心圓 + icon 組合。
建議方案：已收藏時 heart icon 改為紅色（`Color(0xFFE53935)`），未收藏時白色。簡單直覺。

**Google Logo 特殊處理：** Lucide 沒有品牌 logo。
保留 `phosphor_flutter` 僅用於 `googleLogo`，或改用 Flutter 內建的 Google logo asset。
建議：用文字「G」配上圓形背景，或直接寫「使用 Google 登入」不帶 icon。

---

## 動態規格

| ID | 位置 | 時長 | 曲線 | 說明 |
|---|---|---|---|---|
| M01 | L 模式滑動 | — | — | 全屏 `PageView`。標題區 `AnimatedSwitcher` crossfade。 |
| M02 | 密度切換 | 220ms | easeStandard | `AnimatedSwitcher` + `KeyedSubtree` crossfade L/M/S。 |
| M03 | 詳情頁開啟 | 350ms | easeOutCubic | **v11 新增：** 從底部滑入（`slideTransition` 或自訂 `PageRouteBuilder`）。 |
| M04 | 詳情頁關閉 | 追蹤手勢 | — | 向下拖曳 threshold 120px，或點 chevron-down。滑出到底部。 |
| M05 | Hero 動畫 | 320ms | Cupertino | Hero tag `poster-${id}`，列表 → 詳情。 |
| M06 | Page dots | 180ms | motionFast | 活躍 dot 16px / 非活躍 4px。 |

---

## 頁面結構

### 路由架構

```
/signin          → SigninPage（極簡登入）
/library         → LibraryPage（主頁，所有功能集中）
/upload          → UploadPage（push，左上返回箭頭）
/profile         → ProfilePage（push，左上返回箭頭）
/poster/:id      → PosterDetailPage（slide-up modal）
/admin           → AdminReviewPage
/me/submissions  → MySubmissionsPage（push，左上返回箭頭）
```

### 認證守衛

`GoRouter.redirect`：未登入 → `/signin`。已登入且在 `/signin` 或 `/` → `/library`。

---

## 登入頁（`signin_page.dart`）

**參考：** Spotify 登入頁。極簡、不廢話、有活力。

```
┌─────────────────────────┐
│                         │
│                         │
│                         │
│         (spacer)        │
│                         │
│      ┌──────────┐       │
│      │  POSTER. │       │  ← titleLarge, w600, ls: 2.0, 置中
│      └──────────┘       │
│                         │
│    探索電影海報的世界     │  ← bodyMedium, textMute, 置中, 一行
│                         │
│         (spacer)        │
│                         │
│  ┌─────────────────┐    │
│  │  使用 Google 登入 │    │  ← 白色 pill, r999, 22h/16v
│  └─────────────────┘    │
│                         │
│   (safe area bottom)    │
└─────────────────────────┘
```

**規格：**
- 背景：純 `AppTheme.bg`（不要背景圖了，簡潔就好）
- 品牌名：「POSTER.」titleLarge, w600, ls: 2.0, 置中
- 副標：一行，bodyMedium, textMute, 置中
- CTA：白色 pill，置中，底部 safe area + 40px
- 沒有 eyebrow、沒有多行標題、沒有隱私說明

**對比 v10：** 從 4 段文字 + 背景圖 → 品牌名 + 一行字 + 按鈕。砍掉 80% 的文字。

---

## 圖庫頁（`library_page.dart`，取代 `browse_page.dart`）

**參考：** Spotify "Your Library" 頁面

### 整體結構

```
┌─────────────────────────┐
│ (safe area top)         │
│                         │
│ ┌──┐ 圖庫        🔍  ＋ │  ← Top bar
│ │頭│                    │
│ └──┘                    │
│                         │
│ 全部  動作  劇情  收藏   │  ← Filter pills (橫向滾動)
│                         │
│ ↕ 最近              ⊞  │  ← Sort label + density toggle
│                         │
│ ┌──────┐  ┌──────┐      │  ← Content (M mode shown)
│ │      │  │      │      │
│ │ img  │  │ img  │      │
│ │      │  │      │      │
│ │ title│  │ title│      │
│ └──────┘  └──────┘      │
│                         │
│ ┌──────┐  ┌──────┐      │
│ │      │  │      │      │
│ │ img  │  │ img  │      │
│ │      │  │      │      │
│ │ title│  │ title│      │
│ └──────┘  └──────┘      │
│                         │
└─────────────────────────┘
```

### Top Bar

```
┌──┐  圖庫                🔍  ＋
│頭│
└──┘
```

- 位置：`top: safeArea + 8, left: 20, right: 20`
- **左側 Avatar：** 32x32 `ClipOval`，顯示用戶頭像（`CachedNetworkImage`）。未登入 = 字母 fallback（chipBgStrong 背景）。點擊 → `context.push('/profile')`。
- **標題：** 「圖庫」titleLarge, w600, white。Avatar 右邊 12px。
- **右側 Icons：** 搜尋（`LucideIcons.search`, 22px, textMute）+ 上傳（`LucideIcons.plus`, 22px, textMute）。間距 16px。Touch target 44x44。
- **整行高度：** 44px

### Filter Pills

```
全部  動作  劇情  收藏  ＋新分類
```

- 位置：top bar 下方 12px
- 橫向 `ListView`，padding: 20px L/R
- **「全部」pill：** 預設選中 = 顯示所有已核准海報
- **Tag pills：** 從 poster data 動態生成（取所有已用 tags）
- **「收藏」pill：** 切換到只顯示已收藏的海報。需登入，未登入點擊 → toast
- **「＋新分類」pill：** 僅在「收藏」模式下顯示。點擊 → 新增收藏分類 dialog
- **選中狀態：** `chipBgStrong` + white text + `line2` border 0.5px
- **未選中狀態：** `chipBg` + textMute text
- **高度：** 32px per pill, r999
- **Padding：** 12h / 6v per pill, 8px gap

### Sort + Density Row

```
↕ 最近                                    ⊞
```

- 位置：filter pills 下方 8px
- **左側：** 「最近」labelMedium, textMute。點擊 → 排序 bottom sheet（預留，v11 先不做）
- **右側：** Density toggle icon。點擊 cycle L → M → S。
  - L: `LucideIcons.square`, 18px
  - M: `LucideIcons.layoutGrid`, 18px
  - S: `LucideIcons.list`, 18px
  - Color: textMute
- **高度：** 32px

### Content Area

根據 density 模式顯示不同佈局（邏輯與 v10 相同）：

#### L 模式（全屏沉浸）

與 v10 相同的全屏 `PageView`，但移除底部 tab bar：

```
┌─────────────────────────┐
│ ┌─────────────────────┐ │  ← 全屏 PageView（從 top bar 下方開始）
│ │                     │ │
│ │    (poster image)   │ │
│ │                     │ │
│ │  ┌─ gradient top ─┐ │ │  ← black 88% → transparent
│ │  │ {TAG}           │ │ │  ← eyebrow: 第一個 tag 大寫
│ │  │ {title}         │ │ │  ← displaySmall, w600
│ │  │ {year}          │ │ │  ← headlineLarge, white 85%
│ │  │ {director}      │ │ │  ← bodyMedium, white 50%
│ │  └────────────────┘ │ │
│ │                     │ │
│ │  ┌─ gradient bot ─┐ │ │  ← transparent → black 80%
│ │  │   · · ━━ · ·   │ │ │  ← page dots / "2/50"
│ │  └────────────────┘ │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

- Top bar 在 L 模式下依然可見（不隱藏）
- 點擊海報 → slide-up detail modal
- 漸層、標題疊加層與 v10 P2 相同

#### M 模式（雙欄 Grid）

與 v10 相同，但 topPadding 改為 filter pills + sort row 的高度。

```
┌──────┐  ┌──────┐
│      │  │      │  ← Hero tag poster-${id}
│ img  │  │ img  │     r18, gradient overlay
│      │  │      │     title + year overlay
│ title│  │ title│
│ year │  │ year │
└──────┘  └──────┘
```

- Padding: 16px L/R
- Gutter: 12px
- AspectRatio: 0.64
- 點擊 → slide-up detail modal

#### S 模式（列表）

與 v10 相同，但改用 Spotify 風格的行列：

```
┌────┐  Title                     ← 56x56 圓角方形 thumb (r8)
│ img│  year · director           ← 左側 56x56，右側文字
└────┘                            ← 行高 72px，padding 20h
──────────────────────────        ← 0.5px line1 separator
┌────┐  Title
│ img│  year · director
└────┘
```

- Thumbnail: 56x56, r8（比 v10 的 52x76 更方正）
- Title: titleSmall, white, w600
- Meta: bodySmall, textMute
- 分隔線: 0.5px, line1
- 點擊 → slide-up detail modal

---

## 海報詳情頁（`poster_detail_page.dart`）

**v11 核心變更：** 從 push → slide-up modal。X 按鈕 → chevron-down。

### Transition

- **開啟：** 從螢幕底部滑入（`SlideTransition` + `CurvedAnimation`，350ms, easeOutCubic）
- **關閉方式 1：** 點擊頂部 chevron-down icon
- **關閉方式 2：** 向下拖曳（threshold 120px 或 velocity > 800）
- **Hero 動畫：** 保留 `Hero` tag `poster-${id}`

### 佈局

```
┌─────────────────────────┐
│                         │
│    ┌───┐         ┌───┐  │  ← glass icon buttons: 44x44
│    │ ⌄ │         │ ❤️ │  │     左: chevron-down (關閉)
│    └───┘         └───┘  │     右: heart (收藏)
│                         │
│                         │
│      (poster image)     │  ← Hero tag, full-bleed, BoxFit.cover
│                         │
│  ┌─ gradient bottom ──┐ │  ← 480px 高，transparent → black
│  │                    │ │
│  │  {TAG}             │ │  ← eyebrow
│  │  {title}           │ │  ← displaySmall, w600
│  │                    │ │
│  │ Year  │ Director │ Views │  ← _MetaColumns (3 欄)
│  │                    │ │
│  │  ┌────┐ ┌────┐     │ │  ← tag chips
│  │                    │ │
│  │  👁 123 次瀏覽      │ │  ← bodySmall, textFaint
│  └────────────────────┘ │
│                         │
│  ── 相關海報 ──          │  ← 水平滾動卡片（可下滑查看）
│  ┌───┐ ┌───┐ ┌───┐     │
│  │   │ │   │ │   │     │
│  └───┘ └───┘ └───┘     │
│                         │
└─────────────────────────┘
```

**Glass icon button 規格（與 v10 相同）：**
- 44x44, r999, blur(20), black 28%, line1 border
- 左上：`LucideIcons.chevronDown`（取代 `x`），Semantics: 「關閉」
- 右上：`LucideIcons.heart`（收藏）。已收藏 = 紅色 `Color(0xFFE53935)`

**心形收藏狀態（v11 變更）：**
- 未收藏：`LucideIcons.heart`, white, 18px
- 已收藏：`LucideIcons.heart`, `Color(0xFFE53935)`, 18px（紅色表示已收藏）
- Glass button 背景不變（不用 fill icon，用顏色區分）

**其餘佈局與 v10 相同：**
- `_MetaColumns`（Year / Director / Views 三欄）
- `_RelatedSection`（水平滾動相關海報）
- `SingleChildScrollView` 可下滑查看相關海報
- 拖曳關閉手勢保留

---

## 個人資料頁（`profile_page.dart`）

**參考：** Spotify Profile 頁面（簡單列表 + 登出在底部）

**進入方式：** 在 Library top bar 點擊 avatar → `context.push('/profile')`

### 佈局

```
┌─────────────────────────┐
│                         │
│  ←                      │  ← 左上返回箭頭 (LucideIcons.arrowLeft)
│                         │     44x44, textMute, 點擊 pop
│  ┌─────────────────────┐│
│  │ ┌──┐               ││  ← 身份卡（與 v10 相同）
│  │ │頭│ Name           ││     surfaceRaised, r24, line1 border
│  │ │像│ email@gmail    ││
│  │ └──┘ [ADMIN]        ││
│  └─────────────────────┘│
│                         │
│  你的內容                │
│                         │
│  ┌─────────────────────┐│
│  │ ↑ 我的投稿      3  >││  ← 保留
│  └─────────────────────┘│
│                         │
│  ┌─────────────────────┐│
│  │ 🛡 Admin 審核      >││  ← admin only
│  └─────────────────────┘│
│                         │
│         (spacer)        │
│                         │
│  ┌─────────────────────┐│
│  │     🚪 登出         ││  ← ghost pill, 最底部
│  └─────────────────────┘│
│                         │
└─────────────────────────┘
```

**v10 → v11 變更：**
- 移除「我的收藏」行列（收藏已併入 Library filter）
- 移除未登入狀態（Profile 只有登入後才能進入，未登入看不到 avatar）
- X 按鈕 → 左上返回箭頭 `LucideIcons.arrowLeft`
- 其餘保持 v10 的 `_IdentityCard` + `_CardRow` + `_GhostPill` pattern

---

## 篩選 Sheet（保留，微調）

與 v10 `_BlurredFilterSheet` 相同，但：
- Icon 換成 Lucide
- 搜尋 icon: `LucideIcons.search`
- 清除 icon: `LucideIcons.x`

---

## 收藏功能（v11 整合方案）

### 在 Library 中收藏

**問題：** v10 的 heart 在 tab bar 裡，只有 L 模式才能用。M/S 模式要切到 L 才能收藏。很蠢。

**v11 解法：**

| 模式 | 收藏方式 |
|------|---------|
| L 模式 | 長按海報 → 彈出收藏 toast + haptic（或雙擊）|
| M 模式 | 長按卡片 → 收藏 action sheet |
| S 模式 | 長按行列 → 收藏 action sheet |
| Detail | 右上角 heart glass button（最主要的收藏入口）|

**收藏 action sheet：**
```
┌────────────────────────────┐
│         ━━━━               │  ← surface, r28
│                            │
│  {poster.title}            │  ← titleMedium, white
│                            │
│  ❤ 加入收藏 / 取消收藏     │  ← 行列項目，44px 高
│  📁 移到分類…              │  ← 行列項目（如果已收藏）
│                            │
└────────────────────────────┘
```

### 在 Library 中檢視收藏

- 點擊「收藏」filter pill → grid/list 只顯示已收藏的海報
- 此時可出現收藏分類的二級 pills（如果有分類的話）
- 「＋新分類」pill 也在此時出現
- 長按某張收藏的海報 → 移到分類 sheet

---

## 按鈕系統（簡化）

### 白色實心 Pill（主 CTA）

```
┌───────────────────────┐
│  Label Text            │  ← Material color: white, r999
└───────────────────────┘     padding: 22h / 16v
                              text: labelLarge, black, w600
                              InkWell + haptic
```

### 描邊 Pill（Ghost / 次要）

```
┌───────────────────────┐
│  [icon]  Label Text    │  ← transparent, r999, line2 border
└───────────────────────┘     text: labelLarge, textMute
```

### Glass Icon Button（Detail 頁）

```
┌─────┐
│  ⌄  │  ← r999, blur(20), black 28%, line1 border
└─────┘     44x44, icon: 18px, white
```

---

## 互動狀態矩陣

| 元件 | idle | press | success | error/disabled |
|------|------|-------|---------|----------------|
| Library card（M） | static | InkWell ripple | slide-up detail | — |
| Library row（S） | static | InkWell ripple | slide-up detail | — |
| Library hero（L） | static | 整頁可點 | slide-up detail | — |
| 長按收藏 | — | haptic medium | toast「已加入最愛」| toast「請先登入」|
| Detail ❤️ | glass, white | InkWell | icon 轉紅 + invalidate | toast |
| Detail ⌄ | glass | InkWell | slide-down dismiss | — |
| Detail drag | — | scale + translate | slide-down dismiss | 彈回 |
| Filter pill | chipBg | — | chipBgStrong + white text | — |
| Avatar | 圓形圖片 | opacity 0.7 | push /profile | — |
| 密度 toggle | icon | haptic | cycle + crossfade | — |

---

## 無障礙規格

| 項目 | 規格 |
|---|---|
| Touch target | 最小 44x44px |
| Semantics | 所有 icon-only 按鈕必須有 `Semantics(label:, button: true)` |
| 對比度 | textMute 55% ≈ 8:1 ✅, textFaint 35% ≈ 5.3:1 ✅ |
| 長按替代 | Detail 頁提供明確的 heart button 作為長按收藏的替代方案 |
| 螢幕閱讀器 | Detail chevron-down 有 Semantics「關閉」|

---

## Do / Don't

**Do**
- 每個互動元素用 `Material + InkWell`
- 所有 icon button 加 `Semantics`
- 用 Lucide icons，不混用其他 icon 庫（Google logo 除外）
- Detail 頁用 slide-up transition
- 收藏用顏色區分（白 = 未收藏，紅 = 已收藏），不用 fill icon
- Top bar 永遠可見，包含 L 模式

**Don't**
- 不要有底部導航 / tab bar
- 不要有獨立的收藏頁面
- 不要用 `AppBar`，頂部 chrome 用 `Positioned`
- 不要在登入頁寫超過一句話
- 不要用 Phosphor icons（Google logo 除外）
- 不要用 accent color
- 不要讓 M/S 模式的收藏功能需要先切換到 L 模式

---

## 檔案對照表

| 檔案 | 職責 | v11 狀態 |
|---|---|---|
| `app_theme.dart` | Token、text theme | 微調（無大變） |
| `app_router.dart` | 路由 + transition | 重寫（新路由 + slide-up） |
| `signin_page.dart` | 登入頁 | 重寫（極簡化） |
| `browse_page.dart` → `library_page.dart` | 圖庫主頁 | 重寫（top bar + pills + 無 tab bar） |
| `poster_detail_page.dart` | 詳情頁 | 修改（chevron-down + slide-up） |
| `profile_page.dart` | 個人資料 | 簡化（移除收藏行、移除未登入態）|
| `favorites_page.dart` | ~~獨立收藏頁~~ | **刪除**（邏輯併入 library） |
| `submission_page.dart` | 上傳 | 微調（返回箭頭） |
| `my_submissions_page.dart` | 投稿列表 | 微調（返回箭頭） |
| `admin_review_page.dart` | 審核 | 不動 |

---

## 實作優先順序

### S0：基礎設施（必須先做）
- [ ] `pubspec.yaml` 加入 `lucide_icons_flutter`，移除 `phosphor_flutter`
- [ ] 全局替換所有 icon reference
- [ ] `app_router.dart` 重寫路由（`/library` 取代 `/browse`，slide-up detail transition）

### S1：Library 頁面（核心）
- [ ] `browse_page.dart` → `library_page.dart` 重命名 + 重寫
- [ ] 新增 Spotify 風格 top bar（avatar + 標題 + search + upload）
- [ ] 新增 filter pills（tag pills + 收藏 pill）
- [ ] 新增 sort + density toggle row
- [ ] 移除 `_BrowseTabBar` 及所有相關程式碼
- [ ] L/M/S content 保留，調整 topPadding

### S2：Detail 頁面（沉浸體驗）
- [ ] X → chevron-down
- [ ] Push → slide-up modal transition
- [ ] 收藏 icon 改顏色區分（紅 / 白）

### S3：登入頁（極簡化）
- [ ] 重寫為品牌名 + 一行字 + 按鈕
- [ ] 移除背景圖、eyebrow、副標題、隱私說明

### S4：Profile + 清理
- [ ] 移除「我的收藏」行列
- [ ] 移除未登入狀態 view
- [ ] X → 返回箭頭
- [ ] 刪除 `favorites_page.dart`
