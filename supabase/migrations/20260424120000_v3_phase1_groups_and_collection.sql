-- ═══════════════════════════════════════════════════════════════════════════
-- v3 Phase 1 — catalogue tree + per-user collection state + private photos
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Adds three concepts on top of the existing works / posters schema:
--
--   1. poster_groups (recursive)        — turns posters from a flat list
--                                           under works into an arbitrary
--                                           tree (release era → variant)
--
--   2. user_poster_state                — per-(user, poster) ownership:
--                                           owned | wishlist | seen
--
--   3. user_poster_override             — per-(user, poster) private photo
--                                           (strictly private — owner only)
--
-- Plus additive columns on existing tables (studio, is_placeholder,
-- parent_group_id) so migration is 100% non-destructive.
--
-- Rationale + product decisions in docs/plan-v3-collection-pivot.md.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. works — add studio text column ───────────────────────────────────

alter table public.works
  add column if not exists studio text;

create index if not exists idx_works_studio
  on public.works(studio)
  where studio is not null;

comment on column public.works.studio is
  'Free-text studio / IP holder name (e.g. 吉卜力, Marvel, 新海誠 作品群). Not an FK — kept flexible so the editor can type new studios without a separate table.';

-- ─── 2. poster_groups — recursive tree between work and poster ──────────

