-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: approve_submission race condition on concurrent approve clicks.
-- ═══════════════════════════════════════════════════════════════════════════
-- Two admins clicking "核准" at the same time could both pass the
-- `status = pending` check and each create a poster — producing duplicate
-- posters, double-incrementing poster_count, and leaving orphan audit_log
-- entries.
--
-- Fix: SELECT ... FOR UPDATE to lock the submission row for the duration
-- of the transaction. The second caller blocks until the first commits,
-- then sees status = 'approved' and exits cleanly.

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

  -- Fetch + lock submission until commit. Prevents double-approve race.
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

  -- Resolve or create work.
  if p_work_id is not null then
    v_work_id := p_work_id;
  else
    insert into public.works (title_zh, title_en, movie_release_year)
    values (sub.work_title_zh, sub.work_title_en, sub.movie_release_year)
    returning id into v_work_id;
  end if;

  insert into public.posters (
    work_id, title, poster_name, region, year,
    poster_release_date, poster_release_type, size_type,
    channel_category, channel_type, channel_name,
    is_exclusive, exclusive_name, material_type, version_label,
    poster_url, thumbnail_url, image_size_bytes,
    source_url, source_platform, source_note,
    uploader_id, status, reviewer_id, reviewed_at, approved_at, tags
  ) values (
    v_work_id, sub.work_title_zh, sub.poster_name, sub.region, sub.movie_release_year,
    sub.poster_release_date, sub.poster_release_type, sub.size_type,
    sub.channel_category, sub.channel_type, sub.channel_name,
    sub.is_exclusive, sub.exclusive_name, sub.material_type, sub.version_label,
    sub.image_url, sub.thumbnail_url, sub.image_size_bytes,
    sub.source_url, sub.source_platform, sub.source_note,
    sub.uploader_id, 'approved', auth.uid(), now(), now(), '{}'
  )
  returning id into v_poster_id;

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
      'title', sub.work_title_zh
    )
  );

  return v_poster_id;
end;
$$;

commit;
