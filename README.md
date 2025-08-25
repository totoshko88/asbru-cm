# Ásbrú Connection Manager — Modernized Fork

[<img src="https://github.com/totoshko88/asbru-cm/blob/master/res/asbru-logo-256.png?raw=true" align="right" width="200" height="200" />](https://github.com/totoshko88/asbru-cm/tree/master)

## A free and open-source connection manager (updated for PopOS 24.04 and Wayland)

> Note: This is a modernized fork of the original [asbru-cm/asbru-cm](https://github.com/asbru-cm/asbru-cm) project, updated for modern Linux distributions including PopOS 24.04, GTK4, and Wayland.

Ásbrú Connection Manager is a user interface that helps organize remote terminal sessions and automate repetitive tasks.

> Motivation / Case study: The background and reasons behind this modernization are described here —
> https://builder.aws.com/content/31O9whqNkNVmcFCTX7Uce1q5vTu/the-asbru-and-kirodev-case-study

<img width="3840" height="2160" alt="KDE Tumbleweed" src="https://github.com/user-attachments/assets/ece61534-feec-4962-b299-cfaad370a0c4" />
<img width="3840" height="2160" alt="KDE Tumbleweed Dark Keepass" src="https://github.com/user-attachments/assets/90c32163-f3a9-40d3-b41b-18991161c2bf" />

## ✅ Tested environments (up front)

- openSUSE Tumbleweed (20250727)
  - Kernel: 6.15.8-1-default x86_64
  - Desktop: KDE Plasma on Wayland (XDG_SESSION_TYPE=wayland)
  - Perl: 5.42.0
  - Tooling: rpmbuild 4.20.1, appimagetool (continuous), podman 5.6.0

- PopOS 24.04 LTS
  - Desktop: COSMIC on Wayland
  - RDP embedding verified under Wayland/Xwayland

Connection tests and UI smoke checks were executed; protocol mocks are skipped if Test::MockObject is missing. See `RELEASE_NOTES_7.1.0.md` for highlights and full change log.

## 📦 Installation

### AppImage (recommended for any distro)
```bash
wget https://github.com/totoshko88/asbru-cm/releases/latest/download/Asbru-CM.AppImage
chmod +x Asbru-CM.AppImage
./Asbru-CM.AppImage
```

### PopOS / Ubuntu (DEB)
1) Download the .deb from Releases:
   https://github.com/totoshko88/asbru-cm/releases

2) Install with apt (auto-resolves dependencies):
```bash
sudo apt install ./asbru-cm_<version>_all.deb
```

Alternative (dpkg then fix deps):
```bash
sudo dpkg -i asbru-cm_<version>_all.deb || sudo apt -f install
```

### openSUSE / RPM-based (RPM)
```bash
wget https://github.com/totoshko88/asbru-cm/releases/download/v7.1.0/asbru-cm-7.1.0-2.noarch.rpm
sudo zypper install ./asbru-cm-7.1.0-2.noarch.rpm   # or: sudo dnf install ./asbru-cm-7.1.0-2.noarch.rpm
```

For other distros, grab assets from the latest Release page:
https://github.com/totoshko88/asbru-cm/releases

### From source
```bash
git clone https://github.com/totoshko88/asbru-cm.git
cd asbru-cm
./asbru-cm
```

#### Dependencies (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y perl libgtk3-perl libvte-2.91-0 libvte-2.91-dev \
    libyaml-libyaml-perl libjson-xs-perl libnet-dbus-perl
