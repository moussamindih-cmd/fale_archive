#!/usr/bin/env bash
#
# Script de build Vercel pour l'app Flutter web.
# Vercel n'a pas Flutter préinstallé : on le clone (shallow, version pinnée
# sur celle utilisée en CI/dev) avant de builder.
#
set -euo pipefail

FLUTTER_VERSION="3.44.7"

if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" flutter
fi
export PATH="$PATH:$(pwd)/flutter/bin"

flutter config --no-analytics
flutter pub get

DART_DEFINES=()
if [[ -n "${SUPABASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
fi
if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi

flutter build web --release "${DART_DEFINES[@]}"
