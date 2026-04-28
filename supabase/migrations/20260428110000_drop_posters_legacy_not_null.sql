-- ═══════════════════════════════════════════════════════════════════════════
-- posters: drop NOT NULL on legacy columns
--
-- 20260428100200 installed a trigger that fills `title`, `poster_url`,
-- `uploader_id` automatically so admin code didn't need to back-fill
-- them. This migration takes the next step: make the columns nullable
-- so NULL becomes a meaningful state again.
--
-- Rationale per column:
--   - title       still sync'd with poster_name via the title trigger;
--                 nullable lets us delete this denormalised column in
--                 a future cleanup without breaking readers.
--   - poster_url  drop the empty-string default. NULL == "no real
--                 image yet"; the is_placeholder flag remains the
--                 canonical signal for the public client.
--   - uploader_id keep the auth.uid() trigger default (admin IS the
--                 uploader for admin-created rows). Nullable lets
--                 anonymous / system inserts succeed without a fake id.
--
-- Coordinated with:
--   - admin/lib/data/models/poster.dart — fields cast as String?
--   - every Flutter call site that reads these fields
-- ═══════════════════════════════════════════════════════════════════════════

begin;

alter table public.posters alter column title drop not null;
alter table public.posters alter column poster_url drop not null;
alter table public.posters alter column uploader_id drop not null;

-- Drop the empty-string default for poster_url. NULL is now the
-- canonical "no real image" signal (alongside is_placeholder=true).
create or replace function public.fill_legacy_poster_defaults()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.title is null or new.title = '' then
    new.title := coalesce(new.poster_name, '(待命名)');
  end if;

  if new.uploader_id is null then
    new.uploader_id := auth.uid();
  end if;

  return new;
end;
$$;

commit;
