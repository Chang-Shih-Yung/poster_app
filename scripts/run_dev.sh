#!/usr/bin/env bash
# Run the Flutter app with dev env vars from .env.dev
# Usage: ./scripts/run_dev.sh [-d chrome|<deviceId>]
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env.dev}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

exec flutter run "$@" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
