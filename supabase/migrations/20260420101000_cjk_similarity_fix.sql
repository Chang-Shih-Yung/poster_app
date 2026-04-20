-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18 Phase 2 fix: CJK-friendly similarity + optional cross-category search
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: pg_trgm.similarity() is designed for English word matching.
--   - "院線" vs "院線首刷" scores ~0.2 (short Chinese strings = few trigrams)
--   - "懸疑" vs "驚悚" scores ~0.0 (0 char overlap even though semantically close)
-- The old threshold (>= 0.3) filtered out almost all Chinese matches.
--
-- Fix: GREATEST(pg_trgm, substring-containment-score). If one side is a
-- substring of the other, score = 0.85. Works naturally for Chinese short
-- strings. Leaves English matching path unchanged.
--
-- Bonus: admin often wants to see matches across categories (legacy data
-- was mis-categorized). Add optional p_cross_category flag.

begin;

drop function if exists public.find_similar_tags(uuid, text, int);

create or replace function public.find_similar_tags(
  p_category_id uuid,
  p_label text,
  p_limit int default 5,
  p_cross_category boolean default false
)
returns table (
  tag_id uuid,
  slug text,
  label_zh text,
  label_en text,
  aliases text[],
  poster_count int,
  similarity float,
  category_slug text,
  category_title_zh text
)
language sql
security definer
set search_path = public
as $$
  with probe as (
    select lower(trim(p_label)) as q
  ),
  scored as (
    select
      t.id as tag_id,
      t.slug,
      t.label_zh,
      t.label_en,
      t.aliases,
      t.poster_count,
      c.slug as category_slug,
      c.title_zh as category_title_zh,
      greatest(
        -- classic trigram similarity (good for English)
        public.similarity(lower(t.label_zh), (select q from probe)),
        public.similarity(lower(t.label_en), (select q from probe)),
        coalesce((
          select max(public.similarity(lower(a), (select q from probe)))
          from unnest(t.aliases) as a
        ), 0),
        -- CJK-friendly substring containment score
        case
          when (select q from probe) = '' then 0
          when lower(t.label_zh) like '%' || (select q from probe) || '%' then 0.85
          when (select q from probe) like '%' || lower(t.label_zh) || '%' then 0.85
          when lower(t.label_en) like '%' || (select q from probe) || '%' then 0.80
          when (select q from probe) like '%' || lower(t.label_en) || '%' then 0.80
          when exists (
            select 1 from unnest(t.aliases) as a
            where lower(a) like '%' || (select q from probe) || '%'
               or (select q from probe) like '%' || lower(a) || '%'
          ) then 0.80
          else 0
        end
      ) as sim
    from public.tags t
    join public.tag_categories c on c.id = t.category_id
    where t.deprecated = false
      and t.is_other_fallback = false
      and (p_cross_category or t.category_id = p_category_id)
  )
  select
    tag_id, slug, label_zh, label_en, aliases, poster_count,
    sim as similarity, category_slug, category_title_zh
  from scored
  where sim >= 0.25
  order by sim desc, poster_count desc
  limit p_limit;
$$;

grant execute on function public.find_similar_tags(uuid, text, int, boolean) to authenticated;

-- Update submit_tag_suggestion to use the new signature. Still uses
-- same-category scope (we don't want user suggestions to auto-merge
-- into a different category).
create or replace function public.submit_tag_suggestion(
  p_category_id uuid,
  p_label_zh text,
  p_label_en text default null,
  p_reason text default null,
  p_linked_submission_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  top_tag record;
  new_suggestion_id uuid;
  v_poster_id uuid;
  v_label_zh text;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'auth required to suggest a tag';
  end if;

  v_label_zh := trim(p_label_zh);
  if v_label_zh = '' then
    raise exception 'label_zh required';
  end if;

  -- Same-category scope for auto-merge: don't cross categories.
  select tag_id, slug, label_zh, similarity
    into top_tag
  from public.find_similar_tags(p_category_id, v_label_zh, 1, false);

  if top_tag.tag_id is not null and top_tag.similarity >= 0.95 then
    update public.tags
    set aliases = array(
      select distinct unnest(
        coalesce(aliases, '{}') || array[v_label_zh] ||
        case
          when p_label_en is not null and trim(p_label_en) != ''
            and trim(p_label_en) != v_label_zh
          then array[trim(p_label_en)]
          else array[]::text[]
        end
      )
    )
    where id = top_tag.tag_id;

    if p_linked_submission_id is not null then
      select created_poster_id into v_poster_id
      from public.submissions
      where id = p_linked_submission_id;
      if v_poster_id is not null then
        insert into public.poster_tags (poster_id, tag_id, added_by)
        values (v_poster_id, top_tag.tag_id, uid)
        on conflict do nothing;
      end if;
    end if;

    return jsonb_build_object(
      'auto_merged', true,
      'tag_id', top_tag.tag_id,
      'tag_label_zh', top_tag.label_zh,
      'similarity', top_tag.similarity
    );
  end if;

  insert into public.tag_suggestions
    (suggested_by, suggested_label_zh, suggested_label_en,
     category_id, reason, linked_submission_id, status)
  values
    (uid, v_label_zh,
     case when p_label_en is null or trim(p_label_en) = ''
          then null else trim(p_label_en) end,
     p_category_id, p_reason, p_linked_submission_id, 'pending')
  returning id into new_suggestion_id;

  return jsonb_build_object(
    'auto_merged', false,
    'suggestion_id', new_suggestion_id
  );
end $$;

grant execute on function public.submit_tag_suggestion(uuid, text, text, text, uuid) to authenticated;

commit;
