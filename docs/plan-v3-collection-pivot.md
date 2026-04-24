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
- ☑ **Sheets ↔ admin link**: API pull-sync with preview/diff, not
  iframe embed (see §3.5).
- ☑ **Image pipeline split**: Sheets carries text only; image
  upload + processing lives exclusively in the admin (see §3.6).
- ☑ **Canonical poster rule (2026-04-24 refinement)**: every poster
  row **always has an image**, starting as a work-kind-specific
  silhouette placeholder and upgraded to a real scan by the official
  team over time. No `NULL` poster_url ever. See §3.7.
- ☑ **User contribution scope**: users contribute **metadata only**,
  never images. Images are 100% an official-team responsibility. See
  §3.7.
- ☑ **Per-user image override**: users can replace the displayed image
  for posters they collect with their own photo, visible on their own
  profile. Global canonical image is unaffected. See §3.7.
- ☑ **Collection mechanic (2026-04-24 second refinement)**:
  trust-based "flip" — user taps a Silhouette to flip the card to
  `owned`. No photo required, no admin review, no image verification.
  Photo upload is voluntary and produces only a visual 📸 badge for
  the user's own card. Canonical image remains official-only. This
  drops the "Locked (blurred)" tier — see §3.9.
- ☑ **A — Unlock timing**: lenient. User can flip before official has
  uploaded the real image; Silhouette carries a ✓ owned badge until
  real image lands, then upgrades automatically.
- ☑ **B — Override visibility**: strictly private. Only the uploader
  sees their own photo; other viewers always see the canonical image.
  No `visibility` column; no public/community override path in v3.
- ☑ **C — Ownership claim**: frictionless, single-tap, no proof,
  no moderation. Optional photo stays strictly private (owner-only
  view). **No badge tied to photo presence.** See §3.11 for why.
- ☑ **D — Silhouette count**: 8 generic silhouettes, one per
  `work_kind` enum value.
- ☑ **2026-04-24 third refinement — product positioning**: Poster. is
  a **collector's utility tool**, not a game. No consumption-based
  achievement system (flipped-N, set-complete, speed, rarity tier).
  The only badge kind that survives is **contribution-based** (posters
  submitted and approved). See §3.12 for the first-principles
  reasoning.
- ☑ **B6 editor workflow correction**: in practice editors upload the
  real image at sync time or shortly after; the generic silhouette is
  the **rare fallback** for historic posters where no official image
  exists, not the default path. See §4A refinements.
- ☑ **E1**: un-flip is supported; the attached personal photo is
  deleted along with the state row.
- ☑ **E2**: single tap flips, second tap un-flips. No animation
  gating, no undo timer.
- ☑ **E3**: no "once owned" history tracking — current-only.
- ☑ **E4**: binary owned / not owned. No duplicate counters.
- ☑ **E5**: user can re-upload / delete their personal photo freely.
- ☑ **E7**: account deletion fully purges personal state +
  override rows. No anonymized retention (Henry's call — rarity stats
  were dropped in §3.12 anyway).
- ⏳ **E6**: admin-removes-a-poster edge case deferred, pending badge
  / audit decision above (now resolved — revisit in §4E).

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
- **On sync**: every new poster row lands in Supabase with
  `poster_url = placeholder_by_kind(work_kind)` (see §3.7) and a flag
  `is_placeholder = true`.
- **Admin UI has a "needs real image" queue**: editor opens the queue,
  sees the text metadata, drops a file in → admin uploads to the
  `posters` storage bucket, generates thumb + BlurHash, replaces
  `poster_url`, sets `is_placeholder = false`.
- Images also go through the usual compression pipeline
  (`ImageCompressor.compress`) we already have.

Why this split is cleaner than the original "NULL until uploaded"
draft:

- **No `NULL` state in the DB** — every query that renders a poster
  tile can assume `poster_url` is non-null. No branches, no "is this
  row ready yet" logic scattered through UI code.
