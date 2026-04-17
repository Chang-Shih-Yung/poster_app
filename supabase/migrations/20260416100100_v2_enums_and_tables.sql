-- V2 Schema: enums, works, submissions, poster_views
-- Review decisions: work_key nullable UNIQUE (#2), favorites drop denorm (#5)
begin;

-- ─── New enums ───────────────────────────────────────────────────────────────

create type region_enum as enum (
  'TW','KR','HK','CN','JP','US','UK','FR','IT','PL','BE','OTHER'
);

create type release_type_enum as enum (
  'theatrical','reissue','special','limited','other'
);

create type size_type_enum as enum (
  'B1','B2','A3','A4','mini','custom','other'
);

create type channel_cat_enum as enum (
  'cinema','distributor','lottery','exhibition','retail','other'
);

create type submission_status as enum (
  'pending','approved','rejected','duplicate'
);

-- ─── works table ─────────────────────────────────────────────────────────────

create table public.works (
  id uuid primary key default gen_random_uuid(),
  work_key text unique,                          -- nullable UNIQUE (review #2)
  title_zh text not null,
  title_en text,
  movie_release_date date,
  movie_release_year int,
  poster_count int not null default 0,           -- RPC-maintained
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index works_title_zh_trgm_idx
  on public.works using gin (title_zh gin_trgm_ops);

create index works_year_idx
  on public.works (movie_release_year)
  where movie_release_year is not null;

-- ─── posters: add V2 columns ────────────────────────────────────────────────

alter table public.posters
  add column work_id uuid references public.works(id),
  add column poster_name text,
  add column region region_enum default 'TW',
  add column poster_release_date date,
  add column poster_release_type release_type_enum,
  add column size_type size_type_enum,
  add column channel_category channel_cat_enum,
  add column channel_type text,
  add column channel_name text,
  add column is_exclusive boolean not null default false,
  add column exclusive_name text,
  add column material_type text,
  add column version_label text,
  add column image_size_bytes bigint,
  add column source_url text,
  add column source_platform text,
  add column source_note text,
  add column favorite_count bigint not null default 0;

create index posters_work_id_idx
  on public.posters (work_id)
  where work_id is not null;

-- ─── submissions table ──────────────────────────────────────────────────────

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid,
  work_title_zh text not null,
  work_title_en text,
  movie_release_year int,
  poster_name text,
  region region_enum default 'TW',
  poster_release_date date,
  poster_release_type release_type_enum,
  size_type size_type_enum,
  channel_category channel_cat_enum,
  channel_type text,
  channel_name text,
  is_exclusive boolean not null default false,
  exclusive_name text,
  material_type text,
  version_label text,
  image_url text not null,
  thumbnail_url text,
  image_size_bytes bigint,
  source_url text,
  source_platform text,
  source_note text,
  uploader_id uuid not null references public.users(id) on delete restrict,
  status submission_status not null default 'pending',
  reviewer_id uuid references public.users(id),
  review_note text,
  reviewed_at timestamptz,
  matched_work_id uuid references public.works(id),
  created_poster_id uuid references public.posters(id),
  created_at timestamptz not null default now()
);

create index submissions_status_created_idx
  on public.submissions (status, created_at desc);

create index submissions_uploader_idx
  on public.submissions (uploader_id, created_at desc);

create index submissions_batch_idx
  on public.submissions (batch_id)
  where batch_id is not null;

-- ─── poster_views table ─────────────────────────────────────────────────────

create table public.poster_views (
  user_id uuid not null references public.users(id) on delete cascade,
  poster_id uuid not null references public.posters(id) on delete cascade,
  viewed_date date not null default current_date,
  primary key (user_id, poster_id, viewed_date)
);

-- ─── users: add V2 columns ─────────────────────────────────────────────────

alter table public.users
  add column is_public boolean not null default true,
  add column bio text;

-- ─── favorites: drop denormalized columns (review #5) ───────────────────────

alter table public.favorites
  alter column poster_title drop not null;

alter table public.favorites
  drop column if exists poster_title,
  drop column if exists poster_thumbnail_url;

-- ─── RLS for new tables ─────────────────────────────────────────────────────

alter table public.works enable row level security;
alter table public.submissions enable row level security;
alter table public.poster_views enable row level security;

-- works: everyone reads, admin writes
create policy works_read_all on public.works
  for select using (true);

create policy works_admin_write on public.works
  for all using (public.is_admin())
  with check (public.is_admin());

-- submissions: own reads own, admin reads all
create policy submissions_read_own on public.submissions
  for select using (uploader_id = auth.uid() or public.is_admin());

create policy submissions_insert_own on public.submissions
  for insert with check (
    auth.uid() is not null
    and uploader_id = auth.uid()
    and status = 'pending'
  );

create policy submissions_admin_all on public.submissions
  for all using (public.is_admin())
  with check (public.is_admin());

-- poster_views: own writes own
create policy poster_views_own on public.poster_views
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

commit;
