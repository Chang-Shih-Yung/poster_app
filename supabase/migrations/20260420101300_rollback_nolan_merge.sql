-- Rollback: 諾蘭 不該是「經典」的別名。從 aliases 拿掉，suggestion 改回 pending。
begin;

update public.tags
set aliases = array_remove(aliases, '諾蘭')
where slug = 'curation-classic';

update public.tag_suggestions
set status = 'pending',
    merged_into_tag_id = null,
    reviewed_by = null,
    reviewed_at = null,
    admin_note = null
where suggested_label_zh = '諾蘭'
  and status = 'merged';

commit;
