# Ásbrú Connection Manager v7.0.1 - System Requirements and Compatibility

## Overview

Ásbrú Connection Manager v7.0.1 is the latest critical stability release designed for modern Linux distributions with enhanced Wayland compatibility and improved application stability. This version includes critical fixes for PopOS 24.04 and Cosmic desktop environment. This document outlines system requirements, compatibility information, and platform-specific considerations.

## Minimum System Requirements

### Hardware Requirements
- **CPU**: Any x86_64, ARM64, or compatible architecture
- **RAM**: 512 MB minimum, 1 GB recommended
- **Storage**: 50 MB for application files, 100 MB total with dependencies
- **Network**: Required for remote connections (SSH, RDP, VNC, etc.)

### Software Requirements
- **Operating System**: Linux distribution with kernel 5.4+
- **Init System**: systemd (recommended) or compatible
- **Package Manager**: APT (for DEB installation) or compatible
- **Display Server**: Wayland (recommended) or X11
- **Desktop Environment**: Any modern DE (Cosmic, GNOME, KDE, XFCE, etc.)

## Recommended System Configuration

### Optimal Setup
- **OS**: PopOS 24.04 LTS with latest updates
- **Desktop**: Cosmic desktop environment
- **Display**: Wayland with hardware acceleration
- **RAM**: 2 GB or more for multiple connections
- **Storage**: SSD for better performance

### Performance Considerations
- **Multiple Connections**: 1 GB RAM + 100 MB per active connection
- **Large Terminals**: Additional RAM for scrollback buffers
- **File Transfers**: Adequate disk space for temporary files

## Platform Compatibility Matrix

### Primary Supported Platforms ✅

| Distribution | Version | Desktop | Status | Notes |
|--------------|---------|---------|--------|-------|
| PopOS | 24.04 LTS | Cosmic | Full Support | Primary target platform |
| PopOS | 24.04 LTS | GNOME | Full Support | Fallback DE support |
| Ubuntu | 24.04 LTS | GNOME | Full Support | Upstream compatibility |
| Ubuntu | 24.04 LTS | KDE | Full Support | Plasma integration |

### Secondary Supported Platforms ⚠️

| Distribution | Version | Desktop | Status | Notes |
|--------------|---------|---------|--------|-------|
| PopOS | 22.04 LTS | GNOME | Limited | GTK3 fallback mode |
| Ubuntu | 22.04 LTS | GNOME | Limited | Older dependencies |
| Fedora | 40+ | GNOME | Experimental | Manual dependency install |
| Debian | 12+ | Various | Experimental | May require backports |

### Unsupported Platforms ❌

| Distribution | Version | Reason | Alternative |
|--------------|---------|--------|-------------|
| Ubuntu | < 22.04 | GTK/Perl too old | Use v6.4.1 |
| CentOS | 7/8 | EOL/outdated deps | Use RHEL 9+ |
| Arch Linux | Rolling | Untested | Build from source |

## Dependency Requirements

### Core Dependencies (Required)

#### Perl Runtime
- **perl** (>= 5.32)
- **libglib-perl**
- **libcairo-perl**
- **libpango-perl**

#### GUI Framework
- **libgtk4-1** (>= 4.10) OR **libgtk-3-0** (>= 3.24)
- **libgtk4-perl** OR **libgtk3-perl**
- **libadwaita-1-0** (>= 1.4) - for modern theming
- **libgtk4-simplelist-perl** OR **libgtk3-simplelist-perl**

#### Terminal Emulation
- **libvte-2.91-gtk4-0** (preferred) OR **libvte-2.91-0**
- **gir1.2-vte-3.0** OR **gir1.2-vte-2.91**

#### Cryptography and Security
- **libcrypt-cbc-perl**
- **libcrypt-cipher-aes-perl** (modern encryption)
- **libcrypt-pbkdf2-perl** (key derivation)
- **libcrypt-rijndael-perl** (legacy compatibility)
- **libcrypt-x509-perl** (certificate handling)

#### Network and Protocols
- **libsocket6-perl** (IPv6 support)
- **libnet-arp-perl**
- **libio-socket-ssl-perl**
- **libnet-ssleay-perl**
- **openssh-client**

#### Data Handling
- **libyaml-perl**
- **libxml-parser-perl**
- **libfile-which-perl**
- **libossp-uuid-perl**

#### System Integration
- **xdg-desktop-portal** (Wayland file dialogs)
- **libcanberra-gtk3-module** OR **libcanberra-gtk-module**

### Optional Dependencies (Recommended)

#### Password Management
- **keepassxc** (KeePass integration)

#### Connection Protocols
- **freerdp2-wayland** OR **freerdp-x11** OR **rdesktop** (RDP)
- **tigervnc-viewer** OR **xtightvncviewer** (VNC)
- **mosh** (mobile shell)
- **ncat** OR **nmap** (network tools)

#### Legacy Support
- **cu** OR **remote-tty** (serial connections)
- **telnet** (Telnet protocol)
- **ftp** (FTP protocol)

#### Testing and Development
- **libx11-guitest-perl** (GUI testing)

## Desktop Environment Compatibility

### Cosmic Desktop (PopOS 24.04)
- **Status**: Full native support
- **Features**:
  - Native panel integration (when available)
  - Workspace-aware window management
  - Automatic theme synchronization
  - Tiling window manager support
