-- ═══════════════════════════════════════════════════════════════════════════
-- Partner schema — Phase 2c: update approve_submission() RPC
--
-- The previous RPC (20260429110000) inserted into the now-dropped collector
-- flag columns (signed, numbered, edition_number, linen_backed, licensed).
-- After Phase 2b dropped those columns, this RPC would error on next call.
--
-- This migration recreates the RPC without those columns. submissions table
-- still has them (we didn't drop submissions side — admin might want to
-- decide later whether to drop there too); we just don't copy them anymore
-- because the destination doesn't have them.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.approve_submission(
  p_submission_id uuid,
  p_work_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  sub record;
  v_work_id uuid;
  v_poster_id uuid;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into sub
    from public.submissions
    where id = p_submission_id
    for update;

  if not found then
    raise exception 'submission not found';
  end if;
  if sub.status != 'pending' then
    raise exception 'submission already reviewed';
  end if;

  if p_work_id is not null then
    v_work_id := p_work_id;
  else
    insert into public.works
      (title_zh, title_en, movie_release_year, work_kind)
    values
      (sub.work_title_zh, sub.work_title_en, sub.movie_release_year,
       coalesce(sub.work_kind, 'movie'))
    returning id into v_work_id;
  end if;

  -- Collector flag columns (signed, numbered, edition_number,
  -- linen_backed, licensed) were dropped from posters in
  -- 20260429150000_partner_schema_phase2b_drops_and_constraints.sql.
  -- No longer copied here.
  insert into public.posters (
    work_id, work_kind, title, poster_name, region, year,
    poster_release_date, poster_release_type, size_type,
    channel_category, channel_type, channel_name,
    is_exclusive, exclusive_name, material_type, version_label,
    poster_url, thumbnail_url, image_size_bytes,
    source_url, source_platform, source_note,
    uploader_id, status, source, reviewer_id, reviewed_at, approved_at, tags
  ) values (
    v_work_id, coalesce(sub.work_kind, 'movie'),
    sub.work_title_zh, sub.poster_name, sub.region, sub.movie_release_year,
    sub.poster_release_date, sub.poster_release_type, sub.size_type,
    sub.channel_category, sub.channel_type, sub.channel_name,
    sub.is_exclusive, sub.exclusive_name, sub.material_type, sub.version_label,
    sub.image_url, sub.thumbnail_url, sub.image_size_bytes,
    sub.source_url, sub.source_platform, sub.source_note,
    sub.uploader_id, 'approved', 'submission', auth.uid(), now(), now(), '{}'
  )
  returning id into v_poster_id;

  if sub.tag_ids is not null and array_length(sub.tag_ids, 1) > 0 then
    insert into public.poster_tags (poster_id, tag_id, added_by)
    select v_poster_id, t_id, sub.uploader_id
    from unnest(sub.tag_ids) as t_id
    on conflict do nothing;

    update public.tags
      set poster_count = poster_count + 1
      where id = any(sub.tag_ids);
  end if;

  update public.works
     set poster_count = poster_count + 1,
         updated_at = now()
   where id = v_work_id;

  update public.submissions
     set status = 'approved',
         reviewer_id = auth.uid(),
         reviewed_at = now(),
         matched_work_id = v_work_id,
         created_poster_id = v_poster_id
   where id = p_submission_id;

  insert into public.audit_logs (actor_id, action, target_table, target_id, after)
  values (
    auth.uid(), 'approve_submission', 'submissions', p_submission_id,
    jsonb_build_object(
      'work_id', v_work_id,
      'poster_id', v_poster_id,
      'title', sub.work_title_zh,
      'tag_count', coalesce(array_length(sub.tag_ids, 1), 0)
    )
  );

  return v_poster_id;
end $$;

commit;
