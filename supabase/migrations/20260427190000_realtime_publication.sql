-- ═══════════════════════════════════════════════════════════════════════════
-- Add catalogue tables to supabase_realtime publication
--
-- Supabase Realtime piggy-backs on Postgres logical replication, which only
-- ships rows for tables explicitly in the `supabase_realtime` publication.
-- Until now the catalogue tables (works / posters / poster_groups) weren't
-- in there, so Flutter clients subscribing via .channel().onPostgresChanges()
-- never received events when the admin made changes.
--
-- Adding all three to the publication enables instant sync: a write in the
-- Next.js admin propagates to every connected Flutter client within a few
-- hundred ms, no pull-to-refresh needed.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

do $$
declare
  t text;
begin
  foreach t in array array['works', 'posters', 'poster_groups']
  loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

commit;
