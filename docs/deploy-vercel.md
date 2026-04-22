# Deploy to Vercel (web)

Flutter web → Vercel static hosting. Vercel doesn't have Flutter
pre-installed, so we build **locally**, then ship the pre-built
`build/web/` as static files.

---

## One-time setup

1. Install the Vercel CLI: `npm i -g vercel` (or `bun i -g vercel`).
2. `vercel login`.
3. In the repo root, run `vercel link` — pick/create a project.

---

## Every deploy

```bash
# 1. Build the web bundle (reads .env.dev by default).
./scripts/build-web.sh .env.dev       # or .env.prod

# 2. Ship it. vercel.json at repo root points to build/web/
vercel deploy --prod
```

First deploy gives you a URL like `https://poster-app-xyz.vercel.app`.
Custom domain? `vercel domains add yourdomain.com` + point DNS.

---

## Supabase OAuth → Vercel domain

Google sign-in will 400 until you whitelist the Vercel URL in Supabase.

1. Go to your Supabase project → **Authentication** → **URL Configuration**.
2. Add the Vercel URL(s) to **Redirect URLs**:
   - `https://poster-app-xyz.vercel.app/**` (prod)
   - `https://poster-app-xyz-*.vercel.app/**` (preview branches, optional)
3. Also set **Site URL** to the prod URL so email templates use it.

Re-test Google sign-in.

---

## What `vercel.json` does

- `outputDirectory: build/web` — tells Vercel "this dir is my static site".
- `buildCommand: echo '...'` + `installCommand: echo 'skip'` — Vercel
  runs no build on its servers; we ship the pre-built dir.
- `rewrites: /(.*) → /index.html` — GoRouter uses deep links
  (`/poster/abc`, `/home/collection/favorites`). Without this
  rewrite, hard-navigating to a deep link 404s on Vercel.
- `headers` — long-cache hashed JS/wasm/fonts (immutable), no-cache
  `index.html` so every page load gets the latest bundle.
- `cleanUrls + trailingSlash: false` — cosmetic.

---

## Checking the build before deploy

```bash
cd build/web
python3 -m http.server 8080
# open http://localhost:8080
```

Single-origin headers (COEP/COOP) from `vercel.json` aren't applied
by the Python server, so some CanvasKit features may render
differently than on Vercel. If it works here, Vercel will too.

---

## Troubleshooting

**"白底空白長時間載入中"** — check browser console; usually a
missing `SUPABASE_URL` dart-define. Re-run `./scripts/build-web.sh`
after confirming `.env.dev` has the right values.

**Google sign-in redirects to `127.0.0.1:3000`** — the Supabase
OAuth provider still has the dev Site URL. Update it to the Vercel
domain (see above).

**`main.dart.js` download is slow on mobile** — ~3.7 MB compressed.
Vercel serves it gzipped automatically. If first-load TTI is
painful, we can trial `flutter build web --wasm` (experimental, not
production-ready on all browsers yet).

**Stale UI after deploy** — hard-refresh (Cmd/Ctrl+Shift+R). The
`no-cache` header on `index.html` makes this automatic on revisit,
but PWA service worker caches can linger. `vercel.json` could ship a
kill-switch header later if needed.