- Text-only rows are still shipped to the live app the moment they
  sync — users see a silhouette / locked-slot tile immediately, which
  is the whole point of a collector's app (empty slots drive the
  hunt).
- Image work (compress, thumb, BlurHash, moderation) is decoupled
  from the sync flow and can be a proper admin workflow.

### 3.7 Image state machine — four-tier display model

Every poster has ONE canonical image (never null), plus an optional
per-user override. What the user actually sees is resolved at read
time in this order:

```
  ┌────────────────────────────────────────────────────────────┐
  │         Display-image resolution for a (user, poster)       │
  ├────────────────────────────────────────────────────────────┤
  │                                                              │
  │  1. User has uploaded an override?                           │
  │     YES → show user_poster_override.image_url                │
  │           (PERSONALIZED)                                     │
  │     NO  → 2                                                  │
  │                                                              │
  │  2. User's state for this poster is 'owned'?                 │
  │     YES → show posters.poster_url in full colour             │
  │           (UNLOCKED)                                         │
  │     NO  → 3                                                  │
  │                                                              │
  │  3. posters.is_placeholder is FALSE?                         │
  │     (i.e. official team has uploaded the real image)         │
  │     YES → show posters.poster_url blurred + 🔒 badge         │
  │           (LOCKED — "real image exists, you don't own it")   │
  │     NO  → 4                                                  │
  │                                                              │
  │  4. Default: show the generic silhouette for work_kind       │
  │           (SILHOUETTE — "this poster exists but we don't     │
  │           have the real image yet either")                   │
  │                                                              │
  └────────────────────────────────────────────────────────────┘
```

**Four tiers, in the order a collector progresses through them:**

| Tier | What they see | Means |
|---|---|---|
| **Silhouette** | Generic `work_kind` silhouette | "Canonical record exists, no real image yet" |
| **Locked** | Real image blurred + 🔒 | "Official has it, you don't own it" |
| **Unlocked** | Real image, full colour, ✓ badge | "You own this" |
| **Personalized** | User's own photo | "You replaced the image with your own scan" |

**Tables needed:**

- `posters.poster_url` — always non-null. Starts as the silhouette, gets
  replaced by a real scan.
- `posters.is_placeholder` — boolean. TRUE while `poster_url` is still
  the silhouette; FALSE once admin uploads the real scan.
- `user_poster_state (user_id, poster_id, state, …)` — see §2.3 for
  the full shape; `state = 'owned'` drives the Locked → Unlocked jump.
- `user_poster_override (user_id, poster_id, image_url, thumb_url,
  uploaded_at, visibility)` — new table; one row per user per poster
  when the user uploads their own photo.

**Silhouette assets:**

- One image per `work_kind` enum value → 8 images total.
- Stored in a public Supabase bucket `placeholders/` (or committed
  into the repo as static assets — probably cleaner).
- Referenced by `poster_url` as a stable URL so no special-case
  rendering is needed.

**What users CAN contribute (confirmed 2026-04-24):**
- Metadata for missing posters (title, year, channel, etc.)
- Their own photo as a per-user override

**What users CAN'T contribute:**
- The canonical image of a poster — always official team's job.
- Edits to other users' overrides — strictly per-user.

### 3.8 ~~Open sub-questions~~ — all resolved 2026-04-24

A (unlock timing), B (override visibility), C (proof), D (silhouette
count) are now all locked in the Decisions section. See §3.9 for the
game-mechanic rationale that drove these into trust-based territory.

**E (poster_group cover image)**: Claude's call accepted: group rows
may optionally carry a `cover_url` for tree-node visuals, but do not
participate in the user-state model.

### 3.9 Collection mechanic — why trust-based "flip" wins

**The problem with strict proof-based claims.** Poster collectors
routinely own 50–500+ posters. A model that makes them upload a photo
for every single one — and then wait on admin review — turns collection
into unpaid labour. They will quit.

**Two schools of collection apps** (look at what shipped, not what's
theoretically elegant):

