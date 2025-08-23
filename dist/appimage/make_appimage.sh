#!/bin/bash

# This file should be ran from the project's root directory as cwd.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# http://redsymbol.net/articles/unofficial-bash-strict-mode/ ;)
set -euo pipefail
IFS=$'\n\t'

# Too much output can't hurt, it's Bash.
set -x

# Select container engine: prefer docker, fallback to podman
ENGINE=""
if command -v docker >/dev/null 2>&1; then
	ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
	ENGINE="podman"
else
	echo "Error: neither docker nor podman found in PATH. Install one to build AppImage." >&2
	exit 1
fi

echo "Using container engine: $ENGINE" >&2

$ENGINE build --tag=asbru-cm-appimage-maker --file=dist/appimage/Dockerfile .

mkdir -p "${SCRIPT_DIR}/build"

CIDFILE_PATH="${SCRIPT_DIR}/build/appimage-maker.cid"

rm -f "${CIDFILE_PATH}"

RUN_PRIV="--privileged=true"
# Podman often doesn't require --privileged for this flow; keep for docker only
if [ "$ENGINE" = "podman" ]; then
	RUN_PRIV=""
fi

$ENGINE run --cidfile "${CIDFILE_PATH}" $RUN_PRIV -i asbru-cm-appimage-maker /bin/sh < "${SCRIPT_DIR}/container_make_appimage.sh"

CONTAINER_ID="$(cat "${CIDFILE_PATH}")"
rm -f "${CIDFILE_PATH}"

APPIMAGE_DESTINATION="${SCRIPT_DIR}/build/Asbru-CM.AppImage"

rm -f "${APPIMAGE_DESTINATION}"
$ENGINE cp "${CONTAINER_ID}:/Asbru-CM.AppImage" "${APPIMAGE_DESTINATION}"

$ENGINE rm "${CONTAINER_ID}" >/dev/null 2>&1 || true

chmod a+x "${APPIMAGE_DESTINATION}"
