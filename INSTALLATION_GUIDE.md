# Ásbrú Connection Manager v7.0.0 - Installation Guide

## Overview

This guide provides detailed installation instructions for Ásbrú Connection Manager v7.0.0, the modernized release with GTK4 support and Wayland compatibility, specifically optimized for PopOS 24.04 and modern Linux distributions.

## System Requirements

### Minimum Requirements
- **Operating System**: PopOS 24.04 LTS (primary target) or compatible Ubuntu-based distribution
- **Desktop Environment**: Cosmic (recommended), GNOME, KDE, or other modern DE
- **Display Server**: Wayland (recommended) or X11
- **Architecture**: Any (amd64, arm64, etc.)
- **RAM**: 512 MB minimum, 1 GB recommended
- **Storage**: 50 MB for application, 100 MB recommended for dependencies

### Recommended Requirements
- **Operating System**: PopOS 24.04 LTS with latest updates
- **Desktop Environment**: Cosmic desktop for optimal integration
- **Display Server**: Wayland for enhanced security and performance
- **GTK Version**: GTK4 (with GTK3 fallback support)
- **VTE Version**: 3.0+ (with 2.91 fallback support)

## Pre-Installation Checklist

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Required Dependencies
```bash
# Core dependencies (automatically handled by package manager)
sudo apt install perl libgtk4-1 libadwaita-1-0 xdg-desktop-portal

# Optional but recommended
sudo apt install keepassxc freerdp2-wayland tigervnc-viewer
```

### 3. Check GTK4 Support
```bash
# Verify GTK4 is available
pkg-config --exists gtk4 && echo "GTK4 available" || echo "GTK4 not found"

# Check Wayland support
echo $WAYLAND_DISPLAY && echo "Wayland active" || echo "X11 mode"
```

## Installation Methods

### Method 1: DEB Package Installation (Recommended)

#### Download Package
```bash
# Download the DEB package (replace URL with actual download location)
wget https://github.com/your-repo/asbru-cm/releases/download/v7.0.0/asbru-cm_7.0.0-1_all.deb
```

#### Install Package
```bash
# Install the package
sudo dpkg -i asbru-cm_7.0.0-1_all.deb

# Fix any dependency issues
sudo apt-get install -f
```

#### Verify Installation
```bash
# Check if package is installed
dpkg -l | grep asbru-cm

# Test application launch
asbru-cm --version
```

### Method 2: Manual Installation from Source

#### Prerequisites
```bash
sudo apt install build-essential debhelper devscripts lintian
sudo apt install libgtk-4-dev libadwaita-1-dev libvte-2.91-dev
```

#### Build and Install
```bash
# Clone repository
git clone https://github.com/your-repo/asbru-cm.git
cd asbru-cm

# Build package
./build_production.sh

# Install generated package
sudo dpkg -i asbru-cm_7.0.0-1_all.deb
sudo apt-get install -f
```

### Method 3: Build AppImage (Optional)

Requires either Docker or Podman. The script auto-detects which is available.

```bash
# Install a container engine (choose ONE)
sudo apt-get update
sudo apt-get install -y podman           # Simpler, rootless capable
# OR for Docker:
# (See https://docs.docker.com/engine/install/ for distribution specific instructions)

# Clone and build
git clone https://github.com/totoshko88/asbru-cm.git
cd asbru-cm
bash dist/appimage/make_appimage.sh
ls dist/release/Asbru-CM*.AppImage
```

Force Podman if both engines installed:
```bash
ENGINE=podman bash dist/appimage/make_appimage.sh
```

## Post-Installation Configuration

### 1. Desktop Integration
The application should automatically appear in your application menu. If not:

```bash
# Update desktop database
sudo update-desktop-database

# Refresh application cache
sudo gtk-update-icon-cache /usr/share/icons/hicolor/
```

### 2. First Launch
```bash
# Launch from command line
asbru-cm

# Or launch from application menu
# Look for "Ásbrú Connection Manager" in Network/Internet category
```

### 3. Configuration Migration
If upgrading from v6.x:
- Configuration files are automatically migrated
- Existing connections are preserved
- Encrypted passwords are updated to use modern encryption

## Troubleshooting

### Common Issues and Solutions

#### Issue: Package Installation Fails
```bash
# Error: Dependency conflicts
Solution:
sudo apt update
sudo apt install -f
sudo dpkg --configure -a
```

