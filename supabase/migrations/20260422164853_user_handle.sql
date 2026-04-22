-- ═══════════════════════════════════════════════════════════════════════════
-- v19: customisable @handle
-- ═══════════════════════════════════════════════════════════════════════════
-- The Profile page used to render `@<email-prefix>` (henry@gmail.com →
-- @henry). Want users to be able to claim a real handle for future
-- @mention / share-link features. Schema:
--
--   - users.handle: text, unique (case-insensitive), nullable.
--     Constraints: 3-20 chars, lowercase a-z 0-9 _ only, must start
--     with a letter. Enforced via CHECK + a unique index on lower(handle).
--   - user_public_profile() RPC returns the new field.
--
-- Display fallback (front-end): handle ?? email.split('@').first.

begin;

-- 1. Column.
alter table public.users
  add column if not exists handle text;

-- 2. CHECK on shape (lowercase letter-leading, alnum + underscore, 3-20).
do $$ begin
  alter table public.users
    add constraint users_handle_shape
      check (
        handle is null
        or handle ~ '^[a-z][a-z0-9_]{2,19}$'
      );
exception when duplicate_object then null;
end $$;

-- 3. Case-insensitive uniqueness. lower() index avoids double-claim
-- of "Henry" vs "henry"; CHECK already forces lowercase but defending
-- in depth in case someone disables the constraint at the DB level.
create unique index if not exists users_handle_unique_ci
  on public.users (lower(handle))
  where handle is not null;

-- 4. RPC update — return handle alongside the existing fields.
create or replace function public.user_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  u_row public.users%rowtype;
  approved_count int;
  result jsonb;
begin
  select * into u_row from public.users where id = p_user_id;
  if not found or u_row.is_public = false then
    return null;
  end if;

  select count(*) into approved_count
  from public.posters
  where uploader_id = p_user_id
    and status = 'approved'
    and deleted_at is null;

  result := jsonb_build_object(
    'id', u_row.id,
    'display_name', u_row.display_name,
    'handle', u_row.handle,
    'avatar_url', u_row.avatar_url,
    'bio', u_row.bio,
    'submission_count', u_row.submission_count,
    'approved_poster_count', approved_count,
    'is_public', u_row.is_public
  );
  return result;
end;
$$;

commit;
