-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: notify_on_submission_decision references `new.title`, but the
-- submissions table column is `work_title_zh`. Every UPDATE that crossed
-- the status → approved/rejected boundary would trigger the notification
-- function, which would then raise `record "new" has no field "title"`
-- and abort the entire UPDATE.
--
-- Surfaced by bot_write_paths.sql T9:
--   FAIL · trigger raised on UPDATE: record "new" has no field "title"
--
-- The submission approval flow in the front-end (approve_submission RPC
-- → UPDATE submissions SET status = 'approved') would have been silently
-- broken the moment the v19 notifications schema landed. Admin approvals
-- wouldn't have errored visibly to the reviewer because the RPC wraps
-- the UPDATE in its own begin/commit and any exception would roll back
-- without a clean signal — they'd just see "投稿還在 pending". This
-- migration restores the approval path and unblocks the notification
-- trigger's payload.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.notify_on_submission_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ntype public.notification_type;
begin
  if new.status = old.status then return new; end if;
  if new.status = 'approved' then
    ntype := 'submission_approved';
  elsif new.status = 'rejected' then
    ntype := 'submission_rejected';
  else
    return new;
  end if;
  insert into public.notifications
    (user_id, type, target_id, target_kind, payload)
  values (
    new.uploader_id, ntype, new.id, 'submission',
    jsonb_build_object(
      'title', coalesce(new.work_title_zh, '未命名投稿'),
      'note', coalesce(new.review_note, '')
    )
  );
  return new;
end;
$$;

commit;
