-- ═══════════════════════════════════════════════════════════════════════════
-- Ghibli sample data import (34 posters across 5 works)
--
-- One-time data load. NOT a schema migration — kept under scripts/seed/ so
-- it doesn't run as part of `supabase db push`. Paste into Supabase Studio's
-- SQL editor and click Run.
--
-- Wrapped in a single DO block so all data + procedural logic share one
-- session. (An earlier version put data in a `create temp table` and the
-- imperative loop in a separate `do $$ ... $$` block — Supabase Studio runs
-- those as different sessions, so the temp table was already gone by the
-- time the loop tried to read from it.)
--
-- Assumes:
--   • The 5 吉卜力 works (龍貓 / 魔法公主 / 神隱少女 / 霍爾的移動城堡 /
--     蒼鷺與少年) already exist with studio="吉卜力" and work_kind='movie'.
--   • The migrations through 20260427160000_sync_posters_work_kind.sql have
--     been applied so posters.work_kind cascades correctly.
--
-- Idempotent: groups are matched by (work_id, parent, name) and posters by
-- (work_id, parent_group_id, poster_name) before insert, so re-running is
-- safe and won't produce duplicates.
--
-- Posters land as placeholders (is_placeholder=true, poster_url=''). Real
-- images get attached later via the admin tree's upload action.
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare
  v_uploader uuid;
  r record;
  v_work_id uuid;
  v_work_kind public.work_kind_enum;
  v_era_id uuid;
  v_variant_id uuid;
  v_inserted int := 0;
  v_skipped  int := 0;
