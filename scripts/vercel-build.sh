#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Vercel build script — runs on Vercel's build machine, NOT locally.
#
# Flow: installs Flutter SDK → flutter build web with dart-defines
# pulled from Vercel env vars.
#
# Required Vercel env vars (Project → Settings → Environment Variables):
#   SUPABASE_URL
#   SUPABASE_ANON_KEY
# Optional:
#   SENTRY_DSN, APP_ENV
#
# For local builds use scripts/build-web.sh instead.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL not set in Vercel env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY not set in Vercel env}"

APP_ENV="${APP_ENV:-prod}"
SENTRY_DSN="${SENTRY_DSN:-}"

echo "▸ Cloning Flutter stable"
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi
export PATH="$PATH:$PWD/_flutter/bin"

echo "▸ flutter doctor"
flutter --version
flutter config --enable-web

echo "▸ flutter build web --release (APP_ENV=$APP_ENV)"
flutter build web \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --base-href "/"

echo "✅ Built: build/web/"
