-- Close 編輯精選 to user suggestions too.
-- Rationale: editorial curation tags should be defined by admin only.
-- (If users could suggest curation tags we'd get "好片" "超讚" spam.)
begin;

update public.tag_categories
set allows_suggestion = false
where slug = 'curation';

commit;
