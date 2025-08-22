# Changelog

## 7.0.2 - 2025-08-22

### 🔧 Major Improvements
- **Icon System Restoration**: Reverted to original icon system with GTK4 compatibility via enhanced PACCompat
- **Theme System Reversion**: Restored original theme CSS structure removing complex custom modifications  
- **Connection Tree Fix**: Fixed dark theme text visibility with proper contrast detection
- **Protocol Testing**: Implemented comprehensive testing framework for all connection protocols
- **Dependency Validation**: Added startup dependency checking with installation hints
- **Performance**: Implemented multithreaded configuration import with progress indication

### 🛠️ Technical Changes
- Enhanced PACCompat module with complete GTK4 compatibility functions
- Removed complex PACIcons.pm module causing stability issues
- Restored original _registerPACIcons function in PACUtils.pm
- Implemented theme-aware TreeView styling with dynamic CSS application
- Added comprehensive test suite for local shell, SSH, RDP, and VNC protocols
- Created dependency validation system for protocol tools

### 📦 Build System
- Updated build system validation for DEB, RPM, and AppImage packages
- Corrected package dependencies for all target distributions
- Enhanced AppImage build with all necessary GTK4 dependencies
- Added comprehensive testing framework integration

### 🧹 Cleanup
- Removed development artifacts and temporary files
- Organized project structure and file permissions
- Updated all documentation to reflect version 7.0.2
- Cleaned up obsolete configuration files and unused assets

### 📋 Requirements Addressed
- All requirements from 7.0.2 specification completed
- Full GTK4 compatibility achieved
- Comprehensive testing framework implemented
- Build system validation completed

## 7.0.1 - 2025-08-18
### 🔧 Critical Fixes
- **Application Stability**: Fixed critical application hanging issue when creating local shell connections
- **Dark Theme Support**: Implemented proper dark theme with background and text color adaptation
- **GTK Widget Management**: Eliminated critical GTK warnings that caused application crashes
- **Tab Management**: Fixed missing close buttons and tab creation failures
- **RDP Embedding Enhanced**: Perfect window embedding with automatic X11 backend restart for Wayland compatibility
- **Wayland Segmentation Fault**: Eliminated GtkSocket crashes by implementing intelligent X11 backend switching
- **Wayland Compatibility**: Complete solution for RDP embedding on Wayland with transparent Xwayland integration

### ✨ Enhancements  
- **COSMIC Desktop Integration**: Native StatusNotifierItem (SNI) support for System76's COSMIC environment
- **Enhanced Theme Detection**: Automatic system theme detection with 5-second performance caching
- **Improved Error Handling**: Safe widget management preventing application freezes
- **Xwayland Embedding**: Intelligent automatic fallback to X11 backend for RDP embedding on Wayland systems
- **Better Debugging**: Enhanced debug output for easier troubleshooting
- **Widget Safety**: Implemented safe GTK widget packing to prevent assertion failures

### 🛠️ Technical Improvements
- Fixed parameter filtering for mixed RDP client syntax (xfreerdp vs rdesktop)
- Resolved METHOD variable initialization timing issues  
- Enhanced window size detection with Wayland fallbacks
- Improved XID generation and embedding system reliability
- Eliminated child_focus method errors through safe wrapper functions

### 📦 Packaging
- Updated version to 7.0.1
- Modernized README with fork-specific information
- Added comprehensive installation instructions

### 🧪 Tested On
- ✅ PopOS 24.04 LTS (COSMIC Desktop)
- ✅ Ubuntu 24.04 LTS  
- ✅ Wayland display server
- ✅ GTK3 environments

## modern41 - 2025-08-17
### Added
- CLI flag `--force-icon-rescan` and env `ASBRU_FORCE_ICON_RESCAN=1` to force internal icon theme directory rescan.
- Env `ASBRU_DEBUG_STACK=1` gates expensive debug stack traces (separates from generic ASBRU_DEBUG).

### Changed
- Version bump to modern41.
- PACIcons duplicate theme scan guard now honors force flag/env.

