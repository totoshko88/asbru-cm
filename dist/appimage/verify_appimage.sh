#!/usr/bin/env bash

# CI-like verification for Asbru-CM AppImage
# - Ensures perl has PT_INTERP set to /lib/ld-musl-x86_64.so.1 (musl) or /usr/glibc-compat/lib/ld-linux-x86-64.so.2 (glibc)
# - Ensures GTK loaders and immodules caches exist and reference ./usr/lib paths

set -euo pipefail
IFS=$'\n\t'

APPIMG="${1:-}"
if [[ -z "${APPIMG}" || ! -f "${APPIMG}" ]]; then
  echo "Usage: $0 /path/to/Asbru-CM.AppImage" >&2
  exit 2
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found in PATH" >&2; exit 3; }; }

need readelf || true

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

pushd "$TMPDIR" >/dev/null

"${APPIMG}" --appimage-extract >/dev/null 2>&1 || {
  echo "ERROR: Failed to extract AppImage (needs executable bit and compatible runtime)" >&2
  exit 4
}

ROOT="$TMPDIR/squashfs-root"
[[ -d "$ROOT" ]] || { echo "ERROR: squashfs-root not found after extraction" >&2; exit 4; }

PERL_BIN="$ROOT/usr/bin/perl"
[[ -e "$PERL_BIN" ]] || { echo "ERROR: perl not found at usr/bin/perl" >&2; exit 5; }

FILE_OUT="$(file -b "$PERL_BIN" 2>/dev/null || true)"
if echo "$FILE_OUT" | grep -qi 'ELF'; then
  if command -v readelf >/dev/null 2>&1; then
    if ! readelf -l "$PERL_BIN" | grep -qE "Requesting program interpreter: (/lib/ld-musl-x86_64.so.1|/usr/glibc-compat/lib/ld-linux-x86-64.so.2)"; then
      echo "ERROR: PT_INTERP for perl is not a known in-image loader (musl/glibc)" >&2
      readelf -l "$PERL_BIN" | sed 's/^/  /'
      exit 6
    fi
  else
    echo "WARN: readelf not available; skipping PT_INTERP check for perl" >&2
  fi
else
  echo "WARN: usr/bin/perl is not an ELF binary (file: $FILE_OUT); skipping PT_INTERP check" >&2
fi

# GTK caches
IMCACHE="$ROOT/usr/lib/gtk-3.0/3.0.0/immodules.cache"
LOADERSCACHE="$ROOT/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"

[[ -f "$IMCACHE" ]] || { echo "ERROR: GTK immodules.cache not found" >&2; exit 7; }
[[ -f "$LOADERSCACHE" ]] || { echo "ERROR: GDK Pixbuf loaders.cache not found" >&2; exit 8; }

if ! grep -q "./usr/lib" "$IMCACHE"; then
  echo "ERROR: immodules.cache does not contain './usr/lib' paths (expected patched relative paths)" >&2
  head -n 5 "$IMCACHE" | sed 's/^/  /'
  exit 9
fi

if ! grep -q "./usr/lib" "$LOADERSCACHE"; then
  echo "ERROR: loaders.cache does not contain './usr/lib' paths (expected patched relative paths)" >&2
  head -n 5 "$LOADERSCACHE" | sed 's/^/  /'
  exit 10
fi

# Optional: presence of bundled busybox used by AppRun
if [[ ! -x "$ROOT/usr/bin/busybox" ]]; then
  echo "WARN: busybox not found (AppRun will fall back to system sh); not fatal" >&2
fi

echo "VERIFY PASS: AppImage integrity checks succeeded"
