-- ═══════════════════════════════════════════════════════════════════════════
-- posters legacy NOT NULL columns — DB-side defaults
--
-- `posters.title`, `posters.poster_url`, `posters.uploader_id` are NOT
-- NULL for historical reasons (V1 schema before posters had real
-- metadata). Today we want admin-created rows to be able to omit them
-- safely:
--
--   - title       → keep in lock-step with poster_name (single source
--                   of truth at the application layer is poster_name)
--   - poster_url  → empty string until the real image is uploaded;
--                   posters.is_placeholder is the meaningful flag
--   - uploader_id → the admin themselves
--
-- We install BEFORE INSERT defaults + a BEFORE UPDATE sync on title so
-- the admin server actions can drop their manual back-fill code. The
-- Flutter client keeps reading non-null values, so no client coordination
-- is needed.
--
-- Companion ticket in TODOS.md (#1) tracks dropping NOT NULL outright,
-- which is a deeper change and needs Flutter coordination.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create or replace function public.fill_legacy_poster_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- title: never NULL, mirror poster_name when available so reads from
  -- the public client see the curated name even on old code paths that
  -- only know about `title`.
  if new.title is null or new.title = '' then
    new.title := coalesce(new.poster_name, '(待命名)');
  end if;

  -- poster_url: empty string is the documented "no real image yet"
  -- signal. Combined with is_placeholder=true it tells the public client
  -- to render the silhouette.
  if new.poster_url is null then
    new.poster_url := '';
  end if;

  -- uploader_id: fall back to the calling user (auth.uid()). If
  -- unavailable (rare; only happens during seed scripts), let the row
  -- fail on the existing NOT NULL constraint so we don't silently land
  -- a NULL.
  if new.uploader_id is null then
    new.uploader_id := auth.uid();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_fill_legacy_poster_defaults on public.posters;
create trigger trg_fill_legacy_poster_defaults
  before insert on public.posters
  for each row
  execute function public.fill_legacy_poster_defaults();

-- Keep title in lock-step when poster_name changes. We treat
-- poster_name as the canonical name and patch title to match; this
-- avoids "rename poster but the public client still shows the old
-- title" bugs.
create or replace function public.sync_poster_title_from_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.poster_name is distinct from old.poster_name then
    new.title := coalesce(new.poster_name, old.title, '(待命名)');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_poster_title_from_name on public.posters;
create trigger trg_sync_poster_title_from_name
  before update of poster_name on public.posters
  for each row
  execute function public.sync_poster_title_from_name();

commit;
