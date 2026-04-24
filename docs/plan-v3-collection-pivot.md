# Poster. v3 — Collection Pivot

**Status:** live discussion (2026-04-24). Three major decisions are now
locked (see §7). Remaining open questions below that line. Migrations
still not cut — waiting on §7 remainder.

## Decisions locked as of 2026-04-24

- ☑ **Q2 — Admin stack**: separate Next.js app in the monorepo (not
  Flutter web).
- ☑ **Q3 — Editor's first-month tool**: Google Sheets, synced via the
  Sheets API into the admin (no manual CSV download).
- ☑ **Q4 — Collection privacy default**: public (OpenSea-style).
- ☑ **New — Sheets ↔ admin link**: API pull-sync with preview/diff, not
  iframe embed (see §3.5).
- ☑ **New — Image pipeline split**: Sheets carries text only; image
  upload + processing lives exclusively in the admin (see §3.6).

---

## 0. TL;DR

We are turning Poster. from **"a social discovery app for movie posters"**
into **"a collector's database for physical/digital posters you own or
want to own"**. The social surfaces (follow, feed, activity) stay but
freeze; the product centre of gravity moves to **catalogue + collection
+ unlock**.

Three things have to land for this pivot to work:

1. **A canonical poster catalogue** — ~10k rows, hand-curated by a
   non-technical data editor, with parent/child structure (movie →
   variants → printings).
2. **An authoring tool** for that editor — must handle 10k-scale,
   tree hierarchies, bulk import, minimal technical literacy.
3. **A collector's UX** in the app — reframes every screen around
   "what have I collected / what's missing / what's rare", with
   OpenSea / KOCA-style unlock visuals.

This doc walks through each, flags the hard tradeoffs, and ends with a
set of **decisions Henry needs to make** before we split the work into
migrations.

---

## 1. Mental model shift

### What changes

| | v2 (current) | v3 (proposed) |
|---|---|---|
| Primary user goal | Discover new posters | Track what they own & hunt what they don't |
| Unit of content | A single poster upload | A canonical poster record + user's ownership state |
| Data authority | User-contributed | Curated by core team, extended by users |
| Home screen | Feed of recent approvals | "My collection" / "Missing from your set" |
| Identity | Uploader | Collector |
| Reference apps | Instagram / Pinterest | OpenSea, KOCA, Discogs, MyAnimeList |

### What this implies — bluntly

- **The "upload" path becomes secondary.** We just finished polishing
  a 2-stage upload flow; in v3 that flow is a **contribution** path
  ("suggest this poster is missing from the catalogue"), not the main
  action. The centre button probably stops being ＋ Upload and becomes
  🔍 Explore or ✓ Check-in.
- **Every poster needs a canonical record separate from ownership.**
  A poster exists whether or not anyone owns it. Ownership is a join
  table, not a column on the poster.
- **Discovery becomes taxonomy-first**, not timeline-first. Users drill
  down: 電影 → 吉卜力 → 千與千尋 → 2001 正式版 → 日版 B1. Feed is a
  fallback, not the homepage.

### What stays

