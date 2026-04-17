-- ═══════════════════════════════════════════════════════════════════════════
-- Rate limiting for uploads (EPIC 10)
-- ═══════════════════════════════════════════════════════════════════════════
-- Server-side enforcement: an RPC that checks submissions-per-hour for
-- the caller, plus a trigger that refuses inserts if the limit is exceeded.
--
-- Limits chosen conservatively; easy to bump later:
--   - 20 submissions per hour per user
--   - 60 submissions per day per user
-- Admins are exempt.

begin;

create or replace function public.check_upload_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_hour int;
  recent_day int;
begin
  -- Admins are exempt.
  if public.is_admin() then
    return new;
  end if;

  select count(*) into recent_hour
  from public.submissions
  where uploader_id = new.uploader_id
    and created_at > now() - interval '1 hour';

  if recent_hour >= 20 then
    raise exception '投稿速率過快：每小時最多 20 張。請稍後再試。'
      using errcode = 'check_violation';
  end if;

  select count(*) into recent_day
  from public.submissions
  where uploader_id = new.uploader_id
    and created_at > now() - interval '1 day';

  if recent_day >= 60 then
    raise exception '投稿速率過快：每天最多 60 張。請明天再試。'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists submissions_rate_limit on public.submissions;
create trigger submissions_rate_limit
  before insert on public.submissions
  for each row execute function public.check_upload_rate_limit();

-- Companion RPC so the client can preflight-check before uploading.
create or replace function public.get_upload_rate_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  recent_hour int;
  recent_day int;
begin
  uid := auth.uid();
  if uid is null then
    return jsonb_build_object('hour_count', 0, 'day_count', 0, 'can_upload', false);
  end if;

  select count(*) into recent_hour
  from public.submissions
  where uploader_id = uid
    and created_at > now() - interval '1 hour';

  select count(*) into recent_day
  from public.submissions
  where uploader_id = uid
    and created_at > now() - interval '1 day';

  return jsonb_build_object(
    'hour_count', recent_hour,
    'day_count', recent_day,
    'hour_limit', 20,
    'day_limit', 60,
    'can_upload', (recent_hour < 20 and recent_day < 60) or public.is_admin()
  );
end;
$$;

grant execute on function public.get_upload_rate_status() to authenticated;

commit;
