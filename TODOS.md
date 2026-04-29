# TODOS

長尾任務清單。完成後刪掉條目，不留歷史 — Git log 才是歷史。

---

## P3 — 健全性

### CINEMA_NAMES 枚舉接到表單
**What:** `lib/enums.ts` 已定義 CINEMA_NAMES，但 PosterForm/BatchImport 通路名稱還是 free text Input。
**Why:** 結構化才能做後續分析（哪家影城最多獨家版）。
**Context:** `channel_name` 欄位。當 `channel_category === "cinema"` 時切換成 Select。

---

## P3 — Schema / 資料

### 把 `mini` 從 size_type_enum 真的拿掉
**What:** Postgres enum 不能 DROP VALUE，要 recreate 整個 type。
**Why:** Migration `20260429100000` 把 `mini` 的 row 全改成 `other`，但 enum 還包含 `mini`，使用者可以用 SQL 直接寫回去（不會被 admin form 接受，但理論上有可能）。
**Context:**
```sql
-- 1. 建新 enum without mini
-- 2. ALTER TABLE 改用新 enum (含 USING cast)
-- 3. DROP TYPE 舊的
-- 4. RENAME 新的
```
**Recommendation:** 沒人撞到再做。

---
