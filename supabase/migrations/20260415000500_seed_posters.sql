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

-- 40 posters, mixed years/directors/tags. Images from TMDB (poster 2:3 aspect).
-- poster_url  = /w500/ (high-res for detail & L mode)
-- thumbnail_url = /w200/ (grid & list thumbs)
insert into public.posters (
  title, year, director, tags, poster_url, thumbnail_url,
  uploader_id, status, approved_at, view_count
)
values
  ('銀翼殺手 2049', 2017, 'Denis Villeneuve', array['科幻','懸疑'], 'https://image.tmdb.org/t/p/w500/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg', 'https://image.tmdb.org/t/p/w200/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '2 days', 1820),
  ('沙丘', 2021, 'Denis Villeneuve', array['科幻','史詩'], 'https://image.tmdb.org/t/p/w500/gDzOcq0pfeCeqMBwKIJlSmQpjkZ.jpg', 'https://image.tmdb.org/t/p/w200/gDzOcq0pfeCeqMBwKIJlSmQpjkZ.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '3 days', 2150),
  ('沙丘：第二部', 2024, 'Denis Villeneuve', array['科幻','史詩'], 'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', 'https://image.tmdb.org/t/p/w200/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '1 day', 3200),
  ('異星入境', 2016, 'Denis Villeneuve', array['科幻','劇情'], 'https://image.tmdb.org/t/p/w500/pEzNVQfdzYDzVK0XqxERIw2x2se.jpg', 'https://image.tmdb.org/t/p/w200/pEzNVQfdzYDzVK0XqxERIw2x2se.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '12 days', 540),
  ('全面啟動', 2010, 'Christopher Nolan', array['科幻','動作','懸疑'], 'https://image.tmdb.org/t/p/w500/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', 'https://image.tmdb.org/t/p/w200/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '5 days', 2890),
  ('星際效應', 2014, 'Christopher Nolan', array['科幻','劇情'], 'https://image.tmdb.org/t/p/w500/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', 'https://image.tmdb.org/t/p/w200/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '7 days', 2450),
  ('敦克爾克大行動', 2017, 'Christopher Nolan', array['戰爭','歷史'], 'https://image.tmdb.org/t/p/w500/b4Oe15CGLL61Ped0RAS9JpqdmCt.jpg', 'https://image.tmdb.org/t/p/w200/b4Oe15CGLL61Ped0RAS9JpqdmCt.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '25 days', 220),
  ('奧本海默', 2023, 'Christopher Nolan', array['傳記','歷史','劇情'], 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', 'https://image.tmdb.org/t/p/w200/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '4 days', 3410),
  ('黑暗騎士', 2008, 'Christopher Nolan', array['動作','犯罪'], 'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg', 'https://image.tmdb.org/t/p/w200/qJ2tW6WMUDux911r6m7haRef0WH.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '40 days', 180),
  ('記憶拼圖', 2000, 'Christopher Nolan', array['懸疑','劇情'], 'https://image.tmdb.org/t/p/w500/fKTPH2WvH8nHTXeBYBVhawtRqtR.jpg', 'https://image.tmdb.org/t/p/w200/fKTPH2WvH8nHTXeBYBVhawtRqtR.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '60 days', 95),
  ('寄生上流', 2019, 'Bong Joon-ho', array['劇情','驚悚'], 'https://image.tmdb.org/t/p/w500/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', 'https://image.tmdb.org/t/p/w200/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '6 days', 2710),
  ('駭人怪物', 2006, 'Bong Joon-ho', array['科幻','驚悚'], 'https://image.tmdb.org/t/p/w500/m3OE5bpcGHMWYlPkYvgIrncuuGN.jpg', 'https://image.tmdb.org/t/p/w200/m3OE5bpcGHMWYlPkYvgIrncuuGN.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '50 days', 110),
  ('末日列車', 2013, 'Bong Joon-ho', array['科幻','動作'], 'https://image.tmdb.org/t/p/w500/kw6YQudA0TMcNmGUGy5XIw7zbnV.jpg', 'https://image.tmdb.org/t/p/w200/kw6YQudA0TMcNmGUGy5XIw7zbnV.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '9 days', 1180),
  ('惡之地', 1973, 'Terrence Malick', array['犯罪','劇情'], 'https://image.tmdb.org/t/p/w500/z81rBzHNgiNLean2JTGHgxjJ8nq.jpg', 'https://image.tmdb.org/t/p/w200/z81rBzHNgiNLean2JTGHgxjJ8nq.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '80 days', 42),
  ('天堂之日', 1978, 'Terrence Malick', array['劇情','愛情'], 'https://image.tmdb.org/t/p/w500/rwxTYjOZmX2rGhz7avLe1qsjNqe.jpg', 'https://image.tmdb.org/t/p/w200/rwxTYjOZmX2rGhz7avLe1qsjNqe.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '90 days', 38),
  ('紅色警戒', 1998, 'Terrence Malick', array['戰爭','劇情'], 'https://image.tmdb.org/t/p/w500/seMydAaoxQP6F0xbE1jOcTmn5Jr.jpg', 'https://image.tmdb.org/t/p/w200/seMydAaoxQP6F0xbE1jOcTmn5Jr.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '70 days', 55),
  ('生命之樹', 2011, 'Terrence Malick', array['劇情','家庭'], 'https://image.tmdb.org/t/p/w500/l8cwuB5WJSoj4uMAsnzuHBOMaSJ.jpg', 'https://image.tmdb.org/t/p/w200/l8cwuB5WJSoj4uMAsnzuHBOMaSJ.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '11 days', 680),
  ('花樣年華', 2000, 'Wong Kar-wai', array['愛情','劇情'], 'https://image.tmdb.org/t/p/w500/iYypPT4bhqXfq1b6EnmxvRt6b2Y.jpg', 'https://image.tmdb.org/t/p/w200/iYypPT4bhqXfq1b6EnmxvRt6b2Y.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '20 days', 420),
  ('重慶森林', 1994, 'Wong Kar-wai', array['愛情','劇情'], 'https://image.tmdb.org/t/p/w500/43I9DcNoCzpyzK8JCkJYpHqHqGG.jpg', 'https://image.tmdb.org/t/p/w200/43I9DcNoCzpyzK8JCkJYpHqHqGG.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '100 days', 28),
  ('春光乍洩', 1997, 'Wong Kar-wai', array['愛情','劇情'], 'https://image.tmdb.org/t/p/w500/kO4KjUkQOfWSBw06Bdl7m6AlEP7.jpg', 'https://image.tmdb.org/t/p/w200/kO4KjUkQOfWSBw06Bdl7m6AlEP7.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '8 days', 1340),
  ('墮落天使', 1995, 'Wong Kar-wai', array['犯罪','愛情'], 'https://image.tmdb.org/t/p/w500/yyM9BPdwttK5LKZSLvHae7QPKo1.jpg', 'https://image.tmdb.org/t/p/w200/yyM9BPdwttK5LKZSLvHae7QPKo1.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '35 days', 165),
  ('千禧曼波', 2001, 'Hou Hsiao-hsien', array['劇情'], 'https://image.tmdb.org/t/p/w500/wSc6tOp1yoAFbZqxG5XVGHcFvRN.jpg', 'https://image.tmdb.org/t/p/w200/wSc6tOp1yoAFbZqxG5XVGHcFvRN.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '55 days', 72),
  ('刺客聶隱娘', 2015, 'Hou Hsiao-hsien', array['武俠','劇情'], 'https://image.tmdb.org/t/p/w500/10RcGMfzg2lIW1aLcR4ILfNbHK2.jpg', 'https://image.tmdb.org/t/p/w200/10RcGMfzg2lIW1aLcR4ILfNbHK2.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '13 days', 890),
  ('悲情城市', 1989, 'Hou Hsiao-hsien', array['劇情','歷史'], 'https://image.tmdb.org/t/p/w500/n1aIYLgnrlsUrh77G2OdQT9NV1.jpg', 'https://image.tmdb.org/t/p/w200/n1aIYLgnrlsUrh77G2OdQT9NV1.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '120 days', 20),
  ('牯嶺街少年殺人事件', 1991, 'Edward Yang', array['劇情','犯罪'], 'https://image.tmdb.org/t/p/w500/3l8fOAwiN3N5n3hHnZ51eog7Zu2.jpg', 'https://image.tmdb.org/t/p/w200/3l8fOAwiN3N5n3hHnZ51eog7Zu2.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '110 days', 33),
  ('一一', 2000, 'Edward Yang', array['劇情','家庭'], 'https://image.tmdb.org/t/p/w500/mR8dSQZI8X6Z1NClJhFrtJp636z.jpg', 'https://image.tmdb.org/t/p/w200/mR8dSQZI8X6Z1NClJhFrtJp636z.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '18 days', 510),
  ('神隱少女', 2001, 'Hayao Miyazaki', array['動畫','奇幻'], 'https://image.tmdb.org/t/p/w500/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg', 'https://image.tmdb.org/t/p/w200/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '2 days', 4200),
  ('龍貓', 1988, 'Hayao Miyazaki', array['動畫','家庭'], 'https://image.tmdb.org/t/p/w500/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg', 'https://image.tmdb.org/t/p/w200/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '10 days', 1990),
  ('風之谷', 1984, 'Hayao Miyazaki', array['動畫','科幻'], 'https://image.tmdb.org/t/p/w500/tcrkfB8SRPQCgwI88hQScua6nxh.jpg', 'https://image.tmdb.org/t/p/w200/tcrkfB8SRPQCgwI88hQScua6nxh.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '75 days', 88),
  ('霍爾的移動城堡', 2004, 'Hayao Miyazaki', array['動畫','奇幻'], 'https://image.tmdb.org/t/p/w500/13kOl2v0nD2OLbVSHnHk8GUFEhO.jpg', 'https://image.tmdb.org/t/p/w200/13kOl2v0nD2OLbVSHnHk8GUFEhO.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '14 days', 1230),
  ('天氣之子', 2019, 'Makoto Shinkai', array['動畫','愛情'], 'https://image.tmdb.org/t/p/w500/qgrk7r1fV4IjuoeiGS5HOhXNdLJ.jpg', 'https://image.tmdb.org/t/p/w200/qgrk7r1fV4IjuoeiGS5HOhXNdLJ.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '16 days', 980),
  ('你的名字', 2016, 'Makoto Shinkai', array['動畫','愛情'], 'https://image.tmdb.org/t/p/w500/q719jXXEzOoYaps6babgKnONONX.jpg', 'https://image.tmdb.org/t/p/w200/q719jXXEzOoYaps6babgKnONONX.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '5 days', 2660),
  ('鈴芽之旅', 2022, 'Makoto Shinkai', array['動畫','奇幻'], 'https://image.tmdb.org/t/p/w500/yStW1TXF5s7Tbtu9KjIZEaWl6HL.jpg', 'https://image.tmdb.org/t/p/w200/yStW1TXF5s7Tbtu9KjIZEaWl6HL.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '7 days', 2030),
  ('華爾街之狼', 2013, 'Martin Scorsese', array['犯罪','傳記'], 'https://image.tmdb.org/t/p/w500/kW9LmvYHAaS9iA0tHmZVq8hQYoq.jpg', 'https://image.tmdb.org/t/p/w200/kW9LmvYHAaS9iA0tHmZVq8hQYoq.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '22 days', 390),
  ('愛爾蘭人', 2019, 'Martin Scorsese', array['犯罪','劇情'], 'https://image.tmdb.org/t/p/w500/mbm8k3GFhXS0ROd9AD1gqYbIFbM.jpg', 'https://image.tmdb.org/t/p/w200/mbm8k3GFhXS0ROd9AD1gqYbIFbM.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '45 days', 140),
  ('計程車司機', 1976, 'Martin Scorsese', array['犯罪','劇情'], 'https://image.tmdb.org/t/p/w500/ekstpH614fwDX8DUln1a2Opz0N8.jpg', 'https://image.tmdb.org/t/p/w200/ekstpH614fwDX8DUln1a2Opz0N8.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '150 days', 15),
  ('四海好傢伙', 1990, 'Martin Scorsese', array['犯罪','傳記'], 'https://image.tmdb.org/t/p/w500/9OkCLM73MIU2CrKZbqiT8Ln1wY2.jpg', 'https://image.tmdb.org/t/p/w200/9OkCLM73MIU2CrKZbqiT8Ln1wY2.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '95 days', 41),
  ('雨果的冒險', 2011, 'Martin Scorsese', array['冒險','家庭'], 'https://image.tmdb.org/t/p/w500/1dxRq3o3l3bVWNRvvSb7rRf68qp.jpg', 'https://image.tmdb.org/t/p/w200/1dxRq3o3l3bVWNRvvSb7rRf68qp.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '28 days', 260),
  ('花束般的戀愛', 2021, 'Nobuhiro Doi', array['愛情','劇情'], 'https://image.tmdb.org/t/p/w500/73EMVPCQ3G2mTLgXJrFuOgxJfkp.jpg', 'https://image.tmdb.org/t/p/w200/73EMVPCQ3G2mTLgXJrFuOgxJfkp.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '3 days', 2890),
  ('小偷家族', 2018, 'Hirokazu Kore-eda', array['劇情','家庭'], 'https://image.tmdb.org/t/p/w500/4nfRUOv3LX5zLn98WS1WqVBk9E9.jpg', 'https://image.tmdb.org/t/p/w200/4nfRUOv3LX5zLn98WS1WqVBk9E9.jpg', '00000000-0000-0000-0000-000000000001', 'approved', now() - interval '6 days', 2120);

commit;
