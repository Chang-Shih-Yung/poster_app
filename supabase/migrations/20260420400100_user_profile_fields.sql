-- ═══════════════════════════════════════════════════════════════════════════
-- User profile fields: gender + links (+ avatar storage bucket)
-- ═══════════════════════════════════════════════════════════════════════════
-- IG-style profile editing. Adds:
--   - gender enum (optional, includes 不公開 = prefer not to say)
--   - links jsonb array [{label, url}, ...]
--   - avatars storage bucket with own-folder RLS

begin;

do $$ begin
  create type public.gender_enum as enum (
    'male', 'female', 'non_binary', 'prefer_not_say'
  );
exception when duplicate_object then null;
end $$;

alter table public.users
  add column if not exists gender public.gender_enum,
  add column if not exists links jsonb not null default '[]'::jsonb;

-- Allow each user to update their own profile fields (already there
-- via users_update_self policy; just confirms columns are writable).

-- ─── Avatars storage bucket ───────────────────────────────────────────────
-- Mirror the posters bucket pattern: public read, own-folder write.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Drop + recreate (idempotent across re-runs)
drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_own_write" on storage.objects;
drop policy if exists "avatars_own_update" on storage.objects;
drop policy if exists "avatars_own_delete" on storage.objects;

create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars_own_write"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_own_update"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_own_delete"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
