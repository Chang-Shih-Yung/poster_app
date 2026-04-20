-- ═══════════════════════════════════════════════════════════════════════════
-- EPIC 18: Tag Taxonomy SEED DATA
-- ═══════════════════════════════════════════════════════════════════════════
-- 10 categories + ~230 canonical tags.
-- Derived from real poster-collecting communities research (r/MoviePosters,
-- Polska Szkoła Plakatu, Japanese chirashi scene, Mondo, Heritage Auctions,
-- eMoviePoster, IMPAwards, 台灣設計圈).
--
-- Each required category has an "其他 Other" fallback tag.
-- Tags have aliases for search (e.g. "Miyazaki" → 宮崎駿).

begin;

-- ═══════════════════════════════════════════════════════════════════════════
-- Categories (10)
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.tag_categories
  (slug, title_zh, title_en, description_zh, position, icon, kind,
   is_required, allow_other, allows_suggestion)
values
  ('country', '國別', 'Country of Issue',
   '海報的印刷市場（不等於電影出品國；波蘭版美國片會標兩個國別）',
   1, 'globe', 'controlled_vocab', true, true, true),

  ('era', '年代', 'Era',
   '海報印製年代或對應的電影文化年代',
   2, 'calendar', 'free_tag', false, true, true),

  ('medium', '媒材 / 技法', 'Medium & Technique',
   '印刷 / 繪畫 / 攝影 / 拼貼等物理製作方式',
   3, 'palette', 'free_tag', false, true, true),

  ('designer', '設計師', 'Designer',
   '海報的設計者或藝術家（有別於電影導演）',
   4, 'pen-tool', 'controlled_vocab', false, true, true),

  ('edition', '版本', 'Edition Type',
   '院線首刷 / 重映 / 限量 / Teaser 等發行版本類型',
   5, 'layers', 'free_tag', false, true, true),

  ('aesthetic', '美學風格', 'Visual Aesthetic',
   '海報本身的視覺設計風格（非電影類型）',
   6, 'sparkles', 'free_tag', false, true, true),

  ('genre', '類型', 'Genre',
   '電影或作品的敘事類型（劇情、恐怖、動畫…）',
   7, 'film', 'free_tag', false, true, true),

  ('provenance', '收藏狀態', 'Condition & Provenance',
   '海報實體狀態（捲筒 / 摺疊 / 裱布 / 簽名）',
   8, 'archive', 'free_tag', false, true, true),

  ('chirashi_type', 'Chirashi 類型', 'Chirashi Type',
   '日本電影宣傳單張（チラシ）專屬分類',
   9, 'scroll', 'free_tag', false, false, true),

  ('curation', '編輯精選', 'Editorial',
   '編輯策展標籤（收藏必備、大師級、獎項加持…）',
   10, 'star', 'controlled_vocab', false, false, true);

-- ═══════════════════════════════════════════════════════════════════════════
-- Helper: inline function to insert tag with category slug lookup
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function _seed_tag(
  p_cat_slug text, p_slug text, p_zh text, p_en text,
  p_aliases text[] default '{}',
  p_is_other boolean default false
) returns void language plpgsql as $$
begin
  insert into public.tags
    (category_id, slug, label_zh, label_en, aliases, is_other_fallback)
  values
    ((select id from public.tag_categories where slug = p_cat_slug),
     p_slug, p_zh, p_en, p_aliases, p_is_other)
  on conflict (slug) do nothing;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. 國別 (country) — 20 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('country', 'country-us',  '美版', 'United States', array['US','America','american']);
