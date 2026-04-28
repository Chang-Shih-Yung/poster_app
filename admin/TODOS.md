# Admin TODO list

Living follow-up list. Items marked **[done]** are merged; the rest are still
open.

---

## 1. `posters` legacy NOT NULL columns — drop NOT NULL

**[partially done — trigger-based defaults landed; drop NOT NULL still open]**

A BEFORE INSERT trigger (`fill_legacy_poster_defaults`) now fills `title`,
`poster_url`, `uploader_id` automatically, and a BEFORE UPDATE trigger
(`sync_poster_title_from_name`) keeps `title` in lock-step with `poster_name`.
The admin server actions stopped touching these columns explicitly. **Open
follow-up:** drop the NOT NULL constraints outright and update the Flutter
client (`lib/data/models/poster.dart`) to read these as nullable. That
requires a coordinated Flutter release because the model casts `as String`
on these fields today.

**Migration landed:** `20260428100200_posters_legacy_defaults.sql`
**Still open:** `ALTER TABLE posters ALTER COLUMN title DROP NOT NULL` plus
the parallel changes for `poster_url` and `uploader_id`, plus Flutter model
updates.

---

## 2. Cursor pagination for `/works` and `/tree/studio/[studio]` — **[done]**

Server-rendered first batch of 50 rows; "載入更多" button calls the
`loadWorksPage` server action and appends the next 50. Order is
`created_at DESC, id DESC`; cursor is the trailing row's `created_at`. After
any mutation, `revalidatePath` re-renders the page → the accumulated batches
reset to the fresh first page (intentional — server is more authoritative
than the client's cached append history).

---

## 3. Postgres function for recursive group counts — **[done]**

`public.get_group_recursive_counts(p_work_id uuid)` returns
`(group_id, total)` per group. `/tree/work/[id]` and `/tree/group/[id]`
call it via `supabase.rpc(...)` instead of pulling every group + every
poster down to the client. The TS implementation in `lib/groupTree.ts`
stays as the unit-test oracle.

**Migration landed:** `20260428100100_get_group_recursive_counts.sql`

---

## 4. E2E tests for the golden path

Playwright (or `/qa`) covering: log in → create studio → add work → add
group → add poster → upload image → see thumbnail. The user is planning to
drive this via gstack `/qa` against a local `:3000` dev server (Google
OAuth blocks the side preview).

**Open.**

---

## 5. Audit trail for destructive actions — **[done]**

`admin_audit_log` table + `logAudit()` helper in `app/actions/_internal.ts`.
Every rename / delete / kind-change / studio-rename / image-attach writes a
row with `(admin_user_id, admin_email, action, target_kind, target_id,
payload, created_at)`. Audit writes are fire-and-forget — a slow audit
insert never blocks the user-visible mutation, and audit failures log to
the server console rather than failing the action.

**Migration landed:** `20260428100000_admin_audit_log.sql`
**RLS:** admin can read own rows; service-role bypass for the writes.
**Open follow-up:** retention policy (right now rows accumulate forever).
