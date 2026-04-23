-- ═══════════════════════════════════════════════════════════════════
-- Write-path integration tests. Paste into Supabase Dashboard →
-- SQL Editor to run.
--
-- The single trailing UNION ALL SELECT lands all seven rows (T1-T6
-- verdicts + one SUMMARY row with post-state counts) in the same
-- Results grid — Supabase's dashboard only ever shows the LAST
-- SELECT's rows, so we collapse both into one statement.
-- ═══════════════════════════════════════════════════════════════════

drop function if exists public._write_path_tests();

create or replace function public._write_path_tests()
returns table(test_id text, status text, detail text)
language plpgsql
as $fn$
declare
  -- T1
  t1_target uuid := '00000000-0000-0000-0000-000000000109';
  t1_r1     uuid := '00000000-0000-0000-0000-000000000100';
  t1_r2     uuid := '00000000-0000-0000-0000-000000000101';
  t1_r3     uuid := '00000000-0000-0000-0000-000000000102';
  t1_before public.avatar_status;
  t1_after  public.avatar_status;

  -- T2
  t2_follower uuid := 'a1cb9f23-6423-4735-83ea-d10d29693a88';  -- Henry
  t2_target   uuid := '00000000-0000-0000-0000-000000000100';  -- bot00
  t2_cnt_before        int;
  t2_cnt_after_follow  int;
  t2_cnt_after_unfollow int;
  t2_pre_existing boolean;

  -- T3
  t3_bot00 uuid := '00000000-0000-0000-0000-000000000100';
  t3_blocked boolean := false;

  -- T4
  t4_sample uuid;
  t4_before int;
  t4_after  int;
  t4_blocked boolean := false;

  -- T5
  t5_target   uuid := '00000000-0000-0000-0000-000000000109';
  t5_reporter uuid := '00000000-0000-0000-0000-000000000100';
  t5_first  int;
  t5_second int;

  -- T6
  t6_payload    jsonb;
  t6_count      int;
  t6_first_slug text;
