#!/usr/bin/env bash
# Install/run MarkRead in profile mode on a device (Skia forced via manifest
# and CLI flag). Leaves the app running for manual or scripted bench.
#
# Usage:
#   ./scripts/run_profile.sh
#   ./scripts/run_profile.sh <serial>
#   AUTO_BENCH=1 ./scripts/run_profile.sh   # pass MARKREAD_AUTO_BENCH=true

set -euo pipefail

SERIAL="${1:-${DEVICE_SERIAL:-}}"
if [[ -z "$SERIAL" ]]; then
  SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
if [[ -z "$SERIAL" ]]; then
  echo "No device serial." >&2
  exit 1
fi

cd "$(dirname "$0")/.."

DEFINE_ARGS=()
if [[ "${AUTO_BENCH:-0}" == "1" ]]; then
  DEFINE_ARGS+=(--dart-define=MARKREAD_AUTO_BENCH=true)
  echo "MARKREAD_AUTO_BENCH=true (natural flings after open)"
fi

echo "Running profile build on $SERIAL (Impeller disabled)..."
flutter run -d "$SERIAL" --profile --no-enable-impeller "${DEFINE_ARGS[@]}"
