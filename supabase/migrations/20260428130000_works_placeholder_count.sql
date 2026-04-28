-- ═══════════════════════════════════════════════════════════════════════════
-- works.placeholder_count auto-maintenance
--
-- Mirrors the pattern of works_poster_count_trigger.sql.
-- Lets the /tree root list show "N 作品 · M 待補圖" per studio without a
-- live aggregate, same way poster_count works.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. Column ──────────────────────────────────────────────────────────
alter table public.works
  add column if not exists placeholder_count int not null default 0;

-- ─── 2. Trigger function ────────────────────────────────────────────────
create or replace function public.refresh_work_placeholder_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  old_placeholder boolean;
  new_placeholder boolean;
  old_alive boolean;
  new_alive boolean;
begin
  if tg_op = 'INSERT' then
    if new.work_id is not null and new.deleted_at is null and new.is_placeholder then
      update public.works
        set placeholder_count = placeholder_count + 1
        where id = new.work_id;
    end if;
    return new;

  elsif tg_op = 'DELETE' then
    if old.work_id is not null and old.deleted_at is null and old.is_placeholder then
      update public.works
        set placeholder_count = greatest(placeholder_count - 1, 0)
        where id = old.work_id;
    end if;
    return old;

  elsif tg_op = 'UPDATE' then
    old_alive        := (old.work_id is not null and old.deleted_at is null);
    new_alive        := (new.work_id is not null and new.deleted_at is null);
    old_placeholder  := old.is_placeholder;
    new_placeholder  := new.is_placeholder;

    if old.work_id is not distinct from new.work_id then
      -- Same work: only fire when alive-status or placeholder-status changes.
      if (old_alive and old_placeholder) and not (new_alive and new_placeholder) then
        update public.works
          set placeholder_count = greatest(placeholder_count - 1, 0)
          where id = old.work_id;
      elsif not (old_alive and old_placeholder) and (new_alive and new_placeholder) then
        update public.works
          set placeholder_count = placeholder_count + 1
          where id = new.work_id;
      end if;
    else
      if old_alive and old_placeholder then
        update public.works
          set placeholder_count = greatest(placeholder_count - 1, 0)
          where id = old.work_id;
      end if;
      if new_alive and new_placeholder then
        update public.works
          set placeholder_count = placeholder_count + 1
          where id = new.work_id;
      end if;
    end if;
    return new;
  end if;
  return null;
end;
$$;

-- ─── 3. Trigger ─────────────────────────────────────────────────────────
drop trigger if exists trg_posters_refresh_placeholder_count on public.posters;
create trigger trg_posters_refresh_placeholder_count
  after insert or update of work_id, deleted_at, is_placeholder or delete
  on public.posters
  for each row
  execute function public.refresh_work_placeholder_count();

-- ─── 4. Backfill ────────────────────────────────────────────────────────
update public.works w
set placeholder_count = coalesce((
  select count(*)::int
  from public.posters p
  where p.work_id = w.id
    and p.deleted_at is null
    and p.is_placeholder = true
), 0);

commit;
