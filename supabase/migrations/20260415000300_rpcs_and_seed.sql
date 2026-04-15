-- RPC: increment view_count atomically
-- RPC: approve/reject poster (admin only)
begin;

create or replace function public.increment_poster_view_count(poster_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.posters
     set view_count = view_count + 1
   where id = poster_id
     and status = 'approved'
     and deleted_at is null;
$$;

create or replace function public.review_poster(
  poster_id uuid,
  new_status poster_status,
  note text default null
)
returns public.posters
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.posters;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  update public.posters
     set status = new_status,
         reviewer_id = auth.uid(),
         review_note = note,
         reviewed_at = now(),
         approved_at = case when new_status = 'approved' then now() else approved_at end
   where id = poster_id
  returning * into result;

  insert into public.audit_logs (actor_id, action, target_table, target_id, after)
  values (auth.uid(), 'review_poster:' || new_status::text, 'posters', poster_id,
          jsonb_build_object('status', new_status, 'note', note));

  return result;
end;
$$;

grant execute on function public.increment_poster_view_count(uuid) to anon, authenticated;
grant execute on function public.review_poster(uuid, poster_status, text) to authenticated;

commit;
