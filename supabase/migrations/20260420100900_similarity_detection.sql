-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18 Phase 2: Similarity detection & auto-merge
-- ═══════════════════════════════════════════════════════════════════════════
-- Admin shouldn't need to memorize 165+ existing tags to decide
-- 建立 / 合併 / 退回. System surfaces likely duplicates automatically.
--
-- Three RPCs:
--   find_similar_tags(category, label)
--     → top N existing tags + similarity score.
--     Used by admin UI (inline duplicate hint) and suggestion form (live
--     autocomplete as user types).
--
--   submit_tag_suggestion(category, label_zh, label_en, reason, linked_submission)
--     → gateway that auto-merges at >= 0.95 similarity, otherwise creates
--     a normal pending suggestion. Admin queue never sees obvious duplicates.
--
--   suggest_or_use_existing_tag(category, label_zh, label_en, reason, linked_submission)
--     → returns existing close match IF >= 0.75 so the client can offer
--     "did you mean X?" BEFORE the user confirms submission.

begin;

-- pg_trgm already enabled (EPIC 9). Just need a helper function.

-- ─── 1. find_similar_tags ──────────────────────────────────────────────────
-- Tests a label against all tags in the given category. Similarity score is
-- the max of trigram-similarity(label_zh), trigram-similarity(label_en),
-- and the highest alias match (case-insensitive).

create or replace function public.find_similar_tags(
  p_category_id uuid,
  p_label text,
  p_limit int default 5
)
returns table (
  tag_id uuid,
  slug text,
  label_zh text,
  label_en text,
  aliases text[],
  poster_count int,
  similarity float
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
      greatest(
        similarity(lower(t.label_zh), (select q from probe)),
        similarity(lower(t.label_en), (select q from probe)),
        coalesce((
          select max(similarity(lower(a), (select q from probe)))
          from unnest(t.aliases) as a
        ), 0)
      ) as sim
    from public.tags t
    where t.category_id = p_category_id
      and t.deprecated = false
      and t.is_other_fallback = false
  )
  select tag_id, slug, label_zh, label_en, aliases, poster_count, sim as similarity
  from scored
  where sim >= 0.3
  order by sim desc, poster_count desc
  limit p_limit;
$$;

grant execute on function public.find_similar_tags(uuid, text, int) to authenticated;

-- ─── 2. submit_tag_suggestion (gateway with auto-merge) ────────────────────
-- Client calls this instead of inserting directly into tag_suggestions.
-- Returns jsonb:
--   { auto_merged: true,  tag_id: uuid, tag_label_zh: text } — merged silently
--   { auto_merged: false, suggestion_id: uuid }            — entered queue

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

  -- Find the best existing match.
  select tag_id, slug, label_zh, similarity
    into top_tag
  from public.find_similar_tags(p_category_id, v_label_zh, 1);

  -- Auto-merge threshold: 0.95. Very confident duplicates don't go to queue.
  if top_tag.tag_id is not null and top_tag.similarity >= 0.95 then
    -- Add the user's exact input as alias (dedup before insert).
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

    -- If there's a linked submission whose poster has been created, attach tag.
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

  -- Otherwise, create a pending suggestion.
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
