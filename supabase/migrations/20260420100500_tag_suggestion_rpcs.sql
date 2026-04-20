-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18: tag suggestion review RPCs
-- ═══════════════════════════════════════════════════════════════════════════
-- approve_tag_suggestion     — create canonical tag + optionally auto-attach
-- reject_tag_suggestion      — mark rejected with optional admin note
-- merge_tag_suggestion       — add suggestion as alias on an existing tag

begin;

-- ─── approve ───────────────────────────────────────────────────────────────
create or replace function public.approve_tag_suggestion(
  p_suggestion_id uuid
)
returns uuid  -- returns new tag id
language plpgsql
security definer
set search_path = public
as $$
declare
  sug record;
  v_tag_id uuid;
  v_slug text;
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

  -- Slug: prefer user-suggested, else derive from label_zh
  v_slug := coalesce(
    nullif(trim(sug.suggested_slug), ''),
    regexp_replace(
      lower(trim(coalesce(sug.suggested_label_en, sug.suggested_label_zh))),
      '[^a-z0-9]+', '-', 'g'
    )
  );
  -- Prefix with category slug to avoid collisions
  v_slug := (
    (select slug from public.tag_categories where id = sug.category_id)
    || '-' || v_slug
  );

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

  -- If the suggestion was triggered by a submission that's already become
  -- a poster, attach the new tag to that poster.
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

-- ─── reject ───────────────────────────────────────────────────────────────
create or replace function public.reject_tag_suggestion(
  p_suggestion_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  update public.tag_suggestions
  set status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      admin_note = p_note
  where id = p_suggestion_id
    and status = 'pending';

  if not found then
    raise exception 'suggestion not found or already reviewed';
  end if;
end $$;

grant execute on function public.reject_tag_suggestion(uuid, text) to authenticated;

-- ─── merge ────────────────────────────────────────────────────────────────
-- "This 'miyazaki' suggestion is a duplicate of existing 宮崎駿 tag."
-- Adds the suggestion's label as an alias on the target tag, and optionally
-- attaches the target tag to the linked submission's poster.
create or replace function public.merge_tag_suggestion(
  p_suggestion_id uuid,
  p_target_tag_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sug record;
  target_tag record;
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

  select * into target_tag from public.tags where id = p_target_tag_id;
  if not found then
    raise exception 'target tag not found';
  end if;

  -- Add the suggestion's label as alias on target (if not already)
  update public.tags
  set aliases = array(
    select distinct unnest(
      coalesce(aliases, '{}') || array[sug.suggested_label_zh] ||
      case
        when sug.suggested_label_en is not null and sug.suggested_label_en != sug.suggested_label_zh
          then array[sug.suggested_label_en]
        else array[]::text[]
      end
    )
  )
  where id = p_target_tag_id;

  -- Attach target tag to the triggering poster
  if sug.linked_submission_id is not null then
    insert into public.poster_tags (poster_id, tag_id, added_by)
    select created_poster_id, p_target_tag_id, sug.suggested_by
    from public.submissions
    where id = sug.linked_submission_id
      and created_poster_id is not null
    on conflict do nothing;
  end if;

  update public.tag_suggestions
  set status = 'merged',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      merged_into_tag_id = p_target_tag_id
  where id = p_suggestion_id;
end $$;

grant execute on function public.merge_tag_suggestion(uuid, uuid) to authenticated;

commit;