begin
  -- ======= T1 · avatar 3-report safety net =======
  select avatar_status into t1_before from public.users where id = t1_target;

  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values
    (t1_target, t1_r1, 'test T1'),
    (t1_target, t1_r2, 'test T1'),
    (t1_target, t1_r3, 'test T1')
  on conflict do nothing;

  select avatar_status into t1_after from public.users where id = t1_target;

  if t1_before = 'ok' and t1_after = 'pending_review' then
    test_id := 'T1'; status := 'PASS';
    detail := format('avatar 3-report safety net: %s → %s', t1_before, t1_after);
  else
    test_id := 'T1'; status := 'FAIL';
    detail := format('expected ok → pending_review, got %s → %s', t1_before, t1_after);
  end if;
  return next;

  delete from public.avatar_reports where target_user_id = t1_target and reason = 'test T1';
  update public.users set avatar_status = t1_before where id = t1_target;

  -- ======= T2 · follow toggle =======
  select exists (
    select 1 from public.follows
    where follower_id = t2_follower and followee_id = t2_target
  ) into t2_pre_existing;

  select count(*) into t2_cnt_before from public.follows where followee_id = t2_target;

  if not t2_pre_existing then
    insert into public.follows (follower_id, followee_id) values (t2_follower, t2_target);
  end if;
  select count(*) into t2_cnt_after_follow from public.follows where followee_id = t2_target;

  if not t2_pre_existing then
    delete from public.follows where follower_id = t2_follower and followee_id = t2_target;
  end if;
  select count(*) into t2_cnt_after_unfollow from public.follows where followee_id = t2_target;

  test_id := 'T2';
  if t2_pre_existing then
    status := 'SKIP';
    detail := 'Henry already followed bot00 before the test — no-op';
  elsif t2_cnt_after_follow = t2_cnt_before + 1
        and t2_cnt_after_unfollow = t2_cnt_before then
    status := 'PASS';
    detail := format('follow/unfollow cycle: %s → %s → %s',
                     t2_cnt_before, t2_cnt_after_follow, t2_cnt_after_unfollow);
  else
    status := 'FAIL';
    detail := format('cycle leaked: before=%s, after_follow=%s, after_unfollow=%s',
                     t2_cnt_before, t2_cnt_after_follow, t2_cnt_after_unfollow);
  end if;
  return next;

  -- ======= T3 · self-follow CHECK =======
  begin
    insert into public.follows (follower_id, followee_id) values (t3_bot00, t3_bot00);
  exception when check_violation then
    t3_blocked := true;
  end;

  test_id := 'T3';
  if t3_blocked then
    status := 'PASS';
    detail := 'self-follow blocked by no_self_follow CHECK constraint';
  else
    status := 'FAIL';
    detail := 'self-follow got through — constraint missing!';
    delete from public.follows where follower_id = t3_bot00 and followee_id = t3_bot00;
  end if;
  return next;

  -- ======= T4 · favorite PK idempotency =======
  select poster_id into t4_sample
  from public.favorites where user_id = t3_bot00 limit 1;

  test_id := 'T4';
  if t4_sample is null then
    status := 'SKIP';
    detail := 'bot00 has no favorites — nothing to duplicate';
  else
    select count(*) into t4_before from public.favorites where user_id = t3_bot00;

    begin
      insert into public.favorites (user_id, poster_id) values (t3_bot00, t4_sample);
    exception when unique_violation then
      t4_blocked := true;
    end;

    select count(*) into t4_after from public.favorites where user_id = t3_bot00;

    if t4_blocked and t4_after = t4_before then
      status := 'PASS';
      detail := format('duplicate favorite blocked by PK; count stable at %s', t4_before);
    else
      status := 'FAIL';
      detail := format('duplicate leaked: before=%s, after=%s, blocked=%s',
                       t4_before, t4_after, t4_blocked);
    end if;
  end if;
  return next;

  -- ======= T5 · avatar-report uniqueness =======
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (t5_target, t5_reporter, 'test T5 first')
  on conflict do nothing;
  select count(*) into t5_first
  from public.avatar_reports where target_user_id = t5_target and reporter_id = t5_reporter;

  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (t5_target, t5_reporter, 'test T5 second')
  on conflict do nothing;
  select count(*) into t5_second
  from public.avatar_reports where target_user_id = t5_target and reporter_id = t5_reporter;

  test_id := 'T5';
  if t5_first = 1 and t5_second = 1 then
    status := 'PASS';
    detail := 're-report from same user is a no-op (on conflict)';
  else
    status := 'FAIL';
    detail := format('dup leaked: first=%s, second=%s', t5_first, t5_second);
  end if;
  return next;

  delete from public.avatar_reports
  where target_user_id = t5_target and reporter_id = t5_reporter
    and reason like 'test T5%';
  update public.users set avatar_status = 'ok'
  where id = t5_target and avatar_status = 'pending_review';

  -- ======= T6 · home_sections_v2 shape =======
  t6_payload := public.home_sections_v2();
  t6_count := jsonb_array_length(t6_payload);
  t6_first_slug := t6_payload -> 0 ->> 'slug';

  test_id := 'T6';
  if t6_count >= 3 then
    status := 'PASS';
    detail := format('home_sections_v2 returned %s sections, first=%s',
                     t6_count, t6_first_slug);
  else
    status := 'FAIL';
    detail := format('home_sections_v2 only returned %s sections', t6_count);
  end if;
  return next;

  return;
end;
$fn$;


-- All seven rows in one grid:
--   T1-T6 from the function
--   one trailing SUMMARY row with the post-state counts as text,
--   so open_reports / pending_avatars can be eyeballed for leaks.
select test_id, status, detail
from public._write_path_tests()
union all
select
  'SUMMARY' as test_id,
  case when (select count(*) from public.avatar_reports) = 0
        and (select count(*) from public.users where avatar_status = 'pending_review') = 0
       then 'CLEAN' else 'LEAK' end as status,
  format(
    'bots=%s · bot_follows=%s · bot_favorites=%s · open_reports=%s · pending_avatars=%s',
    (select count(*) from public.users where handle like 'bot%'),
    (select count(*) from public.follows
       where follower_id in (select id from public.users where handle like 'bot%')),
    (select count(*) from public.favorites
       where user_id in (select id from public.users where handle like 'bot%')),
    (select count(*) from public.avatar_reports),
    (select count(*) from public.users where avatar_status = 'pending_review')
  ) as detail
order by test_id;

drop function public._write_path_tests();
