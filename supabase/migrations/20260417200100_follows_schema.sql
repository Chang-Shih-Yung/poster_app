-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 11: Social Signals — follows table
-- ═══════════════════════════════════════════════════════════════════════════
-- Public follow graph (IG/Twitter model): any user can see who follows whom.
-- This is the foundation for:
--   - "追蹤的人最近在收" home section
--   - follower/following counts on public profile
--   - future: feed ranking by social proximity
--
-- We deliberately do NOT denormalize follower_count / following_count onto
-- users. The v1 review #5 lesson was: denorm drift. Counts are computed on
-- demand via user_relationship_stats RPC. At 100k+ follows we can revisit.

begin;

create table if not exists public.follows (
  follower_id uuid not null references public.users(id) on delete cascade,
  followee_id uuid not null references public.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  -- Three-layer defense against self-follow: DB, RPC, UI.
  constraint no_self_follow check (follower_id != followee_id)
);

-- Reverse lookup: "who follows me" — the primary key covers (follower, followee)
-- so the left-anchored "who am I following" query is fast. The reverse needs
-- its own index.
create index if not exists idx_follows_followee
  on public.follows (followee_id, created_at desc);

-- ─── RLS ───────────────────────────────────────────────────────────────────

alter table public.follows enable row level security;

-- Public graph: any signed-in user can read who follows whom. This mirrors
-- how IG/Twitter expose follower lists on public profiles.
create policy follows_read_all on public.follows
  for select using (auth.uid() is not null);

-- Only the follower themselves can create their own follow edge.
create policy follows_insert_own on public.follows
  for insert with check (
    auth.uid() is not null
    and follower_id = auth.uid()
    and follower_id != followee_id
  );

-- Only the follower can unfollow (delete their own edge).
create policy follows_delete_own on public.follows
  for delete using (follower_id = auth.uid());

commit;