- **Requirements**: PopOS 24.04 with Cosmic session

### GNOME (Wayland/X11)
- **Status**: Full support
- **Features**:
  - Portal-based file dialogs
  - System tray integration
  - Notification support
  - Theme compatibility
- **Requirements**: GNOME 42+ recommended

### KDE Plasma
- **Status**: Full support
- **Features**:
  - System tray integration
  - KWallet support (optional)
  - Plasma theme compatibility
  - Activities integration
- **Requirements**: Plasma 5.24+ recommended

### XFCE
- **Status**: Compatible
- **Features**:
  - System tray support
  - Basic theme integration
  - Panel integration
- **Requirements**: XFCE 4.16+ recommended

### Other Desktop Environments
- **MATE**: Compatible with basic features
- **Cinnamon**: Compatible with system tray
- **LXQt**: Basic compatibility
- **i3/Sway**: Terminal-focused usage

## Display Server Compatibility

### Wayland (Recommended)
- **Status**: Native support
- **Benefits**:
  - Enhanced security isolation
  - Better multi-monitor support
  - Improved clipboard handling
  - Modern input methods
- **Requirements**:
  - Wayland compositor
  - xdg-desktop-portal
  - Portal backend for DE

### X11 (Fallback)
- **Status**: Full compatibility
- **Features**:
  - Traditional window management
  - System tray support
  - Screen sharing
  - Legacy application support
- **Use Cases**:
  - Older hardware
  - Legacy applications
  - Remote desktop scenarios

## Architecture Support

### x86_64 (amd64)
- **Status**: Primary architecture
- **Testing**: Comprehensive
- **Performance**: Optimal

### ARM64 (aarch64)
- **Status**: Supported
- **Testing**: Basic validation
- **Performance**: Good on modern ARM

### Other Architectures
- **i386**: Not recommended (32-bit limitations)
- **armhf**: Possible but untested
- **RISC-V**: Experimental (Perl/GTK dependent)

## Version Compatibility

### Upgrade Paths

#### From v6.4.1 to v7.0.0
- **Configuration**: Automatic migration
- **Connections**: Preserved
- **Passwords**: Re-encrypted with modern algorithms
- **Themes**: May require adjustment

#### From Earlier Versions
- **v6.x**: Supported with migration
- **v5.x**: Manual migration recommended
- **v4.x and earlier**: Not supported

### Downgrade Considerations
- **Configuration**: May not be compatible
- **Encryption**: Passwords need re-entry
- **Features**: Some modern features unavailable

## Performance Benchmarks

### Startup Time
- **Cold start**: < 3 seconds (SSD, modern CPU)
- **Warm start**: < 1 second
- **Memory usage**: ~50 MB base + ~10 MB per connection

### Connection Performance
- **SSH**: Near-native performance
- **RDP**: Depends on client (freerdp2-wayland recommended)
- **VNC**: Good with hardware acceleration

### Resource Usage
- **CPU**: Low idle, moderate during connections
- **Memory**: Scales with number of connections
- **Network**: Minimal overhead

## Security Considerations

### Modern Security Features
- **Encryption**: AES-256-GCM for password storage
- **Key Derivation**: PBKDF2 with salt
- **Network**: TLS 1.3 support
- **Certificates**: Modern validation

### Wayland Security Benefits
- **Application Isolation**: Enhanced sandbox
- **Input Security**: Protected keylogging prevention
- **Screen Capture**: Permission-based access
- **Clipboard**: Secure inter-app communication

### System Integration
- **Keyring**: GNOME Keyring, KDE Wallet support
- **Audit**: Enhanced logging capabilities
- **Permissions**: Minimal privilege requirements

## Installation Size Requirements

### Package Sizes
- **DEB Package**: ~465 KB
- **Installed Size**: ~3.6 MB
- **Dependencies**: ~50-100 MB (varies by system)
- **Configuration**: ~1-10 MB (depends on usage)

### Disk Space Planning
- **Minimum**: 100 MB free space
- **Recommended**: 500 MB for updates and logs
- **Heavy Usage**: 1 GB+ for screenshots and logs

## Network Requirements

### Protocols Supported
- **SSH**: Port 22 (configurable)
- **RDP**: Port 3389 (configurable)
- **VNC**: Ports 5900-5999 (configurable)
- **Telnet**: Port 23 (configurable)
- **FTP/SFTP**: Ports 21/22 (configurable)

### Firewall Considerations
- **Outbound**: Allow connections to target ports
- **Inbound**: Not required (client application)
- **Proxy**: HTTP/SOCKS proxy support available

## Troubleshooting Compatibility

### Common Issues
1. **GTK4 not available**: Falls back to GTK3
2. **VTE version mismatch**: Uses available version
3. **Wayland portal missing**: Falls back to X11 dialogs
4. **Theme incompatibility**: Uses default theme

### Compatibility Testing
```bash
# Quick compatibility check
./check_compatibility.sh

# Detailed system analysis
./system_analysis.sh > system_report.txt
```

## Future Compatibility

### Planned Support
- **GTK5**: When available
- **Wayland protocols**: New standards
- **Modern distributions**: Rolling updates

### Deprecation Timeline
- **GTK3**: Supported until 2026
- **X11**: Supported indefinitely
- **Older distributions**: Case-by-case basis

---

For the most up-to-date compatibility information, please check the project documentation and GitHub releases page.