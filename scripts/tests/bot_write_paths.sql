-- ═══════════════════════════════════════════════════════════════════
-- Write-path integration tests. Paste into Supabase Dashboard →
-- SQL Editor to run (needs service-role-equivalent privs to bypass
-- RLS + fire triggers).
--
-- Each test is self-contained, rolls back its own side-effects, and
-- prints a PASS / FAIL row. Read-path coverage lives in
-- `scripts/tests/bot_flows_test.py` (runs with anon + no Dashboard).
--
-- Safe to re-run. Safe to interrupt — every test is wrapped in its
-- own transaction with a rollback at the end.
-- ═══════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────
-- T1 · avatar 3-report safety net
-- Target: bot09. Reporters: bot00, bot01, bot02.
-- Expects: avatar_status flips from 'ok' → 'pending_review'.
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  target uuid := '00000000-0000-0000-0000-000000000109';
  r1 uuid := '00000000-0000-0000-0000-000000000100';
  r2 uuid := '00000000-0000-0000-0000-000000000101';
  r3 uuid := '00000000-0000-0000-0000-000000000102';
  status_before public.avatar_status;
  status_after public.avatar_status;
begin
  select avatar_status into status_before from public.users where id = target;

  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values
    (target, r1, 'test T1'),
    (target, r2, 'test T1'),
    (target, r3, 'test T1')
  on conflict do nothing;

  select avatar_status into status_after from public.users where id = target;

  if status_before = 'ok' and status_after = 'pending_review' then
    raise notice 'T1 PASS · avatar 3-report: ok → pending_review';
  else
    raise warning 'T1 FAIL · expected ok → pending_review, got % → %',
      status_before, status_after;
  end if;

  -- Rollback side effects
  delete from public.avatar_reports where target_user_id = target and reason = 'test T1';
  update public.users set avatar_status = status_before where id = target;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- T2 · follow toggle (insert + delete cycle)
-- Henry follows bot00, then unfollows. Verify counts before/after.
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  follower uuid := 'a1cb9f23-6423-4735-83ea-d10d29693a88';  -- Henry
  target   uuid := '00000000-0000-0000-0000-000000000100';  -- bot00
  cnt_before int;
  cnt_after_follow int;
  cnt_after_unfollow int;
  pre_existing boolean;
begin
  select exists (
    select 1 from public.follows
    where follower_id = follower and followee_id = target
  ) into pre_existing;

  select count(*) into cnt_before from public.follows where followee_id = target;

  if not pre_existing then
    insert into public.follows (follower_id, followee_id)
    values (follower, target);
  end if;

  select count(*) into cnt_after_follow from public.follows where followee_id = target;

  if not pre_existing then
    delete from public.follows
    where follower_id = follower and followee_id = target;
  end if;

  select count(*) into cnt_after_unfollow from public.follows where followee_id = target;

  if pre_existing then
    raise notice 'T2 SKIP · Henry already follows bot00 (no-op)';
  elsif cnt_after_follow = cnt_before + 1 and cnt_after_unfollow = cnt_before then
    raise notice 'T2 PASS · follow/unfollow cycle: % → % → %',
      cnt_before, cnt_after_follow, cnt_after_unfollow;
  else
    raise warning 'T2 FAIL · follow toggle leaked: before=%, after_follow=%, after_unfollow=%',
      cnt_before, cnt_after_follow, cnt_after_unfollow;
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- T3 · self-follow DB constraint
-- Assert the `no_self_follow` CHECK constraint actually fires.
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  bot00 uuid := '00000000-0000-0000-0000-000000000100';
  blocked boolean := false;
begin
  begin
    insert into public.follows (follower_id, followee_id)
    values (bot00, bot00);
  exception when check_violation then
    blocked := true;
  end;

  if blocked then
    raise notice 'T3 PASS · self-follow blocked by CHECK constraint';
  else
    raise warning 'T3 FAIL · self-follow got through — constraint missing!';
    delete from public.follows
    where follower_id = bot00 and followee_id = bot00;
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- T4 · favorite idempotency (PK)
-- Re-liking the same poster should be a no-op (primary key collision).
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  bot00 uuid := '00000000-0000-0000-0000-000000000100';
  sample_poster uuid;
  cnt_before int;
  cnt_after int;
  blocked boolean := false;
begin
  select poster_id into sample_poster
  from public.favorites where user_id = bot00 limit 1;

  if sample_poster is null then
    raise notice 'T4 SKIP · bot00 has no favorites yet';
    return;
  end if;

  select count(*) into cnt_before from public.favorites where user_id = bot00;

  begin
    insert into public.favorites (user_id, poster_id)
    values (bot00, sample_poster);
  exception when unique_violation then
    blocked := true;
  end;

  select count(*) into cnt_after from public.favorites where user_id = bot00;

  if blocked and cnt_after = cnt_before then
    raise notice 'T4 PASS · duplicate favorite blocked by PK, count stable %', cnt_before;
  else
    raise warning 'T4 FAIL · duplicate favorite leaked: before=%, after=%, blocked=%',
      cnt_before, cnt_after, blocked;
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- T5 · avatar-report uniqueness (same reporter twice)
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  target uuid := '00000000-0000-0000-0000-000000000109';
  reporter uuid := '00000000-0000-0000-0000-000000000100';
  cnt_first int;
  cnt_second int;
begin
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (target, reporter, 'test T5 first')
  on conflict do nothing;

  select count(*) into cnt_first
  from public.avatar_reports where target_user_id = target and reporter_id = reporter;

  -- Same pair again → should be a no-op (ON CONFLICT)
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (target, reporter, 'test T5 second')
  on conflict do nothing;

  select count(*) into cnt_second
  from public.avatar_reports where target_user_id = target and reporter_id = reporter;

  if cnt_first = 1 and cnt_second = 1 then
    raise notice 'T5 PASS · re-report from same user is a no-op';
  else
    raise warning 'T5 FAIL · dup report leaked: first=%, second=%', cnt_first, cnt_second;
  end if;

  -- Clean up the single report we inserted. Make sure we don't leave
  -- bot09 pending_review (3-threshold may have already fired).
  delete from public.avatar_reports
  where target_user_id = target and reporter_id = reporter
    and reason like 'test T5%';
  update public.users set avatar_status = 'ok'
  where id = target and avatar_status = 'pending_review';
end $$;


-- ───────────────────────────────────────────────────────────────────
-- T6 · home_sections_v2 returns real payload (spot-check shape)
-- ───────────────────────────────────────────────────────────────────
do $$
declare
  row_count int;
  first_section text;
begin
  select count(*), (array_agg(slug))[1]
  into row_count, first_section
  from public.home_sections_v2();

  if row_count >= 3 then
    raise notice 'T6 PASS · home_sections_v2: % sections, first=%', row_count, first_section;
  else
    raise warning 'T6 FAIL · home_sections_v2 returned only % sections', row_count;
  end if;
end $$;


-- ═══════════════════════════════════════════════════════════════════
-- Final: print bot + relationship counts after all tests
-- ═══════════════════════════════════════════════════════════════════
select
  (select count(*) from public.users where handle like 'bot%')                                as bots,
  (select count(*) from public.follows
     where follower_id in (select id from public.users where handle like 'bot%'))             as bot_follows,
  (select count(*) from public.favorites
     where user_id in (select id from public.users where handle like 'bot%'))                 as bot_favorites,
  (select count(*) from public.avatar_reports)                                                as open_reports,
  (select count(*) from public.users where avatar_status = 'pending_review')                  as pending_avatars;
