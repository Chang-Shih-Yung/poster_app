-- ═══════════════════════════════════════════════════════════════════════════
-- Admin destructive-action audit log
--
-- Captures every mutation that goes through `app/actions/*` so we have a
-- "who deleted that studio yesterday" trail. Writes happen via the admin
-- helper `logAudit()` (see app/actions/_internal.ts) which the existing
-- `requireAdmin` flow already has the user identity for.
--
-- Scope: admin actions only. Public submissions go through their own
-- moderation pipeline and don't need this log.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid references auth.users(id) on delete set null,
  admin_email text,
  -- e.g. "rename_work", "delete_studio", "attach_image"
  action text not null,
  -- "work" | "poster" | "group" | "studio" | "image"
  target_kind text not null,
  -- Free text so we can store either a uuid or a synthetic id like the
  -- studio string. JSON stringified for non-uuid kinds.
  target_id text,
  -- Optional snapshot of the row before the change, plus any extra
  -- payload from the action (e.g. the new name, the deleted thumbnail
  -- url). Searchable via JSONB operators when investigating.
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_audit_log_created_at
  on public.admin_audit_log (created_at desc);

create index if not exists idx_admin_audit_log_target
  on public.admin_audit_log (target_kind, target_id);

create index if not exists idx_admin_audit_log_admin
  on public.admin_audit_log (admin_user_id, created_at desc);

-- RLS: admins can read; everyone can write (the action layer is the
-- gate, but RLS still enforces "must be authenticated"). We intentionally
-- never expose this table to the public Flutter client — service-role
-- writes bypass RLS, but we want the layered defense anyway.
alter table public.admin_audit_log enable row level security;

drop policy if exists "admin can read audit log" on public.admin_audit_log;
create policy "admin can read audit log"
  on public.admin_audit_log
  for select
  to authenticated
  using (
    -- Only the admin themselves OR a row matched to their email can be
    -- read. In practice the admin server actions read service-side, so
    -- this policy is mostly a safety net.
    auth.uid() = admin_user_id
  );

drop policy if exists "authenticated can insert audit log" on public.admin_audit_log;
create policy "authenticated can insert audit log"
  on public.admin_audit_log
  for insert
  to authenticated
  with check (auth.uid() = admin_user_id);

commit;
