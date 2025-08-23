# Ásbrú Connection Manager 7.1.0 (Modernization Fork)

Highlights:
- Wayland/Xwayland handling refined; defaults favor embedding compatibility.
- Icon system cleanup: SVG-first across themes with Adwaita fallback; PNG wrappers removed.
- Cosmic desktop integration guarded and optional; SNI/AppIndicator fallbacks.
- Packaging refresh: RPM/DEB specs updated; AppImage build scripts stabilized.

Tested on (local):
- Distro: openSUSE Tumbleweed 20250727
- Kernel: Linux 6.15.8-1-default x86_64
- Desktop: KDE (Wayland)
- Perl: 5.42.0
- AppImage tool: appimagetool continuous (5735cc5)
- rpmbuild: 4.20.1

Known notes:
- AppImage may print readline “no version information” from embedded glibc; harmless, mitigated in subprocess envs.
- Legacy GtkStatusIcon used on desktops without AppIndicator/SNI.

Packaging:
- RPM: dist/rpm/asbru.spec
- AppImage: dist/appimage/make_appimage.sh (requires Docker or Podman)# Ásbrú Connection Manager – Modernized Fork 7.1.0

Highlights:
- Wayland/Xwayland embedding refinements; stable RDP via xfreerdp
- Icon policy cleanup: SVG-first across themes; removed obsolete PNGs for targeted set
- Desktop integration: guarded Cosmic path; StatusNotifierItem optional
- Packaging: refreshed RPM spec; AppImage pipeline (podman/docker)

Tested environments:
- openSUSE Tumbleweed 20250727 (KDE Wayland), Perl 5.42.0
- PopOS 24.04 (COSMIC Wayland)

Build artifacts naming:
- RPM: asbru-cm-<version>-<release>.noarch.rpm
- AppImage: Asbru-CM.AppImage (container-made)

Notes:
- Optional module Test::MockObject is not required; related tests are skipped.
- Use ASBRU_DISABLE_COSMIC=1 to disable Cosmic-specific paths.
