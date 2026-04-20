-- ═══════════════════════════════════════════════════════════════════════════
-- Layer A cleanup: structured-category closure + synonym normaliser + legacy re-categorise
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ─── A0: 刪除使用者誤加的「戰爭」「懸疑」建議 ─────────────────────────────
delete from public.tag_suggestions
where suggested_label_zh in ('戰爭', '懸疑')
  and status = 'pending';

-- ─── A2: 標記結構化 category 為關閉建議 ──────────────────────────────────
-- 這 5 個 category 的 canonical 列表已經夠全面，開放建議只會產生雜訊。
-- (年代靠年份推導；國別靠 region enum；規格靠物理尺寸標準；版本/收藏狀態
-- 都是業界標準 enum。)
update public.tag_categories
set allows_suggestion = false
where slug in ('era', 'country', 'edition', 'provenance', 'chirashi_type');

-- 規格 (size) 沒有獨立 tag_category — 它是 poster 欄位的 enum，本來就不在
-- tag 系統裡。跳過。

-- ─── A3: 同義詞表 ────────────────────────────────────────────────────────
-- 使用者端常見的別寫 / 口語 → canonical tag。送出時 submit_tag_suggestion
-- 先查這張表，命中就直接走 auto-merge。
create table if not exists public.tag_synonyms (
  id uuid primary key default gen_random_uuid(),
  input_label text not null,                    -- 小寫、去空白
  category_id uuid not null references public.tag_categories(id) on delete cascade,
  target_tag_id uuid not null references public.tags(id) on delete cascade,
  added_by uuid references public.users(id),
  created_at timestamptz default now(),
  unique (input_label, category_id)
);

create index if not exists idx_tag_synonyms_lookup
  on public.tag_synonyms (input_label, category_id);

alter table public.tag_synonyms enable row level security;
create policy tag_synonyms_read_all on public.tag_synonyms
  for select using (true);
create policy tag_synonyms_admin_write on public.tag_synonyms
  for all using (public.is_admin()) with check (public.is_admin());

-- Seed 常見同義詞
-- 類型: 語意接近的別寫
insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select '戰爭', c.id, t.id
  from public.tag_categories c, public.tags t
  where c.slug = 'genre' and t.slug = 'genre-action'
on conflict do nothing;

insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select '懸疑', c.id, t.id
  from public.tag_categories c, public.tags t
  where c.slug = 'genre' and t.slug = 'genre-thriller'
on conflict do nothing;

-- 年代: 口語 → decade
insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select s, c.id, t.id
from public.tag_categories c, public.tags t,
     (values ('當代'), ('現代'), ('近代')) v(s)
where c.slug = 'era' and t.slug = 'era-2020s'
on conflict do nothing;

insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select s, c.id, t.id
from public.tag_categories c, public.tags t,
     (values ('復古'), ('老派')) v(s)
where c.slug = 'aesthetic' and t.slug = 'aes-retro'
on conflict do nothing;

-- 編輯精選: 常見別寫
insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select s, c.id, t.id
from public.tag_categories c, public.tags t,
     (values ('得獎'), ('獎項')) v(s)
where c.slug = 'curation' and t.slug = 'curation-award'
on conflict do nothing;

insert into public.tag_synonyms (input_label, category_id, target_tag_id)
select '老片', c.id, t.id
  from public.tag_categories c, public.tags t
  where c.slug = 'curation' and t.slug = 'curation-classic'
on conflict do nothing;

-- ─── A4: 年份→年代對應 helper function ───────────────────────────────────
create or replace function public.normalise_year_to_era_tag(p_label text)
returns uuid
language plpgsql
immutable
as $$
declare
  v_year int;
  v_decade int;
  v_slug text;
begin
  -- 1987 / 2024 / "1980年" / "2010s" / "90年代" …
  v_year := nullif(substring(p_label from '(\d{4})')::text, '')::int;
  if v_year is null then
    -- 兩位數解釋：90 → 1990, 10 → 2010（僅限 0-29 or 50-99）
    v_year := nullif(substring(p_label from '(\d{2})')::text, '')::int;
    if v_year is null then return null; end if;
    if v_year between 0 and 29 then v_year := 2000 + v_year;
    elsif v_year between 30 and 99 then v_year := 1900 + v_year;
    else return null;
    end if;
  end if;

  if v_year < 1900 or v_year > 2099 then return null; end if;

  v_decade := (v_year / 10) * 10;
  v_slug := 'era-' || v_decade::text || 's';

  return (select id from public.tags where slug = v_slug limit 1);