| School | Examples | Supply controlled by | Proof model |
|---|---|---|---|
| **A — Game-controlled supply** | Hearthstone, 神魔之塔, Genshin | The game | No proof needed (game gave it to you) |
| **B — Real-world supply** | Pokémon Go, Pikmin Bloom, Letterboxd, Discogs, MyAnimeList | The real world | **Trust-based. No proof required.** |

Poster. is unambiguously School B. The posters exist in the physical
world; we do not control who bought what. Every shipped School B app
has converged on **trust-based entry with social/aesthetic incentives
to add evidence**, not forced moderation. Letterboxd never asked for
ticket stubs. Discogs never asked for vinyl scans. MyAnimeList never
asked for screenshots. They all ship; they all have millions of users.

**The "flip" interaction.** Every poster tile starts face-down
(Silhouette). The user taps a tile → a quick flip animation → they can
optionally attach their own photo → the tile settles into the
`owned` state on their profile.

- No review.
- No verification beyond an AI NSFW check on any attached photo.
- Attaching a photo is purely a **voluntary flex** — it earns a 📸
  badge on that card in the user's own collection view, and a
  "collector's quality" meta-badge when >70% of their collection
  has photos. Nothing else.

**What this drops vs. the earlier four-tier model.** The "Locked
(blurred real image)" tier disappears. Reasoning: once entry is
trust-based, there's no need to let viewers peek at a blurred real
image for posters they haven't flipped — it just generates a weird
"here's what you could have" envy. Cleaner model:

| Tier | What viewer sees | When |
|---|---|---|
| **Silhouette** | Generic `work_kind` silhouette | Not flipped OR no real image yet |
| **Unlocked (canonical)** | Real image, full colour | Flipped AND real image exists |
| **Unlocked (silhouette)** | Silhouette + ✓ owned + date | Flipped BUT no real image yet — auto-upgrades when admin uploads the real one |
| **Personalized** | Owner's own photo | Only visible to the owner themselves |

**Public vs private view of the same user's collection page:**

```
You (own)  vs  Visitor

Unlocked + photo attached:
  You    →  Personalized (your own photo) + 📸 badge
  Visitor →  Unlocked canonical (official image)    ← same as any other viewer

Unlocked + no photo:
  You    →  Unlocked canonical
  Visitor →  Unlocked canonical

Not yet flipped:
  You    →  Silhouette (tappable → flip)
  Visitor →  hidden from your profile entirely (you haven't claimed it)
```

Visitors never see another user's private photos. Visitors never see
posters the owner hasn't flipped (no "this is what they don't have"
shaming). This aligns Q4 (public default) with Henry's B-answer
(photos stay private): **collection membership is public, collection
photography is private.**

### 3.10 Retained UX hooks (what to build in Phase 3)

**Warning — this section was heavily cut after §3.12's product
positioning lock-in (2026-04-24 third refinement). Most of the
original "gamification hooks" were consumption-based and got dropped.
Only hooks that survive the "can you trivially game it?" test remain.**

| Hook | Inspiration | Implementation sketch |
|---|---|---|
| **Personal completion %** (self-view only) | Pokédex, Discogs collection stats | `(flipped_in_set / total_in_set)`, shown ONLY on owner's own collection page. No public leaderboards, no global percent competition. |
| **Seen vs Owned** | Pokédex silhouette → seen → caught | We already have `state='seen'` in the enum. "I saw this at [cinema]" is a lightweight tap, doesn't affect any score. |
| **Flip animation** | physical TCGs | Flutter `AnimatedBuilder` + `Matrix4.rotationY` (0.5s). Second tap reverses (see E2). Pure UX polish. |
| **Activity journal** | Letterboxd log, Discogs contributor feed | Replace v2 social feed. Focus is on **contribution events** ("X added N posters to the catalogue") and **set completions** ("X finished the Ghibli set"). Flip events are visible but not highlighted — they're low-signal. |
| **Contribution badge** (the only badge) | Wikipedia's barnstar, Stack Overflow badges | `count(submissions where status='approved')` tiers: 10 / 100 / 1000 contributions. Real work, real gate. |

