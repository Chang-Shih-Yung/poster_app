-- ═══════════════════════════════════════════════════════════════════════════
-- Wave 4: PREMIUM_FORMATS 加 TITAN_SCREEN + 是否限量欄位
--
-- 1. premium_format_enum 加 'TITAN_SCREEN'（用 ALTER TYPE ADD VALUE，不用
--    重建 enum 也不會 cascade 到 RPC）
-- 2. posters / submissions 加：
--      is_limited        boolean not null default false
--      limited_quantity  integer null   （只有 is_limited=true 時有意義）
-- 3. approve_submission RPC 同步抄這兩欄
--
-- DB 不強制 limited_quantity > 0 / not null when is_limited — admin form
-- 已經 gate；舊 row 全為 false 也合理。
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── 1. premium_format_enum 加 TITAN_SCREEN ─────────────────────────
alter type public.premium_format_enum add value if not exists 'TITAN_SCREEN';

-- ─── 2. posters / submissions 加 is_limited + limited_quantity ──────
alter table public.posters
  add column if not exists is_limited       boolean not null default false,
  add column if not exists limited_quantity integer;

alter table public.submissions
  add column if not exists is_limited       boolean not null default false,
  add column if not exists limited_quantity integer;

-- ─── 3. approve_submission RPC 抄這兩欄 ────────────────────────────
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
    is_limited, limited_quantity,
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
    sub.is_limited, sub.limited_quantity,
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

-- Force PostgREST schema-cache refresh so new columns are queryable
-- immediately（避免 admin 端撞 PGRST204）
notify pgrst, 'reload schema';

commit;
