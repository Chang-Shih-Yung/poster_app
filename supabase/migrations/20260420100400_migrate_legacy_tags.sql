-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18: migrate legacy posters.tags text[] → poster_tags
-- ═══════════════════════════════════════════════════════════════════════════
-- For each approved poster, try to match each string in `tags[]` to a
-- canonical tag by:
--   1. label_zh match (case-insensitive)
--   2. label_en match (case-insensitive)
--   3. alias match (case-insensitive)
--
-- Unmatched strings go into tag_suggestions with suggested_by=NULL and a
-- 'pending' status so admin can batch-review.
--
-- `posters.tags text[]` is kept in place as backup — will drop in a later
-- migration once Dart side is fully migrated.

begin;

-- Migration runner function
create or replace function _migrate_legacy_tag(
  p_poster_id uuid,
  p_tag_label text
) returns boolean language plpgsql as $$
declare
  v_tag_id uuid;
  v_canon text;
begin
  if p_tag_label is null or trim(p_tag_label) = '' then
    return false;
  end if;

  v_canon := lower(trim(p_tag_label));

  -- Match by label_zh / label_en / alias (case-insensitive)
  select id into v_tag_id from public.tags
    where lower(label_zh) = v_canon
       or lower(label_en) = v_canon
       or v_canon = any(
         select lower(a) from unnest(aliases) a
       )
    limit 1;

  if v_tag_id is not null then
    insert into public.poster_tags (poster_id, tag_id, added_by, added_at)
    values (p_poster_id, v_tag_id, null, now())
    on conflict do nothing;
    return true;
  end if;

  -- Unmatched → push to tag_suggestions (only if not duplicated)
  insert into public.tag_suggestions
    (suggested_by, suggested_label_zh, suggested_label_en,
     category_id, reason, status)
  select
    null,
    p_tag_label,
    p_tag_label,
    (select id from public.tag_categories where slug = 'curation'),
    '這個分類是舊版本遺留下來的，系統沒辦法自動配對到新分類，請判斷要新建一個、合併到已有、或是退回。',
    'pending'
  where not exists (
    select 1 from public.tag_suggestions
    where suggested_label_zh = p_tag_label
      and status = 'pending'
  );
  return false;
end $$;

-- Run the migration
do $$
declare
  r record;
  t text;
  matched int := 0;
  unmatched int := 0;
  ok boolean;
begin
  for r in
    select id, tags from public.posters
    where status = 'approved'
      and deleted_at is null
      and tags is not null
      and array_length(tags, 1) > 0
  loop
    foreach t in array r.tags
    loop
      ok := _migrate_legacy_tag(r.id, t);
      if ok then
        matched := matched + 1;
      else
        unmatched := unmatched + 1;
      end if;
    end loop;
  end loop;

  raise notice 'Legacy tag migration complete: % matched, % unmatched (sent to tag_suggestions)',
    matched, unmatched;
end $$;

-- Update poster_count denorm on tags
update public.tags t
  set poster_count = coalesce((
    select count(*) from public.poster_tags pt
    where pt.tag_id = t.id
  ), 0);

drop function _migrate_legacy_tag(uuid, text);

commit;