create table if not exists public.poster_groups (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.works(id) on delete cascade,
  parent_group_id uuid references public.poster_groups(id) on delete cascade,
  name text not null,
  group_type text,                 -- 'release_era' | 'variant' | custom
  display_order int not null default 0,
  cover_url text,                  -- optional representative image
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_poster_groups_work
  on public.poster_groups(work_id);
create index if not exists idx_poster_groups_parent
  on public.poster_groups(parent_group_id);

-- Tree-walking sanity: no group can be its own ancestor.
-- Enforced app-side (cycle detection in the admin); DB just forbids
-- the trivial (parent = self) case.
alter table public.poster_groups
  drop constraint if exists poster_groups_not_self_parent;
alter table public.poster_groups
  add constraint poster_groups_not_self_parent
  check (id <> parent_group_id);

comment on table public.poster_groups is
  'Recursive groups between a work and its leaf posters. Level shape is editor-defined per work — typically "release era" → "variant" → leaf poster.';

-- ─── 3. posters — add parent_group_id + is_placeholder ──────────────────

alter table public.posters
  add column if not exists parent_group_id uuid references public.poster_groups(id) on delete set null,
  add column if not exists is_placeholder boolean not null default true;

create index if not exists idx_posters_parent_group
  on public.posters(parent_group_id)
  where parent_group_id is not null;

create index if not exists idx_posters_is_placeholder
  on public.posters(is_placeholder)
  where is_placeholder = true;

comment on column public.posters.parent_group_id is
  'v3: leaf poster hangs off a poster_groups node. NULL for legacy v2 posters that haven''t been migrated into the tree yet.';
comment on column public.posters.is_placeholder is
  'v3: TRUE when poster_url is still a work-kind silhouette. FALSE once the admin uploads the real image.';

-- ─── 4. user_poster_state — the "flip" table ────────────────────────────

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_poster_state_enum') then
    create type public.user_poster_state_enum as enum (
      'owned',    -- user has this poster (flipped)
      'wishlist', -- user wants this poster
      'seen'      -- user has seen it (cinema, friend's collection) but doesn't own
    );
  end if;
end
$$;

create table if not exists public.user_poster_state (
  user_id uuid not null references public.users(id) on delete cascade,
  poster_id uuid not null references public.posters(id) on delete cascade,
  state user_poster_state_enum not null,
  flipped_at timestamptz not null default now(),
  note text,
  primary key (user_id, poster_id)
);

create index if not exists idx_user_poster_state_user_flipped
  on public.user_poster_state(user_id, flipped_at desc);
create index if not exists idx_user_poster_state_poster
  on public.user_poster_state(poster_id, state);

comment on table public.user_poster_state is
  'v3: one row per (user, poster) when the user has taken an action on it. Absence of a row = user has not flipped / wished / seen.';

-- ─── 5. user_poster_override — private personal photo ──────────────────

create table if not exists public.user_poster_override (
  user_id uuid not null references public.users(id) on delete cascade,
  poster_id uuid not null references public.posters(id) on delete cascade,
  image_url text not null,
  thumbnail_url text,
  blurhash text,
  image_size_bytes bigint,
  uploaded_at timestamptz not null default now(),
  primary key (user_id, poster_id)
);

create index if not exists idx_user_poster_override_uploaded
  on public.user_poster_override(uploaded_at desc);

comment on table public.user_poster_override is
  'v3: user''s own photo replacing the canonical image in THEIR view only. Strictly private — visible only to the uploader.';

-- ─── 6. RLS — admin-gated writes, per-user reads for collection state ──

alter table public.poster_groups enable row level security;
alter table public.user_poster_state enable row level security;
alter table public.user_poster_override enable row level security;

-- poster_groups: readable by everyone, writable only by admin (role='admin').
drop policy if exists poster_groups_read on public.poster_groups;
create policy poster_groups_read
  on public.poster_groups for select
  using (true);

-- Admin writes gated by users.role = 'admin' on the caller.
drop policy if exists poster_groups_admin_write on public.poster_groups;
create policy poster_groups_admin_write
  on public.poster_groups for all
  using (
    exists (
      select 1 from public.users
      where id = auth.uid() and role in ('admin', 'owner')
    )
  )
  with check (
    exists (
      select 1 from public.users
      where id = auth.uid() and role in ('admin', 'owner')
    )
  );

-- user_poster_state: each user manages only their own rows.
drop policy if exists user_poster_state_self on public.user_poster_state;
create policy user_poster_state_self
  on public.user_poster_state for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- user_poster_state: readable publicly (since collections are public per Q4).
-- Note: override photos are NOT publicly readable, hence no public read policy
-- on user_poster_override.
drop policy if exists user_poster_state_public_read on public.user_poster_state;
create policy user_poster_state_public_read
  on public.user_poster_state for select
  using (true);

-- user_poster_override: strictly private — only the uploader reads.
drop policy if exists user_poster_override_self on public.user_poster_override;
create policy user_poster_override_self
  on public.user_poster_override for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── 7. Convenience: resolved_image_url helper view (optional) ──────────
--
-- Returns the image URL a viewer should render for a (viewer, poster) pair,
-- applying the four-tier resolution rule:
--   Personalized (viewer has override) → user_poster_override.image_url
--   Unlocked      (viewer has owned)    → posters.poster_url (if not placeholder)
--   Silhouette   (placeholder or no-real-image-and-not-owned) → posters.poster_url
--
-- Not materialised; Flutter resolves at query-time so it can pass the viewer's
-- id in. Documented here as a reference for the app side.

comment on column public.posters.poster_url is
  'v3: never NULL. Initially a work-kind silhouette (is_placeholder=true). Replaced with a real scan by admin, is_placeholder flipped to false. The user''s personal override (user_poster_override.image_url) takes precedence in the owner''s own view only.';

-- ─── 8. updated_at trigger for poster_groups ────────────────────────────

create or replace function public.set_poster_groups_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_poster_groups_updated_at on public.poster_groups;
create trigger trg_poster_groups_updated_at
  before update on public.poster_groups
  for each row
  execute function public.set_poster_groups_updated_at();

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- Post-apply checklist (run by Henry in Supabase Dashboard):
--
--   1. SELECT 1 FROM public.poster_groups LIMIT 1;            -- table exists
--   2. SELECT 1 FROM public.user_poster_state LIMIT 1;        -- table exists
--   3. SELECT 1 FROM public.user_poster_override LIMIT 1;     -- table exists
--   4. SELECT is_placeholder FROM public.posters LIMIT 1;     -- column present
--   5. SELECT studio FROM public.works LIMIT 1;               -- column present
--
-- RLS smoke test (with a non-admin auth session):
--   INSERT INTO public.poster_groups (...)  -- expect permission denied
--   INSERT INTO public.user_poster_state (user_id = auth.uid(), ...)  -- OK
--
-- If the migration fails partway through, the BEGIN/COMMIT wraps the whole
-- file so no half-state should persist.
-- ═══════════════════════════════════════════════════════════════════════════
