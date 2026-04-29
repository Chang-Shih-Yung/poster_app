# Poster App — Claude Code Notes

Per-project guidance for Claude Code agents working in this repo.

## Repo layout

- `admin/` — Next.js 15 App Router admin panel (TypeScript, shadcn-new-york, Supabase)
- `lib/` (Flutter) — Flutter app for end users
- `supabase/` — DB migrations + RPCs (production schema is the source of truth)

## Conventions captured so far

- **DESIGN.md is for the Flutter app** (v13 Cool Ink + glass) and does NOT apply to admin
- **Admin styling** = shadcn new-york defaults (no custom design system yet)
- **Channel name** field is intentionally free text — admin is single-user, no autocomplete needed
- **HEIC**: client-side conversion via `heic2any` (lazy import). All file inputs accept HEIC explicitly
- **Tests**: vitest + jsdom + @testing-library/react. ResizeObserver/IntersectionObserver/PointerEvent polyfilled in `vitest.setup.ts`
- **Migrations** push immediately after writing — don't accumulate
- `revalidatePath()` calls are precise (no `"layout"` qualifier — too aggressive)

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore

## GBrain Configuration (configured by /setup-gbrain)

- **Engine**: postgres (Supabase, ap-northeast-1)
- **Project ref**: rycvsklsxubdjafbquix (separate from poster_app's prod DB)
- **Config file**: `~/.gbrain/config.json` (mode 0600)
- **Setup date**: 2026-04-29
- **MCP registered**: yes (user scope, `mcp__gbrain__*` tools)
- **Memory sync**: off (gstack-brain-init not run yet)
- **Repo policy**: `github.com/chang-shih-yung/poster_app` → read-write

### Using gbrain

```bash
gbrain search "query"            # search the brain
gbrain put <slug> <<<"content"   # write a page
gbrain get <slug>                # fetch a specific page
gbrain doctor --json             # health check
```

Inside Claude Code, these are also exposed as `mcp__gbrain__*` tools after restarting.

**Heads-up**: any open Claude Code session will not see the new MCP tools until restart. Tools load at session start, not mid-session.
