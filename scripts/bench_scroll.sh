#!/usr/bin/env bash
# Device-agnostic Markread scroll bench.
#
# Finds an adb device, builds/installs a profile APK with MARKREAD_AUTO_BENCH,
# launches the app, then captures flutter logs while you open a large markdown
# file. Once the viewer loads rendered markdown, in-app natural goBallistic
# flings run automatically (same physics as a finger).
#
# Prerequisites:
#   - Device unlocked, USB debugging on
#   - A large markdown file available on-device (or open via share / file picker)
#   - flutter + adb on PATH
#
# Usage:
#   ./scripts/bench_scroll.sh
#   ./scripts/bench_scroll.sh <serial>
#   WAIT_SEC=30 ./scripts/bench_scroll.sh
#   SKIP_BUILD=1 ./scripts/bench_scroll.sh   # reuse installed APK
#
# Env:
#   WAIT_SEC=30               seconds after launch (covers open + auto flings)
#   PKG=now.link.markread
#   OUT_DIR=/tmp
#   FORCE_120=0               best-effort system peak/min refresh (often denied)
#   SETTLE_SEC=1.2            post-launch settle
#   SKIP_BUILD=0              set 1 to skip flutter build + install
#   REBUILD=1                 force flutter build even if APK exists (default 1)
#
# Outputs:
#   $OUT_DIR/markread_bench_<timestamp>.log
#   summary via scripts/summarize_bench_log.py
#
# Note: FPS HUD is hidden by default; MARKREAD_AUTO_BENCH forces it on.

set -euo pipefail

PKG="${PKG:-now.link.markread}"
# Open + settle + multi-fling run needs more headroom than the old sample-button flow.
WAIT_SEC="${WAIT_SEC:-30}"
OUT_DIR="${OUT_DIR:-/tmp}"
FORCE_120="${FORCE_120:-0}"
SETTLE_SEC="${SETTLE_SEC:-1.2}"
SKIP_BUILD="${SKIP_BUILD:-0}"
REBUILD="${REBUILD:-1}"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="${OUT_DIR}/markread_bench_${TS}.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APK_PATH="${REPO_DIR}/build/app/outputs/flutter-apk/app-profile.apk"
WORK="${OUT_DIR}/markread_bench_work_${TS}"
mkdir -p "$WORK"

# --- adb device discovery ---------------------------------------------------

list_adb_devices() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}'
}

resolve_serial() {
  local requested="${1:-}"
  local devices=()
  local d

  while IFS= read -r d; do
    [[ -n "$d" ]] && devices+=("$d")
  done < <(list_adb_devices)

  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No adb device in 'device' state." >&2
    echo "Connect USB debugging (unlocked) and check: adb devices" >&2
    adb devices -l >&2 || true
    exit 1
  fi

  if [[ -n "$requested" ]]; then
    for d in "${devices[@]}"; do
      if [[ "$d" == "$requested" ]]; then
        echo "$d"
        return 0
      fi
    done
    echo "Requested serial not online: $requested" >&2
    echo "Online devices:" >&2
    for d in "${devices[@]}"; do
      local model
      model="$(adb -s "$d" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
      echo "  $d  ${model:-?}" >&2
    done
    exit 1
  fi

  if [[ ${#devices[@]} -gt 1 ]]; then
    echo "Multiple adb devices online; pass serial or set DEVICE_SERIAL:" >&2
    for d in "${devices[@]}"; do
      local model release
      model="$(adb -s "$d" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
      release="$(adb -s "$d" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)"
      echo "  $d  model=${model:-?}  android=${release:-?}" >&2
    done
    exit 1
  fi

  echo "${devices[0]}"
}

if [[ $# -ge 1 ]]; then
  SERIAL_REQ="$1"
elif [[ -n "${DEVICE_SERIAL:-}" ]]; then
  SERIAL_REQ="$DEVICE_SERIAL"
else
  SERIAL_REQ=""
fi

SERIAL="$(resolve_serial "$SERIAL_REQ")"
ADB=(adb -s "$SERIAL")
MODEL="$("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
echo "Using device: $SERIAL  model=${MODEL:-?}"
echo "log: $LOG"
echo

# Probe whether adb input injection works (some OEMs block it).
INPUT_OK=0
if "${ADB[@]}" shell input tap 1 1 >/dev/null 2>&1; then
  INPUT_OK=1
fi
echo "adb input injection: $([[ "$INPUT_OK" == "1" ]] && echo ok || echo blocked)"

# --- build / install --------------------------------------------------------

if [[ "$SKIP_BUILD" != "1" ]]; then
  if [[ "$REBUILD" == "1" || ! -f "$APK_PATH" ]]; then
    echo "-- flutter build apk --profile (MARKREAD_AUTO_BENCH=true) --"
    (
      cd "$REPO_DIR"
      flutter build apk --profile \
        --dart-define=MARKREAD_AUTO_BENCH=true
    )
  else
    echo "-- reusing existing APK: $APK_PATH --"
  fi
  echo "-- installing --"
  "${ADB[@]}" install -r "$APK_PATH"
  echo
else
  echo "-- SKIP_BUILD=1; using installed $PKG --"
  echo
fi

if [[ "$FORCE_120" == "1" ]]; then
  echo "-- forcing system peak/min refresh 120 (best-effort) --"
  "${ADB[@]}" shell settings put system peak_refresh_rate 120.0 || true
  "${ADB[@]}" shell settings put system min_refresh_rate 120.0 || true
  "${ADB[@]}" shell settings get system peak_refresh_rate || true
  "${ADB[@]}" shell settings get system min_refresh_rate || true
  echo
fi

launch_app() {
  "${ADB[@]}" shell am force-stop "$PKG" >/dev/null 2>&1 || true
  sleep 0.4
  "${ADB[@]}" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep "$SETTLE_SEC"
}

# Start log capture for whole session
"${ADB[@]}" logcat -c
"${ADB[@]}" logcat -v time '*:S' flutter:V >"$LOG" 2>&1 &
LOGPID=$!
cleanup() {
  kill "$LOGPID" 2>/dev/null || true
}
trap cleanup EXIT

echo "== launch + wait ${WAIT_SEC}s =="
echo "Open a large markdown file on the device (Open File / share-to-app)."
echo "With MARKREAD_AUTO_BENCH, the viewer auto-flings after load; FPS HUD is on."
launch_app
sleep "$WAIT_SEC"
echo "active refresh after wait:"
"${ADB[@]}" shell dumpsys display 2>/dev/null \
  | rg -i "mActiveModeId=|mActiveRenderFrameRate=" | head -8 || true

cleanup
trap - EXIT

echo
echo "== log written: $LOG =="
for t in bench bench-md bench-deep bench-frame bench-scroll; do
  echo "$t: $(rg -c "\[$t\]" "$LOG" || echo 0)"
done
echo

if [[ -f "${REPO_DIR}/scripts/summarize_bench_log.py" ]]; then
  python3 "${REPO_DIR}/scripts/summarize_bench_log.py" "$LOG" || true
else
  rg '\[bench\]' "$LOG" | tail -20 || true
fi

echo
echo "Done. Re-summarize:"
echo "  python3 scripts/summarize_bench_log.py $LOG"
