-- ═══════════════════════════════════════════════════════════════════════════
-- 修正面向 admin 的字句：去掉工程術語，改成白話
-- ═══════════════════════════════════════════════════════════════════════════
-- 原因：20260420100400 的自動遷移把 "從既有 posters.tags 自動遷移（EPIC 18-6）,
-- 無法匹配到 canonical tag" 塞到 tag_suggestions.reason。非技術夥伴看不懂。
-- 以後規則：寫進 DB 會出現在 UI 的字串，一律用白話中文。

begin;

update public.tag_suggestions
set reason = '這個分類是舊版本遺留下來的，系統沒辦法自動配對到新分類，請判斷要新建一個、合併到已有、或是退回。'
where reason like '%EPIC 18-6%'
   or reason like '%posters.tags%'
   or reason like '%canonical tag%';

commit;
