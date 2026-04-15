-- Poster App — initial schema
-- Tables: users, posters, favorites, audit_logs
-- RLS: all tables on. Policies below.

begin;

create type poster_status as enum ('pending', 'approved', 'rejected');
create type user_role as enum ('user', 'admin', 'owner');

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  role user_role not null default 'user',
  submission_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.posters (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  year integer,
  director text,
  tags text[] not null default '{}',
  poster_url text not null,
  thumbnail_url text,
  uploader_id uuid not null references public.users(id) on delete restrict,
  status poster_status not null default 'pending',
  reviewer_id uuid references public.users(id),
  review_note text,
  reviewed_at timestamptz,
  view_count bigint not null default 0,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  deleted_at timestamptz
);

create index posters_status_created_idx
  on public.posters (status, created_at desc)
  where deleted_at is null;

create index posters_tags_gin_idx
  on public.posters using gin (tags);

create index posters_uploader_created_idx
  on public.posters (uploader_id, created_at desc);

create index posters_year_idx
  on public.posters (status, year, created_at desc)
  where deleted_at is null;

create index posters_title_trgm_idx
  on public.posters using gin (title gin_trgm_ops);

create extension if not exists pg_trgm;

create table public.favorites (
  user_id uuid not null references public.users(id) on delete cascade,
  poster_id uuid not null references public.posters(id) on delete cascade,
  poster_title text not null,
  poster_thumbnail_url text,
  created_at timestamptz not null default now(),
  primary key (user_id, poster_id)
);

create index favorites_user_created_idx
  on public.favorites (user_id, created_at desc);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users(id),
  action text not null,
  target_table text not null,
  target_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_target_idx
  on public.audit_logs (target_table, target_id, created_at desc);

-- Auto-create users row when a new auth user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper functions
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role in ('admin', 'owner')
  );
$$;

-- RLS
alter table public.users enable row level security;
alter table public.posters enable row level security;
alter table public.favorites enable row level security;
alter table public.audit_logs enable row level security;

-- users policies
create policy users_read_self on public.users
  for select using (id = auth.uid() or public.is_admin());

create policy users_update_self on public.users
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.users where id = auth.uid()));

create policy users_admin_all on public.users
  for all using (public.is_admin())
  with check (public.is_admin());

-- posters policies
create policy posters_read_approved on public.posters
  for select using (
    (status = 'approved' and deleted_at is null)
    or uploader_id = auth.uid()
    or public.is_admin()
  );

create policy posters_insert_own on public.posters
  for insert with check (
    auth.uid() is not null
    and uploader_id = auth.uid()
    and status = 'pending'
    and deleted_at is null
  );

create policy posters_update_own_pending on public.posters
  for update using (
    uploader_id = auth.uid() and status = 'pending'
  ) with check (
    uploader_id = auth.uid() and status = 'pending'
  );

create policy posters_admin_all on public.posters
  for all using (public.is_admin())
  with check (public.is_admin());

-- favorites policies
create policy favorites_own on public.favorites
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- audit_logs: readable by admin only, inserts by SECURITY DEFINER functions
create policy audit_logs_admin_read on public.audit_logs
  for select using (public.is_admin());

commit;
