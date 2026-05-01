-- ═══════════════════════════════════════════════════════════════════════════
-- Wave 3: 海報售價 + 套票組合（poster_sets）
--
-- 對應合夥人 2026-05-02 spec：
--   #13 海報發行售價：贈品 / 金額  →  posters.price_type + posters.price_amount
--   #14 海報發行組合（連結組合資訊）→  poster_sets table + posters.set_id FK
--
-- 設計取捨：
--   - price_currency 暫不加，主場台灣，預設 TWD（admin 確認的決策）
--   - 套票走完整版：poster_sets 是獨立物件，可以個別命名 / 加封面 /
--     之後管理頁列出底下幾張海報。posters.set_id 可空（不是套票就 NULL）
--   - submissions 鏡像同樣三個欄位（user 提交也能標）
--   - approve_submission RPC 一併抄
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. price_type enum ──────────────────────────────────────────────
do $$ begin
  create type public.price_type_enum as enum ('gift', 'paid');
exception when duplicate_object then null;
end $$;

-- ─── 2. poster_sets table ────────────────────────────────────────────
-- A "套票" — N posters released together as a bundle. Independent of
-- works/groups: a set can span multiple works (collab campaigns), and a
-- single work can have multiple sets across different release waves.
create table if not exists public.poster_sets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  cover_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

-- Per-table updated_at trigger (mirrors the poster_groups pattern from
-- 20260424120000 — codebase doesn't have a generic set_updated_at()).
create or replace function public.set_poster_sets_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_poster_sets_updated_at on public.poster_sets;
create trigger trg_poster_sets_updated_at
  before update on public.poster_sets
  for each row execute function public.set_poster_sets_updated_at();

create index if not exists idx_poster_sets_name on public.poster_sets(name);

alter table public.poster_sets enable row level security;

-- Public read (Flutter app surfaces sets in poster detail), admin all.
create policy poster_sets_read_all on public.poster_sets
  for select using (true);
create policy poster_sets_admin_all on public.poster_sets
  for all using (public.is_admin())
  with check (public.is_admin());

-- ─── 3. posters: add price_type / price_amount / set_id ──────────────
alter table public.posters
  add column if not exists price_type   public.price_type_enum,
  add column if not exists price_amount numeric,
  add column if not exists set_id       uuid references public.poster_sets(id) on delete set null;

-- price sanity: amount only meaningful when type='paid'. Don't enforce
-- via CHECK (admin might want partial info during bulk import); UI gates.
create index if not exists idx_posters_set_id
  on public.posters(set_id) where set_id is not null;

-- ─── 4. submissions: mirror the same three columns ───────────────────
alter table public.submissions
  add column if not exists price_type   public.price_type_enum,
  add column if not exists price_amount numeric,
  add column if not exists set_id       uuid references public.poster_sets(id) on delete set null;

-- ─── 5. approve_submission RPC: copy the new columns ────────────────
-- Mirrors the previous shape from 20260501100000 (which already added
-- promo_image_url / promo_thumbnail_url to the same RPC).
create or replace function public.approve_submission(
  p_submission_id uuid,
  p_work_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  sub record;
  v_work_id uuid;
  v_poster_id uuid;
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  select * into sub
    from public.submissions
    where id = p_submission_id
    for update;

  if not found then
    raise exception 'submission not found';
  end if;
  if sub.status != 'pending' then
    raise exception 'submission already reviewed';
  end if;

  if p_work_id is not null then
    v_work_id := p_work_id;
  else
    insert into public.works
      (title_zh, title_en, movie_release_year, work_kind)
    values
      (sub.work_title_zh, sub.work_title_en, sub.movie_release_year,
       coalesce(sub.work_kind, 'movie'))
    returning id into v_work_id;
  end if;

  insert into public.posters (
    work_id, work_kind, title, poster_name, region, year,
    poster_release_date, poster_release_type, size_type,
    channel_category, channel_type, channel_name,
    is_exclusive, exclusive_name, material_type, version_label,
    poster_url, thumbnail_url, image_size_bytes,
    promo_image_url, promo_thumbnail_url,
    price_type, price_amount, set_id,
    source_url, source_platform, source_note,
    uploader_id, status, source, reviewer_id, reviewed_at, approved_at, tags
  ) values (
    v_work_id, coalesce(sub.work_kind, 'movie'),
    sub.work_title_zh, sub.poster_name, sub.region, sub.movie_release_year,
    sub.poster_release_date, sub.poster_release_type, sub.size_type,
    sub.channel_category, sub.channel_type, sub.channel_name,
    sub.is_exclusive, sub.exclusive_name, sub.material_type, sub.version_label,
    sub.image_url, sub.thumbnail_url, sub.image_size_bytes,
    sub.promo_image_url, sub.promo_thumbnail_url,
    sub.price_type, sub.price_amount, sub.set_id,
    sub.source_url, sub.source_platform, sub.source_note,
    sub.uploader_id, 'approved', 'submission', auth.uid(), now(), now(), '{}'
  )
  returning id into v_poster_id;

  update public.submissions
     set status = 'approved',
         reviewer_id = auth.uid(),
         reviewed_at = now(),
         matched_work_id = v_work_id,
         created_poster_id = v_poster_id
   where id = p_submission_id;

  insert into public.admin_audit_log (
    actor_id, action, target_kind, target_id, payload
  ) values (
    auth.uid(), 'approve_submission', 'submissions', p_submission_id,
    jsonb_build_object('work_id', v_work_id, 'poster_id', v_poster_id)
  );

  return v_poster_id;
end;
$$;

grant execute on function public.approve_submission(uuid, uuid) to authenticated;

commit;
