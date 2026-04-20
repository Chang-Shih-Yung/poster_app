-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: approve_tag_suggestion crashed on Chinese-only labels
-- ═══════════════════════════════════════════════════════════════════════════
-- The old slug generator did:
--   regexp_replace(lower(trim(label_en OR label_zh)), '[^a-z0-9]+', '-', 'g')
-- which turned "諾蘭" into "-" (all non-latin → dashes, collapsed).
-- Result: slug = "curation--", and second time it collided with existing.
--
-- Fix:
--   1. Prefer label_en if it contains latin chars (romanized, readable URL)
--   2. Otherwise use label_zh directly (UTF-8 is fine in slug column)
--   3. Collapse whitespace to dash
--   4. If collision still happens, append short random suffix
-- Also rename from "approve_tag_suggestion" to itself (replace).

begin;

create or replace function public.approve_tag_suggestion(
  p_suggestion_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  sug record;
  v_tag_id uuid;
  v_base text;
  v_slug text;
  v_category_slug text;
  v_retry int := 0;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into sug
  from public.tag_suggestions
  where id = p_suggestion_id
  for update;

  if not found then
    raise exception 'suggestion not found';
  end if;
  if sug.status != 'pending' then
    raise exception 'suggestion already reviewed: %', sug.status;
  end if;

  select slug into v_category_slug
    from public.tag_categories where id = sug.category_id;

  -- Slug base:
  -- If user-supplied a slug, use it.
  -- Else if label_en has actual latin chars, use romanised form.
  -- Else fall back to label_zh (UTF-8 slug is valid in Postgres + URL-encodable).
  if coalesce(nullif(trim(sug.suggested_slug), ''), '') != '' then
    v_base := regexp_replace(
      lower(trim(sug.suggested_slug)),
      '\s+', '-', 'g'
    );
  elsif sug.suggested_label_en is not null
    and trim(sug.suggested_label_en) ~ '[A-Za-z0-9]'
  then
    v_base := regexp_replace(
      lower(trim(sug.suggested_label_en)),
      '[^a-z0-9]+', '-', 'g'
    );
    v_base := trim(both '-' from v_base);
  else
    -- CJK-only fallback: preserve Chinese, collapse whitespace.
    v_base := regexp_replace(trim(sug.suggested_label_zh), '\s+', '-', 'g');
  end if;

  -- Edge case: base still empty (all punctuation) → use short UUID fragment
  if v_base is null or v_base = '' or v_base = '-' then
    v_base := substr(md5(random()::text), 1, 6);
  end if;

  v_slug := v_category_slug || '-' || v_base;

  -- Dedup against existing slugs: append random 4-char suffix on collision,
  -- retry up to 5 times (astronomically improbable to hit collision after).
  while exists(select 1 from public.tags where slug = v_slug) and v_retry < 5 loop
    v_slug := v_category_slug || '-' || v_base || '-'
      || substr(md5(random()::text || v_retry::text), 1, 4);
    v_retry := v_retry + 1;
  end loop;

  if exists(select 1 from public.tags where slug = v_slug) then
    raise exception 'slug generation gave up after 5 retries: %', v_slug;
  end if;

  insert into public.tags
    (slug, category_id, label_zh, label_en, is_canonical, created_by)
  values (
    v_slug,
    sug.category_id,
    sug.suggested_label_zh,
    coalesce(sug.suggested_label_en, sug.suggested_label_zh),
    true,
    sug.suggested_by
  )
  returning id into v_tag_id;

  if sug.linked_submission_id is not null then
    insert into public.poster_tags (poster_id, tag_id, added_by)
    select created_poster_id, v_tag_id, sug.suggested_by
    from public.submissions
    where id = sug.linked_submission_id
      and created_poster_id is not null
    on conflict do nothing;
  end if;

  update public.tag_suggestions
  set status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      merged_into_tag_id = v_tag_id
  where id = p_suggestion_id;

  return v_tag_id;
end $$;

grant execute on function public.approve_tag_suggestion(uuid) to authenticated;

-- Clean up any orphaned garbage slug from earlier failed attempts (curation--).
-- Safe delete: only tags with that specific bad slug pattern and no posters.
delete from public.tags
where slug ~ '--$'
  and poster_count = 0
  and not exists (select 1 from public.poster_tags pt where pt.tag_id = tags.id);

commit;