#### Issue: Application Won't Start
```bash
# Check for missing dependencies
ldd /opt/asbru/asbru-cm

# Check GTK version compatibility
export GTK_DEBUG=interactive
asbru-cm
```

#### Issue: Display Issues on Wayland
```bash
# Force X11 mode if needed
export GDK_BACKEND=x11
asbru-cm

# Or enable Wayland explicitly
export GDK_BACKEND=wayland
asbru-cm
```

#### Issue: Terminal Emulation Problems
```bash
# Check VTE version
pkg-config --modversion vte-2.91

# Install additional VTE support
sudo apt install gir1.2-vte-2.91 libvte-2.91-0
```

#### Issue: System Tray Not Working (Cosmic)
```bash
# Cosmic desktop uses different panel system
# Application will fall back to menu bar integration
# No action needed - this is expected behavior
```

### Compatibility Issues

#### PopOS 22.04 and Earlier
- GTK4 may not be available
- Install GTK3 compatibility packages:
```bash
sudo apt install libgtk3-perl libgtk3-simplelist-perl
```

#### Other Ubuntu Distributions
- Ensure universe repository is enabled:
```bash
sudo add-apt-repository universe
sudo apt update
```

#### Fedora/RHEL Systems
- Convert DEB to RPM or build from source
- Install equivalent dependencies:
```bash
sudo dnf install perl-Gtk4 libadwaita
```

## Uninstallation

### Remove Package
```bash
# Remove application
sudo apt remove asbru-cm

# Remove configuration (optional)
rm -rf ~/.config/asbru/

# Remove dependencies (if not used by other packages)
sudo apt autoremove
```

### Clean Uninstall
```bash
# Complete removal including configuration
sudo apt purge asbru-cm
rm -rf ~/.config/asbru/
rm -rf ~/.local/share/asbru/
```

## Advanced Configuration

### Environment Variables
```bash
# Force GTK version
export GTK_VERSION=4  # or 3 for fallback

# Enable debug mode
export ASBRU_DEBUG=1

# Custom configuration directory
export ASBRU_CFG=/path/to/custom/config
```

### Desktop Environment Specific

#### Cosmic Desktop
- Native panel integration (when available)
- Workspace-aware window management
- Automatic theme synchronization

#### GNOME/Wayland
- Portal-based file dialogs
- Proper clipboard integration
- Screen sharing support

#### KDE Plasma
- System tray integration
- KWallet support (optional)
- Plasma theme compatibility

## Security Considerations

### Modern Encryption
- v7.0.0 uses AES-256-GCM encryption
- PBKDF2 key derivation
- Secure password storage

### Wayland Benefits
- Enhanced application isolation
- Secure clipboard handling
- Protected screen capture

### Network Security
- Updated SSL/TLS implementations
- Modern certificate validation
- Enhanced audit logging

## Performance Optimization

### Memory Usage
- GTK4 provides better memory management
- Reduced resource consumption vs GTK3
- Improved terminal rendering performance

### Startup Time
- Optimized dependency loading
- Faster configuration parsing
- Improved theme detection

## Support and Resources

### Documentation
- User Manual: Available in application Help menu
- Online Documentation: https://www.asbru-cm.net/docs/
- GitHub Wiki: https://github.com/your-repo/asbru-cm/wiki

### Community Support
- GitHub Issues: https://github.com/your-repo/asbru-cm/issues
- Community Forum: https://community.asbru-cm.net/
- IRC Channel: #asbru-cm on Libera.Chat

### Professional Support
- Commercial support available through project maintainers
- Custom deployment assistance
- Enterprise integration services

## Version Information

- **Version**: 7.0.0-1
- **Release Date**: August 2025
- **Compatibility**: PopOS 24.04+, Ubuntu 24.04+
- **Architecture**: All (architecture independent)
- **Package Size**: 465 KB
- **Installed Size**: 3.6 MB

## Changelog Highlights

### New in v7.0.0
- GTK4 compatibility with GTK3 fallback
- Wayland native support
- Cosmic desktop integration
- Modern cryptographic modules
- Enhanced security features
- Improved performance and stability

### Breaking Changes
- Minimum GTK version increased
- Some legacy features deprecated
- Configuration format updated (auto-migrated)

### AI Assistance Disclosure
This version was modernized with AI assistance to update dependencies, migrate to GTK4, and ensure compatibility with modern Linux distributions. All changes are documented and tested.

---

For additional help or questions, please refer to the project documentation or contact the development team.