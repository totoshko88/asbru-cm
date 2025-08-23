# E2E protocol harness

This directory provides a minimal environment to exercise RDP and VNC flows locally using LinuxServer containers and to smoke-test Ásbrú against them.

Components:
- linuxserver/xrdp (RDP) on localhost:3389
- linuxserver/webtop:ubuntu-xfce (web/desktop via noVNC) on localhost:3000; optional raw VNC on 5901 if exposed by the tag

Usage:
1. Start services and run quick checks:
   ./smoke.sh
2. In Ásbrú, create connections:
   - RDP → host 127.0.0.1, port 3389, user tester, password Passw0rd!
   - VNC → prefer the WebTop UI at http://127.0.0.1:3000. If 5901 is open, you can also point a VNC connection at 127.0.0.1:5901.
3. Stop:
   docker compose down -v

Notes:
- WebTop is primarily web-based (noVNC on port 3000). Some tags may not expose a raw VNC server; the 5901 mapping is opportunistic.
- Adjust PUID/PGID/TZ and credentials via environment or a .env file as needed.