**Explicitly dropped** (see §3.12 for why):
- ~~Flip-count badges~~ (any flavour: quantity, speed, "first to")
- ~~Set-completion *badges*~~ (the completion % stays as personal
  self-info; the badge layer on top was gameable and got cut)
- ~~Rarity tiers~~ (Common / Rare / Legendary) — global flip counts
  can't be trusted so the tier was fiction
- ~~Photo badge~~ (📸 "attached a photo") — gameable by auto-uploading
  any image; replaced with "photo is private, badge-free"
- ~~Leaderboards of any flipped-quantity metric~~

**Future hooks that would actually work** (post-v3):
- Real-world event check-ins with on-site QR (cheap, verifiable, real)
- Official limited-edition poster runs with per-copy NFC / serial (if
  Poster. ever prints its own physical limited posters — this is
  the Sorare-equivalent: we control supply, we can verify)
- Cinema chain partnership for "actually watched" badges (speculative)

### 3.11 Photo moderation — the honest answer: don't bother

Henry's 2026-04-24 insight: any photo-based verification is theatre.
Someone can grab a Google-image-search result in 10 seconds, crop it,
and upload — no free AI pipeline catches this reliably (Lens-style
reverse-image works only on the most naive copies; any user that
understands the game can get around it).

So we drop photo verification entirely:

- **No review of uploaded photos** (beyond a single NSFW AI check as
  a standard content-safety measure, same pipeline avatars already go
  through).
- **No badge tied to photo upload.** The photo is purely a **private
  personal-collection record**; it has no social or game meaning.
- `user_poster_override` table has no `moderation_state` column.
  Photos exist or don't.
- Admin never looks at user photos in the normal course of operation.
  The only time a user photo surfaces in the admin is via an explicit
  abuse report — which goes through the same NSFW-review path as
  avatar reports.

This is the Discogs / Letterboxd model: upload if you want, it's for
you, nobody's policing it, nobody's rewarding you for it.

### 3.12 Why badges (and consumption-based gamification) got dropped

Henry asked the deepest question (2026-04-24): "if I can just open the
app, flip every card, and collect every badge, then uninstall — what's
the point of the badges?" He's right. This section records why
consumption-based gamification got cut and what stayed.

**The problem with the original four-category badge system:**

| Category | Claimed purpose | Why it fails |
|---|---|---|
| Quantity (flipped 100) | Reward milestone | Mass-flip in one sitting; instant trophy |
| Set completion (all Ghibli) | Reward dedication | Same — flip everything in a category |
| Speed (first to flip X) | Reward early engagement | Purely favours early signups; late joiners locked out; still gameable by anyone who finds the poster first via mass-flip |
| Rarity tier (Legendary) | Signal rare ownership | Global flip counts include fake flips; rarity becomes fiction |

The common weakness: **flipping has no natural gate**. Anyone can flip
anything. So any metric derived from flip counts is noise.

**The one category that survived: contribution.**

Submissions have a natural gate — the admin review queue. A user can't
"contribute 100 posters" without actually writing 100 rows of valid
metadata that pass a human check. That signal is real.

**Why we don't try to gate flipping.**

Four paths were considered:
1. Photo verification → theatre (see §3.11).
2. GPS / time-of-release verification → only works for future posters;
   useless for a historic catalogue.
3. NFC / QR on physical posters → requires IP-holder cooperation.
4. Paid flip unlocks → turns Poster. into a pay-to-play on top of
   already-paid-for physical posters. Absurd.

None work for a free app tracking a historic catalogue of mass-produced
objects. This is a fundamental physics problem with physical poster
ownership, not a design oversight.

**The resulting product positioning (locked 2026-04-24):**

