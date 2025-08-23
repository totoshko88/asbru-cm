#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

# Pick a compose runner that works in this environment (docker, podman, or docker-compose)
if command -v docker >/dev/null 2>&1 && docker --help | grep -q "compose"; then
  COMPOSE=(docker compose)
elif command -v podman >/dev/null 2>&1 && podman help | grep -q "compose"; then
  COMPOSE=(podman compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "No compose-capable CLI found (need docker compose, podman compose, or docker-compose)" >&2
  exit 1
fi

echo "[e2e] Starting protocol containers (linuxserver/xrdp and linuxserver/webtop)"
"${COMPOSE[@]}" up -d

echo "[e2e] Waiting for RDP on 3389..."
for i in {1..30}; do
  if timeout 1 bash -lc 'echo > /dev/tcp/127.0.0.1/3389' 2>/dev/null; then
    echo "[e2e] RDP port is open"
    break
  fi
  sleep 1
done

echo "[e2e] Waiting for WebTop noVNC on 3000..."
for i in {1..60}; do
  if curl -fsS http://127.0.0.1:3000/ >/dev/null; then
    echo "[e2e] WebTop UI is reachable at http://127.0.0.1:3000"
    break
  fi
  sleep 1
done

echo "[e2e] Optional: probing VNC on 5901 (may not be enabled)"
if timeout 1 bash -lc 'echo > /dev/tcp/127.0.0.1/5901' 2>/dev/null; then
  echo "[e2e] VNC port 5901 appears open"
else
  echo "[e2e] VNC port 5901 not open; use the web UI on port 3000 for desktop access"
fi

cat <<EOF

Next steps:
- In Ásbrú, add an RDP connection to host 127.0.0.1:3389.
  Credentials (defaults): USER=tester PASSWORD=Passw0rd!
- For VNC testing, prefer the WebTop UI at http://127.0.0.1:3000.
  If 5901 is open, you can also add a VNC connection to 127.0.0.1:5901.

To stop and clean up: ${COMPOSE[*]} down -v
EOF