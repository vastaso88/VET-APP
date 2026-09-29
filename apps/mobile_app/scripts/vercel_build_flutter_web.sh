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

FLUTTER_DART_DEFINES=()

if [ -n "${ENVIRONMENT:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=ENVIRONMENT=${ENVIRONMENT}")
fi

if [ -n "${APP_NAME:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=APP_NAME=${APP_NAME}")
fi

if [ -n "${SUPABASE_URL:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
fi

if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
fi

if [ -n "${API_BASE_URL:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
fi

if [ -n "${AUTH_REDIRECT_URL:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=AUTH_REDIRECT_URL=${AUTH_REDIRECT_URL}")
fi

# Internal testing phase: keep the development preview entry visible on Vercel
# unless it is explicitly disabled with ENABLE_UI_PREVIEW=false.
FLUTTER_DART_DEFINES+=("--dart-define=ENABLE_UI_PREVIEW=${ENABLE_UI_PREVIEW:-true}")

if [ -n "${DEMO_FOUNDER_EMAIL:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=DEMO_FOUNDER_EMAIL=${DEMO_FOUNDER_EMAIL}")
fi

if [ -n "${DEMO_FOUNDER_PASSWORD:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=DEMO_FOUNDER_PASSWORD=${DEMO_FOUNDER_PASSWORD}")
fi

if [ -n "${BILLING_WEB_URL:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=BILLING_WEB_URL=${BILLING_WEB_URL}")
fi

if [ -n "${ENABLE_MOBILE_BILLING_WEB_LINK:-}" ]; then
  FLUTTER_DART_DEFINES+=("--dart-define=ENABLE_MOBILE_BILLING_WEB_LINK=${ENABLE_MOBILE_BILLING_WEB_LINK}")
fi

flutter build web --release "${FLUTTER_DART_DEFINES[@]}"
