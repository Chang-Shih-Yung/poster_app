# Admin TODO list

Living follow-up list. Items marked **[done]** are merged; the rest are still
open.

---

## 1. `posters` legacy NOT NULL columns — **[done]**

`title`, `poster_url`, `uploader_id` are nullable on the schema and on
`Poster.fromRow`. Triggers still set sensible defaults (auth.uid() for
uploader_id; poster_name for title) but the columns no longer lie about
the data contract — `poster_url IS NULL` now meaningfully says "no
real image yet" alongside `is_placeholder=true`.

Flutter readers in 9 sites updated to fall back gracefully:
`p.title ?? p.posterName ?? '(未命名)'`, `p.posterUrl ?? ''`, and
guarded calls (uploader badge skipped when `uploaderId` is null;
fullscreen viewer disabled for placeholder posters).

**Migrations landed:**
- `20260428100200_posters_legacy_defaults.sql` (triggers)
- `20260428110000_drop_posters_legacy_not_null.sql` (drop NOT NULL)

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
