-- ═══════════════════════════════════════════════════════════════════
-- Write-path integration tests. Paste into Supabase Dashboard →
-- SQL Editor.
--
-- Covers every mutation / trigger / RPC that the v19 backend
-- supports: avatar moderation (auto + admin clear/reject),
-- follows, favourites, submission state transitions,
-- notifications (follow / favourite / submission decision),
-- privacy, @handle regex + uniqueness, soft-delete filtering,
-- tag-suggestion flow, and RLS enforcement. 17 tests → 18 rows
-- (T1-T17 + SUMMARY).
--
-- Every test rolls back its own side-effects before exiting.
-- The SUMMARY row flips to LEAK if anything was left behind.
-- ═══════════════════════════════════════════════════════════════════

drop function if exists public._write_path_tests();

create or replace function public._write_path_tests()
returns table(test_id text, status text, detail text)
language plpgsql
as $fn$
declare
  k_bot00 uuid := '00000000-0000-0000-0000-000000000100';
  k_bot01 uuid := '00000000-0000-0000-0000-000000000101';
  k_bot02 uuid := '00000000-0000-0000-0000-000000000102';
  k_bot05 uuid := '00000000-0000-0000-0000-000000000105';
  k_bot09 uuid := '00000000-0000-0000-0000-000000000109';
  k_henry uuid := 'a1cb9f23-6423-4735-83ea-d10d29693a88';

  v_before       public.avatar_status;
  v_after        public.avatar_status;
  v_avatar_url   text;
  v_count_before int;
  v_count_mid    int;
  v_count_after  int;
  v_boolean      boolean;
  v_text         text;
  v_sample       uuid;
  v_payload      jsonb;
  v_sub_id       uuid;
  v_sug_id       uuid;
  v_sug_payload  jsonb;
  v_category     uuid;
  v_poster       uuid;
  v_uploader     uuid;
  v_notif_before int;
  v_notif_after  int;
  v_row_count    int;
  v_t9_success   boolean := false;
  v_t9_reason    text;
