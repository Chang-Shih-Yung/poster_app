-- ═══════════════════════════════════════════════════════════════════════════
-- Enrich list_notifications to include actor display_name + handle +
-- avatar_url so the front-end can render
--   "Bot 00 開始追蹤你"
--   "Bot 00 收藏了你的 全面啟動"
-- without a per-row join from the client. Also preserves enough data
-- for tap-through nav to the actor's profile.
--
-- The RPC previously returned `setof public.notifications`. We can't
-- change that without breaking the schema cache, so create a new
-- return type and switch the function to return it.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

drop function if exists public.list_notifications(int, int, boolean);

create or replace function public.list_notifications(
  p_offset int default 0,
  p_limit int default 30,
  p_unread_only boolean default false
)
returns table (
  id uuid,
  type public.notification_type,
  actor_id uuid,
  actor_name text,
  actor_handle text,
  actor_avatar_url text,
  target_id uuid,
  target_kind text,
  payload jsonb,
  read_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    n.id,
    n.type,
    n.actor_id,
    au.display_name as actor_name,
    au.handle       as actor_handle,
    case when au.avatar_status = 'ok' then au.avatar_url else null end
                    as actor_avatar_url,
    n.target_id,
    n.target_kind,
    n.payload,
    n.read_at,
    n.created_at
  from public.notifications n
  left join public.users au on au.id = n.actor_id
  where n.user_id = auth.uid()
    and (not p_unread_only or n.read_at is null)
  order by n.created_at desc
  offset p_offset
  limit p_limit;
$$;

grant execute on function public.list_notifications(int, int, boolean) to authenticated;

commit;