begin
  -- Pick an admin to attribute the rows to. Prefer Henry; fall back to any
  -- user that exists in public.users (uploader_id NOT NULL FK). If neither
  -- exists, abort loudly.
  select u.id into v_uploader
    from public.users u
    join auth.users a on a.id = u.id
   where a.email = 'henry1010921@gmail.com'
   limit 1;
  if v_uploader is null then
    select id into v_uploader from public.users limit 1;
  end if;
  if v_uploader is null then
    raise exception 'cannot find any row in public.users to use as uploader_id';
  end if;

  -- Inline data — first row casts the columns whose values can be NULL on
  -- later rows so PostgreSQL's type inference doesn't reject them.
  for r in
    select * from (values
      -- 龍貓 (5)
      ('吉卜力','龍貓','My Neighbor Totoro','1988 日本首映','正式版','日版主視覺','JP',1988,'theatrical','B1','cinema','東寶'::text,false,null::text,'一般紙'::text,null::text,null::text,'雙特映同場《螢火蟲之墓》'::text),
      ('吉卜力','龍貓','My Neighbor Totoro','1988 日本首映','角色版','龍貓等公車','JP',1988,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','龍貓','My Neighbor Totoro','2008 台灣首映','正式版','台灣正式版','TW',2008,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,'台灣 2008 正式院線'),
      ('吉卜力','龍貓','My Neighbor Totoro','2018 30 週年','日版重映','30 週年紀念日版','JP',2018,'reissue','B2','cinema','東寶',false,null,'霧面紙','30 週年',null,null),
      ('吉卜力','龍貓','My Neighbor Totoro','2018 30 週年','台版重映','30 週年紀念台版','TW',2018,'reissue','B2','cinema',null,false,null,'霧面紙','30 週年',null,null),

      -- 魔法公主 (6)
      ('吉卜力','魔法公主','Princess Mononoke','1997 日本首映','正式版','小桑與山獸神','JP',1997,'theatrical','B1','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','魔法公主','Princess Mononoke','1997 日本首映','角色版','阿席達卡角色版','JP',1997,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','魔法公主','Princess Mononoke','1997 日本首映','teaser','前導預告版','JP',1997,'teaser','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','魔法公主','Princess Mononoke','1999 美國首映','Miramax 英文版','Miramax 英文主視覺','US',1999,'theatrical','custom','cinema','Miramax',false,null,null,null,null,null),
      ('吉卜力','魔法公主','Princess Mononoke','2013 台灣首映','正式版','台灣正式版','TW',2013,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,'首映晚 16 年'),
      ('吉卜力','魔法公主','Princess Mononoke','2023 4K 重映','日版','4K 修復版','JP',2023,'reissue','B2','cinema',null,false,null,'霧面紙','4K 修復',null,null),

      -- 神隱少女 (10)
      ('吉卜力','神隱少女','Spirited Away','2001 日本首映','正式版','千尋穿越隧道版','JP',2001,'theatrical','B1','cinema','東寶',false,null,'一般紙',null,null,'最經典構圖'),
      ('吉卜力','神隱少女','Spirited Away','2001 日本首映','角色版','千尋與白龍','JP',2001,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','神隱少女','Spirited Away','2001 日本首映','角色版','湯婆婆單人版','JP',2001,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','神隱少女','Spirited Away','2001 日本首映','前売券','前売券附贈迷你版','JP',2001,'theatrical','A4','cinema','東寶',false,null,'一般紙','迷你版',null,null),
      ('吉卜力','神隱少女','Spirited Away','2002 台灣首映','正式版','台灣正式版','TW',2002,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,null),
      ('吉卜力','神隱少女','Spirited Away','2014 日本重映','IMAX','IMAX 重映版','JP',2014,'reissue','B2','cinema','IMAX',true,'IMAX 影城','霧面紙','IMAX 版',null,null),
      ('吉卜力','神隱少女','Spirited Away','2017 台灣重映','數位版','台灣數位重映版','TW',2017,'reissue','B2','cinema',null,false,null,'一般紙',null,null,null),
      ('吉卜力','神隱少女','Spirited Away','2026 25 週年','日版','25 週年紀念日版','JP',2026,'reissue','B1','cinema','東寶',false,null,'金箔紙','25 週年',null,'紀念紙材升級'),
      ('吉卜力','神隱少女','Spirited Away','2026 25 週年','台版','25 週年紀念台版','TW',2026,'reissue','B1','cinema',null,false,null,'金箔紙','25 週年',null,null),
      ('吉卜力','神隱少女','Spirited Away','2026 25 週年','台版 IMAX','25 週年 IMAX 威秀獨家','TW',2026,'reissue','B2','cinema','威秀影城',true,'威秀影城','霧面紙','25 週年 IMAX',null,'待編輯者確認是否真有獨家'),

      -- 霍爾的移動城堡 (6)
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2004 日本首映','正式版','蘇菲與哈爾城堡','JP',2004,'theatrical','B1','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2004 日本首映','角色版','哈爾單人版','JP',2004,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2004 日本首映','角色版','蘇菲老年版','JP',2004,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2004 日本首映','角色版','卡西法版','JP',2004,'character','B2','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2005 台灣首映','正式版','台灣正式版','TW',2005,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,null),
      ('吉卜力','霍爾的移動城堡','Howl''s Moving Castle','2019 日本重映','正式版','重映紀念版','JP',2019,'reissue','B2','cinema','東寶',false,null,'霧面紙','重映版',null,null),

      -- 蒼鷺與少年 (7)
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2023 日本首映','teaser','蒼鷺神祕版','JP',2023,'teaser','B1','cinema','東寶',false,null,'一般紙','teaser',null,'刻意保密無劇透'),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2023 日本首映','正式版','正式主視覺','JP',2023,'theatrical','B1','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2023 日本首映','前売券','前売券小冊版','JP',2023,'theatrical','A4','cinema','東寶',false,null,'一般紙',null,null,null),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2024 台灣首映','正式版','台灣正式版','TW',2024,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,null),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2024 台灣首映','IMAX','IMAX 威秀獨家','TW',2024,'theatrical','B2','cinema','威秀影城',true,'威秀影城','霧面紙','IMAX',null,'待編輯者確認是否真有獨家'),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2024 國際版','英文版','英文主視覺','US',2024,'theatrical','custom','cinema','GKIDS',false,null,'一般紙',null,null,null),
      ('吉卜力','蒼鷺與少年','The Boy and the Heron','2024 國際版','韓文版','韓國版','KR',2024,'theatrical','B1','cinema',null,false,null,'一般紙',null,null,null)
    ) as t(studio, work_zh, work_en, era, variant, p_name,
           region, year, rtype, sz, ch_cat, ch_name,
           is_exclusive, exc_of, mat, ver_label, src_url, notes)
  loop
    -- 1. Look up the work (must already exist)
    select id, work_kind into v_work_id, v_work_kind
      from public.works
     where studio = r.studio and title_zh = r.work_zh
     limit 1;
    if v_work_id is null then
      raise notice 'work not found: %/% — skipping poster %', r.studio, r.work_zh, r.p_name;
      v_skipped := v_skipped + 1;
      continue;
    end if;

    -- 2. Backfill title_en if missing
    update public.works
       set title_en = r.work_en
     where id = v_work_id
       and (title_en is null or title_en = '');

    -- 3. Find/create level-1 group (release_era)
    select id into v_era_id
      from public.poster_groups
     where work_id = v_work_id and parent_group_id is null and name = r.era;
    if v_era_id is null then
      insert into public.poster_groups (work_id, parent_group_id, name, group_type)
        values (v_work_id, null, r.era, 'release_era')
        returning id into v_era_id;
    end if;

    -- 4. Find/create level-2 group (variant_group), or fall back to era
    if r.variant is not null and r.variant <> '' then
      select id into v_variant_id
        from public.poster_groups
       where work_id = v_work_id
         and parent_group_id = v_era_id
         and name = r.variant;
      if v_variant_id is null then
        insert into public.poster_groups (work_id, parent_group_id, name, group_type)
          values (v_work_id, v_era_id, r.variant, 'variant')
          returning id into v_variant_id;
      end if;
    else
      v_variant_id := v_era_id;
    end if;

    -- 5. Insert poster (skip if same name already lives under same group)
    if exists (
      select 1 from public.posters
       where work_id = v_work_id
         and parent_group_id = v_variant_id
         and poster_name = r.p_name
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    insert into public.posters (
      work_id, work_kind, parent_group_id,
      title, poster_name,
      region, year,
      poster_release_type, size_type,
      channel_category, channel_name,
      is_exclusive, exclusive_name,
      material_type, version_label,
      source_url, source_note,
      is_placeholder, status, poster_url, uploader_id
    ) values (
      v_work_id, v_work_kind, v_variant_id,
      coalesce(nullif(r.p_name, ''), '(待命名)'), r.p_name,
      r.region::region_enum, r.year,
      r.rtype::release_type_enum, r.sz::size_type_enum,
      r.ch_cat::channel_cat_enum, r.ch_name,
      r.is_exclusive, r.exc_of,
      r.mat, r.ver_label,
      r.src_url, r.notes,
      true, 'approved'::poster_status, '', v_uploader
    );
    v_inserted := v_inserted + 1;
  end loop;

  raise notice 'ghibli import complete: % inserted, % skipped (existing or unmapped)',
    v_inserted, v_skipped;
end $$;
