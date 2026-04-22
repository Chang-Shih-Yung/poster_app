# Deploy to Vercel (web)

Flutter web → Vercel. **Push-to-deploy**: `git push origin main` triggers
Vercel to clone, install Flutter, build, and publish. No manual step.

---

## One-time setup (already done)

1. `vercel link` in repo root → picked the `poster-app` project.
2. Vercel Dashboard → Project → **Settings** → **Environment Variables**:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SENTRY_DSN` (optional)
   - `APP_ENV` (optional, defaults to `prod`)
   All set for **Production + Preview + Development**.

---

## Every deploy

```bash
git push origin main
```

That's it. Vercel builds in ~3–5 min (first build downloads Flutter SDK,
subsequent builds reuse the cached clone). Watch progress at
https://vercel.com/dashboard → Deployments.

---

## How it works

- `vercel.json` → `installCommand: echo skip`, `buildCommand: bash scripts/vercel-build.sh`
- `scripts/vercel-build.sh` clones Flutter stable into `_flutter/`,
  puts it on `PATH`, runs `flutter build web --release` with
  dart-defines from Vercel env vars.
- `outputDirectory: build/web` is what Vercel publishes.
- `rewrites: /(.*) → /index.html` keeps GoRouter deep links working.
- `headers` long-caches hashed JS/wasm (immutable), no-caches `index.html`.

---

## Supabase OAuth → Vercel domain

Google sign-in will 400 until the Vercel URL is whitelisted:

1. Supabase → **Authentication** → **URL Configuration**
2. **Site URL**: `https://poster-app-zeta.vercel.app`
3. **Redirect URLs** add:
   - `https://poster-app-zeta.vercel.app/**`
   - `https://poster-app-zeta.vercel.app/auth/v1/callback`

---

## Local preview (optional escape hatch)

If you want to build + preview locally without deploying:

```bash
./scripts/build-web.sh .env.dev
cd build/web && python3 -m http.server 8080
```

`scripts/build-web.sh` reads env from `.env.dev` (or pass `.env.prod`).
Not used by the deploy pipeline — purely for local QA.

---

## Troubleshooting

**Build fails on Vercel with "SUPABASE_URL not set"** — env var missing
in Vercel Dashboard. Check Project → Settings → Environment Variables.

**Build fails with "flutter: command not found"** — `scripts/vercel-build.sh`
didn't clone Flutter. Check Vercel build logs, usually a git clone timeout;
retry the deploy.

**White screen on production** — browser console will tell you. Usually
a missing dart-define (Supabase keys). Check env vars + rebuild.

**Google sign-in redirects to `127.0.0.1:3000`** — Supabase Site URL is
still the dev value. Fix in Supabase dashboard (see above).

**Stale UI after deploy** — hard-refresh (Cmd/Ctrl+Shift+R). PWA service
worker caches sometimes linger. `index.html` is `no-cache`, so normally
you get the latest on revisit.
