-- Phase 2: favorite categories
-- Users can group favorites into named categories. NULL category_id = 預設（全部）

begin;

create table public.favorite_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create index favorite_categories_user_sort_idx
  on public.favorite_categories (user_id, sort_order, created_at);

alter table public.favorites
  add column category_id uuid references public.favorite_categories(id) on delete set null;

create index favorites_user_category_idx
  on public.favorites (user_id, category_id, created_at desc);

alter table public.favorite_categories enable row level security;

create policy own_categories_select on public.favorite_categories
  for select using (user_id = auth.uid());

create policy own_categories_insert on public.favorite_categories
  for insert with check (user_id = auth.uid());

create policy own_categories_update on public.favorite_categories
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy own_categories_delete on public.favorite_categories
  for delete using (user_id = auth.uid());

commit;