Poster. is a **utility** for collectors, not a **game** disguised as
one. Cosmetic gamification on a utility is empty calories — it
attracts the wrong audience (grind-for-trophies) and fails the right
audience (real collectors don't care about fake trophies).

Compare:

| Metric | Discogs (utility) | Sorare (game) |
|---|---|---|
| Badges for consumption | None | Yes, but gated by paid packs |
| Ownership verification | Trust + community | Blockchain-backed |
| Retention driver | Catalogue quality + marketplace | Game loop + speculation |
| User count | ~8M | ~2M, higher ARPU |

Discogs proves a utility-first collector's app scales without any
gamification at all. That's the path.

**What we keep from the game-style UX without the game-style trap:**

- **Flip interaction** — satisfying UX, private self-tracking, no
  prestige attached.
- **Personal collection progress bar** — *"you have 42 of 680"* shown
  ONLY on your own collection page. No leaderboards, no public
  percentage.
- **Contribution badge** — earned through real work (submissions that
  pass review). Persistent, meaningful, unfakeable.
- **Activity feed** — Letterboxd-style "X contributed N posters today"
  or "X completed their Ghibli set" (the latter is visible but isn't
  a badge, just a shareable moment).

**What we throw away:**

- All flip-count badges (quantity / set / speed).
- All rarity tier displays (Common / Rare / Legendary).
- Global flip-count competition displays.
- Any "first to" achievement.
- The idea that photos earn you anything.

**Future doors we leave open (out of scope for v3):**

- Offline events: in-person meetup QR code = real verification of a
  real action = real badge. Cheap when the event is cheap.
- Official limited-edition runs: if Poster. (the team) someday prints
  and numbers its own limited posters, those *can* be cryptographically
  verified — because we control the supply, like Sorare does. Future
  product, not v3.
- Cinema partnerships: if a cinema chain provides API access to
  movie-watching history, "seen this movie" badges become real.
  Entirely speculative.

## 4. Scenario ledger — source-of-truth for what the system does

This section is the human-readable check-list of every flow we've
discussed. Henry and co-founder sign off here **before** any schema
is cut. Anything new that comes up in migration work gets back-added
to this list first.

### 4A. Editor (non-tech) scenarios

**Note (B6 correction, 2026-04-24):** in practice the editor usually
has the real image at sync time — posters get released with press
images, so "official image exists" is the default case. Silhouettes
are a **fallback for historic posters with no surviving image**, not
the normal path.

| # | Scenario | Action | Result |
|---|---|---|---|
| A1 | Editor writes new poster row in Sheet | Fills metadata columns | Row saved in Sheet (nothing in DB yet) |
| A2 | Editor clicks "Sync from Sheet" in admin | Reviews diff preview, confirms | Rows inserted with `is_placeholder = true`; display-image is silhouette for `work_kind` |
| A3 | Editor immediately goes to "needs real image" queue | Drags scanned images onto tiles (usually in the same session as A2) | Placeholder upgraded to real image app-wide |
| A4 | Historic poster with no known image | Editor deliberately leaves as silhouette | `is_placeholder = true` persists; tile shows silhouette indefinitely |
| A5 | Editor corrects a typo | Edits in admin OR in Sheet + re-sync | DB updated |
| A6 | Editor deletes a poster | Admin action | Soft-delete (`deleted_at`); hidden from app, recoverable; affected users notified (see E6) |

### 4B. Collector basic scenarios

| # | Scenario | Action | Result |
|---|---|---|---|
| B1 | New user opens app | Sees tree browse | "Sea of silhouettes", 0/N progress everywhere |
| B2 | Taps into a movie | Sees all posters in that work | All silhouettes, progress counter e.g. 0/12 |
| B3 | Taps a silhouette | Poster detail page | Metadata, path breadcrumb, action buttons |
| B4 | Taps "flip" (no photo) | Flip animation → state = owned | Silhouette becomes canonical image in self-view |
| B5 | Taps "flip" + attaches photo | Flip animation → owned + photo stored | Private photo visible on self-view + (maybe) 📸 badge per §3.11 |
| B6 | Flips before admin uploads real image | state = owned | Silhouette + ✓ badge + date; auto-upgrades to canonical when image lands |
| B7 | Switches to own collection page | Sees progress bar / rarity / achievements | All public info |
| B8 | Receives notification | e.g. "your submission approved" / "your photo earned badge" | Corresponding state updated |

### 4C. Collector contribution (missing-poster) scenarios

| # | Scenario | Action | Result |
|---|---|---|---|
| C1 | User searches, finds nothing | "Propose a missing poster" CTA appears | Opens submission form |
| C2 | User fills form (no image!) | Submits metadata only | Submission row, pending; admin notified |
| C3 | Admin reviews submission queue | Approves / rejects / merges into existing | Corresponding outcome |
| C4 | Approved → poster created | Auto-attaches silhouette, enters "needs real image" queue | User notified "your proposal accepted" |
| C5 | Rejected → user sees reason | Notification carries reason string | User can revise and resubmit |

### 4D. Social / public view scenarios

| # | Scenario | Action | Result |
|---|---|---|---|
| D1 | Visitor views Henry's profile | Sees only flipped posters | Unflipped hidden entirely; personal photos never shown |
| D2 | Visitor views a flipped poster on Henry's profile | Shows canonical image (not Henry's personal photo) | Uniform visual across viewers |
| D3 | Activity item: "X flipped Y poster" | Tappable → poster detail | Can 👏-react (lightweight) |
| D4 | Follow / followers | v2 existing flow | Kept but frozen (no new social features in v3) |

