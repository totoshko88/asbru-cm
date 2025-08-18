# Ásbrú Connection Manager 7.0.1 - Critical Stability Release

## 🚨 Critical Bug Fixes Release

Version 7.0.1 addresses critical stability issues found in version 7.0.0, including application crashes, Wayland compatibility problems, and RDP embedding failures. This is a **highly recommended update** for all users.

## 🎯 Key Improvements

### 🔧 Critical Stability Fixes
- **✅ Application Stability**: Fixed critical application hanging issue when creating local shell connections
- **✅ Wayland Segmentation Fault**: Eliminated GtkSocket crashes by implementing intelligent X11 backend switching  
- **✅ GTK Widget Management**: Resolved critical GTK warnings that caused application crashes
- **✅ Tab Management**: Fixed missing close buttons and tab creation failures
- **✅ Widget Safety**: Implemented safe GTK widget packing to prevent assertion failures

### 🖥️ Enhanced Wayland Compatibility
- **✅ Perfect RDP Embedding**: Advanced window embedding with automatic X11 backend restart for Wayland compatibility
- **✅ Transparent Operation**: Intelligent automatic fallback to X11 backend for RDP embedding on Wayland systems
- **✅ XID Generation**: Successfully generates X11 window IDs (e.g., `XID=52439778`) for perfect embedding
- **✅ Zero Configuration**: No manual setup required - embedding works out of the box on both X11 and Wayland

### 🌟 COSMIC Desktop Integration
- **✅ Native SNI Support**: StatusNotifierItem (SNI) integration for System76's COSMIC environment
- **✅ Modern Tray**: Proper system tray behavior on modern desktop environments
- **✅ Theme Synchronization**: Automatic dark/light theme detection with system integration

### ⚡ Performance Enhancements  
- **✅ Enhanced Theme Detection**: Automatic system theme detection with 5-second performance caching
- **✅ Improved Error Handling**: Safe widget management preventing application freezes
- **✅ Better Debugging**: Enhanced debug output with emoji logging 🔍🚀📡✅
- **✅ Reduced Startup Noise**: Eliminated unnecessary warning messages during normal initialization

## 🛠️ Technical Implementation Details

### Wayland Embedding Architecture
```bash
# Automatic detection and restart with X11 backend
WAYLAND_DISPLAY detected → GDK_BACKEND=x11 → exec restart → Perfect embedding
```

### RDP Client Compatibility Matrix
| Client | X11 Status | Wayland Status | Embedding Quality |
|--------|------------|----------------|-------------------|
| **xfreerdp** | ✅ Perfect | ✅ Perfect | Full GUI in tabs |
| **rdesktop** | ✅ Perfect | ✅ Functional | SSL connections work |

### Enhanced Debugging
```bash
ASBRU_DEBUG=1                # Enable debug output with emoji logging 🔍🚀📡✅
ASBRU_DEBUG_STACK=1          # Include stack traces
ASBRU_FORCE_XFREERDP=1       # Force xfreerdp usage on Wayland (auto-enabled)
```

## 📋 Connection Examples

### xfreerdp (Recommended)
```bash
xfreerdp /parent-window:52442142 /size:740x443 /bpp:24 /dynamic-resolution /u:'user' /v:server:3389
```

### rdesktop (Connectivity Testing)
```bash
rdesktop -X 52442142 -g 740x443 -u 'user' -p 'password' server:3389
# Results in: "Connection established using SSL" ✅
```

## 🧪 Tested Environments

- ✅ **PopOS 24.04 LTS** (COSMIC Desktop) + Wayland
- ✅ **Ubuntu 24.04 LTS** + GNOME/Wayland  
- ✅ **Fedora 40+** + GNOME/Wayland
- ✅ **X11 Display Server** (backward compatibility)

## 🚀 User Experience Improvements

### Before Version 7.0.1
- ❌ Application crashes when creating local connections
- ❌ Segmentation faults on Wayland with RDP embedding
- ❌ Missing tab close buttons
- ❌ GTK widget assertion failures
- ❌ Inconsistent theme detection

### After Version 7.0.1  
- ✅ Stable application behavior across all connection types
- ✅ Perfect RDP embedding on both X11 and Wayland
- ✅ Responsive tab management with proper close buttons
- ✅ Clean startup without GTK warnings
- ✅ Automatic theme detection with caching

## 📦 Installation

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

## 🔄 Upgrade Path

### From 7.0.0
- Direct upgrade recommended
- No configuration changes required
- All existing connections preserved
- Automatic stability improvements

### From 6.x.x
- Follow the full modernization guide in README.md
- Configuration migration handled automatically
- Review new Wayland features

## 📝 Known Issues Resolved

- ✅ **Issue**: Application hanging on local shell connection creation
- ✅ **Issue**: Segmentation faults with GtkSocket on Wayland
- ✅ **Issue**: Missing tab close buttons preventing proper tab management
- ✅ **Issue**: GTK widget assertion failures during startup
- ✅ **Issue**: Inconsistent RDP client selection logic
- ✅ **Issue**: UTF-8 encoding warnings in debug output

## 🤝 Contributing

This modernization fork continues to accept issues and pull requests. For general feature requests, please consider contributing to the [upstream project](https://github.com/asbru-cm/asbru-cm).

## 📄 License

GPL-3.0 License - see [LICENSE](LICENSE) file for details.

---

**Note**: This release represents critical stability improvements over 7.0.0. Upgrading is highly recommended for all users experiencing crashes or Wayland compatibility issues.
