-- ═══════════════════════════════════════════════════════════════════════════
-- 海報發行資訊（spec #18）改多張：建 poster_promo_images 子表
--
-- 原本 posters.promo_image_url + promo_thumbnail_url 只能放一張。合夥人說
-- 要能上傳多張（影院 DM、IG 活動圖、票券優惠等同時收）。改成 1:N 子表：
--
--   poster_promo_images
--     id              uuid pk
--     poster_id       uuid fk → posters.id ON DELETE CASCADE
--     image_url       text not null    （Supabase Storage public URL）
--     thumbnail_url   text not null
--     sort_order      int not null     （admin 拖移排序，預設追加在尾）
--     created_at      timestamptz
--
-- posters.promo_image_url / promo_thumbnail_url 暫不刪 — Flutter 端跟之前
-- 的 admin 程式碼還可能讀，當 read-only 殘留欄位。新表的第一張會在 admin
-- read 時當「主要圖」，舊欄位後續 sweep。
--
-- Backfill：所有現有 posters.promo_image_url not null 的 row → insert 一
-- 筆對應子表（sort_order = 0）。這樣 UI 切過去後資料無縫。
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create table if not exists public.poster_promo_images (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references public.posters(id) on delete cascade,
  image_url text not null,
  thumbnail_url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_poster_promo_images_poster
  on public.poster_promo_images(poster_id, sort_order);

alter table public.poster_promo_images enable row level security;

-- Public read（Flutter app 顯示宣傳圖），admin 寫。
create policy poster_promo_images_read_all on public.poster_promo_images
  for select using (true);
create policy poster_promo_images_admin_all on public.poster_promo_images
  for all using (public.is_admin())
  with check (public.is_admin());

-- Backfill：原本 single column 的資料搬一筆進新表。
insert into public.poster_promo_images (
  poster_id, image_url, thumbnail_url, sort_order
)
select
  p.id,
  p.promo_image_url,
  coalesce(p.promo_thumbnail_url, p.promo_image_url),
  0
from public.posters p
where p.promo_image_url is not null
  and not exists (
    select 1 from public.poster_promo_images x
    where x.poster_id = p.id
  );

-- Tell PostgREST to refresh schema cache so new table is visible
-- immediately (otherwise first request may PGRST204).
notify pgrst, 'reload schema';

commit;