end $$;

-- ─── A3+A4 整合：升級 submit_tag_suggestion ──────────────────────────────
-- 新流程（從上游到下游）：
--   1. 檢查 category 是否關閉建議 → raise
--   2. 年份 regex → era tag 直接 auto-merge
--   3. 同義詞表命中 → auto-merge
--   4. Similarity ≥ 0.95 → auto-merge（既有）
--   5. 進 pending queue

create or replace function public.submit_tag_suggestion(
  p_category_id uuid,
  p_label_zh text,
  p_label_en text default null,
  p_reason text default null,
  p_linked_submission_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  top_tag record;
  new_suggestion_id uuid;
  v_poster_id uuid;
  v_label_zh text;
  v_label_lower text;
  v_category record;
  v_auto_target uuid;
  v_auto_label text;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'auth required to suggest a tag';
  end if;

  v_label_zh := trim(p_label_zh);
  if v_label_zh = '' then
    raise exception 'label_zh required';
  end if;
  v_label_lower := lower(v_label_zh);

  -- A2: 關閉建議的 category 直接拒絕
  select * into v_category from public.tag_categories where id = p_category_id;
  if not v_category.allows_suggestion then
    raise exception 'category_closed_for_suggestion: % 目前不開放使用者建議新分類', v_category.title_zh;
  end if;

  -- A4: 年份正規化（只對 era category 觸發；其他 category 不做）
  if v_category.slug = 'era' then
    v_auto_target := public.normalise_year_to_era_tag(v_label_zh);
    if v_auto_target is not null then
      select label_zh into v_auto_label from public.tags where id = v_auto_target;
      -- 加 label 為別名
      update public.tags
      set aliases = array(select distinct unnest(coalesce(aliases, '{}') || array[v_label_zh]))
      where id = v_auto_target;
      -- Attach 到 linked submission
      if p_linked_submission_id is not null then
        select created_poster_id into v_poster_id from public.submissions where id = p_linked_submission_id;
        if v_poster_id is not null then
          insert into public.poster_tags (poster_id, tag_id, added_by)
          values (v_poster_id, v_auto_target, uid)
          on conflict do nothing;
        end if;
      end if;
      return jsonb_build_object(
        'auto_merged', true,
        'tag_id', v_auto_target,
        'tag_label_zh', v_auto_label,
        'similarity', 1.0,
        'reason', 'year_normalised'
      );
    end if;
  end if;

  -- A3: 同義詞表
  select target_tag_id into v_auto_target
  from public.tag_synonyms
  where input_label = v_label_lower
    and category_id = p_category_id
  limit 1;

  if v_auto_target is not null then
    select label_zh into v_auto_label from public.tags where id = v_auto_target;
    update public.tags
    set aliases = array(select distinct unnest(coalesce(aliases, '{}') || array[v_label_zh]))
    where id = v_auto_target;
    if p_linked_submission_id is not null then
      select created_poster_id into v_poster_id from public.submissions where id = p_linked_submission_id;
      if v_poster_id is not null then
        insert into public.poster_tags (poster_id, tag_id, added_by)
        values (v_poster_id, v_auto_target, uid)
        on conflict do nothing;
      end if;
    end if;
    return jsonb_build_object(
      'auto_merged', true,
      'tag_id', v_auto_target,
      'tag_label_zh', v_auto_label,
      'similarity', 1.0,
      'reason', 'synonym_matched'
    );
  end if;

  -- Similarity ≥ 0.95
  select tag_id, slug, label_zh, similarity
    into top_tag
  from public.find_similar_tags(p_category_id, v_label_zh, 1, false);

  if top_tag.tag_id is not null and top_tag.similarity >= 0.95 then
    update public.tags
    set aliases = array(
      select distinct unnest(
        coalesce(aliases, '{}') || array[v_label_zh] ||
        case when p_label_en is not null and trim(p_label_en) != ''
              and trim(p_label_en) != v_label_zh
             then array[trim(p_label_en)]
             else array[]::text[]
        end
      )
    )
    where id = top_tag.tag_id;

    if p_linked_submission_id is not null then
      select created_poster_id into v_poster_id from public.submissions where id = p_linked_submission_id;
      if v_poster_id is not null then
        insert into public.poster_tags (poster_id, tag_id, added_by)
        values (v_poster_id, top_tag.tag_id, uid)
        on conflict do nothing;
      end if;
    end if;

    return jsonb_build_object(
      'auto_merged', true,
      'tag_id', top_tag.tag_id,
      'tag_label_zh', top_tag.label_zh,
      'similarity', top_tag.similarity,
      'reason', 'similarity_merge'
    );
  end if;

  -- 真的是新建議 → 進 queue
  insert into public.tag_suggestions
    (suggested_by, suggested_label_zh, suggested_label_en,
     category_id, reason, linked_submission_id, status)
  values
    (uid, v_label_zh,
     case when p_label_en is null or trim(p_label_en) = '' then null else trim(p_label_en) end,
     p_category_id, p_reason, p_linked_submission_id, 'pending')
  returning id into new_suggestion_id;

  return jsonb_build_object(
    'auto_merged', false,
    'suggestion_id', new_suggestion_id
  );
end $$;

grant execute on function public.submit_tag_suggestion(uuid, text, text, text, uuid) to authenticated;

-- ─── A1: change_suggestion_category RPC ──────────────────────────────────
-- Admin 可以改 pending suggestion 的 category（修 legacy migration 的盲點）
create or replace function public.change_suggestion_category(
  p_suggestion_id uuid,
  p_new_category_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden: admin only';
  end if;

  update public.tag_suggestions
  set category_id = p_new_category_id
  where id = p_suggestion_id
    and status = 'pending';

  if not found then
    raise exception 'suggestion not found or not pending';
  end if;
end $$;

grant execute on function public.change_suggestion_category(uuid, uuid) to authenticated;

-- ─── A5: 把 legacy 遺留的 curation 建議重新分派到合理 category ─────────
-- 規則：
--   - 年份/十進位 → 年代
--   - 「版」結尾（非「正版」） → 國別（但國別現在關閉建議，所以要走 merge）
--     → 先留在 curation 讓 admin 決定
--   - genre keyword → 類型
do $$
declare
  r record;
  v_new_cat uuid;
begin
  -- 類型 keywords
  for r in
    select ts.id, ts.suggested_label_zh
    from public.tag_suggestions ts
    join public.tag_categories c on c.id = ts.category_id
    where c.slug = 'curation' and ts.status = 'pending'
      and ts.suggested_label_zh in ('動作', '犯罪', '恐怖', '科幻', '動畫', '紀錄片', '歌舞', '武俠', '愛情', '喜劇', '驚悚', '實驗電影', '奇幻', '劇情')
  loop
    select id into v_new_cat from public.tag_categories where slug = 'genre';
    update public.tag_suggestions set category_id = v_new_cat where id = r.id;
  end loop;

  -- 年代 keywords（會被 admin 之後 approve 時自動走 year normaliser）
  for r in
    select ts.id, ts.suggested_label_zh
    from public.tag_suggestions ts
    join public.tag_categories c on c.id = ts.category_id
    where c.slug = 'curation' and ts.status = 'pending'
      and (ts.suggested_label_zh ~ '\d{2,4}'
           or ts.suggested_label_zh in ('當代', '現代', '近代', '老片', '復古'))
  loop
    select id into v_new_cat from public.tag_categories where slug = 'era';
    update public.tag_suggestions set category_id = v_new_cat where id = r.id;
  end loop;

  -- 國別 keywords（「X版」格式）
  for r in
    select ts.id, ts.suggested_label_zh
    from public.tag_suggestions ts
    join public.tag_categories c on c.id = ts.category_id
    where c.slug = 'curation' and ts.status = 'pending'
      and (ts.suggested_label_zh ~ '版$'
           or ts.suggested_label_zh in ('歐美', '亞洲', '韓星'))
  loop
    select id into v_new_cat from public.tag_categories where slug = 'country';
    update public.tag_suggestions set category_id = v_new_cat where id = r.id;
  end loop;
end $$;

commit;
