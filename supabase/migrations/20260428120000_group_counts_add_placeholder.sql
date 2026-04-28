-- ═══════════════════════════════════════════════════════════════════════════
-- Extend get_group_recursive_counts: add placeholder_total column
--
-- tree rows now need to show "N 張海報 · M 待補圖" so the user can
-- see at a glance which groups still need real images. This replaces
-- the previous single-column version with a two-column return.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.get_group_recursive_counts(p_work_id uuid)
returns table(group_id uuid, total bigint, placeholder_total bigint)
language sql
stable
security definer
set search_path = public
as $$
  with recursive subtree as (
    select id as root, id as descendant
    from poster_groups
    where work_id = p_work_id
    union all
    select st.root, g.id
    from subtree st
    join poster_groups g
      on g.parent_group_id = st.descendant
    where g.work_id = p_work_id
  )
  select st.root                                             as group_id,
         coalesce(count(p.id), 0)::bigint                   as total,
         coalesce(count(p.id) filter (where p.is_placeholder), 0)::bigint
                                                            as placeholder_total
  from subtree st
  left join posters p
    on p.parent_group_id = st.descendant
   and p.deleted_at is null
  group by st.root;
$$;

grant execute on function public.get_group_recursive_counts(uuid)
  to authenticated, service_role;

commit;
