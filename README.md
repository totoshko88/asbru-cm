# Ásbrú Connection Manager - Modernized Fork

[<img src="https://www.asbru-cm.net/assets/img/asbru-logo-200.png" align="right" width="200px" height="200px" />](https://asbru-cm.net)

## A free and open-source connection manager - Modernized for PopOS 24.04 and Wayland

> **Note**: This is a modernized fork of the original [asbru-cm/asbru-cm](https://github.com/asbru-cm/asbru-cm) project, updated to work with modern Linux distributions including PopOS 24.04, GTK4, and Wayland display servers.

**Ásbrú Connection Manager** is a user interface that helps organizing remote terminal sessions and automating repetitive tasks.

## 🚀 Why This Fork?

The original Ásbrú Connection Manager project has compatibility issues with modern Linux distributions. This fork addresses these problems and represents a real-world modernization success story.

> 📖 **Case Study**: Read about this modernization project in the AWS Builder Library: [The Ásbrú and KiroDev Case Study](https://builder.aws.com/content/31O9whqNkNVmcFCTX7Uce1q5vTu/the-asbru-and-kirodev-case-study) - Learn how legacy open-source projects can be revitalized for modern environments.

### 🔧 **Critical Fixes Applied**

- ✅ **Dark Theme Support**: Proper dark theme implementation with background and text color adaptation
- ✅ **Wayland Compatibility**: Full support for Wayland display servers including COSMIC desktop
- ✅ **GTK Warnings Eliminated**: Fixed critical GTK widget management issues that caused application crashes
- ✅ **RDP Embedding Enhanced**: Advanced window embedding with automatic Xwayland fallback for Wayland compatibility
- ✅ **Tab Management**: Fixed missing close buttons and tab creation issues
- ✅ **Tray Integration**: StatusNotifierItem (SNI) support for modern desktop environments

### 🆕 **Modern Features**

- **COSMIC Desktop Support**: Native integration with System76's COSMIC desktop environment
- **Enhanced Theme Detection**: Automatic system theme detection with 5-second caching for performance
- **Improved Error Handling**: Safe widget management preventing application freezes
- **Better Debugging**: Enhanced debug output for easier troubleshooting

## 📦 Quick Installation

### From Debian Package (Recommended)
```bash
wget https://github.com/totoshko88/asbru-cm/releases/latest/download/asbru-cm_7.0.1_all.deb
sudo dpkg -i asbru-cm_7.0.1_all.deb
sudo apt -f install  # Resolve dependencies if needed
```

### From Source
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

## 🐛 Environment Variables

```bash
ASBRU_DEBUG=1                # Enable debug output
ASBRU_DEBUG_STACK=1          # Include stack traces
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

## 📋 Tested On

- ✅ PopOS 24.04 LTS (COSMIC Desktop)
- ✅ Ubuntu 24.04 LTS
- ✅ Wayland display server
- ✅ GTK3 and GTK4 environments

## 🔗 Original Project

This fork is based on the excellent work of the original [Ásbrú Connection Manager](https://github.com/asbru-cm/asbru-cm) team. For the full project history, extensive documentation, and upstream development, please visit the original repository.

## 📄 License

GPL-3.0 License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Issues and pull requests specific to this modernization fork are welcome. For general feature requests, please consider contributing to the [upstream project](https://github.com/asbru-cm/asbru-cm).

[license-badge]: https://img.shields.io/badge/License-GPL--3-blue.svg?style=flat
[license-url]: LICENSE