select _seed_tag('country', 'country-uk',  '英版', 'United Kingdom', array['UK','Britain','british','uk_quad']);
select _seed_tag('country', 'country-jp',  '日版', 'Japan', array['JP','japanese','日本']);
select _seed_tag('country', 'country-tw',  '台版', 'Taiwan', array['TW','taiwan','taiwanese','台灣']);
select _seed_tag('country', 'country-hk',  '港版', 'Hong Kong', array['HK','hongkong','香港']);
select _seed_tag('country', 'country-cn',  '中國版', 'Mainland China', array['CN','china','中國','大陸']);
select _seed_tag('country', 'country-kr',  '韓版', 'Korea', array['KR','korea','korean','韓國']);
select _seed_tag('country', 'country-fr',  '法版', 'France', array['FR','french','france','grande','法國']);
select _seed_tag('country', 'country-it',  '義版', 'Italy', array['IT','italian','italy','義大利','due_fogli']);
select _seed_tag('country', 'country-de',  '德版', 'Germany', array['DE','german','德國']);
select _seed_tag('country', 'country-pl',  '波蘭版', 'Poland', array['PL','polish','poland','波蘭']);
select _seed_tag('country', 'country-cz',  '捷克版', 'Czech', array['CZ','czech','捷克']);
select _seed_tag('country', 'country-cu',  '古巴版', 'Cuba', array['CU','cuba','cuban','icaic','古巴']);
select _seed_tag('country', 'country-ru',  '蘇聯版', 'USSR / Russia', array['RU','russia','ussr','soviet','蘇聯','俄羅斯']);
select _seed_tag('country', 'country-au',  '澳版', 'Australia', array['AU','australian','daybill','澳洲']);
select _seed_tag('country', 'country-es',  '西版', 'Spain', array['ES','spanish','spain','西班牙']);
select _seed_tag('country', 'country-in',  '印度版', 'India', array['IN','indian','india','bollywood','印度']);
select _seed_tag('country', 'country-th',  '泰版', 'Thailand', array['TH','thai','thailand','泰國']);
select _seed_tag('country', 'country-vn',  '越南版', 'Vietnam', array['VN','vietnam','vietnamese','越南']);
select _seed_tag('country', 'country-tr',  '土耳其版', 'Turkey', array['TR','turkish','turkey','土耳其']);
select _seed_tag('country', 'country-intl','國際版', 'International', array['international','advance','worldwide']);
select _seed_tag('country', 'country-other','其他國別', 'Other Country', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. 年代 (era) — 18 tags (decade + thematic)
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('era', 'era-silent',      '默片時代', 'Silent Era',   array['pre-1930','silent','默片']);
select _seed_tag('era', 'era-golden-age',  '黃金年代', 'Golden Age',   array['1930s','1940s','classical hollywood']);
select _seed_tag('era', 'era-1950s',       '1950年代', '1950s',        array['50s','fifties']);
select _seed_tag('era', 'era-1960s',       '1960年代', '1960s',        array['60s','sixties']);
select _seed_tag('era', 'era-1970s',       '1970年代', '1970s',        array['70s','seventies','new hollywood']);
select _seed_tag('era', 'era-1980s',       '1980年代', '1980s',        array['80s','eighties']);
select _seed_tag('era', 'era-1990s',       '1990年代', '1990s',        array['90s','nineties']);
select _seed_tag('era', 'era-2000s',       '2000年代', '2000s',        array['00s']);
select _seed_tag('era', 'era-2010s',       '2010年代', '2010s',        array['10s']);
select _seed_tag('era', 'era-2020s',       '2020年代', '2020s',        array['20s']);
select _seed_tag('era', 'era-new-hollywood', '新好萊塢時期', 'New Hollywood', array['1967-1980','new hollywood']);
select _seed_tag('era', 'era-hk-golden',   '港片黃金期', 'HK Golden Age', array['1980s-90s hk','hongkong cinema golden']);
select _seed_tag('era', 'era-tw-new-wave', '台灣新電影', 'Taiwan New Wave', array['1982-1990','taiwan new cinema','侯孝賢','楊德昌']);
select _seed_tag('era', 'era-french-new-wave', '法國新浪潮', 'French New Wave', array['nouvelle vague','godard','truffaut']);
select _seed_tag('era', 'era-polish-school','波蘭海報派黃金期','Polish Poster School Golden Age', array['1950s-1980s poland','polska szkola plakatu']);
select _seed_tag('era', 'era-showa',       '昭和年代', 'Shōwa Era',    array['showa','1926-1989','昭和']);
select _seed_tag('era', 'era-heisei',      '平成年代', 'Heisei Era',   array['heisei','1989-2019','平成']);
select _seed_tag('era', 'era-reiwa',       '令和年代', 'Reiwa Era',    array['reiwa','2019-','令和']);
select _seed_tag('era', 'era-other',       '其他年代', 'Other Era',    array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. 媒材 / 技法 (medium) — 17 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('medium', 'medium-offset-litho',   'Offset 印刷', 'Offset Litho', array['offset','offset lithography']);
select _seed_tag('medium', 'medium-stone-litho',    '石版印刷', 'Stone Lithograph', array['stone litho','lithograph']);
select _seed_tag('medium', 'medium-silkscreen',     '絹印', 'Silkscreen', array['screenprint','silkscreen','絹版']);
select _seed_tag('medium', 'medium-giclee',         '微噴藝術輸出', 'Giclée', array['giclee','inkjet fine-art']);
select _seed_tag('medium', 'medium-letterpress',    '活版印刷', 'Letterpress', array['letterpress','活版']);
select _seed_tag('medium', 'medium-woodblock',      '木刻版畫', 'Woodblock', array['woodblock','木刻','木版']);
select _seed_tag('medium', 'medium-hand-painted',   '手繪', 'Hand-Painted', array['painted','hand-painted','手繪']);
select _seed_tag('medium', 'medium-watercolor',     '水彩', 'Watercolor', array['watercolour','aquarelle']);
select _seed_tag('medium', 'medium-ink-wash',       '水墨', 'Ink Wash', array['ink-wash','sumi-e','水墨']);
select _seed_tag('medium', 'medium-oil-painting',   '油畫', 'Oil Painting', array['oil']);
select _seed_tag('medium', 'medium-photo-montage',  '攝影拼貼', 'Photo Montage', array['photo-montage','photomontage']);
select _seed_tag('medium', 'medium-illustration',   '插畫', 'Illustration', array['illustrated','illustration']);
select _seed_tag('medium', 'medium-typographic',    '字體設計', 'Typographic', array['typography','字體']);
select _seed_tag('medium', 'medium-collage',        '拼貼', 'Collage', array['collage','shear']);
select _seed_tag('medium', 'medium-foil',           '燙金 / 金屬墨', 'Foil / Metallic', array['foil','metallic','金箔']);
select _seed_tag('medium', 'medium-embossed',       '壓印凹凸', 'Embossed', array['embossed','凹凸']);
select _seed_tag('medium', 'medium-risograph',      'Risograph 印刷', 'Risograph', array['riso','risograph']);
select _seed_tag('medium', 'medium-digital',        '數位繪圖', 'Digital Art', array['digital','數位']);
select _seed_tag('medium', 'medium-other',          '其他媒材', 'Other Medium', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. 設計師 (designer) — ~40 tags, international + Asian + Taiwan
-- ═══════════════════════════════════════════════════════════════════════════

-- 台灣/華語（不縮限範圍）
select _seed_tag('designer', 'designer-aaron-nieh',    '聶永真', 'Aaron Nieh', array['aaron nieh','nieh','聶永真']);
select _seed_tag('designer', 'designer-wang-zhi-hong', '王志弘', 'Wang Zhi-Hong', array['wang zhi-hong','wang zhihong','王志弘']);
select _seed_tag('designer', 'designer-joe-fang',      '方序中', 'Joe Fang', array['joe fang','fang hsu-chung','方序中']);
select _seed_tag('designer', 'designer-ho-chia-hsing', '何佳興', 'Ho Chia-Hsing', array['ho chia-hsing','何佳興']);
select _seed_tag('designer', 'designer-huang-hai',     '黃海', 'Huang Hai', array['huang hai','黃海','黄海']);
select _seed_tag('designer', 'designer-chih-ho',       '致禾', 'Chih-Ho', array['chih-ho','chihho','致禾']);
select _seed_tag('designer', 'designer-mist-room',     '霧室', 'Mist Room', array['mist room','mistroom','霧室']);
select _seed_tag('designer', 'designer-bito',          'Bito (朱陳毅)', 'Bito', array['bito','朱陳毅','chen-yi chu']);
select _seed_tag('designer', 'designer-chen-shih-chuan','陳世川', 'Chen Shih-Chuan', array['chen shih-chuan','陳世川']);
select _seed_tag('designer', 'designer-sanyeh-pen',    '三頁文設計', 'Sanyeh Pen', array['三頁文','sanyeh pen']);

-- 日本
select _seed_tag('designer', 'designer-tadanori-yokoo','横尾忠則', 'Tadanori Yokoo', array['tadanori yokoo','yokoo','横尾忠則']);
select _seed_tag('designer', 'designer-kiyoshi-awazu', '粟津潔', 'Kiyoshi Awazu', array['kiyoshi awazu','awazu','粟津潔']);
select _seed_tag('designer', 'designer-eiko-ishioka',  '石岡瑛子', 'Eiko Ishioka', array['eiko ishioka','ishioka','石岡瑛子']);

-- 波蘭海報派
select _seed_tag('designer', 'designer-jan-lenica',    'Jan Lenica', 'Jan Lenica', array['jan lenica','lenica']);
select _seed_tag('designer', 'designer-roman-cieslewicz','Roman Cieślewicz', 'Roman Cieślewicz', array['roman cieslewicz','cieslewicz']);
select _seed_tag('designer', 'designer-waldemar-swierzy','Waldemar Świerzy', 'Waldemar Świerzy', array['waldemar swierzy','swierzy']);
select _seed_tag('designer', 'designer-wiktor-gorka',  'Wiktor Górka', 'Wiktor Górka', array['wiktor gorka','gorka']);
select _seed_tag('designer', 'designer-starowieyski', 'Franciszek Starowieyski', 'Franciszek Starowieyski', array['starowieyski']);
select _seed_tag('designer', 'designer-andrzej-pagowski','Andrzej Pągowski', 'Andrzej Pągowski', array['andrzej pagowski','pagowski']);

-- 美國經典
select _seed_tag('designer', 'designer-saul-bass',     'Saul Bass', 'Saul Bass', array['saul bass','bass']);
select _seed_tag('designer', 'designer-drew-struzan',  'Drew Struzan', 'Drew Struzan', array['drew struzan','struzan']);
select _seed_tag('designer', 'designer-reynold-brown', 'Reynold Brown', 'Reynold Brown', array['reynold brown']);
select _seed_tag('designer', 'designer-bob-peak',      'Bob Peak', 'Bob Peak', array['bob peak']);
select _seed_tag('designer', 'designer-bill-gold',     'Bill Gold', 'Bill Gold', array['bill gold']);
select _seed_tag('designer', 'designer-richard-amsel', 'Richard Amsel', 'Richard Amsel', array['richard amsel','amsel']);
select _seed_tag('designer', 'designer-robert-mcginnis','Robert McGinnis', 'Robert McGinnis', array['mcginnis']);
select _seed_tag('designer', 'designer-philip-castle', 'Philip Castle', 'Philip Castle', array['philip castle']);

-- Mondo / 當代版畫
select _seed_tag('designer', 'designer-tyler-stout',   'Tyler Stout', 'Tyler Stout', array['tyler stout','stout']);
select _seed_tag('designer', 'designer-olly-moss',     'Olly Moss', 'Olly Moss', array['olly moss','moss']);
select _seed_tag('designer', 'designer-martin-ansin',  'Martin Ansin', 'Martin Ansin', array['martin ansin','ansin']);
select _seed_tag('designer', 'designer-laurent-durieux','Laurent Durieux', 'Laurent Durieux', array['laurent durieux','durieux']);
select _seed_tag('designer', 'designer-kilian-eng',    'Kilian Eng', 'Kilian Eng', array['kilian eng']);
select _seed_tag('designer', 'designer-jock',          'Jock', 'Jock', array['jock']);
select _seed_tag('designer', 'designer-phantom-city',  'Phantom City Creative', 'Phantom City Creative', array['phantom city']);
select _seed_tag('designer', 'designer-la-boca',       'La Boca', 'La Boca', array['la boca']);

-- 有名工作室 / 集體
select _seed_tag('designer', 'designer-studio-ghibli', '吉卜力工作室', 'Studio Ghibli (team)', array['ghibli','studio ghibli','吉卜力']);

-- 匿名 / 其他
select _seed_tag('designer', 'designer-unknown',       '未知 / 匿名', 'Unknown / Anonymous', array['anonymous','unknown','不明']);
select _seed_tag('designer', 'designer-other',         '其他設計師', 'Other Designer', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. 版本 (edition) — 16 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('edition', 'edition-first-run',       '院線首刷', 'Theatrical First Run', array['first run','首刷','原版']);
select _seed_tag('edition', 'edition-rerelease',       '二刷 / 再版', 'Re-release', array['re-release','重映','二刷']);
select _seed_tag('edition', 'edition-teaser',          'Teaser / 前導', 'Teaser / Advance', array['teaser','advance','前導']);
select _seed_tag('edition', 'edition-international',   '國際版', 'International', array['international','intl']);
select _seed_tag('edition', 'edition-festival',        '影展版', 'Festival', array['cannes','golden horse','tiff','berlinale','影展']);
select _seed_tag('edition', 'edition-character',       '角色版', 'Character Poster', array['character poster','角色版']);
select _seed_tag('edition', 'edition-style-a',         'Style A', 'Style A', array['style a']);
select _seed_tag('edition', 'edition-style-b',         'Style B', 'Style B', array['style b']);
select _seed_tag('edition', 'edition-imax',            'IMAX 版', 'IMAX', array['imax']);
select _seed_tag('edition', 'edition-dolby',           'Dolby 版', 'Dolby', array['dolby']);
select _seed_tag('edition', 'edition-limited',         '限量版', 'Limited Edition', array['limited','限量']);
select _seed_tag('edition', 'edition-artist-proof',    'AP 簽名試版', 'Artist Proof', array['ap','artist proof']);
select _seed_tag('edition', 'edition-printer-proof',   'PP 印刷試版', 'Printer Proof', array['pp','printer proof']);
select _seed_tag('edition', 'edition-variant',         'Variant 變體版', 'Variant', array['variant']);
select _seed_tag('edition', 'edition-timed-release',   'Timed Release（Mondo）', 'Timed Release', array['timed release','mondo timed']);
select _seed_tag('edition', 'edition-unused',          '未採用稿', 'Unused / Rejected', array['unused','rejected concept','未採用']);
select _seed_tag('edition', 'edition-bootleg',         '非官方 / Bootleg', 'Bootleg', array['bootleg','unauthorized','非官方']);
select _seed_tag('edition', 'edition-fan-art',         '同人 / Fan Art', 'Fan Art', array['fan art','fanart','同人']);
select _seed_tag('edition', 'edition-other',           '其他版本', 'Other Edition', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. 美學風格 (aesthetic) — 15 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('aesthetic', 'aes-minimalist',    '極簡', 'Minimalist', array['minimalist','極簡']);
select _seed_tag('aesthetic', 'aes-maximalist',    '繁複插畫', 'Maximalist Illustrated', array['maximalist','illustrated ensemble','繁複']);
select _seed_tag('aesthetic', 'aes-struzan-style', 'Struzan 風寫實彩繪', 'Photo-realist Painted', array['struzan-style','photo-realist']);
select _seed_tag('aesthetic', 'aes-floating-heads','浮頭構圖', 'Floating Heads', array['floating heads','浮頭']);
select _seed_tag('aesthetic', 'aes-big-face',      '大頭特寫', 'Big Face', array['big face','大頭','大頭照']);
select _seed_tag('aesthetic', 'aes-typographic',   '字體主導', 'Typographic-led', array['typographic-led','type-driven']);
select _seed_tag('aesthetic', 'aes-silhouette',    '剪影風', 'Silhouette', array['silhouette','剪影']);
select _seed_tag('aesthetic', 'aes-surreal',       '超現實（波蘭風）', 'Surreal', array['surreal','surrealist','polish surreal']);
select _seed_tag('aesthetic', 'aes-pop-art',       '普普藝術', 'Pop Art', array['pop-art','普普']);
select _seed_tag('aesthetic', 'aes-noir',          '黑色電影風', 'Noir / High-contrast', array['noir','film-noir','黑色']);
select _seed_tag('aesthetic', 'aes-retro',         '復古重製', 'Retro Reissue', array['retro','vintage-reissue','復古']);
select _seed_tag('aesthetic', 'aes-neon-cyber',    '霓虹賽博', 'Neon / Cyber', array['cyberpunk','neon','霓虹']);
select _seed_tag('aesthetic', 'aes-watercolor',    '水彩風', 'Watercolor Style', array['watercolor style']);
select _seed_tag('aesthetic', 'aes-ink-wash',      '水墨風', 'Ink Wash Style', array['ink-wash style','水墨風']);
select _seed_tag('aesthetic', 'aes-riso-feel',     'Riso 感', 'Risograph Feel', array['riso-aesthetic','risograph look']);
select _seed_tag('aesthetic', 'aes-other',         '其他風格', 'Other Aesthetic', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. 類型 (genre) — 14 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('genre', 'genre-drama',      '劇情', 'Drama',          array['drama','劇情']);
select _seed_tag('genre', 'genre-crime',      '犯罪', 'Crime',          array['crime','犯罪']);
select _seed_tag('genre', 'genre-action',     '動作', 'Action',         array['action','動作']);
select _seed_tag('genre', 'genre-horror',     '恐怖', 'Horror',         array['horror','恐怖']);
select _seed_tag('genre', 'genre-sci-fi',     '科幻', 'Sci-Fi',         array['scifi','sci-fi','science-fiction','科幻']);
select _seed_tag('genre', 'genre-animation',  '動畫', 'Animation',      array['animation','animated','動畫']);
select _seed_tag('genre', 'genre-documentary','紀錄片', 'Documentary',  array['documentary','doc','紀錄片']);
select _seed_tag('genre', 'genre-musical',    '歌舞', 'Musical',        array['musical','歌舞']);
select _seed_tag('genre', 'genre-wuxia',      '武俠', 'Wuxia',          array['wuxia','martial arts','武俠']);
select _seed_tag('genre', 'genre-romance',    '愛情', 'Romance',        array['romance','愛情']);
select _seed_tag('genre', 'genre-comedy',     '喜劇', 'Comedy',         array['comedy','喜劇']);
select _seed_tag('genre', 'genre-thriller',   '驚悚', 'Thriller',       array['thriller','驚悚']);
select _seed_tag('genre', 'genre-experimental','實驗電影', 'Experimental', array['experimental','avant-garde','實驗']);
select _seed_tag('genre', 'genre-fantasy',    '奇幻', 'Fantasy',        array['fantasy','奇幻']);
select _seed_tag('genre', 'genre-other',      '其他類型', 'Other Genre', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. 收藏狀態 (provenance / condition) — 12 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('provenance', 'prov-rolled',       '捲筒保存', 'Rolled',      array['rolled','捲筒']);
select _seed_tag('provenance', 'prov-folded',       '摺疊保存', 'Folded',      array['folded','摺疊']);
select _seed_tag('provenance', 'prov-linen-backed', '裱布處理', 'Linen-Backed', array['linen-backed','linen backed','裱布']);
select _seed_tag('provenance', 'prov-paper-backed', '裱紙處理', 'Paper-Backed', array['paper-backed']);
select _seed_tag('provenance', 'prov-restored',     '修復過', 'Restored',      array['restored','restoration','修復']);
select _seed_tag('provenance', 'prov-pinholes',     '有針孔', 'Pinholes',      array['pinholes','針孔']);
select _seed_tag('provenance', 'prov-fading',       '褪色', 'Fading',         array['fading','faded','褪色']);
select _seed_tag('provenance', 'prov-signed',       '親簽版', 'Signed',        array['signed','autographed','親簽']);
select _seed_tag('provenance', 'prov-numbered',     '限量編號', 'Numbered',    array['numbered','limited-numbered','限量編號']);
select _seed_tag('provenance', 'prov-coa',          '附真品證書 COA', 'COA',   array['coa','certificate of authenticity','真品證書']);
select _seed_tag('provenance', 'prov-theater-used', '戲院使用過', 'Theater-used', array['theater-used','used in theater']);
select _seed_tag('provenance', 'prov-studio-issue', '片商原發（NSS）', 'Studio-issue (NSS)', array['nss','studio-issue']);
select _seed_tag('provenance', 'prov-other',        '其他狀態', 'Other Provenance', array[]::text[], true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. Chirashi 類型 (chirashi_type) — 8 tags
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('chirashi_type', 'chirashi-type-a',  'Chirashi Type A', 'Chirashi Type A', array['type a','typeA']);
select _seed_tag('chirashi_type', 'chirashi-type-b',  'Chirashi Type B', 'Chirashi Type B', array['type b','typeB']);
select _seed_tag('chirashi_type', 'chirashi-type-c',  'Chirashi Type C', 'Chirashi Type C', array['type c','typeC']);
select _seed_tag('chirashi_type', 'chirashi-maeuri',  '前売券附 (mae-uri)', 'Mae-uri (pre-sale)', array['前売','mae-uri','maeuri','pre-sale']);
select _seed_tag('chirashi_type', 'chirashi-shisha',  '試写会版', 'Shisha-kai (preview)', array['試写会','shisha-kai','preview screening']);
select _seed_tag('chirashi_type', 'chirashi-both',    '雙面印刷', 'Double-sided', array['双面','両面','double-sided','両面印刷']);
select _seed_tag('chirashi_type', 'chirashi-glossy',  '亮面', 'Glossy', array['glossy','亮面']);
select _seed_tag('chirashi_type', 'chirashi-matte',   '霧面', 'Matte', array['matte','霧面']);

-- ═══════════════════════════════════════════════════════════════════════════
-- 10. 編輯精選 (curation) — 7 tags (migrated from legacy hardcoded sections)
-- ═══════════════════════════════════════════════════════════════════════════

select _seed_tag('curation', 'curation-must-have',     '收藏必備', 'Collector''s Choice', array['must-have','collectors choice','收藏必備']);
select _seed_tag('curation', 'curation-classic',       '經典', 'Classic', array['classic','經典']);
select _seed_tag('curation', 'curation-master',        '大師級', 'Master-level', array['master','大師']);
select _seed_tag('curation', 'curation-award',         '獎項加持', 'Award-winning', array['award','awarded','獎項']);
select _seed_tag('curation', 'curation-rare',          '稀有 / 絕版', 'Rare / Out-of-print', array['rare','oop','絕版','稀有']);
select _seed_tag('curation', 'curation-entry-level',   '入門必收', 'Entry-level Must', array['entry-level','入門']);
select _seed_tag('curation', 'curation-advanced',      '進階收藏', 'Advanced Collection', array['advanced','進階']);

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

drop function _seed_tag(text, text, text, text, text[], boolean);

commit;