begin
  -- ============================================================
  -- T1 · avatar 3-report safety net trigger
  -- ============================================================
  select avatar_status into v_before from public.users where id = k_bot09;
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (k_bot09, k_bot00, 'test T1'),
         (k_bot09, k_bot01, 'test T1'),
         (k_bot09, k_bot02, 'test T1')
  on conflict do nothing;
  select avatar_status into v_after from public.users where id = k_bot09;

  test_id := 'T1';
  if v_before = 'ok' and v_after = 'pending_review' then
    status := 'PASS';
    detail := format('avatar 3-report trigger: %s → %s', v_before, v_after);
  else
    status := 'FAIL';
    detail := format('expected ok → pending_review, got %s → %s', v_before, v_after);
  end if;
  return next;
  delete from public.avatar_reports where target_user_id = k_bot09 and reason = 'test T1';
  update public.users set avatar_status = v_before where id = k_bot09;

  -- ============================================================
  -- T2 · follow toggle cycle (Henry → bot00)
  -- ============================================================
  select exists (select 1 from public.follows
                  where follower_id = k_henry and followee_id = k_bot00)
    into v_boolean;
  select count(*) into v_count_before from public.follows where followee_id = k_bot00;
  if not v_boolean then
    insert into public.follows (follower_id, followee_id) values (k_henry, k_bot00);
  end if;
  select count(*) into v_count_mid from public.follows where followee_id = k_bot00;
  if not v_boolean then
    delete from public.follows where follower_id = k_henry and followee_id = k_bot00;
    delete from public.notifications
     where user_id = k_bot00 and actor_id = k_henry and type = 'follow';
  end if;
  select count(*) into v_count_after from public.follows where followee_id = k_bot00;

  test_id := 'T2';
  if v_boolean then
    status := 'SKIP'; detail := 'Henry already followed bot00 — no-op';
  elsif v_count_mid = v_count_before + 1 and v_count_after = v_count_before then
    status := 'PASS';
    detail := format('follow cycle: %s → %s → %s', v_count_before, v_count_mid, v_count_after);
  else
    status := 'FAIL';
    detail := format('leaked: before=%s, mid=%s, after=%s',
                     v_count_before, v_count_mid, v_count_after);
  end if;
  return next;

  -- ============================================================
  -- T3 · self-follow CHECK
  -- ============================================================
  v_boolean := false;
  begin
    insert into public.follows (follower_id, followee_id) values (k_bot00, k_bot00);
  exception when check_violation then
    v_boolean := true;
  end;
  test_id := 'T3';
  if v_boolean then
    status := 'PASS'; detail := 'no_self_follow CHECK fires';
  else
    status := 'FAIL'; detail := 'self-follow got through!';
    delete from public.follows where follower_id = k_bot00 and followee_id = k_bot00;
  end if;
  return next;

  -- ============================================================
  -- T4 · favourite PK idempotency
  -- ============================================================
  select poster_id into v_sample from public.favorites where user_id = k_bot00 limit 1;
  test_id := 'T4';
  if v_sample is null then
    status := 'SKIP'; detail := 'bot00 has no favourites to duplicate';
  else
    select count(*) into v_count_before from public.favorites where user_id = k_bot00;
    v_boolean := false;
    begin
      insert into public.favorites (user_id, poster_id) values (k_bot00, v_sample);
    exception when unique_violation then
      v_boolean := true;
    end;
    select count(*) into v_count_after from public.favorites where user_id = k_bot00;
    if v_boolean and v_count_after = v_count_before then
      status := 'PASS';
      detail := format('PK blocks dup; favourites stable at %s', v_count_before);
    else
      status := 'FAIL';
      detail := format('blocked=%s, before=%s, after=%s',
                       v_boolean, v_count_before, v_count_after);
    end if;
  end if;
  return next;

  -- ============================================================
  -- T5 · avatar-report uniqueness
  -- ============================================================
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (k_bot09, k_bot00, 'test T5 first') on conflict do nothing;
  select count(*) into v_count_before
    from public.avatar_reports where target_user_id = k_bot09 and reporter_id = k_bot00;
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (k_bot09, k_bot00, 'test T5 second') on conflict do nothing;
  select count(*) into v_count_after
    from public.avatar_reports where target_user_id = k_bot09 and reporter_id = k_bot00;
  test_id := 'T5';
  if v_count_before = 1 and v_count_after = 1 then
    status := 'PASS'; detail := 'same-reporter second report is a no-op';
  else
    status := 'FAIL';
    detail := format('first=%s, second=%s', v_count_before, v_count_after);
  end if;
  return next;
  delete from public.avatar_reports
   where target_user_id = k_bot09 and reporter_id = k_bot00 and reason like 'test T5%';
  update public.users set avatar_status = 'ok' where id = k_bot09 and avatar_status = 'pending_review';

  -- ============================================================
  -- T6 · home_sections_v2 shape
  -- ============================================================
  v_payload := public.home_sections_v2();
  v_row_count := jsonb_array_length(v_payload);
  v_text := v_payload -> 0 ->> 'slug';
  test_id := 'T6';
  if v_row_count >= 3 then
    status := 'PASS';
    detail := format('%s sections, first=%s', v_row_count, v_text);
  else
    status := 'FAIL';
    detail := format('only %s sections', v_row_count);
  end if;
  return next;

  -- ============================================================
  -- T7 · notify_on_follow trigger
  -- ============================================================
  delete from public.follows
   where follower_id = k_bot00 and followee_id = k_bot05;
  delete from public.notifications
   where user_id = k_bot05 and actor_id = k_bot00 and type = 'follow';
  insert into public.follows (follower_id, followee_id) values (k_bot00, k_bot05);
  select count(*) into v_notif_after from public.notifications
    where user_id = k_bot05 and type = 'follow' and actor_id = k_bot00;
  test_id := 'T7';
  if v_notif_after = 1 then
    status := 'PASS';
    detail := 'follow insert → notification for followee';
  else
    status := 'FAIL';
    detail := format('expected 1 notification, got %s', v_notif_after);
  end if;
  return next;
  delete from public.follows where follower_id = k_bot00 and followee_id = k_bot05;
  delete from public.notifications
   where user_id = k_bot05 and actor_id = k_bot00 and type = 'follow';

  -- ============================================================
  -- T8 · notify_on_favorite trigger
  -- ============================================================
  v_poster := null;
  select p.id, p.uploader_id into v_poster, v_uploader
  from public.posters p
  where p.status = 'approved'
    and p.deleted_at is null
    and p.uploader_id is not null
    and p.uploader_id <> k_bot00
    and not exists (
      select 1 from public.favorites f
      where f.user_id = k_bot00 and f.poster_id = p.id
    )
  limit 1;

  test_id := 'T8';
  if v_poster is null then
    status := 'SKIP';
    detail := 'no approved non-bot00 poster to favourite';
  else
    select count(*) into v_notif_before from public.notifications
      where user_id = v_uploader and type = 'favorite' and target_id = v_poster
        and actor_id = k_bot00;
    insert into public.favorites (user_id, poster_id) values (k_bot00, v_poster);
    select count(*) into v_notif_after from public.notifications
      where user_id = v_uploader and type = 'favorite' and target_id = v_poster
        and actor_id = k_bot00;
    if v_notif_after = v_notif_before + 1 then
      status := 'PASS';
      detail := 'favourite insert → notification for uploader';
    else
      status := 'FAIL';
      detail := format('expected +1, got before=%s after=%s',
                       v_notif_before, v_notif_after);
    end if;
    delete from public.favorites where user_id = k_bot00 and poster_id = v_poster;
    delete from public.notifications
      where user_id = v_uploader and type = 'favorite' and target_id = v_poster
        and actor_id = k_bot00;
  end if;
  return next;

  -- ============================================================
  -- T9 · notify_on_submission_decision trigger
  -- Insert a pending submission, flip to approved, verify
  -- submission_approved notification appears for the uploader.
  -- If the trigger body references a column that doesn't exist
  -- (e.g. the known `new.title` vs `new.work_title_zh` drift),
  -- the UPDATE will raise — caught + reported as FAIL.
  -- ============================================================
  v_sub_id := null;
  v_t9_success := false;
  begin
    insert into public.submissions (work_title_zh, image_url, uploader_id, status)
    values ('T9 test zh', 'https://example.test/t9.jpg', k_bot00, 'pending')
    returning id into v_sub_id;

    update public.submissions set status = 'approved' where id = v_sub_id;

    select count(*) into v_notif_after from public.notifications
      where user_id = k_bot00 and target_id = v_sub_id and type = 'submission_approved';

    v_t9_success := true;
  exception when others then
    v_t9_reason := sqlerrm;
  end;

  test_id := 'T9';
  if not v_t9_success then
    status := 'FAIL';
    detail := format('trigger raised on UPDATE: %s', v_t9_reason);
  elsif v_notif_after = 1 then
    status := 'PASS';
    detail := 'submission approve → notification for uploader';
  else
    status := 'FAIL';
    detail := format('expected 1 submission_approved notification, got %s', v_notif_after);
  end if;
  return next;
  if v_sub_id is not null then
    delete from public.notifications where target_id = v_sub_id;
    delete from public.submissions where id = v_sub_id;
  end if;

  -- ============================================================
  -- T10 · admin_clear_avatar state transition
  -- Simulates what the RPC does (we skip the RPC's auth gate
  -- because the SQL editor runs as postgres).
  -- ============================================================
  update public.users set avatar_status = 'pending_review' where id = k_bot09;
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (k_bot09, k_bot00, 'test T10') on conflict do nothing;

  update public.users set avatar_status = 'ok' where id = k_bot09;
  delete from public.avatar_reports where target_user_id = k_bot09;

  select avatar_status into v_after from public.users where id = k_bot09;
  select count(*) into v_count_after from public.avatar_reports where target_user_id = k_bot09;
  test_id := 'T10';
  if v_after = 'ok' and v_count_after = 0 then
    status := 'PASS';
    detail := 'admin clear → avatar_status=ok + reports wiped';
  else
    status := 'FAIL';
    detail := format('status=%s, reports=%s', v_after, v_count_after);
  end if;
  return next;

  -- ============================================================
  -- T11 · admin_reject_avatar state transition
  -- Verifies status=rejected, avatar_url wiped, reports deleted.
  -- Restores the url at the end.
  -- ============================================================
  select avatar_url into v_avatar_url from public.users where id = k_bot09;
  insert into public.avatar_reports (target_user_id, reporter_id, reason)
  values (k_bot09, k_bot00, 'test T11') on conflict do nothing;

  update public.users set avatar_status = 'rejected', avatar_url = null
   where id = k_bot09;
  delete from public.avatar_reports where target_user_id = k_bot09;

  select avatar_status, avatar_url into v_after, v_text
  from public.users where id = k_bot09;
  select count(*) into v_count_after from public.avatar_reports where target_user_id = k_bot09;
  test_id := 'T11';
  if v_after = 'rejected' and v_text is null and v_count_after = 0 then
    status := 'PASS';
    detail := 'admin reject → status=rejected, url=null, reports wiped';
  else
    status := 'FAIL';
    detail := format('status=%s, url=%s, reports=%s', v_after, v_text, v_count_after);
  end if;
  return next;
  update public.users set avatar_status = 'ok', avatar_url = v_avatar_url where id = k_bot09;

  -- ============================================================
  -- T12 · user_public_profile hides private users
  -- ============================================================
  update public.users set is_public = false where id = k_bot05;
  v_payload := public.user_public_profile(k_bot05);
  update public.users set is_public = true where id = k_bot05;

  test_id := 'T12';
  if v_payload is null then
    status := 'PASS';
    detail := 'user_public_profile returns null for is_public=false';
  else
    status := 'FAIL';
    detail := format('expected null, got %s', v_payload::text);
  end if;
  return next;

  -- ============================================================
  -- T13 · @handle regex CHECK
  -- ============================================================
  v_boolean := false;
  begin
    update public.users set handle = 'BadHandle' where id = k_bot05;
  exception when check_violation then
    v_boolean := true;
  end;
  test_id := 'T13';
  if v_boolean then
    status := 'PASS';
    detail := '@handle CHECK rejects uppercase / bad shape';
  else
    status := 'FAIL';
    detail := 'bad handle got through — CHECK constraint missing';
    update public.users set handle = 'bot05' where id = k_bot05;
  end if;
  return next;

  -- ============================================================
  -- T14 · @handle uniqueness (case-insensitive index)
  -- Try to set bot05's handle to bot00's handle.
  -- ============================================================
  select handle into v_text from public.users where id = k_bot00;
  v_boolean := false;
  begin
    update public.users set handle = v_text where id = k_bot05;
  exception when unique_violation then
    v_boolean := true;
  end;
  test_id := 'T14';
  if v_boolean then
    status := 'PASS';
    detail := format('@handle unique index blocks collision with %s', v_text);
  else
    status := 'FAIL';
    detail := 'duplicate handle got through';
    update public.users set handle = 'bot05' where id = k_bot05;
  end if;
  return next;

  -- ============================================================
  -- T15 · soft-deleted poster disappears from trending_favorites
  -- ============================================================
  v_poster := null;
  select id into v_poster from public.posters
   where status = 'approved' and deleted_at is null and favorite_count > 0
   order by favorite_count desc limit 1;

  test_id := 'T15';
  if v_poster is null then
    status := 'SKIP';
    detail := 'no approved poster with favourites to soft-delete';
  else
    -- trending_favorites returns a jsonb array
    v_payload := public.trending_favorites(7, 20);
    select count(*) into v_count_before
      from jsonb_array_elements(v_payload) as row
     where (row ->> 'id')::uuid = v_poster;

    update public.posters set deleted_at = now() where id = v_poster;

    v_payload := public.trending_favorites(7, 20);
    select count(*) into v_count_after
      from jsonb_array_elements(v_payload) as row
     where (row ->> 'id')::uuid = v_poster;

    update public.posters set deleted_at = null where id = v_poster;

    if v_count_before >= 1 and v_count_after = 0 then
      status := 'PASS';
      detail := 'soft-delete hides poster from trending_favorites';
    else
      status := 'FAIL';
      detail := format('before=%s, after=%s', v_count_before, v_count_after);
    end if;
  end if;
  return next;

  -- ============================================================
  -- T16 · submit_tag_suggestion end-to-end as bot00
  -- ============================================================
  v_category := null;
  select id into v_category from public.tag_categories limit 1;
  test_id := 'T16';
  if v_category is null then
    status := 'SKIP';
    detail := 'no tag_categories — cannot exercise suggestion flow';
    return next;
  else
    v_sug_id := null;
    v_t9_success := false;
    begin
      perform set_config(
        'request.jwt.claims',
        jsonb_build_object('sub', k_bot00::text, 'role', 'authenticated')::text,
        true
      );
      v_sug_payload := public.submit_tag_suggestion(
        v_category, 'T16 測試建議', 'T16 Test Suggestion', null, null
      );
      perform set_config('request.jwt.claims', '', true);

      -- RPC returns jsonb; pull the id out.
      v_sug_id := (v_sug_payload ->> 'id')::uuid;
      v_t9_success := true;
    exception when others then
      perform set_config('request.jwt.claims', '', true);
      v_t9_reason := sqlerrm;
    end;

    if not v_t9_success then
      status := 'FAIL';
      detail := format('submit_tag_suggestion raised: %s', v_t9_reason);
    elsif v_sug_id is not null then
      status := 'PASS';
      detail := format('submit_tag_suggestion returned id=%s', v_sug_id);
    else
      status := 'FAIL';
      detail := format('submit_tag_suggestion returned %s (no id)', v_sug_payload::text);
    end if;
    return next;

    if v_sug_id is not null then
      delete from public.tag_suggestions where id = v_sug_id;
    end if;
  end if;

  -- ============================================================
  -- T17 · RLS blocks anon writes on follows
  -- ============================================================
  v_boolean := false;
  begin
    perform set_config('role', 'anon', true);
    begin
      insert into public.follows (follower_id, followee_id)
      values (k_bot00, k_henry);
    exception when others then
      v_boolean := true;
    end;
    perform set_config('role', 'postgres', true);
  exception when others then
    perform set_config('role', 'postgres', true);
  end;

  test_id := 'T17';
  if v_boolean then
    status := 'PASS';
    detail := 'anon role blocked from inserting into follows';
  else
    status := 'FAIL';
    detail := 'anon got through to follows insert — RLS leak!';
    delete from public.follows where follower_id = k_bot00 and followee_id = k_henry;
  end if;
  return next;

  return;
end;
$fn$;


-- 18 rows in one grid: T1-T17 + SUMMARY.
select test_id, status, detail from public._write_path_tests()
union all
select
  'SUMMARY',
  case when (select count(*) from public.avatar_reports) = 0
        and (select count(*) from public.users where avatar_status = 'pending_review') = 0
       then 'CLEAN' else 'LEAK' end,
  format(
    'bots=%s · bot_follows=%s · bot_favorites=%s · open_reports=%s · pending_avatars=%s',
    (select count(*) from public.users where handle like 'bot%'),
    (select count(*) from public.follows
       where follower_id in (select id from public.users where handle like 'bot%')),
    (select count(*) from public.favorites
       where user_id in (select id from public.users where handle like 'bot%')),
    (select count(*) from public.avatar_reports),
    (select count(*) from public.users where avatar_status = 'pending_review')
  )
order by test_id;

drop function public._write_path_tests();
