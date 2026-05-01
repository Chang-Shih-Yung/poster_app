-- ═══════════════════════════════════════════════════════════════════════════
-- posters: 加上 is_public 欄位
--
-- 合夥人 spec #26「是否公開」對應 admin 上架但不公開的場景。我之前 wave 2
-- 加了 PosterForm toggle 跟 stats card 顯示，但誤以為 posters.is_public 已
-- 經存在（誤把 users.is_public 看成 posters）。實際上 v2 schema 加的是
-- users.is_public（profile 隱私），posters 從來沒這欄。
--
-- 結果：使用者按「新增」會噴 PGRST204 — schema cache 找不到欄位。
--
-- 修法：補欄位、預設 true（與 form 預設一致）、不破壞舊 row。
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.posters
  add column if not exists is_public boolean not null default true;

-- 不另加 index — Flutter 公開 feed 會吃 status='approved' 已經有 index，
-- is_public 篩選只是在那基礎上再加一個 boolean，全表掃 OK。

commit;
