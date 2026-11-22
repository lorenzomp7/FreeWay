#!/usr/bin/env bash
# Installa Flutter in ~/flutter nelle sessioni cloud e scarica le dipendenze del progetto.
# Uso: flutter_sdk.sh VERSIONE   (es. 3.47.0, la stessa usata in CI)
set -uo pipefail
STATUS_FILE=${STATUS_FILE:-/dev/null}
VERSION=${1:?versione di Flutter}
DIR=${FLUTTER_ROOT_DIR:-$HOME/flutter}
fail() { echo "ERRORE: $1"; echo "failed: $1" > "$STATUS_FILE"; exit 1; }

if [ ! -x "$DIR/bin/flutter" ]; then
  echo "Scarico Flutter $VERSION da GitHub"
  rm -rf "$DIR"
  git clone -q --depth 1 --branch "$VERSION" https://github.com/flutter/flutter.git "$DIR" \
    || fail "download di Flutter $VERSION da GitHub non riuscito"
fi
git config --global --add safe.directory "$DIR" 2>/dev/null || true
export PATH="$DIR/bin:$PATH" FLUTTER_SUPPRESS_ANALYTICS=true CI=true

# Il primo avvio scarica l'SDK Dart da storage.googleapis.com.
flutter config --no-analytics > /dev/null 2>&1 || true
flutter --version || fail "avvio di Flutter non riuscito (serve storage.googleapis.com)"
flutter precache --web || fail "download degli strumenti web di Flutter non riuscito"
(cd "$CLAUDE_PROJECT_DIR" && flutter pub get) || fail "flutter pub get non riuscito (serve pub.dev)"
echo ready > "$STATUS_FILE"
echo "Flutter pronto in $DIR"
