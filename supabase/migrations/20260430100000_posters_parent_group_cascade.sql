-- ═══════════════════════════════════════════════════════════════════════════
-- posters.parent_group_id — change FK to ON DELETE CASCADE
--
-- Background:
--   The original v3 groups migration (20260424120000) declared
--     posters.parent_group_id ... on delete set null
--   The intent at the time was "deleting a group shouldn't kill posters;
--   they just become ungrouped under the work". That's a defensible
--   model, but it's NOT the model the admin's mental map uses — the UI
--   has always presented the tree as Google-Drive-shaped: deleting a
--   folder takes everything inside with it. The previous SET NULL
--   behaviour leaked a separate concept (orphaned posters at the work
--   root) that the admin had to know about.
--
-- Decision: switch to ON DELETE CASCADE.
--
--   - Matches Google Drive intuition: delete a folder → contents go too.
--   - Admin UI already supports drag-to-move posters out of a group
--     before deletion, so users can rescue posters they want to keep.
--   - poster_groups.parent_group_id is already ON DELETE CASCADE, so
--     deleting a group already nukes child groups recursively. Posters
--     surviving while their containing group disappears was always the
--     odd one out.
--   - Drag/move operations are UPDATEs, not DELETEs — unaffected by
--     this change.
--
-- After this migration: deleteGroup() in admin/app/actions/groups.ts
-- doesn't need any code change. The DB does the cascade. The confirm
-- dialog copy is updated separately to match the new behaviour.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.posters
  drop constraint if exists posters_parent_group_id_fkey;

alter table public.posters
  add constraint posters_parent_group_id_fkey
  foreign key (parent_group_id) references public.poster_groups(id)
  on delete cascade;

commit;
