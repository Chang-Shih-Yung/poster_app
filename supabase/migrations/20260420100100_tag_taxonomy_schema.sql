-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18: Tag Taxonomy — schema foundation
-- ═══════════════════════════════════════════════════════════════════════════
-- Replaces flat `posters.tags text[]` with a faceted taxonomy:
--   tag_categories (facets: country, era, medium, designer, aesthetic, ...)
--   tags (canonical admin-defined, with aliases for search)
--   poster_tags (many-to-many)
--   tag_suggestions (user-suggested new tags, admin reviews)
--
-- Design decisions (from 2026-04-17 discussion):
--   - No user-created free tags (prevents spam, keeps taxonomy clean)
--   - "其他" fallback tag per required category
--   - aliases text[] for search (label_zh OR label_en OR any alias match)
--   - Users can SUGGEST new tags via separate queue (doesn't block submission)

begin;

-- ─── 1. tag_categories ─────────────────────────────────────────────────────

create table public.tag_categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title_zh text not null,
  title_en text not null,
  description_zh text,
  description_en text,
  position int not null default 0,
  icon text,                               -- lucide icon name
  kind text not null default 'free_tag',   -- 'enum' | 'controlled_vocab' | 'free_tag'
  is_required boolean default false,       -- must user pick at least one at submit?
  allow_other boolean default true,        -- '其他' fallback tag available?
  allows_suggestion boolean default true,  -- users can suggest new tags?
  created_at timestamptz not null default now()
);

-- ─── 2. tags ───────────────────────────────────────────────────────────────

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  category_id uuid not null references public.tag_categories(id) on delete restrict,
  label_zh text not null,
  label_en text not null,
  description text,
  aliases text[] not null default '{}',    -- ['miyazaki','ミヤザキ','宮崎駿']
  poster_count int not null default 0,     -- denorm, periodic refresh
  is_canonical boolean not null default true,
  is_other_fallback boolean not null default false,
  deprecated boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index idx_tags_category on public.tags(category_id) where deprecated = false;
create index idx_tags_aliases_gin on public.tags using gin (aliases);
create index idx_tags_label_zh_trgm
  on public.tags using gin (label_zh gin_trgm_ops);
create index idx_tags_label_en_trgm
  on public.tags using gin (label_en gin_trgm_ops);

-- ─── 3. poster_tags (many-to-many) ─────────────────────────────────────────

create table public.poster_tags (
  poster_id uuid not null references public.posters(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  added_by uuid references public.users(id) on delete set null,
  added_at timestamptz not null default now(),
  primary key (poster_id, tag_id)
);

create index idx_poster_tags_tag on public.poster_tags(tag_id);

-- ─── 4. tag_suggestions ────────────────────────────────────────────────────

create table public.tag_suggestions (
  id uuid primary key default gen_random_uuid(),
  suggested_by uuid references public.users(id) on delete set null,
  suggested_slug text,                      -- auto-generated from label_zh if null
  suggested_label_zh text not null,
  suggested_label_en text,
  category_id uuid not null references public.tag_categories(id) on delete cascade,
  reason text,                              -- user explanation
  linked_submission_id uuid references public.submissions(id) on delete set null,
  status text not null default 'pending',   -- pending | approved | rejected | merged
  merged_into_tag_id uuid references public.tags(id) on delete set null,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now()
);

create index idx_tag_suggestions_status
  on public.tag_suggestions(status, created_at desc);

-- ─── RLS ───────────────────────────────────────────────────────────────────

alter table public.tag_categories enable row level security;
alter table public.tags enable row level security;
alter table public.poster_tags enable row level security;
alter table public.tag_suggestions enable row level security;

-- tag_categories: everyone reads, admin writes
create policy tag_categories_read_all on public.tag_categories
  for select using (true);
create policy tag_categories_admin_write on public.tag_categories
  for all using (public.is_admin()) with check (public.is_admin());

-- tags: everyone reads (for taxonomy UI), admin writes canonical ones
create policy tags_read_all on public.tags
  for select using (true);
create policy tags_admin_write on public.tags
  for all using (public.is_admin()) with check (public.is_admin());

-- poster_tags: read follows poster RLS, write restricted to admin
-- (canonical attachment only; users suggest via tag_suggestions)
create policy poster_tags_read_all on public.poster_tags
  for select using (true);
create policy poster_tags_admin_write on public.poster_tags
  for all using (public.is_admin()) with check (public.is_admin());

-- tag_suggestions: own insert, own read own, admin read all + write
create policy tag_suggestions_read_own on public.tag_suggestions
  for select using (suggested_by = auth.uid() or public.is_admin());
create policy tag_suggestions_insert_own on public.tag_suggestions
  for insert with check (
    auth.uid() is not null
    and suggested_by = auth.uid()
    and status = 'pending'
  );
create policy tag_suggestions_admin_update on public.tag_suggestions
  for update using (public.is_admin()) with check (public.is_admin());

commit;
