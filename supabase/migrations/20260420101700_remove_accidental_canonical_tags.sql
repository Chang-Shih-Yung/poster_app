-- ═══════════════════════════════════════════════════════════════════════════
-- Remove accidentally-approved canonical tags: 戰爭 / 懸疑 under 編輯精選
-- ═══════════════════════════════════════════════════════════════════════════
-- User clicked "建立新分類" earlier during UX testing and produced these
-- tags in the wrong category. They're not referenced by any poster yet,
-- so safe to delete.

begin;

do $$
declare
  r record;
  deleted_count int := 0;
begin
  for r in
    select t.id, t.slug, t.label_zh, t.poster_count, c.title_zh as cat
    from public.tags t
    join public.tag_categories c on c.id = t.category_id
    where t.label_zh in ('戰爭', '懸疑')
      and c.slug = 'curation'
  loop
    raise notice 'REMOVING canonical tag: slug=% label=% cat=% posters=%',
      r.slug, r.label_zh, r.cat, r.poster_count;

    -- 刪 poster_tags 的掛載（如果有的話；應該沒有）
    delete from public.poster_tags where tag_id = r.id;
    -- 刪 tag_synonyms 裡指向這個 tag 的 mapping（如果有的話）
    delete from public.tag_synonyms where target_tag_id = r.id;
    -- 刪 tag_suggestions 裡 merged_into 指向這個 tag 的（reset 成 pending）
    update public.tag_suggestions
      set status = 'pending',
          merged_into_tag_id = null,
          reviewed_by = null,
          reviewed_at = null
      where merged_into_tag_id = r.id;
    -- 最後刪 tag 本身
    delete from public.tags where id = r.id;
    deleted_count := deleted_count + 1;
  end loop;

  raise notice 'Removed % accidental canonical tag(s)', deleted_count;
end $$;

commit;
