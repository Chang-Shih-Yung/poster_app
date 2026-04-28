# Admin TODO list

Living follow-up list for things that came out of the architecture review.
Add new entries with **What / Why / Pros / Cons / Context / Depends on**.

---

## 1. `posters` legacy NOT NULL columns

**What** — Make `posters.title`, `posters.poster_url`, `posters.uploader_id` nullable
(or drop `title` outright in favour of `poster_name`); update Flutter app's reads
to match.

**Why** — Every server-side `createPoster` and the upload flow has to back-fill
these columns with sentinel strings (`title := poster_name`, `poster_url := ""`,
`uploader_id := admin.id`). The schema lies about the data contract: a poster
without a real image still has an empty-string URL.

**Pros** — One source of truth (`poster_name`); empty-string URL goes away;
deletes the back-fill code from `app/actions/posters.ts:createPoster`; future
schema changes don't have to inherit this debt.

**Cons** — Requires a Supabase migration AND a Flutter client bump (the public
app reads `title`/`poster_url`). Has to be coordinated with the user-facing
release. Two-system change.

**Context** — Came out of `/plan-eng-review` 2026-04-28. Search for `legacy NOT
NULL` in the actions to find every back-fill site.

**Depends on** — Flutter app schema migration; Supabase migration ordering.

---

## 2. Cursor pagination for `/works` and `/tree/studio/[studio]`

**What** — Replace the hard `.limit(500)` cap with a cursor-based "load more"
button (or infinite scroll on mobile).

**Why** — Current scale is ~50 works total, but a single popular studio
("漫威", "吉卜力") could grow past 500 once the catalogue fills out. Today
those rows would silently get cut off.

**Pros** — No surprise truncation; mobile scroll perf stays smooth (don't
render 5000 cards on first load); works at any catalogue size.

**Cons** — Pagination state needs to live in the URL (`?cursor=...`) for
shareable links + back-button. About a day of work to do well, with E2E
tests covering "load more then act on a row".

**Context** — Caught during `/plan-eng-review` 2026-04-28. Defensive 500 cap is
in `app/works/page.tsx` and `app/tree/studio/[studio]/page.tsx`.

**Depends on** — Nothing.

---

## 3. Postgres function for recursive group counts

**What** — Move `recursivePosterCount` from client-side TS into a SQL function
`get_group_recursive_counts(work_id uuid) returns table(group_id uuid, total bigint)`.
Server pages call the function instead of pulling all groups+posters.

**Why** — `/tree/work/[id]` and `/tree/group/[id]` currently fetch every group
+ every poster of the work just to compute display badges. For a work with
1,000+ posters that's a lot of bytes over the wire for every page load.

**Pros** — One round-trip instead of two; payload size proportional to
displayed count, not work size; tree pages snappier on large works; SQL is
fast at recursive CTEs.

**Cons** — Adds a Supabase migration; the SQL has to keep matching the TS
behaviour (depth cap, soft-delete filter); harder to test than the pure-TS
version.

**Context** — Caught during `/plan-eng-review` 2026-04-28. TS implementation +
tests live in `lib/groupTree.ts` — keep them as a fallback / oracle.

**Depends on** — Nothing.

---

## 4. E2E tests for the golden path

**What** — Playwright (or similar) covering: log in → create studio → add work
→ add group → add poster → upload image → see thumbnail.

**Why** — Phase 1-3 added 27 unit tests for pure logic, but every Server
Action and every Sheet flow is currently uncovered. A regression that breaks
"add poster" wouldn't show up until manual QA.

**Pros** — One run covers auth gate, server actions, image pipeline, cache
revalidation. Catches integration breakage that unit tests can't.

**Cons** — Playwright + Supabase test user setup is non-trivial. CI run takes
1-2 minutes.

**Context** — Iron-rule regression item from `/plan-eng-review` 2026-04-28.

**Depends on** — Decision on test Supabase project (separate from prod).

---

## 5. Audit trail for destructive actions

**What** — Optional `audit_log` table that captures (admin_email, action, target_id,
target_kind, payload, ts) for every mutation that goes through `app/actions/*`.
A small wrapper around `requireAdmin` writes the row.

**Why** — Today there's no record of who deleted that one studio. With a
single admin and pre-launch data this is fine; once there's >1 admin or after
launch, "what changed and when" needs an answer.

**Pros** — Cheap insurance; debugging "the data looks weird" gets a starting
point.

**Cons** — Writes for every mutation; storage grows linearly with admin
activity. Need a retention policy.

**Context** — Caught during `/plan-eng-review` 2026-04-28 (RLS-only writes
discussion).

**Depends on** — Multi-admin scenario decision.
