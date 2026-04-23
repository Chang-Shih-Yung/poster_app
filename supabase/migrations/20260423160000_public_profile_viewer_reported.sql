-- ═══════════════════════════════════════════════════════════════════════════
-- Extend `user_public_profile` to include a `you_reported` flag so the
-- front-end can disable the 檢舉頭像 action for a target the viewer
-- has already reported. Saves the front-end a round-trip per profile
-- open and stops the "報了卻沒變灰" UX confusion the user flagged.
--
-- Anon callers get you_reported = false (no auth.uid()).
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.user_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u_row public.users%rowtype;
  approved_count int;
  result jsonb;
  visible_avatar text;
  viewer uuid;
  viewer_reported boolean := false;
begin
  select * into u_row from public.users where id = p_user_id;
  if not found or u_row.is_public = false then
    return null;
  end if;

  visible_avatar := case
    when u_row.avatar_status = 'ok' then u_row.avatar_url
    else null
  end;

  select count(*) into approved_count
  from public.posters
  where uploader_id = p_user_id
    and status = 'approved'
    and deleted_at is null;

  viewer := auth.uid();
  if viewer is not null and viewer <> p_user_id then
    select exists (
      select 1 from public.avatar_reports
      where target_user_id = p_user_id and reporter_id = viewer
    ) into viewer_reported;
  end if;

  result := jsonb_build_object(
    'id', u_row.id,
    'display_name', u_row.display_name,
    'handle', u_row.handle,
    'avatar_url', visible_avatar,
    'bio', u_row.bio,
    'submission_count', u_row.submission_count,
    'approved_poster_count', approved_count,
    'is_public', u_row.is_public,
    'viewer_reported', viewer_reported
  );
  return result;
end;
$$;

commit;
