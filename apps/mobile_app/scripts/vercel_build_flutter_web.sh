#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_ROOT="${VERCEL_FLUTTER_ROOT:-$HOME/flutter}"

echo "Preparing Flutter SDK for Vercel build..."

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web >/dev/null
flutter config --no-analytics >/dev/null || true

cd "$APP_DIR"

echo "Running Flutter web build..."
flutter pub get

# Forward the runtime configuration the app reads at compile time
# (lib/shared/config/app_env_keys.dart). Unset variables are skipped so
# the app's own defaults apply.
FLUTTER_DART_DEFINES=()
for name in ENVIRONMENT APP_NAME API_BASE_URL SUPABASE_URL SUPABASE_ANON_KEY; do
  if [ -n "${!name:-}" ]; then
    FLUTTER_DART_DEFINES+=("--dart-define=${name}=${!name}")
  fi
done

flutter build web --release ${FLUTTER_DART_DEFINES[@]+"${FLUTTER_DART_DEFINES[@]}"}