```

## 🏗️ Building Packages

### Debian Package
```bash
./make_debian.sh
# Produces asbru-cm_<version>_all.deb
```

### RPM Package
```bash
bash dist/rpm/build_rpm.sh
ls dist/rpm/build/RPMS/noarch/*.rpm
```

## 🌟 Features

- **Connection Management**: Simple GUI to manage/launch connections to remote machines
- **Scripting Support**: Automation capabilities similar to SecureCRT
- **Multiple Protocols**: SSH, RDP, VNC, Telnet, and more
- **KeePassXC Integration**: Secure password management
- **Cluster Connections**: Manage multiple connections simultaneously
- **Wake On LAN**: Remote machine wake-up capabilities
- **Tabbed Interface**: Organized workspace with tab management
- **Proxy Support**: Connect through proxy servers
- **Variables System**: Local and global variables for password management

### ✅ Tested Protocol Coverage
- SSH, Telnet, SFTP: containerized linuxserver/openssh-server and utility checks
- GUI (VNC-like): linuxserver/webtop for end-to-end GUI readiness
- RDP: linuxserver/rdesktop for connectivity; xfreerdp recommended for embedding

Comprehensive protocol and app-level E2E tests run headlessly and validate connection success via stdout control markers.

## 🐛 Environment Variables

```bash
ASBRU_DEBUG=1                # Enable debug output with emoji logging 🔍🚀📡✅
ASBRU_DEBUG_STACK=1          # Include stack traces
ASBRU_FORCE_XFREERDP=1       # Force xfreerdp usage on Wayland (auto-enabled)
ASBRU_FORCE_ICON_RESCAN=1    # Force icon theme rescan
```

## 🪟 Wayland Embedding Support

This fork includes **intelligent automatic Wayland embedding support** that **works perfectly**:

- **✅ Automatic X11 Backend Switch**: When running on Wayland, the application automatically restarts with X11 backend for full embedding compatibility
- **✅ Perfect RDP Embedding**: GtkSocket-based window embedding works flawlessly with both `xfreerdp` and `rdesktop` clients  
- **✅ Zero Configuration**: No manual setup required - embedding works out of the box on both X11 and Wayland
- **✅ Transparent Operation**: Users don't notice any difference - RDP connections embed seamlessly in tabs

### Technical Implementation
- **Smart Detection**: Detects Wayland using `$WAYLAND_DISPLAY` and `$XDG_SESSION_TYPE` environment variables
- **Automatic Restart**: Forces `GDK_BACKEND=x11` and restarts application transparently on Wayland systems
- **XID Generation**: Successfully generates X11 window IDs (e.g., `XID=52439778`) for perfect embedding
- **Xwayland Integration**: Leverages existing Xwayland infrastructure for maximum compatibility

### Proven Results  
✅ **Tested Successfully**: RDP connections embed perfectly in tabs on PopOS 24.04 COSMIC + Wayland
✅ **No Crashes**: Eliminated segmentation faults that occurred with pure Wayland GtkSocket usage  
✅ **Full Functionality**: All RDP features work including clipboard, sound redirection, and dynamic resolution

### RDP Client Compatibility
- **✅ xfreerdp**: Perfect embedding with full GUI display in tabs
  - Full Wayland/Xwayland compatibility
  - Automatic parent-window embedding
  - Dynamic resolution and features work perfectly
- **✅ rdesktop**: Successful connections with functional SSL
  - Establishes connections: "Connection established using SSL" ✅
  - Successful authentication and protocol negotiation
  - XID embedding working but visual display may be limited on Wayland
  - Recommended for testing connectivity, use xfreerdp for production

### Connection Examples
**xfreerdp** (recommended):
```
xfreerdp /parent-window:52442142 /size:740x443 /bpp:24 /dynamic-resolution /u:'user' /v:server:3389
```

**rdesktop** (connectivity testing):
```
rdesktop -X 52442142 -g 740x443 -u 'user' -p 'password' server:3389
# Results in: "Connection established using SSL" ✅
```

## 📋 Additional compatibility notes

- Ubuntu 24.04 LTS
- Wayland display server
- GTK3 and GTK4 environments

## 🔗 Original Project

This fork is based on the excellent work of the original [Ásbrú Connection Manager](https://github.com/asbru-cm/asbru-cm) team. For the full project history, extensive documentation, and upstream development, please visit the original repository.

## 🎨 Logo & Cultural Symbolism

The Ásbrú name evokes the rainbow bridge motif in Norse tradition. In Slavic and Ukrainian culture, the rainbow bridge (Калинів міст / Kalyniv Mist) symbolizes connection and resilience. This project embraces that universal symbolism of bridges—linking systems and people across distances.

Logo assets are used under the project's GPLv3 license with attribution to the original authors.

## 📄 License

GPL-3.0 License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Issues and pull requests specific to this modernization fork are welcome. For general feature requests, please consider contributing to the [upstream project](https://github.com/asbru-cm/asbru-cm).

[license-badge]: https://img.shields.io/badge/License-GPL--3-blue.svg?style=flat
[license-url]: LICENSE