- Auth, users, profiles, follow (frozen but kept — collectors still
  want to see other collectors' shelves).
- `submissions` table stays, but its meaning shifts: a submission is
  now "I want to propose this poster be added to the catalogue" or
  "I claim I own this canonical poster; here's my photo".
- Supabase as backend, Flutter as client, Vercel for web.

---

## 2. Data model — the parent/child question

### 2.1 The hierarchy the editor needs

Henry described: *"一個電影底下有發行不同院線的海報、不同年代的海報"*.

Concretely for 千與千少 this means the tree is **≥ 3 levels**:

```
千與千尋 (Work)
├── 2001 日本首映
│   ├── B1 原版（Toho 發行）
│   ├── 前売券（advance ticket 附贈）
│   └── 劇場配布小冊
├── 2014 重映
│   ├── IMAX 海報（威秀 獨家）
│   └── 一般戲院版
└── 2024 25 週年
    ├── 25 週年 teaser
    └── 25 週年 final (台灣版)
```

And that's just one movie. For a K-pop album, a concert tour, a
Broadway show — the tree shape is different. The editor **must be able
to define the shape per category**, not have it hardcoded.

### 2.2 Three ways to model this

#### Option A — Rigid 2-table SQL (current)
```
works (canonical IP: 千與千尋)
  └── posters (each individual poster, flat list)
```
- ✅ Simple, indexed, fast
- ❌ No hierarchy between posters — "2014 重映" isn't a thing in the DB,
  it's just a `poster_release_date` column. The editor can't say "these
  5 posters belong to the 2014 重映 set" as a group.
- ❌ Different categories (movie / concert / album) all have to squeeze
  into the same fixed columns.

#### Option B — Generic tree (`poster_groups` + `posters`) ★ recommended starter
```
works             (千與千尋 — the IP)
  └── poster_groups (recursive: 2001日本首映 → inside has groups and posters)
        └── posters  (leaf nodes: the actual image)
```
- `poster_groups` is a recursive table: `id, work_id, parent_group_id, title, group_type`
- Leaf `posters` always hang off a group, never directly off a work
- Editor picks a `group_type` (`release_year`, `cinema_chain`,
  `edition`, `channel`…) which drives UI labels but not schema
- ✅ Arbitrary depth — editor can nest as deep as the subject needs
- ✅ Same schema works for movies, concerts, albums, games, etc.
- ✅ One SQL recursive CTE renders the whole tree for a Work
- ⚠️ Recursive queries need indexes on `parent_group_id`; watch depth

#### Option C — EAV / JSONB hybrid (max flexibility)
```
works
  └── nodes (id, parent_id, type, attrs jsonb)
```
Every row is a node; type + attrs drive rendering.
- ✅ Editor can invent new node types at runtime without migrations
- ❌ Queries get ugly (`attrs->>'size_type' = 'b1'`), search is harder,
  typos in attr keys become permanent
- ❌ Loses foreign-key help (can't FK into a JSONB blob)
- Appropriate **later** if the editor actually needs to invent new
  taxonomies; premature now.

**Recommendation:** start with **Option B** (recursive groups +
leaf posters). It solves the parent/child ask, keeps SQL honest,
and doesn't lock us out of C if we ever genuinely need EAV.

### 2.3 Ownership model — separate from catalogue

```
posters            — canonical rows (no user column)
user_poster_state  — (user_id, poster_id, state, acquired_at, source, photo_url, note)
```

`state` enum: `owned · wishlist · seen · missing · duplicate`.

Why a dedicated table, not columns on `posters`:
- 1 poster → many users' states (obvious)
- Lets us index per-user queries (`where user_id = me`) cheaply
- Supports "I own 2 copies" (duplicate)
- Future: proof-of-ownership photos go here, not on the canonical row

### 2.4 What happens to the current `posters.uploader_id`?

Two interpretations, both fine:
- **A**: "uploader" = the user who first contributed the canonical
  record (credit stays visible but doesn't imply ownership)
- **B**: drop `uploader_id` from `posters`, move it to a
  `poster_contributions` table (an audit log of who added what)

B is cleaner long-term. A is a 1-line change. Can defer.

---

## 3. The authoring tool

### 3.1 The ask, restated

Henry will hand this to a non-technical poster-collector who knows
*what fields matter* but doesn't know SQL. The tool must:

- Handle **~10k rows** comfortably
- Let the editor **build the tree visually** (drag a printing under a
  release-year under a work)
- Support **bulk import** (paste from a spreadsheet, probably CSV/TSV)
- Let the editor **add / delete / rename** nodes freely
- Eventually: let the editor **define new taxonomies** (add a
  "collector's edition" sub-type under Release)

### 3.2 Four realistic paths

| Path | Time-to-useful | Ceiling | Best when |
|---|---|---|---|
| **1. Airtable / Notion DB** | 0.5 day | 5k rows OK, 10k strains | Editor starts tomorrow, we sync via script |
| **2. Supabase Studio only** | 0 day | Works but UX is raw | Editor is OK with spreadsheet-style UI |
| **3. Build a custom admin route** | 1–2 weeks | Unlimited | Medium-term commitment |
| **4. Metabase / Retool frontend** | 2–3 days | Good for CRUD, weak for tree UI | Quick internal tool |

My honest read:

- **Do not wait** for the custom admin. Start the editor on path 1 or
  2 this week. Migrate when path 3 is ready.
- **Build path 3 (custom admin)** because the tree UI is the product
  differentiator, and Airtable's tree UX is ~OK but not great for
  arbitrary depth. Also, once the admin is built, it naturally becomes
  the user-contribution UI described in requirement 3.
- **Skip Retool/Metabase.** Licensing costs + vendor lock-in don't
  earn their keep when we already own a Flutter app and a React-web
  story via Flutter-web.

### 3.3 CSV/Sheet template for the editor (path 1 starter)

What the editor fills in (one row = one leaf poster):

| column | example | notes |
|---|---|---|
| `work_title_zh` | 千與千尋 | required |
| `work_title_en` | Spirited Away | |
| `work_kind` | movie | enum |
| `path` | `2014 重映 > IMAX 威秀獨家` | `>`-separated group tree |
| `poster_name` | IMAX final | required, leaf name |
| `region` | tw | |
| `release_year` | 2014 | optional on leaf (usually on group) |
| `release_type` | theatrical | |
| `size` | b1 | |
| `channel` | cinema | |
| `channel_name` | 威秀 | |
| `is_exclusive` | TRUE | |
| `exclusive_of` | 威秀影城 | |
| `material` | 霧面紙 | |
| `version_label` | v2 修正版 | |
| `image_url` | https://… | optional at import time |
| `source_url` | | |
| `notes` | | free text, migrates into internal field |

A small Python import script converts this into:
- Upsert a `work` (by normalised title + year)
- Walk the `path` segments, upsert `poster_groups` along the way
- Insert the leaf `poster` under the final group

I can write that importer in ~200 lines.

### 3.5 Sheets ↔ admin sync — the pipe between them

Henry's question: "can we embed the Sheet inside the admin so I don't
have to manually export/import CSVs?" — yes, but **not via iframe**.
Iframe embedding is a UX dead-end: the admin "sees" the sheet visually
but can't read or react to its content; authentication is fragile
(third-party cookie restrictions); image upload is still unsolved.

**Chosen approach — API pull-sync with diff preview.**

Flow from the editor's and admin's POV:

1. Editor writes rows in Google Sheets (familiar tool, free, any device).
2. Admin has a top-bar button `🔄 從 Sheet 同步 (上次 2 小時前)`.
3. Click → backend calls Google Sheets API, reads the range, walks
   every row, and produces a diff against the current Supabase state.
4. Preview modal shows:
   ```
   ➕ 新增 42 筆
   🔄 更新 15 筆
   ⚠️ 衝突 2 筆 (click to review)
   ❌ 無效 1 筆 (missing required field)
   ```
5. Editor confirms → backend upserts into `works / poster_groups /
   posters`. Text-only; images are a separate path (see §3.6).
6. Sync log is appended to an `admin_sync_runs` table so we can always
   roll back.

**Why API pull, not Apps Script push or 2-way sync:**

| option | editor sees | admin sees | failure mode |
|---|---|---|---|
| iframe embed | Sheet | nothing useful | admin becomes "page with a Google Sheet on it" |
| API pull (★) | Sheet | diff preview + commit | blast-radius-contained; user confirms each sync |
| Apps Script webhook push | Sheet | near-real-time | silent Apps-Script quota failures; no preview |
| 2-way sync | Sheet + admin | Sheet + admin | conflict resolution is a week of engineering we don't need |

**Auth / cost:**

- One-time setup: Google Cloud free project → enable Sheets API → create
  a service account → share the Sheet with that account's email as
  Viewer.
- Free tier: 300 reads/minute/project — we'll hit that once per manual
  sync, nowhere near the limit.
- No Google Workspace subscription needed.

**Long-term role of Sheets:**

Sheets is a Phase-1 transitional tool. Once the admin has native
add/edit/bulk-import for every field, editors switch to the admin
entirely and Sheets becomes a backup export destination.

### 3.6 Image pipeline — Sheets does text, admin does images

Sheets can't hold real image files (only URLs, which rot). So we split
the pipeline:

- **Sheets rows**: no image column, or an optional `source_url`
  (reference only — not the canonical asset).
- **On sync**: every new/updated poster row lands in Supabase with
  `poster_url = NULL` and a flag `needs_image = true`.
- **Admin UI has a "needs image" queue**: editor opens the queue, sees
  the text metadata, drops a file in → admin uploads to
  `posters` storage bucket, generates thumb + BlurHash, sets
  `poster_url`, clears `needs_image`.
- Images also go through the usual compression pipeline
  (`ImageCompressor.compress`) we already have.

Why this split is cleaner:

- Editors who are filling data in bulk (from public references / books)
  often don't have the image handy at that moment anyway.
- Separating text from image means a bad image upload doesn't block a
  whole row — the text is already live and can start showing up in
  collection tree views as "this poster exists but no image yet"
  (grey-out rendering).
- Image work (compress, thumb, BlurHash, moderation) can be
  server-side background-queued without coupling to the sync flow.

### 3.4 Custom admin — where does it live?

**Three places it could go:**

- **3A. `/admin` route inside the Flutter web build**
  Pros: same auth, same types, one deploy.
  Cons: Flutter web is… fine for forms, not great for "Supabase-Studio-
  like" interactive tree editors. Drag/drop and virtualised tables are
  painful in Flutter.

- **3B. Separate Next.js app in the same monorepo, shared Supabase**
  Pros: best React ecosystem for admin UI (shadcn/ui, TanStack Table,
  dnd-kit, react-arborist tree component). Deploys to its own Vercel
  project at `admin.poster.app`.
  Cons: two codebases, but they share only the DB (which is fine).

- **3C. Separate repo entirely**
  Pros: total isolation.
  Cons: auth sharing gets fiddly; duplicate CI.

**Recommendation: 3B.** Monorepo → `/admin` next.js sub-app → deploy
to a different Vercel project → same Supabase → gated to
`role = 'admin' | 'editor'`. This is the setup that lets us reach the
"user contribution" phase later (requirement 3): once the admin UI
exists, we can gradually expose read-only / suggest-only slices of it
inside the Flutter app.

Folder layout:

```
poster_app/
  lib/                 # existing Flutter app (current repo)
  supabase/migrations/ # existing migrations
  admin/               # NEW — Next.js
    app/
    components/
    lib/supabase.ts
    package.json
  docs/
  scripts/
```

One repo, two Vercel projects, one DB. This is the standard "two
frontends one backend" monorepo pattern.

---

## 4. Frontend reframe — the collector's UX

### 4.1 Inspiration mapped

- **OpenSea**: grid of NFTs with ownership state overlay ("You own 3 of
  40"), collection progress bar, rarity badges. We steal: **progress
  chrome on every collection page**, **rarity tiers**, **owner count
  per item**.
- **KOCA / 카드수집 apps**: "photo-card album" mental model — every card
  has a slot; slots are empty until you check-in. We steal: **slot-based
  grid**, **locked/unlocked visual** (blurred + lock icon vs. coloured),
  **collection completion percent**.

### 4.2 Proposed screen set

| Screen | Core purpose | v2 equivalent |
|---|---|---|
| **Home (Explore)** | Browse catalogue by taxonomy tree | Home feed |
| **Collection** | "My shelf" — grouped by Work or Tag | Profile → uploaded posters |
| **Work detail** | Recursive tree view of one work, with my ownership state on each leaf | Poster detail page |
| **Progress / Achievements** | % complete per collection, badges | — (new) |
| **Search** | Multi-facet taxonomy search | existing search (keep) |
| **Contribute** | Propose a missing poster / fix a record | existing upload (reframed) |
| **Feed** (deprecated but kept) | Recent activity | Home feed (frozen) |

### 4.3 State pills (per poster, per user)

`owned · wishlist · seen · missing · duplicate`

Visual:
- Owned → full-colour, ✓ badge
- Seen (you saw one in real life but don't own it) → full-colour, 👁 badge
- Wishlist → dim, ★ badge
- Missing (default) → blurred / grayscale, 🔒 badge
- Duplicate → owned variant with a `×N` pill

Editable from: the Work detail tree, the Collection screen, and a
long-press on any poster tile.

### 4.4 Unlock / progress mechanic

Derived from `user_poster_state`:
```
WorkProgress(work_id, user_id) = owned_count / total_canonical_count
```
Surfaced as:
- Progress bars on every Work card
- Streak-like achievements: "Studio Ghibli 完成 80%"
- Global rarity (low-owner-count posters get a rarity tier label:
  Common / Rare / Legendary — based on global `owned_count` distribution)

### 4.5 What to do with the current code

- **Keep** (frozen): follow, feed, notifications, favorites (favorites
  become a strict subset of wishlist).
- **Refactor**: search (stays, but gains taxonomy facets), profile
  (becomes collection-first, not poster-first).
- **Reframe, don't rewrite**: the current `/poster/:id` detail becomes
  `/posters/:id` (one leaf); we add `/works/:id` (tree view) as the
  new main detail.

---

## 5. Phasing — one realistic order

### Phase 0 — this week
- ✅ Delete bot seed (done as `delete_bot_seed.sql`, waiting on Henry to run).
- ✅ This doc; Henry decides on the open questions below.

### Phase 1 — catalogue foundation (1–2 weeks)
- Add `poster_groups` recursive table + migration
- Extend `posters` with `parent_group_id` (nullable during transition)
- Add `user_poster_state` table
- Data import script for the editor's CSV
- Editor starts filling in **Airtable** while the custom admin is built
  (path 1 interim)

### Phase 2 — admin UI (2–4 weeks)
- Spin up `admin/` Next.js app in monorepo
- Tree-view editor (react-arborist or similar)
- Bulk import UI (paste CSV / drop file)
- Role-gated behind `users.role in ('admin','editor')`
- Editor migrates from Airtable to admin UI

### Phase 3 — collector's frontend (3–5 weeks)
- `/works/:id` tree detail page
- Collection screen
- State-pill editing
- Progress / rarity chrome
- Feed / follow get archived under a secondary tab

### Phase 4 — open contribution (later, maybe never)
- User-facing "suggest a poster" path that writes to a moderation queue
- Reviewer workflow inside the admin UI
- Revisit whether `submissions` table merges with this

---

## 6. Risks & considerations

### Data risks

- **Schema churn cost.** The editor *will* want to add fields mid-way
  through. Every new field = migration + Flutter model change + admin
  UI field. Option B's `poster_groups` being recursive helps (group
  types carry no schema cost), but leaf `posters` still have fixed
  columns. Mitigation: agree on a `custom_fields jsonb` column on
  `posters` from day one. Editor dumps ad-hoc stuff there; we promote
  popular keys to real columns over time.

- **Dedup with free-text inputs.** Non-tech editor will type
  "千與千尋", "千與千尋 ", "千与千寻" — DB will store all three as
  distinct works unless we normalise. Mitigation: normalise on write
  (NFKC + trim + optional CN→TW via `cn2an`/`opencc`) and enforce
  `unique(slug)` where slug is derived.

- **10k scale is trivial for Postgres, but painful in Flutter lists.**
  Keep using paginated RPCs. The admin UI needs virtualisation
  (TanStack Table handles this). No single query should ever load >500
  rows into the Flutter app.

### Product risks

- **Pivot cost is invisible but real.** Users who installed for the
  discovery feed will see a different app. If the install base is still
  small (is it?) this is fine; if not, we phase.

- **Collector audience is narrower than social audience.** Smaller TAM,
  deeper engagement. Monetisation path changes (subscription /
  transactions) — not this doc's problem, but worth naming.

- **Editor is a single point of failure.** One person curating 10k rows
  = bus factor 1. Need import tooling + admin UI so that a second
  editor can pick up the slack, and so the data is readable as a
  spreadsheet independent of our schema (export CSV button = must-have).

### Tech risks

- **Flutter-web admin would be painful.** If Henry prefers one codebase
  only, we'd end up reinventing react-arborist / TanStack Table in
  Flutter. Strongly recommend monorepo + separate Next.js admin.

- **Auth sharing between two Vercel apps.** Supabase Auth handles this
  natively via JWT cookies on the same root domain (`*.poster.app`).
  Fine, but a 1-day setup task when the time comes.

- **Migration order.** `user_poster_state` references `posters.id`; we
  must not drop `posters.uploader_id` until the app stops reading it.
  This doc assumes we add columns additively and clean up at the end
  of Phase 3.

- **Row-level security.** `user_poster_state` must be RLS-gated per
  user (a collector's ownership list can be private). Default: read
  own rows, read others' rows only if their profile is public.

### Process risks

- **Scope drift on the admin tool.** "Build a Supabase-Studio-like
  schema designer" is a 6-month ask. We should scope the first version
  down to: **manage tree + rows for ONE fixed schema**. Schema changes
  still go through migrations. We revisit schema designer in year 2.

- **Frozen-but-live code decays.** If we freeze feed/notifications,
  they'll break on the next Supabase client version bump and nobody
  notices. Mitigation: a skinny smoke test in `bot_flows_test.py` that
  hits the frozen endpoints on every backend deploy.

---

## 7. Open questions

### ☑ Resolved as of 2026-04-24

1. ~~**Tree model**~~ → defer to Henry's next reply; my recommendation
   stands: Option B (recursive `poster_groups`).
2. ~~**Admin location**~~ → Monorepo `admin/` Next.js (3B).
3. ~~**Editor path for month 1**~~ → Google Sheets + API pull-sync
   into the admin.
4. ~~**Ownership privacy default**~~ → Public (OpenSea-style).

### ⏳ Still open — please answer next

5. **Current upload flow fate**: keep as "contribute" with the same
   2-stage UI? Or redesign entirely around "check-in I own this
   canonical poster"?
   → *Leaning toward: keep the 2-stage UI but rewire the form's fields
   so it says "propose a missing poster" when the matched work exists,
   and "I own this" when the user lands from a canonical poster page.*

6. **Rarity model**: show global owner counts (like NFT platforms)?
   This reveals every user's collection size — even with Q4 public, we
   may want to aggregate (`3,241 owners`) rather than reveal exact
   sets.
   → *Leaning toward: yes, show aggregate counts + per-poster rarity
   tier; individual ownership sets stay per-user and are revealed on
   the owner's profile page, not at the poster page.*

7. **Submission / contribution merge**: one queue or two?
   - One queue — every user contribution (new poster OR my ownership
     claim) goes through the same admin review
   - Two queues — catalogue additions need stricter review; ownership
     claims are self-serve
   → *Leaning toward: two queues. Catalogue additions are "write to the
   canonical DB" and need vetting; ownership state writes to
   `user_poster_state` (user's own row) and doesn't need vetting
   except for fraud heuristics.*

8. **Does the editor need offline / local drafts** in Sheets, or is
   always-online OK?

9. **Bus-factor**: solo editor or 2–3?

10. **Timeline**: hard external deadline, or 2–3 month stage?

### Claude's suggested defaults for the leaning items

If Henry doesn't want to debate 5/6/7 individually, the defaults I'd
code against are the "leaning toward" lines above. Flag any you want
to overturn.

---

## 8. What Claude will do next

Now that Q2/Q3/Q4 + Sheets-sync + image-split are locked:

**Immediately unblocked to start (safe, no hard dependencies):**
1. Delete bot seed — waiting on Henry to paste `delete_bot_seed.sql`.
2. Produce the Google Sheet template CSV (header row + enum hints +
   required-field asterisks) so the editor can start filling tomorrow.
3. Add freeze labels to feed / notifications / favorites code so future
   maintainers know these are parked, not abandoned.

**Ready to draft (waiting on §7 remainder 5/6/7):**
4. Phase-1 migration: `poster_groups` recursive table +
   `posters.parent_group_id` + `user_poster_state` + `needs_image`
   flag. I'll produce the SQL but not apply until Henry signs off.
5. Sheets-to-Supabase importer (TypeScript, runs as an admin API
   route). ~200 lines. Needs Google Cloud service-account JSON from
   Henry before it can run live, but the code itself is independent.

**Scaffolding for Phase 2 (can start in parallel):**
6. `admin/` Next.js sub-app skeleton (empty routes, shared Supabase
   client, `role` gate middleware).

**Still blocked:**
7. Anything touching the `submissions` table — waits on Q7 decision
   (one vs. two queues).
8. Collection-frontend work — waits on Q5 (how to reframe the upload
   flow).

---

## 9. Shared mental model — what goes where

Quick reference card for "should this feature live in Sheets, admin,
or the Flutter app?":

| Feature | Sheets | Admin (Next.js) | Flutter app |
|---|---|---|---|
| Add a new work (1 row) | ✅ easy | ✅ | 🚫 read-only |
| Add 200 works (bulk) | ✅ paste-friendly | ✅ csv drop | 🚫 |
| Build parent/child tree | ❌ path-string hack | ✅ drag-drop | 🚫 |
| Upload the image file | ❌ | ✅ | ✅ (as contribution) |
| Compress / thumb / BlurHash | 🚫 | ✅ auto | 🚫 server does it |
| Approve a user submission | 🚫 | ✅ | 🚫 |
| Mark "I own this" | 🚫 | 🚫 | ✅ |
| Browse tree / search / feed | 🚫 | 🔍 read-only | ✅ |
| Edit my profile | 🚫 | 🚫 | ✅ |
| Rarity / global owner counts | 🚫 | ✅ (dashboard) | ✅ (per-poster pill) |

The two "official" pipelines (Sheets → admin, user → admin review) both
converge on the same Supabase tables. Flutter app is downstream
read-only-ish consumer of the canonical state, with writes limited to
per-user rows (`user_poster_state`, `favorites`, `follows`).

---

*End of live doc. Next step: Henry confirms Q5/Q6/Q7 (or accepts the
"leaning toward" defaults), we split Phase-1 migrations + admin
scaffolding + Sheets importer into tickets.*