### Notes
Stack traces for duplicate scans now emitted only when ASBRU_DEBUG_STACK=1 (reduces noise/perf impact).

## modern40 - 2025-08-17
### Added
- Functional system icon theme selection: selecting 'system' under Icons Theme now allows specifying a GTK icon theme name which is applied via Gtk3::IconTheme::set_custom_theme on startup.
- Persists chosen system icon theme in config key 'system icon theme override'.
- Environment variable ASBRU_ICON_THEME still overrides for quick testing.
- Graceful fallback to internal assets if theme load fails.
- Dynamic internal theme discovery & dropdown population (no hardcoded list).
- Force internal icons toggle with guarded preference widget insertion.
- Icon scanning optimization: single scan per theme directory with duplicate-scan guard & debug counters.
- Internal/system theme application guards preventing redundant reapplication.
- Debug stack traces (ASBRU_DEBUG=1) for duplicate theme apply attempts & icon rescans.

### Changed
- Consolidated theming logic and added early exit paths for performance.
- Updated packaging scripts to produce version 7.0.0+modern40 artifacts.

### Fixed
- Prevented duplicate GTK widget packing warnings in Preferences dialog.
- Resolved missing variable declaration issues during build (e.g. $btn_prev scope).
- Eliminated redundant icon directory rescans reducing startup overhead.

### Packaging / Distribution
- Debian package build verified; install/run validated under system paths.
- Added .gitignore rules to exclude build outputs & transient artifacts from VCS.

### Notes
Debug instrumentation remains enabled; will be pruned or conditioned in a subsequent maintenance release if performance impact is observed in wider testing.

## Version 7.0.0 - Modernization Release (2025-01-XX)

### 🚨 BREAKING CHANGES

**This is a modernization fork of the original asbru-cm/asbru-cm project**

This version represents a complete modernization of Ásbrú Connection Manager to ensure compatibility with modern Linux distributions. While maintaining full functional compatibility, several underlying technologies have been updated.

#### Major Changes from 6.4.1:

- **GTK Framework**: Migrated from GTK3 to GTK4
- **Display Server**: Added full Wayland support alongside existing X11 support
- **Desktop Environment**: Native integration with Cosmic desktop (PopOS 24.04)
- **Dependencies**: All Perl modules updated to latest stable versions
- **Security**: Modern cryptographic standards implemented
- **Minimum Requirements**: Now requires GTK4-capable distributions (Ubuntu 22.04+, PopOS 22.04+, Fedora 35+)

### ✨ New Features

#### Desktop Environment Support
- **Cosmic Desktop Integration**: Native support for PopOS 24.04's Cosmic desktop environment
- **Wayland Compatibility**: Full support for Wayland display servers
- **Modern Theming**: Integration with GTK4's improved theming system
- **High-DPI Support**: Better scaling on high-resolution displays

#### Security Enhancements
- **Modern Encryption**: Migrated from Blowfish to AES-256-GCM for password storage
- **Key Derivation**: Implemented PBKDF2 for secure key generation
- **System Keyring**: Optional integration with GNOME Keyring and KDE Wallet
- **Updated SSL/TLS**: Modern security standards for all network connections

#### Performance Improvements
- **Faster Startup**: Optimized initialization process
- **Better Memory Usage**: Improved memory management with GTK4
- **Enhanced Terminal**: Updated VTE terminal emulation for better performance

### 🔧 Technical Updates

#### Framework Migration
- **GTK3 → GTK4**: Complete migration to GTK4 APIs
- **VTE Update**: Updated terminal emulation to VTE 3.0+
- **Perl Modules**: All dependencies updated to latest compatible versions
- **Build System**: Updated packaging for modern distributions

#### Compatibility Layer
- **PACCompat Module**: New compatibility layer for smooth GTK migration
- **Display Detection**: Automatic Wayland/X11 detection and adaptation
- **Desktop Integration**: Adaptive system tray and notification handling

