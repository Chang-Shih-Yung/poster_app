-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: increment_view_with_dedup never incremented view_count.
-- ═══════════════════════════════════════════════════════════════════════════
-- Root cause: `GET DIAGNOSTICS inserted = ROW_COUNT` returns bigint, but
-- `inserted` was declared boolean. PostgreSQL has no implicit bigint→bool
-- cast, so this raised on every call. The Dart side silently swallowed the
-- error, masking the bug. Result: view_count was frozen at seed values.
--
-- Fix: use an integer and compare > 0.

begin;

create or replace function public.increment_view_with_dedup(p_poster_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
begin
  insert into public.poster_views (user_id, poster_id, viewed_date)
  values (auth.uid(), p_poster_id, current_date)
  on conflict do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.posters
       set view_count = view_count + 1
     where id = p_poster_id
       and status = 'approved'
       and deleted_at is null;
  end if;
end;
$$;

commit;
