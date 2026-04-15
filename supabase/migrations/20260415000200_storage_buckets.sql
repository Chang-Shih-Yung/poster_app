-- Posters storage bucket + policies
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'posters',
  'posters',
  true,
  10 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "posters_public_read"
  on storage.objects for select
  using (bucket_id = 'posters');

create policy "posters_authenticated_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'posters'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "posters_admin_manage"
  on storage.objects for all
  using (
    bucket_id = 'posters' and public.is_admin()
  ) with check (
    bucket_id = 'posters' and public.is_admin()
  );

commit;
