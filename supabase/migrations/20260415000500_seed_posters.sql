-- Phase 2: seed 40 approved posters (one-time data migration).
-- Migrations only run once per environment, so no re-run guard needed.
-- Creates a synthetic "seed" auth user and 40 approved posters.

begin;

create extension if not exists pgcrypto;

-- Seed user (fixed UUID)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'seed@local.test',
  extensions.crypt('seed-password-not-real', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Seed Bot"}'::jsonb,
  now(), now()
)
on conflict (id) do nothing;

-- Make sure the public.users row exists (the handle_new_user trigger should have created it).
insert into public.users (id, display_name, role)
values ('00000000-0000-0000-0000-000000000001', 'Seed Bot', 'owner')
on conflict (id) do update set role = 'owner';

-- 40 posters, mixed years/directors/tags. Images via picsum.photos (2:3 aspect).
insert into public.posters (
  title, year, director, tags, poster_url, thumbnail_url,
  uploader_id, status, approved_at, view_count
)
values
  ('銀翼殺手 2049', 2017, 'Denis Villeneuve', array['科幻','懸疑'], 'https://picsum.photos/id/1011/600/900', 'https://picsum.photos/id/1011/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '2 days', 1820),
  ('沙丘', 2021, 'Denis Villeneuve', array['科幻','史詩'], 'https://picsum.photos/id/1012/600/900', 'https://picsum.photos/id/1012/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '3 days', 2150),
  ('沙丘：第二部', 2024, 'Denis Villeneuve', array['科幻','史詩'], 'https://picsum.photos/id/1013/600/900', 'https://picsum.photos/id/1013/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '1 day', 3200),
  ('異星入境', 2016, 'Denis Villeneuve', array['科幻','劇情'], 'https://picsum.photos/id/1014/600/900', 'https://picsum.photos/id/1014/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '12 days', 540),
  ('全面啟動', 2010, 'Christopher Nolan', array['科幻','動作','懸疑'], 'https://picsum.photos/id/1015/600/900', 'https://picsum.photos/id/1015/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '5 days', 2890),
  ('星際效應', 2014, 'Christopher Nolan', array['科幻','劇情'], 'https://picsum.photos/id/1016/600/900', 'https://picsum.photos/id/1016/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '7 days', 2450),
  ('敦克爾克大行動', 2017, 'Christopher Nolan', array['戰爭','歷史'], 'https://picsum.photos/id/1018/600/900', 'https://picsum.photos/id/1018/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '25 days', 220),
  ('奧本海默', 2023, 'Christopher Nolan', array['傳記','歷史','劇情'], 'https://picsum.photos/id/1019/600/900', 'https://picsum.photos/id/1019/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '4 days', 3410),
  ('黑暗騎士', 2008, 'Christopher Nolan', array['動作','犯罪'], 'https://picsum.photos/id/1020/600/900', 'https://picsum.photos/id/1020/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '40 days', 180),
  ('記憶拼圖', 2000, 'Christopher Nolan', array['懸疑','劇情'], 'https://picsum.photos/id/1021/600/900', 'https://picsum.photos/id/1021/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '60 days', 95),
  ('寄生上流', 2019, 'Bong Joon-ho', array['劇情','驚悚'], 'https://picsum.photos/id/1022/600/900', 'https://picsum.photos/id/1022/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '6 days', 2710),
  ('駭人怪物', 2006, 'Bong Joon-ho', array['科幻','驚悚'], 'https://picsum.photos/id/1023/600/900', 'https://picsum.photos/id/1023/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '50 days', 110),
  ('末日列車', 2013, 'Bong Joon-ho', array['科幻','動作'], 'https://picsum.photos/id/1024/600/900', 'https://picsum.photos/id/1024/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '9 days', 1180),
  ('惡之地', 1973, 'Terrence Malick', array['犯罪','劇情'], 'https://picsum.photos/id/1025/600/900', 'https://picsum.photos/id/1025/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '80 days', 42),
  ('天堂之日', 1978, 'Terrence Malick', array['劇情','愛情'], 'https://picsum.photos/id/1026/600/900', 'https://picsum.photos/id/1026/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '90 days', 38),
  ('紅色警戒', 1998, 'Terrence Malick', array['戰爭','劇情'], 'https://picsum.photos/id/1027/600/900', 'https://picsum.photos/id/1027/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '70 days', 55),
  ('生命之樹', 2011, 'Terrence Malick', array['劇情','家庭'], 'https://picsum.photos/id/1028/600/900', 'https://picsum.photos/id/1028/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '11 days', 680),
  ('花樣年華', 2000, 'Wong Kar-wai', array['愛情','劇情'], 'https://picsum.photos/id/1029/600/900', 'https://picsum.photos/id/1029/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '20 days', 420),
  ('重慶森林', 1994, 'Wong Kar-wai', array['愛情','劇情'], 'https://picsum.photos/id/1031/600/900', 'https://picsum.photos/id/1031/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '100 days', 28),
  ('春光乍洩', 1997, 'Wong Kar-wai', array['愛情','劇情'], 'https://picsum.photos/id/1032/600/900', 'https://picsum.photos/id/1032/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '8 days', 1340),
  ('墮落天使', 1995, 'Wong Kar-wai', array['犯罪','愛情'], 'https://picsum.photos/id/1033/600/900', 'https://picsum.photos/id/1033/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '35 days', 165),
  ('千禧曼波', 2001, 'Hou Hsiao-hsien', array['劇情'], 'https://picsum.photos/id/1035/600/900', 'https://picsum.photos/id/1035/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '55 days', 72),
  ('刺客聶隱娘', 2015, 'Hou Hsiao-hsien', array['武俠','劇情'], 'https://picsum.photos/id/1036/600/900', 'https://picsum.photos/id/1036/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '13 days', 890),
  ('悲情城市', 1989, 'Hou Hsiao-hsien', array['劇情','歷史'], 'https://picsum.photos/id/1037/600/900', 'https://picsum.photos/id/1037/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '120 days', 20),
  ('牯嶺街少年殺人事件', 1991, 'Edward Yang', array['劇情','犯罪'], 'https://picsum.photos/id/1038/600/900', 'https://picsum.photos/id/1038/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '110 days', 33),
  ('一一', 2000, 'Edward Yang', array['劇情','家庭'], 'https://picsum.photos/id/1039/600/900', 'https://picsum.photos/id/1039/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '18 days', 510),
  ('神隱少女', 2001, 'Hayao Miyazaki', array['動畫','奇幻'], 'https://picsum.photos/id/1040/600/900', 'https://picsum.photos/id/1040/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '2 days', 4200),
  ('龍貓', 1988, 'Hayao Miyazaki', array['動畫','家庭'], 'https://picsum.photos/id/1041/600/900', 'https://picsum.photos/id/1041/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '10 days', 1990),
  ('風之谷', 1984, 'Hayao Miyazaki', array['動畫','科幻'], 'https://picsum.photos/id/1042/600/900', 'https://picsum.photos/id/1042/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '75 days', 88),
  ('霍爾的移動城堡', 2004, 'Hayao Miyazaki', array['動畫','奇幻'], 'https://picsum.photos/id/1043/600/900', 'https://picsum.photos/id/1043/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '14 days', 1230),
  ('天氣之子', 2019, 'Makoto Shinkai', array['動畫','愛情'], 'https://picsum.photos/id/1044/600/900', 'https://picsum.photos/id/1044/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '16 days', 980),
  ('你的名字', 2016, 'Makoto Shinkai', array['動畫','愛情'], 'https://picsum.photos/id/1045/600/900', 'https://picsum.photos/id/1045/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '5 days', 2660),
  ('鈴芽之旅', 2022, 'Makoto Shinkai', array['動畫','奇幻'], 'https://picsum.photos/id/1047/600/900', 'https://picsum.photos/id/1047/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '7 days', 2030),
  ('華爾街之狼', 2013, 'Martin Scorsese', array['犯罪','傳記'], 'https://picsum.photos/id/1048/600/900', 'https://picsum.photos/id/1048/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '22 days', 390),
  ('愛爾蘭人', 2019, 'Martin Scorsese', array['犯罪','劇情'], 'https://picsum.photos/id/1049/600/900', 'https://picsum.photos/id/1049/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '45 days', 140),
  ('計程車司機', 1976, 'Martin Scorsese', array['犯罪','劇情'], 'https://picsum.photos/id/1050/600/900', 'https://picsum.photos/id/1050/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '150 days', 15),
  ('四海好傢伙', 1990, 'Martin Scorsese', array['犯罪','傳記'], 'https://picsum.photos/id/1051/600/900', 'https://picsum.photos/id/1051/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '95 days', 41),
  ('雨果的冒險', 2011, 'Martin Scorsese', array['冒險','家庭'], 'https://picsum.photos/id/1052/600/900', 'https://picsum.photos/id/1052/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '28 days', 260),
  ('花束般的戀愛', 2021, 'Nobuhiro Doi', array['愛情','劇情'], 'https://picsum.photos/id/1053/600/900', 'https://picsum.photos/id/1053/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '3 days', 2890),
  ('小偷家族', 2018, 'Hirokazu Kore-eda', array['劇情','家庭'], 'https://picsum.photos/id/1054/600/900', 'https://picsum.photos/id/1054/300/450', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '6 days', 2120);

commit;
