#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Build Flutter web for Vercel deployment.
#
# Usage:
#   scripts/build-web.sh                  # reads .env.dev (default)
#   scripts/build-web.sh .env.prod        # reads a specific env file
#
# Produces: build/web/   (static assets, ready to `vercel deploy`)
#
# Requirements:
#   - flutter on PATH
#   - .env file with SUPABASE_URL + SUPABASE_ANON_KEY (optional:
#     SENTRY_DSN, APP_ENV)
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

ENV_FILE="${1:-.env.dev}"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Env file not found: $ENV_FILE"
  echo "   Create one with:"
  echo "     SUPABASE_URL=https://xxx.supabase.co"
  echo "     SUPABASE_ANON_KEY=eyJ..."
  exit 1
fi

echo "▸ Reading $ENV_FILE"
# Export KEY=VALUE lines, skipping comments + blanks. Using a plain
# read-loop (process substitution + `set -a` was inconsistent across
# bash 3.2 on macOS).
while IFS='=' read -r key value; do
  [ -z "$key" ] && continue
  case "$key" in \#*) continue ;; esac
  export "$key=$value"
done < <(grep -v '^\s*#' "$ENV_FILE" | grep '=')

: "${SUPABASE_URL:?SUPABASE_URL not set in $ENV_FILE}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY not set in $ENV_FILE}"

APP_ENV="${APP_ENV:-prod}"
SENTRY_DSN="${SENTRY_DSN:-}"

echo "▸ Cleaning prior build"
rm -rf build/web

echo "▸ flutter build web --release  (APP_ENV=$APP_ENV)"
flutter build web \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --base-href "/"

echo ""
echo "✅ Built: build/web/"
echo ""
echo "Next steps:"
echo "  1) Preview locally:"
echo "       cd build/web && python3 -m http.server 8080"
echo "       open http://localhost:8080"
echo ""
echo "  2) Deploy to Vercel:"
echo "       vercel deploy --prod"
echo "     (run from the repo root; vercel.json points at build/web)"
echo ""
echo "  ⚠️  Remember: after first deploy, add the Vercel domain to"
echo "      Supabase → Authentication → URL Configuration → Redirect URLs"
echo "      so Google OAuth can round-trip."
