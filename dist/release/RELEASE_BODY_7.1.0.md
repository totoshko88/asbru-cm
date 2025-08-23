# Ásbrú Connection Manager 7.1.0 — Hardened Runtime and Packaging

## Highlights
- Safer spawn/runtime: CORE-first Perl loader, sanitized env, robust quoting
- Global Proxy: empty means “use system default” (ALL_PROXY/HTTPS_PROXY/HTTP_PROXY/NO_PROXY)
- SSH formatting: destinations standardized as `user@host`
- AppImage polish: MUSL loader preference, GTK caches rebuilt, icon/desktop metadata validated
- Tests: category runner stabilized; protocols + performance green, GUI skipped if Gtk4 missing
- Packaging: RPM and AppImage builds validated; verification script added

## Downloads
- AppImage: Asbru-CM.AppImage
  - SHA256: 76511b4b77b3f64ce30b687d4d89f7c06ee7ca78462fc9fe0a8b044b8db88709
- RPM (noarch): asbru-cm-7.1.0-2.noarch.rpm
  - SHA256: 83d5395234e97c8cdf56f9a2da4b6ac89e7b67f0ddea0b35c3a5f46138482718

## Notes
- AppImage bundles AppStream metadata and correct Icon=asbru-cm.
- Wayland/Xwayland handling refined; X11 force action is available in the desktop file.