### 4E. Edge cases — resolved 2026-04-24

| # | Edge case | Resolution |
|---|---|---|
| E1 | User un-flips | Supported. Second tap on a flipped card un-flips. Attached personal photo is deleted from Storage + DB. |
| E2 | User double-tap / mis-tap | Not a special case. Flip is a tap toggle; un-flip is symmetric. No undo timer needed. |
| E3 | Sold a poster, used to own it | Not tracked. Current-only model. Self-declared; user's own concern. |
| E4 | Owns multiple copies of same poster | Not tracked. Binary owned / not owned. |
| E5 | Re-uploads / deletes personal photo | Supported. New upload overwrites old file in Storage (hard-delete, not soft). |
| E6 | Admin removes a poster that users have flipped | Admin-triggered removal is rare; when it happens, soft-delete the `poster` row; cascade soft-delete `user_poster_state` + `user_poster_override` rows referencing it; notify affected users with the reason string supplied by admin. |
| E7 | User deletes account | Hard-purge `user_poster_state`, `user_poster_override`, uploaded photos in Storage. No retention. (Rarity tier stats were removed in §3.12, so nothing depends on anonymized retention.) |

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

5. **Current upload flow fate**: confirmed direction — drop stage 1
   (pick image) entirely. The ＋ button leads to a metadata-only
   "propose a missing poster" form. A separate flow ("attach my photo
   to this flipped poster") lives on each poster's detail page inside
   the owner's collection view. ✅ Direction locked by the §3.9
   refinement.

5b. ~~§3.8 sub-questions~~ → all resolved.

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

## 9. Data flow diagram (2026-04-24 revision, post-trust-based-flip)

For showing the co-founder — this is the current picture of how data
moves through v3.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              POSTER. v3 DATA FLOW — trust-based flip edition                  │
└─────────────────────────────────────────────────────────────────────────────┘

 官方編輯端                  Next.js 後台                    使用者端 (Flutter)
 ─────────                   ───────────                    ──────────────────

 Google Sheets              [目錄同步面板]                    [樹狀瀏覽]
 (文字 only)    ──API──▶    ├─ Sheet diff preview             ├─ 所有海報按樹狀分類
                            ├─ 一鍵 import                     ├─ 未翻牌 = Silhouette
                            ├─ 自動掛 silhouette               └─ 已翻牌 = Unlocked /
                            └─ is_placeholder = true              Personalized
                                    │                              │
                                    ▼                              ▼
                            [待補真圖佇列]                      [翻牌互動]
                            ├─ 按熱度排序                        ├─ tap → 翻面動畫
                            ├─ 拖真圖上傳                        ├─ 可選上傳自拍 (+📸)
                            ├─ 自動壓縮 + thumb + BlurHash       ├─ 寫 user_poster_state
                            └─ is_placeholder = false            │    (state = 'owned')
                                    │                            └─ 自拍寫 user_poster_
                                    │                                 override (永遠 private)
 使用者投稿 ──metadata only──▶ [投稿審核佇列]                       │
 (在 app 按 ＋，不附圖)         ├─ 只審 metadata                  │
                                ├─ 通過 = 新 poster + silhouette │ (無審核、信任制)
                                └─ 進入「待補真圖佇列」            │
                                         │                        ▼
                                         ▼                  [個人卡夾]
                                ┌───────────────────┐      ├─ 看到已翻牌全部
                                │   Supabase DB     │◀─────┤  (自己 = Personalized
                                │                   │      │   + 未翻牌 silhouette)
                                │  works            │      ├─ set 進度條
                                │  poster_groups    │      ├─ 稀有度徽章
                                │  posters          │      └─ 成就 / 活動 feed
                                │  user_poster_     │
                                │    state          │      [公開 profile (別人看你)]
                                │  user_poster_     │      ├─ 只看到已翻牌
                                │    override       │      ├─ 全部顯示官方圖
                                │    (private only) │      └─ 看不到未翻牌 / 自拍
                                │  submissions      │
                                └───────────────────┘
```

**渲染邏輯（讀取時）**:

```
                 Is viewer the owner?
                  ├── YES (self-view)
                  │     ├── 已 flip + 有自拍 → Personalized (自拍)
                  │     ├── 已 flip + 無自拍 → Unlocked canonical / silhouette
                  │     └── 未 flip        → Silhouette (可點擊翻牌)
                  │
                  └── NO  (public view of someone else's profile)
                        ├── 已 flip → Unlocked canonical / silhouette
                        └── 未 flip → 不顯示 (不秀「他還沒收到」)
```

**Three write-paths, one canonical DB:**

1. Sheet sync (bulk text from editor) → occasional batch imports
2. Admin direct edit (image uploads, corrections, submission review)
3. User submissions (metadata only, via app ＋) → admin queue-reviewed

**One read-path, two render modes:** self-view sees everything
including unflipped tiles (to tempt the hunt); public-view only sees
what's been flipped (no envy, no shaming).

## 10. Shared mental model — what goes where

Quick reference card for "should this feature live in Sheets, admin,
or the Flutter app?":

| Feature | Sheets | Admin (Next.js) | Flutter app |
|---|---|---|---|
| Add a new work (1 row) | ✅ easy | ✅ | 🚫 text-only submission |
| Add 200 works (bulk) | ✅ paste-friendly | ✅ csv drop | 🚫 |
| Build parent/child tree | ❌ path-string hack | ✅ drag-drop | 🚫 |
| Upload the **canonical** image | 🚫 | ✅ exclusive | 🚫 forbidden |
| Upload **my own** override image | 🚫 | 🚫 | ✅ |
| Compress / thumb / BlurHash | 🚫 | ✅ auto | ⚠️ client-side for override only |
| Approve a user submission | 🚫 | ✅ | 🚫 |
| Mark "I own this" | 🚫 | 🚫 | ✅ |
| Browse tree / search / feed | 🚫 | 🔍 read-only | ✅ |
| Edit my profile | 🚫 | 🚫 | ✅ |
| Rarity / global owner counts | 🚫 | ✅ (dashboard) | ✅ (per-poster pill) |
| Silhouette assets (8 generic) | 🚫 | ✅ one-time upload | 🚫 read-only |

The two "official" pipelines (Sheets → admin, user → admin review) both
converge on the same Supabase tables. Flutter app is downstream
read-only-ish consumer of the canonical state, with writes limited to
per-user rows (`user_poster_state`, `favorites`, `follows`).

---

*End of live doc. Next step: Henry confirms Q5/Q6/Q7 (or accepts the
"leaning toward" defaults), we split Phase-1 migrations + admin
scaffolding + Sheets importer into tickets.*
