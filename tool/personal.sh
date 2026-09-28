#!/usr/bin/env bash
# Runs a flutter command with the private guides bundled in.
#
#   tool/personal.sh run
#   tool/personal.sh build apk --release
#
# Private guides live in /private (git-ignored and NOT listed in pubspec), so a
# plain `flutter build` always produces the public app. This script copies them
# into assets/private/ only for the duration of the command and removes them on
# exit, so a personal build can never leak into a public one by accident.
set -euo pipefail

cd "$(dirname "$0")/.."

src=private
dst=assets/private

if [ $# -eq 0 ]; then
  echo "uso: tool/personal.sh <comando de flutter> [args...]" >&2
  exit 64
fi

cleanup() {
  find "$dst" -type f ! -name README.md -delete
}
trap cleanup EXIT INT TERM

# Start clean even if a previous run was killed before its trap fired.
cleanup
if compgen -G "$src/*.json" > /dev/null; then
  cp "$src"/*.json "$dst"/
else
  echo "aviso: $src/ no tiene guías; se compila sin ellas" >&2
fi

flutter "$@"
