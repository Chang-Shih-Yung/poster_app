-- ═══════════════════════════════════════════════════════════════════════════
-- Recursive poster count per group, computed in SQL
--
-- /tree/work/[id] and /tree/group/[id] previously fetched every group +
-- every poster of the work and computed `recursivePosterCount` in TS.
-- For a work with 1,000 posters that's a lot of bytes to push down to
-- the client just to render badges.
--
-- This function returns one row per group in a work, with the total
-- count of (non-deleted) posters living anywhere underneath. The caller
-- joins it onto the group list it already has.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.get_group_recursive_counts(p_work_id uuid)
returns table(group_id uuid, total bigint)
language sql
stable
security definer
set search_path = public
as $$
  -- subtree(root, descendant): every (root, descendant) pair where
  -- descendant lives somewhere under root in the group tree. The base
  -- case `root = descendant` covers "direct children of root" without
  -- a separate union.
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
  select st.root as group_id,
         coalesce(count(p.id), 0)::bigint as total
  from subtree st
  left join posters p
    on p.parent_group_id = st.descendant
   and p.deleted_at is null
  group by st.root;
$$;

-- Allow authenticated callers (admin Server Actions reach in via auth
-- cookie). Anonymous Flutter readers don't currently need this, so
-- service_role + authenticated is enough.
grant execute on function public.get_group_recursive_counts(uuid)
  to authenticated, service_role;

commit;