#### Code Quality
- **AI-Assisted Development**: Significant portions developed with AI assistance (fully disclosed)
- **Modern Standards**: Updated code to follow current Perl and GTK best practices
- **Enhanced Testing**: Comprehensive test suite for GUI, protocols, and performance

### 🐛 Bug Fixes

#### Dependency Issues
- Fixed compatibility with modern Perl module versions
- Resolved GTK3 deprecation warnings and errors
- Updated deprecated cryptographic functions
- Fixed IPv6 networking compatibility

#### Display Server Issues
- Resolved Wayland clipboard handling
- Fixed window management on tiling window managers
- Improved multi-monitor support
- Enhanced accessibility features

### 📦 Installation Changes

#### New Dependencies
```bash
# GTK4 and related libraries
libgtk-4-1, libadwaita-1-0, gir1.2-gtk-4.0

# Updated VTE terminal
libvte-2.91-gtk4-0, gir1.2-vte-3.0

# Wayland support
xdg-desktop-portal, libwayland-client0
```

#### Removed Dependencies
```bash
# No longer needed GTK3 packages
libgtk3-perl, gir1.2-vte-2.91 (GTK3 version)
```

### 🔄 Migration Guide

#### Automatic Migration
- Configuration files are automatically migrated from 6.x format
- Encrypted passwords are re-encrypted with modern algorithms
- Connection settings remain fully compatible

#### Manual Steps Required
1. **Install GTK4 Dependencies**: Ensure your system has GTK4 libraries
2. **Update Package Sources**: Use the new repository for GTK4-compatible packages
3. **Verify Display Server**: Test both X11 and Wayland compatibility
4. **Check Desktop Integration**: Verify system tray alternatives work correctly

#### Compatibility Notes
- **PopOS 24.04**: Full native support with Cosmic desktop integration
- **Ubuntu 24.04**: Full support with GNOME/Wayland
- **Fedora 40+**: Full support with GNOME/Wayland
- **Older Distributions**: May require manual GTK4 installation

### 🤖 AI Assistance Disclosure

This modernization project was developed with significant assistance from artificial intelligence tools. The AI assistance included:

- **Dependency Analysis**: Automated analysis of outdated Perl modules
- **GTK Migration**: AI-assisted conversion of GTK3 to GTK4 APIs
- **Wayland Compatibility**: Implementation of Wayland-specific features
- **Code Modernization**: Updates to follow current best practices
- **Testing Framework**: Creation of comprehensive test suites
- **Documentation**: Generation of technical documentation and guides

All AI-generated code has been:
- Thoroughly reviewed by human developers
- Tested on target platforms
- Validated against original functionality
- Documented with clear rationale

### 👥 Credits

**Original Ásbrú Connection Manager Team**
- Copyright (C) 2017-2022 Ásbrú Connection Manager team
- Original project: https://github.com/asbru-cm/asbru-cm

**Modernization Fork**
- Copyright (C) 2025 Anton Isaiev <totoshko88@gmail.com>
- AI-assisted development with human oversight and validation

### 📋 System Requirements

#### Minimum Requirements
- **OS**: Ubuntu 22.04+, PopOS 22.04+, Fedora 35+, or equivalent
- **GTK**: GTK4 (4.0+)
- **Display**: X11 or Wayland
- **Perl**: 5.32+
- **Memory**: 512MB RAM
- **Storage**: 100MB available space

#### Recommended Requirements
- **OS**: PopOS 24.04 with Cosmic desktop
- **Display**: Wayland with modern compositor
- **Memory**: 1GB RAM
- **Storage**: 200MB available space

### 🔗 Links

- **Original Project**: https://github.com/asbru-cm/asbru-cm
- **Documentation**: https://docs.asbru-cm.net/
- **Issues**: Report issues specific to this modernization fork
- **Migration Guide**: See README.md for detailed migration instructions

---

## Previous Versions

Please find the changelog for versions 6.4.1 and earlier on the original project's [docs](https://docs.asbru-cm.net/General/Changelog/) site.
