#!/usr/bin/env bash
set -euo pipefail

if [ -z "${APPIMAGE:-}" ]; then
  build_dir=$(cd "$(dirname "$0")"/../../dist/appimage/build 2>/dev/null && pwd || true)
  if [ -n "$build_dir" ]; then
    found=$(cd "$build_dir" && ls -1 Asbru-*.AppImage 2>/dev/null | head -n1 || true)
    if [ -n "$found" ]; then
      APPIMAGE="$build_dir/$found"
    else
      APPIMAGE=""
    fi
  else
    APPIMAGE=""
  fi
fi
if [ -z "$APPIMAGE" ] || [ ! -f "$APPIMAGE" ]; then
  echo "AppImage not found. Set APPIMAGE env or place it under dist/appimage/build." >&2
  exit 1
fi

run_cmd=("$APPIMAGE")

# Prefer X if available; otherwise try Xvfb
if [ -z "${DISPLAY:-}" ]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    echo "[app-smoke] Using Xvfb (xvfb-run)"
    run_cmd=(xvfb-run -a -s "-screen 0 1280x800x24" "$APPIMAGE")
  else
    echo "[app-smoke] No DISPLAY and no xvfb-run found; cannot run GUI smoke test" >&2
    exit 2
  fi
fi

echo "[app-smoke] Launching: ${run_cmd[*]}"
ASBRU_LOG_LEVEL=${ASBRU_LOG_LEVEL:-INFO} "${run_cmd[@]}" &
pid=$!
sleep 5
if ps -p $pid >/dev/null 2>&1; then
  echo "[app-smoke] App started successfully; terminating to finish the smoke test"
  kill $pid || true
  wait $pid || true
  exit 0
else
  echo "[app-smoke] App exited early; check logs above"
  exit 3
fi