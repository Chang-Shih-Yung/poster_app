# Black-box integration tests

Two scripts, two purposes:

## `bot_flows_test.py` — automated, anon-key, read-path

Runs against live Supabase (URL + anon key read from `.env.dev`).
Verifies every surface that consumes the 10-bot seed fixture:

- Seed integrity — bot handles, roles, follow counts, favorite counts
- Discovery RPCs — `trending_favorites`, `active_collectors`,
  `home_sections_v2`, `for_you_feed_v1`
- Search + public profile — `search_users`, `user_public_profile`,
  `user_relationship_stats` for Henry / BIU / bot00
- Notification + CF pipeline shape sanity

**Run:**
```bash
python3 scripts/tests/bot_flows_test.py
```

Exit 0 = all pass, 1 = any fail. No dependencies beyond Python 3.9+.

**Coverage gap:** RLS-protected tables (`follows`, `favorites`,
`avatar_reports`) are never read directly — anon is blocked at the
DB level. Every check goes through a `security definer` RPC that
aggregates the same data. This is the same contract the live Flutter
client hits, so test coverage mirrors real runtime behaviour.

## `bot_write_paths.sql` — manual, Dashboard SQL Editor, write-path

Write operations (report-trigger fires, follow/unfollow cycle, PK
collision handling, CHECK-constraint enforcement) need service-role
privs to bypass RLS and fire DB triggers. Paste into the Supabase
Dashboard SQL editor and run.

Each test lives in its own `DO` block:
- Reads the before state
- Does its write
- Asserts via `RAISE NOTICE 'PASS'` / `RAISE WARNING 'FAIL'`
- Rolls back every side-effect before exiting

Safe to run repeatedly — nothing persists outside the DO block.

## When to rerun

- After every seed change to `scripts/tests/bot_seed.sql` (if/when
  that file lands — right now the seed lives inline in chat)
- Before every major backend deploy that touches follow / favorite /
  moderation schema or RPCs
- When a new RPC is added to the app that powers a home-page surface
  — add an assertion for it here first

## If a test fails

1. Check the detail line (e.g. `expected ≥ 10, got 0`).
2. If it's a shape mismatch (missing field), the RPC contract changed
   — update the test AND the Dart call-site together.
3. If it's an empty-data failure, the seed likely got partially wiped
   — re-run the bot seed snippet from chat history.
